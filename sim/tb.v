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

    reg [3:0] TEST_STEP = 0;
    reg [127:0] mst_wfifo;
    reg  [15:0] mst_ctrl; // 7b_adr, 1b_rw, 1b_rdy(en), 3b_rsvd, 4b_len
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

    i2c_slave #(
        .SLV_ADDR   ('h2d       )
    ) i2c_slave1_x (
        .clk        (clk_100m   ),
        .rstn       (rstn       ),
        .scl        (scl        ),
        .sda        (sda        )
    );

    i2c_slave #(
        .SLV_ADDR   ('h2c       )
    ) i2c_slave2_x (
        .clk        (clk_100m   ),
        .rstn       (rstn       ),
        .scl        (scl        ),
        .sda        (sda        )
    );

    always @ (posedge mst_ctrl[7]) begin
        $display("I2C_MST_STEP_%0h @ %0t ns, addr=%0h, wr=%0h, len=%0h",
            TEST_STEP,
            $realtime,
            mst_ctrl[15:9],
            !mst_ctrl[8],
            mst_ctrl[3:0] );
    end

    // i2c_master control
    initial begin
        TEST_STEP = 0;
        mst_wfifo = {16{8'h5a}};
        mst_ctrl = 'h00_00;
        #210;

        TEST_STEP = 1;
        MST_CTRL_ONCE('h2d, 1, 'hf);
        #2880;

        TEST_STEP = 2;
        MST_CTRL_ONCE('h2d, 0, 'hf);
        #388;

        TEST_STEP = 3;
        MST_CTRL_ONCE('h2c, 1, 'hf);
        #2880;

        TEST_STEP = 4;
        MST_CTRL_ONCE('h2c, 0, 'hf);
        #2880;

        TEST_STEP = 5;
    end

    initial begin
        @ (posedge rstn) $display ("rstn end");
        wait (TEST_STEP == 'h1);
        $display("sim start");

        wait (TEST_STEP == 'h5);
        $display("sim end");
        $finish;
    end

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

    task MST_CTRL_ONCE;
        input [6:0] addr;
        input       rd_wr; // wr = 0 = !rd
        input [3:0] pld_len;
    begin
        mst_ctrl = {addr, rd_wr, 4'b1000, pld_len};
        @ (posedge mst_status[7]) mst_ctrl = 'h00_00;
        @ (negedge mst_status[7]);
    end
    endtask

endmodule

