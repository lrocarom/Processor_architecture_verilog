`timescale 1ns/1ps

module mul_latency_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer cycle;
    integer mul_start_cycle;
    integer mul_busy_cycles;
    reg saw_mul_start;

    cpu uut(
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle <= 0;
            mul_start_cycle <= -1;
            mul_busy_cycles <= 0;
            saw_mul_start <= 1'b0;
        end else begin
            cycle <= cycle + 1;
            if (!saw_mul_start && (uut.ex_alu_type == 4'b0101) && !uut.mul_busy) begin
                mul_start_cycle <= cycle;
                saw_mul_start <= 1'b1;
            end
            if (uut.mul_busy)
                mul_busy_cycles <= mul_busy_cycles + 1;
        end
    end

    initial begin
        // Initialize instruction memory with NOPs
        for (i = 0; i < 4096; i = i + 1) begin
            uut.fetch_stage.memory_ins.instr_mem[i] = 32'h00000013;
        end

        // Program @ 0x1000
        // x1 = 3
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h00300093;
        // x2 = 4
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h00400113;
        // x3 = x1 * x2 (MUL)
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h022081B3;
        // x5 = 1 (executes after MUL completes)
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h00100293;
        // JAL x0, 0 (loop)
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h0000006F;

        // Release reset
        #20 reset = 0;

        // Let it run
        #2000;

        $display("[MUL_TB] x3=0x%08h mul_busy_cycles=%0d start_cycle=%0d",
                 uut.register_table.data_register[3], mul_busy_cycles, mul_start_cycle);

        if (uut.register_table.data_register[3] !== 32'h0000000C) begin
            $display("[MUL_TB] FAIL: bad mul result");
        end else if (mul_busy_cycles < 5) begin
            $display("[MUL_TB] FAIL: mul stall too short");
        end else begin
            $display("[MUL_TB] PASS");
        end

        $finish;
    end
endmodule
