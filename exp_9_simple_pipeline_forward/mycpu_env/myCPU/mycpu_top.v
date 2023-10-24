module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire [ 3:0] inst_sram_we,    // 4 bit error 2
    output wire        inst_sram_en,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire [ 3:0] data_sram_we,    // 4 bit
    output wire        data_sram_en,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

wire [31:0] seq_pc;
wire [31:0] nextpc;
wire        br_taken;
wire [31:0] br_target;
wire [31:0] inst;


wire [11:0] alu_op;
wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;

wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;

wire        inst_add_w;
wire        inst_sub_w;
wire        inst_slt;
wire        inst_sltu;
wire        inst_nor;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_slli_w;
wire        inst_srli_w;
wire        inst_srai_w;
wire        inst_addi_w;
wire        inst_ld_w;
wire        inst_st_w;
wire        inst_jirl;
wire        inst_b;
wire        inst_bl;
wire        inst_beq;
wire        inst_bne;
wire        inst_lu12i_w;

wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [31:0] rf_rdata1_default;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;
wire [31:0] rf_rdata2_default;
wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;

wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [31:0] mem_result;
wire [31:0] final_result; 

assign seq_pc       = IF_pc + 3'h4;
assign nextpc       = br_taken ? br_target : seq_pc;
// error 4: br_target reg?

assign inst_sram_we    = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

////////////////////////////// pipeline control begin //////////////////////////////


wire IF_allowin, ID_allowin, EX_allowin, MEM_allowin, WB_allowin;
wire IF_ready_go, ID_ready_go, EX_ready_go, MEM_ready_go, WB_ready_go;
wire IF_to_ID_valid, ID_to_EX_valid, EX_to_MEM_valid, MEM_to_WB_valid;

// wire ID_EX_hazard = ID_valid && EX_valid && rf_we_EX && (rf_waddr_EX == rf_raddr1 || rf_waddr_EX == rf_raddr2);

// wire ID_MEM_hazard = ID_valid && MEM_valid && rf_we_MEM && (rf_waddr_MEM == rf_raddr1 || rf_waddr_MEM == rf_raddr2);

// wire ID_WB_hazard = ID_valid && WB_valid && rf_we_WB && (rf_waddr_WB == rf_raddr1 || rf_waddr_WB == rf_raddr2);

// wire WAR_hazard = ID_EX_hazard | ID_MEM_hazard | ID_WB_hazard;

wire WAR_hazard = ID_valid && EX_valid && res_from_mem_EX && (rf_waddr_EX == rf_raddr1 || rf_waddr_EX == rf_raddr2);

reg WAR_hazard_prev;
always @(posedge clk) begin
    WAR_hazard_prev <= WAR_hazard;
end
// compare ID rf_src <=> EX/MEM/WB rf_dest
// (inst has rf_ops) & (rf_ops != 0) & ( ppl has inst )

assign IF_ready_go = 1;
assign ID_ready_go = (WAR_hazard == 0);
assign EX_ready_go = 1;
assign MEM_ready_go = 1;
assign WB_ready_go = 1;

assign IF_allowin = !IF_valid || IF_ready_go && ID_allowin;
assign ID_allowin = !ID_valid || ID_ready_go && EX_allowin;
assign EX_allowin = !EX_valid || EX_ready_go && MEM_allowin;
assign MEM_allowin = !MEM_valid || MEM_ready_go && WB_allowin;
assign WB_allowin = !WB_valid || WB_ready_go;

assign IF_to_ID_valid = IF_valid && IF_ready_go;
assign ID_to_EX_valid = ID_valid && ID_ready_go;
assign EX_to_MEM_valid = EX_valid && EX_ready_go;
assign MEM_to_WB_valid = MEM_valid && MEM_ready_go;

////////////////////////////// pipeline control end //////////////////////////////

//////////////////////////////  pipeline regs begin  //////////////////////////////

reg [31:0] inst_IF, inst_ID;
reg        IF_valid, ID_valid, EX_valid, MEM_valid, WB_valid;
reg [31:0] IF_pc, ID_pc, EX_pc, MEM_pc, WB_pc;
reg        rf_we_EX, rf_we_MEM, rf_we_WB;
reg [ 4:0] rf_waddr_EX, rf_waddr_MEM, rf_waddr_WB; // error 1
reg [31:0] final_result_WB;
reg [11:0] alu_op_EX;
reg [31:0] alu_src1_EX, alu_src2_EX, alu_result_MEM;
reg        res_from_mem_EX, res_from_mem_MEM;
reg        mem_we_EX, mem_we_MEM;
reg [31:0] rkd_value_EX, rkd_value_MEM;   // error 3 save rkd_value
reg        data_sram_en_EX, data_sram_en_MEM; // error 2
reg [ 4:0] rk_EX, rk_MEM, rk_WB;
reg [ 4:0] rj_EX, rj_MEM, rj_WB;
reg [ 4:0] rd_EX, rd_MEM, rd_WB;
reg        rk_valid_EX, rk_valid_MEM, rk_valid_WB;
reg        rj_valid_EX, rj_valid_MEM, rj_valid_WB;
reg        rd_valid_EX, rd_valid_MEM, rd_valid_WB;
reg        rd_is_dest_EX, rd_is_dest_MEM, rd_is_dest_WB;
reg        inst_fetched;


    /* valid */
