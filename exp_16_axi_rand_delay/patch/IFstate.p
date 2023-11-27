--- E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_15_axi\myCPU\IFstate.v
+++ E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_16_axi_rand_delay\myCPU\IFstate.v
@@ -108,6 +108,15 @@
             if_gone <= 1'b1;
     end
 
+    always @(posedge clk ) begin
+        if(~resetn)
+            if_inst_reg <= 32'b0;
+        else if(inst_sram_data_ok)
+            if_inst_reg <= inst_sram_rdata;
+        else
+            if_inst_reg <= if_inst_reg;
+    end
+
     /* Instruction Fetch: use inst_sram */
     // assign inst_sram_en    = if_allowin & resetn;
     assign inst_sram_req = ~pre_if_handled & if_allowin;
@@ -132,7 +141,7 @@
         else if(pre_if_allowin | exec_flush | ertn_flush | br_taken_exe | br_taken_id)
             pc_src <= pre_if_pc_next;
     end
-    assign if_inst = inst_sram_rdata;
+    assign if_inst = {32{~if_handled}} & inst_sram_rdata | {32{if_handled}} & if_inst_reg;
     assign if_exc_rf = | if_pc_reg[1:0];
     assign if_valid_rf = if_valid;
 endmodule

