
module PPU (
    input logic clk100mhz,
    input logic nameTableWriteEnable,
    input logic [7:0] nameTableWriteData,
    input logic [12:0] nameTableWriteAddr,
    output logic hsync,
    output logic vsync,
    output logic [3:0] vgaRed,
    output logic [3:0] vgaGreen,
    output logic [3:0] vgaBlue
);
    localparam H_ACTIVE = 640;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC = 96;
    localparam H_BACK_PORCH = 48;
    localparam H_TOTAL = H_ACTIVE + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH;

    localparam V_ACTIVE = 480;
    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC = 2;
    localparam V_BACK_PORCH = 33;
    localparam V_TOTAL = V_ACTIVE + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;

    localparam TILE_SIZE = 8;
    localparam TILES_X = H_ACTIVE / TILE_SIZE;
    localparam TILES_Y = V_ACTIVE / TILE_SIZE;

    localparam STAGE_FETCH_NAME_TABLE = 2'b00;
    localparam STAGE_FETCH_PATTERN_TABLE = 2'b01;
    localparam STAGE_IDLE = 2'b10;
    localparam STAGE_RENDER = 2'b11;

    // Counter for horizontal and vertical sync
    logic [9:0] col = 0;
    logic [9:0] row = 0;
    logic isRendering = (col < H_ACTIVE) && (row < V_ACTIVE);

    logic [63:0] patternTable [128];
    logic [7:0] nameTable [TILES_X * TILES_Y];
    logic [1:0] stage = 2'b00;
    logic [7:0] tileX = col >> 3;
    logic [6:0] tileY = row >> 3;
    logic [2:0] subX = 8'd7 - (col & 8'd7);
    logic [2:0] subY = 8'd7 - (row & 8'd7);
    logic [12:0] nameTableIndex = tileY * TILES_X + tileX;
    logic [7:0] patternTableIndex;
    logic pixel;

    initial begin
        $readmemh("patternTable.hex", patternTable);

        for (int i = 0; i < TILES_X * TILES_Y; i = i + 1) begin
            nameTable[i] = 8'h0;
        end
    end

    logic [1:0] clockDiv = 2'b00;
    logic clk25mhz = clockDiv[1];

    // Horizontal and vertical counters
    always_ff @(posedge clk25mhz) begin
        if (col == H_TOTAL - 1) begin
            col <= 0;
            if (row == V_TOTAL - 1)
                row <= 0;
            else
                row <= row + 1;
        end else begin
            col <= col + 1;
        end

        hsync <= (col >= (H_ACTIVE + H_FRONT_PORCH) &&
                    col < (H_ACTIVE + H_FRONT_PORCH + H_SYNC)) ? 1'b0 : 1'b1;
        vsync <= (row >= (V_ACTIVE + V_FRONT_PORCH) &&
                    row < (V_ACTIVE + V_FRONT_PORCH + V_SYNC)) ? 1'b0 : 1'b1;
    end

    always_ff @(posedge clk100mhz) begin
        clockDiv <= clockDiv + 1;

        if (nameTableWriteEnable) begin
            nameTable[nameTableWriteAddr] <= nameTableWriteData;
        end

        if (isRendering) begin
            unique case (stage)
                STAGE_FETCH_NAME_TABLE: begin
                    patternTableIndex <= nameTable[nameTableIndex];
                    stage <= STAGE_FETCH_PATTERN_TABLE;
                end
                STAGE_FETCH_PATTERN_TABLE: begin
                    pixel <= patternTable[patternTableIndex > 8'h20 ? patternTableIndex - 8'h20 : 8'h0][subY * 8 + subX];
                    stage <= STAGE_IDLE;
                end
                STAGE_IDLE: begin
                    stage <= STAGE_RENDER;
                end
                STAGE_RENDER: begin
                    if (pixel == 1'b1) begin
                        vgaRed <= 4'hf;
                        vgaGreen <= 4'hf;
                        vgaBlue <= 4'hf;
                    end else begin
                        vgaRed <= 4'h0;
                        vgaGreen <= 4'h0;
                        vgaBlue <= 4'h0;
                    end

                    stage <= STAGE_FETCH_NAME_TABLE;
                end
            endcase
        end else begin
            vgaRed <= 4'h0;
            vgaGreen <= 4'h0;
            vgaBlue <= 4'h0;
        end
    end
endmodule