always @(posedge clk) begin
    if (reset) begin
        IF_valid  <= 0;
        ID_valid  <= 0;
        EX_valid  <= 0;
        MEM_valid <= 0;
        WB_valid  <= 0;
    end
    else begin
        if(IF_allowin)
            IF_valid  <= 1'b1;
        if(ID_allowin)
            ID_valid  <= br_taken ? 0 : IF_to_ID_valid;
        if(EX_allowin)
            EX_valid  <= ID_to_EX_valid;
        if(MEM_allowin)
            MEM_valid <= EX_to_MEM_valid;
        if(WB_allowin)
            WB_valid  <= MEM_to_WB_valid;
    end
end
/// maybe here is err 82

    /* pre-IF PC */
always @(posedge clk) begin
    if (reset) begin
        IF_pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if(IF_allowin) begin
        IF_pc <= nextpc;
    end
end

// err 84 stash instIF 
always @(posedge clk ) begin
    inst_fetched <= IF_allowin;
    if (inst_fetched) begin
        inst_IF <= inst_sram_rdata;
    end
end

    // IF => ID
always @(posedge clk) begin
    if (IF_to_ID_valid && ID_allowin) begin
        ID_pc  <= IF_pc;
    end

    if (ID_allowin && IF_to_ID_valid) begin
        inst_ID <= inst_sram_rdata;
    end
    
end

    // ID => EX
always @(posedge clk) begin
    if (ID_to_EX_valid && EX_allowin) begin
        EX_pc  <= ID_pc;
        rf_we_EX  <= gr_we;
        rf_waddr_EX  <= dest;
        alu_op_EX <= alu_op;
        alu_src1_EX <= alu_src1;
        alu_src2_EX <= alu_src2;
        res_from_mem_EX <= res_from_mem;
        rk_EX <= rk;
        rj_EX <= rj;
        rd_EX <= rd;
        rk_valid_EX <= rk_valid;
        rj_valid_EX <= rj_valid;
        rd_valid_EX <= rd_valid;
        rd_is_dest_EX <= rd_is_dest;
        mem_we_EX <= mem_we;
        rkd_value_EX <= rkd_value;
        data_sram_en_EX <= res_from_mem | mem_we;
    end
end

    // EX => MEM
always @(posedge clk) begin
    if (EX_to_MEM_valid && MEM_allowin) begin
        MEM_pc <= EX_pc;
        rkd_value_MEM <= rkd_value;
        res_from_mem_MEM <= res_from_mem_EX;
        rf_we_MEM <= rf_we_EX;
        rf_waddr_MEM <= rf_waddr_EX;
        alu_result_MEM <= alu_result;
        //mem_we_MEM <= mem_we;
        //data_sram_en_MEM <= res_from_mem | mem_we;
        rk_MEM <= rk_EX;
        rj_MEM <= rj_EX;
        rd_MEM <= rd_EX;
        rk_valid_MEM <= rk_valid_EX;
        rj_valid_MEM <= rj_valid_EX;
        rd_valid_MEM <= rd_valid_EX;
        rd_is_dest_MEM <= rd_is_dest_EX;
    end
end
    
        // MEM => WB
always @(posedge clk) begin
    if (MEM_to_WB_valid && WB_allowin) begin
        WB_pc  <= MEM_pc;
        rf_we_WB  <= rf_we_MEM;
        rf_waddr_WB  <= rf_waddr_MEM;
        final_result_WB <= final_result;
        rk_WB <= rk_MEM;
        rj_WB <= rj_MEM;
        rd_WB <= rd_MEM;
        rk_valid_WB <= rk_valid_MEM;
        rj_valid_WB <= rj_valid_MEM;
        rd_valid_WB <= rd_valid_MEM;
        rd_is_dest_WB <= rd_is_dest_MEM;
    end
end

//////////////////////////////  pipeline regs end  //////////////////////////////

//////////////////////////////  forward wires begin  //////////////////////////////

