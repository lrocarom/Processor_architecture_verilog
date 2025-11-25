module alu_stage(
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] alu_op1,
    input  wire [31:0] alu_op2,
    input  wire [3:0]  alu_operation,

    input wire is_write_in,
    input wire is_store_in,
    input wire is_load_in,
    input wire is_branch,
    
    output wire [31:0] alu_result

);


alu_module alu(
    .reg_a      ( alu_op1 ),
    .reg_b      ( alu_op2 ),
    .alu_ctrl   ( alu_operation ),
    .result_value ( alu_result )
    );



endmodule