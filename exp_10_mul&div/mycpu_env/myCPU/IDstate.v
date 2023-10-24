module IDstate(
    input             clk,
    input             resetn,
    output reg        id_valid,
    // ifstate <-> idstate
    output            id_allowin,
    output            br_taken_id,
    output      [5:0] br_rf_all_id,
    output     [31:0] br_target_id,
    input             if_to_id_valid,
    input      [31:0] if_inst,
    input      [31:0] if_pc,
    // idstate <-> exestate
    // data:    alu(alu_src1, alu_src2, alu_op)
    // control: res_from_mem, mem_we
    output reg [31:0] id_pc,
    input             exe_allowin,
    input             br_taken_exe,
    output     [5 :0] id_rf_all, // {id_rf_we, id_rf_waddr[4:0]}
    output            id_to_exe_valid,   
    output     [79:0] id_alu_data_all, 
    // {calc_h,calc_s,alu_op[14:0] revised in exp10, alu_src1[31:0], alu_src2[31:0]}
    output            id_res_from_mem, // res_from_mem
    output      [7:0] id_mem_all,// should be revised in exp11 for st.h/b
    //{mem_we, ld_b, ld_h, ld_w, ld_ue, st_b, st_h, st_w}
    output     [31:0] id_rkd_value,
    // idstate <-> wbstate
    // input      [5 :0] exe_rf_all, // {exe_rf_we, exe_rf_waddr}
    input      [38:0] exe_fwd_all, // {exe_res_from_mem, exe_rf_we, exe_rf_waddr, exe_alu_result}
    input      [37:0] mem_fwd_all, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    input      [37:0] wb_fwd_all,  // {wb_rf_we, wb_rf_waddr, wb_rf_wdata}

    input             exe_valid,
    input             mem_valid,
    input             wb_valid
);

    wire        id_ready_go;
    // reg         id_valid;
    reg  [31:0] inst;

    wire        ld_ue;//load should be unsigned extended
    wire        ld_w;
    wire        ld_h;
    wire        ld_b;
    wire        st_w;
    wire        st_h;
    wire        st_b;
    wire        calc_h;//the calculation should be done in unsigned
    wire        calc_s;//use the high part of mul or high part of div(part of mod)
    wire [13:0] alu_op;//extended in exp10
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire        src1_is_pc;
    wire        src2_is_imm;
    wire        src2_is_4;
    wire        res_from_mem;
    wire        dst_is_r1;
    wire        gr_we;
    wire        mem_we;
    wire        src_reg_is_rd;
    wire [4: 0] dest;
    wire [31:0] rj_value;
    wire [31:0] rkd_value;
    wire [31:0] imm;
    wire [31:0] br_offs;
    wire [31:0] jirl_offs;

    wire [31:0] pc_seq;
    wire [31:0] pc_next;

    wire [ 5:0] op_31_26;
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] rd;
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] i12;
    wire [19:0] i20;
    wire [15:0] i16;
    wire [25:0] i26;

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    wire        inst_add_w;
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_slti;
    wire        inst_sltui;
    wire        inst_andi;
    wire        inst_ori;
    wire        inst_xori;
    wire        inst_sll_w;
    wire        inst_srl_w;
    wire        inst_sra_w;

    wire        inst_mul_w;
    wire        inst_mulh_w;
    wire        inst_mulh_wu;
    wire        inst_div_w;
    wire        inst_mod_w;
    wire        inst_div_wu;
    wire        inst_mod_wu;

    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_ld_b;
    wire        inst_ld_h;
    wire        inst_ld_bu;
    wire        inst_ld_hu;
    wire        inst_st_b;
    wire        inst_st_h;

    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_blt;
    wire        inst_bge;
    wire        inst_bltu;
    wire        inst_bgeu;
    wire        inst_beq;
    wire        inst_bne;

    wire        inst_pcaddu12i;
    wire        inst_lu12i_w;

    wire        need_ui5;
    wire        need_si12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        need_ui12;

    wire        conflict_r1;
    wire        conflict_r2;
    wire [ 4:0] rf_raddr1;
    wire [31:0] rf_rdata1;
    wire [ 4:0] rf_raddr2;
    wire [31:0] rf_rdata2;

    wire        id_rf_we;
    wire [ 4:0] id_rf_waddr;

    wire        exe_res_from_mem;
    wire        exe_rf_we;
    wire [ 4:0] exe_rf_waddr;
    wire [31:0] exe_alu_result;
    
    wire        mem_rf_we;
    wire [ 4:0] mem_rf_waddr;
    wire [31:0] mem_rf_wdata;

    wire        wb_rf_we;
    wire [ 4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;

    assign {exe_res_from_mem, exe_rf_we, exe_rf_waddr, exe_alu_result} = exe_fwd_all;
    assign {mem_rf_we, mem_rf_waddr, mem_rf_wdata}                     = mem_fwd_all;
    assign {wb_rf_we, wb_rf_waddr, wb_rf_wdata}                        = wb_fwd_all;

    // valid signals


    wire need_raddr1, need_raddr2;
    // wire raw_exe_id, raw_mem_id, raw_wb_id;
    wire raw_exe_ldw;
    wire raw_exe_r1, raw_exe_r2, raw_mem_r1, raw_mem_r2, raw_wb_r1, raw_wb_r2;
    
    assign need_raddr1 = ~(inst_lu12i_w | inst_bl | inst_b);
    assign need_raddr2 = need_raddr1 & ~(inst_addi_w | inst_ld_w | inst_jirl | inst_slli_w | inst_srai_w 
                           | inst_srli_w | inst_slti | inst_sltui | inst_andi | inst_ori | inst_xori);
    // assign raw_exe_id  = exe_valid & exe_rf_we & ((need_raddr1 & (|rf_raddr1) & exe_rf_waddr == rf_raddr1) | (need_raddr2 & (|rf_raddr2) & exe_rf_waddr == rf_raddr2));
    // assign raw_mem_id  = mem_valid & mem_rf_we & ((need_raddr1 & (|rf_raddr1) & mem_rf_waddr == rf_raddr1) | (need_raddr2 & (|rf_raddr2) & mem_rf_waddr == rf_raddr2));
    // assign raw_wb_id   = wb_valid  & wb_rf_we  & ((need_raddr1 & (|rf_raddr1) & wb_rf_waddr  == rf_raddr1) | (need_raddr2 & (|rf_raddr2) & wb_rf_waddr  == rf_raddr2));
    assign raw_exe_ldw = exe_valid & exe_rf_we & exe_res_from_mem & (((|rf_raddr1) & exe_rf_waddr == rf_raddr1) | ((|rf_raddr2) & exe_rf_waddr == rf_raddr2));
    assign raw_exe_r1  = exe_valid & exe_rf_we & (need_raddr1 & (|rf_raddr1) & exe_rf_waddr == rf_raddr1);
    assign raw_exe_r2  = exe_valid & exe_rf_we & (need_raddr2 & (|rf_raddr2) & exe_rf_waddr == rf_raddr2);
    assign raw_mem_r1  = mem_valid & mem_rf_we & (need_raddr1 & (|rf_raddr1) & mem_rf_waddr == rf_raddr1);
    assign raw_mem_r2  = mem_valid & mem_rf_we & (need_raddr2 & (|rf_raddr2) & mem_rf_waddr == rf_raddr2);
    assign raw_wb_r1   = wb_valid  & wb_rf_we  & (need_raddr1 & (|rf_raddr1) & wb_rf_waddr  == rf_raddr1);
    assign raw_wb_r2   = wb_valid  & wb_rf_we  & (need_raddr2 & (|rf_raddr2) & wb_rf_waddr  == rf_raddr2);

    // assign raw_exe_id  = raw_exe_r1 | raw_exe_r2;
    // assign raw_mem_id  = raw_mem_r1 | raw_mem_r2;
    // assign raw_wb_id   = raw_wb_r1  | raw_wb_r2;

    // assign id_ready_go = ~raw_exe_id & ~raw_mem_id & ~raw_wb_id;
    assign id_ready_go = ~raw_exe_ldw;
    assign id_allowin  = ~id_valid & id_ready_go | id_ready_go & exe_allowin;
    assign id_to_exe_valid = id_valid & id_ready_go;
    assign ld_b   = inst_ld_b | inst_ld_bu;
    assign ld_h   = inst_ld_h | inst_ld_hu;
    assign ld_w   = inst_ld_w;
    assign ld_ue  = inst_ld_bu | inst_ld_hu;
    assign st_b   = inst_st_b;
    assign st_h   = inst_st_h;
    assign st_w   = inst_st_w;
    assign calc_h = inst_mulh_w | inst_mulh_wu | inst_div_w | inst_div_wu;
    assign calc_s = inst_mulh_w | inst_mul_w | inst_mod_w | inst_div_w;


    always @(posedge clk) begin
        if(~resetn)
            id_valid <= 1'b0;
        else if(br_taken_id | br_taken_exe)
            id_valid <= 1'b0;
        else if(id_allowin)
            id_valid <= if_to_id_valid;
    end

    // pc & inst    
    always @(posedge clk) begin
        if(if_to_id_valid & id_allowin) begin
            id_pc <= if_pc;
        end
    end
    always @(posedge clk) begin
        if(if_to_id_valid & id_allowin) begin
            inst  <= if_inst;
        end
    end

    // reg raw_wb_id_reg;
    // always @(posedge clk) begin
    //     raw_wb_id_reg <= raw_wb_id;
    // end

    assign br_taken_id = (
                    inst_jirl
                    || inst_bl
                    || inst_b
                    ) && id_valid && ~raw_exe_ldw;
    assign br_rf_all_id = {inst_beq, inst_bne, inst_blt, inst_bltu, inst_bge, inst_bgeu};
    // (id_valid | raw_exe_id | raw_mem_id | raw_wb_id | raw_wb_id_reg)
    assign br_target_id = (inst_beq || inst_bne || inst_bl || inst_b) ? (id_pc + br_offs) :
                                                    /*inst_jirl*/ (rj_value + jirl_offs);
    
    /* decoding */
    assign op_31_26  = inst[31:26];
    assign op_25_22  = inst[25:22];
    assign op_21_20  = inst[21:20];
    assign op_19_15  = inst[19:15];

    assign rd   = inst[ 4: 0];
    assign rj   = inst[ 9: 5];
    assign rk   = inst[14:10];

    assign i12  = inst[21:10];
    assign i20  = inst[24: 5];
    assign i16  = inst[25:10];
    assign i26  = {inst[ 9: 0], inst[25:10]};

    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

    assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];

    assign inst_slti      = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui     = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    assign inst_andi      = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori       = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori      = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    assign inst_sll_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra_w     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
    assign inst_pcaddu12i = op_31_26_d[6'h07] & ~inst[25];

    assign inst_mul_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
    assign inst_mulh_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
    assign inst_mulh_wu = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
    assign inst_div_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
    assign inst_mod_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
    assign inst_div_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
    assign inst_mod_wu  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];

    assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
    assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
    assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
    assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
    assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
    assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];


    assign inst_jirl    = op_31_26_d[6'h13];
    assign inst_b       = op_31_26_d[6'h14];
    assign inst_bl      = op_31_26_d[6'h15];
    assign inst_beq     = op_31_26_d[6'h16];
    assign inst_bne     = op_31_26_d[6'h17];
    assign inst_lu12i_w = op_31_26_d[6'h05] & ~inst[25];

    assign inst_blt     = op_31_26_d[6'h18];
    assign inst_bge     = op_31_26_d[6'h19];
    assign inst_bltu    = op_31_26_d[6'h1a];
    assign inst_bgeu    = op_31_26_d[6'h1b];


    assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                        | inst_jirl | inst_bl | inst_pcaddu12i | inst_ld_b
                        | inst_ld_bu | inst_ld_h | inst_ld_hu | inst_st_b | inst_st_h;
    assign alu_op[ 1] = inst_sub_w;
    assign alu_op[ 2] = inst_slt | inst_slti | inst_blt | inst_bge;
    assign alu_op[ 3] = inst_sltu | inst_sltui | inst_bltu | inst_bgeu;
    assign alu_op[ 4] = inst_and | inst_andi;
    assign alu_op[ 5] = inst_nor;
    assign alu_op[ 6] = inst_or | inst_ori;
    assign alu_op[ 7] = inst_xor | inst_xori;
    assign alu_op[ 8] = inst_slli_w | inst_sll_w;
    assign alu_op[ 9] = inst_srli_w | inst_srl_w;
    assign alu_op[10] = inst_srai_w | inst_sra_w;
    assign alu_op[11] = inst_lu12i_w;
    assign alu_op[12] = inst_mul_w | inst_mulh_w | inst_mulh_wu;
    assign alu_op[13] = inst_div_w | inst_div_wu | inst_mod_w | inst_mod_wu;;//mod uses the same op as div and

    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_ui12  =  inst_andi | inst_ori | inst_andi | inst_xori;
    assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti| inst_sltui ;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne;//| inst_blt | inst_bltu | inst_bge | inst_bgeu;
    assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
    assign need_si26  =  inst_b | inst_bl;
    assign src2_is_4  =  inst_jirl | inst_bl;

    assign imm = {32{src2_is_4}} & 32'h4 |
                 {32{need_si20}} & {i20[19:0], 12'b0} |
                 {32{need_si12 | need_ui5}} & {{20{i12[11]}}, i12[11:0]} |
                 {32{need_ui12}} & {20'b0,i12[11:0]};

    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0}:
                                 {{14{i16[15]}}, i16[15:0], 2'b0};

    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

    assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bltu | inst_bge | inst_bgeu | inst_st_b | inst_st_h | inst_st_w;

    assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;

    assign src2_is_imm =inst_slli_w |
                        inst_srli_w |
                        inst_srai_w |
                        inst_addi_w |
                        inst_ld_b   |
                        inst_ld_bu  |
                        inst_ld_h   |
                        inst_ld_hu  |
                        inst_ld_w   |
                        inst_st_b   |
                        inst_st_h   |
                        inst_st_w   |
                        inst_lu12i_w|
                        inst_jirl   |
                        inst_bl     |
                        inst_slti   |
                        inst_sltui  |
                        inst_andi   |
                        inst_ori    |
                        inst_xori   |
                        inst_pcaddu12i;
    assign alu_src1 = src1_is_pc  ? id_pc[31:0] : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;

    assign res_from_mem = inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu;
    assign dst_is_r1    = inst_bl;
    assign gr_we        = ~inst_beq & ~inst_bne & ~inst_b & ~inst_st_w & ~inst_blt & ~inst_bltu & ~inst_bge & ~inst_bgeu;// serve as rf_we
    assign mem_we       = inst_st_w | inst_st_b | inst_st_h;   
    assign dest         = dst_is_r1 ? 5'd1 : rd;

    /* regfile read */
    assign rf_raddr1   = rj;
    assign rf_raddr2   = src_reg_is_rd ? rd : rk;
    assign id_rf_we    = gr_we; 
    assign id_rf_waddr = dest; 
    assign id_rf_all   = {id_rf_we, id_rf_waddr};
    
    regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (wb_rf_we   ),
    .waddr  (wb_rf_waddr),
    .wdata  (wb_rf_wdata)
    );
    // assign rj_value  = rf_rdata1;
    // assign rkd_value = rf_rdata2;
    assign rj_value  = raw_exe_r1 ? exe_alu_result
                     : raw_mem_r1 ? mem_rf_wdata
                     : raw_wb_r1  ? wb_rf_wdata
                     : rf_rdata1;

    assign rkd_value = raw_exe_r2 ? exe_alu_result
                     : raw_mem_r2 ? mem_rf_wdata
                     : raw_wb_r2  ? wb_rf_wdata
                     : rf_rdata2;

    assign id_alu_data_all = {calc_h, calc_s, alu_op, alu_src1, alu_src2};
    assign id_mem_all = {mem_we, ld_b, ld_h, ld_w, ld_ue, st_b, st_h, st_w};
    assign id_rkd_value = rkd_value;
    assign id_res_from_mem = res_from_mem;


endmodule