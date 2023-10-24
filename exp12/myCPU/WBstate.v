module WBstate(
    input              clk,
    input              resetn,
    output reg         wb_valid,
    // memstate <-> wbstate
    output             wb_allowin,
    input       [52:0] mem_rf_all, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata_reg}
    input              mem_to_wb_valid,
    input       [31:0] mem_pc,    
    // debug info
    output      [31:0] debug_wb_pc,
    output      [ 3:0] debug_wb_rf_we,
    output      [ 4:0] debug_wb_rf_wnum,
    output      [31:0] debug_wb_rf_wdata,
    // idstate <-> wbstate
    output      [52:0] wb_rf_all,// {rf_we, rf_waddr, rf_wdata_reg}
    input              cancel_exc_ertn,//canceled by exception or ereturn
    input      [108:0] mem_csr_rf,//{csr_rd,csr_wr,csr_rvalue,csr_mask,csr_wvalue}
    input       [5 :0] mem_exc_rf,//{syscall,ertn}
    output      [31:0] csr_wr_mask,
    output      [31:0] csr_wr_value,
    output      [13:0] csr_wr_num,
    output             csr_we,
    output      [0 :0] wb_exc,//for extension
    output             ertn_flush
);
    wire [31:0] csr_rvalue;
    wire        wb_ready_go;
    wire [31:0] rf_wdata;
    // reg         wb_valid;
    reg  [31:0] wb_pc;
    reg  [31:0] rf_wdata_reg;
    reg  [4 :0] rf_waddr;
    reg         rf_we;
    reg  [94:0] wb_csr_rf_reg;
    reg  [5 :0] wb_exc_rf_reg;
    wire [13:0] wb_csr_wr_num;
    wire        wb_csr_wr;
    wire        wb_csr_rd;

    /* valid signals */
    assign wb_ready_go = 1'b1;
    assign wb_allowin  = ~wb_valid | wb_ready_go;     
    always @(posedge clk) begin
        if(~resetn | cancel_exc_ertn)
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
            wb_csr_rf_reg <= 95'b0;
        else if(mem_to_wb_valid)
            wb_csr_rf_reg <= mem_csr_rf;
    end

    always @(posedge clk) begin
        if(~resetn)
            wb_exc_rf_reg <= 6'b0;
        else if(mem_to_wb_valid)
            wb_exc_rf_reg <= mem_exc_rf;
    end

    assign wb_rf_all  = {,rf_we, rf_waddr, rf_wdata};
    assign {wb_csr_rd,wb_csr_wr,csr_rvalue,csr_mask,csr_wvalue} = wb_csr_rf_reg;
    assign rf_wdata   = {32{~csr_rd}} & rf_wdata_reg | {32{csr_rd}} & csr_rvalue;
    assign wb_exc     = wb_exc_rf_reg[5:1] & {5{wb_valid}};
    assign ertn_flush = wb_exc_rf_reg[0] & wb_valid;
    /* debug info */
    assign debug_wb_pc       = wb_pc;
    assign debug_wb_rf_wdata = rf_wdata;
    assign debug_wb_rf_we    = {4{rf_we & wb_valid}};
    assign debug_wb_rf_wnum  = rf_waddr;

    assign wb_csr_wr_num     = wb_csr_rf[106:92];
    assign wb_csr_wr         = wb_csr_rf[107];
    assign csr_we            = wb_csr_wr & wb_valid;
endmodule