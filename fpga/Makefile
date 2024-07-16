# https://github.com/YosysHQ/oss-cad-suite-build
OSSCAD_PATH = ~/keep/oss-cad-suite
OSSCAD_BIN = $(OSSCAD_PATH)/bin

# FPGA CHIPs
# Alchitry Cu
CU_CHIP = hx8k
CU_PACKAGE = cb132
CU_FREQ = 50 # MHz // 100 MHz but timing is not met
CU_PCF_PATH = cu.pcf
CU_TOP_MODULE = Top

# Nandland Go
GO_CHIP = hx1k
GO_PACKAGE = vq100
GO_FREQ = 25 # MHz
GO_PCF_PATH = go.pcf
GO_TOP_MODULE = GoBoardTop

OUTPUT_PATH = build
TESTBENCH_PATH = testbenches

SRC_PATH = src

.PHONY: all build clean test dotfile

all: build test

build: build-cu

build-cu:
	mkdir -p $(OUTPUT_PATH)
	$(OSSCAD_BIN)/yosys -p "verilog_defines -D ALCHITRY_CU=1; read_verilog -sv $(SRC_PATH)/*.sv; synth_ice40 -top $(CU_TOP_MODULE) -json $(OUTPUT_PATH)/$(CU_TOP_MODULE).json"
	$(OSSCAD_BIN)/nextpnr-ice40 --$(CU_CHIP) --package $(CU_PACKAGE) --json $(OUTPUT_PATH)/$(CU_TOP_MODULE).json --pcf $(CU_PCF_PATH) --asc $(OUTPUT_PATH)/$(CU_TOP_MODULE).asc --freq $(CU_FREQ)
	$(OSSCAD_BIN)/icepack $(OUTPUT_PATH)/$(CU_TOP_MODULE).asc  $(OUTPUT_PATH)/$(CU_TOP_MODULE).bin

build-go:
	mkdir -p $(OUTPUT_PATH)
	$(OSSCAD_BIN)/yosys -p "verilog_defines -D NANDLAND_GO=1; read_verilog -sv $(SRC_PATH)/*.sv; synth_ice40 -top $(GO_TOP_MODULE) -json $(OUTPUT_PATH)/$(GO_TOP_MODULE).json"
	$(OSSCAD_BIN)/nextpnr-ice40 --$(GO_CHIP) --package $(GO_PACKAGE) --json $(OUTPUT_PATH)/$(GO_TOP_MODULE).json --pcf $(GO_PCF_PATH) --asc $(OUTPUT_PATH)/$(GO_TOP_MODULE).asc --freq $(GO_FREQ)
	$(OSSCAD_BIN)/icepack $(OUTPUT_PATH)/$(GO_TOP_MODULE).asc  $(OUTPUT_PATH)/$(GO_TOP_MODULE).bin

test:
	mkdir -p $(OUTPUT_PATH)
	@echo "Running testbenches..."
	@for tb in $(TESTBENCH_PATH)/*.sv; do \
		tb_name=$$(basename $$tb .sv); \
		echo "Compiling and running $$tb_name..."; \
		$(OSSCAD_BIN)/iverilog -g2012 -o $(OUTPUT_PATH)/$$tb_name $(SRC_PATH)/*.sv $$tb && \
		cd $(OUTPUT_PATH) && $(OSSCAD_BIN)/vvp ./$$tb_name && cd ..; \
		if [ $$? -ne 0 ]; then \
			echo "Error: Testbench $$tb_name failed"; \
			exit 1; \
		fi; \
	done
	@echo "All testbenches passed successfully."

dotfile:
	mkdir -p $(OUTPUT_PATH)
	$(OSSCAD_BIN)/yosys -p "verilog_defines -D ALCHITRY_CU=1; read_verilog -sv $(SRC_PATH)/*.sv; hierarchy -check -top $(CU_TOP_MODULE); proc; opt; fsm; opt; memory; opt; show -format dot -prefix $(OUTPUT_PATH)/$(CU_TOP_MODULE)"

clean:
	rm -rf $(OUTPUT_PATH)
