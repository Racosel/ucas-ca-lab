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

/*
 *	THIS MODULE: parameters
 */

	parameter INIT    	= 4'b0001,
			  WAIT 		= 4'b0010,
			  WAIT2  	= 4'b0100,
			  DONE    	= 4'b1000;

	parameter ID_INST	= 4'b0000,
			  ID_DATA	= 4'b0001;

/*
 * 	THIS MODULE: State Machine registers
 */

	reg [ 3:0] ar_state, r_state, w_state, b_state;
	
	reg [ 3:0] arid_r;
	reg [31:0] araddr_r;
	reg [ 7:0] arlen_r;
	reg [ 2:0] arsize_r;
	reg [ 1:0] arburst_r;
	reg [ 1:0] arlock_r;
	reg [ 3:0] arcache_r;
	reg [ 2:0] arprot_r;

	reg [ 3:0] rid_r;
	reg [31:0] rdata_r;

	reg [ 3:0] awid_r;
	reg [31:0] awaddr_r;
	reg [ 7:0] awlen_r;
	reg [ 2:0] awsize_r;
	reg [ 1:0] awburst_r;
	reg [ 1:0] awlock_r;
	reg [ 3:0] awcache_r;
	reg [ 2:0] awprot_r;

	reg [ 3:0] wid_r;
	reg [31:0] wdata_r;
	reg [ 3:0] wstrb_r;
	reg        wlast_r;

	reg [3:0] bid_r;



/*
 *	THIS MODULE: State Machines (state transition logic)
 */

	// auxilary classfication
	wire req_read_data  = cpu_data_sram_req && !cpu_data_sram_wr;
	wire req_read_inst  = cpu_inst_sram_req && !cpu_inst_sram_wr;
	wire req_write_data = cpu_data_sram_req &&  cpu_data_sram_wr;
		// impossible to write inst sram
	
	wire read_req_from_cpu  =  req_read_data || req_read_inst;
	wire write_req_from_cpu = req_write_data && !read_req_from_cpu;	
		// STRICTLY NOT CONTAIN READ REQUEST

	/*
	 *	AR Channel: Read Address Channel (state transition logic)
	 *	
	 *	INIT -> WAIT: 	1. 	read request from cpu
	 *					2. 	r_state == INIT (R Channel is ready to accept request)
	 *  WAIT -> DONE: 		arready && arvalid
	 *	DONE -> INIT: 		NOTHING
	 */
	always @(posedge aclk) begin
		if (~aresetn)
			ar_state <= INIT;
		else begin
			case (ar_state)

				INIT: begin
					if (read_req_from_cpu && r_state == INIT)
						ar_state <= WAIT;
					else
						ar_state <= INIT;
				end

				WAIT: begin
					if (arready && arvalid)
						ar_state <= DONE;
					else
						ar_state <= WAIT;
				end

				DONE:
					ar_state <= INIT;

				default:
					ar_state <= INIT;

			endcase
		end
	end


	/*
	 *	R Channel: Read Data Channel (state transition logic)
	 *	
	 *	INIT -> WAIT: 	1. 	ar_state == WAIT (AR Channel accepted request)
	 *					2. 	arready && arvalid
	 *	WAIT -> DONE: 		rvalid && rlast && rready (Need to add burst support in future)
	 *	DONE -> INIT: 		NOTHING
	 */
	always @(posedge aclk) begin
		if (~aresetn)
			r_state <= INIT;
		else begin
			case (r_state)

				INIT: begin
					if (arready && arvalid && ar_state == WAIT)
						r_state <= WAIT;
					else
						r_state <= INIT;
				end

				WAIT: begin
					if (rvalid && rlast && rready)	// FIXME: rlast will be used in cache
						r_state <= DONE;
					else
						r_state <= WAIT;
				end

				DONE:
						r_state <= INIT;

				default:
					r_state <= INIT;

			endcase
		end
	end

	
	/*
	 *	AW & W Channel: Write Address & Data Channel (state transition logic)
	 *
	 *	INIT -> WAIT: 	1. 	write request from cpu
	 *					2. 	b_state == INIT (B Channel is ready to accept request)
	 *	WAIT -> WAIT2: 	  	awready && awvalid	(FIRST ENSURE THE AW CHANNEL IS READY)
	 *	WAIT2 -> DONE: 	 	wready && wvalid
	 *	DONE -> INIT: 		NOTHING
	 */
	always @(posedge aclk) begin
		if (~aresetn)
			w_state <= INIT;
		else begin
			case (w_state)

				INIT: begin
					if (write_req_from_cpu && b_state == INIT)
						w_state <= WAIT;
					else
						w_state <= INIT;
				end

				WAIT: begin
					if (awready && awvalid)
						w_state <= WAIT2;
					else
						w_state <= WAIT;
				end

				WAIT2: begin
					if (wready && wvalid)
						w_state <= DONE;
					else
						w_state <= WAIT2;
				end

				DONE:
					w_state <= INIT;

				default:
					w_state <= INIT;

			endcase
		end
	end

	/*
	 *	B Channel: Write Response Channel (state transition logic)
	 *
	 *	INIT -> WAIT: 	1. 	w_state == WAIT2 (W Channel accepted request)
	 *					2. 	wready && wvalid
	 *	WAIT -> DONE: 		bready && bvalid
	 *	DONE -> INIT: 		NOTHING
	 */
	always @(posedge aclk) begin
		if (~aresetn)
			b_state <= INIT;
		else begin
			case (b_state)

				INIT: begin
					if (wready && wvalid && w_state == WAIT2)
						b_state <= WAIT;
					else
						b_state <= INIT;
				end

				WAIT: begin
					if (bvalid)
						b_state <= DONE;
					else
						b_state <= WAIT;
				end

				DONE:
					b_state <= INIT;

				default:
					b_state <= INIT;

			endcase
		end
	end

