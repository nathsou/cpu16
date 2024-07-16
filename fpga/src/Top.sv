
`ifdef ALCHITRY_CU
  `define NUM_RAM_REGS 8192
`elsif ALCHITRY_AU
  `define NUM_RAM_REGS 65536
`else
  `error "Board not defined. Use ALCHITRY_CU or ALCHITRY_AU."
`endif

module Top (
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
    logic [15:0] displayReg;
    logic haltFlag;
    logic zeroFlag;
    logic carryFlag;
    logic memReadReady;

    ResetConditioner resetConditioner (
        .clk(clk),
        .in(~rstN),
        .out(rst)
    );

    SevenSegment4 segments (
        .clk(clk),
        .rst(rst),
        .value(displayReg),
        .segs(ioSeg),
        .sel(ioSel)
    );

    ROM rom (
        .addr(programCounter),
        .data(romData)
    );

    CPU #(.NUM_RAM_REGS(`NUM_RAM_REGS)) cpu (
        .clk(slowClk),
        .rst(rst),
        .romData(romData),
        .programCounter(programCounter),
        .displayReg(displayReg),
        .haltFlag(haltFlag),
        .zeroFlag(zeroFlag),
        .carryFlag(carryFlag),
        .memReadReady(memReadReady)
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
    assign ioLed[15:0] = romData;
endmodule
