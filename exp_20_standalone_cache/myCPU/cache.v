/**
 * Module: cache
 * Description: This module implements a cache for a CPU. It handles read and write operations between the cache and the CPU, as well as between the cache and an AXI interface. The cache is organized into multiple ways and banks, and supports cache line operations. It also includes a write buffer and dirty bit tracking.
 */

`define WIDTH      32

`define TAG_WIDTH  20
`define IDX_WIDTH   8
`define OFT_WIDTH   4
`define LIN_WIDTH 128

`define BYTE_NUM    4
`define WAY_NUM     2
`define BANK_NUM    4

module cache(
    input           clk,
    input           resetn,

    /*
     *  CACHE <==> CPU
     */
    input           valid,
    input           op,
    input   [ 7:0]  index,
    input   [19:0]  tag,
    input   [ 3:0]  offset,
    input   [ 3:0]  wstrb,
    input   [31:0]  wdata,   
    output          addr_ok, 
    output          data_ok,
    output  [31:0]  rdata,

    /*
     *  CACHE <==> AXI
     */
    input           rd_rdy,
    input           ret_valid,
    input           ret_last,
    input   [ 31:0] ret_data,
    output          rd_req,
    output  [  2:0] rd_type,
    output  [ 31:0] rd_addr,
    
    input           wr_rdy,
    output          wr_req,
    output  [  2:0] wr_type,
    output  [ 31:0] wr_addr,
    output  [  3:0] wr_wstrb,
    output  [127:0] wr_data 
);

/*
 * Main FSM
 */
parameter   IDLE 	= 5'b00001,
            LOOKUP 	= 5'b00010,
            MISS    = 5'b00100,
            REPLACE = 5'b01000,
            REFILL 	= 5'b10000;
reg [4:0]   curr_state;
reg [4:0]   next_state;

/*
 * FSM for write buffer
 */
parameter   W_IDLE  = 2'b01;
parameter   W_WRITE = 2'b10;
reg [1:0]   Wcurr_state;
reg [1:0]   Wnext_state;


wire                    tagv_we     [`WAY_NUM - 1:0];
wire [`IDX_WIDTH - 1:0] tagv_addr   [`WAY_NUM - 1:0];
wire [`TAG_WIDTH    :0] tagv_rdata  [`WAY_NUM - 1:0];   // DONT '-1'!
wire [`TAG_WIDTH    :0] tagv_wdata  [`WAY_NUM - 1:0];   // TAG + VALID needs {`TAG_WIDTH+1} bits

wire                    data_we     [`WAY_NUM - 1:0][`BANK_NUM - 1:0];
wire [`IDX_WIDTH - 1:0] data_addr   [`WAY_NUM - 1:0][`BANK_NUM - 1:0];
wire [    `WIDTH - 1:0] data_rdata  [`WAY_NUM - 1:0][`BANK_NUM - 1:0];
wire [    `WIDTH - 1:0] data_wdata  [`WAY_NUM - 1:0][`BANK_NUM - 1:0];
wire [    `WIDTH - 1:0] data_wdata_final;

reg  [`LIN_WIDTH - 1:0] dirty       [`WAY_NUM-1:0];
wire [`IDX_WIDTH - 1:0] dirty_index;

wire                  read_valid  [`WAY_NUM - 1:0];
wire [`TAG_WIDTH-1:0] read_tag    [`WAY_NUM - 1:0];
wire [`LIN_WIDTH-1:0] read_rdata  [`WAY_NUM - 1:0];


reg                     req_op_r;
reg  [`IDX_WIDTH - 1:0] req_index_r;
reg  [`TAG_WIDTH - 1:0] req_tag_r;
reg  [`OFT_WIDTH - 1:0] req_offset_r;
reg  [    `WIDTH - 1:0] req_wdata_r;
reg  [ `BYTE_NUM - 1:0] req_wstrb_r;

reg                     wr_way_r;
reg  [             1:0] wr_bank_r;
reg  [`IDX_WIDTH - 1:0] wr_index_r;
reg  [`TAG_WIDTH - 1:0] wr_tag_r;
reg  [`OFT_WIDTH - 1:0] wr_offset_r;
reg  [    `WIDTH    :0] wr_wdata_r;
reg  [ `BYTE_NUM    :0] wr_wstrb_r;
wire                    wr_writing;

// Tag cmp
wire [             1:0] bank;
wire [             1:0] req_bank_r;
wire                    cache_hit;
wire                    hit_way;
wire [    `WAY_NUM - 1:0] hit;
wire [    `WAY_NUM - 1:0] wr_hit;
wire                    hit_write;
wire                    hit_write_hazard;
wire                    index_offset_remain;

