`timescale 1ns/1ps

module sb_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer cycle;
    integer sb_enq_count;
    integer sb_drain_count;

    cpu uut(
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle <= 0;
            sb_enq_count <= 0;
            sb_drain_count <= 0;
        end else begin
            cycle <= cycle + 1;
            if (uut.mem_stage_inst.sb_enq_valid)
                sb_enq_count <= sb_enq_count + 1;
            if (uut.mem_stage_inst.sb.mem_valid)
                sb_drain_count <= sb_drain_count + 1;
        end
    end

    initial begin
        // Initialize instruction memory with NOPs
        for (i = 0; i < 4096; i = i + 1) begin
            uut.fetch_stage.memory_ins.instr_mem[i] = 32'h00000013;
        end

        // Initialize backing memory
        uut.mem_stage_inst.data_mem.data_mem[16'h0040] = 32'hAABBCCDD; // 0x100
        uut.mem_stage_inst.data_mem.data_mem[16'h0041] = 32'h11223344; // 0x104

        // Program @ 0x1000
        // LW x1, 0x100(x0)     ; bring line into cache
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h10002083;
        // ADDI x2, x0, 0x80    ; x2 = 0x80
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h08000113;
        // SB x2, 0x104(x0)     ; store hit -> enqueue in SB
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h10200223;
        // LBU x3, 0x104(x0)    ; must bypass from SB -> 0x80
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h10404183;
        // LBU x4, 0x104(x0)    ; after drain, should still read 0x80
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h10404203;
        // JAL x0, 0
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h0000006F;

        // Release reset
        #20 reset = 0;

        // Let it run
        #3000;

        $display("[SB_TB] x1=0x%08h x2=0x%08h x3=0x%08h x4=0x%08h",
                 uut.register_table.data_register[1],
                 uut.register_table.data_register[2],
                 uut.register_table.data_register[3],
                 uut.register_table.data_register[4]);
        $display("[SB_TB] mem[0x0100]=0x%08h mem[0x0104]=0x%08h",
                 uut.mem_stage_inst.data_mem.data_mem[16'h0040],
                 uut.mem_stage_inst.data_mem.data_mem[16'h0041]);
        $display("[SB_TB] sb_enq=%0d sb_drain=%0d", sb_enq_count, sb_drain_count);

        if (uut.register_table.data_register[3] !== 32'h00000080 ||
            uut.register_table.data_register[4] !== 32'h00000080 ||
            uut.mem_stage_inst.data_mem.data_mem[16'h0041] !== 32'h11223380 ||
            sb_enq_count < 1 || sb_drain_count < 1) begin
            $display("[SB_TB] FAIL");
        end else begin
            $display("[SB_TB] PASS");
        end

        $finish;
    end
endmodule
