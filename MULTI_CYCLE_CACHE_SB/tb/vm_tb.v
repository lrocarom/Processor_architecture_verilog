// --------------------------------------------------------------
// vm_tb.v
//
// VM testbench for iTLB + dTLB.
//
// How to run:
//   make vm
//
// Program layout (physical):
//   0x1000: supervisor boot (initial map, IRET)
//   0x2000: exception handler (maps VA -> PA+0x1000, IRET)
//   0x0000: user code (VA 0x00000000 -> PA 0x00000000)
//   0x3000: user code after iTLB miss (VA 0x00002000 -> PA 0x00003000)
//
// TLB mappings:
//   Boot: VA 0x00000000 -> PA 0x00000000 (code + data)
//   Handler: VA fault -> PA fault + 0x1000 (code + data)
//
// Expected behavior:
//   - Boot maps VA 0x0000, IRET to user
//   - User LW/SW at VA 0x0000/0x0004 (dTLB hit)
//   - User JAL to VA 0x2000 (iTLB miss -> handler maps -> resume)
//   - User2 LW/SW at VA 0x1800/0x1804 (dTLB miss -> handler maps -> resume)
// --------------------------------------------------------------
`timescale 1ns/1ps

module vm_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer cycle;
    reg saw_itlb_miss;
    reg saw_dtlb_miss;
    reg saw_store_base;
    reg saw_store_miss;
    reg saw_iret;
    reg saw_vm_enable;
    reg saw_tlbwrite;

    cpu uut(
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    // Simple cycle counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            cycle <= 0;
        else
            cycle <= cycle + 1;
    end

    initial begin
        // Initialize instruction memory with NOPs
        for (i = 0; i < 4096; i = i + 1) begin
            uut.fetch_stage.memory_ins.instr_mem[i] = 32'h00000013;
        end

        // -----------------------------
        // Supervisor boot @ PA 0x1000
        // -----------------------------
        // ADDI x1, x0, 0x0      ; x1 = 0x00000000 (VA for user code/data)
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h00000093;
        // ADDI x2, x0, 0x0      ; x2 = 0x00000000 (PA for user code/data)
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h00000113;
        // TLBWRITE x1, x2       ; map VA 0x0 -> PA 0x0
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h0020900B;
        // IRET                  ; enter user mode at VA 0x0 (rm0=0)
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h0000200B;

        // -----------------------------
        // Exception handler @ PA 0x2000
        // -----------------------------
        // MOVRM x1, rm1         ; x1 = fault VA
        uut.fetch_stage.memory_ins.instr_mem[16'h0800] = 32'h0000808B;
        // MOVRM x2, rm2         ; x2 = fault VA + 0x1000 (precomputed in HW)
        uut.fetch_stage.memory_ins.instr_mem[16'h0801] = 32'h0001010B;
        // TLBWRITE x1, x2       ; map VA -> PA+0x1000 (iTLB + dTLB)
        uut.fetch_stage.memory_ins.instr_mem[16'h0802] = 32'h0020900B;
        // IRET                  ; return to faulting PC
        uut.fetch_stage.memory_ins.instr_mem[16'h0803] = 32'h0000200B;

        // -----------------------------
        // User code @ PA 0x0000 (VA 0x0000)
        // -----------------------------
        // LW x5, 0(x0)          ; load from VA 0x0000 -> PA 0x0000
        uut.fetch_stage.memory_ins.instr_mem[16'h0000] = 32'h00002283;
        // SW x5, 4(x0)          ; store to VA 0x0004 -> PA 0x0004
        uut.fetch_stage.memory_ins.instr_mem[16'h0001] = 32'h00502223;
        // JAL x0, 0x2000        ; jump to VA 0x2000 (iTLB miss)
        uut.fetch_stage.memory_ins.instr_mem[16'h0002] = 32'h7F90106F;

        // -----------------------------
        // User code @ PA 0x3000 (VA 0x2000)
        // -----------------------------
        // MOVRM x7, rm1         ; x7 = fault VA (0x2000)
        uut.fetch_stage.memory_ins.instr_mem[16'h0C00] = 32'h0000838B;
        // LW x6, -0x800(x7)     ; load from VA 0x1800 (dTLB miss)
        uut.fetch_stage.memory_ins.instr_mem[16'h0C01] = 32'h8003A303;
        // SW x6, -0x7FC(x7)     ; store to VA 0x1804 (dTLB miss)
        uut.fetch_stage.memory_ins.instr_mem[16'h0C02] = 32'h8063A223;
        // JAL x0, 0             ; loop
        uut.fetch_stage.memory_ins.instr_mem[16'h0C03] = 32'h0000006F;

        // Data memory initialization
        uut.mem_stage_inst.data_mem.data_mem[16'h0000] = 32'hA5A5A5A5;
        uut.mem_stage_inst.data_mem.data_mem[16'h0001] = 32'h00000000;
        // PA 0x2800 -> index 0x0A00
        uut.mem_stage_inst.data_mem.data_mem[16'h0A00] = 32'hDEADBEEF;
        uut.mem_stage_inst.data_mem.data_mem[16'h0A01] = 32'h00000000;

        // Release reset
        #20 reset = 0;

        // Let it run
        #5000;

        $display("[VM_TB] data_mem[0x0000] = 0x%h", uut.mem_stage_inst.data_mem.data_mem[16'h0000]);
        $display("[VM_TB] data_mem[0x0004] = 0x%h", uut.mem_stage_inst.data_mem.data_mem[16'h0001]);
        $display("[VM_TB] data_mem[0x2800] = 0x%h", uut.mem_stage_inst.data_mem.data_mem[16'h0A00]);
        $display("[VM_TB] data_mem[0x2804] = 0x%h", uut.mem_stage_inst.data_mem.data_mem[16'h0A01]);

        if (!saw_iret || !saw_vm_enable || !saw_itlb_miss || !saw_tlbwrite ||
            !saw_dtlb_miss || !saw_store_base || !saw_store_miss) begin
            $display("[VM_TB] FAIL: iret=%0d vm_en=%0d itlb_miss=%0d tlbwrite=%0d dtlb_miss=%0d store_base=%0d store_miss=%0d",
                     saw_iret, saw_vm_enable, saw_itlb_miss, saw_tlbwrite,
                     saw_dtlb_miss, saw_store_base, saw_store_miss);
        end else begin
            $display("[VM_TB] PASS: edge cases covered");
        end
        $finish;
    end

    // Event-based prints + flags
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            saw_itlb_miss  <= 1'b0;
            saw_dtlb_miss  <= 1'b0;
            saw_store_base <= 1'b0;
            saw_store_miss <= 1'b0;
            saw_iret       <= 1'b0;
            saw_vm_enable  <= 1'b0;
            saw_tlbwrite   <= 1'b0;
        end else begin
            if (uut.if_tlb_miss && !saw_itlb_miss) begin
                saw_itlb_miss <= 1'b1;
                $display("[VM_TB] iTLB miss VA=0x%08h PC=0x%08h", uut.if_tlb_fault_addr, uut.program_counter);
            end
            if (uut.mem_tlb_miss && !saw_dtlb_miss) begin
                saw_dtlb_miss <= 1'b1;
                $display("[VM_TB] dTLB miss VA=0x%08h PC=0x%08h", uut.mem_tlb_fault_addr, uut.mem_tlb_fault_pc);
            end
            if (uut.mem_stage_inst.tlbwrite_in) begin
                saw_tlbwrite <= 1'b1;
                $display("[VM_TB] TLBWRITE PC=0x%08h VA=0x%08h PA=0x%08h x1=0x%08h x2=0x%08h rm1=0x%08h",
                         uut.mem_stage_inst.pc_in,
                         uut.mem_stage_inst.alu_result_in,
                         uut.mem_stage_inst.write_data_in,
                         uut.register_table.data_register[1],
                         uut.register_table.data_register[2],
                         uut.rm1);
            end
            if (uut.mem_iret_taken && !saw_iret) begin
                saw_iret <= 1'b1;
                $display("[VM_TB] IRET committed");
            end
            if (uut.vm_enable && !saw_vm_enable) begin
                saw_vm_enable <= 1'b1;
                $display("[VM_TB] VM enabled");
            end
        end
    end

    // Log actual stores to backing memory
    always @(posedge clk) begin
        if (!reset && uut.mem_stage_inst.mem_write_en) begin
            $display("[C%0d] STORE commit addr=0x%08h data=0x%08h",
                     cycle, uut.mem_stage_inst.mem_addr, uut.mem_stage_inst.mem_wdata);
            if (uut.mem_stage_inst.mem_addr == 32'h00000004)
                saw_store_base <= 1'b1;
            if (uut.mem_stage_inst.mem_addr == 32'h00002804)
                saw_store_miss <= 1'b1;
        end
    end

endmodule
