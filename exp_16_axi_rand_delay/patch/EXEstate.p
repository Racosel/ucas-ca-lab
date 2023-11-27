--- E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_15_axi\myCPU\EXEstate.v
+++ E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_16_axi_rand_delay\myCPU\EXEstate.v
@@ -1,5 +1,5 @@
 module EXEstate(
-    input              clk,
+    input wire        clk,
     input              resetn,
     output reg         exe_valid,
     // idstate <-> exestate
@@ -200,7 +200,7 @@
     assign {st_b, st_h, st_w}        = exe_mem_all[2:0];
     // assign data_sram_en    = (exe_res_from_mem | mem_we) & ~(mem_ale | mem_exc_flush);//(|mem_exc_rf[6:0]));
     assign data_sram_wr    = mem_we;
-    assign data_sram_req   = (exe_res_from_mem | mem_we) & ~(mem_ale | mem_exc_flush) & ~mem_handled & exe_valid;//(|mem_exc_rf[6:0]))
+    assign data_sram_req   = (exe_res_from_mem | mem_we) & ~(mem_ale | mem_exc_flush) & ~mem_handled & exe_valid & mem_allowin;//(|mem_exc_rf[6:0]))
     assign data_sram_size  = {st_w,st_h};
     assign data_sram_wstrb = {4{st_w}} | {4{st_h}} & {exe_result[1],exe_result[1],~exe_result[1],~exe_result[1]}
                   | {4{st_b}} & {exe_result[1:0]==2'b11,exe_result[1:0]==2'b10,

