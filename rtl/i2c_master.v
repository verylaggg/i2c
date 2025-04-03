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
* Description : I2C Master
* 
******************************************************************************/
/*
ex. data = 8'h5a = 8'b01011010
      ____    __    __    __    __    __    __    __    __    _________
SCL       |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|  |__|   

        SR    0     1     0     1     1     0     1     0     ST         
      __           _____       ___________       _____          ____       
SDA     |_________|     |_____|           |_____|     |________|              
                                                                               
*/

module i2c_master(
    input   clk,
    input   rstn,
    input   [7:0] mst_dfifo,
    inout   scl,
    inout   sda
);
    reg [3:0] cnt;
    wire    clk_div16, clk_div8, clk_div4, clk_div2;
    wire    scl_en = 'h0;
    wire    sda_en = 'h0;

    always @ (posedge clk or negedge rstn) begin
        if (!rstn)
            cnt <= 'h0;
        else
            cnt <= cnt + 1;
    end

    assign scl = scl_en ? clk_div4 : 'hz;
    assign sda = sda_en ? 'h0 : 'hz;
    assign {clk_div16, clk_div8, clk_div4, clk_div2} = cnt;

endmodule