/******************************************************************************
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
* Description : testbench
* 
******************************************************************************/
`timescale 1ns/1ns
module tb();

    reg TEST_STEP = 0;
    reg [127:0] mst_wfifo;
    reg  [15:0] mst_ctrl; // 7b_adr, 1b_rw, 1b_rdy(en), 3b_rsvd, 4b_len
    reg sda_slv;
    reg [3:0] last_mst_fsm;
    wire [127:0] mst_rfifo;
    wire rstn, clk, clk_20m , clk_50m , clk_100m;
    wire  [7:0] mst_status; // 1b_busy, 7b_rsvd
    wire scl, sda;
    pullup (sda);

    clk_rst_model # (
        .period     (100        )
    ) clk_rst_m (
        .clk        (clk        ),
        .clk_20m    (clk_20m    ),
        .clk_50m    (clk_50m    ),
        .clk_100m   (clk_100m   ),
        .rstn       (rstn       )
    );

    i2c_master i2c_master_x (
        .clk        (clk_100m   ),
        .rstn       (rstn       ),
        .mst_wfifo  (mst_wfifo  ), // MSB -- B0 -- Bx -- LSB
        .mst_ctrl   (mst_ctrl   ),
        .mst_rfifo  (mst_rfifo  ),
        .mst_status (mst_status ),
        .scl        (scl        ),
        .sda        (sda        )
    );

    always @ (posedge clk_100m) begin
        if (i2c_master_x.mst_fsm != i2c_master_x.mst_fsm_n)
            last_mst_fsm <= i2c_master_x.mst_fsm;
        else
            last_mst_fsm <= last_mst_fsm;
    end

    // payload
    always @ (posedge scl or negedge rstn) begin
        if (!rstn)
            mst_wfifo <= {16{8'h5a}};
        else
            mst_wfifo <= mst_wfifo;
    end

    // payload ready control
    initial begin
        mst_ctrl = 'h5b_03;
        #210;
        mst_ctrl = 'h5b_83;
        repeat (1) @ (posedge mst_status[7]);
        mst_ctrl = 'h5b_03;
    end

    // ack response
    always @ (*) begin
        sda_slv = 'hz;

        if (i2c_master_x.is_wr) begin // write
            if (i2c_master_x.in_n_ack) begin
                @ (posedge i2c_master_x.sda_chg);
                sda_slv = 'h0; // ack = 0 = !nack
                @ (posedge i2c_master_x.sda_chg);
                force sda_slv = 'hz;
                @ (negedge i2c_master_x.sda_chg);
                release sda_slv;
            end
        end else begin // read
            if (i2c_master_x.in_n_ack && last_mst_fsm == 2) begin
                @ (posedge i2c_master_x.sda_chg);
                sda_slv = 'h0; // ack = 0 = !nack
                @ (posedge i2c_master_x.sda_chg);
                force sda_slv = 'hz;
                @ (negedge i2c_master_x.sda_chg);
                release sda_slv;
            end

        end
    end

    assign sda = sda_slv;

    initial begin
        @ (posedge rstn) $display ("rstn end");
        TEST_STEP = 1;
        $display("sim start");

        // wait ~busy
        @ (posedge mst_status[7]);
        @ (negedge mst_status[7]);
        #(150);
        TEST_STEP = 2;
        $display("sim end");
        $finish;
    end

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

endmodule

