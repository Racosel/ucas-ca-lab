module mycpu_core(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input wire         inst_sram_addr_ok,
    input wire         inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [ 1:0] data_sram_size,
    output wire [ 3:0] data_sram_wstrb,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata, 
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    wire        id_allowin;
    wire        exe_allowin;
    wire        mem_allowin;
    wire        wb_allowin;

    wire        exe_ready_go;

    wire        if_to_id_valid;
    wire        id_to_exe_valid;
    wire        exe_to_mem_valid;
    wire        mem_to_wb_valid;

    wire [31:0] if_pc;
    wire [31:0] id_pc;
    wire [31:0] exe_pc;
    wire [31:0] mem_pc;

    wire [5 :0] id_rf_all;
    // wire [5 :0] exe_rf_all;
    wire [53:0] exe_fwd_all;
    wire [39:0] mem_rf_all;
    wire [52:0] wb_rf_all;

    wire        id_res_from_mem;
    wire        exe_res_from_mem;

    wire [7 :0] id_mem_all;
    wire [7 :0] exe_mem_all;
    
    wire [31:0] id_rkd_value;
    wire [31:0] exe_rkd_value;


    wire        br_taken_id;
    wire        br_taken_exe;
    wire [31:0] br_target_id;
    wire [31:0] br_target_exe;
    wire [5 :0] br_rf_all_id;
    // wire [31:0] id_to_if_pc_next;
    wire [31:0] if_inst;
    wire [79:0] id_alu_data_all;
    wire [31:0] exe_result;

    wire if_valid, id_valid, exe_valid, mem_valid, wb_valid;
    wire [31:0] ertn_pc;
    wire [31:0] exec_pc;
    wire        ertn_flush;
    wire        exec_flush;
    wire        cancel_exc_ertn_tlbflush;
    // wire        cancel_exc_ertn_tlbflush_mem;
    wire [3 :0] if_exc_rf;//if exc

    wire [31:0] csr_rd_value;
    wire        csr_re;
    wire [13:0] csr_rd_num;
    wire [8 :0] id_exc_rf;
    wire [79:0] id_csr_rf;//id exc
    wire [1 :0] id_timer_rf;
    wire        has_int;

    wire [63:0] current_time;
    wire [14:0] exe_exc_rf;
    wire [79:0] exe_csr_rf;//exe exc

    wire [14:0] mem_exc_rf;
    wire [79:0] mem_csr_rf;//mem exc
    wire [31:0] mem_fault_vaddr;

    wire [31:0] csr_wr_mask;
    wire [31:0] csr_wr_value;
    wire [13:0] csr_wr_num;
    wire        csr_we;//wb exc
    wire [31:0] wb_fault_vaddr;
    wire        mem_pipeline_block;
    wire [13:0] wb_exc;

    //tlb related
    wire        tlb_flush;//change to tlb
    wire [31:0] tlb_flush_addr;
    wire        tlbr_flush;
    wire [31:0] tlbrentry_pc;

    wire [9 :0] id_tlb_rf;

    wire [2 :0] exe_tlb_rf;
    wire        csr_tlbsrch,exe_invtlb;
    wire [9 :0] exe_invasid;
    wire [18:0] exe_invvppn;
    wire [4 :0] tlb_op;
    //tlb related wire
    wire [2 :0] mem_tlb_rf;
    wire        wb_tlbwr,wb_tlbfill,wb_tlbrd;
    wire [3 :0] tlb_inst;
    wire [31:0] pre_if_vaddr;
    wire [2 :0] s0_exc;
    wire [31:0] exe_vaddr;
    wire [4 :0] s1_exc;
    wire        exe_wr_rd;
    //csr-tlb wire
    wire [9 :0] asid;
    wire [1 :0] plv;
    wire        da;
    wire        pg;
    wire        dmw0_plv0;
    wire        dmw0_plv3;
    wire [2 :0] dmw0_vseg;
    wire [2 :0] dmw0_pseg;
    wire        dmw1_plv0;
    wire        dmw1_plv3;
    wire [2 :0] dmw1_vseg;
    wire [2 :0] dmw1_pseg;
    //tlbrsch
    wire [18:0] csr_s1_vppn;
    wire        csr_s1_found;
    wire [3 :0] csr_s1_index;
    wire [19:0] csr_s1_ppn;
    wire [5 :0] csr_s1_ps;
    wire [1 :0] csr_s1_plv;
    wire [1 :0] csr_s1_mat;
    wire        csr_s1_d;
    wire        csr_s1_v;
    //tlbwr
    wire        csr_tlb_we;
    wire [3 :0] csr_w_index;
    wire        csr_w_e;
    wire [18:0] csr_w_vppn;
    wire [ 5:0] csr_w_ps;
    wire [ 9:0] csr_w_asid;
    wire        csr_w_g;
    wire [19:0] csr_w_ppn0;
    wire [ 1:0] csr_w_plv0;
    wire [ 1:0] csr_w_mat0;
    wire        csr_w_d0;
    wire        csr_w_v0;
    wire [19:0] csr_w_ppn1;
    wire [ 1:0] csr_w_plv1;
    wire [ 1:0] csr_w_mat1;
    wire        csr_w_d1;
    wire        csr_w_v1;
    //tlbrd
    wire [3 :0] csr_r_index;
    wire        csr_r_e;
    wire [18:0] csr_r_vppn;
    wire [ 5:0] csr_r_ps;
    wire [ 9:0] csr_r_asid;
    wire        csr_r_g;
    wire [19:0] csr_r_ppn0;
    wire [ 1:0] csr_r_plv0;
    wire [ 1:0] csr_r_mat0;
    wire        csr_r_d0;
    wire        csr_r_v0;
    wire [19:0] csr_r_ppn1;
    wire [ 1:0] csr_r_plv1;
    wire [ 1:0] csr_r_mat1;
    wire        csr_r_d1;
    wire        csr_r_v1;


    assign exec_flush      = |wb_exc[13:1];
    assign tlbr_flush      = wb_exc[0];
    assign cancel_exc_ertn_tlbflush = ertn_flush | exec_flush | tlb_flush | tlbr_flush;
    assign tlb_inst = {exe_tlbsrch,wb_tlbwr,wb_tlbfill,wb_tlbrd};
    // assign cancel_exc_ertn_tlbflush_mem = cancel_exc_ertn_tlbflush | (|mem_exc_rf);

    mmu mmu_inst(
        .clk(clk),
    //user related tlb signals
        .pre_if_vaddr(pre_if_vaddr),
        .pre_if_addr(inst_sram_addr),
        .s0_exc(s0_exc),//{s0_pif,s0_ppi,s0_tlbr}
        .exe_vaddr(exe_vaddr),
        .exe_wr_rd(exe_wr_rd),
        .exe_wr(data_sram_wr),
        .exe_addr(data_sram_addr),
        .s1_exc(s1_exc),//{s1_pil,s1_pis,s1_pme,s1_ppi,s1_tlbr}
    //kernel related tlb signals
        .asid(asid),
        .plv(plv),
        .inst_tlbsrch(csr_tlbsrch),
        .inst_invtlb(exe_invtlb),
        .da(da),
        .pg(pg),
        .dmw0_plv0(dmw0_plv0),
        .dmw0_plv3(dmw0_plv3),
        .dmw0_vseg(dmw0_vseg),
        .dmw0_pseg(dmw0_pseg),
        .dmw1_plv0(dmw1_plv0),
        .dmw1_plv3(dmw1_plv3),
        .dmw1_vseg(dmw1_vseg),
        .dmw1_pseg(dmw1_pseg),
    //tlbrsch
        .csr_s1_vppn(csr_s1_vppn),
        .csr_s1_found(csr_s1_found),
        .csr_s1_index(csr_s1_index),
        .csr_s1_ppn(csr_s1_ppn),
        .csr_s1_ps(csr_s1_ps),
        .csr_s1_plv(csr_s1_plv),
        .csr_s1_mat(csr_s1_mat),
        .csr_s1_d(csr_s1_d),
        .csr_s1_v(csr_s1_v),
    //tlbwr
        .csr_tlb_we(csr_tlb_we),
        .csr_w_index(csr_w_index),
        .csr_w_e(csr_w_e),
        .csr_w_vppn(csr_w_vppn),
        .csr_w_ps(csr_w_ps),
        .csr_w_asid(csr_w_asid),
        .csr_w_g(csr_w_g),
        .csr_w_ppn0(csr_w_ppn0),
        .csr_w_plv0(csr_w_plv0),
        .csr_w_mat0(csr_w_mat0),
        .csr_w_d0(csr_w_d0),
        .csr_w_v0(csr_w_v0),
        .csr_w_ppn1(csr_w_ppn1),
        .csr_w_plv1(csr_w_plv1),
        .csr_w_mat1(csr_w_mat1),
        .csr_w_d1(csr_w_d1),
        .csr_w_v1(csr_w_v1),
    //tlbrd
        .csr_r_index(csr_r_index),
        .csr_r_e(csr_r_e),
        .csr_r_vppn(csr_r_vppn),
        .csr_r_ps(csr_r_ps),
        .csr_r_asid(csr_r_asid),
        .csr_r_g(csr_r_g),
        .csr_r_ppn0(csr_r_ppn0),
        .csr_r_plv0(csr_r_plv0),
        .csr_r_mat0(csr_r_mat0),
        .csr_r_d0(csr_r_d0),
        .csr_r_v0(csr_r_v0),
        .csr_r_ppn1(csr_r_ppn1),
        .csr_r_plv1(csr_r_plv1),
        .csr_r_mat1(csr_r_mat1),
        .csr_r_d1(csr_r_d1),
        .csr_r_v1(csr_r_v1),
    //invtlb signals
        .invtlb_op(tlb_op),
        .inv_vppn(exe_invvppn),
        .inv_asid(exe_invasid)
    );

    IFstate ifstate(
        .clk(clk),
        .resetn(resetn),
        .if_valid_rf(if_valid),

        .inst_sram_req(inst_sram_req),
        .inst_sram_wr(inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        // .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),
        .inst_sram_rdata(inst_sram_rdata),
        
        .id_allowin(id_allowin),
        .br_taken_id(br_taken_id),
        .br_taken_exe(br_taken_exe),
        .br_target_id(br_target_id),
        .br_target_exe(br_target_exe),
        // .id_to_if_pc_next(id_to_if_pc_next),
        .if_to_id_valid(if_to_id_valid),
        .if_inst(if_inst),
        .if_pc(if_pc),
        .ertn_pc(ertn_pc),
        .exec_pc(exec_pc),
        .tlbrentry_pc(tlbrentry_pc),
        .ertn_flush(ertn_flush),
        .exec_flush(exec_flush),
        .tlbr_flush(tlbr_flush),
        .if_exc_rf(if_exc_rf),

        //tlb rf
        .tlb_flush(tlb_flush),
        .tlb_flush_addr(tlb_flush_addr),
        //tlb translate
        .pre_if_vaddr(pre_if_vaddr),
        .s0_exc(s0_exc)
    );

    IDstate idstate(
        .clk(clk),
        .resetn(resetn),
        .id_valid(id_valid),

        .id_allowin(id_allowin),
        .br_taken_id(br_taken_id),
        .br_taken_exe(br_taken_exe),
        .br_target_id(br_target_id),
        .br_rf_all_id(br_rf_all_id),
        // .id_to_if_pc_next(id_to_if_pc_next),
        .if_to_id_valid(if_to_id_valid),
        .if_inst(if_inst),
        .if_pc(if_pc),

        .exe_allowin(exe_allowin),
        .id_rf_all(id_rf_all),
        .id_to_exe_valid(id_to_exe_valid),
        .id_pc(id_pc),
        .id_alu_data_all(id_alu_data_all),
        .id_res_from_mem(id_res_from_mem),
        .id_mem_all(id_mem_all),
        .id_rkd_value(id_rkd_value),

        .exe_fwd_all(exe_fwd_all),
        .mem_fwd_all(mem_rf_all),
        .wb_fwd_all(wb_rf_all),

        .exe_valid(exe_valid),
        .mem_valid(mem_valid),
        .wb_valid(wb_valid),

        .cancel_exc_ertn_tlbflush(cancel_exc_ertn_tlbflush),
        .if_exc_rf(if_exc_rf),
        .has_int(has_int),
        .id_csr_rf(id_csr_rf),
        .id_exc_rf(id_exc_rf),
        .id_timer_rf(id_timer_rf),

        //tlb rf
        .id_tlb_rf(id_tlb_rf)
    );


    EXEstate exestate(
        .clk(clk),
        .resetn(resetn),
        .exe_valid(exe_valid),
        
        .exe_allowin(exe_allowin),
        .exe_ready_go(exe_ready_go),
        .id_rf_all(id_rf_all),
        .id_to_exe_valid(id_to_exe_valid),
        .id_pc(id_pc),
        .id_alu_data_all(id_alu_data_all),
        .id_res_from_mem(id_res_from_mem),
        .id_mem_all(id_mem_all),
        .id_rkd_value(id_rkd_value),
        .br_target_id(br_target_id),
        .br_taken_exe(br_taken_exe),
        .br_target_exe(br_target_exe),
        .br_rf_all_id(br_rf_all_id),

        .mem_allowin(mem_allowin),
        .exe_fwd_all(exe_fwd_all),
        .exe_to_mem_valid(exe_to_mem_valid),
        .exe_pc(exe_pc),
        .exe_result(exe_result),
        .exe_res_from_mem(exe_res_from_mem),
        .exe_mem_all(exe_mem_all),
        .exe_rkd_value(exe_rkd_value),

        .data_sram_req(data_sram_req),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        // .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr_ok(data_sram_addr_ok),

        .cancel_exc_ertn_tlbflush(cancel_exc_ertn_tlbflush),
        .id_csr_rf(id_csr_rf),
        .id_timer_rf(id_timer_rf),
        .id_exc_rf(id_exc_rf),
        .timer(current_time),
        .mem_pipeline_block(mem_pipeline_block),
        .exe_exc_rf(exe_exc_rf),
        .exe_csr_rf(exe_csr_rf),

    //tlb rf
        .id_tlb_rf(id_tlb_rf),
        .exe_tlb_rf(exe_tlb_rf),
        .exe_tlbsrch(exe_tlbsrch),
        .exe_invtlb(exe_invtlb),
        .exe_invasid(exe_invasid),
        .exe_invvppn(exe_invvppn),
        .tlb_op(tlb_op),
        .exe_vaddr(exe_vaddr),
        .s1_exc(s1_exc),
        .exe_wr_rd(exe_wr_rd)
    );

    MEMstate memstate(
        .clk(clk),
        .resetn(resetn),
        .mem_valid(mem_valid),

        .mem_allowin(mem_allowin),
        .exe_ready_go(exe_ready_go),
        .exe_rf_all(exe_fwd_all[37:32]),
        .exe_to_mem_valid(exe_to_mem_valid),
        .exe_pc(exe_pc),
        .exe_result(exe_result),
        .exe_res_from_mem(exe_res_from_mem),
        .exe_mem_all(exe_mem_all),
        .exe_rkd_value(exe_rkd_value),

        .wb_allowin(wb_allowin),
        .mem_rf_all(mem_rf_all),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_pc(mem_pc),

        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata(data_sram_rdata),


        .cancel_exc_ertn_tlbflush(cancel_exc_ertn_tlbflush),
        .exe_csr_rf(exe_csr_rf),
        .exe_exc_rf(exe_exc_rf),
        .mem_exc_rf(mem_exc_rf),
        .mem_csr_rf(mem_csr_rf),
        .mem_fault_vaddr(mem_fault_vaddr),
        .mem_pipeline_block(mem_pipeline_block),

    //tlb rf
        .exe_tlb_rf(exe_tlb_rf),
        .mem_tlb_rf(mem_tlb_rf)
    ) ;

    WBstate wbstate(
        .clk(clk),
        .resetn(resetn),
        .wb_valid(wb_valid),

        .wb_allowin(wb_allowin),
        .mem_rf_all(mem_rf_all),
        .mem_to_wb_valid(mem_to_wb_valid),
        .mem_pc(mem_pc),

        .debug_wb_pc(debug_wb_pc),
        .debug_wb_rf_we(debug_wb_rf_we),
        .debug_wb_rf_wnum(debug_wb_rf_wnum),
        .debug_wb_rf_wdata(debug_wb_rf_wdata),

        .wb_rf_all(wb_rf_all),

        .cancel_exc_ertn_tlbflush(cancel_exc_ertn_tlbflush),
        .mem_csr_rf(mem_csr_rf),
        .mem_exc_rf(mem_exc_rf),
        .mem_fault_vaddr(mem_fault_vaddr),
        .csr_wr_mask(csr_wr_mask),
        .csr_wr_value(csr_wr_value),
        .csr_wr_num(csr_wr_num),
        .csr_rd_value(csr_rd_value),
        .csr_we(csr_we),
        .csr_re(csr_re),
        .csr_rd_num(csr_rd_num),
        .wb_exc(wb_exc),
        .ertn_flush(ertn_flush),
        .wb_fault_vaddr(wb_fault_vaddr),

        .mem_tlb_rf(mem_tlb_rf),//{inst_tlbwr,inst_tlbfill,inst_tlbrd}
        .wb_tlbwr(wb_tlbwr),
        .wb_tlbfill(wb_tlbfill),
        .wb_tlbrd(wb_tlbrd),
        .tlb_flush(tlb_flush),
        .tlb_flush_addr(tlb_flush_addr)
    );

    csr csr_reg(
        .clk(clk),
        .exc(wb_exc),
        .ertn_flush(ertn_flush),
        .resetn(resetn),
        .csr_re(csr_re),
        .csr_wr_num(csr_wr_num),
        .csr_rd_num(csr_rd_num),
        .csr_we(csr_we),
        .csr_wr_mask(csr_wr_mask),
        .csr_wr_value(csr_wr_value),
        .wb_pc(debug_wb_pc),
        .wb_fault_vaddr(wb_fault_vaddr),
        .csr_rd_value(csr_rd_value),
        .csr_eentry_pc(exec_pc),
        .csr_eertn_pc(ertn_pc),
        .csr_tlbrentry_pc(tlbrentry_pc),
        .has_int(has_int),
    //tlb rf
        .tlb_inst(tlb_inst),
    //tlb related control
        .asid(asid),
        .plv(plv),
        .csr_tlbsrch(csr_tlbsrch),
        .da(da),
        .pg(pg),
        .csr_dmw0_plv0(dmw0_plv0),
        .csr_dmw0_plv3(dmw0_plv3),
        .csr_dmw0_vseg(dmw0_vseg),
        .csr_dmw0_pseg(dmw0_pseg),
        .csr_dmw1_plv0(dmw1_plv0),
        .csr_dmw1_plv3(dmw1_plv3),
        .csr_dmw1_vseg(dmw1_vseg),
        .csr_dmw1_pseg(dmw1_pseg),
    //tlb wire
    //search port1
        .s1_vppn(csr_s1_vppn),
        .s1_found(csr_s1_found),
        .s1_index(csr_s1_index),
        .s1_ppn(csr_s1_ppn),
        .s1_ps(csr_s1_ps),
        .s1_plv(csr_s1_plv),
        .s1_mat(csr_s1_mat),
        .s1_d(csr_s1_d),
        .s1_v(csr_s1_v),
    //write port
        .tlb_we(csr_tlb_we),
        .w_index(csr_w_index),
        .w_e(csr_w_e),
        .w_vppn(csr_w_vppn),
        .w_ps(csr_w_ps),
        .w_asid(csr_w_asid),
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

    cpu_timer localtimer(
        .clk(clk),
        .resetn(resetn),
        .time_now(current_time)
    );
endmodule