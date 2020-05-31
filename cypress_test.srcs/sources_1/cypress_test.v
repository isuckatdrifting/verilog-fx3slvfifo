module cypress_test(
  input wire        clk,
  input wire        resetn,
  // Cypress USB interface
  inout wire [31:0] fx3_fdata,
 output wire  [1:0] fx3_faddr,
 output wire        fx3_slrd,
 output wire        fx3_slwr,
  input wire        fx3_flaga,
  input wire        fx3_flagb,
  input wire        fx3_flagc,
  input wire        fx3_flagd,
 output wire        fx3_sloe,
 output wire        fx3_pclk,
 output wire        fx3_slcs,
 output wire        fx3_pktend,
 output wire  [1:0] fx3_PMODE,

 output wire  [7:0] led
);

slave_in u_slave_in(

);

slave_out u_slave_out(

);



endmodule