/*
 *	THIS MODULE: State Machines (output logic)
 */

	/*
	 *	AR Channel: Read Address Channel (output logic)
	 */
	always @(posedge aclk) begin
		if (ar_state == INIT) begin
			arid_r    <= req_read_data ? ID_DATA : ID_INST;
			araddr_r  <= req_read_data ? cpu_data_sram_addr : cpu_inst_sram_addr;
			arlen_r   <= 8'd0;
			arsize_r  <= {1'b0, req_read_data ? cpu_data_sram_size : cpu_inst_sram_size};
			arburst_r <= 2'b1;
			arlock_r  <= 2'b0;
			arcache_r <= 4'b0;
			arprot_r  <= 3'b0;
		end
	end

	/*
	 *	R Channel: Read Data Channel (output logic)
	 */
	always @(posedge aclk) begin
		if (~aresetn) begin
			rid_r   <=  4'b0;
			rdata_r <= 32'b0;
		end
		else if (r_state == WAIT) begin
			rid_r   <= rid;
			rdata_r <= rdata;
		end
	end

	/*
	 *	AW & W Channel: Write Address & Data Channel (output logic)
	 */
	always @(posedge aclk) begin
		if (w_state == INIT) begin
			awid_r    <= ID_DATA;
			awaddr_r  <= cpu_data_sram_addr;
			awlen_r   <= 8'b0;
			awsize_r  <= {1'b0, cpu_data_sram_size};
			awburst_r <= 2'b1;
			awlock_r  <= 2'b0;
			awcache_r <= 4'b0;
			awprot_r  <= 3'b0;

			wid_r     <= ID_DATA;
			wdata_r   <= cpu_data_sram_wdata;
			wstrb_r   <= cpu_data_sram_wstrb;
			wlast_r   <= 1'b1;
		end
	end

	/*
	 *	B Channel: Write Response Channel (output logic)
	 */
	always @(posedge aclk) begin
		if (~aresetn)
			bid_r   <= 4'b0;
		else if (b_state == WAIT)
			bid_r <= bid;
	end

/*
 *	CPU: SRAM Interface (cpu_core::in)
 */

	// auxilary classfication

	// ready to accept request, same as AR Channel's INIT -> WAIT logic
	wire r_inst_addr_ok = (read_req_from_cpu && r_state == INIT) && (arid_r == ID_INST) && aresetn;
	wire r_data_addr_ok = (read_req_from_cpu && r_state == INIT) && (arid_r == ID_DATA) && aresetn;

	wire r_inst_data_ok = ( r_state == DONE) && ( rid_r == ID_INST);
	wire r_data_data_ok = ( r_state == DONE) && ( rid_r == ID_DATA);

	// ready to accept request, same as AW Channel's INIT -> WAIT logic
	wire w_data_addr_ok = (write_req_from_cpu && b_state == INIT) && ( wid_r == ID_DATA) && aresetn;

	wire w_data_data_ok = ( b_state == DONE) && ( bid_r == ID_DATA);

	// cpu interface
	assign cpu_inst_sram_rdata   = rdata_r;	// they are the same
	assign cpu_data_sram_rdata   = rdata_r;	// cause only one of them is valid
	assign cpu_inst_sram_addr_ok = r_inst_addr_ok;
	assign cpu_inst_sram_data_ok = r_inst_data_ok;
	assign cpu_data_sram_addr_ok = r_data_addr_ok || w_data_addr_ok;
	assign cpu_data_sram_data_ok = r_data_data_ok || w_data_data_ok;


/*
 *	THIS MODULE: AXI Interface (cpu_top::out)
 */
	assign arid		= arid_r;
	assign araddr	= araddr_r;
	assign arlen	= arlen_r;
	assign arsize	= arsize_r;
	assign arburst	= arburst_r;
	assign arlock	= arlock_r;
	assign arcache	= arcache_r;
	assign arprot	= arprot_r;
	
	assign awid 	= awid_r; 
	assign awaddr 	= awaddr_r;
	assign awlen 	= awlen_r;
	assign awsize 	= awsize_r;
	assign awburst 	= awburst_r;
	assign awlock 	= awlock_r;
	assign awcache 	= awcache_r;
	assign awprot 	= awprot_r;
	
	assign wid 		= wid_r;
	assign wdata 	= wdata_r;
	assign wstrb 	= wstrb_r;
	assign wlast 	= wlast_r;

	// signals need async reset
	assign arvalid	= (ar_state == WAIT ) &&  aresetn;	// RESET VAL: 0
	assign rready 	= ( r_state == WAIT ) || ~aresetn;	// RESET VAL: 1
	assign awvalid 	= ( w_state == WAIT ) &&  aresetn;	// RESET VAL: 0
	assign wvalid 	= ( w_state == WAIT2) &&  aresetn;	// RESET VAL: 0
	assign bready 	= ( b_state == WAIT ) || ~aresetn;	// RESET VAL: 1


/*
 *	CPU: Trace Debug Interface (cpu_core::out)
 */
	assign debug_wb_pc       = cpu_debug_wb_pc;
	assign debug_wb_rf_we    = cpu_debug_wb_rf_we;
	assign debug_wb_rf_wnum  = cpu_debug_wb_rf_wnum;
	assign debug_wb_rf_wdata = cpu_debug_wb_rf_wdata;

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

endmodule
