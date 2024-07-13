module ROM (
    input logic [15:0] addr,
    output logic [15:0] data
);
    always_comb begin
        case (addr)
            16'h0000: data = 16'h5655;
            16'h0001: data = 16'h5811;
            16'h0002: data = 16'h4800;
            16'h0003: data = 16'hC261;
            16'h0004: data = 16'h6808;
            16'h0005: data = 16'hFFB0;
            16'h0006: data = 16'hD261;
            16'h0007: data = 16'hC261;
            16'h0008: data = 16'h6804;
            16'h0009: data = 16'hFFB0;
            16'h000A: data = 16'hC914;
            16'h000B: data = 16'h6806;
            16'h000C: data = 16'hFFA1;
            16'h000D: data = 16'hC914;
            16'h000E: data = 16'h0000;
            default: data = 16'h0000;
        endcase
    end
endmodule