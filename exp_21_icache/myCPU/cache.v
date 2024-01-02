module cache(
    //cache_cpu_interface
    input  wire         clk,
    input  wire         reset,
    input  wire         valid,
    input  wire         op,
    input  wire [  7:0] index,
    input  wire [ 19:0] tag,
    input  wire [  3:0] offset,
    input  wire [  3:0] wstrb,
    input  wire [ 31:0] wdata,
    output wire         addr_ok,
    output wire         data_ok,
    output wire [ 31:0] rdata,
    //cache_bridge_interface
    output wire         rd_req,
    output wire [  2:0] rd_type,
    output wire [ 31:0] rd_addr,
    input  wire         rd_rdy,
    input  wire         ret_valid,
    input  wire         ret_last,
    input  wire [ 31:0] ret_data,
    output wire         wr_req,
    output wire [  2:0] wr_type,
    output wire [ 31:0] wr_addr,
    output wire [  3:0] wr_wstrb,
    output wire [127:0] wr_data,
    input  wire         wr_rdy
);
    reg  [  5:0] main_state;
    reg  [  5:0] main_state_next;
    reg  [  5:0] write_state;
    reg  [  5:0] write_state_next;
    wire         req_stall; 
    wire [  3:0] refill_data_ok;
    reg          lookup_op;
    reg  [  7:0] lookup_index;
    reg  [ 19:0] lookup_tag;
    reg  [  3:0] lookup_offset;
    reg  [  3:0] lookup_wstrb;
    reg  [ 31:0] lookup_wdata;
    reg          wr_req_cond;
    wire [ 19:0] way0_tag;
    wire [ 19:0] way1_tag;
    wire         way0_v;
    wire         way1_v;
    wire         way0_hit;
    wire         way1_hit;
    wire         lookup_hit;
    wire [ 31:0] way0_load_word;
    wire [ 31:0] way1_load_word;
    wire [ 31:0] final_ret_data;
    reg          write_buf_way;
    reg  [  1:0] write_buf_bank;
    reg  [  7:0] write_buf_index;
    reg  [  3:0] write_buf_wstrb;
    reg  [ 31:0] write_buf_wdata;
    reg          miss_buf_way;
    reg  [  1:0] miss_buf_num;
    reg  [255:0] d_reg_0;
    reg  [255:0] d_reg_1;
    wire         tagv_ram_0_en;
    wire         tagv_ram_0_we;
    wire [  7:0] tagv_ram_0_index;
    wire [ 20:0] tagv_ram_0_wdata;
    wire [ 20:0] tagv_ram_0_rdata;
    wire         tagv_ram_1_en;
    wire         tagv_ram_1_we;
    wire [  7:0] tagv_ram_1_index;
    wire [ 20:0] tagv_ram_1_wdata;
    wire [ 20:0] tagv_ram_1_rdata;
    wire         data_bank_0_en;
    wire         data_bank_1_en;
    wire         data_bank_2_en;
    wire         data_bank_3_en;
    wire         data_bank_4_en;
    wire         data_bank_5_en;
    wire         data_bank_6_en;
    wire         data_bank_7_en;
    wire [  3:0] data_bank_0_we;
    wire [  3:0] data_bank_1_we;
    wire [  3:0] data_bank_2_we;
    wire [  3:0] data_bank_3_we;
    wire [  3:0] data_bank_4_we;
    wire [  3:0] data_bank_5_we;
    wire [  3:0] data_bank_6_we;
    wire [  3:0] data_bank_7_we;
    wire [  7:0] data_bank_0_index;
    wire [  7:0] data_bank_1_index;
    wire [  7:0] data_bank_2_index;
    wire [  7:0] data_bank_3_index;
    wire [  7:0] data_bank_4_index;
    wire [  7:0] data_bank_5_index;
    wire [  7:0] data_bank_6_index;
    wire [  7:0] data_bank_7_index;
    wire [ 31:0] data_bank_0_rdata;
    wire [ 31:0] data_bank_1_rdata;
    wire [ 31:0] data_bank_2_rdata;
    wire [ 31:0] data_bank_3_rdata;
    wire [ 31:0] data_bank_4_rdata;
    wire [ 31:0] data_bank_5_rdata;
    wire [ 31:0] data_bank_6_rdata;
    wire [ 31:0] data_bank_7_rdata;
    wire [ 31:0] data_bank_0_wdata;
    wire [ 31:0] data_bank_1_wdata;
    wire [ 31:0] data_bank_2_wdata;
    wire [ 31:0] data_bank_3_wdata;
    wire [ 31:0] data_bank_4_wdata;
    wire [ 31:0] data_bank_5_wdata;
    wire [ 31:0] data_bank_6_wdata;
    wire [ 31:0] data_bank_7_wdata;
    reg          q0;
    reg          q1;
    reg          q2;
    wire         lfsr;
    
    localparam IDLE    = 6'b000001,
               LOOKUP  = 6'b000010,
               MISS    = 6'b000100,
               REPLACE = 6'b001000,
               REFILL  = 6'b010000,
               WRITE   = 6'b100000;

    localparam OP_READ  = 1'b0,
               OP_WRITE = 1'b1;

    always@(posedge clk) 
    begin
        if (reset)
        begin
            main_state  <= IDLE;
            write_state <= IDLE;
        end
        else
        begin
            main_state  <= main_state_next;
            write_state <= write_state_next;
        end
    end  

    always@(*)
    begin
        case (main_state)
            IDLE:
                if (valid & addr_ok)
                    main_state_next = LOOKUP;
                else
                    main_state_next = IDLE;
            LOOKUP:
                if (valid & addr_ok)
                    main_state_next = LOOKUP;
                else if (~lookup_hit)
                    main_state_next = MISS;
                else
                    main_state_next = IDLE;
            MISS:
                if (wr_rdy)
                    main_state_next = REPLACE;
                else
                    main_state_next = MISS;
            REPLACE:
                if (rd_rdy)
                    main_state_next = REFILL;
                else
                    main_state_next = REPLACE;
            REFILL:
                if (ret_valid && ret_last)
                    main_state_next = IDLE;
                else
                    main_state_next = REFILL;
            default:
                    main_state_next = IDLE;
        endcase
    end

    always@(*)
    begin
        case(write_state)
            IDLE:
                if (lookup_op == OP_WRITE && lookup_hit)
                    write_state_next = WRITE;
                else
                    write_state_next = IDLE;
            WRITE:
                if (lookup_op == OP_WRITE && lookup_hit)
                    write_state_next = WRITE;
                else
                    write_state_next = IDLE;
            default:
                    write_state_next = IDLE;
        endcase
    end

    assign req_stall = write_state == WRITE && op == OP_READ && offset[3:2] == write_buf_bank
                    || main_state == LOOKUP && op == OP_READ && lookup_op == OP_WRITE && tag == lookup_tag && index == lookup_index && offset[3:2] == lookup_offset[3:2]
                    || main_state != IDLE && main_state != LOOKUP;

    assign addr_ok = ~(req_stall || main_state == LOOKUP && !lookup_hit);
    assign data_ok = (lookup_op == OP_READ && lookup_hit || lookup_op == OP_WRITE) && main_state == LOOKUP || (|refill_data_ok && lookup_op == OP_READ);
    assign refill_data_ok[0] = lookup_offset[3:2] == 2'b00 && miss_buf_num == 2'b00 && ret_valid;
    assign refill_data_ok[1] = lookup_offset[3:2] == 2'b01 && miss_buf_num == 2'b01 && ret_valid;
    assign refill_data_ok[2] = lookup_offset[3:2] == 2'b10 && miss_buf_num == 2'b10 && ret_valid;
    assign refill_data_ok[3] = lookup_offset[3:2] == 2'b11 && miss_buf_num == 2'b11 && ret_valid;
    
    always@(posedge clk)
    begin
        if (reset)
            wr_req_cond <= 0;
        else if (main_state == MISS && wr_rdy)
            wr_req_cond <= 1;
        else
            wr_req_cond <= 0;
    end
    assign wr_req  = wr_req_cond && (miss_buf_way ? d_reg_1[lookup_index] : d_reg_0[lookup_index]) && (miss_buf_way ? tagv_ram_1_rdata[0] : tagv_ram_0_rdata[0]);
    assign wr_type = 3'b100;
    assign wr_addr = miss_buf_way ? {tagv_ram_1_rdata[20:1], lookup_index, 4'd0} : {tagv_ram_0_rdata[20:1], lookup_index, 4'd0};
    assign wr_wstrb = 4'b1111;
    assign wr_data = miss_buf_way ? {data_bank_7_rdata, data_bank_6_rdata, data_bank_5_rdata, data_bank_4_rdata} :
                                    {data_bank_3_rdata, data_bank_2_rdata, data_bank_1_rdata, data_bank_0_rdata};
    assign rd_req  = main_state == REPLACE;
    assign rd_type = 3'b100;
    assign rd_addr = {lookup_tag, lookup_index, 4'd0};

    always@(posedge clk)
    begin
        if (valid & addr_ok)
        begin
            lookup_op     <= op;
            lookup_index  <= index; 
            lookup_tag    <= tag;
            lookup_offset <= offset;
            lookup_wstrb  <= wstrb;
            lookup_wdata  <= wdata;
        end
    end
    assign way0_tag = tagv_ram_0_rdata[20:1];
    assign way1_tag = tagv_ram_1_rdata[20:1];
    assign way0_v   = tagv_ram_0_rdata[0];
    assign way1_v   = tagv_ram_1_rdata[0];
    assign way0_hit = lookup_tag == way0_tag && way0_v && main_state == LOOKUP;
    assign way1_hit = lookup_tag == way1_tag && way1_v && main_state == LOOKUP;
    assign lookup_hit = way0_hit || way1_hit;
    assign way0_load_word = {32{lookup_offset[3:2] == 2'd0}} & data_bank_0_rdata | {32{lookup_offset[3:2] == 2'd1}} & data_bank_1_rdata | {32{lookup_offset[3:2] == 2'd2}} & data_bank_2_rdata | {32{lookup_offset[3:2] == 2'd3}} & data_bank_3_rdata;
    assign way1_load_word = {32{lookup_offset[3:2] == 2'd0}} & data_bank_4_rdata | {32{lookup_offset[3:2] == 2'd1}} & data_bank_5_rdata | {32{lookup_offset[3:2] == 2'd2}} & data_bank_6_rdata | {32{lookup_offset[3:2] == 2'd3}} & data_bank_7_rdata;
    assign rdata          = {32{way0_hit}} & way0_load_word | {32{way1_hit}} & way1_load_word | {32{|refill_data_ok}} & ret_data;
    assign final_ret_data = {32{lookup_op == OP_READ || lookup_op == OP_WRITE && lookup_offset[3:2] != miss_buf_num}} & ret_data 
                          | {32{lookup_op == OP_WRITE && lookup_offset[3:2] == miss_buf_num}} & (ret_data & ~{{8{lookup_wstrb[3]}}, {8{lookup_wstrb[2]}}, {8{lookup_wstrb[1]}}, {8{lookup_wstrb[0]}}} | lookup_wdata & {{8{lookup_wstrb[3]}}, {8{lookup_wstrb[2]}}, {8{lookup_wstrb[1]}}, {8{lookup_wstrb[0]}}});

    always@(posedge clk)
    begin
        if (lookup_hit && lookup_op == OP_WRITE)
        begin
            write_buf_way   <= way1_hit;
            write_buf_bank  <= lookup_offset[3:2];
            write_buf_index <= lookup_index;
            write_buf_wstrb <= lookup_wstrb;
            write_buf_wdata <= lookup_wdata;
        end
    end

    always@(posedge clk)
    begin
        if (main_state == MISS && wr_rdy)
            miss_buf_way <= lfsr;
    end

    always@(posedge clk)
    begin
        if (main_state == REPLACE && rd_rdy)
            miss_buf_num <= 2'd0;
        else if (ret_valid)
            miss_buf_num <= miss_buf_num + 2'd1;
    end

    always@(posedge clk)
    begin
        if (reset)
            d_reg_0 <= 256'd0;
        else if (write_state == WRITE && !write_buf_way)
            d_reg_0[write_buf_index] <= 1'b1;
        else if (main_state == REFILL && ret_valid && ret_last && lookup_op == OP_WRITE && !miss_buf_way)
            d_reg_0[lookup_index] <= 1'b1; 

        if (reset)
            d_reg_1 <= 256'd0;
        else if (write_state == WRITE && write_buf_way)
            d_reg_1[write_buf_index] <= 1'b1;
        else if (main_state == REFILL && ret_valid && ret_last && lookup_op == OP_WRITE && miss_buf_way)
            d_reg_1[lookup_index] <= 1'b1; 
        else if (main_state == REFILL && ret_valid && ret_last && lookup_op == OP_READ && miss_buf_way)
            d_reg_1[lookup_index] <= 1'b0; 
    end

    always@(posedge clk)
    begin
        if (reset)
        begin
            q0 <= 1;
            q1 <= 1;
            q2 <= 1;
        end
        else
        begin
            q0 <= q1;
            q1 <= q0 ^ q2;
            q2 <= q0;
        end
    end
    assign lfsr = q0;

    tagv_ram 
        tagv_ram_0
        (
            .clka  (clk              ),   
            .ena   (tagv_ram_0_en    ),
            .wea   (tagv_ram_0_we    ),
            .addra (tagv_ram_0_index ),   //7:0
            .dina  (tagv_ram_0_wdata ),   //20:0
            .douta (tagv_ram_0_rdata )    //20:0
        ),
        tagv_ram_1
        (
            .clka  (clk              ),   
            .ena   (tagv_ram_1_en    ),
            .wea   (tagv_ram_1_we    ),
            .addra (tagv_ram_1_index ),   //7:0
            .dina  (tagv_ram_1_wdata ),   //20:0
            .douta (tagv_ram_1_rdata )    //20:0
        );
        assign tagv_ram_0_en    = (main_state == IDLE || main_state == LOOKUP) && ~req_stall
                                || main_state == MISS && wr_rdy
                                || main_state == REFILL && ret_valid && ret_last && !miss_buf_way;

        assign tagv_ram_0_we    = main_state == REFILL && ret_valid && ret_last && !miss_buf_way;

        assign tagv_ram_0_index = {8{(main_state == IDLE || main_state == LOOKUP)}} & index 
                                | {8{(main_state == MISS || main_state == REFILL)}} &lookup_index;

        assign tagv_ram_0_wdata = {lookup_tag, 1'b1};

        assign tagv_ram_1_en    = (main_state == IDLE || main_state == LOOKUP) && ~req_stall
                                || main_state == MISS && wr_rdy
                                || main_state == REFILL && ret_valid && ret_last && miss_buf_way;

        assign tagv_ram_1_we    = main_state == REFILL && ret_valid && ret_last && miss_buf_way;

        assign tagv_ram_1_index = {8{(main_state == IDLE || main_state == LOOKUP)}} & index 
                                | {8{(main_state == MISS || main_state == REFILL)}} & lookup_index;

        assign tagv_ram_1_wdata = {lookup_tag, 1'b1};

    data_bank_ram
        data_bank_ram_0
        (
            .clka  (clk              ),   
            .ena   (data_bank_0_en    ),
            .wea   (data_bank_0_we    ),   //3:0
            .addra (data_bank_0_index ),   //7:0
            .dina  (data_bank_0_wdata ),   //31:0
            .douta (data_bank_0_rdata )    //31:0
        ),
        data_bank_ram_1
        (
            .clka  (clk              ),   
            .ena   (data_bank_1_en    ),
            .wea   (data_bank_1_we    ),   //3:0
            .addra (data_bank_1_index ),   //7:0
            .dina  (data_bank_1_wdata ),   //31:0
            .douta (data_bank_1_rdata )    //31:0
        ),
        data_bank_ram_2
        (
            .clka  (clk              ),   
            .ena   (data_bank_2_en    ),
            .wea   (data_bank_2_we    ),   //3:0
            .addra (data_bank_2_index ),   //7:0
            .dina  (data_bank_2_wdata ),   //31:0
            .douta (data_bank_2_rdata )    //31:0
        ),
        data_bank_ram_3
        (
            .clka  (clk              ),   
            .ena   (data_bank_3_en    ),
            .wea   (data_bank_3_we    ),   //3:0
            .addra (data_bank_3_index ),   //7:0
            .dina  (data_bank_3_wdata ),   //31:0
            .douta (data_bank_3_rdata )    //31:0
        ),
        data_bank_ram_4
        (
            .clka  (clk              ),   
            .ena   (data_bank_4_en    ),
            .wea   (data_bank_4_we    ),   //3:0
            .addra (data_bank_4_index ),   //7:0
            .dina  (data_bank_4_wdata ),   //31:0
            .douta (data_bank_4_rdata )    //31:0
        ),
        data_bank_ram_5
        (
            .clka  (clk              ),   
            .ena   (data_bank_5_en    ),
            .wea   (data_bank_5_we    ),   //3:0
            .addra (data_bank_5_index ),   //7:0
            .dina  (data_bank_5_wdata ),   //31:0
            .douta (data_bank_5_rdata )    //31:0
        ),
        data_bank_ram_6
        (
            .clka  (clk              ),   
            .ena   (data_bank_6_en    ),
            .wea   (data_bank_6_we    ),   //3:0
            .addra (data_bank_6_index ),   //7:0
            .dina  (data_bank_6_wdata ),   //31:0
            .douta (data_bank_6_rdata )    //31:0
        ),
        data_bank_ram_7
        (
            .clka  (clk              ),   
            .ena   (data_bank_7_en    ),
            .wea   (data_bank_7_we    ),   //3:0
            .addra (data_bank_7_index ),   //7:0
            .dina  (data_bank_7_wdata ),   //31:0
            .douta (data_bank_7_rdata )    //31:0
        );
    assign data_bank_0_en    = (main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] ==2'b00
                             || write_state == WRITE && !write_buf_way && write_buf_bank == 2'b00 
                             || main_state == MISS && wr_rdy && !lfsr
                             || main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b00; 

    assign data_bank_0_we    = {4{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b00}} & write_buf_wstrb
                             | {4{main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b00}} & 4'b1111;

    assign data_bank_0_index = {8{(main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b00}} & index
                             | {8{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b00}} & write_buf_index
                             | {8{main_state == MISS || main_state == REFILL}} & lookup_index;
            
    assign data_bank_0_wdata = {32{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b00}} & write_buf_wdata
                             | {32{main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b00}} & final_ret_data;

    assign data_bank_1_en    = (main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b01
                             || write_state == WRITE && !write_buf_way && write_buf_bank == 2'b01 
                             || main_state == MISS && wr_rdy && !lfsr
                             || main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b01; 

    assign data_bank_1_we    = {4{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b01}} & write_buf_wstrb
                             | {4{main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b01}} & 4'b1111;

    assign data_bank_1_index = {8{(main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b01}} & index
                             | {8{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b01}} & write_buf_index
                             | {8{main_state == MISS || main_state == REFILL}} & lookup_index;
            
    assign data_bank_1_wdata = {32{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b01}} & write_buf_wdata
                             | {32{main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b01}} & final_ret_data;
    
    assign data_bank_2_en    = (main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b10
                             || write_state == WRITE && !write_buf_way && write_buf_bank == 2'b10 
                             || main_state == MISS && wr_rdy && !lfsr
                             || main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b10; 

    assign data_bank_2_we    = {4{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b10}} & write_buf_wstrb
                             | {4{main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b10}} & 4'b1111;

    assign data_bank_2_index = {8{(main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b10}} & index
                             | {8{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b10}} & write_buf_index
                             | {8{main_state == MISS || main_state == REFILL}} & lookup_index;
            
    assign data_bank_2_wdata = {32{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b10}} & write_buf_wdata
                             | {32{main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b10}} & final_ret_data;

    assign data_bank_3_en    = (main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b11
                             || write_state == WRITE && !write_buf_way && write_buf_bank == 2'b11 
                             || main_state == MISS && wr_rdy && !lfsr
                             || main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b11; 

    assign data_bank_3_we    = {4{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b11}} & write_buf_wstrb
                             | {4{main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b11}} & 4'b1111;

    assign data_bank_3_index = {8{(main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b11}} & index
                             | {8{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b11}} & write_buf_index
                             | {8{main_state == MISS || main_state == REFILL}} & lookup_index;
            
    assign data_bank_3_wdata = {32{write_state == WRITE && !write_buf_way && write_buf_bank == 2'b11}} & write_buf_wdata
                             | {32{main_state == REFILL && ret_valid && !miss_buf_way && miss_buf_num == 2'b11}} & final_ret_data;

    assign data_bank_4_en    = (main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b00
                             || write_state == WRITE && write_buf_way && write_buf_bank == 2'b00 
                             || main_state == MISS && wr_rdy && lfsr
                             || main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b00; 

    assign data_bank_4_we    = {4{write_state == WRITE && write_buf_way && write_buf_bank == 2'b00}} & write_buf_wstrb
                             | {4{main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b00}} & 4'b1111;

    assign data_bank_4_index = {8{(main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b00}} & index
                             | {8{write_state == WRITE && write_buf_way && write_buf_bank == 2'b00}} & write_buf_index
                             | {8{main_state == MISS || main_state == REFILL}} & lookup_index;
            
    assign data_bank_4_wdata = {32{write_state == WRITE && write_buf_way && write_buf_bank == 2'b00}} & write_buf_wdata
                             | {32{main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b00}} & final_ret_data;

    assign data_bank_5_en    = (main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b01
                             || write_state == WRITE && write_buf_way && write_buf_bank == 2'b01 
                             || main_state == MISS && wr_rdy && lfsr
                             || main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b01; 

    assign data_bank_5_we    = {4{write_state == WRITE && write_buf_way && write_buf_bank == 2'b01}} & write_buf_wstrb
                             | {4{main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b01}} & 4'b1111;

    assign data_bank_5_index = {8{(main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b01}} & index
                             | {8{write_state == WRITE && write_buf_way && write_buf_bank == 2'b01}} & write_buf_index
                             | {8{main_state == MISS || main_state == REFILL}} & lookup_index;
            
    assign data_bank_5_wdata = {32{write_state == WRITE && write_buf_way && write_buf_bank == 2'b01}} & write_buf_wdata
                             | {32{main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b01}} & final_ret_data;

    assign data_bank_6_en    = (main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b10
                             || write_state == WRITE && write_buf_way && write_buf_bank == 2'b10
                             || main_state == MISS && wr_rdy && lfsr
                             || main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b10; 

    assign data_bank_6_we    = {4{write_state == WRITE && write_buf_way && write_buf_bank == 2'b10}} & write_buf_wstrb
                             | {4{main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b10}} & 4'b1111;

    assign data_bank_6_index = {8{(main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b10}} & index
                             | {8{write_state == WRITE && write_buf_way && write_buf_bank == 2'b10}} & write_buf_index
                             | {8{main_state == MISS || main_state == REFILL}} & lookup_index;
            
    assign data_bank_6_wdata = {32{write_state == WRITE && write_buf_way && write_buf_bank == 2'b10}} & write_buf_wdata
                             | {32{main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b10}} & final_ret_data;

    assign data_bank_7_en    = (main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b11
                             || write_state == WRITE && write_buf_way && write_buf_bank == 2'b11 
                             || main_state == MISS && wr_rdy && lfsr
                             || main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b11; 

    assign data_bank_7_we    = {4{write_state == WRITE && write_buf_way && write_buf_bank == 2'b11}} & write_buf_wstrb
                             | {4{main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b11}} & 4'b1111;

    assign data_bank_7_index = {8{(main_state == LOOKUP || main_state == IDLE) && !req_stall && offset[3:2] == 2'b11}} & index
                             | {8{write_state == WRITE && write_buf_way && write_buf_bank == 2'b11}} & write_buf_index
                             | {8{main_state == MISS || main_state == REFILL}} & lookup_index;
            
    assign data_bank_7_wdata = {32{write_state == WRITE && write_buf_way && write_buf_bank == 2'b11}} & write_buf_wdata
                             | {32{main_state == REFILL && ret_valid && miss_buf_way && miss_buf_num == 2'b11}} & final_ret_data;

endmodule