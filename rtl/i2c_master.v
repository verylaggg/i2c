/*******************************************************************************
* |----------------------------------------------------------------------------|
* |                      Copyright (C) 2024-2025 VeryLag.                      |
* |                                                                            |
* | THIS SOURCE CODE IS FOR PERSONAL DEVELOPEMENT; OPEN FOR ALL USES BY ANYONE.|
* |                                                                            |
* |   Feel free to modify and use this code, but attribution is appreciated.   |
* |                                                                            |
* |----------------------------------------------------------------------------|
*
* Author : VeryLag (verylag0401@gmail.com)
* 
* Creat : 2025/04/03
* 
* Description : I2C Master
* 
*******************************************************************************/
/*
ex. data = 8'h5a = 8'b01011010
      ____    __    __    __    __    __    __    __    __    _________
SCL       |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|   

        STR   0     1     0     1     1     0     1     0    STP         
      __           _____       ___________       _____          ____       
SDA     |_________|     |_____|           |_____|     |________|              
       fp                                                                      
      __     ___________       ___________       _____          ____       
SDA     |___|           |_____|           |_____|     |________|              
                                                                               
*/

module i2c_master(
    input   clk,
    input   rstn,
    input   [7:0] mst_dfifo,
    output  scl,
    inout   sda
);
    localparam  IDLE    = 0,
                START   = 1, // 0
                ADDR_RW = 2,
                RD_WR   = 3, // WR = 0
                DATA    = 4,
                ACK_NACK= 5, // ACK = 0
                STOP    = 6; // 1

    reg     [3:0]   mst_fsm, mst_fsm_n;
    reg     [3:0]   sda_cnt, clk_div_cnt, bit_cnt;
    reg             sda_en_d1, scl_d1, scl_en, sda_en;
    reg [8*10-1:0]  mst_fsm_ascii;
    reg [7:0] data_buf;
    wire sda_chg;
    wire            scl_rp, scl_fp, scl_bp, str_stb, end_trans;
    wire            clk_div16, clk_div8, clk_div4, clk_div2;

    // to simulate enable i2c master whenever data is ready
    initial begin
        sda_en = 'h0;
        #278;
        sda_en = 'h1;
    end

    always @ (*) begin
        case (mst_fsm)
        IDLE:     mst_fsm_ascii = "IDLE"    ;
        START:    mst_fsm_ascii = "START"   ;
        ADDR_RW:  mst_fsm_ascii = "ADDR_RW" ;
        RD_WR:    mst_fsm_ascii = "RD_WR"   ;
        DATA:     mst_fsm_ascii = "DATA"    ;
        ACK_NACK: mst_fsm_ascii = "ACK_NACK";
        STOP:     mst_fsm_ascii = "STOP"    ;
        endcase
    end

    always @ (*) begin
        mst_fsm_n = mst_fsm;

        case (mst_fsm)
        IDLE: begin
            if (!sda)
                mst_fsm_n = START;
        end
        START: begin
            if (sda_chg)
                mst_fsm_n = ADDR_RW;
        end
        ADDR_RW: begin // 7-bits
            if (bit_cnt == 'h7 && scl_fp)
                mst_fsm_n = ACK_NACK;
        end
//        RD_WR: begin
//            if (scl)
//                mst_fsm_n = ACK_NACK;
//        end
        // the state is also used for ADDR_RW
        DATA: begin // 8-bits
            if (bit_cnt == 'h7 && scl_fp)
                mst_fsm_n = ACK_NACK;
        end
        ACK_NACK: begin
            if (scl_fp)
                mst_fsm_n = DATA;
            else if (end_trans)
                mst_fsm_n = STOP;
        end
        STOP: begin
            mst_fsm_n = IDLE;
        end
        endcase
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            mst_fsm <= IDLE;
        else
            mst_fsm <= mst_fsm_n;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            clk_div_cnt <= 'h0;
        else if (scl_en)
            clk_div_cnt <= clk_div_cnt + 1;
        else
            clk_div_cnt <= 'h0;
    end

    always @ (posedge clk) begin
        sda_en_d1 <= sda_en;
        scl_d1 <= scl;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            scl_en <= 'h0;
        else if (str_stb)
            scl_en <= 'h1;
        else
            scl_en <= scl_en;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            sda_cnt <= 'h0;
        else if (scl)
            sda_cnt <= 'h0;
        else
            sda_cnt <= sda_cnt + 'h1;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            data_buf <= 'h0;
        // TODO NACK needless load
        else if (sda_chg) begin
            if (mst_fsm == START || mst_fsm == ACK_NACK)
                data_buf <= mst_dfifo;
            else if (mst_fsm == DATA || mst_fsm == ADDR_RW)
                data_buf <= {1'h0, data_buf[7:1]};
        end else
            data_buf <= data_buf;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            bit_cnt <= 'h0;
        else if (sda_chg && (mst_fsm == DATA || mst_fsm == ADDR_RW))
            bit_cnt <= bit_cnt + 'h1;
        else if (mst_fsm == ACK_NACK)
            bit_cnt <= 'h0;
        else
            bit_cnt <= bit_cnt;
    end

    assign sda_chg= sda_cnt == 'h4;
    assign scl_rp = !scl_d1 & scl ;
    assign scl_fp = scl_d1 & !scl ;
    assign scl_bp = scl_d1 ^ scl ;

    assign str_stb = !sda_en_d1 && sda_en;
    //assign scl_en = str_stb ? 'h1 : 'h0;
    //assign sda_en = 'h1;
    assign scl = scl_en ? clk_div16 : 'h1;
    assign sda = !sda_en      ? 'hz :
         (mst_fsm == IDLE)    ? 'h0 :
         (mst_fsm == START)   ? data_buf[0] :
         (mst_fsm == ADDR_RW) ? data_buf[0] :
         (mst_fsm == DATA)    ? data_buf[0] : 'hz;
    assign {clk_div16, clk_div8, clk_div4, clk_div2} = clk_div_cnt;

endmodule