// LOAD data
wire [      `WIDTH-1:0] load_word   [`WAY_NUM-1:0];
wire [      `WIDTH-1:0] load_res;

// miss(replace)
wire                    replace_way_num; 
reg  [             1:0] ret_cnt;
wire                    if_replace;

// for interface
reg                     wr_req_r;
wire                    rst;

// random gen
reg  [             7:0] random;

// genvar
genvar i, j;

// rst
assign rst = ~resetn;

/*
 * Random
 */

always @ (posedge clk) begin
    if(rst)
        random <= 8'b0;
    else
        random <= {random[6:0], random[1] ^ random[2] ^ random[3] ^ random[7]};
end

/*
 * FSM state switch
 */
always @ (posedge clk) begin
    if (rst) begin
        curr_state <= IDLE;
        Wcurr_state <= W_IDLE;
    end else begin
        curr_state <= next_state;
        Wcurr_state <= Wnext_state;
    end
end

/*
 * Main FSM logic
 */

always @ (*) begin
    case(curr_state)
        IDLE:
            if(valid & ~hit_write_hazard)
                next_state = LOOKUP;      
            else
                next_state = IDLE;
        LOOKUP:
            if((~valid | hit_write_hazard) & cache_hit)
                next_state = IDLE;
            else if (valid & cache_hit)
                next_state = LOOKUP;
            else if (if_replace)
                next_state = REPLACE;
            else
                next_state = MISS;
        MISS:
            if(wr_rdy)
                next_state = REPLACE;
            else
                next_state = MISS;
        REPLACE:
            if(rd_rdy)
                next_state = REFILL;
            else
                next_state = REPLACE;
        REFILL:
            if(ret_valid & ret_last)
                next_state = IDLE;
            else
                next_state = REFILL;
        default:
            next_state = IDLE;
    endcase
end

/*
 * FSM for write buffer logic
 */

always @ (*) begin
    case(Wcurr_state)
        W_IDLE:
            if(curr_state == LOOKUP & hit_write)
                Wnext_state = W_WRITE;
            else
                Wnext_state = W_IDLE;
        W_WRITE:
            if(hit_write)
                Wnext_state = W_WRITE;
            else
                Wnext_state = W_IDLE;
        default:
            Wnext_state = W_IDLE;
    endcase
end

/*
 * tagv_inst
 */

assign tagv_we   [0] = ret_valid & ret_last & ~replace_way_num;
assign tagv_we   [1] = ret_valid & ret_last &  replace_way_num;
assign tagv_wdata[0] = {req_tag_r, 1'b1};
assign tagv_wdata[1] = {req_tag_r, 1'b1};
assign tagv_addr [0] = (curr_state == IDLE || curr_state == LOOKUP) ? index : req_index_r;
assign tagv_addr [1] = (curr_state == IDLE || curr_state == LOOKUP) ? index : req_index_r;
generate 
    for(i = 0; i < `WAY_NUM; i = i + 1) begin
        tagv tagv_inst(
            .clka   (clk            ),
            .wea    (tagv_we   [i]  ),
            .addra  (tagv_addr [i]  ),
            .dina   (tagv_wdata[i]  ),
            .douta  (tagv_rdata[i]  )
        );
        assign read_valid[i] = tagv_rdata[i][0];
        assign read_tag[i]   = tagv_rdata[i][`TAG_WIDTH:1];
    end
endgenerate

/*
 * data_inst
 */

generate
    for(i = 0; i < `BANK_NUM; i = i + 1) begin
        assign data_we[0][i] = {4{(wr_writing) & (wr_bank_r == i) & ~wr_way_r}} & wr_wstrb_r |
                               {4{ret_valid & ret_cnt == i & ~replace_way_num}} & 4'hf;
        assign data_we[1][i] = {4{(wr_writing) & (wr_bank_r == i) & wr_way_r}}  & wr_wstrb_r |
                               {4{ret_valid & ret_cnt == i & replace_way_num}}  & 4'hf;
    end
endgenerate

