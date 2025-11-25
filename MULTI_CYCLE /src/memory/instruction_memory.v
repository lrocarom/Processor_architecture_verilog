
module instruction_memory(input  [31:0]  program_counter,
                          output  [31:0]  instruction_out);
    

    reg [31:0] instr_mem [0:255];


    initial begin
        instr_mem[0] = 32'h003100B3;  // ADD x1, x2, x3
        instr_mem[1] = 32'h007303B3; // ADD x5, x6, x7
        instr_mem[2] = 32'h00C585B3; // ADD x10, x11, x12
        instr_mem[3] = 32'h00004430;
        instr_mem[4] = 32'h00008610;
        instr_mem[5] = 32'h00000431;
        instr_mem[6] = 32'h00008610;
        instr_mem[7] = 32'h00000422;
        instr_mem[8] = 32'h00000431;
        instr_mem[9] = 32'h00000431;

    end

    assign instruction_out = instr_mem[program_counter[9:2]];


endmodule
