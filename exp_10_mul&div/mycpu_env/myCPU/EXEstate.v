module EXEstate(
    input              clk,
    input              resetn,
    output reg         exe_valid,
    // idstate <-> exestate
    output             exe_allowin,
    input       [5 :0] id_rf_all, // {id_rf_we, id_rf_waddr}
    input              id_to_exe_valid,
    input       [31:0] id_pc,    
    input       [75:0] id_alu_data_all, // {exe_alu_op, exe_alu_src1, exe_alu_src2}
    input              id_res_from_mem, 
    input              id_mem_we,
    input       [31:0] id_rkd_value,
    // exestate <-> memstate
    input              mem_allowin,
    // output reg  [5 :0] exe_rf_all,  // {exe_rf_we, exe_rf_waddr}
    output      [38:0] exe_fwd_all, // {exe_res_from_mem, exe_rf_we, exe_rf_waddr, exe_alu_result}
    output             exe_to_mem_valid,
    output reg  [31:0] exe_pc,
    output      [31:0] exe_alu_result,
    output reg         exe_res_from_mem,
    output reg         exe_mem_we,
    output reg  [31:0] exe_rkd_value
);

    wire        exe_ready_go;
    // reg         exe_valid;

    reg  [11:0] exe_alu_op;
    reg  [31:0] exe_alu_src1;
    reg  [31:0] exe_alu_src2;
    reg  [5 :0] exe_rf_all;


    /* valid signals */
    assign exe_ready_go      = 1'b1;
    assign exe_allowin       = ~exe_valid | exe_ready_go & mem_allowin;     
    assign exe_to_mem_valid  = exe_valid & exe_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            exe_valid <= 1'b0;
        else
            exe_valid <= id_to_exe_valid & exe_allowin; 
    end

    /* idstate <-> exestate */
    always @(posedge clk) begin
        if(id_to_exe_valid & exe_allowin)
            exe_pc <= id_pc;
    end
    always @(posedge clk) begin
        if(id_to_exe_valid & exe_allowin)
            {exe_alu_op, exe_alu_src1, exe_alu_src2} <= id_alu_data_all;
    end
    always @(posedge clk) begin
        if(id_to_exe_valid & exe_allowin)
            {exe_res_from_mem, exe_mem_we, exe_rkd_value} <= {id_res_from_mem, id_mem_we, id_rkd_value};
    end
    always @(posedge clk) begin
        if(~resetn)
            exe_rf_all <= 6'd0;
        else if(id_to_exe_valid & exe_allowin)
            exe_rf_all <= id_rf_all;
    end

    assign exe_fwd_all = {exe_res_from_mem, exe_rf_all, exe_alu_result};

    /* alu instantiation */        
    alu u_alu(
        .alu_op     (exe_alu_op    ),
        .alu_src1   (exe_alu_src1  ),
        .alu_src2   (exe_alu_src2  ),
        .alu_result (exe_alu_result)
    );

    /* exe forwarding */
    assign exe_fwd_all = {exe_res_from_mem, exe_rf_all, exe_alu_result};

endmodule