`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/10/11 13:54:05
// Design Name: 
// Module Name: div
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module csr(
    input         clk,
    input  [0 :0] exc,//should be revised in exp13 only set sys and brk
    input         ertn_flush,
    input         resetn,
    input         csr_re,
    input  [13:0] csr_wr_num,
    input  [13:0] csr_rd_num,
    input         csr_we,
    input  [31:0] csr_wr_mask,
    input  [31:0] csr_wr_value,
    input  [31:0] wb_pc,
    output [31:0] csr_rd_value,
    output [31:0] csr_eentry_pc,
    output [31:0] csr_eertn_pc
);

localparam  CSR_CRMD             = 14'b0,
            CSR_CRMD_PLV_START   = 0,
            CSR_CRMD_PLV_END     = 1,
            CSR_CRMD_IE          = 2,
            CSR_PRMD             = 14'b1,
            CSR_PRMD_PPLV_START  = 0,
            CSR_PRMD_PPLV_END    = 1,
            CSR_PRMD_PIE         = 2,
            CSR_ECFG             = 14'b100,
            CSR_ECFG_LIE_START   = 0,
            CSR_ECFG_LIE_END     = 12,
            CSR_ESTAT            = 14'h5,
            CSR_ESTAT_IS10_START = 0,
            CSR_ESTAT_IS10_END   = 1,
            CSR_ERA              = 14'h6,
            CSR_ERA_PC_START     = 0,
            CSR_ERA_PC_END       = 31,
            CSR_EENTRY           = 14'hc,
            CSR_EENTRY_VA_START  = 12,
            CSR_EENTRY_VA_END    = 31,
            CSR_SAVE0            = 14'h30,
            CSR_SAVE1            = 14'h31,
            CSR_SAVE2            = 14'h32,
            CSR_SAVE3            = 14'h33,
            CSR_SAVE_DATA_START  = 0,
            CSR_SAVE_DATA_END    = 31,
            CSR_TICLR            = 14'h44,
            CSR_TICLR_CLR        = 1;
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
//ticlr start
wire        csr_ticlr_clr;
//ticlr end
wire        wb_ex;
wire        sys;
wire        break;

assign sys   = exc[0];
assign break = 1'b0;
assign wb_ex = sys | break;
assign wb_ecode = {6{sys}} & 6'hb | {6{break}} & 6'hc;
assign wb_esubcode = 9'b0;

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

    csr_estat_is[9:2] = 8'b0;
    // csr_estat_is[9:2] = hw_int_in[7:0]; // not achieved
    csr_estat_is[10] <= 1'b0;

    // if(timer_cnt[31:0] == 32'b0)//not achieved
    //     csr_estat_is[11] <= 1'b1;
    // else if(csr_we && csr_wr_num == CSR_TICLR && csr_wr_mask[CSR_TICLR_CLR] && csr_wr_value[CSR_TICLR_CLR])
    //     csr_estat_is[11] <= 1'b0;
    csr_estat_is[11] <= 1'b0;
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

//eentry start
always @(posedge clk ) begin
    if(~resetn)
        csr_eentry_va <= 20'b0;
    else if(csr_we && csr_wr_num == CSR_EENTRY)
        csr_eentry_va <= csr_wr_mask[CSR_EENTRY_VA_END:CSR_EENTRY_VA_START] & csr_wr_value[CSR_EENTRY_VA_END:CSR_EENTRY_VA_START]
                         | csr_wr_mask[CSR_EENTRY_VA_END:CSR_EENTRY_VA_START] & csr_eentry_va;
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
assign csr_ticlr_clr = 1'b0;
assign csr_rd_value = {32{csr_re}}
                    & ( {32{csr_rd_num == CSR_CRMD}} & csr_crmd
                        | {32{csr_rd_num == CSR_PRMD}} & csr_prmd
                        | {32{csr_rd_num == CSR_ECFG}} & csr_ecfg
                        | {32{csr_rd_num == CSR_ESTAT}} & csr_estat
                        | {32{csr_rd_num == CSR_ERA}}   & csr_era
                        | {32{csr_rd_num == CSR_EENTRY}} & csr_eentry
                        | {32{csr_rd_num == CSR_SAVE0}} & csr_save0_data
                        | {32{csr_rd_num == CSR_SAVE1}} & csr_save1_data
                        | {32{csr_rd_num == CSR_SAVE2}} & csr_save2_data
                        | {32{csr_rd_num == CSR_SAVE3}} & csr_save3_data);
assign csr_eentry_pc = csr_eentry;
assign csr_eertn_pc  = csr_era;
endmodule