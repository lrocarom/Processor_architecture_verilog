
module instruction_memory(input  [31:0]  program_counter,
                          output  [31:0]  instruction_out);
    

    reg [31:0] instr_mem [0:255];


    initial begin
        instr_mem[0] = 32'h000044BB;
        //instr_mem[0] = 32'h00004416;
        instr_mem[1] = 32'h00000000;
        instr_mem[2] = 32'h00000000;
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

// 0000000000000 00001 00010 00011 0000

// 0000000000000 00000 00110 01011 0001

// 0000000000000 00000 00010 00011 0001
// 0000000000000 00000 00010 00011 0001

 //0000000000011 00001 00001 00001 0011

// 00000000000000000000010000100010