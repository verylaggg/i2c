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

    reg testport = 0;
    reg [7:0] mst_dfifo;
    wire rstn, clk, clk_20m , clk_50m , clk_100m;
    wire  [7:0] mst_status;
    reg  [7:0] mst_ctrl;
    wire scl, sda;
    //pullup (scl);
    pullup (sda);
    reg sda_slv;

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
        .mst_dfifo  (mst_dfifo  ),
        .mst_ctrl   (mst_ctrl   ),
        .mst_status (mst_status ),
        .scl        (scl        ),
        .sda        (sda        )
    );

    // payload
    always @ (posedge scl or negedge rstn) begin
        if (!rstn)
            mst_dfifo <= 'h5a; // wr instr
        else if (i2c_master_x.bit_cnt == 'h7 && (i2c_master_x.mst_fsm == 3 || i2c_master_x.mst_fsm == 4 ))
            mst_dfifo <= mst_dfifo + 2; // randam addr + wr instr
        else
            mst_dfifo <= mst_dfifo;
    end

    // payload ready control
    initial begin
        mst_ctrl = 'h00;
        #210;
        mst_ctrl = 'h80;
        repeat (4) @ (posedge mst_status[7]);
        mst_ctrl = 'h00;

    end

    // ack response
    always @ (*) begin
        sda_slv = 'hz;

        wait (i2c_master_x.mst_fsm == 5);
        @ (posedge i2c_master_x.sda_chg);
        sda_slv = 'h0; // ack = 0 = !nack
        @ (posedge i2c_master_x.sda_chg);
        force sda_slv = 'hz;
        @ (negedge i2c_master_x.sda_chg);
        release sda_slv;
    end

    assign sda = sda_slv;

    initial begin
        @ (posedge rstn) $display ("rstn end");
        testport = 1;
        $display("sim start");

        // wait ~busy
        @ (posedge mst_status[7]);
        @ (negedge mst_status[7]);
        #(150);
        testport = 2;
        $display("sim end");
        $finish;
    end

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

endmodule

