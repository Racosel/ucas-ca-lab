module EXEstate(
    input              clk,
    input              resetn,
    output reg         exe_valid,
    // idstate <-> exestate
    output             exe_allowin,
    output             br_taken_exe,
    input       [5 :0] br_rf_all_id,//beq,bne,blt,bltu,bge,bgeu
    input       [31:0] br_target_id,
    output reg  [31:0] br_target_exe,
    input       [5 :0] id_rf_all, // {id_rf_we, id_rf_waddr}
    input              id_to_exe_valid,
    input       [31:0] id_pc,    
    input       [79:0] id_alu_data_all, 
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
    reg         inst_beq, inst_bne, inst_blt, inst_bltu, inst_bge, inst_bgeu;
    reg         exe_calc_h;
    reg         exe_calc_s;
    reg  [13:0] exe_alu_op;
    reg  [31:0] exe_alu_src1;
    reg  [31:0] exe_alu_src2;
    reg  [5 :0] exe_rf_all;
    reg  [5 :0] br_ref_exe;

    wire [31:0] exe_alu_result;
    wire [63:0] mul_temp_result;
    wire [31:0] mul_result;
    wire [31:0] divide_result;//result of the divide operation
    wire [31:0] mod_result;//result of the mod operation
    wire [31:0] div_result;//result of the dividor
    wire        div_complete;
    // wire [31:0] exe_result;
    wire        rj_eq_rd;

    /* valid signals */
    assign exe_ready_go      = ~exe_alu_op[13] | div_complete;
    assign exe_allowin       = ~exe_valid | exe_ready_go & mem_allowin;     
    assign exe_to_mem_valid  = exe_valid & exe_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            exe_valid <= 1'b0;
        else if(br_taken_exe)
            exe_valid <= 1'b0;
        else if(exe_allowin)
            exe_valid <= id_to_exe_valid; 
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
    always @(posedge clk ) begin
        if(id_to_exe_valid & exe_allowin)
            {inst_beq, inst_bne, inst_blt, inst_bltu, inst_bge, inst_bgeu} <= br_rf_all_id;
    end
    always @(posedge clk ) begin
        if(id_to_exe_valid & exe_allowin)
            br_target_exe <= br_target_id;
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
    mul u_mul(
        .clk(clk),
        .resetn(resetn),
        .sign(exe_calc_s),
        .X(exe_alu_src1),
        .Y(exe_alu_src2),
        .P(mul_temp_result)
    );
    /* exe forwarding */
    assign mul_result = {32{exe_calc_h}} & mul_temp_result[63:32] 
                        | {32{~exe_calc_h}} & mul_temp_result[31:0];
    div u_div(
        .div_clk(clk),
        .resetn(resetn),
        .div(exe_alu_op[13]),
        .div_signed(exe_calc_s),
        .x(exe_alu_src1),
        .y(exe_alu_src2),
        .s(divide_result),
        .r(mod_result),
        .complete(div_complete)
    );
    assign div_result = {32{exe_calc_h}} & divide_result | {32{~exe_calc_h}} & mod_result;
    assign exe_result = {32{exe_alu_op[12]}} & mul_result | {32{exe_alu_op[13]}} & div_result 
                        | {32{~exe_alu_op[12] & ~exe_alu_op[13]}} & exe_alu_result;
    assign exe_fwd_all = {exe_res_from_mem, exe_rf_all, exe_result};


    assign rj_eq_rd = (exe_alu_src1 == exe_alu_src2);
    assign br_taken_exe = (inst_beq  &&  rj_eq_rd
                          || inst_bne  && !rj_eq_rd//can be extended by use alu_op and result from alu
                          ) & exe_valid;//always generated in one cycle, if not, do as id
endmodule
