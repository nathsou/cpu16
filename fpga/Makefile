# https://github.com/YosysHQ/oss-cad-suite-build
OSSCAD_PATH = ~/keep/oss-cad-suite
OSSCAD_BIN = $(OSSCAD_PATH)/bin

# FPGA CHIP
CHIP = hx8k
PACKAGE = cb132
FREQ = 100 # MHz
PCF_PATH = cu.pcf

TOP_MODULE = Top
OUTPUT_PATH = build
TESTBENCH_PATH = testbenches

SRC_PATH = src

.PHONY: all build clean test

all: build test

build:
	mkdir -p $(OUTPUT_PATH)
	$(OSSCAD_BIN)/yosys -p "read_verilog -sv $(SRC_PATH)/*.sv; synth_ice40 -top $(TOP_MODULE) -json $(OUTPUT_PATH)/$(TOP_MODULE).json"
	$(OSSCAD_BIN)/nextpnr-ice40 --$(CHIP) --package $(PACKAGE) --json $(OUTPUT_PATH)/$(TOP_MODULE).json --pcf $(PCF_PATH) --asc $(OUTPUT_PATH)/$(TOP_MODULE).asc --freq $(FREQ)
	$(OSSCAD_BIN)/icepack $(OUTPUT_PATH)/$(TOP_MODULE).asc  $(OUTPUT_PATH)/$(TOP_MODULE).bin

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

clean:
	rm -rf $(OUTPUT_PATH)