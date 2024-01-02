module mycpu_top (
/*
 *	THIS MODULE: wires (mycpu_top::in/out)
 */
	input  wire        aclk,
	input  wire        aresetn,
	
	output wire [ 3:0] arid,
	output wire [31:0] araddr,
	output wire [ 7:0] arlen,
	output wire [ 2:0] arsize,
	output wire [ 1:0] arburst,
	output wire [ 1:0] arlock,
	output wire [ 3:0] arcache,
	output wire [ 2:0] arprot,
	output wire        arvalid,
	input  wire        arready,

	input  wire [ 3:0] rid,
	input  wire [31:0] rdata,
	input  wire [ 1:0] rresp,
	input  wire        rlast,
	input  wire        rvalid,
	output wire        rready,

	output wire [ 3:0] awid,
	output wire [31:0] awaddr,
	output wire [ 7:0] awlen,
	output wire [ 2:0] awsize,
	output wire [ 1:0] awburst,
	output wire [ 1:0] awlock,
	output wire [ 3:0] awcache,
	output wire [ 2:0] awprot,
	output wire        awvalid,
	input  wire        awready,

	output wire [ 3:0] wid,
	output wire [31:0] wdata,
	output wire [ 3:0] wstrb,
	output wire        wlast,
	output wire        wvalid,
	input  wire        wready,

	input  wire [ 3:0] bid,
	input  wire [ 1:0] bresp,
	input  wire        bvalid,
	output wire        bready,
	
	output wire [31:0] debug_wb_pc,
	output wire [ 3:0] debug_wb_rf_we,
	output wire [ 4:0] debug_wb_rf_wnum,
	output wire [31:0] debug_wb_rf_wdata
);

/*
 *	CPU: wires (cpu_core::in/out)
 */

	wire        cpu_inst_sram_req;
	wire        cpu_inst_sram_wr;
	wire [ 1:0] cpu_inst_sram_size;
	wire [ 3:0] cpu_inst_sram_wstrb;
	wire [31:0] cpu_inst_sram_addr;
	wire [31:0] cpu_inst_sram_wdata;
	wire        cpu_inst_sram_addr_ok;
	wire        cpu_inst_sram_data_ok;
	wire [31:0] cpu_inst_sram_rdata;

	wire        cpu_data_sram_req;
	wire        cpu_data_sram_wr;
	wire [ 1:0] cpu_data_sram_size;
	wire [ 3:0] cpu_data_sram_wstrb;
	wire [31:0] cpu_data_sram_addr;
	wire [31:0] cpu_data_sram_wdata;
	wire        cpu_data_sram_addr_ok;
	wire        cpu_data_sram_data_ok;
	wire [31:0] cpu_data_sram_rdata;

	wire [31:0] cpu_debug_wb_pc;
	wire [ 3:0] cpu_debug_wb_rf_we;
	wire [ 4:0] cpu_debug_wb_rf_wnum;
	wire [31:0] cpu_debug_wb_rf_wdata;

    localparam INIT       	= 4'b1,
			   WAIT_TASK	= 4'b10,	//wait for single task
               WAIT_OTHER 	= 4'b100,	//wait for other machine
			   WAIT_WIRE 	= 4'b1000;	//wait for the wire
    
/*
 *  CACHE WIRES
 */

	wire            icache_rd_rdy;
    wire            icache_ret_valid;
    wire            icache_ret_last;
	wire    [ 31:0] icache_ret_data;
    wire            icache_rd_req;
    wire    [  2:0] icache_rd_type;
    wire    [ 31:0] icache_rd_addr;
    
    wire            icache_wr_rdy;
    wire            icache_wr_req;
    wire    [  2:0] icache_wr_type;
    wire    [ 31:0] icache_wr_addr;
    wire    [  3:0] icache_wr_wstrb;
    wire    [127:0] icache_wr_data;

/*
*    VIRTUAL WIRES CAN BEE SEEN BY FRONT MACHINE
*/

	wire 	  	inst_addr_handled;
	wire		inst_data_handled;
	wire		data_addr_handled;
	wire		data_data_handled;
