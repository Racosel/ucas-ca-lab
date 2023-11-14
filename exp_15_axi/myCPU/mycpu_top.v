module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire [3 :0] arid,
    output wire [31:0] araddr,
    output wire [7 :0] arlen,
    output wire [2 :0] arsize,
    output wire [1 :0] arburst,
    output wire [1 :0] arlock,
    output wire [3 :0] arcache,
    output wire [2 :0] arprot,
    output wire        arvalid,
    input  wire        arready,
                
    output wire [3 :0] rid,
    input  wire [31:0] rdata,
    input  wire [1 :0] cpu_rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,
               
    output wire [3 :0] awid,
    output wire [31:0] awaddr,
    output wire [7 :0] awlen,
    output wire [2 :0] awsize,
    output wire [1 :0] awburst,
    output wire [1 :0] awlock,
    output wire [3 :0] awcache,
    output wire [2 :0] awprot,
    output wire        awvalid,
    input  wire        awready,
    
    output wire [3 :0] wid,
    output wire [31:0] wdata,
    output wire [3 :0] wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,
    
    input  wire [3 :0] bid,
    input  wire [1 :0] bresp,
    input  wire        bvalid,
    output wire        bready,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    localparam  WAIT    = 1'b0,
                READY   = 1'b1;

    wire        inst_sram_wr;
    wire [1 :0] inst_sram_size;
    wire [3 :0] inst_sram_wstrb;
    wire [31:0] inst_sram_wdata;
    //useless information
    wire        inst_sram_req;
    wire [31:0] inst_sram_addr;
    reg         inst_sram_req_reg;
    reg  [31:0] inst_sram_addr_reg;
    reg         inst_sram_handled;
    wire        inst_sram_addr_ok;
    //stage 1
    wire        inst_sram_data_ok;
    wire [31:0] inst_sram_rdata;
    //stage 2

    wire        data_sram_req;
    wire        data_sram_wr;
    wire [ 1:0] data_sram_size;
    wire [ 3:0] data_sram_wstrb;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire        data_sram_addr_ok;
    //to handle information
    reg         data_sram_wr_reg;
    reg  [ 1:0] data_sram_size_reg;
    reg  [ 3:0] data_sram_wstrb_reg;
    reg  [31:0] data_sram_addr_reg;
    reg  [31:0] data_sram_wdata_reg;
    reg         data_sram_handled;
    //information needed
    wire        data_sram_data_ok;
    wire [31:0] data_sram_rdata;
    //next stage

    //machines for read and write
    reg         read_req_status;
    reg         read_data_status;
    reg         write_req_status;
    reg         write_data_status;
    //regs needed to support

    assign arid_choose = ~data_sram_handled;

    always @(posedge clk ) begin
        if(~resetn)
            read_req_status <= WAIT;
        else if(read_req_status == WAIT && (~inst_sram_handled | ~data_sram_handled))
            read_req_status <= READY;
        else if(read_req_status == READY && arready)
            read_req_status <= WAIT;
    end

    always @(posedge clk ) begin
        if(~resetn)
            read_data_status <= WAIT;
        else if(read_data_status == WAIT && read_req_status == READ && arready)
            read_data_status <= READY;
        else if(read_data_status == READY )
    end

    always @(posedge clk ) begin
        if(~resetn)
            inst_sram_handled <= 1;
        else if(inst_sram_addr_ok && inst_sram_req)
            inst_sram_handled <= 0;
        else if(inst_sram_data_ok)
            inst_sram_handled <= 1;
    end

    always @(posedge clk ) begin
        if(~resetn)
            data_sram_handled <= 1;
        else if(data_sram_addr_ok && data_sram_req)
            data_sram_handled <= 0;
        else if(data_sram_data_ok)
            data_sram_handled <= 1;
    end

    always @(posedge clk ) begin
        
    end

    always @(posedge clk ) begin
        
    end


    //fixed information
    assign arlen = 0;
    assign arburst = 0x1;
    assign arlock = 0;
    assign arcache = 0;
    assign arprot = 0;
    assign awid = 1;
    assign awlen = 0;
    assign awburst = 0x1;
    assign awlock = 0;
    assign awcache = 0
    assign awprot = 0;
    assign wlast = 1;
    //fixed information
endmodule

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
    wire [53:0] mem_rf_all;
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
    wire [6 :0] exe_exc_rf;
    wire [78:0] exe_csr_rf;//exe exc

    wire [6 :0] mem_exc_rf;
    wire [78:0] mem_csr_rf;//mem exc
    wire [31:0] mem_fault_vaddr;

    wire [31:0] csr_wr_mask;
    wire [31:0] csr_wr_value;
    wire [13:0] csr_wr_num;
    wire        csr_we;//wb exc
    wire [31:0] wb_fault_vaddr;
    wire        mem_exc_flush;
    wire [5 :0] wb_exc;
    assign exec_flush      = |wb_exc;
    assign cancel_exc_ertn = ertn_flush | exec_flush;
    assign inst_sram_wr = 1'b0;
    // assign cancel_exc_ertn_mem = cancel_exc_ertn | (|mem_exc_rf);
    IFstate ifstate(
        .clk(clk),
        .resetn(resetn),
        .if_valid_rf(if_valid),

        .inst_sram_req(inst_sram_req),
        .inst_sram_wr(inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr(inst_sram_addr),
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
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr_ok(data_sram_addr_ok),

        .cancel_exc_ertn(cancel_exc_ertn),
        .id_csr_rf(id_csr_rf),
        .id_timer_rf(id_timer_rf),
        .id_exc_rf(id_exc_rf),
        .timer(current_time),
        .mem_exc_flush(mem_exc_flush),
        .exe_exc_rf(exe_exc_rf),
        .exe_csr_rf(exe_csr_rf)
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

        // .data_sram_en(data_sram_en),
        // .data_sram_we(data_sram_wstrb),
        // .data_sram_addr(data_sram_addr),
        // .data_sram_wdata(data_sram_wdata),
        // .data_sram_rdata(data_sram_rdata),
        .data_sram_data_ok(data_sram_data_ok),
        .data_sram_rdata(data_sram_rdata),


        .cancel_exc_ertn(cancel_exc_ertn),
        .exe_csr_rf(exe_csr_rf),
        .exe_exc_rf(exe_exc_rf),
        .mem_exc_rf(mem_exc_rf),
        .mem_csr_rf(mem_csr_rf),
        .mem_fault_vaddr(mem_fault_vaddr),
        .mem_exc_flush(mem_exc_flush)
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
        .mem_fault_vaddr(mem_fault_vaddr),
        .csr_wr_mask(csr_wr_mask),
        .csr_wr_value(csr_wr_value),
        .csr_wr_num(csr_wr_num),
        .csr_we(csr_we),
        .wb_exc(wb_exc),
        .ertn_flush(ertn_flush),
        .wb_fault_vaddr(wb_fault_vaddr)
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
        .has_int(has_int)
    );

    cpu_timer localtimer(
        .clk(clk),
        .resetn(resetn),
        .time_now(current_time)
    );
endmodule