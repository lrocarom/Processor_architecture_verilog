


module alu_module  (input wire [ 31 : 0 ] reg_a,
             input wire [ 31 : 0 ] reg_b,
             input wire [ 3 : 0 ] alu_ctrl,
             output reg [ 31 : 0 ] result_value );

    always @(*) begin
        case (alu_ctrl)
            4'b0001 : result_value = reg_a + reg_b; //ADD
            4'b0010 : result_value = reg_a - reg_b; //SUB
            4'b0011 : result_value = reg_a & reg_b; //AND
            4'b0100 : result_value = reg_a | reg_b; //OR
            4'b0101 : result_value = reg_a * reg_b; //MULT

            default: result_value = 0;
        endcase
    end
    
endmodule