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

    wire [63:0] outdata_s;
    wire [63:0] outdata_u;
    reg  [63:0] res_from_div_s;
    reg  [63:0] res_from_div_u;
    reg         reg_complete_u,reg_complete_s;
    wire        complete_s,complete_u;
    wire        div_ready_s_r,div_ready_s_d,div_ready_u_d,div_ready_u_r;
    wire        div_start_s,div_start_u;
    reg         handled_s;
    reg         handled_u;

    assign div_start_s = div & ~handled_s;
    assign div_start_u = div & ~handled_u;

    always @(posedge div_clk ) begin
        if(~resetn | ~div)
            handled_s <= 1'b0;
        else if(div)begin
            if(~handled_s)
                handled_s <= div_ready_s_d & div_ready_s_r;
            else
                handled_s <= 1'b1;
        end
    end

        always @(posedge div_clk ) begin
        if(~resetn | ~div)
            handled_u <= 1'b0;
        else if(div)begin
            if(~handled_u)
                handled_u <= div_ready_u_d & div_ready_u_r;
            else
                handled_u <= 1'b1;
        end
    end

    div_gen_0 div_s(
        .s_axis_divisor_tdata(y),
        .s_axis_divisor_tvalid (div_start_s),
        .s_axis_divisor_tready (div_ready_s_r),
        .s_axis_dividend_tdata(x),
        .s_axis_dividend_tvalid (div_start_s),
        .s_axis_dividend_tready (div_ready_s_d),
        .aclk(div_clk),
        .m_axis_dout_tdata(outdata_s),
        .m_axis_dout_tvalid (complete_s)
    );
    div_gen_1 div_u(
        .s_axis_divisor_tdata(y),
        .s_axis_divisor_tvalid (div_start_u),
        .s_axis_divisor_tready (div_ready_u_r),
        .s_axis_dividend_tdata(x),
        .s_axis_dividend_tvalid (div_start_u),
        .s_axis_dividend_tready (div_ready_u_d),
        .aclk(div_clk),
        .m_axis_dout_tdata(outdata_u),
        .m_axis_dout_tvalid (complete_u)
    );
    assign complete = reg_complete_u & reg_complete_s; 
    assign {s,r} = {64{div_signed}} & res_from_div_s | {64{~div_signed}} & res_from_div_u;
    always @(posedge div_clk ) begin
        if(complete_u)begin
            res_from_div_u <= outdata_u;
        end
    end
    always @(posedge div_clk ) begin
        if(complete_s)begin
            res_from_div_s <= outdata_s;
        end
    end
    always @(posedge div_clk ) begin
        if(~ handled_u)begin
            reg_complete_u <= 1'b0;
        end
        else if(complete_u)begin
            reg_complete_u <= 1'b1;
        end
    end
    always @(posedge div_clk ) begin
        if(~ handled_s)
            reg_complete_s <= 1'b0;
        else if(complete_s)
            reg_complete_s <= 1'b1;
     end
endmodule
