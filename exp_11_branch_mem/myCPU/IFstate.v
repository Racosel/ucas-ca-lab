module IFstate(
    input             clk,
    input             resetn, // resetn==1 <-> do reset
    output reg        if_valid,

    output            inst_sram_en,
    output     [ 3:0] inst_sram_we,
    output     [31:0] inst_sram_addr,
    output     [31:0] inst_sram_wdata,
    input      [31:0] inst_sram_rdata,

    input             id_allowin,
    input             br_taken_id,
    input      [31:0] br_target_id,
    input             br_taken_exe,
    input      [31:0] br_target_exe,
    output            if_to_id_valid,
    output     [31:0] if_inst,
    output reg [31:0] if_pc
);

    wire        if_ready_go;
    // reg         if_valid;
    wire [31:0] pc_seq;
    wire [31:0] pc_next;
    

    assign if_ready_go    = 1'b1;
    assign if_to_id_valid = if_valid & if_ready_go;
    assign if_allowin     = ~if_valid | if_ready_go & id_allowin;     
    
    always @(posedge clk) begin
        if(~resetn)
            if_valid <= 1'b0;
        else
            if_valid <= 1'b1;
    end

    /* Instruction Fetch: use inst_sram */
    assign inst_sram_en    = if_allowin & resetn;
    assign inst_sram_we    = 4'b0;
    assign inst_sram_addr  = pc_next;
    assign inst_sram_wdata = 32'b0;


    /* Write if_pc: write pc_next generated from the former instruction */
    assign pc_seq  = if_pc + 32'd4;  
    assign pc_next = br_taken_exe ? br_target_exe : br_taken_id ? br_target_id : pc_seq;
    // br signals passed on from IDstate
    always @(posedge clk) begin
        if(~resetn)
            if_pc <= 32'h1bfffffc;
        else if(if_allowin)
            if_pc <= pc_next;
    end
    assign if_inst = inst_sram_rdata;

endmodule