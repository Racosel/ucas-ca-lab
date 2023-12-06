`timescale 1ns / 1ps

module div(
    input clk,
    input resetn,
    input cancel_exc_ertn,
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
    reg         handling;
    reg         canceled_s,canceled_u;

    always @(posedge clk ) begin
        if(~resetn)
            handling <= 1'b0;
        else if(complete | cancel_exc_ertn)
            handling <= 1'b0;
        else if(div)
            handling <= 1'b1;
    end

    always @(posedge clk ) begin
        if(~resetn)
            canceled_s <= 1'b0;
        else if(~canceled_s & cancel_exc_ertn & handling)
            canceled_s <= handled_s;
        else if(canceled_s & complete_s)
            canceled_s <= 1'b0;
    end

    always @(posedge clk ) begin
        if(~resetn)
            canceled_u <= 1'b0;
        else if(~canceled_u & cancel_exc_ertn & handling)
            canceled_u <= handled_u;
        else if(canceled_u & complete_u)
            canceled_u <= 1'b0;
    end

    assign div_start_s = div & ~handled_s;
    assign div_start_u = div & ~handled_u;

    always @(posedge clk ) begin
        if(~resetn | ~div)
            handled_s <= 1'b0;
        else if(div)begin
            if(~handled_s)
                handled_s <= div_ready_s_d & div_ready_s_r;
            else
                handled_s <= 1'b1;
        end
    end

        always @(posedge clk ) begin
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
        .aclk(clk),
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
        .aclk(clk),
        .m_axis_dout_tdata(outdata_u),
        .m_axis_dout_tvalid (complete_u)
    );
    assign complete = reg_complete_u & reg_complete_s;
    assign {s,r} = {64{div_signed}} & res_from_div_s | {64{~div_signed}} & res_from_div_u;
    always @(posedge clk ) begin
        if(complete_u)begin
            res_from_div_u <= outdata_u;
        end
    end
    always @(posedge clk ) begin
        if(complete_s)begin
            res_from_div_s <= outdata_s;
        end
    end
    always @(posedge clk ) begin
        if(~ handled_u | complete)begin
            reg_complete_u <= 1'b0;
        end
        else if(complete_u & ~canceled_u)begin
            reg_complete_u <= 1'b1;
        end
    end
    always @(posedge clk ) begin
        if(~ handled_s | complete)
            reg_complete_s <= 1'b0;
        else if(complete_s & ~canceled_s)
            reg_complete_s <= 1'b1;
     end
endmodule
