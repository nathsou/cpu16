
module ALU (
    input logic [15:0] a,
    input logic [15:0] b,
    input logic [4:0] op,
    input logic enable,
    input logic zeroFlagIn,
    input logic carryFlagIn,
    output logic zeroFlagOut,
    output logic carryFlagOut,
    output logic conditionMet,
    output logic [16:0] out
);
    logic isSub = (op & 1'b1) == 1'b1;
    logic includeCarry = (op & 2'b11) == 2'b10 || (op & 2'b11) == 2'b11; // all adc/sbc ops
    logic forceCarry = (op & 2'b11) == 2'b01 || op == 5'd20; // all sub ops or inc
    logic [2:0] condition = op[4:2];
    logic carryIn = op != 5'd21 && (forceCarry || (includeCarry && carryFlagIn));

    always_comb begin
        conditionMet = 1'b1;
        carryFlagOut = carryFlagIn;
        out = 17'hxxxx;

        if (enable) begin
            case (op)
                5'd22: out = a & b;
                5'd23: out = ~(a & b);
                5'd24: out = a | b;
                5'd25: out = a ^ b;
                5'd26: out = a << (b & 4'hf);
                5'd27: out = a >> (b & 4'hf);
                default: begin
                    case (condition)
                        3'b000: conditionMet = 1'b1; // always
                        3'b001: conditionMet = zeroFlagIn; // if zero
                        3'b010: conditionMet = ~zeroFlagIn; // if not zero
                        3'b011: conditionMet = carryFlagIn; // if carry
                        3'b100: conditionMet = ~carryFlagIn; // if not carry
                    endcase

                    out = a + ((isSub ? ~b : b) & 16'hffff) + carryIn;
                    carryFlagOut = out[16];
                end
            endcase
        end
    end

    assign zeroFlagOut = out[15:0] == 16'h0;
endmodule
