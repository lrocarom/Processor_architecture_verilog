
module instruction_memory(input  [31:0]  program_counter,
                          output  [31:0]  instruction_out);
    

    reg [31:0] instr_mem [0:255];


    initial begin
        instr_mem[0] = 32'h00004430;
        instr_mem[1] = 32'h00008610;
        instr_mem[2] = 32'h00000431;
        instr_mem[3] = 32'h00008610;
    end

    assign instruction_out = instr_mem[program_counter[9:2]];


endmodule

// 0000000000000 00001 00010 00011 0000

// 0000000000000 00000 00110 01011 0001

// 0000000000000 00000 00010 00011 0001
// 0000000000000 00000 00010 00011 0001