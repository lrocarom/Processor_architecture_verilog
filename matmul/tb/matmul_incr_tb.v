`timescale 1ns/1ps

`ifndef STAGE1
`ifndef STAGE2
`ifndef STAGE3
`define STAGE1
`endif
`endif
`endif

module matmul_incr_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer j;
    integer t;
    integer cycle;
    reg report_printed;
    reg saw_target_store;
    integer done_countdown;
    integer mismatch_count;
    integer first_bad;

    localparam integer MEM_WORDS = 65536;
    localparam integer N = 8;
    localparam [31:0] BASE_A = 32'h00000100;
    localparam [31:0] BASE_B = 32'h00000200;
    localparam [31:0] BASE_C = 32'h00000300;
    localparam integer BASE_A_WORD = (BASE_A >> 2);
    localparam integer BASE_B_WORD = (BASE_B >> 2);
    localparam integer BASE_C_WORD = (BASE_C >> 2);

    cpu uut(
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cycle <= 0;
            report_printed <= 1'b0;
            saw_target_store <= 1'b0;
            done_countdown <= -1;
        end else begin
            cycle <= cycle + 1;

            if (uut.mem_stage_inst.is_store_in) begin
`ifdef STAGE1
                if (uut.mem_stage_inst.alu_result_in == (BASE_C + 32'h1C)) begin
                    saw_target_store <= 1'b1;
                    done_countdown <= 200;
                end
`elsif STAGE2
                if (uut.mem_stage_inst.alu_result_in == (BASE_C + 32'h1C)) begin
                    saw_target_store <= 1'b1;
                    done_countdown <= 200;
                end
`else
                if (uut.mem_stage_inst.alu_result_in == BASE_C) begin
                    saw_target_store <= 1'b1;
                    done_countdown <= 200;
                end
`endif
            end

            if (done_countdown > 0)
                done_countdown <= done_countdown - 1;

            if ((done_countdown == 0) && !report_printed) begin
`ifdef STAGE1
                mismatch_count = 0;
                first_bad = -1;
                for (i = 0; i < N; i = i + 1) begin
                    if (uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD + i] !== i[31:0]) begin
                        mismatch_count = mismatch_count + 1;
                        if (first_bad == -1) first_bad = i;
                    end
                end
                if (mismatch_count == 0) begin
                    $display("[INCR1] PASS");
                end else begin
                    $display("[INCR1] FAIL mismatches=%0d first_bad=%0d", mismatch_count, first_bad);
                end
`elsif STAGE2
                mismatch_count = 0;
                first_bad = -1;
                for (i = 0; i < N; i = i + 1) begin
                    if (uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD + i] !==
                        uut.mem_stage_inst.data_mem.data_mem[BASE_A_WORD + i]) begin
                        mismatch_count = mismatch_count + 1;
                        if (first_bad == -1) first_bad = i;
                    end
                end
                if (mismatch_count == 0) begin
                    $display("[INCR2] PASS");
                end else begin
                    $display("[INCR2] FAIL mismatches=%0d first_bad=%0d", mismatch_count, first_bad);
                end
`else
                if (uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD] === 32'd36) begin
                    $display("[INCR3] PASS sum=%0d", uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD]);
                end else begin
                    $display("[INCR3] FAIL sum=%0d", uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD]);
                end
`endif
                report_printed <= 1'b1;
            end
        end
    end

    initial begin
        mismatch_count = 0;
        first_bad = -1;

        // Clear memory
        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            uut.mem_stage_inst.data_mem.data_mem[i] = 32'h0;
        end

        // Init A/B for stages that need them
        for (i = 0; i < N; i = i + 1) begin
            uut.mem_stage_inst.data_mem.data_mem[BASE_A_WORD + i] = i + 1;
            uut.mem_stage_inst.data_mem.data_mem[BASE_B_WORD + i] = 32'd1;
        end

        // Program @ 0x1000
`ifdef STAGE1
        // Stage1: linear store 0..7 to C
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h30000513;
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h00000593;
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h00800613;
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h00B52023;
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h00450513;
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h00158593;
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'hFFF60613;
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'hFE0610E3;
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h0000006F;
`elsif STAGE2
        // Stage2: linear copy A -> C
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h10000513;
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h30000593;
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h00800613;
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h00052683;
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h00D5A023;
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h00450513;
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'h00458593;
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'hFFF60613;
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h040D] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h040E] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h040F] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0410] = 32'hFC0616E3;
        uut.fetch_stage.memory_ins.instr_mem[16'h0411] = 32'h0000006F;
`else
        // Stage3: single dot product (sum of A with B=1)
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h10000513;
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h20000593;
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h00800613;
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h00000393;
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h30000813;
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h00000793;
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'h00052683;
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h0005A703;
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h00450513;
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h00458593;
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'h00138393;
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h00070463;
        uut.fetch_stage.memory_ins.instr_mem[16'h040D] = 32'h00D787B3;
        uut.fetch_stage.memory_ins.instr_mem[16'h040E] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h040F] = 32'hFCC3CEE3;
        uut.fetch_stage.memory_ins.instr_mem[16'h0410] = 32'h00F82023;
        uut.fetch_stage.memory_ins.instr_mem[16'h0411] = 32'h0000006F;
`endif

        #20 reset = 0;

        for (t = 0; t < 200000; t = t + 1000) begin
            #1000;
            if (report_printed) begin
                $finish;
            end
        end
        $display("[INCR] TIMEOUT");
        $finish;
    end
endmodule
