module cpu_timer(
    input  wire        clk,
    input  wire        resetn,
    output wire [63:0] time_now
);
    reg [63:0] current_time;

    always @(posedge clk ) begin
        if(~resetn)
            current_time <= 63'b0;
        else
            current_time <= current_time + 1;
    end

    assign time_now = current_time;
endmodule