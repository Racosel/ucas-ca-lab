`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/11 15:24:25
// Design Name: 
// Module Name: mul
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mul(
input mul_clk,
input resetn,
input mul_signed,
input [31:0] x,
input [31:0] y,
output[63:0]result
);
    wire [32:0] extended_x;
    wire [32:0] extended_y;
    wire [63:0] tempans;
    assign extended_x = {mul_signed & x[31],x};
    assign extended_y = {mul_signed & y[31],y};
    assign tempans = $signed(extended_x) * $signed(extended_y) ;
    assign result = tempans;
endmodule
