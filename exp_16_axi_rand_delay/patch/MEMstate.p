--- E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_15_axi\myCPU\MEMstate.v
+++ E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_16_axi_rand_delay\myCPU\MEMstate.v
@@ -95,9 +95,9 @@
     end
     always @(posedge clk) begin
         if(~resetn)
-            {mem_res_from_mem, mem_all, rkd_value} <= 0;
+            {mem_res_from_mem, mem_all} <= 0;
         else if(mem_allowin & exe_ready_go)
-            {mem_res_from_mem, mem_all, rkd_value} <= {exe_res_from_mem, exe_mem_all, exe_rkd_value};
+            {mem_res_from_mem, mem_all} <= {exe_res_from_mem, exe_mem_all};
     end
 
     always @(posedge clk) begin

