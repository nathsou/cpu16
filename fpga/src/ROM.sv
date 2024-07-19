module ROM (
    input logic [15:0] addr,
    output logic [15:0] data
);
    always_comb begin
        case (addr)
            16'h0000: data = 16'h71FF;
            16'h0001: data = 16'h8002;
            16'h0002: data = 16'h8001;
            16'h0003: data = 16'h6BE8;
            16'h0004: data = 16'hED15;
            16'h0005: data = 16'hA800;
            16'h0006: data = 16'h8880;
            16'h0007: data = 16'h5803;
            16'h0008: data = 16'h6805;
            16'h0009: data = 16'hEDE0;
            16'h000A: data = 16'hAE00;
            16'h000B: data = 16'hF614;
            16'h000C: data = 16'h6822;
            16'h000D: data = 16'hFFA0;
            16'h000E: data = 16'hC020;
            16'h000F: data = 16'h6813;
            16'h0010: data = 16'hFFA4;
            16'h0011: data = 16'h8880;
            16'h0012: data = 16'h5805;
            16'h0013: data = 16'h6805;
            16'h0014: data = 16'hEDE0;
            16'h0015: data = 16'hAE00;
            16'h0016: data = 16'hF614;
            16'h0017: data = 16'h6817;
            16'h0018: data = 16'hFFA0;
            16'h0019: data = 16'hC020;
            16'h001A: data = 16'h6808;
            16'h001B: data = 16'hFFA4;
            16'h001C: data = 16'h8880;
            16'h001D: data = 16'hC915;
            16'h001E: data = 16'h8800;
            16'h001F: data = 16'h681A;
            16'h0020: data = 16'hFFA9;
            16'h0021: data = 16'h680A;
            16'h0022: data = 16'hFFA0;
            16'h0023: data = 16'h8880;
            16'h0024: data = 16'h9081;
            16'h0025: data = 16'h9882;
            16'h0026: data = 16'hDB20;
            16'h0027: data = 16'hD202;
            16'h0028: data = 16'h9001;
            16'h0029: data = 16'h9802;
            16'h002A: data = 16'h680F;
            16'h002B: data = 16'hFFA1;
            16'h002C: data = 16'h8881;
            16'h002D: data = 16'h9082;
            16'h002E: data = 16'h0000;
            16'h002F: data = 16'h5000;
            16'h0030: data = 16'hC161;
            16'h0031: data = 16'h6808;
            16'h0032: data = 16'hFFB0;
            16'h0033: data = 16'hC961;
            16'h0034: data = 16'hC161;
            16'h0035: data = 16'h6804;
            16'h0036: data = 16'hFFB0;
            16'h0037: data = 16'hD214;
            16'h0038: data = 16'h6806;
            16'h0039: data = 16'hFFA1;
            16'h003A: data = 16'hD214;
            16'h003B: data = 16'hF615;
            16'h003C: data = 16'hBE80;
            default: data = 16'h0000;
        endcase
    end
endmodule