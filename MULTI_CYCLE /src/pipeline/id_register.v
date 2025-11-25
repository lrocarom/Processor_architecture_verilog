module id_register(
    input          clk,
    input          reset,
    input wire [31:0] in_data_register_a,
    input wire [31:0] in_data_register_b,
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
    output reg [31:0] out_data_register_a,
    output reg [31:0] out_data_register_b,
    output reg [31:0] out_data_register_d,
    output reg [4:0] out_reg_d,
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
            out_data_register_a       <= 32'b0;
            out_data_register_b       <= 32'b0;
            out_data_register_d       <= 32'b0;
            out_alu_operation_type    <= 4'b0;
            out_write_register        <= 1'b0;
            out_load_word_memory      <= 1'b0;
            out_store_word_memory     <= 1'b0;
            out_branch                <= 1'b0;
            out_branch_operation_type <= 4'b0;
            out_jump                  <= 1'b0;
            out_panic                 <= 1'b0;
        end else begin
            out_data_register_a       <= in_data_register_a;
            out_data_register_b       <= in_data_register_b;
            out_data_register_d       <= in_data_register_d;
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
