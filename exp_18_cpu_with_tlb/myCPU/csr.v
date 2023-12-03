`timescale 1ns / 1ps

module csr(
    input         clk,
    input  [5 :0] exc,//{INT,ADEF,ALE,BRK,INE,SYS}
    input         ertn_flush,
    input         resetn,
    input         csr_re,
    input  [13:0] csr_wr_num,
    input  [13:0] csr_rd_num,
    input         csr_we,
    input  [31:0] csr_wr_mask,
    input  [31:0] csr_wr_value,
    input  [31:0] wb_pc,
    input  [31:0] wb_fault_vaddr,
    output [31:0] csr_rd_value,
    output [31:0] csr_eentry_pc,
    output [31:0] csr_eertn_pc,
    output        has_int,
    //tlb related extention
    input  [4 :0] tlb_inst,//{inst_tlbsrch,inst_tlbwr,inst_tlbfill,inst_tlbrd,inst_invtlb}
    input  [4 :0] invtlb_op,
    input  [18:0] inv_vppn,
    input  [9 :0] inv_asid
);


localparam  CSR_CRMD                = 14'h0,
            CSR_CRMD_PLV_START      = 0,
            CSR_CRMD_PLV_END        = 1,
            CSR_CRMD_IE             = 2,
            CSR_PRMD                = 14'h1,
            CSR_PRMD_PPLV_START     = 0,
            CSR_PRMD_PPLV_END       = 1,
            CSR_PRMD_PIE            = 2,
            CSR_ECFG                = 14'h4,
            CSR_ECFG_LIE_START      = 0,
            CSR_ECFG_LIE_END        = 12,
            CSR_ESTAT               = 14'h5,
            CSR_ESTAT_IS10_START    = 0,
            CSR_ESTAT_IS10_END      = 1,
            CSR_ERA                 = 14'h6,
            CSR_BADV                = 14'h7,
            CSR_ERA_PC_START        = 0,
            CSR_ERA_PC_END          = 31,
            CSR_EENTRY              = 14'hc,
            CSR_EENTRY_VA_START     = 12,
            CSR_EENTRY_VA_END       = 31,
            CSR_SAVE0               = 14'h30,
            CSR_SAVE1               = 14'h31,
            CSR_SAVE2               = 14'h32,
            CSR_SAVE3               = 14'h33,
            CSR_SAVE_DATA_START     = 0,
            CSR_SAVE_DATA_END       = 31,
            CSR_TICLR               = 14'h44,
            CSR_TICLR_CLR           = 0,
            CSR_TID                 = 14'h40,
            CSR_TID_TID_START       = 0,
            CSR_TID_TID_END         = 31,
            CSR_TCFG                = 14'h41,
            CSR_TCFG_EN             = 0,
            CSR_TCFG_PERIOD         = 1,
            CSR_TCFG_INITVAL_START  = 2,
            CSR_TCFG_INITVAL_END    = 31,
            CSR_TVAL                = 14'h42,
            CSR_TLBIDX              = 14'h10,
            CSR_TLBIDX_IDX_START    = 0,
            CSR_TLBIDX_IDX_END      = 3,
            CSR_TLBIDX_PS_START     = 24,
            CSR_TLBIDX_PS_END       = 29,
            CSR_TLBIDX_NE           = 31,
            CSR_TLBEHI              = 14'h11,
            CSR_TLBEHI_VPPN_START   = 13,
            CSR_TLBEHI_VPPN_END     = 31,
            CSR_TLBELO0             = 14'h12,
            CSR_TLBELO1             = 14'h13,
            CSR_TLBELO_V            = 0,
            CSR_TLBELO_D            = 1,
            CSR_TLBELO_PLV_START    = 2,
            CSR_TLBELO_PLV_END      = 3,
            CSR_TLBELO_MAT_START    = 4,
            CSR_TLBELO_MAT_END      = 5,
            CSR_TLBELO_G            = 6,
            CSR_TLBELO_PPN_START    = 8,
            CSR_TLBELO_PPN_END      = 27,
            CSR_ASID                = 14'h18,
            CSR_ASID_ASID_START     = 0,
            CSR_ASID_ASID_END       = 9,
            CSR_TLBRENTRY           = 14'h88,
            CSR_TLBRENTRY_PPN_START = 12,
            CSR_TLBRENTRY_PPN_END   = 31;
//crmd start
wire [31:0] csr_crmd;
reg  [1 :0] csr_crmd_plv;
reg         csr_crmd_ie;
//below should be down in virtual memory
wire        csr_crmd_da;
wire        csr_crmd_pg;
wire [1 :0] csr_crmd_datf;
wire [1 :0] csr_crmd_datm;
//crmd end
//prmd start
wire [31:0] csr_prmd;
reg  [1 :0] csr_prmd_pplv;
reg         csr_prmd_pie;
//prmd end
//ecfg start
wire [31:0] csr_ecfg;
reg  [12:0] csr_ecfg_lie;
//ecfg end
//estate start
wire [31:0] csr_estat;
reg  [12:0] csr_estat_is;
reg  [5 :0] csr_estat_ecode;
reg  [8 :0] csr_estat_esubcode;
wire [5 :0] wb_ecode;
wire [8 :0] wb_esubcode;
//estate end
//era start
wire [31:0] csr_era;
reg  [31:0] csr_era_pc;
//era end
//badv start
wire [31:0] csr_badv;
reg  [31:0] csr_badv_pc;
//badv end
//eentry start
wire [31:0] csr_eentry;
reg  [20:0] csr_eentry_va;
//eentry end
//savr start
reg  [31:0] csr_save0_data;
reg  [31:0] csr_save1_data;
reg  [31:0] csr_save2_data;
reg  [31:0] csr_save3_data;
//save end
//tid start
wire [31:0] csr_tid;
reg  [31:0] csr_tid_tid;
//tid end
//tcfg start
wire [31:0] csr_tcfg;
reg         csr_tcfg_en;
reg         csr_tcfg_periodic;
reg  [29:0] csr_tcfg_initval;
wire [31:0] tcfg_next_value;
wire [31:0] csr_tval;//tcfg is read only
//tcfg end
//tval begin
reg  [31:0] timer_cnt;
//tval end
//ticlr start
wire        csr_ticlr_clr;
//ticlr end
//tlbindex start
reg  [3 :0] tlbidx_index;
reg  [5 :0] tlbidx_ps;
reg         tlbidx_ne;
wire [31:0] csr_tlbidx;
//tlbindex end
//tlbehi start
reg  [18:0] tlbehi_vppn;
wire [31:0] csr_tlbehi;
//tlbehi end
//tlbelo0,tlbelo1 start
reg         tlbelo0_v;
reg         tlbelo0_d;
reg  [1 :0] tlbelo0_plv;
reg  [1 :0] tlbelo0_mat;
reg         tlbelo0_g;
reg  [19:0] tlbelo0_ppn;
wire [31:0] csr_tlbelo0;
reg         tlbelo1_v;
reg         tlbelo1_d;
reg  [1 :0] tlbelo1_plv;
reg  [1 :0] tlbelo1_mat;
reg         tlbelo1_g;
reg  [19:0] tlbelo1_ppn;
wire [31:0] csr_tlbelo1;
//tlbelo0,tlbelo1 end
//asid start
reg  [9 :0] asid_asid;
wire [7 :0] asid_asidbits;
wire [31:0] csr_asid;
//asid end
//tlbrentry start
reg  [19:0] tlbrentry_ppn;
wire [31:0] csr_tlbrentry;
//tlbrentry end
//csr regs end

wire        wb_ex;
wire        int,adef,ale,brk,ine,sys;
wire        break;
//non-sense wire
wire [7 :0] hw_int_in;
wire [31:0] core_id;
wire        wb_ex_addr_err;
//tlb related wire
wire        inst_tlbsrch;
wire        inst_tlbrd;
wire        inst_tlbwr;
wire        inst_tlbfill;
wire        inst_invtlb;
//wire to handle tlb
//search port1
wire [18:0] s1_vppn;
wire        s1_va_bit12;
wire [ 9:0] s1_asid;
wire         s1_found;
wire [3 :0]  s1_index;
wire [19:0]  s1_ppn;
wire [ 5:0]  s1_ps;
wire [ 1:0]  s1_plv;
wire [ 1:0]  s1_mat;
wire         s1_d;
wire         s1_v;
//write port
wire         tlb_we; //w(rite) e(nable)
wire [3 :0]  w_index;
wire         w_e;
wire [18:0]  w_vppn;
wire [ 5:0]  w_ps;
wire [ 9:0]  w_asid;
wire         w_g;
wire [19:0]  w_ppn0;
wire [ 1:0]  w_plv0;
wire [ 1:0]  w_mat0;
wire         w_d0;
wire         w_v0;
wire [19:0]  w_ppn1;
wire [ 1:0]  w_plv1;
wire [ 1:0]  w_mat1;
wire         w_d1;
wire         w_v1;
// read port
wire [3 :0]  r_index;
wire         r_e;
wire [18:0]  r_vppn;
wire [ 5:0]  r_ps;
wire [ 9:0]  r_asid;
wire         r_g;
wire [19:0]  r_ppn0;
wire [ 1:0]  r_plv0;
wire [ 1:0]  r_mat0;
wire         r_d0;
wire         r_v0;
wire [19:0]  r_ppn1;
wire [ 1:0]  r_plv1;
wire [ 1:0]  r_mat1;
wire         r_d1;
wire         r_v1;


assign {int,adef,ale,brk,ine,sys} = exc;
assign wb_ex = int | adef | ale | brk | ine | sys;
assign wb_ecode = int ? 6'h0 : adef ? 6'h08 : ine ? 6'h0D : sys ? 6'hB : 
                  brk ? 6'hc : 6'h9;
assign wb_esubcode = 9'b0;
assign hw_int_in = 8'b0;
assign core_id = 32'b0;
assign has_int = ((|(csr_estat_is[12:0] & csr_ecfg_lie[12:0])) & csr_crmd_ie);
assign wb_ex_addr_err = adef | ale;
//tlb
assign {inst_tlbsrch,inst_tlbwr,inst_tlbfill,inst_tlbrd,inst_invtlb} = tlb_inst;
//crmd start
always @(posedge clk ) begin
    if(~resetn)
        csr_crmd_plv <= 2'b0;
    else if(wb_ex)
        csr_crmd_plv <= 2'b0;
    else if(ertn_flush)
        csr_crmd_plv <= csr_prmd_pplv;//eret
    else if(csr_we && csr_wr_num == CSR_CRMD)
        csr_crmd_plv <= csr_wr_mask[CSR_CRMD_PLV_END:CSR_CRMD_PLV_START] & csr_wr_value[CSR_CRMD_PLV_END:CSR_CRMD_PLV_START]
                        | ~csr_wr_mask[CSR_CRMD_PLV_END: CSR_CRMD_PLV_START] & csr_crmd_plv;
end

always @(posedge clk ) begin
    if(~resetn)
        csr_crmd_ie <= 1'b0;
    else if(wb_ex)
        csr_crmd_ie <= 1'b0;
    else if(ertn_flush)
        csr_crmd_ie <= csr_prmd_pie;
    else if(csr_we && csr_wr_num == CSR_CRMD)
        csr_crmd_ie <= csr_wr_mask[CSR_CRMD_IE] & csr_wr_value[CSR_CRMD_IE]
                       | ~csr_wr_mask[CSR_CRMD_IE] & csr_crmd_ie;
end
//virtual memory
assign csr_crmd_da   = 1'b1;
assign csr_crmd_pg   = 1'b0;
assign csr_crmd_datf = 2'b00;
assign csr_crmd_datm = 2'b00;
//crmd end

assign csr_crmd = {23'b0,csr_crmd_datm,csr_crmd_datf,csr_crmd_pg,csr_crmd_da,csr_crmd_ie,csr_crmd_plv};

//prmd start
always @(posedge clk ) begin
    if(~resetn)begin
        csr_prmd_pplv <= 2'b0;
        csr_prmd_pie  <= 1'b0;
    end
    else if(wb_ex)begin
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie  <= csr_crmd_ie;
    end
    else if(csr_we && csr_wr_num == CSR_PRMD)begin
        csr_prmd_pplv <= csr_wr_mask[CSR_PRMD_PPLV_END:CSR_PRMD_PPLV_START] & csr_wr_value[CSR_PRMD_PPLV_END:CSR_PRMD_PPLV_START]
                         | ~csr_wr_mask[CSR_PRMD_PPLV_END:CSR_PRMD_PPLV_START] & csr_prmd_pplv;
        csr_prmd_pie  <= csr_wr_mask[CSR_PRMD_PIE] & csr_wr_value[CSR_PRMD_PIE]
                         | ~csr_wr_mask[CSR_PRMD_PIE] & CSR_PRMD_PIE;
    end
end

assign csr_prmd = {29'b0,csr_prmd_pie,csr_prmd_pplv};
//prmd end

//ecfg start
always @(posedge clk ) begin
    if(~resetn)
        csr_ecfg_lie <= 13'b0;
    else if(csr_we && csr_wr_num == CSR_ECFG)
        csr_ecfg_lie <= csr_wr_mask[CSR_ECFG_LIE_END:CSR_ECFG_LIE_START] & 13'h1bff & csr_wr_value[CSR_ECFG_LIE_END:CSR_ECFG_LIE_START]
                        | ~csr_wr_mask[CSR_ECFG_LIE_END:CSR_ECFG_LIE_START] & 13'h1bff & csr_ecfg_lie;
end
assign csr_ecfg = {19'b0,csr_ecfg_lie};
//ecfg end

//estate start
always @(posedge clk ) begin
    if(~resetn)
        csr_estat_is[1:0] <= 2'b0;
    else if(csr_we && csr_wr_num == CSR_ESTAT)
        csr_estat_is[1:0] <= csr_wr_mask[CSR_ESTAT_IS10_END:CSR_ESTAT_IS10_START] & csr_wr_value[CSR_ESTAT_IS10_END:CSR_ESTAT_IS10_START]
                             | ~csr_wr_mask[CSR_ESTAT_IS10_END:CSR_ESTAT_IS10_START] & csr_estat_is[1:0];

    // csr_estat_is[9:2] = 8'b0;
    csr_estat_is[9:2] = hw_int_in[7:0]; // not achieved
    csr_estat_is[10] <= 1'b0;

    if(~resetn)
        csr_estat_is[11] <= 1'b0;
    else if(csr_tcfg_en && timer_cnt[31:0] == 32'b0)
        csr_estat_is[11] <= 1'b1;
    else if(csr_we & (csr_wr_num == CSR_TICLR)
                   & csr_wr_mask[CSR_TICLR_CLR] 
                   & csr_wr_value[CSR_TICLR_CLR])
        csr_estat_is[11] <= 1'b0;
    // csr_estat_is[11] <= 1'b0;
    csr_estat_is[12] <= 1'b0;
    // csr_estat_is[12] <= ipi_int_in;//not achieved
end
always @(posedge clk ) begin
    if(wb_ex)begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end
assign csr_estat = {1'b0,csr_estat_esubcode,csr_estat_ecode,3'b0,csr_estat_is};
//estate end

//era start
always @(posedge clk ) begin
    if(~resetn)
        csr_era_pc <= 32'b0;
    else if(wb_ex)
        csr_era_pc <= wb_pc;
    else if(csr_we && csr_wr_num == CSR_ERA)
        csr_era_pc <= csr_wr_mask[CSR_ERA_PC_END:CSR_ERA_PC_START] & csr_wr_value[CSR_ERA_PC_END:CSR_ERA_PC_START]
                      | ~csr_wr_mask[CSR_ERA_PC_END:CSR_ERA_PC_START] & csr_era_pc;
end
assign csr_era = csr_era_pc;
//era end
//badv start
always @(posedge clk ) begin
    if(wb_ex & wb_ex_addr_err)
        csr_badv_pc <= (adef)? wb_pc: wb_fault_vaddr;//not support virtual memory
end
assign csr_badv = csr_badv_pc;
//badv end
//eentry start
always @(posedge clk ) begin
    if(~resetn)
        csr_eentry_va <= 20'b0;
    else if(csr_we && csr_wr_num == CSR_EENTRY)
        csr_eentry_va <= csr_wr_mask[CSR_EENTRY_VA_END:CSR_EENTRY_VA_START] & csr_wr_value[CSR_EENTRY_VA_END:CSR_EENTRY_VA_START]
                         | ~csr_wr_mask[CSR_EENTRY_VA_END:CSR_EENTRY_VA_START] & csr_eentry_va;
end
assign csr_eentry = {csr_eentry_va,12'b0};
//eentry end

//save start
always @(posedge clk ) begin
    if(~resetn)
        csr_save0_data <= 32'b0;
    else if(csr_we && csr_wr_num == CSR_SAVE0)
        csr_save0_data <= csr_wr_mask[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START] & csr_wr_value[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START]
                          | ~csr_wr_mask[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START] & csr_save0_data;
    if(~resetn)
        csr_save1_data <= 32'b0;
    else if(csr_we && csr_wr_num == CSR_SAVE1)
        csr_save1_data <= csr_wr_mask[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START] & csr_wr_value[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START]
                          | ~csr_wr_mask[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START] & csr_save1_data;
    if(~resetn)
        csr_save2_data <= 32'b0;
    else if(csr_we && csr_wr_num == CSR_SAVE2)
        csr_save2_data <= csr_wr_mask[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START] & csr_wr_value[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START]
                          | ~csr_wr_mask[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START] & csr_save2_data;
    if(~resetn)
        csr_save3_data <= 32'b0;
    else if(csr_we && csr_wr_num == CSR_SAVE3)
        csr_save3_data <= csr_wr_mask[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START] & csr_wr_value[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START]
                          | ~csr_wr_mask[CSR_SAVE_DATA_END:CSR_SAVE_DATA_START] & csr_save3_data;
end
//save end
//tid begin
always @(posedge clk ) begin
    if(~resetn)
        csr_tid_tid <= core_id;
    else if(csr_we && csr_wr_num == CSR_TID)
        csr_tid_tid <= csr_wr_mask[CSR_TID_TID_END:CSR_TID_TID_START] & csr_wr_value[CSR_TID_TID_END:CSR_TID_TID_START]
                       | ~csr_wr_mask[CSR_TID_TID_END:CSR_TID_TID_START] & csr_tid_tid;
end
assign csr_tid = csr_tid_tid;
//tid end
//tcfg begin
always @(posedge clk ) begin
    if(~resetn)
        csr_tcfg_en <= 1'b0;
    else if(csr_we && csr_wr_num == CSR_TCFG)
        csr_tcfg_en <= csr_wr_mask[CSR_TCFG_EN:CSR_TCFG_EN] & csr_wr_value[CSR_TCFG_EN:CSR_TCFG_EN]
                       | ~csr_wr_mask[CSR_TCFG_EN:CSR_TCFG_EN] & csr_tcfg_en;
    if(csr_we && csr_wr_num == CSR_TCFG)begin
        csr_tcfg_periodic <= csr_wr_mask[CSR_TCFG_PERIOD] & csr_wr_value[CSR_TCFG_PERIOD]
                             | ~csr_wr_mask[CSR_TCFG_PERIOD] & csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wr_mask[CSR_TCFG_INITVAL_END:CSR_TCFG_INITVAL_START] & csr_wr_value[CSR_TCFG_INITVAL_END:CSR_TCFG_INITVAL_START]
                            | ~csr_wr_mask[CSR_TCFG_INITVAL_END:CSR_TCFG_INITVAL_START] & csr_tcfg_initval;
    end
end
assign csr_tcfg = {csr_tcfg_initval,csr_tcfg_periodic,csr_tcfg_en};
//tcfg end
//tval begin
assign tcfg_next_value = csr_wr_mask[31:0] & csr_wr_value
                         | ~csr_wr_mask[31:0] & {csr_tcfg_initval,csr_tcfg_periodic,csr_tcfg_en};
always @(posedge clk ) begin
    if(~resetn)
        timer_cnt <= 32'hffffffff;
    else if(csr_we && csr_wr_num == CSR_TCFG && tcfg_next_value[CSR_TCFG_EN])
        timer_cnt <= {tcfg_next_value[CSR_TCFG_INITVAL_END:CSR_TCFG_INITVAL_START],2'b0};
    else if(csr_tcfg_en & ~&timer_cnt)
        if((~|timer_cnt) & csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval,2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
end
assign csr_tval = timer_cnt;
//tval end
//csr_ticlr start
assign csr_ticlr_clr = 1'b0;
//csr_ticlr end
//tlbindex start
always @(posedge clk ) begin
    if(~resetn)
        tlbidx_index <= 4'b0;
    else if(csr_we && csr_wr_num == CSR_TLBIDX)begin
        tlbidx_index <= csr_wr_mask[CSR_TLBIDX_IDX_END:CSR_TLBIDX_IDX_START] & csr_wr_value[CSR_TLBIDX_IDX_END:CSR_TLBIDX_IDX_START]
                        | ~csr_wr_mask[CSR_TLBIDX_IDX_END:CSR_TLBIDX_IDX_START] & tlbidx_index;
    end
    else if(inst_tlbsrch && s1_found)
        tlbidx_index <= s1_index;
   // else if(tlb)
end
always @(posedge clk ) begin
    if(~resetn)begin
        tlbidx_ps <= 6'b0;
    end
    else if(csr_we && csr_wr_num == CSR_TLBIDX)begin
        tlbidx_ps <= csr_wr_mask[CSR_TLBIDX_PS_END:CSR_TLBIDX_PS_START] & csr_wr_value[CSR_TLBIDX_PS_END:CSR_TLBIDX_PS_START]
                     | ~csr_wr_mask[CSR_TLBIDX_PS_END:CSR_TLBIDX_PS_START] & tlbidx_ps;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbidx_ps <= r_ps;
        else
            tlbidx_ps <= 6'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)begin
        tlbidx_ne <= 1'b0;
    end
    else if(csr_we && csr_wr_num == CSR_TLBIDX)begin
        tlbidx_ne <= csr_wr_mask[CSR_TLBIDX_NE] & csr_wr_value[CSR_TLBIDX_NE]
                     | ~csr_wr_mask[CSR_TLBIDX_NE] & tlbidx_ne;
    end
    else if(inst_tlbsrch)begin
        if(s1_found)
            tlbidx_ne <= 1'b0;
        else
            tlbidx_ne <= 1'b1;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbidx_ne <= 1'b0;
        else
            tlbidx_ne <= 1'b1;
    end
end
assign csr_tlbidx = {tlbidx_ne,1'b0,tlbidx_ps,20'b0,tlbidx_index};
//tlbindex end
//tlbehi start
always @(posedge clk ) begin
    if(~resetn)begin
        tlbehi_vppn <= 19'b0;
    end
    else if(csr_we && csr_wr_num == CSR_TLBEHI)begin
        tlbehi_vppn <= csr_wr_mask[CSR_TLBEHI_VPPN_END:CSR_TLBEHI_VPPN_START] & csr_wr_value[CSR_TLBEHI_VPPN_END:CSR_TLBEHI_VPPN_START]
                     | ~csr_wr_mask[CSR_TLBEHI_VPPN_END:CSR_TLBEHI_VPPN_START] & tlbehi_vppn;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbehi_vppn <= r_vppn;
        else
            tlbehi_vppn <= 19'b0;
    end
end
assign csr_tlbehi = {tlbehi_vppn,13'b0};
//tlbehi end
//tlbelo0,tlbelo1 start
always @(posedge clk ) begin
    if(~resetn)
        tlbelo0_v <= 1'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO0)begin
        tlbelo0_v <= csr_wr_mask[CSR_TLBELO_V] & csr_wr_value[CSR_TLBELO_V]
                     | ~csr_wr_mask[CSR_TLBELO_V] & tlbelo0_v;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo0_v <= r_v0;
        else
            tlbelo0_v <= 1'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo0_d <= 1'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO0)begin
        tlbelo0_d <= csr_wr_mask[CSR_TLBELO_D] & csr_wr_value[CSR_TLBELO_D]
                     | ~csr_wr_mask[CSR_TLBELO_D] & tlbelo0_d;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo0_d <= r_d0;
        else
            tlbelo0_d <= 0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo0_plv <= 2'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO0)begin
        tlbelo0_plv <= csr_wr_mask[CSR_TLBELO_PLV_END:CSR_TLBELO_PLV_START] & csr_wr_value[CSR_TLBELO_PLV_END:CSR_TLBELO_PLV_START]
                       | ~csr_wr_mask[CSR_TLBELO_PLV_END:CSR_TLBELO_PLV_START] & tlbelo0_plv;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo0_plv <= r_plv0;
        else
            tlbelo0_plv <= 2'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo0_mat <= 2'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO0)begin
        tlbelo0_mat <= csr_wr_mask[CSR_TLBELO_MAT_END:CSR_TLBELO_MAT_START] & csr_wr_value[CSR_TLBELO_MAT_END:CSR_TLBELO_MAT_START]
                     | ~csr_wr_mask[CSR_TLBELO_MAT_END:CSR_TLBELO_MAT_START] & tlbelo0_mat;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo0_mat <= r_mat0;
        else
            tlbelo0_mat <= 2'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo0_g <= 1'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO0)begin
        tlbelo0_g <= csr_wr_mask[CSR_TLBELO_G] & csr_wr_value[CSR_TLBELO_G]
                     | ~csr_wr_mask[CSR_TLBELO_G] & tlbelo0_g;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo0_g <= r_g;
        else
            tlbelo0_g <= 1'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo0_ppn <= 20'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO0)begin
        tlbelo0_ppn <= csr_wr_mask[CSR_TLBELO_PPN_END:CSR_TLBELO_PPN_START] & csr_wr_value[CSR_TLBELO_PPN_END:CSR_TLBELO_PPN_START]
                     | ~csr_wr_mask[CSR_TLBELO_PPN_END:CSR_TLBELO_PPN_START] & tlbelo0_ppn;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo0_ppn <= r_ppn0;
        else
            tlbelo0_ppn <= 19'b0;
    end
end
assign csr_tlbelo0 = {4'b0,tlbelo0_ppn,1'b0,tlbelo0_g,tlbelo0_mat,tlbelo0_plv,tlbelo0_d,tlbelo0_v};


always @(posedge clk ) begin
    if(~resetn)
        tlbelo1_v <= 1'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO1)begin
        tlbelo1_v <= csr_wr_mask[CSR_TLBELO_V] & csr_wr_value[CSR_TLBELO_V]
                     | ~csr_wr_mask[CSR_TLBELO_V] & tlbelo1_v;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo1_v <= r_v1;
        else
            tlbelo1_v <= 1'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo1_d <= 1'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO1)begin
        tlbelo1_d <= csr_wr_mask[CSR_TLBELO_D] & csr_wr_value[CSR_TLBELO_D]
                     | ~csr_wr_mask[CSR_TLBELO_D] & tlbelo1_d;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo1_d <= r_d1;
        else
            tlbelo1_d <= 1'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo1_plv <= 2'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO1)begin
        tlbelo1_plv <= csr_wr_mask[CSR_TLBELO_PLV_END:CSR_TLBELO_PLV_START] & csr_wr_value[CSR_TLBELO_PLV_END:CSR_TLBELO_PLV_START]
                       | ~csr_wr_mask[CSR_TLBELO_PLV_END:CSR_TLBELO_PLV_START] & tlbelo1_plv;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo1_plv <= r_plv1;
        else
            tlbelo1_plv <= 2'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo1_mat <= 2'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO1)begin
        tlbelo1_mat <= csr_wr_mask[CSR_TLBELO_MAT_END:CSR_TLBELO_MAT_START] & csr_wr_value[CSR_TLBELO_MAT_END:CSR_TLBELO_MAT_START]
                     | ~csr_wr_mask[CSR_TLBELO_MAT_END:CSR_TLBELO_MAT_START] & tlbelo1_mat;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo1_mat <= r_mat1;
        else
            tlbelo1_mat <= 2'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo1_g <= 1'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO1)begin
        tlbelo1_g <= csr_wr_mask[CSR_TLBELO_G] & csr_wr_value[CSR_TLBELO_G]
                     | ~csr_wr_mask[CSR_TLBELO_G] & tlbelo1_g;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo1_g <= r_g;
        else
            tlbelo1_g <= 1'b0;
    end
end
always @(posedge clk ) begin
    if(~resetn)
        tlbelo1_ppn <= 20'b0;
    else if(csr_we && csr_wr_num == CSR_TLBELO1)begin
        tlbelo1_ppn <= csr_wr_mask[CSR_TLBELO_PPN_END:CSR_TLBELO_PPN_START] & csr_wr_value[CSR_TLBELO_PPN_END:CSR_TLBELO_PPN_START]
                     | ~csr_wr_mask[CSR_TLBELO_PPN_END:CSR_TLBELO_PPN_START] & tlbelo1_ppn;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            tlbelo1_ppn <= r_ppn1;
        else
            tlbelo1_ppn <= 19'b0;
    end
end
assign csr_tlbelo1 = {4'b0,tlbelo1_ppn,1'b0,tlbelo1_g,tlbelo1_mat,tlbelo1_plv,tlbelo1_d,tlbelo1_v};
//tlbelo0,tlbelo1 end
//asid start
always @(posedge clk ) begin
    if(~resetn)
        asid_asid <= 10'b0;
    else if(csr_we && csr_wr_num == CSR_ASID)begin
        asid_asid <= csr_wr_mask[CSR_ASID_ASID_END:CSR_ASID_ASID_START] & csr_wr_value[CSR_ASID_ASID_END:CSR_ASID_ASID_START]
                     | ~csr_wr_mask[CSR_ASID_ASID_END:CSR_ASID_ASID_START] & asid_asid;
    end
    else if(inst_tlbrd)begin
        if(r_e)
            asid_asid <= r_asid;
        else 
            asid_asid <= 10'b0;
    end
end
assign asid_asidbits = 8'ha;
assign csr_asid = {8'b0,asid_asidbits,6'b0,asid_asid};
//asid end
//tlbrentry start
always @(posedge clk ) begin
    if(~resetn)
        tlbrentry_ppn <= 20'b0;
    else if(csr_we && csr_wr_num == CSR_TLBRENTRY)
        tlbrentry_ppn <= csr_wr_mask[CSR_TLBRENTRY_PPN_END:CSR_TLBRENTRY_PPN_START] & csr_wr_value[CSR_TLBRENTRY_PPN_END:CSR_TLBRENTRY_PPN_START]
                         | ~csr_wr_mask[CSR_TLBRENTRY_PPN_END:CSR_TLBRENTRY_PPN_START] & tlbrentry_ppn;
end
//tlbrentry end
assign csr_rd_value = {32{csr_re}}
                      & ( {32{csr_rd_num == CSR_CRMD}} & csr_crmd
                        | {32{csr_rd_num == CSR_PRMD}} & csr_prmd
                        | {32{csr_rd_num == CSR_ECFG}} & csr_ecfg
                        | {32{csr_rd_num == CSR_ESTAT}} & csr_estat
                        | {32{csr_rd_num == CSR_BADV}} & csr_badv
                        | {32{csr_rd_num == CSR_ERA}}   & csr_era
                        | {32{csr_rd_num == CSR_EENTRY}} & csr_eentry
                        | {32{csr_rd_num == CSR_SAVE0}} & csr_save0_data
                        | {32{csr_rd_num == CSR_SAVE1}} & csr_save1_data
                        | {32{csr_rd_num == CSR_SAVE2}} & csr_save2_data
                        | {32{csr_rd_num == CSR_SAVE3}} & csr_save3_data
                        | {32{csr_rd_num == CSR_TID}} & csr_tid
                        | {32{csr_rd_num == CSR_TCFG}} & csr_tcfg
                        | {32{csr_rd_num == CSR_TVAL}} & csr_tval
                        | {32{csr_rd_num == CSR_TICLR}} & 32'b0
                        | {32{csr_rd_num == CSR_TLBIDX}} & csr_tlbidx
                        | {32{csr_rd_num == CSR_TLBEHI}} & csr_tlbehi
                        | {32{csr_rd_num == CSR_TLBELO0}} & csr_tlbelo0
                        | {32{csr_rd_num == CSR_TLBELO1}} & csr_tlbelo1
                        | {32{csr_rd_num == CSR_ASID}} & csr_asid
                        | {32{csr_rd_num == CSR_TLBRENTRY}} & csr_tlbrentry);
assign csr_eentry_pc = csr_eentry;
assign csr_eertn_pc  = csr_era;
assign s1_va_bit12   = 1'b0;

//tlb search
assign s0_asid       = asid_asid;
assign s0_vppn       = 0;
assign s1_asid       = {10{inst_invtlb}} & inv_asid | {10{~inst_invtlb}} & asid_asid;
assign s1_vppn       = {19{inst_invtlb}} & inv_vppn | {19{~inst_invtlb}} & tlbehi_vppn;

//tlb read
assign r_index      = tlbidx_index;

//tlb fill or write
assign tlb_we       = inst_tlbfill | inst_tlbwr;
assign w_index      = {4{inst_tlbwr}} & tlbidx_index | {4{inst_tlbfill}} & $random;
assign w_e          = ((csr_estat_ecode == 6'h3F) | ~tlbidx_ne) & (inst_tlbfill | inst_tlbwr);
assign w_vppn       = tlbehi_vppn;
assign w_ps         = tlbidx_ps;
assign w_asid       = asid_asid;
assign w_g          = tlbelo0_g & tlbelo1_g;
assign w_ppn0       = tlbelo0_ppn;
assign w_plv0       = tlbelo0_plv;
assign w_mat0       = tlbelo0_mat;
assign w_d0         = tlbelo0_d;
assign w_v0         = tlbelo0_v;
assign w_ppn1       = tlbelo1_ppn;
assign w_plv1       = tlbelo1_plv;
assign w_mat1       = tlbelo1_mat;
assign w_d1         = tlbelo1_d;
assign w_v1         = tlbelo1_v;

tlb mytlb(
    .clk(clk),

    // search port 0 (for fetch)
    .s0_vppn(s0_vppn),
    .s0_va_bit12(s0_va_bit12),
    .s0_asid(s0_asid),
    .s0_found(s0_found),
    .s0_index(s0_index),
    .s0_ppn(s0_ppn),
    .s0_ps(s0_ps),
    .s0_plv(s0_plv),
    .s0_mat(s0_mat),
    .s0_d(s0_d),
    .s0_v(s0_v),

    // search port 1 (for load/store)
    .s1_vppn(s1_vppn),
    .s1_va_bit12(s1_va_bit12),
    .s1_asid(s1_asid),
    .s1_found(s1_found),
    .s1_index(s1_index),
    .s1_ppn(s1_ppn),
    .s1_ps(s1_ps),
    .s1_plv(s1_plv),
    .s1_mat(s1_mat),
    .s1_d(s1_d),
    .s1_v(s1_v),

    // invtlb opcode
    .invtlb_valid(inst_invtlb),
    .invtlb_op(invtlb_op),

    // write port
    .we(tlb_we), //w(rite) e(nable)
    .w_index(w_index),
    .w_e(w_e),
    .w_vppn(w_vppn),
    .w_ps(w_ps),
    .w_asid(w_asid),
    .w_g(w_g),
    .w_ppn0(w_ppn0),
    .w_plv0(w_plv0),
    .w_mat0(w_mat0),
    .w_d0(w_d0),
    .w_v0(w_v0),
    .w_ppn1(w_ppn1),
    .w_plv1(w_plv1),
    .w_mat1(w_mat1),
    .w_d1(w_d1),
    .w_v1(w_v1),

    // read port
    .r_index(r_index),
    .r_e(r_e),
    .r_vppn(r_vppn),
    .r_ps(r_ps),
    .r_asid(r_asid),
    .r_g(r_g),
    .r_ppn0(r_ppn0),
    .r_plv0(r_plv0),
    .r_mat0(r_mat0),
    .r_d0(r_d0),
    .r_v0(r_v0),
    .r_ppn1(r_ppn1),
    .r_plv1(r_plv1),
    .r_mat1(r_mat1),
    .r_d1(r_d1),
    .r_v1(r_v1)
);
endmodule