/*
 *   MACHINES
 */
    reg [3:0] inst_addr_port;
    // reg [3:0] inst_data_port;//no need to wait for req just wait for other machine
    reg [3:0] data_addr_port;
    // reg [3:0] data_data_port;//no need to wait for req just wait for other machine

    always @(posedge aclk ) begin
        if(~aresetn)
            inst_addr_port <= INIT;
        else begin
            if(inst_addr_port == INIT)
                inst_addr_port <= WAIT_TASK;
			else if(inst_addr_port == WAIT_TASK)begin
				if(icache_rd_req)
					inst_addr_port <= WAIT_WIRE;
				else
					inst_addr_port <= WAIT_TASK;
			end
            else if(inst_addr_port == WAIT_WIRE)
                if(inst_addr_handled)
                    inst_addr_port <= WAIT_TASK;
                else
                    inst_addr_port <= WAIT_WIRE;
			else 
				inst_addr_port <= inst_addr_port;
        end
    end

	// always @(posedge aclk ) begin
	// 	if(~aresetn)
	// 		inst_data_port <= INIT;
	// 	else begin
	// 		if(inst_data_port == INIT)
	// 			inst_data_port <= WAIT_OTHER;
	// 		else if(inst_data_port == WAIT_OTHER) begin
	// 			if(inst_addr_port == WAIT_OTHER)
	// 				inst_data_port <= WAIT_WIRE;
	// 			else
	// 				inst_data_port <= WAIT_OTHER;
	// 		end
	// 		else if(inst_data_port == WAIT_WIRE)begin
	// 			if(inst_data_handled)
	// 				inst_data_port <= WAIT_OTHER;
	// 			else
	// 				inst_data_port <= WAIT_WIRE;
	// 		end
	// 	end
	// end

	always @(posedge aclk ) begin
        if(~aresetn)
            data_addr_port <= INIT;
        else begin
            if(data_addr_port == INIT)
                data_addr_port <= WAIT_TASK;
			else if(data_addr_port == WAIT_TASK)begin
				if(cpu_data_sram_req)
					data_addr_port <= WAIT_WIRE;// data_addr_port <= WAIT_OTHER;
				else
					data_addr_port <= WAIT_TASK;
			end
			// if(data_addr_port == WAIT_OTHER)begin
			// 	if(data_data_port == WAIT_OTHER)
			// 		data_addr_port <= WAIT_WIRE
			// 	else
			// 		data_addr_port <= WAIT_OTHER;
			// end
            else if(data_addr_port == WAIT_WIRE)
                if(data_addr_handled)
                    data_addr_port <= WAIT_TASK;
                else
                    data_addr_port <= WAIT_WIRE;
			else 
				data_addr_port <= data_addr_port;
        end
    end

	// always @(posedge aclk ) begin
	// 	if(~aresetn)
	// 		data_data_port <= INIT;
	// 	else begin
	// 		if(data_data_port == INIT)
	// 			data_data_port <= WAIT_OTHER;
	// 		else if(data_data_port == WAIT_OTHER) begin
	// 			if(data_addr_port == WAIT_OTHER)
	// 				data_data_port <= WAIT_WIRE;
	// 			else
	// 				data_data_port <= WAIT_OTHER;
	// 		end
	// 		else if(data_data_port == WAIT_WIRE)begin
	// 			if(data_data_handled)
	// 				data_data_port <= WAIT_OTHER;
	// 			else
	// 				data_data_port <= WAIT_WIRE;
	// 		end
	// 	end
	// 	else
	// 		inst_data_port <= inst_data_port;
	// end

/*
 *  PHOTO TAKER:take photos when req meet addr_ok
 */
	reg	 [31:0] inst_addr_r;
	reg			inst_addr_valid;
	reg  [2 :0] icache_rd_type_r;

	reg  [31:0] data_addr_r;
	reg	 		data_wr_r;
	reg  [1 :0] data_size_r;
	reg  [3 :0] data_strb_r;
	reg	 [31:0] data_data_r;
	reg			data_valid;

	always @(posedge aclk ) begin
		if(~aresetn)
			inst_addr_r <= 0;
		else begin
			if(icache_rd_rdy & icache_rd_req)begin
				inst_addr_r <= icache_rd_addr;
				icache_rd_type_r <= icache_rd_type;
			end
			else begin
				inst_addr_r <= inst_addr_r;
				icache_rd_type_r <= icache_rd_type;
			end
		end
	end

	always @(posedge aclk ) begin
		if(~aresetn)
			inst_addr_valid <= 0;
		else begin
			if(icache_rd_rdy & icache_rd_req)
				inst_addr_valid <= 1;
			else if(inst_addr_handled)
				inst_addr_valid <= 0;
			else
				inst_addr_valid <= inst_addr_valid;
		end
	end

	always @(posedge aclk ) begin
		if(~aresetn)begin
			data_addr_r <= 0;
			data_wr_r	<= 0;
			data_size_r <= 0;
			data_strb_r <= 0;
			data_data_r <= 0;
		end
		else begin
			if(cpu_data_sram_addr_ok & cpu_data_sram_req)begin
				data_addr_r <= cpu_data_sram_addr;
				data_wr_r	<= cpu_data_sram_wr;
				data_size_r <= cpu_data_sram_size;
				data_strb_r <= cpu_data_sram_wstrb;
				data_data_r <= cpu_data_sram_wdata;
			end
			else begin
				data_addr_r <= data_addr_r;
				data_wr_r	<= data_wr_r;
				data_size_r <= data_size_r;
				data_strb_r <= data_strb_r;
				data_data_r <= data_data_r;
			end
		end
	end

	always @(posedge aclk ) begin
		if(~aresetn)
			data_valid <= 1'b0;
		else begin
			if(cpu_data_sram_addr_ok & cpu_data_sram_req)
				data_valid <= 1;
			else if(data_addr_handled)
				data_valid <= 0;
			else
				data_valid <= data_valid;
		end
	end

