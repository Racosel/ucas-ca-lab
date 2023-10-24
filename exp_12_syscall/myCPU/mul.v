`timescale 1ns / 1ps

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
