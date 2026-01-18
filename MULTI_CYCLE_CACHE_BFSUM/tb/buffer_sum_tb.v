`timescale 1ns/1ps

module buffer_sum_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer cycle;
    integer start_cycle;
    integer end_cycle;
    reg     saw_store;

    cpu uut(
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle <= 0;
            start_cycle <= -1;
            end_cycle <= -1;
            saw_store <= 1'b0;
        end else begin
            cycle <= cycle + 1;
            if ((cycle % 200) == 0) begin
                $display("[BUFFER_SUM][C%0d] PC=0x%08h i(x3)=0x%08h sum(x2)=0x%08h mul_busy=%0d",
                         cycle, uut.program_counter,
                         uut.register_table.data_register[3],
                         uut.register_table.data_register[2],
                         uut.mul_busy);
            end
            if (start_cycle == -1 && uut.program_counter == 32'h00001014) begin
                start_cycle <= cycle;
            end
            if (uut.ex_branch && (uut.ex_pc == 32'h00001028)) begin
                $display("[BUFFER_SUM][C%0d] BLT pc=0x%08h rs1(x3)=0x%08h rs2(x4)=0x%08h taken=%0d target=0x%08h",
                         cycle,
                         uut.ex_pc,
                         uut.alu_op1_real,
                         uut.alu_op2_real,
                         uut.branch_taken,
                         uut.branch_target);
            end
            if (!saw_store && uut.mem_stage_inst.mem_write_en &&
                (uut.mem_stage_inst.mem_addr == 32'h00000300)) begin
                end_cycle <= cycle;
                saw_store <= 1'b1;
            end
        end
    end

    initial begin
        // Initialize instruction memory with NOPs
        for (i = 0; i < 4096; i = i + 1) begin
            uut.fetch_stage.memory_ins.instr_mem[i] = 32'h00000013;
        end

        // Initialize data memory: a[i] = i (128 words at 0x100)
        for (i = 0; i < 128; i = i + 1) begin
            uut.mem_stage_inst.data_mem.data_mem[16'h0040 + i] = i[31:0];
        end
        // Clear sum output location at 0x300
        uut.mem_stage_inst.data_mem.data_mem[16'h00C0] = 32'h00000000;

        // Program @ 0x1000
        // x1 = 0x100 (base)
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h10000093;
        // x2 = 0 (sum)
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h00000113;
        // x3 = 0 (i)
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h00000193;
        // x4 = 128 (limit)
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h08000213;
        // x6 = 4 (stride)
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h00400313;
        // loop:
        // x5 = x3 * x6
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h026182B3;
        // x7 = x1 + x5
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'h005083B3;
        // x8 = mem[x7]
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h0003A403;
        // x2 = x2 + x8
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h00810133;
        // x3 = x3 + 1
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h00118193;
        // BLT x3, x4, loop (-0x14)
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'hFE41C6E3;
        // SW x2, 0x300(x0)
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'h30202023;
        // JAL x0, 0
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h0000006F;

        // Release reset
        #20 reset = 0;

        // Let it run (MUL has artificial latency)
        #20000;

        $display("[BUFFER_SUM] sum(x2)=0x%08h mem[0x0300]=0x%08h",
                 uut.register_table.data_register[2],
                 uut.mem_stage_inst.data_mem.data_mem[16'h00C0]);
        if (start_cycle != -1 && end_cycle != -1) begin
            $display("[BUFFER_SUM] loop_cycles=%0d total_cycles=%0d",
                     (end_cycle - start_cycle + 1), cycle);
        end else begin
            $display("[BUFFER_SUM] loop_cycles=NA total_cycles=%0d", cycle);
        end
        if (!saw_store) begin
            $display("[BUFFER_SUM] WARNING: store to 0x300 not observed");
        end

        if (uut.mem_stage_inst.data_mem.data_mem[16'h00C0] !== 32'd8128) begin
            $display("[BUFFER_SUM] FAIL");
        end else begin
            $display("[BUFFER_SUM] PASS");
        end

        $finish;
    end
endmodule
