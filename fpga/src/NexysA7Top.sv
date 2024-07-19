
module NexysA7Top (
    input logic CLK100MHZ,
    input logic BTNR,
    output logic [6:0] SEG,
    output logic [7:0] AN,
    output logic DP,
    output logic [15:0] LED
);
    logic rst;
    logic btn;
    logic [15:0] programCounter;
    logic [15:0] romData;
    logic [31:0] displayReg;
    logic haltFlag;
    logic zeroFlag;
    logic carryFlag;
    logic memReadReady;

    ResetConditioner resetConditioner (
        .clk(CLK100MHZ),
        .in(BTNR),
        .out(rst)
    );

    ROM rom (
        .addr(programCounter),
        .data(romData)
    );

    CPU #(.NUM_RAM_REGS(65536)) cpu (
        .clk(CLK100MHZ),
        .rst(rst),
        .romData(romData),
        .programCounter(programCounter),
        .displayReg(displayReg),
        .haltFlag(haltFlag),
        .zeroFlag(zeroFlag),
        .carryFlag(carryFlag),
        .memReadReady(memReadReady)
    );

    NexyA7SevenSegment sevenSeg (
        .clk(CLK100MHZ),
        .x(displayReg),
        .seg(SEG[6:0]),
        .an(AN[7:0]),
        .dp(DP)
    );

    assign LED[11:0] = programCounter[11:0];
    assign LED[15:12] = {haltFlag, zeroFlag, carryFlag, memReadReady};
endmodule
