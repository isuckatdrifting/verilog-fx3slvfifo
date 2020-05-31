`timescale 1ns/1ps
`define PARTIAL_TO_CYPRESS 3'd1
`define WRITE_TO_CYPRESS 3'd3
`define READ_FROM_CYPRESS 3'd4
`define CFG_PLENGTH 10

module cypress_test_tb;

reg clk, resetn;
reg fx3_flaga, fx3_flagb, fx3_flagc, fx3_flagd; //flagc: partial flag for IN EP. flagd: full flag
wire [1:0] fx3_faddr, fx3_PMODE;
wire fx3_pclk, fx3_slrd, fx3_slwr, fx3_sloe, fx3_slcs, fx3_pktend;
reg [2:0] mode;
wire [31:0] fx3_fdata;
reg  [31:0] fdata_out; // Config data to load
reg [31:0] cfg [0:`CFG_PLENGTH-1];
reg [7:0] cfg_counter;
reg slrd_dly1, slrd_dly2;

task cypress_stream;
	input [2:0] stream_mode;
begin
  mode = stream_mode;
  if(stream_mode == `WRITE_TO_CYPRESS) begin
    fx3_flaga = 1; //fx3_flagb = 1;
    #(10*(`CFG_PLENGTH+2))
    // fx3_flagb = 0;
    #40
    fx3_flaga = 0;
    #90
    mode  = 3'd0;
  end else if(stream_mode == `READ_FROM_CYPRESS) begin
    fx3_flagc = 1; //fx3_flagd = 1;
    #(10*(`CFG_PLENGTH+2))
    // fx3_flagd = 0;
    #40
    fx3_flagc = 0;
    #90
    mode  = 3'd0;
  end else if(stream_mode == `PARTIAL_TO_CYPRESS) begin
    fx3_flaga = 1; //fx3_flagb = 1;
    #(10*(30+2))
    // fx3_flagb = 0;
    #60
    fx3_flaga = 0;
    #90
    mode  = 3'd0;
  end
end
endtask

usb_master u_usb_master(
  .usbclk (clk),
  .resetn (resetn),
  .test_mode_p  (mode),
  .pmod   (fx3_PMODE),
  .pclk   (fx3_pclk),
  .fdata  (fx3_fdata),
  .faddr  (fx3_faddr),
  .slrd   (fx3_slrd),
  .slwr   (fx3_slwr),
  .sloe   (fx3_sloe),
  .slcs   (fx3_slcs),
  .flaga  (fx3_flaga),
  .flagb  (fx3_flagb),
  .flagc  (fx3_flagc),
  .flagd  (fx3_flagd),
  .pktend (fx3_pktend)
);

initial begin
  clk = 0; resetn = 0; mode = 3'd0;
	fx3_flaga = 0; fx3_flagb = 0; fx3_flagc = 0; fx3_flagd = 0;
  #20 resetn = 1;
  #500;
  @(posedge fx3_pclk);
  cypress_stream(`READ_FROM_CYPRESS);
end
always #5 clk = ~clk;

initial begin
  cfg[0] = {1'b1, 7'h00, {23{1'b0}}, 1'b1}; // system reset
  cfg[1] = {1'b1, 7'h01, {8{1'b0}}, 16'd100}; // pulse count
  //                      pw, freq_div
  cfg[2] = {1'b1, 7'h02, {12{1'b0}}, 4'd0, 8'd20}; // pulse config
  //               row_sp,col_sp,           frame,measure
  cfg[3] = {1'b1, 7'h03, 8'h00, 8'h00, {6{1'b0}}, 1'b1, 1'b0};
  //                          hist_mode_flag
  cfg[4] = {1'b1, 7'h04, {22{1'b0}}, 2'b01};
  //               hist_c2, hist_c1
  cfg[5] = {1'b1, 7'h05, 12'd25, 12'd25};
  //               hist_c4, hist_c3
  cfg[6] = {1'b1, 7'h06, 12'd25, 12'd25};
  //               hist_upth, hist_loth
  cfg[7] = {1'b1, 7'h07, 12'hFFF, 12'h000};
  //                          cfg_ready
  cfg[8] = {1'b1, 7'h08, {23{1'b0}}, 1'b1}; 
  //                       1: oneshot/0: cont, system start
  cfg[9] = {1'b1, 7'h09, {22{1'b0}}, 1'b0, 1'b1};
  slrd_dly1 = 0; slrd_dly2 = 0;
  cfg_counter = 8'h00;
  fdata_out = 32'h0000_0000;
end

always @(posedge fx3_pclk) begin
  // delay two cycles, then sendout data
  slrd_dly1 <= fx3_slrd;
  slrd_dly2 <= slrd_dly1;
  if(mode == `READ_FROM_CYPRESS && !slrd_dly2 && cfg_counter < `CFG_PLENGTH) begin
    cfg_counter <= cfg_counter + 1;
	  fdata_out <= cfg[cfg_counter];
  end else begin
    fdata_out <= 32'h0000_0000;
  end 
end
assign fx3_fdata = (mode == `WRITE_TO_CYPRESS) ? 32'hz : fdata_out;

endmodule