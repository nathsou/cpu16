
module NexyA7SevenSegment (
    input  logic [31:0] x,
    input  logic        clk,
    output logic [6:0]  seg,
    output logic [7:0]  an,
    output logic        dp
);

    logic [2:0]  s;
    logic [3:0]  digit;
    logic [7:0]  aen;
    logic [19:0] clkdiv;

    assign dp  = 1'b1;
    assign s   = clkdiv[19:17];
    assign aen = 8'b11111111; // all turned off initially

    // Quad 4-to-1 MUX
    always_ff @(posedge clk) begin
        unique case (s)
            3'd0: digit = x[3:0];
            3'd1: digit = x[7:4];
            3'd2: digit = x[11:8];
            3'd3: digit = x[15:12];
            3'd4: digit = x[19:16];
            3'd5: digit = x[23:20];
            3'd6: digit = x[27:24];
            3'd7: digit = x[31:28];
            default: digit = x[3:0];
        endcase
    end

    // Decoder for 7-segment display values
    always_comb begin
        unique case (digit)
            4'h0: seg = 7'b1000000;
            4'h1: seg = 7'b1111001;
            4'h2: seg = 7'b0100100;
            4'h3: seg = 7'b0110000;
            4'h4: seg = 7'b0011001;
            4'h5: seg = 7'b0010010;
            4'h6: seg = 7'b0000010;
            4'h7: seg = 7'b1111000;
            4'h8: seg = 7'b0000000;
            4'h9: seg = 7'b0010000;
            4'hA: seg = 7'b0001000;
            4'hB: seg = 7'b0000011;
            4'hC: seg = 7'b1000110;
            4'hD: seg = 7'b0100001;
            4'hE: seg = 7'b0000110;
            4'hF: seg = 7'b0001110;
            default: seg = 7'b0000000; // 'U'
        endcase
    end

    // Anode control
    always_comb begin
        an = 8'b11111111;
        if (aen[s]) begin
            an[s] = 1'b0;
        end
    end

    // Clock divider
    always_ff @(posedge clk) begin
        clkdiv <= clkdiv + 1'b1;
    end
endmodule