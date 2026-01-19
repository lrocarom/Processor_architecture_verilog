`timescale 1ns/1ps

module mem_copy_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer cycle;
    integer start_cycle;
    integer end_cycle;
    reg     saw_last_store;
    integer a_mismatch;
    integer b_mismatch;
    integer first_bad_a;
    integer first_bad_b;

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
            saw_last_store <= 1'b0;
        end else begin
            cycle <= cycle + 1;
            if (start_cycle == -1 && uut.program_counter == 32'h00001014) begin
                start_cycle <= cycle;
            end
            if (!saw_last_store && uut.mem_stage_inst.mem_write_en &&
                (uut.mem_stage_inst.mem_addr == 32'h000004FC)) begin
                end_cycle <= cycle;
                saw_last_store <= 1'b1;
            end
        end
    end

    initial begin
        a_mismatch = 0;
        b_mismatch = 0;
        first_bad_a = -1;
        first_bad_b = -1;

        // Initialize entire data memory to 0 to avoid X propagation
        for (i = 0; i < 4096; i = i + 1) begin
            uut.mem_stage_inst.data_mem.data_mem[i] = 32'h00000000;
        end

        // Program @ 0x1000
        // x7 = 0x100 (ptr_a)
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h10000393;
        // x9 = 0x300 (ptr_b)
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h30000493;
        // x3 = 0 (i)
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h00000193;
        // x4 = 128 (limit)
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h08000213;
        // x5 = 5 (value)
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h00500293;
        // loop1:
        // NOPs to allow x7 to write back before next store
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'h00000013;
        // SW x5, 0(x7)  ; a[i] = 5
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h0053A023;
        // x7 = x7 + 4
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h00438393;
        // x3 = x3 + 1
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h00118193;
        // BLT x3, x4, loop1 (-0x10)
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'hFE41C6E3;
        // reset for loop2
        // x7 = 0x100 (ptr_a)
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'h10000393;
        // x9 = 0x300 (ptr_b)
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h30000493;
        // x3 = 0 (i)
        uut.fetch_stage.memory_ins.instr_mem[16'h040D] = 32'h00000193;
        // loop2:
        // NOPs to allow x7/x9 to write back before next load/store
        uut.fetch_stage.memory_ins.instr_mem[16'h040E] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h040F] = 32'h00000013;
        // LW x6, 0(x7)  ; x6 = a[i]
        uut.fetch_stage.memory_ins.instr_mem[16'h0410] = 32'h0003A303;
        // NOP to avoid load->store hazard on x6
        uut.fetch_stage.memory_ins.instr_mem[16'h0411] = 32'h00000013;
        // SW x6, 0(x9)  ; b[i] = x6
        uut.fetch_stage.memory_ins.instr_mem[16'h0412] = 32'h0064A023;
        // x7 = x7 + 4
        uut.fetch_stage.memory_ins.instr_mem[16'h0413] = 32'h00438393;
        // x9 = x9 + 4
        uut.fetch_stage.memory_ins.instr_mem[16'h0414] = 32'h00448493;
        // x3 = x3 + 1
        uut.fetch_stage.memory_ins.instr_mem[16'h0415] = 32'h00118193;
        // BLT x3, x4, loop2 (-0x20)
        uut.fetch_stage.memory_ins.instr_mem[16'h0416] = 32'hFE41C0E3;
        // JAL x0, 0
        uut.fetch_stage.memory_ins.instr_mem[16'h0417] = 32'h0000006F;

        // Release reset
        #20 reset = 0;

        // Let it run
        #300000;

        // Check results
        for (i = 0; i < 128; i = i + 1) begin
            if (uut.mem_stage_inst.data_mem.data_mem[16'h0040 + i] !== 32'h00000005) begin
                a_mismatch = a_mismatch + 1;
                if (first_bad_a == -1) first_bad_a = i;
            end
            if (uut.mem_stage_inst.data_mem.data_mem[16'h00C0 + i] !== 32'h00000005) begin
                b_mismatch = b_mismatch + 1;
                if (first_bad_b == -1) first_bad_b = i;
            end
        end

        $display("[MEM_COPY] a[0]=0x%08h b[0]=0x%08h a[127]=0x%08h b[127]=0x%08h",
                 uut.mem_stage_inst.data_mem.data_mem[16'h0040],
                 uut.mem_stage_inst.data_mem.data_mem[16'h00C0],
                 uut.mem_stage_inst.data_mem.data_mem[16'h00BF],
                 uut.mem_stage_inst.data_mem.data_mem[16'h013F]);
        if (start_cycle != -1 && end_cycle != -1) begin
            $display("[MEM_COPY] loop_cycles=%0d total_cycles=%0d",
                     (end_cycle - start_cycle + 1), cycle);
        end else begin
            $display("[MEM_COPY] loop_cycles=NA total_cycles=%0d", cycle);
        end

        if (!saw_last_store) begin
            $display("[MEM_COPY] WARN: store to 0x4FC not observed");
        end
        if (a_mismatch != 0 || b_mismatch != 0) begin
            $display("[MEM_COPY] WARN: a_mismatch=%0d b_mismatch=%0d first_bad_a=%0d first_bad_b=%0d",
                     a_mismatch, b_mismatch, first_bad_a, first_bad_b);
        end

        if ((a_mismatch == 0) && (b_mismatch == 0)) begin
            $display("[MEM_COPY] PASS");
        end else begin
            $display("[MEM_COPY] FAIL");
        end

        $finish;
    end
endmodule
