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
* Creat : 2025/04/18
* 
* Description : I2C Slave
* 
*******************************************************************************/
module i2c_slave(
    input   clk,
    input   rstn,
    input   scl,
    inout   sda
);
    localparam  IDLE    = 0,
                START   = 1, // 0
                ADDR_RW = 2, // WR = 0 = !RD
                DATA    = 3,
                N_ACK   = 4, // ACK = 0 = !NACK
                STOP    = 5; // 1
    localparam DATA_CHG_INTERVAL = 'h4;

    reg     [6:0]   slave_addr = 'h2d;
    reg     [3:0]   slv_fsm, slv_fsm_n, bit_cnt;
    reg     [4:0]   pld_cnt;
    reg [8*10-1:0]  slv_fsm_ascii;
    reg     [127:0] data_buf;
    reg             scl_d1, sda_d1, selected, mst_wr;
    reg     [7:0]   mst_instr;
    wire            scl_fp, scl_rp, sda_fp, sda_rp, sda_o;
    // states
    wire            in_idle  = slv_fsm == IDLE;
    wire            in_str   = slv_fsm == START;
    wire            in_addrw = slv_fsm == ADDR_RW;
    wire            in_data  = slv_fsm == DATA;
    wire            in_n_ack = slv_fsm == N_ACK;
    wire            in_stp   = slv_fsm == STOP;

    always @ (*) begin
        case (slv_fsm)
        IDLE:     slv_fsm_ascii = "IDLE"    ;
        START:    slv_fsm_ascii = "START"   ;
        ADDR_RW:  slv_fsm_ascii = "ADDR_RW" ;
        DATA:     slv_fsm_ascii = "DATA"    ;
        N_ACK:    slv_fsm_ascii = "N_ACK"   ;
        STOP:     slv_fsm_ascii = "STOP"    ;
        endcase
    end

    always @ (*) begin
        slv_fsm_n = slv_fsm;

        case (slv_fsm)
        // 'h0
        IDLE: begin
            if (scl && sda_fp)
                slv_fsm_n = START;
        end
        // 'h1
        START: begin
            if (scl_fp)
                slv_fsm_n = ADDR_RW;
        end
        // 'h2
        ADDR_RW: begin // 7b addr + 1b rw
            if (bit_cnt == 'h7 && scl_fp)
                slv_fsm_n = N_ACK;
        end
        // 'h3
        DATA: begin // 8b data
            if (scl && sda_rp)
                slv_fsm_n = STOP;
            else if (bit_cnt == 'h7 && scl_fp)
                slv_fsm_n = N_ACK;
        end
        // 'h4
        N_ACK: begin
            if (!mst_wr && scl && sda)
                slv_fsm_n = STOP;
            else if (scl_fp)
                slv_fsm_n = DATA;
        end
        // 'h5
        STOP: begin
            slv_fsm_n = IDLE;
        end
        endcase
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            slv_fsm <= IDLE;
        else
            slv_fsm <= slv_fsm_n;
    end

    always @ (posedge clk) begin
            scl_d1 <= scl;
            sda_d1 <= sda;
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
        if (!rstn || in_idle)
            {selected, mst_wr} <= 'h0;
        else if (in_addrw && scl_fp && bit_cnt == 'h7)
            {selected, mst_wr} <= {mst_instr[7:1] == slave_addr, !mst_instr[0]};
        else
            {selected, mst_wr} <= {selected, mst_wr};
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            data_buf <= {4{32'hdead_beef}};
        else if (scl_fp && in_data && mst_wr)
            data_buf <= {data_buf[126:0], sda};
        else if (scl_fp && in_data && !mst_wr)
            data_buf <= {data_buf[126:0], 1'h0};
        else
            data_buf <= data_buf;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            mst_instr <= 'h0;
        else if (scl_rp && in_addrw)
            mst_instr <= {mst_instr[6:0], sda};
        else
            mst_instr <= mst_instr;
    end

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            pld_cnt <= 'h0;
        else if (in_data && bit_cnt == 'h0 && scl_fp)
            pld_cnt <= pld_cnt + 'h1;
        else
            pld_cnt <= pld_cnt;
    end

    assign scl_fp = scl_d1 && !scl;
    assign scl_rp = !scl_d1 && scl;
    assign sda_fp = sda_d1 && !sda;
    assign sda_rp = !sda_d1 && sda;
    assign sda_o = in_idle ? 'hz :
            (in_n_ack && selected && !mst_wr && pld_cnt == 'h0) ? 'h0 :
            (in_n_ack && selected && mst_wr && pld_cnt < 'h11) ? 'h0 :
            (in_data && !mst_wr) ? data_buf[127] : 'hz;
    assign sda = sda_o;
endmodule