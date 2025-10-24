module decode_instruction(
    input  wire [31:0] instruction,
    output wire [3:0]  opcode,
    output wire [4:0]  reg_a,
    output wire [4:0]  reg_b,
    output wire [4:0]  reg_d,
    output wire [12:0] offset
);

assign opcode = instruction[3:0];
assign reg_d  = instruction[8:4];
assign reg_b  = instruction[13:9];
assign reg_a  = instruction[18:14];
assign offset = instruction[31:19];

endmodule
