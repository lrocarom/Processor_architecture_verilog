module decode_stage(
    input  clk,
    input  reset,
    input  wire [31:0] instruction,
    output wire [4:0]  reg_rs1,
    output wire [4:0]  reg_rs2,
    output wire [4:0]  reg_d,
    output wire [31:0] imm_i_type,
    output wire [31:0] imm_s_type,
    output wire [31:0] imm_b_type,
    output wire alu_operation,
    output wire [3:0] alu_operation_type,
    output wire alu_use_imm,
    output wire write_register,
    output wire load_word_memory,
    output wire store_word_memory,
    output wire [1:0] mem_size,
    output wire load_unsigned,
    output wire branch,
    output wire [3:0] branch_operation_type,
    output wire jump,
    output wire panic,
    output wire mov_rm,
    output wire tlbwrite,
    output wire iret

);

    
    wire [6:0]  opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    decode_instruction decoder( .instruction( instruction ),
                                .opcode( opcode ),
                                .rs1( reg_rs1 ),
                                .rs2( reg_rs2 ),
                                .rd( reg_d ),
                                .funct3( funct3 ),
                                .funct7( funct7 ),
                                .imm_i_type(imm_i_type),
                                .imm_s_type(imm_s_type),
                                .imm_b_type(imm_b_type));

    control_module control( .opcode( opcode ),
                        .funct3( funct3 ),      
                        .funct7( funct7 ),
                        .alu_operation( alu_operation ),
                        .alu_operation_type(alu_operation_type),
                        .alu_use_imm( alu_use_imm ),
                        .write_register(write_register),
                        .load_word_memory(load_word_memory),
                        .store_word_memory(store_word_memory),
                        .mem_size(mem_size),
                        .load_unsigned(load_unsigned),
                        .branch( branch ),
                        .branch_operation_type( branch_operation_type ),
                        .jump( jump ),
                        .panic( panic ),
                        .mov_rm( mov_rm ),
                        .tlbwrite( tlbwrite ),
                        .iret( iret )); 
                    
endmodule

