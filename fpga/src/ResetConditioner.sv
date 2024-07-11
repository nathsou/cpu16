
module ResetConditioner #(
    parameter int STAGES = 4
) (
    input  logic clk,
    input  logic in,
    output logic out
);

    logic [STAGES-1:0] stage;

    always_ff @(posedge clk) begin
        if (in) begin
            stage <= '1;
        end else begin
            stage <= {stage[STAGES-2:0], 1'b0};
        end
    end

    assign out = stage[STAGES-1];

endmodule