generate
    for(i = 0; i < `WAY_NUM; i = i + 1) begin
        assign read_rdata[i] = {data_rdata[i][3], data_rdata[i][2],  data_rdata[i][1], data_rdata[i][0]};
    end
endgenerate

generate
    for(i = 0; i < `WAY_NUM; i = i + 1) begin
        for(j = 0; j < `BANK_NUM; j = j + 1) begin
            data data_inst(
                .clka   (clk                ),
                .wea    (data_we   [i][j]   ),
                .addra  (data_addr [i][j]   ),
                .dina   (data_wdata[i][j]   ),
                .douta  (data_rdata[i][j]   )
            );
            assign data_wdata[i][j] = (wr_writing) ? wr_wdata_r :
                                      ((req_bank_r != j) | ~req_op_r) ? ret_data : data_wdata_final;
            assign data_addr[i][j]  = (curr_state == IDLE) | (curr_state == LOOKUP) ? index : req_index_r;
        end
    end
endgenerate

assign data_wdata_final =  {wr_wstrb_r[3] ? wr_wdata_r[31:24] : ret_data[31:24],
                            wr_wstrb_r[2] ? wr_wdata_r[23:16] : ret_data[23:16],
                            wr_wstrb_r[1] ? wr_wdata_r[15: 8] : ret_data[15: 8],
                            wr_wstrb_r[0] ? wr_wdata_r[ 7: 0] : ret_data[ 7: 0]};

assign load_res= data_rdata[hit_way][req_bank_r];

/*
 * dirty_inst (use regfile)
 */

always @ (posedge clk) begin
    if(rst) begin
        dirty[0] <= 256'b0;
        dirty[1] <= 256'b0;
    end else if (wr_writing) begin
        dirty[wr_way_r][wr_index_r] <= 1'b1;
    end else if (ret_valid & ret_last) begin 
        dirty[replace_way_num][req_index_r] <= req_op_r;
    end
end

/*
 * tag compare
 */

assign hit[0]               = read_valid[0] && (read_tag[0] == req_tag_r);
assign hit[1]               = read_valid[1] && (read_tag[1] == req_tag_r);
assign cache_hit            = hit[0] || hit[1];
assign hit_way              = hit[0] ? 0 : 1;
assign hit_write            = (curr_state == LOOKUP) && cache_hit && req_op_r;
assign hit_write_hazard     = valid & ~op & (
                                ((curr_state == LOOKUP) & hit_write & index_offset_remain)
                                |(wr_writing & (bank == req_bank_r))
                            );
assign index_offset_remain  = {index, offset} == {req_index_r, req_offset_r};

/*
 * request buffer
 */

always @ (posedge clk)
begin
    if(rst) begin
        req_index_r  <= 0;
        req_offset_r <= 0;
        req_op_r     <= 0;
        req_tag_r    <= 0;
        req_wdata_r  <= 0;
        req_wstrb_r  <= 0;
    end
    else if(next_state == LOOKUP) begin
        req_index_r   <= index;
        req_offset_r  <= offset;
        req_op_r      <= op;
        req_tag_r     <= tag;
        req_wdata_r   <= wdata;
        req_wstrb_r   <= wstrb;
    end
end
assign bank       = offset[3:2];
assign req_bank_r = req_offset_r[3:2];

/*
 * write buffer
 */

always @ (posedge clk)
begin
    if(rst) begin
        wr_way_r    <= 0;
        wr_bank_r   <= 0;
        wr_index_r  <= 0;
        wr_tag_r    <= 0;
        wr_wdata_r  <= 0;
        wr_wstrb_r  <= 0;
        wr_offset_r <= 0;
    end
    else if(hit_write) begin
        wr_tag_r    <= req_tag_r;
        wr_way_r    <= hit_way;
        wr_bank_r   <= req_bank_r;
        wr_index_r  <= req_index_r;
        wr_wstrb_r  <= req_wstrb_r;
        wr_wdata_r  <= req_wdata_r;
        wr_offset_r <= req_offset_r;
    end
end

always @ (posedge clk) begin
    if (rst)
        wr_req_r <= 1'b0;
    else if(curr_state == MISS && next_state == REPLACE)
        wr_req_r <= 1'b1;
    else if(wr_rdy)
        wr_req_r <= 1'b0;
end

assign wr_writing = (Wcurr_state == W_WRITE);


/*
 * replace
 */

always @ (posedge clk) begin
    if(rst)
        ret_cnt <= 0;
    else if (ret_valid & ~ret_last)
        ret_cnt <= ret_cnt + 1;
    else if (ret_valid & ret_last)
        ret_cnt <= 0;
end
assign replace_way_num  = random[0];
assign if_replace = ~dirty[replace_way_num][req_index_r] | ~read_valid[replace_way_num];

/*
 * connect
 */

assign rd_type  = 3'b110;
assign rd_addr  = {req_tag_r, req_index_r, req_offset_r};
assign rd_req   = (curr_state == REPLACE);
assign rdata    = ret_valid ? ret_data : load_res;

assign wr_type  = 3'b110;
assign wr_addr  = {read_tag[replace_way_num], req_index_r, req_offset_r};
assign wr_req   = wr_req_r;
assign wr_wstrb = 4'hf;
assign wr_data  = {data_rdata[replace_way_num][3], data_rdata[replace_way_num][2],
                   data_rdata[replace_way_num][1], data_rdata[replace_way_num][0]};

assign addr_ok   = (curr_state == IDLE) | (curr_state == LOOKUP & valid & cache_hit & (op | (~op & ~hit_write_hazard)));
assign data_ok   = (curr_state == LOOKUP & (cache_hit | req_op_r)) | (curr_state == REFILL & ~req_op_r & ret_valid & (ret_cnt == req_bank_r));

endmodule