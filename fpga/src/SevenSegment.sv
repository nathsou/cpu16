
module SevenSegment (
    input logic [3:0] char,
    output logic [6:0] segs
);
    always_comb begin
        unique case (char)
            4'd0: segs = 7'b0111111;
            4'd1: segs = 7'b0000110;
            4'd2: segs = 7'b1011011;
            4'd3: segs = 7'b1001111;
            4'd4: segs = 7'b1100110;
            4'd5: segs = 7'b1101101;
            4'd6: segs = 7'b1111101;
            4'd7: segs = 7'b0000111;
            4'd8: segs = 7'b1111111;
            4'd9: segs = 7'b1100111;
            4'd10: segs = 7'b1110111;
            4'd11: segs = 7'b1111100;
            4'd12: segs = 7'b0111001;
            4'd13: segs = 7'b1011110;
            4'd14: segs = 7'b1111001;
            4'd15: segs = 7'b1110001;
        endcase
    end
endmodule
