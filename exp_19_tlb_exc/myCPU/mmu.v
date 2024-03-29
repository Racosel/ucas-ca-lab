module mmu
(
    input  wire   clk,
    //user related tlb signals
    input  [31:0] pre_if_vaddr,
    output [31:0] pre_if_addr,
    output [2 :0] s0_exc,//{s0_pif,s0_ppi,s0_tlbr}
    input  [31:0] exe_vaddr,
    input         exe_wr_rd,
    input         exe_wr,
    output [31:0] exe_addr,
    output [4 :0] s1_exc,//{s1_pil,s1_pis,s1_pme,s1_ppi,s1_tlbr}
    //kernel related tlb signals
    input  [9 :0] asid,
    input  [1 :0] plv,
    input         inst_tlbsrch,
    input         inst_invtlb,
    input         da,
    input         pg,
    input         dmw0_plv0,
    input         dmw0_plv3,
    input  [2 :0] dmw0_vseg,
    input  [2 :0] dmw0_pseg,
    input         dmw1_plv0,
    input         dmw1_plv3,
    input  [2 :0] dmw1_vseg,
    input  [2 :0] dmw1_pseg,
    //tlbrsch
    input  [18:0] csr_s1_vppn,
    output        csr_s1_found,
    output [3 :0] csr_s1_index,
    output [19:0] csr_s1_ppn,
    output [5 :0] csr_s1_ps,
    output [1 :0] csr_s1_plv,
    output [1 :0] csr_s1_mat,
    output        csr_s1_d,
    output        csr_s1_v,
    //tlbwr
    input         csr_tlb_we,
    input  [3 :0] csr_w_index,
    input         csr_w_e,
    input  [18:0] csr_w_vppn,
    input [ 5:0]  csr_w_ps,
    input [ 9:0]  csr_w_asid,
    input         csr_w_g,
    input [19:0]  csr_w_ppn0,
    input [ 1:0]  csr_w_plv0,
    input [ 1:0]  csr_w_mat0,
    input         csr_w_d0,
    input         csr_w_v0,
    input [19:0]  csr_w_ppn1,
    input [ 1:0]  csr_w_plv1,
    input [ 1:0]  csr_w_mat1,
    input         csr_w_d1,
    input         csr_w_v1,
    //tlbrd
    input  [3 :0] csr_r_index,
    output        csr_r_e,
    output [18:0] csr_r_vppn,
    output [ 5:0] csr_r_ps,
    output [ 9:0] csr_r_asid,
    output        csr_r_g,
    output [19:0] csr_r_ppn0,
    output [ 1:0] csr_r_plv0,
    output [ 1:0] csr_r_mat0,
    output        csr_r_d0,
    output        csr_r_v0,
    output [19:0] csr_r_ppn1,
    output [ 1:0] csr_r_plv1,
    output [ 1:0] csr_r_mat1,
    output        csr_r_d1,
    output        csr_r_v1,
    //invtlb signals
    input  [4 :0] invtlb_op,
    input  [18:0] inv_vppn,
    input  [9 :0] inv_asid
);

    // search port 0 (for fetch)
    wire [18:0]  s0_vppn;
    wire         s0_va_bit12;
    wire         s0_found;
    wire [3 :0]  s0_index;
    wire [19:0]  s0_ppn;
    wire [5 :0]  s0_ps;
    wire [1 :0]  s0_plv;
    wire [1 :0]  s0_mat;
    wire         s0_d;
    wire         s0_v;
    //pre if related
    wire         s0_dmw0_hit,s0_dmw1_hit,s0_dmw_hit;
    wire [19:0]  s0_dmw_ppn;
    wire [31:0]  s0_translated_ppn;
    wire         s0_tlbr,s0_pif,s0_ppi;
    // search port 1 (for load/store)
    wire [18:0]  s1_vppn;
    wire         s1_va_bit12;
    wire [9 :0]  s1_asid;
    wire         s1_found;
    wire [3 :0]  s1_index;
    wire [19:0]  s1_ppn;
    wire [5 :0]  s1_ps;
    wire [1 :0]  s1_plv;
    wire [1 :0]  s1_mat;
    wire         s1_d;
    wire         s1_v;
    //exe related
    wire         s1_dmw0_hit,s1_dmw1_hit,s1_dmw_hit;
    wire         s1_tlbr,s1_pil,s1_pis,s1_ppi,s1_pme;
    wire [19:0]  s1_dmw_ppn;
    wire [19:0]  s1_translated_ppn;
    //dmw translate of s0(pre if)
    assign s0_dmw0_hit = (pre_if_vaddr[31:29] == dmw0_vseg) & ((plv == 2'b0) & dmw0_plv0 | (plv == 2'b11) & dmw0_plv3);
    assign s0_dmw1_hit = (pre_if_vaddr[31:29] == dmw1_vseg) & ((plv == 2'b0) & dmw1_plv0 | (plv == 2'b11) & dmw1_plv3);
    assign s0_dmw_ppn = {{3{s0_dmw0_hit}} & dmw0_pseg | {3{s0_dmw1_hit}} & dmw1_pseg ,pre_if_vaddr[28:12]};
    assign s0_dmw_hit = s0_dmw0_hit | s0_dmw1_hit;
    //tlb translate of s0(pre if)
    assign s0_vppn = pre_if_vaddr[31:13];
    assign s0_va_bit12 = pre_if_vaddr[12];
    //final s0
    assign s0_translated_ppn = s0_dmw_hit ? s0_dmw_ppn : s0_ppn;
    assign pre_if_addr = {{20{da}} & pre_if_vaddr[31:12] | {20{pg}} & s0_translated_ppn,pre_if_vaddr[11:0]};
    //handle s0 exception
    assign s0_tlbr = ~s0_found;
    assign s0_pif  = ~s0_v;
    assign s0_ppi  = (s0_plv == 2'b0) & (plv == 2'b11);
    assign s0_exc = {3{pg & ~s0_dmw_hit}} & {s0_pif,s0_ppi,s0_tlbr};//only in pg mode can generate problem
    //dmw translate of s1(pre if)
    assign s1_dmw0_hit = (exe_vaddr[31:29] == dmw0_vseg) & ((plv == 2'b0) & dmw0_plv0 | (plv == 2'b11) & dmw0_plv3);
    assign s1_dmw1_hit = (exe_vaddr[31:29] == dmw1_vseg) & ((plv == 2'b0) & dmw1_plv0 | (plv == 2'b11) & dmw1_plv3);
    assign s1_dmw_ppn = {{3{s1_dmw0_hit}} & dmw0_pseg | {3{s1_dmw1_hit}} & dmw1_pseg ,exe_vaddr[28:12]};
    assign s1_dmw_hit = s1_dmw0_hit | s1_dmw1_hit;
    //tlb translate of s1(pre if)
    assign s1_vppn = {19{exe_wr_rd}} & exe_vaddr[31:13] | {19{inst_tlbsrch}} & csr_s1_vppn | {19{inst_invtlb}} & inv_vppn;
    assign s1_va_bit12 = exe_wr_rd & exe_vaddr[12];
    assign s1_asid = {10{~inst_invtlb}} & asid | {10{inst_invtlb}} & inv_asid;
    //final s1
    assign s1_translated_ppn = s1_dmw_hit ? s1_dmw_ppn : s1_ppn;
    assign exe_addr = {{20{da}} & exe_vaddr[31:12] | {20{pg}} & s1_translated_ppn,exe_vaddr[11:0]};
    //handle s1 exception
    assign s1_tlbr = ~s1_found;
    assign s1_pil  = ~exe_wr & ~s1_v;
    assign s1_pis  =  exe_wr & ~s1_v;
    assign s1_ppi  = (s1_plv == 2'b0) & (plv == 2'b11);
    assign s1_pme  = exe_wr & ~s1_d;
    assign s1_exc = {5{pg & exe_wr_rd & ~s1_dmw_hit}} & {s1_pil,s1_pis,s1_pme,s1_ppi,s1_tlbr};
    //handle csr related
    //csr search
    assign csr_s1_found = s1_found;
    assign csr_s1_index = s1_index;
    assign csr_s1_ppn   = s1_ppn;
    assign csr_s1_ps    = s1_ps;
    assign csr_s1_plv   = s1_plv;
    assign csr_s1_mat   = s1_mat;
    assign csr_s1_d     = s1_d;
    assign csr_s1_v     = s1_v;
    //csr rd
    // assign csr_r_e      = r_e;
    // assign csr_r_vppn   = r_vppn;
    // assign csr_r_ps     = r_ps;
    // assign csr_r_asid   = r_asid;
    // assign csr_r_g      = r_g;
    // assign csr_r_ppn0   = r_ppn0;
    // assign csr_r_plv0   = r_plv0;
    // assign csr_r_mat0   = r_mat0;
    // assign csr_r_d0     = r_d0;
    // assign csr_r_v0     = r_v0;
    // assign csr_r_ppn1   = r_ppn1;
    // assign csr_r_plv1   = r_plv1;
    // assign csr_r_mat1   = r_mat1;
    // assign csr_r_d1     = r_d1;
    // assign csr_r_v1     = r_v1;
