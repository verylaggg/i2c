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

TODO: SDA Counter can be simplified.
*/

module i2c_master #(
    parameter DATA_CHG_INTERVAL = 'h4
)(
    input   clk,
    input   rstn,
    input   [127:0] mst_wfifo,
    input   [15:0] mst_ctrl,
    output  [127:0] mst_rfifo,
    output  [7:0] mst_status,
    output  scl,
    inout   sda
);
    localparam  IDLE    = 0,
                START   = 1, // 0
                ADDR_RW = 2, // WR = 0 = !RD
                DATA    = 3,
                N_ACK   = 4, // ACK = 0 = !NACK
                STOP    = 5; // 1

    reg     [3:0]   mst_fsm, mst_fsm_n;
    reg     [3:0]   sda_cnt, clk_div_cnt, bit_cnt;
    reg     [4:0]   pld_cnt, pld_len_r;
    reg             sda_en_d1, scl_d1, scl_en, sda_en;
    reg [8*10-1:0]  mst_fsm_ascii;
    reg     [127:0] data_buf, mst_rfifo;
    reg             rcv_ack, mst_wr;
    wire            sda_chg, str_stb, stp_stb, scl_fp, sda_o;
    wire            clk_div16, clk_div8, clk_div4, clk_div2;
    // states
    wire            in_idle  = mst_fsm == IDLE;
    wire            in_str   = mst_fsm == START;
    wire            in_addrw = mst_fsm == ADDR_RW;
    wire            in_data  = mst_fsm == DATA;
    wire            in_n_ack = mst_fsm == N_ACK;
    wire            in_stp   = mst_fsm == STOP;
    // control signals
    wire    [6:0]   address = mst_ctrl[15:9];
    wire            rd_wr   = mst_ctrl[8];
    wire            pld_rdy = mst_ctrl[7];
    wire    [4:0]   pld_len = mst_ctrl[3:0] + 'h1; // max payload=16Bytes
    // status signals
    wire    [7:0]   mst_status;

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            sda_en = 'h0;
        else if (in_idle && pld_rdy)
            sda_en = 'h1;
        else if (in_stp && sda && scl)
            sda_en = 'h0;
        else
            sda_en = sda_en;
    end

    always @ (*) begin
        case (mst_fsm)
        IDLE:     mst_fsm_ascii = "IDLE"    ;
        START:    mst_fsm_ascii = "START"   ;
        ADDR_RW:  mst_fsm_ascii = "ADDR_RW" ;
        DATA:     mst_fsm_ascii = "DATA"    ;
        N_ACK:    mst_fsm_ascii = "N_ACK"   ;
        STOP:     mst_fsm_ascii = "STOP"    ;
        endcase
    end

    always @ (*) begin
        mst_fsm_n = mst_fsm;

        case (mst_fsm)
        // 'h0
        IDLE: begin
            if (!sda && scl)
                mst_fsm_n = START;
        end
        // 'h1
        START: begin
            if (scl_fp)
                mst_fsm_n = ADDR_RW;
        end
        // 'h2
        ADDR_RW: begin // 7-bits
            if (bit_cnt == 'h7 && scl_fp)
                mst_fsm_n = N_ACK;
        end
        // 'h3
        DATA: begin // 8-bits
            if (bit_cnt == 'h7 && scl_fp)
                mst_fsm_n = N_ACK;
        end
        // 'h4
        N_ACK: begin
            if (scl_fp) begin
                if (!rcv_ack || (pld_cnt == 'h0))
                    mst_fsm_n = STOP;
                else
                    mst_fsm_n = DATA;
            end
        end
        // 'h5
        STOP: begin
            if (scl && sda)
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
        if (!rstn || stp_stb)
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
        else if (in_idle && pld_rdy) //scl_fp && in_str)
            data_buf <= {address, rd_wr, 120'h0};
        else if (scl_fp && in_n_ack && mst_wr) begin
            if (pld_cnt == pld_len_r)
                data_buf <= mst_wfifo;
            else
                data_buf <= {data_buf[126:0], 1'h0};
        end else if (sda_chg && (bit_cnt > 0) && in_addrw)
            data_buf <= {data_buf[126:0], 1'h0};
        else if (sda_chg && in_data) begin
            if (bit_cnt > 0 && mst_wr)
                data_buf <= {data_buf[126:0], 1'h0};
            else if (!mst_wr) // mst_rd
                data_buf <= {data_buf[126:0], sda};
        end else
            data_buf <= data_buf;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn) begin
            pld_cnt <= 'h0;
            pld_len_r <= 'h0;
            mst_wr <= 'h0;
        end else if (pld_rdy && in_idle) begin
            mst_wr <= !rd_wr;
            pld_cnt <= pld_len;
            pld_len_r <= pld_len;
        end else if (sda_chg && in_data && bit_cnt == 'h0)
            pld_cnt <= pld_cnt - 'h1;
        else begin
            mst_wr <= mst_wr;
            pld_cnt <= pld_cnt;
            pld_len_r <= pld_len_r;
        end
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            rcv_ack <= 'h0;
        else if (in_n_ack) begin
            if (!sda && scl)
                rcv_ack <= 'h1;
            else
                rcv_ack <= rcv_ack;
        end else
            rcv_ack <= 'h0;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            bit_cnt <= 'h0;
        else if (scl_fp && (in_data || in_addrw))
            bit_cnt <= bit_cnt + 'h1;
        else if (scl_fp && in_n_ack)
            bit_cnt <= 'h0;
        else
            bit_cnt <= bit_cnt;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn || in_str)
            mst_rfifo <= 'h0;
        else if (in_stp && !mst_wr && sda_chg)
            mst_rfifo <= data_buf;
        else
            mst_rfifo <= mst_rfifo;
    end

    assign sda_chg= sda_cnt == DATA_CHG_INTERVAL;
    assign scl_fp = scl_d1 & !scl ;
    assign str_stb = !sda_en_d1 && sda_en;
    assign stp_stb = sda_en_d1 && !sda_en;
    assign {clk_div16, clk_div8, clk_div4, clk_div2} = clk_div_cnt;
    assign busy = !in_idle;
    assign mst_status = {busy, 7'h0};
    assign scl = scl_en ? clk_div16 : 'h1;
    assign sda_o = !sda_en ? 'hz :
            (in_idle)    ? 'h0 :
            (in_str)     ? data_buf[127] :
            (in_addrw)   ? data_buf[127] :
            (in_data && mst_wr) ? data_buf[127] :
            (in_stp && sda_cnt != 0) ? 'h0 :
            (in_n_ack && !mst_wr && pld_cnt < pld_len_r && pld_cnt > 'h0) ? 'h0 : 'hz;
    assign sda = sda_o;

endmodule