

module branch_comparision (input wire [3:0]  branch_operation,
                           input wire [31:0] data_register_a,
                           input wire [31:0] data_register_b,
                           output reg branch);

    always @(*) begin
        case (branch_operation)
            4'b0001 : branch =  (data_register_a == data_register_b); // BEQ
            4'b0010 : branch =  (data_register_a != data_register_b); // BNE
            4'b0011 : branch =  ($signed(data_register_a) <  $signed(data_register_b)); // BLT
            4'b0100 : branch =  ($signed(data_register_a) >= $signed(data_register_b)); // BGE
            default: branch = 1'b0;
        endcase
    end
    
    
endmodule