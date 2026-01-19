module control_module(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        alu_operation,
    output reg [3:0]  alu_operation_type,
    output reg        alu_use_imm,
    output reg        write_register,
    output reg        load_word_memory,
    output reg        store_word_memory,
    output reg [1:0]  mem_size,       // 2'b00=byte, 2'b10=word
    output reg        load_unsigned,  // 1 = zero-extend (LBU)
    output reg        branch,
    output reg [3:0]  branch_operation_type,
    output reg        jump,
    output reg        panic,
    output reg        mov_rm,
    output reg        tlbwrite,
    output reg        iret
);

    always @(*) begin
        // Default values
        alu_operation       = 0;
        alu_operation_type  = 4'b0000;
        alu_use_imm         = 0;
        write_register      = 0;
        load_word_memory    = 0;
        store_word_memory   = 0;
        mem_size            = 2'b10;
        load_unsigned       = 0;
        branch              = 0;
        branch_operation_type = 4'b0000;
        jump                = 0;
        panic               = 0;
        mov_rm              = 0;
        tlbwrite            = 0;
        iret                = 0;

        case(opcode)
            7'b0110011: begin // R-type ALU
                alu_operation      = 1;
                write_register     = 1;
                case({funct7, funct3})
                    10'b0000000000: alu_operation_type = 4'b0001; // ADD
                    10'b0100000000: alu_operation_type = 4'b0010; // SUB
                    10'b0000000111: alu_operation_type = 4'b0011; // AND
                    10'b0000000110: alu_operation_type = 4'b0100; // OR
                    10'b0000001000: alu_operation_type = 4'b0101; // MUL
                    // Agrega más según necesites
                    default: panic = 1;
                endcase
            end

            7'b0010011: begin // I-type ALU
                alu_operation      = 1;
                alu_use_imm        = 1;
                write_register     = 1;
                case(funct3)
                    3'b000: alu_operation_type = 4'b0001; // ADDI
                    3'b111: alu_operation_type = 4'b0011; // ANDI
                    3'b110: alu_operation_type = 4'b0100; // ORI
                    default: panic = 1;
                endcase
            end

            7'b0000011: begin // LOAD
                load_word_memory   = 1;
                write_register     = 1;
                case (funct3)
                    3'b010: begin // LW
                        mem_size      = 2'b10;
                        load_unsigned = 1'b0;
                    end
                    3'b000: begin // LB
                        mem_size      = 2'b00;
                        load_unsigned = 1'b0;
                    end
                    3'b100: begin // LBU
                        mem_size      = 2'b00;
                        load_unsigned = 1'b1;
                    end
                    default: begin
                        panic = 1;
                    end
                endcase
            end

            7'b0100011: begin // STORE
                store_word_memory  = 1;
                case (funct3)
                    3'b010: begin // SW
                        mem_size = 2'b10;
                    end
                    3'b000: begin // SB
                        mem_size = 2'b00;
                    end
                    default: begin
                        panic = 1;
                    end
                endcase
            end

            7'b1100011: begin // BRANCH
                branch = 1;
                case(funct3)
                    3'b000: branch_operation_type = 4'b0001; // BEQ
                    3'b001: branch_operation_type = 4'b0010; // BNE
                    3'b100: branch_operation_type = 4'b0011; // BLT
                    3'b101: branch_operation_type = 4'b0100; // BGE
                    default: panic = 1;
                endcase
            end

            7'b1101111: begin // JAL
                jump = 1;
                write_register = 1; 
            end

            7'b1100111: begin // JALR
                jump = 1;
                write_register = 1;
            end

            7'b0110111, 7'b0010111: begin // LUI / AUIPC
                write_register = 1;
            end

            // Custom-0 opcode for VM support
            7'b0001011: begin
                case (funct3)
                    3'b000: begin // MOVRM: move rmX -> rd (rm index in rs1 field)
                        write_register = 1;
                        mov_rm = 1;
                    end
                    3'b001: begin // TLBWRITE: rs1=VA, rs2=PA (privileged)
                        tlbwrite = 1;
                        alu_operation_type = 4'b1111; // PASS_A
                    end
                    3'b010: begin // IRET: return from exception (privileged)
                        iret = 1;
                    end
                    default: begin
                        panic = 1;
                    end
                endcase
            end

            default: begin
                panic = 1; // Opcode not valid
            end
        endcase
    end

endmodule
