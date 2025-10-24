# =========================================================
# Verilog CPU Project Makefile
# =========================================================

# Compiler and viewer
IVERILOG = /home/lrocarom/Documents/MASTER_HPC/Q1/PROCESSOR_ARCHITECTURE/PRACTIQUES/iverilog_v12_0/install/bin/iverilog
VVP = /home/lrocarom/Documents/MASTER_HPC/Q1/PROCESSOR_ARCHITECTURE/PRACTIQUES/iverilog_v12_0/install/bin/vvp
GTKWAVE = gtkwave

# Directories
SRC_DIR = src
TB_DIR = tb
BUILD_DIR = build

# Output files
TARGET = $(BUILD_DIR)/cpu_sim
WAVE = $(BUILD_DIR)/cpu_wave.vcd

# Source files
SRC = $(wildcard $(SRC_DIR)/*.v)
TB = $(wildcard $(TB_DIR)/*.v)

# =========================================================
# Default target
# =========================================================
all: run

# =========================================================
# Compile simulation
# =========================================================
$(TARGET): $(SRC) $(TB)
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(TARGET) $(SRC) $(TB)

# =========================================================
# Run simulation
# =========================================================
run: $(TARGET)
	$(VVP) $(TARGET)

# =========================================================
# View waveform
# =========================================================
wave: run
	$(GTKWAVE) $(WAVE) &

# =========================================================
# Clean build files
# =========================================================
clean:
	rm -rf $(BUILD_DIR)

.PHONY: all run wave clean
