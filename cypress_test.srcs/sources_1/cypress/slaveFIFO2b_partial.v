module slaveFIFO2b_partial(
	input wire        reset_,
	input wire        clk_100,
	input wire        partial_mode_selected,
	input wire        flaga_d,
	input wire        flagb_d,
 output wire        slwr_partial_,
 output wire        pktend_partial_,
 output wire [31:0] data_out_partial,
 output reg         cypress_fifo_rd_en,
	input wire [31:0] cypress_fifo_dout,
  input wire        cypress_fifo_data_valid,
  input wire        cypress_fifo_empty
);

reg [2:0] current_partial_state, next_partial_state;
//parameters for PARTIAL mode state machine
parameter [2:0] partial_idle                   = 3'd0;
parameter [2:0] partial_wait_flagb             = 3'd1;
parameter [2:0] partial_write                  = 3'd2;
parameter [2:0] partial_write_wr_delay         = 3'd3;
parameter [2:0] partial_wait		               = 3'd4;

reg [3:0] strob_cnt;
reg       strob; 
reg [4:0] short_pkt_cnt;
reg [31:0]data_gen_partial;
reg pktend_prtl_;

assign slwr_partial_ = ((current_partial_state == partial_write) | (current_partial_state == partial_write_wr_delay)) ? 1'b0 : 1'b1;

//counters for short pkt
always @(posedge clk_100, negedge reset_)begin
	if(!reset_)begin 
		short_pkt_cnt <= 4'd0;
	end else if(current_partial_state == partial_idle)begin
		short_pkt_cnt <= 4'd0;
	end else if((current_partial_state == partial_write) || (current_partial_state == partial_write_wr_delay))begin
		short_pkt_cnt <= short_pkt_cnt + 1'b1;
	end	
end

//counter to generate the strob for PARTIAL
always @(posedge clk_100, negedge reset_)begin
	if(!reset_)begin 
		strob_cnt <= 4'd0;
	end else if(current_partial_state == partial_idle)begin
		strob_cnt <= 4'd0;
	end else if(current_partial_state == partial_wait)begin
		strob_cnt <= strob_cnt + 1'b1;
	end	
end

//Strob logic
always@(posedge clk_100, negedge reset_)begin
	if(!reset_)begin
		strob <= 1'b0;
	end else if((current_partial_state == partial_wait) && (strob_cnt == 4'b0111)) begin
		strob <= !strob;
	end
end

always@(*)begin
	if((partial_mode_selected) & (strob == 1'b1) & (short_pkt_cnt == 5'b11111))begin
		pktend_prtl_ = 1'b0;
	end else begin
		pktend_prtl_ = 1'b1;
	end
end	

assign pktend_partial_ = pktend_prtl_;

//PARTIAL mode state machine
always @(posedge clk_100, negedge reset_)begin
	if(!reset_)begin 
		current_partial_state <= partial_idle;
	end else begin
		current_partial_state <= next_partial_state;
	end	
end

//PARTIAL mode state machine combo
always @(*)begin
	next_partial_state = current_partial_state;
	case(current_partial_state)
	partial_idle:begin
		if((partial_mode_selected) & (flaga_d == 1'b1))begin
			next_partial_state = partial_wait_flagb; 
		end else begin
			next_partial_state = partial_idle;
		end	
	end
	partial_wait_flagb :begin
		if (flagb_d == 1'b1)begin
			next_partial_state = partial_write; 
		end else begin
			next_partial_state = partial_wait_flagb; 
		end
	end
	partial_write:begin
		if((flagb_d == 1'b0) | ((strob == 1'b1) & (short_pkt_cnt == 4'b1110)))begin
			next_partial_state = partial_write_wr_delay;
		end else begin
		 	next_partial_state = partial_write;
		end
	end
        partial_write_wr_delay:begin
		next_partial_state = partial_wait;
	end
	partial_wait:begin
		if(strob_cnt == 4'b0111)begin
			next_partial_state = partial_idle;
		end else begin
			next_partial_state = partial_wait;
		end
	end	
	endcase
end

//data generator counter for Partial mode
always @(posedge clk_100, negedge reset_)begin
	if(!reset_)begin 
		data_gen_partial <= 32'd0;
    cypress_fifo_rd_en <= 0;
  end else begin
    if((slwr_partial_ == 1'b0) & (partial_mode_selected)) begin
    //   cypress_fifo_rd_en <= 1;
        data_gen_partial <= data_gen_partial + 1;
    end else if (!partial_mode_selected) begin
      data_gen_partial <= 32'd0;
    end	
    if(cypress_fifo_empty) begin
      cypress_fifo_rd_en <= 0;
    end
  end
end

assign data_out_partial = data_gen_partial;//cypress_fifo_data_valid ? cypress_fifo_dout: 32'h0000_0000;// ;

endmodule

