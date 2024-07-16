///////////////////////////////////////////////////////////////////////////////
// File downloaded from http://www.nandland.com
///////////////////////////////////////////////////////////////////////////////
// This file converts an input binary number into an output which can get sent
// to a 7-Segment LED.  7-Segment LEDs have the ability to display all decimal
// numbers 0-9 as well as hex digits A, B, C, D, E and F.  The input to this
// module is a 4-bit binary number.  This module will properly drive the
// individual segments of a 7-Segment LED in order to display the digit.
// Hex encoding table can be viewed at:
// http://en.wikipedia.org/wiki/Seven-segment_display
///////////////////////////////////////////////////////////////////////////////

module GoBoardSevenSegment  (
  input wire clk,
  input wire [3:0] value,
  output wire segmentA,
  output wire segmentB,
  output wire segmentC,
  output wire segmentD,
  output wire segmentE,
  output wire segmentF,
  output wire segmentG
);

  reg [6:0] r_Hex_Encoding;
  
  // Purpose: Creates a case statement for all possible input binary numbers.
  // Drives r_Hex_Encoding appropriately for each input combination.
  always @(posedge clk) begin
      case (value)
        4'b0000 : r_Hex_Encoding <= 7'h7E;
        4'b0001 : r_Hex_Encoding <= 7'h30;
        4'b0010 : r_Hex_Encoding <= 7'h6D;
        4'b0011 : r_Hex_Encoding <= 7'h79;
        4'b0100 : r_Hex_Encoding <= 7'h33;          
        4'b0101 : r_Hex_Encoding <= 7'h5B;
        4'b0110 : r_Hex_Encoding <= 7'h5F;
        4'b0111 : r_Hex_Encoding <= 7'h70;
        4'b1000 : r_Hex_Encoding <= 7'h7F;
        4'b1001 : r_Hex_Encoding <= 7'h7B;
        4'b1010 : r_Hex_Encoding <= 7'h77;
        4'b1011 : r_Hex_Encoding <= 7'h1F;
        4'b1100 : r_Hex_Encoding <= 7'h4E;
        4'b1101 : r_Hex_Encoding <= 7'h3D;
        4'b1110 : r_Hex_Encoding <= 7'h4F;
        4'b1111 : r_Hex_Encoding <= 7'h47;
      endcase
  end

  // r_Hex_Encoding[7] is unused
  assign segmentA = ~r_Hex_Encoding[6];
  assign segmentB = ~r_Hex_Encoding[5];
  assign segmentC = ~r_Hex_Encoding[4];
  assign segmentD = ~r_Hex_Encoding[3];
  assign segmentE = ~r_Hex_Encoding[2];
  assign segmentF = ~r_Hex_Encoding[1];
  assign segmentG = ~r_Hex_Encoding[0];

endmodule
