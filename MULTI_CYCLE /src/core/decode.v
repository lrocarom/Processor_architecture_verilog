module decode_instruction(
    input  wire [31:0] instruction,
    output wire [6:0]  opcode,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [4:0]  rd,
    output wire [2:0] funct3,
    output wire [6:0] funct7,
    output wire [31:0] imm_i_type,
    output wire [31:0] imm_s_type
);


assign opcode = instruction[6:0];
assign rd     = instruction[11:7];
assign funct3 = instruction[14:12];
assign rs1    = instruction[19:15];
assign rs2    = instruction[24:20];
assign funct7 = instruction[31:25];

assign imm_i_type = { {20{instruction[31]}}, instruction[31:20] };
assign imm_s_type = { {20{instruction[31]}}, instruction[31:25], instruction[11:7] };
endmodule
