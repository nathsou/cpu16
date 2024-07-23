# https://github.com/YosysHQ/oss-cad-suite-build
OSSCAD_PATH = ~/keep/oss-cad-suite
OSSCAD_BIN = $(OSSCAD_PATH)/bin

TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES = $(shell pwd)/../build/RegisterFile.sv
MODULE = test_register_file
TOPLEVEL = cpu16_RegisterFile

include $(shell cocotb-config --makefiles)/Makefile.sim
