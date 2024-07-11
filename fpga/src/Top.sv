
module Top (
    input  logic clk,
    input  logic rst_n,
    output logic [7:0] led
);
    logic rst;
    
    ResetConditioner resetConditioner (
        .clk (clk),
        .in (~rst_n),
        .out (rst)
    );
    
    assign led = rst ? 8'hAA : 8'h55;
endmodule