/*
 *  SELECTER:select who to occupy the read channel
 */
	//extrem remind always remember to avoid the loooooooooooopppppppp
	reg [1:0] selecter;
	reg [1:0] back_selecter;
	always @(posedge aclk ) begin
		if(~aresetn)
			selecter <= 2'b0;
		else begin
			if(selecter == 2'b0)begin
				if(data_valid == 1 && ~data_wr_r)
					selecter <= 2'b10;
				else if(inst_addr_valid == 1)
					selecter <= 2'b1;
				else
					selecter <= 2'b0;
			end
			else if(selecter == 2'b1)begin
				if(arvalid & arready)
					selecter <= 2'b0;
				else
					selecter <= 2'b1;
			end
			else if(selecter == 2'b10)begin
				if(arvalid & arready)
					selecter <= 2'b0;
				else
					selecter <= 2'b10; 
			end
			else
				selecter <= selecter;
		end
	end

/*
 * WRITER:make it easy to write
 */

	reg			handled_aw;
	reg			handled_w;
	reg  		valid_b;
	reg	 [31:0] b_addr;
	wire		rw_conflict;
	
	always @(posedge aclk ) begin
		if(~aresetn)
			handled_aw <= 1'b0;
		else begin
			if(handled_aw == 1'b0)begin
				if(awvalid & awready)
					handled_aw <= 1'b1;
				else
					handled_aw <= 1'b0;
			end
			else begin
				if(handled_w == 1'b1)
					handled_aw <= 1'b0;
				else
					handled_aw <= 1'b1;
			end
		end
	end

	always @(posedge aclk ) begin
		if(~aresetn)
			handled_w <= 1'b0;
		else begin
			if(handled_w == 1'b0)begin
				if(wvalid & wready)
					handled_w <= 1'b1;
				else
					handled_w <= 1'b0;
			end
			else begin
				if(handled_aw == 1'b1)
					handled_w <= 1'b0;
				else
					handled_w <= 1'b1;
			end
		end
	end

	always @(posedge aclk ) begin
		if(~aresetn)
			valid_b <= 1'b0;
		else begin
			if(valid_b == 1'b0)begin
				if(data_addr_handled & data_wr_r)
					valid_b <= 1'b1;
				else
					valid_b <= 1'b0;
			end
			else begin
				if(bvalid & bready)
					valid_b <= 1'b0;
				else
					valid_b <= 1'b1;
			end
		end
	end

	always @(posedge aclk ) begin
		if(~aresetn)
			b_addr <= 32'b0;
		else begin
			if(handled_aw & handled_w)
				b_addr <= data_addr_r;
			else
				b_addr <= b_addr;
		end
	end

	assign rw_conflict = (araddr == awaddr) & awvalid | (b_addr == araddr) & valid_b;

	assign arid = {3'b0,selecter[1]};
	assign araddr = {32{selecter[0]}} & inst_addr_r | {32{selecter[1]}} & data_addr_r;
	assign arlen = {8{selecter[0]}} & 8'b11;
	assign arsize = 3'b10;
	assign arburst = 2'b1;
	assign arlock = 0;
	assign arcache = 0;
	assign arprot = 0;
	assign arvalid = (selecter[0] | selecter[1]) & ~rw_conflict;

	assign rready = 1;
	

	assign awid = 4'b1;
	assign awaddr = data_addr_r;
	assign awlen = 0;
	assign awsize = data_size_r;
	assign awburst = 2'b1;
	assign awlen = 0;
	assign awcache = 0;
	assign awprot = 0;
	assign awvalid = ~handled_aw & data_wr_r & (data_addr_port == WAIT_WIRE);

	assign wid = 4'b1;
	assign wdata = data_data_r;
	assign wstrb = data_strb_r;
	assign wlast = 1;
	assign wvalid = ~handled_w & data_wr_r & (data_addr_port == WAIT_WIRE);

	assign bready = 1;

	assign icache_rd_rdy = (inst_addr_port == WAIT_TASK);
	assign icache_ret_valid = (rid == 0) & rready & rvalid;
	assign icache_ret_data = {32{icache_ret_valid}} & rdata;

	assign cpu_data_sram_addr_ok = (data_addr_port == WAIT_TASK);
	assign cpu_data_sram_data_ok = (rid == 1) & rready & rvalid | (bid == 1) & bready & bvalid;
	assign cpu_data_sram_rdata = {32{cpu_data_sram_data_ok}} & rdata;

	assign inst_addr_handled = selecter[0] & arready & arvalid;
	assign data_addr_handled = selecter[1] & arready & arvalid | handled_aw & handled_w;
/*
 *	CPU: Trace Debug Interface (cpu_core::out)
 */
	assign debug_wb_pc       = cpu_debug_wb_pc;
	assign debug_wb_rf_we    = cpu_debug_wb_rf_we;
	assign debug_wb_rf_wnum  = cpu_debug_wb_rf_wnum;
	assign debug_wb_rf_wdata = cpu_debug_wb_rf_wdata;

/*
 * CACHE
 */

	assign icache_ret_last = rlast & (rid == 0);

	//useless
	assign icache_wr_rdy     = 1'b1;

/*
 * CPU: instanciation (cpu_core::in/out)
 */

	mycpu_core mycpu_core_inst (
		.clk				(aclk),
		.resetn				(aresetn),

		.inst_sram_req		(cpu_inst_sram_req),
		.inst_sram_wr		(cpu_inst_sram_wr),
		.inst_sram_size		(cpu_inst_sram_size),
		.inst_sram_wstrb	(cpu_inst_sram_wstrb),
		.inst_sram_addr		(cpu_inst_sram_addr),
		.inst_sram_wdata	(cpu_inst_sram_wdata),
		.inst_sram_addr_ok	(cpu_inst_sram_addr_ok),
		.inst_sram_data_ok	(cpu_inst_sram_data_ok),
		.inst_sram_rdata	(cpu_inst_sram_rdata),

		.data_sram_req		(cpu_data_sram_req),
		.data_sram_wr		(cpu_data_sram_wr),
		.data_sram_size		(cpu_data_sram_size),
		.data_sram_wstrb	(cpu_data_sram_wstrb),
		.data_sram_addr		(cpu_data_sram_addr),
		.data_sram_wdata	(cpu_data_sram_wdata),
		.data_sram_addr_ok	(cpu_data_sram_addr_ok),
		.data_sram_data_ok	(cpu_data_sram_data_ok),
		.data_sram_rdata	(cpu_data_sram_rdata),

		.debug_wb_pc		(cpu_debug_wb_pc),
		.debug_wb_rf_we		(cpu_debug_wb_rf_we),
		.debug_wb_rf_wnum	(cpu_debug_wb_rf_wnum),
		.debug_wb_rf_wdata	(cpu_debug_wb_rf_wdata)
	);
	cache icache(
		.clk					(aclk),
		.reset					(~aresetn),

		.valid					(cpu_inst_sram_req),
		.op						(cpu_inst_sram_wr),
		.index					(cpu_inst_sram_addr[11:4]),
		.tag					(cpu_inst_sram_addr[31:12]),
		.offset					(cpu_inst_sram_addr[3:0]),
		.wstrb					(cpu_inst_sram_wstrb),
		.wdata					(cpu_inst_sram_wdata),   
		.addr_ok				(cpu_inst_sram_addr_ok), 
		.data_ok				(cpu_inst_sram_data_ok),
		.rdata					(cpu_inst_sram_rdata),

		/*
		*  CACHE <==> AXI
		*/
		.rd_rdy					(icache_rd_rdy),
		.ret_valid				(icache_ret_valid),
		.ret_last				(icache_ret_last),
		.ret_data				(icache_ret_data),
		.rd_req					(icache_rd_req),
		.rd_type				(icache_rd_type),
		.rd_addr				(icache_rd_addr),
		
		.wr_rdy					(icache_wr_rdy),
		.wr_req					(icache_wr_req),
		.wr_type				(icache_wr_type),
		.wr_addr				(icache_wr_addr),
		.wr_wstrb				(icache_wr_wstrb),
		.wr_data 				(icache_wr_data)
	);
endmodule
