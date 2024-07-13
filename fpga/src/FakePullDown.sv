
// https://forum.alchitry.com/t/alchitry-cu-and-io-pulldown-resistors/17

module FakePullDown #(
    parameter SIZE = 1
) (
    input  logic clk,
    inout  wire  [SIZE-1:0] in,
    output logic [SIZE-1:0] out
);
    logic [3:0] flip;
    logic [SIZE-1:0] saved;

    always_ff @(posedge clk) begin
        flip <= flip + 1;
        if (flip > 2) begin
            saved <= in;
        end
    end
    
    assign in = flip ? 'z : '0;
    assign out = saved;
endmodule
