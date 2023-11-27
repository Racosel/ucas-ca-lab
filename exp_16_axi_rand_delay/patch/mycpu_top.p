--- E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_15_axi\myCPU\mycpu_top.v
+++ E:\UCAS\3A\CA-Lab\ucas-ca-lab\exp_16_axi_rand_delay\myCPU\mycpu_top.v
@@ -81,376 +81,354 @@
 	wire [ 4:0] cpu_debug_wb_rf_wnum;
 	wire [31:0] cpu_debug_wb_rf_wdata;
 
-/*
- *	THIS MODULE: parameters
- */
-
-	parameter INIT    	= 5'b00001,
-			  WAIT0		= 5'b00010,
-			  WAIT 		= 5'b00100,
-			  WAIT2  	= 5'b01000,
-			  DONE    	= 5'b10000;
-
-	parameter ID_INST	= 4'b0000,
-			  ID_DATA	= 4'b0001;
-
-/*
- * 	THIS MODULE: State Machine registers
- */
-
-	reg [ 4:0] ar_state, r_state, w_state, b_state;
-
-	wire [3:0] arid_w;
-	reg [ 3:0] arid_r;
-	reg [31:0] araddr_r;
-	reg [ 7:0] arlen_r;
-	reg [ 2:0] arsize_r;
-	reg [ 1:0] arburst_r;
-	reg [ 1:0] arlock_r;
-	reg [ 3:0] arcache_r;
-	reg [ 2:0] arprot_r;
-
-	reg [ 3:0] rid_r;
-	reg [31:0] rdata_r;
-
-	wire [3:0] awid_w;
-	reg [ 3:0] awid_r;
-	reg [31:0] awaddr_r;
-	reg [ 7:0] awlen_r;
-	reg [ 2:0] awsize_r;
-	reg [ 1:0] awburst_r;
-	reg [ 1:0] awlock_r;
-	reg [ 3:0] awcache_r;
-	reg [ 2:0] awprot_r;
-
-	reg [ 3:0] wid_r;
-	reg [31:0] wdata_r;
-	reg [ 3:0] wstrb_r;
-	reg        wlast_r;
-
-	reg [3:0] bid_r;
-
-
-
-/*
- *	THIS MODULE: State Machines (state transition logic)
- */
-
-	// auxilary classfication
-	wire req_read_data  = cpu_data_sram_req && !cpu_data_sram_wr;
-	wire req_read_inst  = cpu_inst_sram_req && !cpu_inst_sram_wr;
-	wire req_write_data = cpu_data_sram_req &&  cpu_data_sram_wr;
-		// impossible to write inst sram
+    localparam INIT       	= 4'b1,
+			   WAIT_TASK	= 4'b10,	//wait for single task
+               WAIT_OTHER 	= 4'b100,	//wait for other machine
+			   WAIT_WIRE 	= 4'b1000;	//wait for the wire
+    
+
+/*
+*    VIRTUAL WIRES CAN BEE SEEN BY FRONT MACHINE
+*/
+
+	wire 	  	inst_addr_handled;
+	wire		inst_data_handled;
+	wire		data_addr_handled;
+	wire		data_data_handled;
+/*
+ *   MACHINES
+ */
+    reg [3:0] inst_addr_port;
+    // reg [3:0] inst_data_port;//no need to wait for req just wait for other machine
+    reg [3:0] data_addr_port;
+    // reg [3:0] data_data_port;//no need to wait for req just wait for other machine
+
+    always @(posedge aclk ) begin
+        if(~aresetn)
+            inst_addr_port <= INIT;
+        else begin
+            if(inst_addr_port == INIT)
+                inst_addr_port <= WAIT_TASK;
+			else if(inst_addr_port == WAIT_TASK)begin
+				if(cpu_inst_sram_req)
+					inst_addr_port <= WAIT_WIRE;
+				else
+					inst_addr_port <= WAIT_TASK;
+			end
+            else if(inst_addr_port == WAIT_WIRE)
+                if(inst_addr_handled)
+                    inst_addr_port <= WAIT_TASK;
+                else
+                    inst_addr_port <= WAIT_WIRE;
+			else 
+				inst_addr_port <= inst_addr_port;
+        end
+    end
+
+	// always @(posedge aclk ) begin
+	// 	if(~aresetn)
+	// 		inst_data_port <= INIT;
+	// 	else begin
+	// 		if(inst_data_port == INIT)
+	// 			inst_data_port <= WAIT_OTHER;
+	// 		else if(inst_data_port == WAIT_OTHER) begin
+	// 			if(inst_addr_port == WAIT_OTHER)
+	// 				inst_data_port <= WAIT_WIRE;
+	// 			else
+	// 				inst_data_port <= WAIT_OTHER;
+	// 		end
+	// 		else if(inst_data_port == WAIT_WIRE)begin
+	// 			if(inst_data_handled)
+	// 				inst_data_port <= WAIT_OTHER;
+	// 			else
+	// 				inst_data_port <= WAIT_WIRE;
+	// 		end
+	// 	end
+	// end
+
+	always @(posedge aclk ) begin
+        if(~aresetn)
+            data_addr_port <= INIT;
+        else begin
+            if(data_addr_port == INIT)
+                data_addr_port <= WAIT_TASK;
+			else if(data_addr_port == WAIT_TASK)begin
+				if(cpu_data_sram_req)
+					data_addr_port <= WAIT_WIRE;// data_addr_port <= WAIT_OTHER;
+				else
+					data_addr_port <= WAIT_TASK;
+			end
+			// if(data_addr_port == WAIT_OTHER)begin
+			// 	if(data_data_port == WAIT_OTHER)
+			// 		data_addr_port <= WAIT_WIRE
+			// 	else
+			// 		data_addr_port <= WAIT_OTHER;
+			// end
+            else if(data_addr_port == WAIT_WIRE)
+                if(data_addr_handled)
+                    data_addr_port <= WAIT_TASK;
+                else
+                    data_addr_port <= WAIT_WIRE;
+			else 
+				data_addr_port <= data_addr_port;
+        end
+    end
+
+	// always @(posedge aclk ) begin
+	// 	if(~aresetn)
+	// 		data_data_port <= INIT;
+	// 	else begin
+	// 		if(data_data_port == INIT)
+	// 			data_data_port <= WAIT_OTHER;
+	// 		else if(data_data_port == WAIT_OTHER) begin
+	// 			if(data_addr_port == WAIT_OTHER)
+	// 				data_data_port <= WAIT_WIRE;
+	// 			else
+	// 				data_data_port <= WAIT_OTHER;
+	// 		end
+	// 		else if(data_data_port == WAIT_WIRE)begin
+	// 			if(data_data_handled)
+	// 				data_data_port <= WAIT_OTHER;
+	// 			else
+	// 				data_data_port <= WAIT_WIRE;
+	// 		end
+	// 	end
+	// 	else
+	// 		inst_data_port <= inst_data_port;
+	// end
+
+/*
+ *  PHOTO TAKER:take photos when req meet addr_ok
+ */
+	reg	 [31:0] inst_addr_r;
+	reg			inst_addr_valid;
+
+	reg  [31:0] data_addr_r;
+	reg	 		data_wr_r;
+	reg  [1 :0] data_size_r;
+	reg  [3 :0] data_strb_r;
+	reg	 [31:0] data_data_r;
+	reg			data_valid;
+
+	always @(posedge aclk ) begin
+		if(~aresetn)
+			inst_addr_r <= 0;
+		else begin
+			if(cpu_inst_sram_addr_ok & cpu_inst_sram_req)
+				inst_addr_r <= cpu_inst_sram_addr;
+			else
+				inst_addr_r <= inst_addr_r;
+		end
+	end
+
+	always @(posedge aclk ) begin
+		if(~aresetn)
+			inst_addr_valid <= 0;
+		else begin
+			if(cpu_inst_sram_addr_ok & cpu_inst_sram_req)
+				inst_addr_valid <= 1;
+			else if(inst_addr_handled)
+				inst_addr_valid <= 0;
+			else
+				inst_addr_valid <= inst_addr_valid;
+		end
+	end
+
+	always @(posedge aclk ) begin
+		if(~aresetn)begin
+			data_addr_r <= 0;
+			data_wr_r	<= 0;
+			data_size_r <= 0;
+			data_strb_r <= 0;
+			data_data_r <= 0;
+		end
+		else begin
+			if(cpu_data_sram_addr_ok & cpu_data_sram_req)begin
+				data_addr_r <= cpu_data_sram_addr;
+				data_wr_r	<= cpu_data_sram_wr;
+				data_size_r <= cpu_data_sram_size;
+				data_strb_r <= cpu_data_sram_wstrb;
+				data_data_r <= cpu_data_sram_wdata;
+			end
+			else begin
+				data_addr_r <= data_addr_r;
+				data_wr_r	<= data_wr_r;
+				data_size_r <= data_size_r;
+				data_strb_r <= data_strb_r;
+				data_data_r <= data_data_r;
+			end
+		end
+	end
+
+	always @(posedge aclk ) begin
+		if(~aresetn)
+			data_valid <= 1'b0;
+		else begin
+			if(cpu_data_sram_addr_ok & cpu_data_sram_req)
+				data_valid <= 1;
+			else if(data_addr_handled)
+				data_valid <= 0;
+			else
+				data_valid <= data_valid;
+		end
+	end
+
+/*
+ *  SELECTER:select who to occupy the read channel
+ */
+	//extrem remind always remember to avoid the loooooooooooopppppppp
+	reg [1:0] selecter;
+	reg [1:0] back_selecter;
+	always @(posedge aclk ) begin
+		if(~aresetn)
+			selecter <= 2'b0;
+		else begin
+			if(selecter == 2'b0)begin
+				if(data_valid == 1 && ~data_wr_r)
+					selecter <= 2'b10;
+				else if(inst_addr_valid == 1)
+					selecter <= 2'b1;
+				else
+					selecter <= 2'b0;
+			end
+			else if(selecter == 2'b1)begin
+				if(arvalid & arready)
+					selecter <= 2'b0;
+				else
+					selecter <= 2'b1;
+			end
+			else if(selecter == 2'b10)begin
+				if(arvalid & arready)
+					selecter <= 2'b0;
+				else
+					selecter <= 2'b10; 
+			end
+			else
+				selecter <= selecter;
+		end
+	end
+
+/*
+ * WRITER:make it easy to write
+ */
+
+	reg			handled_aw;
+	reg			handled_w;
+	reg  		valid_b;
+	reg	 [31:0] b_addr;
+	wire		rw_conflict;
 	
-	wire read_req_from_cpu  =  req_read_data || req_read_inst;
-	// wire write_req_from_cpu = req_write_data && !read_req_from_cpu;
-	wire write_req_from_cpu = req_write_data;
-		// STRICTLY NOT CONTAIN READ REQUEST
-
-	/*
-	 *	AR Channel: Read Address Channel (state transition logic)
-	 *	
-	 *	INIT -> WAIT: 	1. 	read request from cpu
-	 *					2. 	r_state == INIT (R Channel is ready to accept request)
-	 *  WAIT -> DONE: 		arready && arvalid
-	 *	DONE -> INIT: 		NOTHING
-	 */
-	always @(posedge aclk) begin
-		if (~aresetn)
-			ar_state <= INIT;
-		else begin
-			case (ar_state)
-
-				INIT: begin
-					if (req_read_data & cpu_data_sram_req | cpu_inst_sram_req & cpu_inst_sram_addr_ok)
-						ar_state <= WAIT0;
-					else
-						ar_state <= INIT;
-				end
-
-				WAIT0:begin
-					if(r_state == INIT)
-						ar_state <= WAIT;
-					else
-						ar_state <= WAIT0;
-				end
-
-				WAIT: begin
-					if (arready && arvalid)
-						ar_state <= DONE;
-					else
-						ar_state <= WAIT;
-				end
-
-				DONE:
-					ar_state <= INIT;
-
-				default:
-					ar_state <= INIT;
-
-			endcase
-		end
-	end
-
-
-	/*
-	 *	R Channel: Read Data Channel (state transition logic)
-	 *	
-	 *	INIT -> WAIT: 	1. 	ar_state == WAIT (AR Channel accepted request)
-	 *					2. 	arready && arvalid
-	 *	WAIT -> DONE: 		rvalid && rlast && rready (Need to add burst support in future)
-	 *	DONE -> INIT: 		NOTHING
-	 */
-	always @(posedge aclk) begin
-		if (~aresetn)
-			r_state <= INIT;
-		else begin
-			case (r_state)
-
-				INIT: begin
-					if (arready && arvalid && ar_state == WAIT)
-						r_state <= WAIT;
-					else
-						r_state <= INIT;
-				end
-
-				WAIT: begin
-					if (rvalid && rlast && rready)	// FIXME: rlast will be used in cache
-						r_state <= DONE;
-					else
-						r_state <= WAIT;
-				end
-
-				DONE:
-						r_state <= INIT;
-
-				default:
-					r_state <= INIT;
-
-			endcase
-		end
-	end
-
+	always @(posedge aclk ) begin
+		if(~aresetn)
+			handled_aw <= 1'b0;
+		else begin
+			if(handled_aw == 1'b0)begin
+				if(awvalid & awready)
+					handled_aw <= 1'b1;
+				else
+					handled_aw <= 1'b0;
+			end
+			else begin
+				if(handled_w == 1'b1)
+					handled_aw <= 1'b0;
+				else
+					handled_aw <= 1'b1;
+			end
+		end
+	end
+
+	always @(posedge aclk ) begin
+		if(~aresetn)
+			handled_w <= 1'b0;
+		else begin
+			if(handled_w == 1'b0)begin
+				if(wvalid & wready)
+					handled_w <= 1'b1;
+				else
+					handled_w <= 1'b0;
+			end
+			else begin
+				if(handled_aw == 1'b1)
+					handled_w <= 1'b0;
+				else
+					handled_w <= 1'b1;
+			end
+		end
+	end
+
+	always @(posedge aclk ) begin
+		if(~aresetn)
+			valid_b <= 1'b0;
+		else begin
+			if(valid_b == 1'b0)begin
+				if(data_addr_handled & data_wr_r)
+					valid_b <= 1'b1;
+				else
+					valid_b <= 1'b0;
+			end
+			else begin
+				if(bvalid & bready)
+					valid_b <= 1'b0;
+				else
+					valid_b <= 1'b1;
+			end
+		end
+	end
+
+	always @(posedge aclk ) begin
+		if(~aresetn)
+			b_addr <= 32'b0;
+		else begin
+			if(handled_aw & handled_w)
+				b_addr <= data_addr_r;
+			else
+				b_addr <= b_addr;
+		end
+	end
+
+	assign rw_conflict = (araddr == awaddr) & awvalid | (b_addr == araddr) & valid_b;
+
+	assign arid = {3'b0,selecter[1]};
+	assign araddr = {32{selecter[0]}} & inst_addr_r | {32{selecter[1]}} & data_addr_r;
+	assign arlen = 0;
+	assign arsize = 3'b10;
+	assign arburst = 2'b1;
+	assign arlock = 0;
+	assign arcache = 0;
+	assign arprot = 0;
+	assign arvalid = (selecter[0] | selecter[1]) & ~rw_conflict;
+
+	assign rready = 1;
 	
-	/*
-	 *	AW & W Channel: Write Address & Data Channel (state transition logic)
-	 *
-	 *	INIT -> WAIT: 	1. 	write request from cpu
-	 *					2. 	b_state == INIT (B Channel is ready to accept request)
-	 *	WAIT -> WAIT2: 	  	awready && awvalid	(FIRST ENSURE THE AW CHANNEL IS READY)
-	 *	WAIT2 -> DONE: 	 	wready && wvalid
-	 *	DONE -> INIT: 		NOTHING
-	 */
-	always @(posedge aclk) begin
-		if (~aresetn)
-			w_state <= INIT;
-		else begin
-			case (w_state)
-
-				INIT: begin
-					if (cpu_data_sram_addr_ok & req_write_data)
-						w_state <= WAIT0;
-					else
-						w_state <= INIT;
-				end
-
-				WAIT0:begin
-					if(b_state == INIT)
-						w_state <= WAIT;
-					else
-						w_state <= WAIT0;
-				end
-
-				WAIT: begin
-					if (awready && awvalid)
-						w_state <= WAIT2;
-					else
-						w_state <= WAIT;
-				end
-
-				WAIT2: begin
-					if (wready && wvalid)
-						w_state <= DONE;
-					else
-						w_state <= WAIT2;
-				end
-
-				DONE:
-					w_state <= INIT;
-
-				default:
-					w_state <= INIT;
-
-			endcase
-		end
-	end
-
-	/*
-	 *	B Channel: Write Response Channel (state transition logic)
-	 *
-	 *	INIT -> WAIT: 	1. 	w_state == WAIT2 (W Channel accepted request)
-	 *					2. 	wready && wvalid
-	 *	WAIT -> DONE: 		bready && bvalid
-	 *	DONE -> INIT: 		NOTHING
-	 */
-	always @(posedge aclk) begin
-		if (~aresetn)
-			b_state <= INIT;
-		else begin
-			case (b_state)
-
-				INIT: begin
-					if (wready && wvalid && w_state == WAIT2)
-						b_state <= WAIT;
-					else
-						b_state <= INIT;
-				end
-
-				WAIT: begin
-					if (bvalid)
-						b_state <= DONE;
-					else
-						b_state <= WAIT;
-				end
-
-				DONE:
-					b_state <= INIT;
-
-				default:
-					b_state <= INIT;
-
-			endcase
-		end
-	end
-
-/*
- *	THIS MODULE: State Machines (output logic)
- */
-
-	/*
-	 *	AR Channel: Read Address Channel (output logic)
-	 */
-	assign arid_w = req_read_data ? ID_DATA : ID_INST;
-	always @(posedge aclk) begin
-		if (req_read_data & r_data_addr_ok | cpu_inst_sram_req & cpu_inst_sram_addr_ok) begin
-			arid_r    <= arid_w;
-			araddr_r  <= req_read_data ? cpu_data_sram_addr : cpu_inst_sram_addr;
-			arlen_r   <= 8'd0;
-			arsize_r  <= {1'b0, req_read_data ? cpu_data_sram_size : cpu_inst_sram_size};
-			arburst_r <= 2'b1;
-			arlock_r  <= 2'b0;
-			arcache_r <= 4'b0;
-			arprot_r  <= 3'b0;
-		end
-	end
-
-	/*
-	 *	R Channel: Read Data Channel (output logic)
-	 */
-	always @(posedge aclk) begin
-		if (~aresetn) begin
-			rid_r   <=  4'b0;
-			rdata_r <= 32'b0;
-		end
-		else if (r_state == WAIT) begin
-			rid_r   <= rid;
-			rdata_r <= rdata;
-		end
-	end
-
-	/*
-	 *	AW & W Channel: Write Address & Data Channel (output logic)
-	 */
-	assign awid_w = ID_DATA;
-	always @(posedge aclk) begin
-		if (cpu_data_sram_addr_ok & req_write_data) begin
-			awid_r    <= awid_w;
-			awaddr_r  <= cpu_data_sram_addr;
-			awlen_r   <= 8'b0;
-			awsize_r  <= {1'b0, cpu_data_sram_size};
-			awburst_r <= 2'b1;
-			awlock_r  <= 2'b0;
-			awcache_r <= 4'b0;
-			awprot_r  <= 3'b0;
-
-			wid_r     <= ID_DATA;
-			wdata_r   <= cpu_data_sram_wdata;
-			wstrb_r   <= cpu_data_sram_wstrb;
-			wlast_r   <= 1'b1;
-		end
-	end
-
-	/*
-	 *	B Channel: Write Response Channel (output logic)
-	 */
-	always @(posedge aclk) begin
-		if (~aresetn)
-			bid_r   <= 4'b0;
-		else if (b_state == WAIT)
-			bid_r <= bid;
-	end
-
-/*
- *	CPU: SRAM Interface (cpu_core::in)
- */
-
-	// auxilary classfication
-
-	// ready to accept request, same as AR Channel's INIT -> WAIT logic
-	wire r_inst_addr_ok = (ar_state == INIT) && (arid_w == ID_INST) && aresetn;
-	wire r_data_addr_ok = (ar_state == INIT) && (arid_w == ID_DATA) && aresetn;
-
-	wire r_inst_data_ok = ( r_state == DONE) && ( rid_r == ID_INST);
-	wire r_data_data_ok = ( r_state == DONE) && ( rid_r == ID_DATA);
-
-	// ready to accept request, same as AW Channel's INIT -> WAIT logic
-	wire w_data_addr_ok = (write_req_from_cpu && w_state == INIT) && (awid_w == ID_DATA) && aresetn;
-
-	wire w_data_data_ok = ( b_state == DONE) && ( bid_r == ID_DATA);
-
-	// cpu interface
-	assign cpu_inst_sram_rdata   = rdata_r;	// they are the same
-	assign cpu_data_sram_rdata   = rdata_r;	// cause only one of them is valid
-	assign cpu_inst_sram_addr_ok = r_inst_addr_ok;
-	assign cpu_inst_sram_data_ok = r_inst_data_ok;
-	assign cpu_data_sram_addr_ok = r_data_addr_ok || w_data_addr_ok;
-	assign cpu_data_sram_data_ok = r_data_data_ok || w_data_data_ok;
-
-
-/*
- *	THIS MODULE: AXI Interface (cpu_top::out)
- */
-	assign arid		= arid_r;
-	assign araddr	= araddr_r;
-	assign arlen	= arlen_r;
-	assign arsize	= arsize_r;
-	assign arburst	= arburst_r;
-	assign arlock	= arlock_r;
-	assign arcache	= arcache_r;
-	assign arprot	= arprot_r;
-	
-	assign awid 	= awid_r; 
-	assign awaddr 	= awaddr_r;
-	assign awlen 	= awlen_r;
-	assign awsize 	= awsize_r;
-	assign awburst 	= awburst_r;
-	assign awlock 	= awlock_r;
-	assign awcache 	= awcache_r;
-	assign awprot 	= awprot_r;
-	
-	assign wid 		= wid_r;
-	assign wdata 	= wdata_r;
-	assign wstrb 	= wstrb_r;
-	assign wlast 	= wlast_r;
-
-	// signals need async reset
-	assign arvalid	= (ar_state == WAIT ) &&  aresetn;	// RESET VAL: 0
-	assign rready 	= ( r_state == WAIT ) || ~aresetn;	// RESET VAL: 1
-	assign awvalid 	= ( w_state == WAIT ) &&  aresetn;	// RESET VAL: 0
-	assign wvalid 	= ( w_state == WAIT2) &&  aresetn;	// RESET VAL: 0
-	assign bready 	= ( b_state == WAIT ) || ~aresetn;	// RESET VAL: 1
-
-
+
+	assign awid = 4'b1;
+	assign awaddr = data_addr_r;
+	assign awlen = 0;
+	assign awsize = data_size_r;
+	assign awburst = 2'b1;
+	assign awlen = 0;
+	assign awcache = 0;
+	assign awprot = 0;
+	assign awvalid = ~handled_aw & data_wr_r & (data_addr_port == WAIT_WIRE);
+
+	assign wid = 4'b1;
+	assign wdata = data_data_r;
+	assign wstrb = data_strb_r;
+	assign wlast = 1;
+	assign wvalid = ~handled_w & data_wr_r & (data_addr_port == WAIT_WIRE);
+
+	assign bready = 1;
+
+	assign cpu_inst_sram_addr_ok = (inst_addr_port == WAIT_TASK);
+	assign cpu_inst_sram_data_ok = (rid == 0) & rready & rvalid;
+	assign cpu_inst_sram_rdata = {32{cpu_inst_sram_data_ok}} & rdata;
+
+	assign cpu_data_sram_addr_ok = (data_addr_port == WAIT_TASK);
+	assign cpu_data_sram_data_ok = (rid == 1) & rready & rvalid | (bid == 1) & bready & bvalid;
+	assign cpu_data_sram_rdata = {32{cpu_data_sram_data_ok}} & rdata;
+
+	assign inst_addr_handled = selecter[0] & arready & arvalid;
+	assign data_addr_handled = selecter[1] & arready & arvalid | handled_aw & handled_w;
 /*
  *	CPU: Trace Debug Interface (cpu_core::out)
  */

