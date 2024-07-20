
`ifdef ALCHITRY_CU
  `define NUM_RAM_REGS 8192
`else
  `define NUM_RAM_REGS 4096
`endif

module AlchitryTop (
    input logic clk,
    input logic rstN,
    output logic [7:0] led,
    output logic [6:0] ioSeg,
    output logic [3:0] ioSel,
    output logic [23:0] ioLed
);
    logic slowClk;
    logic rst;
    logic [15:0] programCounter;
    logic [15:0] romData;
    logic [31:0] displayReg;
    logic haltFlag;
    logic zeroFlag;
    logic carryFlag;
    logic memReadReady;
    logic ramWriteEnable;
    logic [15:0] ramWriteAddr;
    logic [15:0] ramWriteData;
    logic [15:0] ramReadAddr;
    logic [15:0] ramReadData;

    ResetConditioner resetConditioner (
        .clk(clk),
        .in(~rstN),
        .out(rst)
    );

    SevenSegment4 segments (
        .clk(clk),
        .rst(rst),
        .value(displayReg[15:0]),
        .segs(ioSeg),
        .sel(ioSel)
    );

    ROM rom (
        .addr(programCounter),
        .data(romData)
    );

    RAM #(.DataWidth(16), .NumRegs(`NUM_RAM_REGS)) ram (
        .clk(slowClk),
        .writeEnable(ramWriteEnable),
        .writeAddr(ramWriteAddr),
        .writeData(ramWriteData),
        .readAddr(ramReadAddr),
        .readData(ramReadData)
    );

    CPU cpu (
        .clk(slowClk),
        .rst(rst),
        .romData(romData),
        .ramReadData(ramReadData),
        .programCounter(programCounter),
        .displayReg(displayReg[15:0]),
        .haltFlag(haltFlag),
        .zeroFlag(zeroFlag),
        .carryFlag(carryFlag),
        .memReadReady(memReadReady),
        .ramWriteEnable(ramWriteEnable),
        .ramWriteAddr(ramWriteAddr),
        .ramWriteData(ramWriteData),
        .ramReadAddr(ramReadAddr)
    );

    `ifdef ALCHITRY_CU
        // We need to slow down the clock for the ALCHITRY CU for the CPU to run reliably
        always_ff @(posedge clk) begin
            slowClk <= ~slowClk;
        end
    `else
        assign slowClk = clk;
    `endif

    assign led = programCounter;
    assign ioLed[23:20] = {haltFlag, carryFlag, zeroFlag, memReadReady};
    assign ioLed[19:16] = 4'b0;
    assign ioLed[15:0] = romData;
endmodule
