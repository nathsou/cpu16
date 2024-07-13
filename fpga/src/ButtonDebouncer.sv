module ButtonDebouncer #(
    parameter CLOCK_CYCLES = 1_000_000  // 10ms at 100MHz clock
)(
    input  logic clk,           // System clock
    input  logic rst,
    input  logic in,     // Raw button input
    output logic out     // Debounced button output
);
    logic [$clog2(CLOCK_CYCLES)-1:0] counter;
    logic button_state;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= '0;
            button_state <= 1'b0;
            out <= 1'b0;
        end else begin
            if (in != button_state) begin
                // Button state changed, reset counter
                counter <= '0;
                button_state <= in;
            end else if (counter < CLOCK_CYCLES) begin
                // Increment counter
                counter <= counter + 1'b1;
            end else begin
                // Counter reached DEBOUNCE_TIME, update output
                out <= button_state;
            end
        end
    end
endmodule
