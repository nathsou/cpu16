
module GoBoardTop (
    input logic clk,
    input logic [3:0] button,
    output logic [3:0] led,
    output wire segment1A,
    output wire segment1B,
    output wire segment1C,
    output wire segment1D,
    output wire segment1E,
    output wire segment1F,
    output wire segment1G,
    output wire segment2A,
    output wire segment2B,
    output wire segment2C,
    output wire segment2D,
    output wire segment2E,
    output wire segment2F,
    output wire segment2G
);
    logic rst;
    logic [15:0] programCounter;
    logic [15:0] romData;
    logic [15:0] displayReg;
    logic haltFlag;
    logic zeroFlag;
    logic carryFlag;
    logic memReadReady;

    ResetConditioner resetConditioner (
        .clk(clk),
        .in(button[0] || button[1] || button[2] || button[3]),
        .out(rst)
    );

    GoBoardSevenSegment seg1 (
        .clk(clk),
        .value(displayReg[7:4]),
        .segmentA(segment1A),
        .segmentB(segment1B),
        .segmentC(segment1C),
        .segmentD(segment1D),
        .segmentE(segment1E),
        .segmentF(segment1F),
        .segmentG(segment1G)
    );

    GoBoardSevenSegment seg2 (
        .clk(clk),
        .value(displayReg[3:0]),
        .segmentA(segment2A),
        .segmentB(segment2B),
        .segmentC(segment2C),
        .segmentD(segment2D),
        .segmentE(segment2E),
        .segmentF(segment2F),
        .segmentG(segment2G)
    );

    ROM rom (
        .addr(programCounter),
        .data(romData)
    );

    CPU #(.NUM_RAM_REGS(4096)) cpu (
        .clk(clk),
        .rst(rst),
        .romData(romData),
        .programCounter(programCounter),
        .displayReg(displayReg),
        .haltFlag(haltFlag),
        .zeroFlag(zeroFlag),
        .carryFlag(carryFlag),
        .memReadReady(memReadReady)
    );

    assign led = {memReadReady, zeroFlag, carryFlag, haltFlag};
endmodule
