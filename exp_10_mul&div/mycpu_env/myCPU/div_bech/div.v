`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/11 13:54:05
// Design Name: 
// Module Name: div
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


module div(
    input div_clk,
    input resetn,
    input div,
    input div_signed,
    input [31:0] x,
    input [31:0] y,
    output [31:0] s,
    output [31:0] r,
    output complete
    );
    reg valid;
    always @(posedge div_clk ) begin
        if(~resetn)begin
            valid <= 1'b1;
        end
        else begin
            valid <= div;
        end
    end
    wire [63:0] outdata_s;
    wire [63:0] outdata_u;
    wire complete_s,complete_u;
    wire div_ready_s_r,div_ready_s_d,div_ready_u_d,div_ready_u_r;
    wire div_start;
    assign div_start = div & ~ valid;
    reg [63:0] res_from_div_u;
    reg        reg_complete_u;
    div_gen_0 div_s(
        .s_axis_divisor_tdata(y),
        .s_axis_divisor_tvalid(div_start),
        .s_axis_dividend_tdata(x),
        .s_axis_dividend_tvalid(div_start),
        .aclk(div_clk),
        .m_axis_dout_tdata(outdata_s),
        .m_axis_dout_tvalid(complete_s)
    );
    div_gen_1 div_u(
        .s_axis_divisor_tdata(y),
        .s_axis_divisor_tvalid(div_start),
        .s_axis_dividend_tdata(x),
        .s_axis_dividend_tvalid(div_start),
        .aclk(div_clk),
        .m_axis_dout_tdata(outdata_u),
        .m_axis_dout_tvalid(complete_u)
    );
    assign complete = reg_complete_u & complete_s; 
    assign {s,r} = {64{div_signed}} & outdata_s | {64{~div_signed}} & res_from_div_u;
    always @(posedge div_clk ) begin
        if(complete_u)begin
            res_from_div_u <= outdata_u;
        end
    end
    always @(posedge div_clk ) begin
        if(~valid)begin
            reg_complete_u <= 1'b0;
        end
        else if(complete_u)begin
            reg_complete_u <= 1'b1;
        end
    end
endmodule
