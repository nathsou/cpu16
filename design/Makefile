SHELL := /bin/bash
TOP := cpu16_Top
TARGET := nexysa7
current_dir := ${CURDIR}
SOURCES := ${current_dir}/build/Top.sv
SOURCES += ${current_dir}/build/ResetConditioner.sv
SOURCES += ${current_dir}/build/ALU.sv
SOURCES += ${current_dir}/build/RegisterFile.sv
SOURCES += ${current_dir}/build/CPU.sv
SOURCES += ${current_dir}/build/ROM.sv
SOURCES += ${current_dir}/build/RAM.sv
SOURCES += ${current_dir}/build/SevenSegment.sv

BUILDDIR := ${current_dir}/build
BOARD_BUILDDIR := ${BUILDDIR}/${TARGET}

DEVICE := xc7a100t_test
BITSTREAM_DEVICE := artix7
PARTNAME := xc7a100tcsg324-1
OFL_BOARD := unsupported

VIVADO_CMD := C:\Xilinx\Vivado\2024.1\bin\vivado.bat
PROG_CMD := prog_nexysa7

XDC := ${current_dir}/nexysa7.xdc

# Determine the type of constraint being used
ifneq (${XDC},)
  XDC_CMD := -x ${XDC}
endif

# Determine if we should use Surelog/UHDM to read sources
ifneq (${SURELOG_CMD},)
  SURELOG_OPT := -s ${SURELOG_CMD}
endif

define conda_run
	source $(F4PGA_INSTALL_DIR)/$(FPGA_FAM)/conda/etc/profile.d/conda.sh && \
	conda activate $(FPGA_FAM) && \
	cd ${BUILDDIR} && \
	$(1)
endef

# Check if running in WSL
ifeq ($(shell uname -r | sed -n 's/.*\( *Microsoft *\).*/\1/ip'),microsoft)
  BUILD_VIVADO_CMD := build-vivado-wsl
else
  BUILD_VIVADO_CMD := build-vivado-windows
endif

.DELETE_ON_ERROR:

# Build design using F4PGA
build: build-veryl ${BOARD_BUILDDIR}/${TOP}.bit

build-veryl:
	veryl build

${SOURCES} cpu16.f: build-veryl

${BOARD_BUILDDIR}:
	mkdir -p ${BOARD_BUILDDIR}

${BOARD_BUILDDIR}/${TOP}.eblif: ${SOURCES} ${XDC} | ${BOARD_BUILDDIR}
	$(call conda_run, symbiflow_synth -t ${TOP} ${SURELOG_OPT} -v ${SOURCES} -d ${BITSTREAM_DEVICE} -p ${PARTNAME} ${XDC_CMD})

${BOARD_BUILDDIR}/${TOP}.net: ${BOARD_BUILDDIR}/${TOP}.eblif
	$(call conda_run, symbiflow_pack -e ${TOP}.eblif -d ${DEVICE} 2>&1 > /dev/null)

${BOARD_BUILDDIR}/${TOP}.place: ${BOARD_BUILDDIR}/${TOP}.net
	$(call conda_run, symbiflow_place -e ${TOP}.eblif -d ${DEVICE} -n ${TOP}.net -P ${PARTNAME} 2>&1 > /dev/null)

${BOARD_BUILDDIR}/${TOP}.route: ${BOARD_BUILDDIR}/${TOP}.place
	$(call conda_run, symbiflow_route -e ${TOP}.eblif -d ${DEVICE} 2>&1 > /dev/null)

${BOARD_BUILDDIR}/${TOP}.fasm: ${BOARD_BUILDDIR}/${TOP}.route
	$(call conda_run, symbiflow_write_fasm -e ${TOP}.eblif -d ${DEVICE})

${BOARD_BUILDDIR}/${TOP}.bit: ${BOARD_BUILDDIR}/${TOP}.fasm
	$(call conda_run, symbiflow_write_bitstream -d ${BITSTREAM_DEVICE} -f ${TOP}.fasm -p ${PARTNAME} -b ${TOP}.bit)

# New rule to build with Vivado based on environment
build-vivado: $(BUILD_VIVADO_CMD)

build-vivado-windows: build-veryl
	${VIVADO_CMD} -nojournal -nolog -mode batch -source .\nexysa7.tcl

build-vivado-wsl: build-veryl
	@echo "Building project for Nexys A7 board using Vivado for Windows from WSL..."
	@tmp_dir=$$(wslpath $$(wslvar TEMP))/cpu16_build; \
	cwd=$$(pwd); \
	rm -rf $$tmp_dir; \
	mkdir -p $$tmp_dir; \
	cp -rf . $$tmp_dir; \
	cd $$tmp_dir; \
	powershell.exe -Command "${VIVADO_CMD} -nojournal -nolog -mode batch -source .\nexysa7.tcl"; \
	mkdir -p $$cwd/build/nexysa7; \
	cp -f $$tmp_dir/build/vivado/cpu16.runs/impl_1/*.bin $$cwd/build/; \
	echo "Build complete. Output files copied to build/"

prog: ${BUILDDIR}/${TOP}.bit
	${PROG_CMD} ${BUILDDIR}/${TOP}.bit

clean:
	rm -rf ${BUILDDIR}
