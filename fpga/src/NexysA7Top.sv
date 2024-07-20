module NexysA7Top (
    input logic CLK100MHZ,
    input logic BTNR,
    output logic [6:0] SEG,
    output logic [7:0] AN,
    output logic DP,
    output logic [15:0] LED,
    output logic VGA_HS,
    output logic VGA_VS,
    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B
);
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

    logic [7:0] nameTableWriteData = ramWriteData[7:0];
    logic [12:0] nameTableWriteAddr;
    logic nameTableWriteEnable = ramWriteEnable && ramWriteAddr == 16'hffff && ~ramWriteData[15];

    always_ff @(posedge CLK100MHZ) begin
        // memory mapped I/O
        if (ramWriteEnable) begin
            case (ramWriteAddr)
                16'hffff: begin
                    if (ramWriteData[15]) begin
                        nameTableWriteAddr <= ramWriteData[12:0];
                    end
                end
                default: begin
                    // do nothing
                end
            endcase
        end
    end

    ResetConditioner resetConditioner (
        .clk(CLK100MHZ),
        .in(BTNR),
        .out(rst)
    );

    ROM rom (
        .addr(programCounter),
        .data(romData)
    );

    RAM #(.DataWidth(16), .NumRegs(65536)) ram (
        .clk(CLK100MHZ),
        .writeEnable(ramWriteEnable),
        .writeAddr(ramWriteAddr),
        .writeData(ramWriteData),
        .readAddr(ramReadAddr),
        .readData(ramReadData)
    );

    CPU cpu (
        .clk(CLK100MHZ),
        .rst(rst),
        .romData(romData),
        .ramReadData(ramReadData),
        .programCounter(programCounter),
        .displayReg(displayReg),
        .haltFlag(haltFlag),
        .zeroFlag(zeroFlag),
        .carryFlag(carryFlag),
        .memReadReady(memReadReady),
        .ramWriteEnable(ramWriteEnable),
        .ramWriteAddr(ramWriteAddr),
        .ramWriteData(ramWriteData),
        .ramReadAddr(ramReadAddr)
    );

    PPU ppu (
        .clk100mhz(CLK100MHZ),
        .nameTableWriteEnable(nameTableWriteEnable),
        .nameTableWriteData(nameTableWriteData),
        .nameTableWriteAddr(nameTableWriteAddr),
        .hsync(VGA_HS),
        .vsync(VGA_VS),
        .vgaRed(VGA_R),
        .vgaGreen(VGA_G),
        .vgaBlue(VGA_B)
    );

    NexysA7SevenSegment sevenSeg (
        .clk(CLK100MHZ),
        .x(displayReg),
        .seg(SEG[6:0]),
        .an(AN[7:0]),
        .dp(DP)
    );

    assign LED[11:0] = programCounter[11:0];
    assign LED[15:12] = {haltFlag, zeroFlag, carryFlag, memReadReady};
endmodule
