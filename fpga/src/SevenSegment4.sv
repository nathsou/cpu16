
module SevenSegment4 (
    input logic clk,
    input logic rst,
    input logic [15:0] value,
    output logic [6:0] segs,
    output logic [3:0] sel
);
    logic [12:0] counter;
    logic [3:0] activeChar;
    logic [6:0] segsNeg;

    SevenSegment seg (
        .char(activeChar),
        .segs(segsNeg)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= '0;
        end else begin
            counter <= counter + 1'b1;
        end
    end

    always_comb begin
        unique case (counter[12:11])
            2'b00: begin
                activeChar = value[3:0];
                sel = 4'b1110;
            end
            2'b01: begin
                activeChar = value[7:4];
                sel = 4'b1101;
            end
            2'b10: begin
                activeChar = value[11:8];
                sel = 4'b1011;
            end
            2'b11: begin
                activeChar = value[15:12];
                sel = 4'b0111;
            end
        endcase
    end

    assign segs = ~segsNeg;
endmodule
