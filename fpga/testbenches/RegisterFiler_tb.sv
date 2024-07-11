`timescale 1ns / 1ps

module RegisterFile_tb;

  // Parameters
  parameter DataWidth  = 8;
  parameter NumRegs    = 16;
  parameter IndexWidth = $clog2(NumRegs);

  // Signals
  logic                  clk;
  logic                  writeEn;
  logic [IndexWidth-1:0] writeAddr;
  logic [ DataWidth-1:0] writeData;
  logic [IndexWidth-1:0] readAddr1;
  logic [IndexWidth-1:0] readAddr2;
  logic [ DataWidth-1:0] readData1;
  logic [ DataWidth-1:0] readData2;

  // Instantiate the RegisterFile
  RegisterFile #(
    .DataWidth(DataWidth),
    .NumRegs(NumRegs),
    .IndexWidth(IndexWidth)
  ) dut (
    .*
  );

  // Clock generation
  always #5 clk = ~clk;

  // Test stimulus
  initial begin
    // Initialize signals
    clk       = 0;
    writeEn   = 0;
    writeAddr = 0;
    writeData = 0;
    readAddr1 = 0;
    readAddr2 = 0;

    // Reset
    #10;

    // Test case 1: Write to register 0 and read it back
    writeEn   = 1;
    writeAddr = 0;
    writeData = 8'hAA;
    #10;
    writeEn   = 0;
    readAddr1 = 0;
    #10;
    assert(readData1 == 8'hAA) else $error("Test case 1 failed");

    // Test case 2: Write to register 15 and read it back
    writeEn   = 1;
    writeAddr = 15;
    writeData = 8'h55;
    #10;
    writeEn   = 0;
    readAddr2 = 15;
    #10;
    assert(readData2 == 8'h55) else $error("Test case 2 failed");

    // Test case 3: Simultaneous read from two different registers
    readAddr1 = 0;
    readAddr2 = 15;
    #10;
    assert(readData1 == 8'hAA && readData2 == 8'h55) else $error("Test case 3 failed");

    // Test case 4: Write to a register while reading from it
    writeEn   = 1;
    writeAddr = 7;
    writeData = 8'h33;
    readAddr1 = 7;
    #10;
    writeEn   = 0;
    #10;
    assert(readData1 == 8'h33) else $error("Test case 4 failed");

    // Test case 5: Write disabled
    writeEn   = 0;
    writeAddr = 0;
    writeData = 8'hFF;
    #10;
    readAddr1 = 0;
    #10;
    assert(readData1 == 8'hAA) else $error("Test case 5 failed");

    // End simulation
    $display("All test cases completed");
    $finish;
  end

  // Optional: Dump waveforms
  initial begin
    $dumpfile("RegisterFile_tb.vcd");
    $dumpvars(0, RegisterFile_tb);
  end

endmodule
