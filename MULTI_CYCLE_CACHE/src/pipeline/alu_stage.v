module alu_stage(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] alu_op1,
    input  wire [31:0] alu_op2,
    input  wire [3:0]  alu_operation, // The operation coming from Decoder
    input  wire        is_write_in,
    input  wire        is_store_in,
    input  wire        is_load_in,
    input  wire        is_branch,
    input  wire [31:0] imm_i_type,
    input  wire [31:0] imm_s_type,    // You will need this for STORES (S-Type)
    output wire [31:0] alu_result
);

    localparam CMD_ADD = 4'b0001; 


    // --- 2. Handle the ALU Input B (The Value) ---
    wire [31:0] alu_src_b;
    

    assign alu_src_b = (is_load_in)  ? imm_i_type :
                       (is_store_in) ? imm_s_type : 
                       alu_op2;


    wire [3:0] effective_alu_op;

    assign effective_alu_op = (is_load_in || is_store_in) ? CMD_ADD : alu_operation;


    alu_module alu(
        .reg_a        ( alu_op1 ),
        .reg_b        ( alu_src_b ),
        .alu_ctrl     ( effective_alu_op ), // Use the forced op
        .result_value ( alu_result )
    );

endmodule