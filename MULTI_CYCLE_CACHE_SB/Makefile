# =========================================================
# Verilog CPU Project Makefile
# =========================================================

# Compiler and viewer
IVERILOG = /opt/homebrew/bin/iverilog
VVP = /opt/homebrew/bin/vvp
GTKWAVE = gtkwave

# Directories
SRC_DIR = src
TB_DIR = tb
BUILD_DIR = build

# Output files
TARGET = $(BUILD_DIR)/cpu_sim
WAVE = $(BUILD_DIR)/cpu_wave.vcd
VM_TARGET = $(BUILD_DIR)/vm_tb_sim
GENERAL_TARGET = $(BUILD_DIR)/cpu_general_tb_sim
SB_TARGET = $(BUILD_DIR)/sb_tb_sim

# Source files
SRC = $(shell find $(SRC_DIR) -type f -name "*.v")
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
# VM test (only vm_tb.v)
# =========================================================
vm: $(SRC) $(TB_DIR)/vm_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(VM_TARGET) $(SRC) $(TB_DIR)/vm_tb.v
	$(VVP) $(VM_TARGET)

# =========================================================
# General CPU test (cpu_general_tb.v)
# =========================================================
general: $(SRC) $(TB_DIR)/cpu_general_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(GENERAL_TARGET) $(SRC) $(TB_DIR)/cpu_general_tb.v
	$(VVP) $(GENERAL_TARGET)

# =========================================================
# Store buffer test
# =========================================================
sb: $(SRC) $(TB_DIR)/sb_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(SB_TARGET) $(SRC) $(TB_DIR)/sb_tb.v
	$(VVP) $(SB_TARGET)

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

.PHONY: all run wave vm general sb clean
