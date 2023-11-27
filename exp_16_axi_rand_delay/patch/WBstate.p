--- E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_15_axi\myCPU\WBstate.v
+++ E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_16_axi_rand_delay\myCPU\WBstate.v
@@ -4,7 +4,7 @@
     output reg         wb_valid,
     // memstate <-> wbstate
     output             wb_allowin,
-    input       [52:0] mem_rf_all, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata_reg}
+    input       [53:0] mem_rf_all, // {mem_rf_we, mem_rf_waddr, mem_rf_wdata_reg}
     input              mem_to_wb_valid,
     input       [31:0] mem_pc,    
     // debug info

