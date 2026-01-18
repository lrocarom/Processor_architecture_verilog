module id_register(
    input          clk,
    input          reset,
    input wire [31:0] in_data_register_rs1,
    input wire [31:0] in_data_register_rs2,
    input wire [31:0] in_data_register_d,
    input wire [4:0] in_reg_d,
    input wire [3:0] in_alu_operation_type,
    input wire       in_alu_use_imm,
    input wire in_write_register,
    input wire in_load_word_memory,
    input wire in_store_word_memory,
    input wire [1:0] in_mem_size,
    input wire       in_load_unsigned,
    input wire in_branch,
    input wire [3:0] in_branch_operation_type,
    input wire in_jump,
    input wire in_panic,
    input wire [4:0] in_reg_rs1,
    input wire [4:0] in_reg_rs2,
    input wire [31:0] in_imm_i_type,
    input wire [31:0] in_imm_s_type,
    input wire [31:0] in_pc,
    input wire        in_mov_rm,
    input wire        in_tlbwrite,
    input wire        in_iret,
    input wire [31:0] in_rm_value,
    input             in_stall_hold,
    input             in_stall_bubble,
    output reg [31:0] out_data_register_rs1,
    output reg [31:0] out_data_register_rs2,
    output reg [4:0] out_reg_rd,
    output reg [3:0] out_alu_operation_type,
    output reg       out_alu_use_imm,
    output reg out_write_register,
    output reg out_load_word_memory,
    output reg out_store_word_memory,
    output reg [1:0] out_mem_size,
    output reg       out_load_unsigned,
    output reg out_branch,
    output reg [3:0] out_branch_operation_type,
    output reg out_jump,
    output reg out_panic,
    output reg [4:0] out_reg_rs1,
    output reg [4:0] out_reg_rs2,
    output reg [31:0] out_imm_i_type,
    output reg [31:0] out_imm_s_type,
    output reg [31:0] out_pc,
    output reg        out_mov_rm,
    output reg        out_tlbwrite,
    output reg        out_iret,
    output reg [31:0] out_rm_value
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            out_data_register_rs1       <= 32'b0;
            out_data_register_rs2       <= 32'b0;
            out_imm_i_type       <= 32'b0;
            out_imm_s_type       <= 32'b0;
            out_alu_operation_type    <= 4'b0;
            out_alu_use_imm           <= 1'b0;
            out_write_register        <= 1'b0;
            out_load_word_memory      <= 1'b0;
            out_store_word_memory     <= 1'b0;
            out_mem_size              <= 2'b10;
            out_load_unsigned         <= 1'b0;
            out_branch                <= 1'b0;
            out_branch_operation_type <= 4'b0;
            out_jump                  <= 1'b0;
            out_panic                 <= 1'b0;
            out_pc                    <= 32'b0;
            out_reg_rd               <= 5'b0;
            out_reg_rs1              <= 5'b0;
            out_reg_rs2              <= 5'b0;
            out_mov_rm                <= 1'b0;
            out_tlbwrite              <= 1'b0;
            out_iret                  <= 1'b0;
            out_rm_value              <= 32'b0;
        end 
        else if (in_stall_bubble) begin
            // Insert bubble: clear control signals but keep operands/pc
            out_alu_operation_type    <= 4'b0;
            out_alu_use_imm           <= 1'b0;
            out_write_register        <= 1'b0;
            out_load_word_memory      <= 1'b0;
            out_store_word_memory     <= 1'b0;
            out_mem_size              <= 2'b10;
            out_load_unsigned         <= 1'b0;
            out_branch                <= 1'b0;
            out_branch_operation_type <= 4'b0;
            out_jump                  <= 1'b0;
            out_panic                 <= 1'b0;
            out_mov_rm                <= 1'b0;
            out_tlbwrite              <= 1'b0;
            out_iret                  <= 1'b0;
        end
        else if (in_stall_hold) begin
            // Hold stage during cache/if stall
            out_data_register_rs1       <= out_data_register_rs1;
            out_data_register_rs2       <= out_data_register_rs2;
            out_imm_i_type            <= out_imm_i_type;
            out_imm_s_type            <= out_imm_s_type;
            out_alu_operation_type    <= out_alu_operation_type;
            out_alu_use_imm           <= out_alu_use_imm;
            out_write_register        <= out_write_register;
            out_load_word_memory      <= out_load_word_memory;
            out_store_word_memory     <= out_store_word_memory;
            out_mem_size              <= out_mem_size;
            out_load_unsigned         <= out_load_unsigned;
            out_branch                <= out_branch;
            out_branch_operation_type <= out_branch_operation_type;
            out_jump                  <= out_jump;
            out_panic                 <= out_panic;
            out_reg_rd               <= out_reg_rd;
            out_reg_rs1               <= out_reg_rs1;
            out_reg_rs2               <= out_reg_rs2;
            out_pc                    <= out_pc;
            out_mov_rm                <= out_mov_rm;
            out_tlbwrite              <= out_tlbwrite;
            out_iret                  <= out_iret;
            out_rm_value              <= out_rm_value;
        end
        else begin
            out_data_register_rs1       <= in_data_register_rs1;
            out_data_register_rs2       <= in_data_register_rs2;
            out_imm_i_type       <= in_imm_i_type;
            out_imm_s_type       <= in_imm_s_type;
            out_reg_rd               <= in_reg_d;
            out_alu_operation_type    <= in_alu_operation_type;
            out_alu_use_imm           <= in_alu_use_imm;
            out_write_register        <= in_write_register;
            out_load_word_memory      <= in_load_word_memory;
            out_store_word_memory     <= in_store_word_memory;
            out_mem_size              <= in_mem_size;
            out_load_unsigned         <= in_load_unsigned;
            out_branch                <= in_branch;
            out_branch_operation_type <= in_branch_operation_type;
            out_jump                  <= in_jump;
            out_panic                 <= in_panic;
            out_reg_rs1                  <= in_reg_rs1;
            out_reg_rs2                 <= in_reg_rs2;
            out_pc                    <= in_pc;
            out_mov_rm                <= in_mov_rm;
            out_tlbwrite              <= in_tlbwrite;
            out_iret                  <= in_iret;
            out_rm_value              <= in_rm_value;
        end
    end


endmodule

// is_write
// is_store

// alu_ctrl

// rd -> VALUE

// data_register_a
// data_register_b

// register_d