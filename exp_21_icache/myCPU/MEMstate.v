module MEMstate(
    input              clk,
    input              resetn,
    output reg         mem_valid,
    // exestate -> memstate
    output             mem_allowin,
    input              exe_ready_go,
    input       [5 :0] exe_rf_all, // {exe_rf_we, exe_rf_waddr}
    input              exe_to_mem_valid,
    input       [31:0] exe_pc,    
    input       [31:0] exe_result, 
    input              exe_res_from_mem,
    input       [7 :0] exe_mem_all,
    //{mem_we, ld_b, ld_h, ld_w, ld_se, st_b, st_h, st_w}
    input       [31:0] exe_rkd_value,
    // memstate -> wbstate
    input              wb_allowin,
    // output      [53:0] mem_rf_all, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata} if is ld, can't use data directly
    output      [38:0] mem_rf_all,
    output             mem_to_wb_valid,
    output reg  [31:0] mem_pc,

    // data sram
    // output             data_sram_en,
    // output      [ 3:0] data_sram_we,
    // output      [31:0] data_sram_addr,
    // output      [31:0] data_sram_wdata,
    // input       [31:0] data_sram_rdata,

    
    input  wire        data_sram_data_ok,
    input  wire [31:0] data_sram_rdata, 

    //exc
    input              cancel_exc_ertn_tlbflush,//canceled by exception or ereturn
    input       [79:0] exe_csr_rf,//{csr_rd,csr_wr,mem_csr_num,csr_rd_value,csr_mask,csr_wvalue}
    input       [14:0] exe_exc_rf,//{INT,ADEF,BRK,INE,SYS,ertn}
    output      [14:0] mem_exc_rf,//{INT,ADEF,ALE,BRK,INE,SYS,ertn}
    output reg  [79:0] mem_csr_rf,//{csr_rd,csr_wr,mem_csr_num,csr_rd_value,csr_mask,csr_wvalue}
    output      [31:0] mem_fault_vaddr,
    output             mem_pipeline_block,

    //tlb
    input       [2 :0] exe_tlb_rf,
    output reg  [2 :0] mem_tlb_rf//now tlbsrch has handled
);


