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
    input       [7 :0] exe_mem_all,
    //{mem_we, ld_b, ld_h, ld_w, ld_se, st_b, st_h, st_w}
    input       [31:0] exe_rkd_value,
    // memstate -> wbstate
    input              wb_allowin,
    output      [52:0] mem_rf_all, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata}
    output             mem_to_wb_valid,
    output reg  [31:0] mem_pc,
    // data sram
    output             data_sram_en,
    output      [ 3:0] data_sram_we,
    output      [31:0] data_sram_addr,
    output      [31:0] data_sram_wdata,
    input       [31:0] data_sram_rdata,
    input              cancel_exc_ertn,//canceled by exception or ereturn
    input       [78:0] exe_csr_rf,//{ertn,csr_rd,csr_wr,mem_csr_wr_num,csr_rd_value,csr_mask,csr_wvalue}
    input       [5 :0] exe_exc_rf,//{INT,ADEF,BRK,INE,SYS,ertn}
    output      [6 :0] mem_exc_rf,//{INT,ADEF,ALE,BRK,INE,SYS,ertn}
    output reg  [78:0] mem_csr_rf,//{ertn,csr_rd,csr_wr,mem_csr_wr_num,csr_rd_value,csr_mask,csr_wvalue}
    output      [31:0] mem_fault_vaddr
);


    wire        mem_ready_go;
    wire [31:0] mem_result;
    // reg         mem_valid;
    reg  [7 :0] mem_all;
    reg  [31:0] rkd_value;
    wire [31:0] mem_rf_wdata;
    reg         mem_rf_we;
    reg  [4 :0] mem_rf_waddr;
    reg  [31:0] alu_result;
    reg         mem_res_from_mem;
    wire        mem_we, ld_b, ld_h, ld_w, ld_se, st_b, st_h, st_w;
    wire [3 :0] strb;
    wire [13:0] mem_csr_wr_num;
    wire        mem_csr_wr;
    wire        mem_ale;
    reg  [6 :0] mem_exc_rf_reg;

    // valid signals
    assign mem_ready_go     = 1'b1;
    assign mem_allowin      = ~mem_valid | mem_ready_go & wb_allowin | cancel_exc_ertn;     
    assign mem_to_wb_valid  = mem_valid & mem_ready_go;
    assign mem_rf_wdata     = mem_res_from_mem ? mem_result : alu_result;
    assign mem_rf_all       = {mem_csr_wr,mem_csr_wr_num,mem_rf_we, mem_rf_waddr, mem_rf_wdata};
    always @(posedge clk) begin
        if(~resetn | cancel_exc_ertn)
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
        if(~resetn)
            {mem_res_from_mem, mem_all, rkd_value} <= 0;
        else if(exe_to_mem_valid & mem_allowin)
            {mem_res_from_mem, mem_all, rkd_value} <= {exe_res_from_mem, exe_mem_all, exe_rkd_value};
    end

    always @(posedge clk) begin
        if(~resetn)
            mem_exc_rf_reg <= 2'b0;
        else if(exe_to_mem_valid & mem_allowin)
            mem_exc_rf_reg <= {exe_exc_rf[5:4],mem_ale,exe_exc_rf[3:0]};
    end

    always @(posedge clk ) begin
        if(~resetn)
            mem_csr_rf <= exe_csr_rf;
        else if(exe_to_mem_valid & mem_allowin)
            mem_csr_rf <= exe_csr_rf;
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
    assign mem_we                    = exe_mem_all[7] & mem_valid & ~cancel_exc_ertn & ~mem_ale;
    assign {st_b, st_h, st_w}        = exe_mem_all[2:0];
    assign strb = {4{st_w}} | {4{st_h}} & {exe_result[1],exe_result[1],~exe_result[1],~exe_result[1]}
                  | {4{st_b}} & {exe_result[1:0]==2'b11,exe_result[1:0]==2'b10,
                                 exe_result[1:0]==2'b01,exe_result[1:0]==2'b00};
    /* sram instantiation */
    assign data_sram_en    = (exe_res_from_mem | mem_we) & ~((|mem_exc_rf_reg[3:0]) | mem_ale | (|mem_exc_rf_reg[6:5]));
    assign data_sram_we    = {4{mem_we & ~(|mem_exc_rf_reg)}} & strb ;
    assign data_sram_addr  = {exe_result[31:2],2'b0};
    assign data_sram_wdata = {32{st_b}} & {4{exe_rkd_value[7:0]}}
                             | {32{st_h}} & {2{exe_rkd_value[15:0]}}
                             | {32{st_w}} & exe_rkd_value;
    assign mem_csr_wr_num = mem_csr_rf[77:64];
    assign mem_csr_wr = mem_csr_rf[78];
    assign mem_exc_rf = mem_exc_rf_reg;
    assign mem_ale   = exe_res_from_mem & (exe_mem_all[5] & exe_result[0] | exe_mem_all[4] & (|exe_result[1:0])) 
                       | (exe_mem_all[7]) & (st_h & exe_result[0] | st_w & (|exe_result[1:0]));
    // assign mem_ale = 2'b0;
    assign mem_fault_vaddr = alu_result;
endmodule