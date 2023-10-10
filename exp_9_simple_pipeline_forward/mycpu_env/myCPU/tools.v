module decoder_2_4(
    input  wire [ 1:0] in,
    output wire [ 3:0] out
);

genvar i;
generate for (i=0; i<4; i=i+1) begin : gen_for_dec_2_4
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_4_16(
    input  wire [ 3:0] in,
    output wire [15:0] out
);

genvar i;
generate for (i=0; i<16; i=i+1) begin : gen_for_dec_4_16
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_5_32(
    input  wire [ 4:0] in,
    output wire [31:0] out
);

genvar i;
generate for (i=0; i<32; i=i+1) begin : gen_for_dec_5_32
    assign out[i] = (in == i);
end endgenerate

endmodule


module decoder_6_64(
    input  wire [ 5:0] in,
    output wire [63:0] out
);

genvar i;
generate for (i=0; i<64; i=i+1) begin : gen_for_dec_6_64
    assign out[i] = (in == i);
end endgenerate

endmodule

module priority_mux_4_32(
    input  wire [ 4:0] need,
    input  wire [31:0] data_in0,
    input  wire [ 4:0] dest_in0,
    input  wire [31:0] data_in1,
    input  wire [ 4:0] dest_in1,
    input  wire [31:0] data_in2,
    input  wire [ 4:0] dest_in2,
    input  wire [31:0] data_in3,
    input  wire [ 4:0] dest_in3,
    output wire [31:0] data_out
);
// 4-to-64 priority mux, compare need with dest_in0, dest_in1, dest_in2, dest_in3
// the first match will be selected
// priority: dest_in0 > dest_in1 > dest_in2 > dest_in3

    wire [31:0] data_out_mux;
    assign data_out_mux = (need == dest_in0) ? data_in0 :
                        (need == dest_in1) ? data_in1 :
                        (need == dest_in2) ? data_in2 :
                        (need == dest_in3) ? data_in3 :
                        64'h0;
    assign data_out = (need == 5'h0) ? 32'h0 : data_out_mux;

endmodule