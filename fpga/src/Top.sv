
module Top (
    input  logic clk,
    input  logic rstN,
    inout  logic [4:0] ioButton,
    output logic [7:0] led,
    output logic [6:0] ioSeg,
    output logic [3:0] ioSel
);
    logic rst;
    logic [7:0] counter;
    logic manualClk;
    logic pulledDownBtn;

    ResetConditioner resetConditioner (
        .clk(clk),
        .in(~rstN),
        .out(rst)
    );

    FakePullDown #(.SIZE(1)) fakePullDown (
        .clk(clk),
        .in(ioButton[0]),
        .out(pulledDownBtn)
    );
    
    ButtonDebouncer buttonDebouncer (
        .clk(clk),
        .rst(rst),
        .in(pulledDownBtn),
        .out(manualClk)
    );

    SevenSegment4 segments (
        .clk(clk),
        .rst(rst),
        .value(counter),
        .segs(ioSeg),
        .sel(ioSel)
    );

    always_ff @(posedge manualClk or posedge rst) begin
        if (rst) begin
            counter <= '0;
        end else begin
            counter <= counter + 1'b1;
        end
    end

    assign led = counter;
endmodule
