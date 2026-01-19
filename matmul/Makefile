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
BRANCH_TARGET = $(BUILD_DIR)/branch_tb_sim
BUFFER_SUM_TARGET = $(BUILD_DIR)/buffer_sum_tb_sim
MEM_COPY_TARGET = $(BUILD_DIR)/mem_copy_tb_sim
MATMUL_TARGET = $(BUILD_DIR)/matmul_tb_sim
MATMUL_SMALL_TARGET = $(BUILD_DIR)/matmul_small_tb_sim
MATMUL_INCR_TARGET = $(BUILD_DIR)/matmul_incr_tb_sim
MUL_LAT_TARGET = $(BUILD_DIR)/mul_latency_tb_sim

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
# Branch test
# =========================================================
branch: $(SRC) $(TB_DIR)/branch_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(BRANCH_TARGET) $(SRC) $(TB_DIR)/branch_tb.v
	$(VVP) $(BRANCH_TARGET)

# =========================================================
# Buffer sum performance test
# =========================================================
buffer_sum: $(SRC) $(TB_DIR)/buffer_sum_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(BUFFER_SUM_TARGET) $(SRC) $(TB_DIR)/buffer_sum_tb.v
	$(VVP) $(BUFFER_SUM_TARGET)

# =========================================================
# Mem copy test
# =========================================================
mem_copy: $(SRC) $(TB_DIR)/mem_copy_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(MEM_COPY_TARGET) $(SRC) $(TB_DIR)/mem_copy_tb.v
	$(VVP) $(MEM_COPY_TARGET)

# =========================================================
# Matrix multiply test (no MUL)
# =========================================================
matmul: $(SRC) $(TB_DIR)/matmul_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(MATMUL_TARGET) $(SRC) $(TB_DIR)/matmul_tb.v
	$(VVP) $(MATMUL_TARGET)
## =========================================================
## Matrix multiply small test (trace-heavy)
## =========================================================
matmul_small: $(SRC) $(TB_DIR)/matmul_small_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(MATMUL_SMALL_TARGET) $(SRC) $(TB_DIR)/matmul_small_tb.v
	$(VVP) $(MATMUL_SMALL_TARGET)
## =========================================================
## Matrix multiply incremental tests
## =========================================================
matmul_incr1: $(SRC) $(TB_DIR)/matmul_incr_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(MATMUL_INCR_TARGET) -DSTAGE1 $(SRC) $(TB_DIR)/matmul_incr_tb.v
	$(VVP) $(MATMUL_INCR_TARGET)

matmul_incr2: $(SRC) $(TB_DIR)/matmul_incr_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(MATMUL_INCR_TARGET) -DSTAGE2 $(SRC) $(TB_DIR)/matmul_incr_tb.v
	$(VVP) $(MATMUL_INCR_TARGET)

matmul_incr3: $(SRC) $(TB_DIR)/matmul_incr_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(MATMUL_INCR_TARGET) -DSTAGE3 $(SRC) $(TB_DIR)/matmul_incr_tb.v
	$(VVP) $(MATMUL_INCR_TARGET)
# =========================================================
# MUL latency test
# =========================================================
mul_latency: $(SRC) $(TB_DIR)/mul_latency_tb.v
	@mkdir -p $(BUILD_DIR)
	$(IVERILOG) -o $(MUL_LAT_TARGET) $(SRC) $(TB_DIR)/mul_latency_tb.v
	$(VVP) $(MUL_LAT_TARGET)

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

.PHONY: all run wave vm general sb branch buffer_sum mem_copy matmul matmul_small matmul_incr1 matmul_incr2 matmul_incr3 mul_latency clean
