module instruction_memory(
    input  [31:0] address,         // Renamed from program_counter
    output [31:0] instruction_out
);

    // 4096 words = 16KB (covers physical 0x0000..0x3FFF)
    reg [31:0] instr_mem [0:4095];
    integer base;

    // Read logic (Asynchronous / Zero Latency)
    // This matches the Cache's expectation to latch data immediately
    assign instruction_out = instr_mem[address[13:2]];
    integer i;
    
    initial begin
        // Initialize to NOPs (ADDI x0, x0, 0)
        
        for (i=0; i<4096; i=i+1) instr_mem[i] = 32'h00000013;

        // --- TEST PROGRAM ---
        // Program placed at physical 0x1000 (word index 0x400)
        base = 32'h00001000 >> 2;
        // 1. ADDI x1, x0, 10     (x1 = 10)
        instr_mem[base + 0] = 32'h00A00093; 
        
        // 2. SW   x1, 100(x0)    (Mem[100] = 10) -> Triggers STORE Stall
        instr_mem[base + 1] = 32'h06402223; 
        
        // 3. LW   x2, 100(x0)    (x2 = Mem[100]) -> Triggers LOAD HIT (should be fast)
        instr_mem[base + 2] = 32'h06402103;
        
        // 4. LW   x3, 104(x0)    (x3 = Mem[104]) -> Triggers LOAD MISS (Refill from Mem)
        instr_mem[base + 3] = 32'h06802183;
        
        // 5. ADD  x4, x2, x3     (x4 = 10 + ?)   -> Verify Forwarding/Result
        instr_mem[base + 4] = 32'h00310233;
        
        // 6. JAL  x0, 0          (Infinite Loop) -> Stops PC from running away
        instr_mem[base + 5] = 32'h0000006f; 
    end

endmodule