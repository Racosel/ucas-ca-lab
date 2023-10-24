module WBstate(
    input              clk,
    input              resetn,
    output reg         wb_valid,
    // memstate <-> wbstate
    output             wb_allowin,
    input       [37:0] mem_rf_all, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    input              mem_to_wb_valid,
    input       [31:0] mem_pc,    
    // debug info
    output      [31:0] debug_wb_pc,
    output      [ 3:0] debug_wb_rf_we,
    output      [ 4:0] debug_wb_rf_wnum,
    output      [31:0] debug_wb_rf_wdata,
    // idstate <-> wbstate
    output      [37:0] wb_rf_all  // {rf_we, rf_waddr, rf_wdata}
);
    
    wire        wb_ready_go;
    // reg         wb_valid;
    reg  [31:0] wb_pc;
    reg  [31:0] rf_wdata;
    reg  [4 :0] rf_waddr;
    reg         rf_we;

    /* valid signals */
    assign wb_ready_go = 1'b1;
    assign wb_allowin  = ~wb_valid | wb_ready_go;     
    always @(posedge clk) begin
        if(~resetn)
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
            {rf_we, rf_waddr, rf_wdata} <= 38'd0;
        else if(mem_to_wb_valid)
            {rf_we, rf_waddr, rf_wdata} <= mem_rf_all;
    end

    assign wb_rf_all = {rf_we, rf_waddr, rf_wdata};

    /* debug info */
    assign debug_wb_pc       = wb_pc;
    assign debug_wb_rf_wdata = rf_wdata;
    assign debug_wb_rf_we    = {4{rf_we & wb_valid}};
    assign debug_wb_rf_wnum  = rf_waddr;
endmodule