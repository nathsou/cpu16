
module CPU #(
    parameter NUM_RAM_REGS = 65536
) (
    input logic clk,
    input logic rst,
    input logic [15:0] romData,
    output logic [15:0] programCounter,
    output logic [15:0] displayReg,
    output logic haltFlag,
    output logic zeroFlag,
    output logic carryFlag,
    output logic memReadReady
);
    logic regWriteEnable;
    logic [2:0] regWriteAddr;
    logic [2:0] regReadAddr1;
    logic [2:0] regReadAddr2;
    logic [15:0] regWriteData;
    logic [15:0] regReadData1;
    logic [15:0] regReadData2;
    logic [16:0] aluOut;
    logic ramWriteEnable;
    logic [15:0] ramWriteAddr;
    logic [15:0] ramWriteData;
    logic [15:0] ramReadAddr;
    logic [15:0] ramReadData;
    logic aluEnable;
    logic aluConditionMet;
    logic haltFlag;
    logic zeroFlag;
    logic carryFlag;
    logic aluZeroOut;
    logic aluCarryOut;
    // stall for one cycle before reading from memory during a load operation
    logic isReadingMem = ~memReadReady && romData[15:14] == 2'b10 && romData[7];
    logic countEnable = ~haltFlag && ~isReadingMem;

    RegisterFile #(.DataWidth(16), .NumRegs(8)) regs (
        .clk(clk),
        .rst(rst),
        .writeEnable(regWriteEnable),
        .countEnable(countEnable),
        .writeAddr(regWriteAddr),
        .writeData(regWriteData),
        .readAddr1(regReadAddr1),
        .readAddr2(regReadAddr2),
        .readData1(regReadData1),
        .readData2(regReadData2),
        .programCounter(programCounter),
        .displayReg(displayReg)
    );

    ALU alu (
        .a(regReadData1),
        .b(regReadData2),
        .op(romData[4:0]),
        .enable(aluEnable),
        .zeroFlagIn(zeroFlag),
        .carryFlagIn(carryFlag),
        .zeroFlagOut(aluZeroOut),
        .carryFlagOut(aluCarryOut),
        .conditionMet(aluConditionMet),
        .out(aluOut)
    );

    RAM #(.DataWidth(16), .NumRegs(NUM_RAM_REGS)) ram (
        .clk(clk),
        .writeEnable(ramWriteEnable),
        .writeAddr(ramWriteAddr),
        .writeData(ramWriteData),
        .readAddr(ramReadAddr),
        .readData(ramReadData)
    );

    always_comb begin
        aluEnable = 1'b0;
        regWriteEnable = 1'b0;
        ramWriteEnable = 1'b0;
        regWriteAddr = 3'bxxx;
        regReadAddr1 = 3'bxxx;
        regReadAddr2 = 3'bxxx;
        regWriteData = 16'hxxxx;
        ramWriteAddr = 16'hxxxx;
        ramWriteData = 16'hxxxx;
        ramReadAddr = 16'hxxxx;

        if (~haltFlag) begin
            case (romData[15:14])
                2'b01: begin // set: [{01} <dst: 3> <val: 11>]
                    regWriteEnable = 1'b1;
                    regWriteAddr = romData[13:11];
                    regWriteData = romData[10:0];
                end
                2'b10: begin // mem: [{10} <dst: 3> <addr: 3> <load/store: 1> <offset: 7>]
                    regReadAddr1 = romData[10:8];

                    if (romData[7]) begin // load
                        regWriteEnable = memReadReady;
                        regWriteAddr = romData[13:11];
                        regWriteData = ramReadData;
                        ramReadAddr = regReadData1 + romData[6:0];
                    end else begin // store
                        ramWriteEnable = 1'b1;
                        ramWriteAddr = regReadData1 + romData[6:0];
                        regReadAddr2 = romData[13:11];
                        ramWriteData = regReadData2;
                    end
                end
                2'b11: begin // alu: [{11} <dst: 3> <src1: 3> <src2: 3> <op: 5>]
                    aluEnable = 1'b1;
                    regWriteAddr = romData[13:11];
                    regReadAddr1 = romData[10:8];
                    regReadAddr2 = romData[7:5];
                    regWriteData = aluOut;
                    regWriteEnable = aluConditionMet;
                end
            endcase
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            haltFlag <= 1'b0;
            zeroFlag <= 1'b0;
            carryFlag <= 1'b0;
            memReadReady <= 1'b0;
        end else begin
            if (~haltFlag) begin
                case (romData[15:14])
                    2'b00: begin
                        case (romData[2:0])
                            3'b000: haltFlag <= 1'b1;
                            3'b001: zeroFlag <= 1'b1;
                            3'b010: zeroFlag <= 1'b0;
                            3'b011: carryFlag <= 1'b1;
                            3'b100: carryFlag <= 1'b0;
                        endcase
                    end
                    2'b10: begin
                        if (romData[7]) begin
                            memReadReady <= ~memReadReady;
                        end
                    end
                    2'b11: begin
                        if (aluConditionMet) begin
                            zeroFlag <= aluZeroOut;
                            carryFlag <= aluCarryOut;
                        end
                    end
                endcase
            end
        end
    end
endmodule
