
module control_module(  input [3:0] opcode ,
                        output wire alu_operation,
                        output reg [3:0] alu_operation_type,
                        output wire write_register,
                        output wire load_word_memory,
                        output wire store_word_memory,
                        output wire branch);

     
    assign store_word_memory = (opcode == 4'b0010);
    assign branch       = (opcode == 4'b0011);

    assign alu_operation = (opcode == 4'b0000);
    assign load_word_memory  = (opcode == 4'b0001);
    assign write_register  = (opcode == 4'b0000) || (opcode == 4'b0001);

    always @(*) begin
        alu_operation_type = 4'b0000;
        case(opcode)
            4'b0000: begin     //ADD
                alu_operation_type = 4'b0001;
                
                end
            4'b0000: begin     //SUB
                alu_operation_type = 4'b0010;
                
                end
            4'b0000: begin     //AND
                alu_operation_type = 4'b0011;
                
                end
            4'b0000: begin     //OR
                alu_operation_type = 4'b0100;
                
                end
        endcase
    end
    
endmodule