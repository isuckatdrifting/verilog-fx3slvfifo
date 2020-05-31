module usb_master(
  input wire        usbclk, // max 100MHz
  input wire        resetn,
  input wire  [2:0] test_mode_p,
 output wire  [1:0] pmod,
 output wire        pclk,
  inout wire [31:0] fdata,
 output reg   [1:0] faddr,
 output reg         slrd,
 output reg         slwr,
 output reg         sloe,
 output reg         slcs,
  input wire        flaga,
  input wire        flagb,
  input wire        flagc,
  input wire        flagd,
 output reg         pktend
);
assign pmod = 2'b11;
assign pclk = usbclk;

localparam mode_miso = 4, mode_mosi = 3;
localparam IDLE = 0, 
  MISO_PENDING_FLAG = 1, MISO_FLAG_RCVD = 2, MISO_READING = 3, MISO_READING_DELAY = 4,
  MOSI_PENDING_FLAG = 5, MOSI_FLAG_RCVD = 6, MOSI_WRITING = 7, MOSI_WRITING_DELAY = 8,
  DONE = 9;
reg [31:0] fdata_d;
reg flaga_d, flagb_d, flagc_d, flagd_d;
reg [2:0] mode;
reg [3:0] state, next_state;
reg [3:0] rd_cnt, wr_cnt, dly_cnt;
// Sync inputs
always @(posedge usbclk or negedge resetn) begin
  if(!resetn) begin
    fdata_d <= 32'd0;
    flaga_d <= 0; flagb_d <= 0; flagc_d <= 0; flagd_d <= 0; mode <= 3'b000;
  end else begin
    fdata_d <= fdata;
    flaga_d <= flaga;
		flagb_d <= flagb;
		flagc_d <= flagc;
		flagd_d <= flagd;
    mode <= test_mode_p;
  end
end

always @(posedge usbclk or negedge resetn) begin
  if(!resetn) state <= IDLE;
  else state <= next_state;
end

always @* begin
  case(state)
    IDLE: begin
            case(mode)
              mode_miso: next_state = MISO_PENDING_FLAG;
              mode_mosi: next_state = MOSI_PENDING_FLAG;
              default: next_state = IDLE;
            endcase
          end
    MISO_PENDING_FLAG: if(mode == mode_miso) begin
            next_state = flagc_d? MISO_FLAG_RCVD: MISO_PENDING_FLAG;
          end else begin
            next_state = IDLE;
          end
    MISO_FLAG_RCVD: if(mode == mode_miso) begin
            next_state = MISO_READING;
          end else begin
            next_state = IDLE;
          end
    MISO_READING: if(mode == mode_miso) begin
            next_state = rd_cnt == 6? MISO_READING_DELAY: MISO_READING;
          end else begin
            next_state = IDLE;
          end
    MISO_READING_DELAY: if(mode == mode_miso) begin
            next_state = dly_cnt == 2? DONE : MISO_READING_DELAY;
          end else begin
            next_state = IDLE;
          end

    MOSI_PENDING_FLAG: if(mode == mode_mosi) begin
            next_state = flaga_d? MOSI_WRITING: MOSI_PENDING_FLAG;
          end else begin
            next_state = IDLE;
          end
    MOSI_FLAG_RCVD: if(mode == mode_mosi) begin
            next_state = MOSI_WRITING;
          end else begin
            next_state = IDLE;
          end
    MOSI_WRITING: if(mode == mode_mosi) begin
            next_state = wr_cnt == 15? MOSI_WRITING_DELAY: MOSI_WRITING;
          end else begin
            next_state = IDLE;
          end
    MOSI_WRITING_DELAY: if(mode == mode_mosi) begin
            next_state = dly_cnt == 2? DONE : MOSI_WRITING_DELAY;
          end else begin
            next_state = IDLE;
          end

    DONE: next_state = IDLE;
    default: next_state = IDLE;
  endcase
end

always @(posedge usbclk or negedge resetn) begin
  if(!resetn) begin
    faddr <= 2'b00;
    slcs <= 1;
    sloe <= 1;
    slrd <= 1;
    slwr <= 1;
    rd_cnt <= 0;
    dly_cnt <= 0;
    pktend <= 0;
  end else begin
    case(next_state)
      IDLE: begin
        faddr <= 2'b00;
        slcs <= 1;
        sloe <= 1;
        slrd <= 1;
        slwr <= 1;
        rd_cnt <= 0;
        dly_cnt <= 0;
        pktend <= 0;
      end
      MISO_PENDING_FLAG: begin
        faddr <= 2'b11;
        slcs <= 0;
      end
      MISO_FLAG_RCVD: begin
        sloe <= 0;
        slrd <= 0;
      end
      MISO_READING: begin
        if(rd_cnt < 6) begin
          rd_cnt <= rd_cnt + 1;
          if(rd_cnt == 5) begin
            slrd <= 1;
          end
        end
      end
      MISO_READING_DELAY: begin
        if(dly_cnt < 2) begin
          dly_cnt <= dly_cnt + 1;
          if(dly_cnt == 1) begin
            sloe <= 1;
          end
        end
      end
      MOSI_PENDING_FLAG: begin
        faddr <= 2'b00;
        slcs <= 0;
      end
      MOSI_FLAG_RCVD: begin
        slwr <= 0;
      end
      MOSI_WRITING: begin
      end
      MOSI_WRITING_DELAY: begin
        if(dly_cnt < 3) dly_cnt <= dly_cnt + 1;
        else begin
          dly_cnt <= dly_cnt;
          slwr <= 1;
        end
      end
      default:;
    endcase
  end
end
endmodule