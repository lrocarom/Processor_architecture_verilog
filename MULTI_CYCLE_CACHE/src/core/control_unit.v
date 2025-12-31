module control_module(
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        alu_operation,
    output reg [3:0]  alu_operation_type,
    output reg        write_register,
    output reg        load_word_memory,
    output reg        store_word_memory,
    output reg        branch,
    output reg [3:0]  branch_operation_type,
    output reg        jump,
    output reg        panic
);

    always @(*) begin
        // Default values
        alu_operation       = 0;
        alu_operation_type  = 4'b0000;
        write_register      = 0;
        load_word_memory    = 0;
        store_word_memory   = 0;
        branch              = 0;
        branch_operation_type = 4'b0000;
        jump                = 0;
        panic               = 0;

        case(opcode)
            7'b0110011: begin // R-type ALU
                alu_operation      = 1;
                write_register     = 1;
                case({funct7, funct3})
                    10'b0000000000: alu_operation_type = 4'b0001; // ADD
                    10'b0100000000: alu_operation_type = 4'b0010; // SUB
                    10'b0000000111: alu_operation_type = 4'b0011; // AND
                    10'b0000000110: alu_operation_type = 4'b0100; // OR
                    // Agrega más según necesites
                    default: panic = 1;
                endcase
            end

            7'b0010011: begin // I-type ALU
                alu_operation      = 1;
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
            end

            7'b0100011: begin // STORE
                store_word_memory  = 1;
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

            default: begin
                panic = 1; // Opcode not valid
            end
        endcase
    end

endmodule
