--- E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_15_axi\myCPU\csr.v
+++ E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_16_axi_rand_delay\myCPU\csr.v
@@ -11,7 +11,6 @@
     input         csr_we,
     input  [31:0] csr_wr_mask,
     input  [31:0] csr_wr_value,
-    input  [31:0] badv_input,
     input  [31:0] wb_pc,
     input  [31:0] wb_fault_vaddr,
     output [31:0] csr_rd_value,

