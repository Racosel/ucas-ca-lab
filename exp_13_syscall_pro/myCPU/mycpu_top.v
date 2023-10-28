module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en,
    output wire [ 3:0] inst_sram_we,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
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
    wire [52:0] mem_rf_all;
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
    wire [80:0] id_alu_data_all;
    wire [31:0] exe_result;

    wire if_valid, id_valid, exe_valid, mem_valid, wb_valid;
    wire [31:0] ertn_pc;
    wire [31:0] exec_pc;
    wire        ertn_flush;
    wire        exec_flush;
    wire        cancel_exc_ertn;
    // wire        cancel_exc_ertn_mem;
    wire        if_exc_rf;//if exc

    wire [31:0] csr_rd_value;
    wire        csr_re;
    wire [13:0] csr_rd_num;
    wire [5 :0] id_exc_rf;
    wire [78:0] id_csr_rf;//id exc
    wire [1 :0] id_timer_rf;
    wire        has_int;

    wire [63:0] current_time;
    wire [5 :0] exe_exc_rf;
    wire [78:0] exe_csr_rf;//exe exc

    wire [6 :0] mem_exc_rf;
    wire [78:0] mem_csr_rf;//mem exc

    wire [31:0] csr_wr_mask;
    wire [31:0] csr_wr_value;
    wire [13:0] csr_wr_num;
    wire        csr_we;//wb exc

    wire [5 :0] wb_exc;
    assign exec_flush      = |wb_exc;
    assign cancel_exc_ertn = ertn_flush | exec_flush;
    // assign cancel_exc_ertn_mem = cancel_exc_ertn | (|mem_exc_rf);
    IFstate ifstate(
        .clk(clk),
        .resetn(resetn),
        .if_valid(if_valid),

        .inst_sram_en(inst_sram_en),
        .inst_sram_we(inst_sram_we),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
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
        .ertn_flush(ertn_flush),
        .exec_flush(exec_flush),
        .if_exc_rf(if_exc_rf)
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

        .cancel_exc_ertn(cancel_exc_ertn),
        .csr_rd_value(csr_rd_value),
        .if_exc_rf(if_exc_rf),
        .has_int(has_int),
        .csr_re(csr_re),
        .csr_rd_num(csr_rd_num),
        .id_csr_rf(id_csr_rf),
        .id_exc_rf(id_exc_rf),
        .id_timer_rf(id_timer_rf)
    );


    EXEstate exestate(
        .clk(clk),
        .resetn(resetn),
        .exe_valid(exe_valid),
        
        .exe_allowin(exe_allowin),
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
        .cancel_exc_ertn(cancel_exc_ertn),
        .id_csr_rf(id_csr_rf),
        .id_timer_rf(id_timer_rf),
        .id_exc_rf(id_exc_rf),
        .timer(current_time),
        .exe_exc_rf(exe_exc_rf),
        .exe_csr_rf(exe_csr_rf)
    );

    MEMstate memstate(
        .clk(clk),
        .resetn(resetn),
        .mem_valid(mem_valid),

        .mem_allowin(mem_allowin),
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

        .data_sram_en(data_sram_en),
        .data_sram_we(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_rdata(data_sram_rdata),
        .cancel_exc_ertn(cancel_exc_ertn),
        .exe_csr_rf(exe_csr_rf),
        .exe_exc_rf(exe_exc_rf),
        .mem_exc_rf(mem_exc_rf),
        .mem_csr_rf(mem_csr_rf)
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

        .cancel_exc_ertn(cancel_exc_ertn),
        .mem_csr_rf(mem_csr_rf),
        .mem_exc_rf(mem_exc_rf),
        .csr_wr_mask(csr_wr_mask),
        .csr_wr_value(csr_wr_value),
        .csr_wr_num(csr_wr_num),
        .csr_we(csr_we),
        .wb_exc(wb_exc),
        .ertn_flush(ertn_flush)
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
        .csr_rd_value(csr_rd_value),
        .csr_eentry_pc(exec_pc),
        .csr_eertn_pc(ertn_pc),
        .has_int(has_int)
    );

    cpu_timer localtimer(
        .clk(clk),
        .resetn(resetn),
        .time_now(current_time)
    );
endmodule