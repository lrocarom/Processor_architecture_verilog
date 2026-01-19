`timescale 1ns/1ps

module branch_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer cycle;
    integer branch_total;
    integer branch_taken;
    integer branch_not_taken;
    integer branch_flushes;
    reg [31:0] last_branch_pc;
    reg test_pass;

    cpu uut(
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    initial begin
        branch_total = 0;
        branch_taken = 0;
        branch_not_taken = 0;
        branch_flushes = 0;
        last_branch_pc = 32'hFFFFFFFF;

        // Initialize instruction memory with NOPs
        for (i = 0; i < 4096; i = i + 1) begin
            uut.fetch_stage.memory_ins.instr_mem[i] = 32'h00000013;
        end

        // -----------------------------
        // Branch test program @ PA 0x1000
        // -----------------------------
        // x1 = 5
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h00500093;
        // x2 = 5
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h00500113;
        // x3 = 7
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h00700193;
        // x4 = 9
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h00900213;
        // BEQ x1, x2, +8 (skip next)
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h00208463;
        // x5 = 0x11 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h01100293;
        // x5 = 0x22 (taken path)
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'h02200293;
        // BNE x1, x2, +8 (not taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h00209463;
        // x6 = 0x33 (executes)
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h03300313;
        // BNE x1, x3, +8 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h00309463;
        // x6 = 0x44 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'h04400313;
        // x6 = 0x55 (taken path)
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'h05500313;
        // BLT x1, x4, +8 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h0040C463;
        // x7 = 0x66 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h040D] = 32'h06600393;
        // x7 = 0x77 (taken path)
        uut.fetch_stage.memory_ins.instr_mem[16'h040E] = 32'h07700393;
        // BGE x4, x1, +8 (taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h040F] = 32'h00125463;
        // x8 = 0x88 (skipped)
        uut.fetch_stage.memory_ins.instr_mem[16'h0410] = 32'h08800413;
        // x8 = 0x99 (taken path)
        uut.fetch_stage.memory_ins.instr_mem[16'h0411] = 32'h09900413;
        // BLT x4, x1, +8 (not taken)
        uut.fetch_stage.memory_ins.instr_mem[16'h0412] = 32'h00124463;
        // x9 = 0xAA (executes)
        uut.fetch_stage.memory_ins.instr_mem[16'h0413] = 32'h0AA00493;
        // x9 = 0xBB (executes)
        uut.fetch_stage.memory_ins.instr_mem[16'h0414] = 32'h0BB00493;
        // JAL x0, 0 (loop)
        uut.fetch_stage.memory_ins.instr_mem[16'h0415] = 32'h0000006F;

        // Release reset
        #20 reset = 0;

        // Run for enough cycles to complete program
        for (cycle = 0; cycle < 200; cycle = cycle + 1) begin
            @(posedge clk);
        end

        // Check results
        test_pass = 1;
        if (uut.register_table.data_register[5] !== 32'h00000022) test_pass = 0;
        if (uut.register_table.data_register[6] !== 32'h00000055) test_pass = 0;
        if (uut.register_table.data_register[7] !== 32'h00000077) test_pass = 0;
        if (uut.register_table.data_register[8] !== 32'h00000099) test_pass = 0;
        if (uut.register_table.data_register[9] !== 32'h000000BB) test_pass = 0;

        if (test_pass) begin
            $display("[BRANCH_TB] PASS");
        end else begin
            $display("[BRANCH_TB] FAIL: x5=0x%08h x6=0x%08h x7=0x%08h x8=0x%08h x9=0x%08h",
                     uut.register_table.data_register[5],
                     uut.register_table.data_register[6],
                     uut.register_table.data_register[7],
                     uut.register_table.data_register[8],
                     uut.register_table.data_register[9]);
        end

        $display("[BRANCH_TB] Metrics: total=%0d taken=%0d not_taken=%0d flushes=%0d",
                 branch_total, branch_taken, branch_not_taken, branch_flushes);

        $finish;
    end

    // Branch-level tracing and metrics
    always @(posedge clk) begin
        if (!reset) begin
            if (uut.ex_branch && (uut.ex_pc != last_branch_pc)) begin
                last_branch_pc = uut.ex_pc;
                branch_total = branch_total + 1;
                if (uut.branch_taken) begin
                    branch_taken = branch_taken + 1;
                    branch_flushes = branch_flushes + 1;
                end else begin
                    branch_not_taken = branch_not_taken + 1;
                end

                case (uut.ex_branch_type)
                    4'b0001: $display("[BRANCH_TB][C%0d] BEQ  rs1=0x%08h rs2=0x%08h taken=%0d target=0x%08h",
                                      cycle, uut.alu_op1_real, uut.alu_op2_real, uut.branch_taken, uut.branch_target);
                    4'b0010: $display("[BRANCH_TB][C%0d] BNE  rs1=0x%08h rs2=0x%08h taken=%0d target=0x%08h",
                                      cycle, uut.alu_op1_real, uut.alu_op2_real, uut.branch_taken, uut.branch_target);
                    4'b0011: $display("[BRANCH_TB][C%0d] BLT  rs1=0x%08h rs2=0x%08h taken=%0d target=0x%08h",
                                      cycle, uut.alu_op1_real, uut.alu_op2_real, uut.branch_taken, uut.branch_target);
                    4'b0100: $display("[BRANCH_TB][C%0d] BGE  rs1=0x%08h rs2=0x%08h taken=%0d target=0x%08h",
                                      cycle, uut.alu_op1_real, uut.alu_op2_real, uut.branch_taken, uut.branch_target);
                    default: $display("[BRANCH_TB][C%0d] BR?  op=0x%0h rs1=0x%08h rs2=0x%08h taken=%0d target=0x%08h",
                                      cycle, uut.ex_branch_type, uut.alu_op1_real, uut.alu_op2_real, uut.branch_taken, uut.branch_target);
                endcase
            end
        end
    end
endmodule
