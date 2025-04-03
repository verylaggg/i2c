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
* Creat : 2025/04/02
* 
* Description : testbench
* 
******************************************************************************/
`timescale 1ns/1ns
module tb();

    reg testport = 0;
    wire rstn, clk, clk_20m , clk_50m , clk_100m;
    wire scl, sda;
    pullup (scl);
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
        .mst_dfifo  (8'h5a      ),
        .scl        (scl        ),
        .sda        (sda        )
    );

    initial begin
        @ (posedge rstn) $display ("rstn end");
        testport = 1;
        $display("sim start");

        #(150*1000*8);
        testport = 0;
        $display("sim end");
        $finish;
    end

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

endmodule

