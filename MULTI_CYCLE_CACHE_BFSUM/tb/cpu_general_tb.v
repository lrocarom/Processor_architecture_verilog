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
    integer icache_stall_cycles;
    integer dcache_stall_cycles;
    integer branch_total;
    integer branch_taken;
    integer branch_not_taken;
    integer first_store_cycle;
    integer last_store_cycle;
    reg [31:0] last_branch_pc;
    reg vm_enabled;
    reg saw_itlb_miss;
    reg saw_tlbwrite;
    reg saw_iret;
    reg saw_vm_enable;
    reg saw_vm_user;
    reg sb_hit_x16;
    reg sb_hit_x17;
    reg saw_load_x16;
    reg saw_load_x17;

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
            icache_stall_cycles <= 0;
            dcache_stall_cycles <= 0;
            branch_total <= 0;
            branch_taken <= 0;
            branch_not_taken <= 0;
            first_store_cycle <= -1;
            last_store_cycle <= -1;
            last_branch_pc <= 32'hFFFFFFFF;
            vm_enabled <= 1'b0;
            saw_itlb_miss <= 1'b0;
            saw_tlbwrite <= 1'b0;
            saw_iret <= 1'b0;
            saw_vm_enable <= 1'b0;
            saw_vm_user <= 1'b0;
            sb_hit_x16 <= 1'b0;
            sb_hit_x17 <= 1'b0;
            saw_load_x16 <= 1'b0;
            saw_load_x17 <= 1'b0;
        end else begin
            cycle <= cycle + 1;
            total_cycles <= total_cycles + 1;
            if (uut.if_stall_req) if_stall_cycles <= if_stall_cycles + 1;
            if (uut.mem_stall_req) mem_stall_cycles <= mem_stall_cycles + 1;
            if (uut.hazard_stall_req) hazard_stall_cycles <= hazard_stall_cycles + 1;
            if (uut.fetch_stage.icache_stall) icache_stall_cycles <= icache_stall_cycles + 1;
            if (uut.mem_stage_inst.cache_stall) dcache_stall_cycles <= dcache_stall_cycles + 1;
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
            // Capture store-to-load forwarding when the load is in MEM stage
            if (uut.mem_stage_inst.is_load_in && (uut.mem_stage_inst.rd_in == 5'd16) && !saw_load_x16) begin
                sb_hit_x16 <= uut.mem_stage_inst.sb_lookup_hit;
                saw_load_x16 <= 1'b1;
                $display("[CPU_TB][C%0d] LD x16 addr=0x%08h off=%0d sz=%0d uns=%0d sb_hit=%0d sb_be=0x%0h sb_data=0x%08h cache=0x%08h ld=0x%08h",
                         cycle,
                         uut.mem_stage_inst.alu_result_in,
                         uut.mem_stage_inst.alu_result_in[1:0],
                         uut.mem_stage_inst.mem_size_in,
                         uut.mem_stage_inst.load_unsigned_in,
                         uut.mem_stage_inst.sb_lookup_hit,
                         uut.mem_stage_inst.sb_lookup_be,
                         uut.mem_stage_inst.sb_lookup_data,
                         uut.mem_stage_inst.cache_rdata,
                         uut.mem_stage_inst.load_data);
            end
            if (uut.mem_stage_inst.is_load_in && (uut.mem_stage_inst.rd_in == 5'd17) && !saw_load_x17) begin
                sb_hit_x17 <= uut.mem_stage_inst.sb_lookup_hit;
                saw_load_x17 <= 1'b1;
                $display("[CPU_TB][C%0d] LD x17 addr=0x%08h off=%0d sz=%0d uns=%0d sb_hit=%0d sb_be=0x%0h sb_data=0x%08h cache=0x%08h ld=0x%08h",
                         cycle,
                         uut.mem_stage_inst.alu_result_in,
                         uut.mem_stage_inst.alu_result_in[1:0],
                         uut.mem_stage_inst.mem_size_in,
                         uut.mem_stage_inst.load_unsigned_in,
                         uut.mem_stage_inst.sb_lookup_hit,
                         uut.mem_stage_inst.sb_lookup_be,
                         uut.mem_stage_inst.sb_lookup_data,
                         uut.mem_stage_inst.cache_rdata,
                         uut.mem_stage_inst.load_data);
            end
            if (!vm_enabled && (uut.program_counter == 32'h000010A4)) begin
                uut.rm4[0] <= 1'b0; // enter user mode to enable VM
                vm_enabled <= 1'b1;
                $display("[CPU_TB][C%0d] VM enabled (rm4[0]=0)", cycle);
            end
            if (uut.vm_enable) saw_vm_enable <= 1'b1;
            if (uut.if_tlb_miss) saw_itlb_miss <= 1'b1;
            if (uut.mem_stage_inst.tlbwrite_in) saw_tlbwrite <= 1'b1;
            if (uut.mem_stage_inst.iret_taken) saw_iret <= 1'b1;
            if (uut.register_table.data_register[20] == 32'h00000123) saw_vm_user <= 1'b1;
            if (uut.ex_branch && (uut.ex_pc != last_branch_pc)) begin
                last_branch_pc <= uut.ex_pc;
                branch_total <= branch_total + 1;
                if (uut.branch_taken) branch_taken <= branch_taken + 1;
                else branch_not_taken <= branch_not_taken + 1;
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
        // Covers: ALU, MUL, byte/word LD/ST, SB bypass, JAL/JALR, branches
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
        // x14 = 0x66
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'h06600713;
        // SB x14, 0x105(x0)      ; first store
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h10E002A3;
        // SB x15, 0x105(x0)      ; second store (newest)
        uut.fetch_stage.memory_ins.instr_mem[16'h040D] = 32'h10F002A3;
        // LBU x16, 0x105(x0)     ; should forward newest store
        uut.fetch_stage.memory_ins.instr_mem[16'h040E] = 32'h10504803;
        // LBU x17, 0x105(x0)     ; after drain, should still read 0x77
        uut.fetch_stage.memory_ins.instr_mem[16'h040F] = 32'h10504883;
        // JAL x0, +8 (skip next)
        uut.fetch_stage.memory_ins.instr_mem[16'h0410] = 32'h0080006F;
        // x8 = 0x11 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h0411] = 32'h01100413;
        // x8 = 0x22 (executed)
        uut.fetch_stage.memory_ins.instr_mem[16'h0412] = 32'h02200413;
        // x9 = 0x10
        uut.fetch_stage.memory_ins.instr_mem[16'h0413] = 32'h01000493;
        // JALR x0, 0x10(x0) -> jump to 0x10 (no RAW hazard)
        uut.fetch_stage.memory_ins.instr_mem[16'h0414] = 32'h01000067;
        // x10 = 0x33 (executes after JALR returns)
        uut.fetch_stage.memory_ins.instr_mem[16'h0415] = 32'h03300513;
        // -----------------------------
        // Branch block @ PA 0x1050
        // -----------------------------
        // x18 = 5
        uut.fetch_stage.memory_ins.instr_mem[16'h0416] = 32'h00500913;
        // x19 = 5
        uut.fetch_stage.memory_ins.instr_mem[16'h0417] = 32'h00500993;
        // x21 = 7
        uut.fetch_stage.memory_ins.instr_mem[16'h0418] = 32'h00700A93;
        // x22 = 9
        uut.fetch_stage.memory_ins.instr_mem[16'h0419] = 32'h00900B13;
        // BEQ x18, x19, +8 (skip next)
        uut.fetch_stage.memory_ins.instr_mem[16'h041A] = 32'h01390463;
        // x23 = 0x11 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h041B] = 32'h01100B93;
        // x23 = 0x22 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h041C] = 32'h02200B93;
        // BNE x18, x19, +8 (not taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h041D] = 32'h01391463;
        // x24 = 0x33 (executes)
        uut.fetch_stage.memory_ins.instr_mem[16'h041E] = 32'h03300C13;
        // BNE x18, x21, +8 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h041F] = 32'h01591463;
        // x24 = 0x44 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h0420] = 32'h04400C13;
        // x24 = 0x55 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h0421] = 32'h05500C13;
        // BLT x18, x22, +8 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h0422] = 32'h01694463;
        // x25 = 0x66 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h0423] = 32'h06600C93;
        // x25 = 0x77 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h0424] = 32'h07700C93;
        // BGE x22, x18, +8 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h0425] = 32'h012B5463;
        // x26 = 0x88 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h0426] = 32'h08800D13;
        // x26 = 0x99 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h0427] = 32'h09900D13;
        // JAL x0, +8 (jump to VM start @ 0x10A0)
        uut.fetch_stage.memory_ins.instr_mem[16'h0428] = 32'h0080006F;
        // NOP
        uut.fetch_stage.memory_ins.instr_mem[16'h0429] = 32'h00000013;
        // VM start: JAL x0, 0x2000 (iTLB miss when VM enabled)
        uut.fetch_stage.memory_ins.instr_mem[16'h042A] = 32'h7590006F;

        // Target @ PA 0x10 (for JALR)
        // x11 = 0x44
        uut.fetch_stage.memory_ins.instr_mem[16'h0004] = 32'h04400593;
        // JAL x0, +0x1044 (return to 0x1058)
        uut.fetch_stage.memory_ins.instr_mem[16'h0005] = 32'h0440106F;

        // -----------------------------
        // Exception handler @ PA 0x2000
        // -----------------------------
        // MOVRM x13, rm1        ; x13 = fault VA
        uut.fetch_stage.memory_ins.instr_mem[16'h0800] = 32'h0000868B;
        // MOVRM x14, rm2        ; x14 = fault VA + 0x1000 (precomputed in HW)
        uut.fetch_stage.memory_ins.instr_mem[16'h0801] = 32'h0001070B;
        // TLBWRITE x13, x14     ; map VA -> PA+0x1000 (iTLB + dTLB)
        uut.fetch_stage.memory_ins.instr_mem[16'h0802] = 32'h00E6900B;
        // IRET                  ; return to faulting PC
        uut.fetch_stage.memory_ins.instr_mem[16'h0803] = 32'h0000200B;

        // -----------------------------
        // VM user code @ PA 0x3000 (VA 0x2000 -> PA 0x3000)
        // -----------------------------
        // x20 = 0x123
        uut.fetch_stage.memory_ins.instr_mem[16'h0C00] = 32'h12300A13;
        // x21 = x20 + 1
        uut.fetch_stage.memory_ins.instr_mem[16'h0C01] = 32'h001A0A93;
        // JAL x0, 0 (loop)
        uut.fetch_stage.memory_ins.instr_mem[16'h0C02] = 32'h0000006F;

        // Data memory initialization
        uut.mem_stage_inst.data_mem.data_mem[16'h0040] = 32'h00000000; // 0x100
        uut.mem_stage_inst.data_mem.data_mem[16'h0041] = 32'hAABBCCDD; // 0x104

        // Release reset
        #20 reset = 0;
        // Preload iTLB/dTLB entry for VA 0x1000 -> PA 0x1000 (so VM can enable)
        #1;
        uut.fetch_stage.itlb.tag_array[1] = 18'b0;
        uut.fetch_stage.itlb.ppn_array[1] = 8'h01;
        uut.fetch_stage.itlb.valid_array[1] = 1'b1;
        uut.mem_stage_inst.dtlb.tag_array[1] = 18'b0;
        uut.mem_stage_inst.dtlb.ppn_array[1] = 8'h01;
        uut.mem_stage_inst.dtlb.valid_array[1] = 1'b1;

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
        $display("[CPU_TB] x18 = 0x%08h", uut.register_table.data_register[18]);
        $display("[CPU_TB] x19 = 0x%08h", uut.register_table.data_register[19]);
        $display("[CPU_TB] x20 = 0x%08h", uut.register_table.data_register[20]);
        $display("[CPU_TB] x21 = 0x%08h", uut.register_table.data_register[21]);
        $display("[CPU_TB] x22 = 0x%08h", uut.register_table.data_register[22]);
        $display("[CPU_TB] x23 = 0x%08h", uut.register_table.data_register[23]);
        $display("[CPU_TB] x24 = 0x%08h", uut.register_table.data_register[24]);
        $display("[CPU_TB] x25 = 0x%08h", uut.register_table.data_register[25]);
        $display("[CPU_TB] x26 = 0x%08h", uut.register_table.data_register[26]);
        $display("[CPU_TB] mem[0x0100] = 0x%08h", uut.mem_stage_inst.data_mem.data_mem[16'h0040]);
        $display("[CPU_TB] mem[0x0104] = 0x%08h", uut.mem_stage_inst.data_mem.data_mem[16'h0041]);
        $display("[CPU_TB] x15 = 0x%08h", uut.register_table.data_register[15]);
        $display("[CPU_TB] x16 = 0x%08h", uut.register_table.data_register[16]);
        $display("[CPU_TB] x17 = 0x%08h", uut.register_table.data_register[17]);
        $display("[CPU_TB] SB fwd: x16_hit=%0d x17_hit=%0d",
                 sb_hit_x16, sb_hit_x17);
        $display("[CPU_TB] VM flags: vm_en=%0d itlb_miss=%0d tlbwrite=%0d iret=%0d vm_user=%0d",
                 saw_vm_enable, saw_itlb_miss, saw_tlbwrite, saw_iret, saw_vm_user);

        $display("[CPU_TB] cycles=%0d", total_cycles);
        $display("[CPU_TB] wb_writes=%0d store_commits=%0d", wb_writes, store_commits);
        $display("[CPU_TB] stalls: if=%0d mem=%0d hazard=%0d",
                 if_stall_cycles, mem_stall_cycles, hazard_stall_cycles);
        $display("[CPU_TB] cache_stalls: icache=%0d dcache=%0d",
                 icache_stall_cycles, dcache_stall_cycles);
        $display("[CPU_TB] branches: total=%0d taken=%0d not_taken=%0d",
                 branch_total, branch_taken, branch_not_taken);
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
            uut.register_table.data_register[23] !== 32'h00000022 ||
            uut.register_table.data_register[24] !== 32'h00000055 ||
            uut.register_table.data_register[25] !== 32'h00000077 ||
            uut.register_table.data_register[26] !== 32'h00000099 ||
            uut.register_table.data_register[20] !== 32'h00000123 ||
            uut.register_table.data_register[21] !== 32'h00000124 ||
            !sb_hit_x16 ||
            !saw_vm_enable || !saw_itlb_miss || !saw_tlbwrite || !saw_iret || !saw_vm_user ||
            uut.mem_stage_inst.data_mem.data_mem[16'h0040] !== 32'h00000011 ||
            uut.mem_stage_inst.data_mem.data_mem[16'h0041] !== 32'hAABB7780) begin
            $display("[CPU_TB] FAIL");
        end else begin
            $display("[CPU_TB] PASS");
        end

        $finish;
    end

endmodule
