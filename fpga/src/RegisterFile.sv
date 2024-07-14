
module RegisterFile #(
  parameter DataWidth = 16,
  parameter NumRegs = 8,
  parameter IndexWidth = $clog2(NumRegs)
) (
  input logic clk,
  input logic rst,
  input logic countEnable, 
  input logic writeEnable,
  input logic [IndexWidth-1:0] writeAddr,
  input logic [DataWidth-1:0] writeData,
  input logic [IndexWidth-1:0] readAddr1,
  input logic [IndexWidth-1:0] readAddr2,
  output logic [DataWidth-1:0] readData1,
  output logic [DataWidth-1:0] readData2,
  output logic [DataWidth-1:0] programCounter,
  output logic [DataWidth-1:0] displayReg
);
  logic [DataWidth-1:0] regs[NumRegs];

  always_ff @(posedge clk or posedge rst) begin
    if (rst) begin
      for (int i = 1; i < NumRegs; i++) begin
        regs[i] <= '0;
      end
    end else begin
      if (writeEnable && writeAddr != '0) begin // Z is not writable
        regs[writeAddr] <= writeData;
      end
      
      if (countEnable && !(writeAddr == (NumRegs-1) && writeEnable)) begin
        regs[NumRegs-1] <= regs[NumRegs-1] + 1'b1;
      end
    end
  end

  assign readData1 = regs[readAddr1];
  assign readData2 = regs[readAddr2];
  assign programCounter = regs[NumRegs-1];
  assign displayReg = regs[2];
endmodule
