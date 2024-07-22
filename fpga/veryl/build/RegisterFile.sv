module veryl_RegisterFile (
    input  logic          i_clk            ,
    input  logic          i_count_enable   ,
    input  logic          i_write_enable   ,
    input  logic [3-1:0]  i_write_address  ,
    input  logic [16-1:0] i_write_data     ,
    input  logic [3-1:0]  i_read_addr1     ,
    input  logic [3-1:0]  i_read_addr2     ,
    output logic [16-1:0] o_read_data1     ,
    output logic [16-1:0] o_read_data2     ,
    output logic [16-1:0] o_program_counter
);
    logic [16-1:0] r_regs [0:8-1];

    always_ff @ (posedge i_clk) begin
        case (i_write_address) inside
            0               : begin
                              end
            1, 2, 3, 4, 5, 6: begin
                                  if (i_write_enable) begin
                                      r_regs[i_write_address] <= i_write_data;
                                  end
                              end
            7: begin
                   if (i_write_enable) begin
                       r_regs[7] <= i_write_data;
                   end else if (i_count_enable) begin
                       r_regs[7] <= r_regs[7] + 1;
                   end
               end
        endcase
    end

    always_comb o_read_data1      = r_regs[i_read_addr1];
    always_comb o_read_data2      = r_regs[i_read_addr2];
    always_comb o_program_counter = r_regs[7];
endmodule

`ifdef __veryl_test_veryl_RegisterFile__
module veryl_TestRegisterFile;
endmodule
`endif
//# sourceMappingURL=RegisterFile.sv.map
