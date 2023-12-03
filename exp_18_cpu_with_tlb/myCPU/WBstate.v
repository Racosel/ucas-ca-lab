module WBstate(
    input              clk,
    input              resetn,
    output reg         wb_valid,
    // memstate <-> wbstate
    output             wb_allowin,
    input       [53:0] mem_rf_all, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata_reg}
    input              mem_to_wb_valid,
    input       [31:0] mem_pc,    
    // debug info
    output      [31:0] debug_wb_pc,
    output      [ 3:0] debug_wb_rf_we,
    output      [ 4:0] debug_wb_rf_wnum,
    output      [31:0] debug_wb_rf_wdata,
    // idstate <-> wbstate
    output      [52:0] wb_rf_all,// {rf_we, rf_waddr, rf_wdata_reg}
    input              cancel_exc_ertn_tlbflush,//canceled by exception or ereturn
    input       [79:0] mem_csr_rf,//{wb_res_from_csr,csr_wr,csr_wr_num,csr_mask,csr_wr_value}
    input       [6 :0] mem_exc_rf,//{syscall,ertn}
    //csr wr port
    output      [31:0] csr_wr_mask,
    output      [31:0] csr_wr_value,
    output      [13:0] csr_wr_num,
    output             csr_we,
    //csr rd port
    input       [31:0] csr_rd_value,
    output             csr_re,//to csr
    output     [13:0]  csr_rd_num,
    //csr exception related
    input       [31:0] mem_fault_vaddr,
    output      [5 :0] wb_exc,//for extension
    output             ertn_flush,
    output      [31:0] wb_fault_vaddr,
    //tlb related
    input       [2 :0] mem_tlb_rf,//{inst_tlbwr,inst_tlbfill,inst_tlbrd}
    output             wb_tlbwr,
    output             wb_tlbfill,
    output             wb_tlbrd,
    output             tlb_flush,
    output      [31:0] tlb_flush_addr
);

localparam  CSR_CRMD                = 14'h0,
            CSR_ASID                = 14'h18,
            CSR_DMW0                = 14'h180,
            CSR_DMW1                = 14'h181;

    wire        wb_ready_go;
    wire [31:0] rf_wdata;
    // reg         wb_valid;
    
    reg  [31:0] wb_pc;
    reg  [31:0] rf_wdata_reg;
    reg  [4 :0] rf_waddr;
    reg         rf_we;
    reg  [79:0] wb_csr_rf_reg;
    reg  [6 :0] wb_exc_rf_reg;
    reg  [31:0] fault_vaddr_reg;
    // wire        wb_res_from_csr;
    wire        wb_csr_wr;
    wire        wb_csr_rd;
    wire        truly_we;
    //tlb rf and reflush
    reg  [2 :0] wb_tlb_rf_reg;
    wire        inst_tlbfill,inst_tlbwr,inst_tlbrd;
    wire        csr_wr_flush;
    /* valid signals */
    assign wb_ready_go = 1'b1;
    assign wb_allowin  = ~wb_valid | wb_ready_go | cancel_exc_ertn_tlbflush;     
    always @(posedge clk) begin
        if(~resetn | cancel_exc_ertn_tlbflush)
            wb_valid <= 1'b0;
        else
            wb_valid <= mem_to_wb_valid & wb_allowin; 
    end

    /*  memstate <-> wbstate */
    always @(posedge clk) begin
        if(mem_to_wb_valid)
            wb_pc <= mem_pc;
    end
    always @(posedge clk) begin
        if(~resetn)
            {rf_we, rf_waddr, rf_wdata_reg} <= 38'd0;
        else if(mem_to_wb_valid)
            {rf_we, rf_waddr, rf_wdata_reg} <= mem_rf_all;
    end

    always @(posedge clk) begin
        if(~resetn)
            wb_csr_rf_reg <= 80'b0;
        else if(mem_to_wb_valid)
            wb_csr_rf_reg <= mem_csr_rf;
    end

    always @(posedge clk) begin
        if(~resetn)
            wb_exc_rf_reg <= 7'b0;
        else//revise because bug in pipe line, alu result was sent to sram without reg,if exc, it takes two cycles to arrive in mem,make it error
            wb_exc_rf_reg <= mem_exc_rf;
    end

    always @(posedge clk ) begin
        if(~resetn)
            fault_vaddr_reg <= 32'b0;
        else//revise because bug in pipe line, alu result was sent to sram without reg,if exc, it takes two cycles to arrive in mem,make it error
            fault_vaddr_reg <= mem_fault_vaddr;
    end

    always @(posedge clk ) begin
        if(~resetn)
            wb_tlb_rf_reg <= 3'b0;
        else if(mem_to_wb_valid)
            wb_tlb_rf_reg <= mem_tlb_rf;
    end

    assign truly_we = rf_we & wb_valid & ~|wb_exc;

    assign wb_rf_all  = {wb_csr_wr,csr_wr_num,truly_we, rf_waddr, rf_wdata} & {53{wb_valid}};
    assign {wb_csr_rd,wb_csr_wr,csr_wr_num,csr_wr_mask,csr_wr_value} = wb_csr_rf_reg;
    assign rf_wdata   = {32{~wb_csr_rd}} & rf_wdata_reg | {32{wb_csr_rd}} & csr_rd_value;
    assign wb_exc     = wb_exc_rf_reg[6:1] & {6{wb_valid}};
    assign ertn_flush = wb_exc_rf_reg[0] & wb_valid;
    assign wb_fault_vaddr = fault_vaddr_reg;
    /* debug info */
    assign debug_wb_pc       = wb_pc;
    assign debug_wb_rf_wdata = rf_wdata;
    assign debug_wb_rf_we    = {4{truly_we}};
    assign debug_wb_rf_wnum  = rf_waddr;
    //csr rf
    assign csr_we            = wb_csr_wr & wb_valid;
    assign csr_re            = wb_csr_rd & wb_valid;
    assign csr_rd_num        = csr_wr_num;
    //tlb rf
    assign {inst_tlbwr,inst_tlbfill,inst_tlbrd} = wb_tlb_rf_reg;
    assign wb_tlbwr = wb_valid & inst_tlbwr;
    assign wb_tlbrd = wb_valid & inst_tlbrd;
    assign wb_tlbfill = wb_valid & inst_tlbfill; 
    assign csr_wr_flush = wb_csr_wr & (csr_wr_num == CSR_CRMD
                                     | csr_wr_num == CSR_ASID
                                     | csr_wr_num == CSR_DMW0
                                     | csr_wr_num == CSR_DMW1);
    assign tlb_flush_addr = debug_wb_pc + 4;
    assign tlb_flush = (csr_wr_flush | wb_tlbwr | wb_tlbfill | wb_tlbrd) & wb_valid;
endmodule