`timescale 1ns/1ps

module cpu_general_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer cycle;
    integer total_cycles;
    integer wb_writes;
    integer store_commits;
    integer if_stall_cycles;
    integer mem_stall_cycles;
    integer hazard_stall_cycles;
    integer first_store_cycle;
    integer last_store_cycle;

    cpu uut(
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    // Cycle counter + basic performance metrics
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle <= 0;
            total_cycles <= 0;
            wb_writes <= 0;
            store_commits <= 0;
            if_stall_cycles <= 0;
            mem_stall_cycles <= 0;
            hazard_stall_cycles <= 0;
            first_store_cycle <= -1;
            last_store_cycle <= -1;
        end else begin
            cycle <= cycle + 1;
            total_cycles <= total_cycles + 1;
            if (uut.if_stall_req) if_stall_cycles <= if_stall_cycles + 1;
            if (uut.mem_stall_req) mem_stall_cycles <= mem_stall_cycles + 1;
            if (uut.hazard_stall_req) hazard_stall_cycles <= hazard_stall_cycles + 1;
            if (uut.wb_write_reg) wb_writes <= wb_writes + 1;
            if (uut.mem_stage_inst.mem_write_en) begin
                store_commits <= store_commits + 1;
                if (first_store_cycle == -1) first_store_cycle <= cycle;
                last_store_cycle <= cycle;
            end
            if (uut.mem_stage_inst.sb_enq_valid) begin
                $display("[CPU_TB][C%0d] SB_ENQ addr=0x%08h data=0x%08h be=0x%0h",
                         cycle, uut.mem_stage_inst.sb_enq_addr,
                         uut.mem_stage_inst.sb_enq_data,
                         uut.mem_stage_inst.sb_enq_byte_en);
            end
            if (uut.mem_stage_inst.sb.mem_valid) begin
                $display("[CPU_TB][C%0d] SB_DRAIN addr=0x%08h data=0x%08h be=0x%0h",
                         cycle, uut.mem_stage_inst.sb.mem_addr,
                         uut.mem_stage_inst.sb.mem_data,
                         uut.mem_stage_inst.sb.mem_byte_en);
            end
            if (uut.wb_write_reg && (uut.wb_register_d == 5'd16 || uut.wb_register_d == 5'd17)) begin
                $display("[CPU_TB][C%0d] WB x%0d = 0x%08h (sb_hit=%0d sb_be=0x%0h cache=0x%08h)",
                         cycle, uut.wb_register_d, uut.wb_data_out,
                         uut.mem_stage_inst.sb_lookup_hit,
                         uut.mem_stage_inst.sb_lookup_be,
                         uut.mem_stage_inst.cache_rdata);
            end
        end
    end

    initial begin
        // Initialize instruction memory with NOPs
        for (i = 0; i < 4096; i = i + 1) begin
            uut.fetch_stage.memory_ins.instr_mem[i] = 32'h00000013;
        end

        // -----------------------------
        // General CPU test program @ PA 0x1000
        // -----------------------------
        // x1 = 5
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h00500093;
        // x2 = x1 + 7 = 12 (forwarding)
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h00708113;
        // x3 = x1 + x2 = 17 (forwarding)
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h002081B3;
        // x12 = x1 * x2 = 60 (MUL)
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h02208633;
        // SW x3, 0x100(x0)
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h10302023;
        // LW x4, 0x100(x0)
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h10002203;
        // x5 = 0x80
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'h08000293;
        // SB x5, 0x104(x0)
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h10500223;
        // LB x6, 0x104(x0)
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h10400303;
        // LBU x7, 0x104(x0)
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h10404383;
        // x15 = 0x77
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'h07700793;
        // SB x15, 0x105(x0)      ; store hit -> enqueue in SB
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'h10F002A3;
        // LBU x16, 0x105(x0)     ; must bypass from SB -> 0x77
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h10504803;
        // LBU x17, 0x105(x0)     ; after drain, should still read 0x77
        uut.fetch_stage.memory_ins.instr_mem[16'h040D] = 32'h10504883;
        // JAL x0, +8 (skip next)
        uut.fetch_stage.memory_ins.instr_mem[16'h040E] = 32'h0080006F;
        // x8 = 0x11 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h040F] = 32'h01100413;
        // x8 = 0x22 (executed)
        uut.fetch_stage.memory_ins.instr_mem[16'h0410] = 32'h02200413;
        // x9 = 0x10
        uut.fetch_stage.memory_ins.instr_mem[16'h0411] = 32'h01000493;
        // JALR x0, 0(x9) -> jump to 0x10
        uut.fetch_stage.memory_ins.instr_mem[16'h0412] = 32'h00048067;
        // x10 = 0x33 (executes after JALR returns)
        uut.fetch_stage.memory_ins.instr_mem[16'h0413] = 32'h03300513;
        // JAL x0, 0 (loop)
        uut.fetch_stage.memory_ins.instr_mem[16'h0414] = 32'h0000006F;

        // Target @ PA 0x10
        // x11 = 0x44
        uut.fetch_stage.memory_ins.instr_mem[16'h0004] = 32'h04400593;
        // JAL x0, +0x1024 (return to 0x1038)
        uut.fetch_stage.memory_ins.instr_mem[16'h0005] = 32'h0240106F;

        // Data memory initialization
        uut.mem_stage_inst.data_mem.data_mem[16'h0040] = 32'h00000000; // 0x100
        uut.mem_stage_inst.data_mem.data_mem[16'h0041] = 32'hAABBCCDD; // 0x104

        // Release reset
        #20 reset = 0;

        // Let it run
        #8000;

        $display("[CPU_TB] x1  = 0x%08h", uut.register_table.data_register[1]);
        $display("[CPU_TB] x2  = 0x%08h", uut.register_table.data_register[2]);
        $display("[CPU_TB] x3  = 0x%08h", uut.register_table.data_register[3]);
        $display("[CPU_TB] x4  = 0x%08h", uut.register_table.data_register[4]);
        $display("[CPU_TB] x5  = 0x%08h", uut.register_table.data_register[5]);
        $display("[CPU_TB] x6  = 0x%08h", uut.register_table.data_register[6]);
        $display("[CPU_TB] x7  = 0x%08h", uut.register_table.data_register[7]);
        $display("[CPU_TB] x8  = 0x%08h", uut.register_table.data_register[8]);
        $display("[CPU_TB] x9  = 0x%08h", uut.register_table.data_register[9]);
        $display("[CPU_TB] x10 = 0x%08h", uut.register_table.data_register[10]);
        $display("[CPU_TB] x11 = 0x%08h", uut.register_table.data_register[11]);
        $display("[CPU_TB] x12 = 0x%08h", uut.register_table.data_register[12]);
        $display("[CPU_TB] mem[0x0100] = 0x%08h", uut.mem_stage_inst.data_mem.data_mem[16'h0040]);
        $display("[CPU_TB] mem[0x0104] = 0x%08h", uut.mem_stage_inst.data_mem.data_mem[16'h0041]);
        $display("[CPU_TB] x15 = 0x%08h", uut.register_table.data_register[15]);
        $display("[CPU_TB] x16 = 0x%08h", uut.register_table.data_register[16]);
        $display("[CPU_TB] x17 = 0x%08h", uut.register_table.data_register[17]);

        $display("[CPU_TB] cycles=%0d", total_cycles);
        $display("[CPU_TB] wb_writes=%0d store_commits=%0d", wb_writes, store_commits);
        $display("[CPU_TB] stalls: if=%0d mem=%0d hazard=%0d",
                 if_stall_cycles, mem_stall_cycles, hazard_stall_cycles);
        $display("[CPU_TB] store_cycle_first=%0d store_cycle_last=%0d",
                 first_store_cycle, last_store_cycle);
        if (total_cycles > 0) begin
            $display("[CPU_TB] wb_ipc=%0f", wb_writes * 1.0 / total_cycles);
        end

        if (uut.register_table.data_register[1]  !== 32'h00000005 ||
            uut.register_table.data_register[2]  !== 32'h0000000C ||
            uut.register_table.data_register[3]  !== 32'h00000011 ||
            uut.register_table.data_register[4]  !== 32'h00000011 ||
            uut.register_table.data_register[5]  !== 32'h00000080 ||
            uut.register_table.data_register[6]  !== 32'hFFFFFF80 ||
            uut.register_table.data_register[7]  !== 32'h00000080 ||
            uut.register_table.data_register[8]  !== 32'h00000022 ||
            uut.register_table.data_register[9]  !== 32'h00000010 ||
            uut.register_table.data_register[10] !== 32'h00000033 ||
            uut.register_table.data_register[11] !== 32'h00000044 ||
            uut.register_table.data_register[12] !== 32'h0000003C ||
            uut.register_table.data_register[16] !== 32'h00000077 ||
            uut.register_table.data_register[17] !== 32'h00000077 ||
            uut.mem_stage_inst.data_mem.data_mem[16'h0040] !== 32'h00000011 ||
            uut.mem_stage_inst.data_mem.data_mem[16'h0041] !== 32'hAABB7780) begin
            $display("[CPU_TB] FAIL");
        end else begin
            $display("[CPU_TB] PASS");
        end

        $finish;
    end

endmodule
