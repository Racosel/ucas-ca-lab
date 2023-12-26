module tlb #(
    parameter TLBNUM = 16
)
(
    input  wire clk,

    // search port 0 (for fetch)
    input  wire [18:0]  s0_vppn,
    input  wire         s0_va_bit12,
    input  wire [ 9:0]  s0_asid,
    output wire         s0_found,
    output wire [$clog2(TLBNUM) - 1:0] s0_index,
    output wire [19:0]  s0_ppn,
    output wire [ 5:0]  s0_ps,
    output wire [ 1:0]  s0_plv,
    output wire [ 1:0]  s0_mat,
    output wire         s0_d,
    output wire         s0_v,

    // search port 1 (for load/store)
    input  wire [18:0]  s1_vppn,
    input  wire         s1_va_bit12,
    input  wire [ 9:0]  s1_asid,
    output wire         s1_found,
    output wire [$clog2(TLBNUM) - 1:0] s1_index,
    output wire [19:0]  s1_ppn,
    output wire [ 5:0]  s1_ps,
    output wire [ 1:0]  s1_plv,
    output wire [ 1:0]  s1_mat,
    output wire         s1_d,
    output wire         s1_v,

    // invtlb opcode
    input  wire         invtlb_valid,
    input  wire [ 4:0]  invtlb_op,

    // write port
    input  wire         we, //w(rite) e(nable)
    input  wire [$clog2(TLBNUM) - 1:0] w_index,
    input  wire         w_e,
    input  wire [18:0]  w_vppn,
    input  wire [ 5:0]  w_ps,
    input  wire [ 9:0]  w_asid,
    input  wire         w_g,
    input  wire [19:0]  w_ppn0,
    input  wire [ 1:0]  w_plv0,
    input  wire [ 1:0]  w_mat0,
    input  wire         w_d0,
    input  wire         w_v0,
    input  wire [19:0]  w_ppn1,
    input  wire [ 1:0]  w_plv1,
    input  wire [ 1:0]  w_mat1,
    input  wire         w_d1,
    input  wire         w_v1,

    // read port
    input  wire [$clog2(TLBNUM) - 1:0] r_index,
    output wire         r_e,
    output wire [18:0]  r_vppn,
    output wire [ 5:0]  r_ps,
    output wire [ 9:0]  r_asid,
    output wire         r_g,
    output wire [19:0]  r_ppn0,
    output wire [ 1:0]  r_plv0,
    output wire [ 1:0]  r_mat0,
    output wire         r_d0,
    output wire         r_v0,
    output wire [19:0]  r_ppn1,
    output wire [ 1:0]  r_plv1,
    output wire [ 1:0]  r_mat1,
    output wire         r_d1,
    output wire         r_v1
);

    reg [TLBNUM - 1:0] tlb_e;
    reg [TLBNUM - 1:0] tlb_ps4MB; //pagesize 1:4MB, 0:4KB

    reg [18:0]  tlb_vppn    [TLBNUM - 1:0];
    reg [ 9:0]  tlb_asid    [TLBNUM - 1:0];
    reg         tlb_g       [TLBNUM - 1:0];
    reg [19:0]  tlb_ppn0    [TLBNUM - 1:0];
    reg [ 1:0]  tlb_plv0    [TLBNUM - 1:0];
    reg [ 1:0]  tlb_mat0    [TLBNUM - 1:0];
    reg         tlb_d0      [TLBNUM - 1:0];
    reg         tlb_v0      [TLBNUM - 1:0];
    reg [19:0]  tlb_ppn1    [TLBNUM - 1:0];
    reg [ 1:0]  tlb_plv1    [TLBNUM - 1:0];
    reg [ 1:0]  tlb_mat1    [TLBNUM - 1:0];
    reg         tlb_d1      [TLBNUM - 1:0];
    reg         tlb_v1      [TLBNUM - 1:0];

    wire [TLBNUM - 1:0] match0;
    wire [TLBNUM - 1:0] match1;
    wire [TLBNUM - 1:0] cond   [ 3:0];
    wire [TLBNUM - 1:0] invtlb_masks [31:0];
    wire                s0_ppg_sel;
    wire                s1_ppg_sel;
    /*
    * Write port: check `we`, then write
    */
    always @ (posedge clk) begin
        if (we) begin
            tlb_e    [w_index] <= w_e;
            tlb_ps4MB[w_index] <= (w_ps == 6'd22);
            tlb_vppn [w_index] <= w_vppn;
            tlb_asid [w_index] <= w_asid;
            tlb_g    [w_index] <= w_g;

            tlb_ppn0 [w_index] <= w_ppn0;
            tlb_plv0 [w_index] <= w_plv0;
            tlb_mat0 [w_index] <= w_mat0;
            tlb_d0   [w_index] <= w_d0;
            tlb_v0   [w_index] <= w_v0;

            tlb_ppn1 [w_index] <= w_ppn1;
            tlb_plv1 [w_index] <= w_plv1;
            tlb_mat1 [w_index] <= w_mat1;
            tlb_d1   [w_index] <= w_d1;
            tlb_v1   [w_index] <= w_v1;
        end else if (invtlb_valid) begin
            tlb_e <= ~invtlb_masks[invtlb_op] & tlb_e;
        end
    end

    /*
     * Read port: direct connection
     */
    assign r_e    = tlb_e    [r_index];
    assign r_vppn = tlb_vppn [r_index];
    assign r_ps   = tlb_ps4MB[r_index] ? 6'd22 : 6'd12;
    assign r_asid = tlb_asid [r_index];
    assign r_g    = tlb_g    [r_index];
    
    assign r_ppn0 = tlb_ppn0 [r_index];
    assign r_plv0 = tlb_plv0 [r_index];
    assign r_mat0 = tlb_mat0 [r_index];
    assign r_d0   = tlb_d0   [r_index];
    assign r_v0   = tlb_v0   [r_index];

    assign r_ppn1 = tlb_ppn1 [r_index];
    assign r_plv1 = tlb_plv1 [r_index];
    assign r_mat1 = tlb_mat1 [r_index];
    assign r_d1   = tlb_d1   [r_index];
    assign r_v1   = tlb_v1   [r_index];

    /*
     * Search port
     */

    genvar i;
    generate
        for (i = 0; i < TLBNUM; i = i + 1) begin: search
            assign match0[i] = (s0_vppn[18: 9]==tlb_vppn[i][18: 9])
                                && (tlb_ps4MB[i] || s0_vppn[8:0]==tlb_vppn[i][8:0])
                                && ((s0_asid==tlb_asid[i]) || tlb_g[i])
                                && tlb_e[i];
            assign match1[i] = (s1_vppn[18: 9]==tlb_vppn[i][18: 9])
                                && (tlb_ps4MB[i] || s1_vppn[8:0]==tlb_vppn[i][8:0])
                                && ((s1_asid==tlb_asid[i]) || tlb_g[i])
                                && tlb_e[i];
        end
    endgenerate

    assign s0_found = |match0;
    log s0_log (.in(match0), .out(s0_index));
    assign s0_ppg_sel = tlb_ps4MB[s0_index] ? s0_vppn[9] : s0_va_bit12;
    assign s0_ps      = tlb_ps4MB[s0_index] ? 6'd22 : 6'd12;

    assign s0_ppn   = s0_ppg_sel ? tlb_ppn1[s0_index] : tlb_ppn0[s0_index];
    assign s0_plv   = s0_ppg_sel ? tlb_plv1[s0_index] : tlb_plv0[s0_index];
    assign s0_mat   = s0_ppg_sel ? tlb_mat1[s0_index] : tlb_mat0[s0_index];
    assign s0_d     = s0_ppg_sel ? tlb_d1  [s0_index] : tlb_d0  [s0_index];
    assign s0_v     = s0_ppg_sel ? tlb_v1  [s0_index] : tlb_v0  [s0_index];

    assign s1_found = |match1;
    log s1_log (.in(match1), .out(s1_index));
    assign s1_ppg_sel = tlb_ps4MB[s1_index] ? s1_vppn[9] : s1_va_bit12;
    assign s1_ps      = tlb_ps4MB[s1_index] ? 6'd22 : 6'd12;

    assign s1_ppn   = s1_ppg_sel ? tlb_ppn1[s1_index] : tlb_ppn0[s1_index];
    assign s1_plv   = s1_ppg_sel ? tlb_plv1[s1_index] : tlb_plv0[s1_index];
    assign s1_mat   = s1_ppg_sel ? tlb_mat1[s1_index] : tlb_mat0[s1_index];
    assign s1_d     = s1_ppg_sel ? tlb_d1  [s1_index] : tlb_d0  [s1_index];
    assign s1_v     = s1_ppg_sel ? tlb_v1  [s1_index] : tlb_v0  [s1_index];

    /*
     * Invalidation
     */
    generate for (i = 0; i < TLBNUM; i = i + 1) begin
        // cond0 : G == 0 ?
        assign cond[0][i] = ~tlb_g[i];
        // cond1 : G == 1 ?
        assign cond[1][i] =  tlb_g[i]; 
        // cond2 : ASID == s1_asid ?
        assign cond[2][i] = s1_asid == tlb_asid[i];
        // cond3 : VPN == s1_vppn ?
        assign cond[3][i] = s1_vppn[18:10] == tlb_vppn[i][18:10] &&     
                               (s1_vppn[ 9: 0] == tlb_vppn[i][ 9: 0] || tlb_ps4MB[i]);
    end        
    endgenerate

    assign invtlb_masks[0] = cond[0] | cond[1];                // clear all
    assign invtlb_masks[1] = cond[0] | cond[1];                // clear all
    assign invtlb_masks[2] = cond[1];                           // clear all G = 1
    assign invtlb_masks[3] = cond[0];                           // clear all G = 0
    assign invtlb_masks[4] = cond[0] & cond[2];                // clear all ASID = s1_asid, G = 0
    assign invtlb_masks[5] = cond[0] & cond[2] & cond[3];     // clear all ASID = s1_asid, G = 0, VPN = s1_vppn
    assign invtlb_masks[6] = (cond[0] | cond[2]) & cond[3];   // clear all ASID = s1_asid, VPN = s1_vppn
    generate for (i = 7; i < 32; i = i + 1) begin
        assign invtlb_masks[i] = 16'b0; 
        // TIPS: 未在表中出现�? op 将触发保留指令例外，此处不做处理
    end
    endgenerate


endmodule

module log(
    input  wire [15:0] in,
    output wire [ 3:0] out
);
    assign out = {4{in[ 0]}} &  4'd0 | {4{in[ 1]}} &  4'd1 | {4{in[ 2]}} &  4'd2 | {4{in[ 3]}} &  4'd3 |
                 {4{in[ 4]}} &  4'd4 | {4{in[ 5]}} &  4'd5 | {4{in[ 6]}} &  4'd6 | {4{in[ 7]}} &  4'd7 |
                 {4{in[ 8]}} &  4'd8 | {4{in[ 9]}} &  4'd9 | {4{in[10]}} & 4'd10 | {4{in[11]}} & 4'd11 |
                 {4{in[12]}} & 4'd12 | {4{in[13]}} & 4'd13 | {4{in[14]}} & 4'd14 | {4{in[15]}} & 4'd15;
endmodule