tlb mytlb(
    .clk(clk),
    // search port 0 (for fetch)
    .s0_vppn(s0_vppn),
    .s0_va_bit12(s0_va_bit12),
    .s0_asid(asid),
    .s0_found(s0_found),
    .s0_index(s0_index),
    .s0_ppn(s0_ppn),
    .s0_ps(s0_ps),
    .s0_plv(s0_plv),
    .s0_mat(s0_mat),
    .s0_d(s0_d),
    .s0_v(s0_v),
    // search port 1 (for load/store)
    .s1_vppn(s1_vppn),
    .s1_va_bit12(s1_va_bit12),
    .s1_asid(s1_asid),
    .s1_found(s1_found),
    .s1_index(s1_index),
    .s1_ppn(s1_ppn),
    .s1_ps(s1_ps),
    .s1_plv(s1_plv),
    .s1_mat(s1_mat),
    .s1_d(s1_d),
    .s1_v(s1_v),
    // invtlb opcode
    .invtlb_valid(inst_invtlb),
    .invtlb_op(invtlb_op),
    // write port
    .we(csr_tlb_we), //w(rite) e(nable)
    .w_index(csr_w_index),
    .w_e(csr_w_e),
    .w_vppn(csr_w_vppn),
    .w_ps(csr_w_ps),
    .w_asid(asid),
    .w_g(csr_w_g),
    .w_ppn0(csr_w_ppn0),
    .w_plv0(csr_w_plv0),
    .w_mat0(csr_w_mat0),
    .w_d0(csr_w_d0),
    .w_v0(csr_w_v0),
    .w_ppn1(csr_w_ppn1),
    .w_plv1(csr_w_plv1),
    .w_mat1(csr_w_mat1),
    .w_d1(csr_w_d1),
    .w_v1(csr_w_v1),

    // read port
    .r_index(csr_r_index),
    .r_e(csr_r_e),
    .r_vppn(csr_r_vppn),
    .r_ps(csr_r_ps),
    .r_asid(csr_r_asid),
    .r_g(csr_r_g),
    .r_ppn0(csr_r_ppn0),
    .r_plv0(csr_r_plv0),
    .r_mat0(csr_r_mat0),
    .r_d0(csr_r_d0),
    .r_v0(csr_r_v0),
    .r_ppn1(csr_r_ppn1),
    .r_plv1(csr_r_plv1),
    .r_mat1(csr_r_mat1),
    .r_d1(csr_r_d1),
    .r_v1(csr_r_v1)
);
endmodule