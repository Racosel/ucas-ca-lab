module MEMstate(
    input              clk,
    input              resetn,
    output reg         mem_valid,
    // exestate -> memstate
    output             mem_allowin,
    input       [5 :0] exe_rf_all, // {exe_rf_we, exe_rf_waddr}
    input              exe_to_mem_valid,
    input       [31:0] exe_pc,    
    input       [31:0] exe_result, 
    input              exe_res_from_mem, 
    input              exe_mem_we,
    input       [31:0] exe_rkd_value,
    // memstate -> wbstate
    input              wb_allowin,
    output      [37:0] mem_rf_all, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    output             mem_to_wb_valid,
    output reg  [31:0] mem_pc,
    // data sram
    output             data_sram_en,
    output      [ 3:0] data_sram_we,
    output      [31:0] data_sram_addr,
    output      [31:0] data_sram_wdata,
    input       [31:0] data_sram_rdata
);
    wire        mem_ready_go;
    wire [31:0] mem_result;
    // reg         mem_valid;
    reg         mem_we;
    reg  [31:0] rkd_value;
    wire [31:0] mem_rf_wdata;
    reg         mem_rf_we;
    reg  [4 :0] mem_rf_waddr;
    reg  [31:0] alu_result;
    reg         mem_res_from_mem;

    // valid signals
    assign mem_ready_go     = 1'b1;
    assign mem_allowin      = ~mem_valid | mem_ready_go & wb_allowin;     
    assign mem_to_wb_valid  = mem_valid & mem_ready_go;
    assign mem_rf_wdata     = mem_res_from_mem ? mem_result : alu_result;
    assign mem_rf_all       = {mem_rf_we, mem_rf_waddr, mem_rf_wdata};
    always @(posedge clk) begin
        if(~resetn)
            mem_valid <= 1'b0;
        else
            mem_valid <= exe_to_mem_valid & mem_allowin; 
    end

    // exestate <-> memstate
    always @(posedge clk) begin
        if(exe_to_mem_valid & mem_allowin)
            mem_pc <= exe_pc;
    end
    always @(posedge clk) begin
        if(exe_to_mem_valid & mem_allowin)
            alu_result <= exe_result;
    end
    always @(posedge clk) begin
        if(~resetn)
            {mem_rf_we, mem_rf_waddr} <= 6'd0;
        else if(exe_to_mem_valid & mem_allowin)
            {mem_rf_we, mem_rf_waddr} <= exe_rf_all;
    end
    always @(posedge clk) begin
        if(exe_to_mem_valid & mem_allowin)
            {mem_res_from_mem, mem_we, rkd_value} <= {exe_res_from_mem, exe_mem_we, exe_rkd_value};
    end

    /* sram instantiation */
    assign data_sram_en    = exe_res_from_mem || exe_mem_we;
    assign data_sram_we    = {4{exe_mem_we}};
    assign data_sram_addr  = exe_result;
    assign data_sram_wdata = exe_rkd_value;

    assign mem_result      = data_sram_rdata;

endmodule