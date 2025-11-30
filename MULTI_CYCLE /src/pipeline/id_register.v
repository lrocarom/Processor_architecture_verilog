module id_register(
    input          clk,
    input          reset,
    input wire [31:0] in_data_register_rs1,
    input wire [31:0] in_data_register_rs2,
    input wire [31:0] in_data_register_d,
    input reg [4:0] in_reg_d,
    input wire [3:0] in_alu_operation_type,
    input wire in_write_register,
    input wire in_load_word_memory,
    input wire in_store_word_memory,
    input wire in_branch,
    input wire [3:0] in_branch_operation_type,
    input wire in_jump,
    input wire in_panic,
    output reg [31:0] out_data_register_rs1,
    output reg [31:0] out_data_register_rs2,
    output reg [4:0] out_reg_rd,
    output reg [3:0] out_alu_operation_type,
    output reg out_write_register,
    output reg out_load_word_memory,
    output reg out_store_word_memory,
    output reg out_branch,
    output reg [3:0] out_branch_operation_type,
    output reg out_jump,
    output reg out_panic
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            out_data_register_rs1       <= 32'b0;
            out_data_register_rs2       <= 32'b0;
            out_alu_operation_type    <= 4'b0;
            out_write_register        <= 1'b0;
            out_load_word_memory      <= 1'b0;
            out_store_word_memory     <= 1'b0;
            out_branch                <= 1'b0;
            out_branch_operation_type <= 4'b0;
            out_jump                  <= 1'b0;
            out_panic                 <= 1'b0;
        end else begin
            out_data_register_rs1       <= in_data_register_rs1;
            out_data_register_rs2       <= in_data_register_rs2;
            out_reg_rd               <= in_reg_d;
            out_alu_operation_type    <= in_alu_operation_type;
            out_write_register        <= in_write_register;
            out_load_word_memory      <= in_load_word_memory;
            out_store_word_memory     <= in_store_word_memory;
            out_branch                <= in_branch;
            out_branch_operation_type <= in_branch_operation_type;
            out_jump                  <= in_jump;
            out_panic                 <= in_panic;
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
