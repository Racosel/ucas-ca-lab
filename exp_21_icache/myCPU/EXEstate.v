module EXEstate(
    input wire        clk,
    input              resetn,
    output reg         exe_valid,
    // idstate <-> exestate
    output             exe_allowin,
    output             exe_ready_go,
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
    //{mem_we, ld_b, ld_h, ld_w, ld_se, st_b, st_h, st_w};should be used in exp11
    input       [31:0] id_rkd_value,
    // exestate <-> memstate
    input              mem_allowin,
    //data_sram
    output wire        data_sram_req,
    output wire        data_sram_wr,
    output wire [ 1:0] data_sram_size,
    output wire [ 3:0] data_sram_wstrb,
    // output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire        data_sram_addr_ok,

    // output reg  [5 :0] exe_rf_all,  // {exe_rf_we, exe_rf_waddr}
    // output      [53:0] exe_fwd_all, // {{exe_csr_wr,exe_csr_wr_num}},exe_res_from_mem, exe_rf_we, exe_rf_waddr, exe_result}
    output      [39:0] exe_fwd_all,
    output             exe_to_mem_valid,
    output reg  [31:0] exe_pc,
    output      [31:0] exe_result,
    output reg         exe_res_from_mem,
    output reg  [7 :0] exe_mem_all,
    output reg  [31:0] exe_rkd_value,

    //csr related
    input              cancel_exc_ertn_tlbflush,//canceled by exception or ereturn
    input       [79:0] id_csr_rf,//{csr_rd,csr_wr,csr_num,csr_mask,csr_wvalue}
    input       [8 :0] id_exc_rf,//{int,pif,ppi,adef,sys,brk,ine,pre_if_tlbr,ertn}
    input       [1 :0] id_timer_rf,
    input       [63:0] timer,
    input              mem_pipeline_block,
    output      [14:0] exe_exc_rf,//{int,pil,pis,pif,pme,if_ppi,exe_ppi,adef,ale,sys,brk,ine,if_tlbr,exe_tlbr,ertn}
    output      [79:0] exe_csr_rf,//{exe_res_from_csr,csr_wr,csr_um,csr_mask,csr_wvalue}

    //tlb related
    input       [9 :0] id_tlb_rf,//{inst_tlbsrch,inst_tlbwr,inst_tlbfill,inst_tlbrd,inst_invtlb,tlb_op[4:0]}
    output      [2 :0] exe_tlb_rf,//now tlbsrch has handled
    output             exe_tlbsrch,
    output             exe_invtlb,
    output      [9 :0] exe_invasid,
    output      [18:0] exe_invvppn,
    output      [4 :0] tlb_op,
    //tlb translate
    output      [31:0] exe_vaddr,
    input       [4 :0] s1_exc,//{s1_pil,s1_pis,s1_pme,s1_ppi,s1_tlbr}
    output             exe_wr_rd

);
    // reg         exe_valid;
    reg         inst_beq, inst_bne, inst_blt, inst_bltu, inst_bge, inst_bgeu;
    reg         exe_calc_h;
    reg         exe_calc_s;
    reg  [13:0] exe_alu_op;
    reg  [31:0] exe_alu_src1;
    reg  [31:0] exe_alu_src2;
    reg  [5 :0] exe_rf_all;
    reg  [8 :0] exe_exc_rf_reg;
    reg  [1 :0] exe_timer_reg;
    wire [31:0] exe_alu_result;
    wire [63:0] mul_temp_result;
    wire [31:0] mul_result;
    wire [31:0] divide_result;//result of the divide operation
    wire [31:0] mod_result;//result of the mod operation
    wire [31:0] div_result;//result of the dividor
    wire        div_complete;
    // wire [31:0] exe_result;
    wire        rj_eq_rd;

    //exe csr
    wire        exe_res_from_csr;
    wire [13:0] exe_csr_wr_num;
    wire        exe_csr_wr;
    wire [31:0] timer_result;
    reg  [79:0] exe_csr_rf_reg;
    wire        mem_ale;
    reg         mem_handled;
    wire        exe_pil,exe_pis,exe_pme,exe_ppi,exe_tlbr;
    wire        int,pif,pre_if_ppi,adef,sys,brk,ine,pre_if_tlbr,ertn;
    //mem_rf
    wire        mem_we, ld_b, ld_h, ld_w, ld_se, st_b, st_h, st_w;
    //tlb rf
    reg  [9 :0] exe_tlb_rf_reg;
    wire        inst_tlbsrch;
    wire [4 :0] tlb_op;

    /* valid signals */
    assign exe_ready_go      = (~exe_alu_op[13] | div_complete) 
                               & ((mem_handled & mem_allowin | data_sram_addr_ok & mem_allowin) | ~exe_res_from_mem & ~mem_we 
                                   | mem_pipeline_block | cancel_exc_ertn_tlbflush | (|exe_exc_rf) ); //need mem
    assign exe_allowin       = ~exe_valid | exe_ready_go & mem_allowin | cancel_exc_ertn_tlbflush;
    assign exe_to_mem_valid  = exe_valid & exe_ready_go;
    always @(posedge clk) begin
        if(~resetn)
            exe_valid <= 1'b0;
        else if(br_taken_exe | cancel_exc_ertn_tlbflush | mem_pipeline_block)
            exe_valid <= 1'b0;
        else if(exe_allowin)
            exe_valid <= id_to_exe_valid; 
    end

    /* idstate <-> exestate */
    always @(posedge clk) begin
        if(~resetn)
            exe_pc <= 32'b0;
        else if(id_to_exe_valid & exe_allowin)
            exe_pc <= id_pc;
    end
    always @(posedge clk) begin
        if(~resetn)
            {exe_calc_h, exe_calc_s, exe_alu_op, exe_alu_src1, exe_alu_src2} <= 0;
        else if(id_to_exe_valid & exe_allowin)
            {exe_calc_h, exe_calc_s, exe_alu_op, exe_alu_src1, exe_alu_src2} <= id_alu_data_all;
    end
    always @(posedge clk) begin
        if(~resetn)
            {exe_res_from_mem, exe_mem_all, exe_rkd_value} <= 0;
        else if(id_to_exe_valid & exe_allowin)
            {exe_res_from_mem, exe_mem_all, exe_rkd_value} <= {id_res_from_mem, id_mem_all, id_rkd_value};
    end
    always @(posedge clk ) begin
        if(~resetn)
            {inst_beq, inst_bne, inst_blt, inst_bltu, inst_bge, inst_bgeu} <= 0;
        else if(id_to_exe_valid & exe_allowin)
            {inst_beq, inst_bne, inst_blt, inst_bltu, inst_bge, inst_bgeu} <= br_rf_all_id;
    end
    always @(posedge clk ) begin
        if(~resetn)
            br_target_exe <= 0;
        else if(id_to_exe_valid & exe_allowin)
            br_target_exe <= br_target_id;
    end
    always @(posedge clk) begin
        if(~resetn)
            exe_rf_all <= 6'd0;
        else if(id_to_exe_valid & exe_allowin)
            exe_rf_all <= id_rf_all;
    end
    //csr rf
    always @(posedge clk ) begin
        if(~resetn)
            exe_csr_rf_reg <= 79'b0;
        else if(id_to_exe_valid & exe_allowin)
            exe_csr_rf_reg <= id_csr_rf;
    end

    always @(posedge clk ) begin
        if(~resetn)
            exe_exc_rf_reg <= 9'b0;
        else if(id_to_exe_valid & exe_allowin)
            exe_exc_rf_reg <= id_exc_rf;
    end

    always @(posedge clk ) begin
        if(~resetn)
            exe_timer_reg <= 2'b0;
        else if(id_to_exe_valid & exe_allowin)
            exe_timer_reg <= id_timer_rf;
    end
    //axi sram rf
    always @(posedge clk ) begin
        if(~resetn)
            mem_handled <= 1'b0;
        else if(exe_allowin)
            mem_handled <= 1'b0;
        else if(data_sram_addr_ok & data_sram_req)
            mem_handled <= 1'b1;
    end
    //tlb rf
    always @(posedge clk) begin
        if(~resetn)
            exe_tlb_rf_reg <= 10'b0;
        else if(exe_allowin & id_to_exe_valid)
            exe_tlb_rf_reg <= id_tlb_rf;
    end
    /* alu instantiation */        
    alu u_alu(
        .alu_op     (exe_alu_op[11:0]),
        .alu_src1   (exe_alu_src1    ),
        .alu_src2   (exe_alu_src2    ),
        .alu_result (exe_alu_result  )
    );
    mul_34 u_mul(
        .mul_clk(clk),
        .resetn(resetn),
        .mul_signed(exe_calc_s),
        .x(exe_alu_src1),
        .y(exe_alu_src2),
        .result(mul_temp_result)
    );
    /* exe forwarding */
    assign mul_result = {32{exe_calc_h}} & mul_temp_result[63:32] 
                        | {32{~exe_calc_h}} & mul_temp_result[31:0];
    div u_div(
        .clk(clk),
        .resetn(resetn),
        .cancel_exc_ertn(cancel_exc_ertn_tlbflush),
        .div(exe_alu_op[13] & exe_valid),
        .div_signed(exe_calc_s),
        .x(exe_alu_src1),
        .y(exe_alu_src2),
        .s(divide_result),
        .r(mod_result),
        .complete(div_complete)
    );
    //div_result
    assign div_result = {32{exe_calc_h}} & divide_result | {32{~exe_calc_h}} & mod_result;
    assign exe_result = (|exe_timer_reg) ? timer_result
                        : ({32{exe_alu_op[12]}} & mul_result | {32{exe_alu_op[13]}} & div_result 
                        | {32{~exe_alu_op[12] & ~exe_alu_op[13]}} & exe_alu_result);

    //mem ref
    assign mem_we          = exe_mem_all[7] & exe_valid & ~cancel_exc_ertn_tlbflush & ~mem_ale;
    assign {st_b, st_h, st_w}        = exe_mem_all[2:0];
    // assign data_sram_en    = (exe_res_from_mem | mem_we) & ~(mem_ale | mem_pipeline_block);//(|mem_exc_rf[6:0]));
    assign data_sram_wr    = mem_we;
    assign data_sram_req   = (exe_res_from_mem | mem_we) & ~((|exe_exc_rf) | mem_pipeline_block) & ~mem_handled & exe_valid & mem_allowin;//(|mem_exc_rf[6:0]))
    assign data_sram_size  = {st_w,st_h};
    assign data_sram_wstrb = {4{st_w}} | {4{st_h}} & {exe_result[1],exe_result[1],~exe_result[1],~exe_result[1]}
                  | {4{st_b}} & {exe_result[1:0]==2'b11,exe_result[1:0]==2'b10,
                                 exe_result[1:0]==2'b01,exe_result[1:0]==2'b00};
    assign exe_vaddr  = exe_result;
    assign data_sram_wdata = {32{st_b}} & {4{exe_rkd_value[7:0]}}
                             | {32{st_h}} & {2{exe_rkd_value[15:0]}}
                             | {32{st_w}} & exe_rkd_value;
    assign mem_ale   = exe_res_from_mem & (exe_mem_all[5] & exe_result[0] | exe_mem_all[4] & (|exe_result[1:0])) 
                       | (exe_mem_all[7]) & (st_h & exe_result[0] | st_w & (|exe_result[1:0]));

    assign timer_result = {32{exe_timer_reg[0]}} & timer[31:0] | {32{exe_timer_reg[1]}} & timer[63:32];
    assign exe_fwd_all = {exe_res_from_csr,exe_res_from_mem, exe_rf_all, exe_result} & {54{exe_valid}};

    //branch reference
    assign rj_eq_rd = (exe_alu_src1 == exe_alu_src2);
    assign br_taken_exe = (inst_beq   &  rj_eq_rd
                          | inst_bne  & !rj_eq_rd//can be extended by use alu_op and result from alu
                          | inst_blt  & exe_alu_result[0]
                          | inst_bltu & exe_alu_result[0]
                          | inst_bge  & ~exe_alu_result[0]
                          | inst_bgeu & ~exe_alu_result[0]
                          ) & exe_valid;//always generated in one cycle, if not, do as id

    //exc reference
    assign {int,pif,pre_if_ppi,adef,sys,brk,ine,pre_if_tlbr,ertn} = exe_exc_rf_reg;
    assign exe_exc_rf = {int,exe_pil,exe_pis,pif,exe_pme,pre_if_ppi,exe_ppi,adef,mem_ale,sys,brk,ine,pre_if_tlbr,exe_tlbr,ertn};
    assign exe_res_from_csr = exe_csr_rf_reg[79];
    assign exe_csr_wr_num = exe_csr_rf_reg[77:64];
    assign exe_csr_wr = exe_csr_rf_reg[78];
    assign exe_csr_rf = exe_csr_rf_reg;
    //tlb rf
    assign inst_tlbsrch  = exe_tlb_rf_reg[9];
    assign exe_tlbsrch   = inst_tlbsrch & exe_valid & ~mem_pipeline_block;
    assign inst_invtlb   = exe_tlb_rf_reg[5];
    assign exe_invtlb   = inst_invtlb & exe_valid & ~mem_pipeline_block;
    assign tlb_op        = exe_tlb_rf_reg[4:0];
    assign exe_invasid   = exe_alu_src1[9:0];
    assign exe_invvppn   = exe_alu_src2[31:13];
    assign exe_tlb_rf    = exe_tlb_rf_reg[8:6];
    assign {exe_pil,exe_pis,exe_pme,exe_ppi,exe_tlbr} = s1_exc;
    assign exe_wr_rd     = exe_res_from_mem | mem_we;
endmodule