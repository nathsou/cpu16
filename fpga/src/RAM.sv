
module RAM #(
    parameter DataWidth = 16,
    parameter NumRegs = 8,
    parameter IndexWidth = $clog2(NumRegs)
) (
    input logic clk,
    input logic writeEnable,
    input logic [IndexWidth-1:0] writeAddr,
    input logic [DataWidth-1:0] writeData,
    input logic [IndexWidth-1:0] readAddr,
    output logic [DataWidth-1:0] readData
);
    logic [DataWidth-1:0] mem[NumRegs];

    always_ff @(posedge clk) begin
        if (writeEnable) begin
            mem[writeAddr] <= writeData;
        end

        readData <= mem[readAddr];
    end
endmodule