localparam  CSR_CRMD                = 14'h0,
            CSR_ASID                = 14'h18,
            CSR_DMW0                = 14'h180,
            CSR_DMW1                = 14'h181;

    wire        mem_ready_go;
    wire [31:0] mem_result;
    reg         mem_gone;
    // reg         mem_valid;
    reg  [7 :0] mem_all;
    reg  [31:0] rkd_value;
    wire [31:0] mem_rf_wdata;
    reg         mem_rf_we;
    reg  [4 :0] mem_rf_waddr;
    reg  [31:0] alu_result;
    reg         mem_res_from_mem;
    wire        mem_res_from_csr;
    wire [3 :0] strb;
    wire        mem_ale;
    reg  [14:0] mem_exc_rf_reg;
    wire        mem_wr,mem_ld_not_handled;
    wire        ld_b,ld_h,ld_se,ld_w,mem_we;
    //wire to handle flush of the pipe line
    wire [2 :0] tlb_task;
    wire        mem_csr_wr;
    wire [13:0] mem_csr_num;
    wire        csr_wr_block;
    // valid signals
    assign mem_ready_go     = (~mem_res_from_mem & ~mem_we | data_sram_data_ok) & ~mem_gone | (|mem_exc_rf_reg);
    assign mem_allowin      = ~mem_valid | mem_ready_go & wb_allowin | cancel_exc_ertn_tlbflush | mem_gone;     
    assign mem_to_wb_valid  = mem_valid & mem_ready_go;
    assign mem_rf_wdata     = mem_res_from_mem ? mem_result : alu_result;
    assign mem_rf_all       = {mem_res_from_csr,mem_ld_not_handled ,mem_rf_we, mem_rf_waddr, mem_rf_wdata} & {54{mem_valid}};
    always @(posedge clk) begin
        if(~resetn | cancel_exc_ertn_tlbflush)
            mem_valid <= 1'b0;
        else if(mem_allowin)begin
            if(exe_ready_go)
                mem_valid <= exe_to_mem_valid;
            else 
                mem_valid <= 1'b0;
        end
        else
            mem_valid <= mem_valid;
    end

    // exestate <-> memstate
    always @(posedge clk) begin
        if(mem_allowin & exe_ready_go)
            mem_pc <= exe_pc;
    end
    always @(posedge clk) begin
        if(mem_allowin & exe_ready_go)
            alu_result <= exe_result;
    end
    always @(posedge clk) begin
        if(~resetn)
            {mem_rf_we, mem_rf_waddr} <= 6'd0;
        else if(mem_allowin & exe_ready_go)
            {mem_rf_we, mem_rf_waddr} <= exe_rf_all;
    end
    always @(posedge clk) begin
        if(~resetn)
            {mem_res_from_mem, mem_all} <= 0;
        else if(mem_allowin & exe_ready_go)
            {mem_res_from_mem, mem_all} <= {exe_res_from_mem, exe_mem_all};
    end

    always @(posedge clk) begin
        if(~resetn)
            mem_exc_rf_reg <= 15'b0;
        else if(mem_allowin & exe_ready_go)
            mem_exc_rf_reg <= exe_exc_rf;
    end

    always @(posedge clk ) begin
        if(~resetn)
            mem_csr_rf <= exe_csr_rf;
        else if(mem_allowin & exe_ready_go)
            mem_csr_rf <= exe_csr_rf;
    end

    always @(posedge clk ) begin
        if(~resetn)
            mem_gone <= 1'b1;
        else if(exe_ready_go & mem_allowin)
            mem_gone <= 1'b0;
        else if(mem_ready_go)
            mem_gone <= 1'b1;
    end
    //tlb rf
    always @(posedge clk ) begin
        if(~resetn)
            mem_tlb_rf <= 3'b0;
        else if(exe_ready_go & mem_allowin)
            mem_tlb_rf <= exe_tlb_rf;
    end

    assign mem_result[7:0] = {8{ld_w | ld_h & ~alu_result[1] | ld_b & alu_result[1:0] == 2'b00}} & data_sram_rdata[7:0]
                               | {8{ld_b & alu_result[1:0] == 2'b01}} & data_sram_rdata[15:8]
                               | {8{ld_h & alu_result[1] | ld_b & alu_result[1:0] == 2'b10}} & data_sram_rdata[23:16]
                               | {8{ld_b & alu_result[1:0] == 2'b11}} & data_sram_rdata[31:24];
    assign mem_result[15:8] = {8{ld_w | ld_h & ~alu_result[1]}} & data_sram_rdata[15:8]
                                | {8{ld_h & alu_result[1]}} & data_sram_rdata[31:24]
                                | {8{ld_b & ld_se & mem_result[7]}};
    assign mem_result[31:16] = {16{ld_w}} & data_sram_rdata[31:16]
                                 | {16{ld_h & ld_se & mem_result[15]}}
                                 | {16{ld_b & ld_se & mem_result[7]}};
    assign {ld_b, ld_h, ld_w, ld_se} = mem_all[6:3];
    assign mem_we = mem_all[7];
    assign mem_ld_not_handled = mem_res_from_mem & ~data_sram_data_ok | ~mem_valid;
    assign mem_fault_vaddr = alu_result;
    assign mem_res_from_csr = mem_csr_rf[79];
    assign mem_exc_rf = mem_exc_rf_reg;
    //pipeline block related
    assign tlb_task = mem_tlb_rf[2:0];
    assign mem_csr_wr = mem_csr_rf[78];
    assign mem_csr_num = mem_csr_rf[77:64];
    assign csr_wr_block = mem_csr_wr & (mem_csr_num == CSR_CRMD
                                      | mem_csr_num == CSR_ASID
                                      | mem_csr_num == CSR_DMW0
                                      | mem_csr_num == CSR_DMW1);
    assign mem_pipeline_block = ((|mem_exc_rf_reg) | (|tlb_task) | (csr_wr_block)) & mem_valid;
endmodule