module IFstate(
    input             clk,
    input             resetn, // resetn==1 <-> do reset
    output             if_valid_rf,

    // output            inst_sram_en,
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input wire         inst_sram_addr_ok,
    input wire         inst_sram_data_ok,
    input  wire [31:0] inst_sram_rdata,
    // output     [ 3:0] inst_sram_we,
    // output     [31:0] inst_sram_addr,
    // output     [31:0] inst_sram_wdata,
    // input      [31:0] inst_sram_rdata,

    input             id_allowin,
    input             br_taken_id,
    input      [31:0] br_target_id,
    input             br_taken_exe,
    input      [31:0] br_target_exe,
    output            if_to_id_valid,
    output     [31:0] if_inst,
    output     [31:0] if_pc,
    input      [31:0] ertn_pc,
    input      [31:0] exec_pc,
    input             ertn_flush,
    input             exec_flush,
    output            if_exc_rf
);
    reg  [31:0] pc_src;
    reg         pre_if_handled;
    reg         pre_if_valid;
    wire        pre_if_ready_go;
    wire        pre_if_allowin;
    reg         if_handled;
    reg         if_valid;
    reg  [31:0] if_pc_reg;
    reg  [31:0] if_inst_reg;
    reg         if_gone;
    wire        if_ready_go;
    wire        if_allowin;
    // reg         if_valid;
    wire [31:0] pc_seq;
    wire [31:0] pre_if_pc_next;
    

    assign pre_if_allowin  = pre_if_handled & if_allowin 
                             | if_allowin & inst_sram_addr_ok;//not received request or has gone
    assign pre_if_ready_go = inst_sram_addr_ok | pre_if_handled;//request received
    assign if_allowin      = if_ready_go & id_allowin | if_gone;
    assign if_ready_go     = (inst_sram_data_ok | if_handled) & ~if_gone;
    assign if_to_id_valid  = if_valid & if_ready_go;
    
    always @(posedge clk ) begin
        if(~resetn)
            pre_if_handled <= 1'b0;
        else if(pre_if_allowin)
            pre_if_handled <= 1'b0;
        else if(inst_sram_addr_ok & inst_sram_req)
            pre_if_handled <= 1'b1;
    end

    always @(posedge clk ) begin
        if(~resetn)
            if_handled <= 1'b0;//allow the first instruction in 
        else if(if_allowin & pre_if_ready_go)
            if_handled <= 1'b0;
        else if(inst_sram_data_ok)
            if_handled <= 1'b1;
    end

    always @(posedge clk ) begin
        if(~resetn)
            pre_if_valid <= 1'b0;
        else if(~pre_if_handled)//request not received, always valid
            pre_if_valid <= 1'b1;
        else if(pre_if_handled & (br_taken_exe | br_taken_id | exec_flush | ertn_flush) & ~if_allowin)
            pre_if_valid <= 1'b0;
    end

    always @(posedge clk) begin
        if(~resetn)
            if_valid <= 1'b0;
        else if(br_taken_exe | br_taken_id | exec_flush | ertn_flush)
            if_valid <= 1'b0;
        else if(if_allowin & pre_if_ready_go)
            if_valid <= pre_if_valid;
    end

    always @(posedge clk ) begin
        if(~resetn)
            if_pc_reg <= 1'b0;
        else if(if_allowin & pre_if_ready_go)
            if_pc_reg <= pc_src;
    end

    always @(posedge clk ) begin
        if(~resetn)
            if_gone <= 1'b1;
        else if(pre_if_ready_go & if_allowin)
            if_gone <= 1'b0;
        else if(if_ready_go & id_allowin)
            if_gone <= 1'b1;
    end

    /* Instruction Fetch: use inst_sram */
    // assign inst_sram_en    = if_allowin & resetn;
    assign inst_sram_req = ~pre_if_handled & if_allowin;
    assign inst_sram_wr = 1'b0;
    assign inst_sram_size = 2'b10;
    assign inst_sram_wstrb = 4'b0;
    assign inst_sram_addr = pc_src;
    assign inst_sram_wdata = 32'b0;
    assign if_pc = if_pc_reg;
    // assign inst_sram_we    = 4'b0;
    // assign inst_sram_addr  = pre_if_pc_next;
    // assign inst_sram_wdata = 32'b0;


    /* Write if_pc: write pre_if_pc_next generated from the former instruction */
    assign pc_seq  = pc_src + 32'd4;  
    assign pre_if_pc_next = exec_flush? exec_pc: ertn_flush? ertn_pc :br_taken_exe ? br_target_exe : br_taken_id ? br_target_id : pc_seq;
    // br signals passed on from IDstate
    always @(posedge clk) begin
        if(~resetn)
            pc_src <= 32'h1c000000;
        else if(pre_if_allowin | exec_flush | ertn_flush | br_taken_exe | br_taken_id)
            pc_src <= pre_if_pc_next;
    end
    assign if_inst = inst_sram_rdata;
    assign if_exc_rf = | if_pc_reg[1:0];
    assign if_valid_rf = if_valid;
endmodule