wire [31:0] rf_rdatas_EX, rf_rdatas_MEM, rf_rdatas_WB;
wire [ 4:0] rf_raddr_EX, rf_raddr_MEM, rf_raddr_WB; 
// include wen, if wen == 0, then addr = 0
// ! if wb data from mem, you can't use EX result!!

assign rf_rdatas_EX = alu_result;
assign rf_rdatas_MEM = final_result;
assign rf_rdatas_WB = rf_wdata;

assign rf_raddr_EX = rf_we_EX & ~res_from_mem_EX ? 
                        rf_waddr_EX : 5'd0;
assign rf_raddr_MEM = rf_we_MEM ? 
                        rf_waddr_MEM : 5'd0;
assign rf_raddr_WB = rf_we_WB ? 
                        rf_waddr_WB : 5'd0;

priority_mux_4_32 u_rf_rdata_1(
    .need     (rf_raddr1),
    .data_in0 (rf_rdatas_EX),
    .dest_in0 (rf_raddr_EX),
    .data_in1 (rf_rdatas_MEM),
    .dest_in1 (rf_raddr_MEM),
    .data_in2 (rf_rdatas_WB),
    .dest_in2 (rf_raddr_WB),
    .data_in3 (rf_rdata1_default),
    .dest_in3 (rf_raddr1),
    .data_out (rf_rdata1)
    );

priority_mux_4_32 u_rf_rdata_2(
    .need     (rf_raddr2),
    .data_in0 (rf_rdatas_EX),
    .dest_in0 (rf_raddr_EX),
    .data_in1 (rf_rdatas_MEM),
    .dest_in1 (rf_raddr_MEM),
    .data_in2 (rf_rdatas_WB),
    .dest_in2 (rf_raddr_WB),
    .data_in3 (rf_rdata2_default),
    .dest_in3 (rf_raddr2),
    .data_out (rf_rdata2)
    );

//////////////////////////////  forward wires end  //////////////////////////////

wire rk_valid = (rk != 0) && (inst_add_w | inst_sub_w | inst_slt | inst_sltu | inst_and | inst_nor | inst_or | inst_xor);
wire rj_valid = (rj != 0) && !(inst_b | inst_bl | inst_lu12i_w);
wire rd_valid = (rd != 0) && !(inst_b | inst_bl);
wire rd_is_dest = !(inst_b | inst_bl | inst_beq | inst_bne);
// if rd is not dest, then the dest is r1

assign inst = inst_ID;
assign inst_sram_en = ~reset && IF_allowin;
assign data_sram_en = data_sram_en_EX;

assign op_31_26  = inst[31:26];
assign op_25_22  = inst[25:22];
assign op_21_20  = inst[21:20];
assign op_19_15  = inst[19:15];

assign rd   = inst[ 4: 0];
assign rj   = inst[ 9: 5];
assign rk   = inst[14:10];

assign i12  = inst[21:10];
assign i20  = inst[24: 5];
assign i16  = inst[25:10];
assign i26  = {inst[ 9: 0], inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));

assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];

assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                    | inst_jirl | inst_bl;
assign alu_op[ 1] = inst_sub_w;
assign alu_op[ 2] = inst_slt;
assign alu_op[ 3] = inst_sltu;
assign alu_op[ 4] = inst_and;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or;
assign alu_op[ 7] = inst_xor;
assign alu_op[ 8] = inst_slli_w;
assign alu_op[ 9] = inst_srli_w;
assign alu_op[10] = inst_srai_w;
assign alu_op[11] = inst_lu12i_w;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
assign need_si16  =  inst_jirl | inst_beq | inst_bne;
assign need_si20  =  inst_lu12i_w;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

// error 4
assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w | inst_lu12i_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;

//assign rf_raddr1 = rj;
//assign rf_raddr2 = src_reg_is_rd ? rd :rk;
assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1_default),
    // .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2_default),
    // .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                    ) && ID_valid && ID_ready_go;
                    //error xxx
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ID_pc + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs);

assign alu_src1 = src1_is_pc  ? ID_pc[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op_EX    ),
    .alu_src1   (alu_src1_EX  ),
    .alu_src2   (alu_src2_EX  ),
    .alu_result (alu_result  )
    );

//assign data_sram_we    = {4{mem_we_MEM && MEM_valid}};/**/
assign data_sram_we    = {4{mem_we_EX}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = rkd_value_EX;

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem_MEM ? mem_result : alu_result_MEM;

assign rf_we    = rf_we_WB && WB_valid;
assign rf_waddr = rf_waddr_WB;
assign rf_wdata = final_result_WB;

// debug info generate
assign debug_wb_pc       = WB_pc;
assign debug_wb_rf_we    = {4{rf_we}};
assign debug_wb_rf_wnum  = rf_waddr_WB;
assign debug_wb_rf_wdata = final_result_WB;


endmodule