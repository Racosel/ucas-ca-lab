`timescale 1ns / 1ps

///////////////////// below ensure correctness /////////////////////////

module wallace_tree( //17 bit wallace tree

    input  [16:0] A_,
    input  [14:0] CI, //15 bit C_in/C_out
    output [14:0] CO,
    output [ 1:0] B_ // B is output for the terminate adder
);

    wire [ 5:0] O1;
    wire [ 3:0] O2;
    wire [ 1:0] O3;
    wire [ 1:0] O4;
    wire [ 0:0] O5;
    assign CO = {O5, O4, O3, O2, O1};

    wire [ 5:0] I1;
    wire [ 3:0] I2;
    wire [ 1:0] I3;
    wire [ 1:0] I4;
    wire [ 0:0] I5;
    assign I5 = CI[14:14];
    assign I4 = CI[13:12];
    assign I3 = CI[11:10];
    assign I2 = CI[ 9: 6];
    assign I1 = CI[ 5: 0];

    wire [5:0] T1;
    wire [3:0] T2;
    wire [3:0] T3;
    wire [1:0] T4;
    wire [1:0] T5;

    wire [0:0] L1, L2, L3;

    half_adder inst_10 (        A_[ 1], A_[ 0], O1[ 0], T1[ 0]);
    adder      inst_11 (A_[ 4], A_[ 3], A_[ 2], O1[ 1], T1[ 1]);
    adder      inst_12 (A_[ 7], A_[ 6], A_[ 5], O1[ 2], T1[ 2]);
    adder      inst_13 (A_[10], A_[ 9], A_[ 8], O1[ 3], T1[ 3]);
    adder      inst_14 (A_[13], A_[12], A_[11], O1[ 4], T1[ 4]);
    adder      inst_15 (A_[16], A_[15], A_[14], O1[ 5], T1[ 5]);

    adder      inst_20 (I1[ 2], I1[ 1], I1[ 0], O2[ 0], T2[ 0]);
    adder      inst_21 (I1[ 5], I1[ 4], I1[ 3], O2[ 1], T2[ 1]);
    adder      inst_22 (T1[ 2], T1[ 1], T1[ 0], O2[ 2], T2[ 2]);
    adder      inst_23 (T1[ 5], T1[ 4], T1[ 3], O2[ 3], T2[ 3]);

    link       inst_30 (                I2[ 0], L1            );
    link       inst_31 (                I2[ 1], L2            );
    adder      inst_32 (T2[ 0], I2[ 3], I2[ 2], O3[ 0], T3[ 0]);
    adder      inst_33 (T2[ 3], T2[ 2], T2[ 1], O3[ 1], T3[ 1]);

    adder      inst_40 (L1    , I3[ 1], I3[ 0], O4[ 0], T4[ 0]);
    adder      inst_41 (T3[ 1], T3[ 0], L2    , O4[ 1], T4[ 1]);

    link       inst_50 (                I4[ 0], L3            );
    adder      inst_51 (T4[ 1], T4[ 0], I4[ 1], O5[ 0], T5[ 0]);

    adder      inst_60 (T5[ 0], L3    , I5[ 0], B_[ 1], B_[ 0]);

endmodule


module adder( // 1 bit full adder
    input  [0:0] A,
    input  [0:0] B,
    input  [0:0] C_in,
    output [0:0] C_out,
    output [0:0] S
);
    assign C_out = A & B | C_in & A | C_in & B;
    assign S = A ^ B ^ C_in;

endmodule


module link( // 1 bit wire
    input  [0:0] A,
    output [0:0] B
);
    assign B = A;
endmodule


module half_adder( // 1 bit half adder
    input [0:0] A,
    input [0:0] B,
    output [0:0] C_out,
    output [0:0] S
);
    assign C_out = A & B;
    assign S = A ^ B;
endmodule


module adder_68( // 68 bit full adder
    input  [67:0] A,
    input  [67:0] B,
    input  [ 0:0] C_in,
    output [ 0:0] C_out,
    output [67:0] S
);
    assign {C_out, S} = A + B + C_in;
endmodule


module gen_select( // generate select signal for partial product
    input [2:0]y, // {y_i+1, y_i, y_i-1}
    output [3:0]sel // {-2X, -X, +X, +2X}
);
    assign sel[3] = (y == 3'b100);
    assign sel[2] = (y == 3'b101) | (y == 3'b110);
    assign sel[1] = (y == 3'b001) | (y == 3'b010);
    assign sel[0] = (y == 3'b011);
endmodule


module select ( // select partial product
    input  [3:0] sel, // {-2X, -X, +X, +2X}
    input  [0:0] x,
    input  [0:0] x_in,
    output [0:0] p,
    output [0:0] x_out
);
    assign p =  sel[3] & ~x_in |
                sel[2] & ~x    |
                sel[1] &  x    |
                sel[0] &  x_in ;
    assign x_out = x;
endmodule


module partial_product ( // 34 bit partial product, but written in 35bit for sign extend
    input  [ 2:0]y, // {y_i+1, y_i, y_i-1}
    input  [33:0]x,
    output [34:0]p,
    output [ 0:0]c
);
    wire [3:0]sel;
    wire [34:0]temp;
    assign temp[0] = 1'b0;
    gen_select gen_select0(y, sel);

    genvar i;
    generate
        for (i = 0; i < 34; i = i + 1) begin: gen_for
            select select1(sel, x[i], temp[i], p[i], temp[i+1]);
        end
    endgenerate

    assign p[34] =  sel[3] & ~temp[34]|
                    sel[2] & ~   x[33]|
                    sel[1] &     x[33]|
                    sel[0] &  temp[34];
    assign c = sel[3] | sel[2];
endmodule

///////////////////////// above ensure correctness /////////////////////////
module multiplier(          // 34 bit multiplier
    input  [33:0] X,
    input  [33:0] Y,
    output [67:0] P
);
    wire [ 594:0] p;            //33bit * 16 -> 35bit * 17
    wire [1155:0] pad;          //64bit * 16 -> 68bit * 17
    wire [  16:0] c;            //15bit -> 17bit
    wire [1034:0] wallace_c;    //14bit * 65 -> 15bit * 69
    wire [  68:0] adder_X;      //65bit -> 69bit
    wire [  67:0] adder_Y;      //64bit -> 68bit
    genvar i;

    partial_product partial_product0(
        {Y[1:0], 1'b0},
        X,
        p[34:0],
        c[0]
    );

    assign pad[67:0] = {{34{p[33]}}, p[33:0]};

    generate
        for (i = 1; i < 17; i = i + 1) begin: gen_for1
            partial_product partial_product0(
                Y[2*i+1:2*i-1],
                X,
                p[35*i+34:35*i],
                c[i]
            );
            assign pad[68*i+67:68*i] = {    //68bit
                {34-2*i-1{p[35*i+34]}},     //68-35-2i=33-2i=34-2i-1
                p[35*i+34:35*i],            //35
                {2*i{Y[2*i+1]&!(Y[2*i]&Y[2*i-1])}}  //2i
            };
        end
    endgenerate

    assign wallace_c[14:0] = c[14:0];
    assign adder_X[0] = c[15];///////
    
    genvar j;
    generate
    for (j = 0; j < 68; j = j + 1) begin: gen_for2
        wallace_tree wallace_tree1( 
            { 
                pad[ 0*68+j], pad[ 1*68+j], pad[ 2*68+j], pad[ 3*68+j],
                pad[ 4*68+j], pad[ 5*68+j], pad[ 6*68+j], pad[ 7*68+j],
                pad[ 8*68+j], pad[ 9*68+j], pad[10*68+j], pad[11*68+j],
                pad[12*68+j], pad[13*68+j], pad[14*68+j], pad[15*68+j], pad[16*68+j]
            },
            wallace_c[15*j+14 :15*j ],
            wallace_c[15*j+14+15:15*j+15],
            {adder_X[j+1], adder_Y[j]}
        );
        end
    endgenerate

    adder_68 adder_68_0(
        adder_X[67:0],
        adder_Y,
        c[16],
        ,
        P
    );
endmodule

module mul(
    // input  [33:0] X,
    // input  [33:0] Y,
    // output [67:0] P
    input         clk,
    input         resetn,
    input         sign,
    input  [31:0] X,
    input  [31:0] Y,
    output [63:0] P
);

    wire  [33:0] X_;
    wire  [33:0] Y_;
    wire  [67:0] P_;
    assign X_ = {{2{sign & X[31]}}, X};
    assign Y_ = {{2{sign & Y[31]}}, Y};
    multiplier multiplier0(
        X_,
        Y_,
        P_
    );
    // assign P = P_[63:0];
    assign P = P_;

endmodule