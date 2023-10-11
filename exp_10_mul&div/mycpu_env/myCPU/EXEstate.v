module EXEstate(
    input              clk,
    input              resetn,
    output reg         exe_valid,
    // idstate <-> exestate
    output             exe_allowin,
    input       [5 :0] id_rf_all, // {id_rf_we, id_rf_waddr}
    input              id_to_exe_valid,
    input       [31:0] id_pc,    
    input       [80:0] id_alu_data_all, 
    // {calc_h,calc_s,alu_op[14:0] revised in exp10, alu_src1[31:0], alu_src2[31:0]}
    input              id_res_from_mem, 
    input        [7:0] id_mem_all,
    //{mem_we, ld_b, ld_h, ld_w, ld_ue, st_b, st_h, st_w};should be used in exp11
    input       [31:0] id_rkd_value,
    // exestate <-> memstate
    input              mem_allowin,
    // output reg  [5 :0] exe_rf_all,  // {exe_rf_we, exe_rf_waddr}
    output      [38:0] exe_fwd_all, // {exe_res_from_mem, exe_rf_we, exe_rf_waddr, exe_result}
    output             exe_to_mem_valid,
    output reg  [31:0] exe_pc,
    output      [31:0] exe_result,
    output reg         exe_res_from_mem,
    output reg         exe_mem_we,
    output reg  [31:0] exe_rkd_value
);

    wire        exe_ready_go;
    // reg         exe_valid;
    reg         exe_calc_h;
    reg         exe_calc_s;
    reg  [14:0] exe_alu_op;
    reg  [31:0] exe_alu_src1;
    reg  [31:0] exe_alu_src2;
    reg  [5 :0] exe_rf_all;

    wire [31:0] exe_alu_result;
    wire [63:0] mul_temp_result;
    wire [31:0] mul_result;
    wire [31:0] divide_result;//result of the divide operation
    wire [31:0] mod_result;//result of the mod operation
    wire [31:0] div_result;//result of the dividor
    wire        div_complete;
    // wire [31:0] exe_result;

    /* valid signals */
    assign exe_ready_go      = ~alu_op[13] | div_complete;
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
            {exe_calc_h, exe_calc_s, exe_alu_op, exe_alu_src1, exe_alu_src2} <= id_alu_data_all;
    end
    always @(posedge clk) begin
        if(id_to_exe_valid & exe_allowin)
            {exe_res_from_mem, exe_mem_we, exe_rkd_value} <= {id_res_from_mem, id_mem_all[7], id_rkd_value};
    end
    always @(posedge clk) begin
        if(~resetn)
            exe_rf_all <= 6'd0;
        else if(id_to_exe_valid & exe_allowin)
            exe_rf_all <= id_rf_all;
    end

    /* alu instantiation */        
    alu u_alu(
        .alu_op     (exe_alu_op[11:0]),
        .alu_src1   (exe_alu_src1    ),
        .alu_src2   (exe_alu_src2    ),
        .alu_result (exe_alu_result  )
    );
    module mul(
        .mul_clk(clk),
        .resetn(resetn),
        .mul_signed(exe_calc_s),
        .x(exe_alu_src1),
        .y(exe_alu_src2),
        .result(mul_temp_result)
    );
    /* exe forwarding */
    assign mul_result = {32{exe_calc_h}} & mul_temp_result[63:32] | {32{~exe_calc_h}} & mul_temp_result[31:0];
    module div(
        .div_clk(clk),
        .resetn(resetn),
        .div(exe_aluop[13]),
        .div_signed(exe_calc_s),
        .x(exe_alu_src1),
        .y(exe_alu_src2),
        .s(divide_result),
        .r(mod_result),
        .complete(div_complete)
    );
    assign div_result = {32{exe_calc_h}} & divide_result | {32{~exe_calc_h}} & mod_result;
    assign exe_result = {32{alu_op[12]}} & mul_result | {32{alu_op[13]}} & div_result 
                        | {32{~alu_op[12] & ~alu_op[13]}} & alu_result;
    assign exe_fwd_all = {exe_res_from_mem, exe_rf_all, exe_result};

endmodule