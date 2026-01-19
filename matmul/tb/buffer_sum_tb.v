`timescale 1ns/1ps

module buffer_sum_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer cycle;
    integer start_cycle;
    integer end_cycle;
    reg     saw_store;
    integer load_mismatch_count;
    reg [31:0] last_bad_addr;
    reg [31:0] last_bad_val;
    reg [31:0] last_bad_exp;
    integer load_error_sum;
    integer observed_sum;
    reg [31:0] first_bad_addr;
    reg [31:0] first_bad_val;
    reg [31:0] first_bad_exp;
    reg [31:0] expected_sum;
    reg [31:0] pending_load_val;
    reg [31:0] pending_load_idx;
    reg        pending_load_valid;
    integer    wb_mismatch_count;
    reg [127:0] load_seen;
    integer load_seen_count;
    integer missing_idx_sum;
    integer missing_first;

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
            load_mismatch_count <= 0;
            last_bad_addr <= 32'b0;
            last_bad_val <= 32'b0;
            last_bad_exp <= 32'b0;
            load_error_sum <= 0;
            observed_sum <= 0;
            first_bad_addr <= 32'b0;
            first_bad_val <= 32'b0;
            first_bad_exp <= 32'b0;
            expected_sum <= 0;
            pending_load_val <= 0;
            pending_load_idx <= 0;
            pending_load_valid <= 1'b0;
            wb_mismatch_count <= 0;
            load_seen <= 128'b0;
            load_seen_count <= 0;
            missing_idx_sum <= 0;
            missing_first <= -1;
        end else begin
            cycle <= cycle + 1;
            if (start_cycle == -1 && uut.program_counter == 32'h00001014) begin
                start_cycle <= cycle;
            end
            if (!saw_store && uut.mem_stage_inst.mem_write_en &&
                (uut.mem_stage_inst.mem_addr == 32'h00000300)) begin
                end_cycle <= cycle;
                saw_store <= 1'b1;
            end
            if (uut.mem_stage_inst.is_load_in && (uut.mem_stage_inst.rd_in == 5'd8) &&
                !uut.mem_stage_inst.stall_req) begin
                if ((uut.mem_stage_inst.alu_result_in >= 32'h00000100) &&
                    (uut.mem_stage_inst.alu_result_in <= 32'h000002FC)) begin
                    observed_sum <= observed_sum + uut.mem_stage_inst.load_data;
                    pending_load_val <= uut.mem_stage_inst.load_data;
                    pending_load_idx <= ((uut.mem_stage_inst.alu_result_in - 32'h00000100) >> 2);
                    pending_load_valid <= 1'b1;
                    if (!load_seen[((uut.mem_stage_inst.alu_result_in - 32'h00000100) >> 2)]) begin
                        load_seen[((uut.mem_stage_inst.alu_result_in - 32'h00000100) >> 2)] <= 1'b1;
                        load_seen_count <= load_seen_count + 1;
                    end
                    if (uut.mem_stage_inst.load_data !==
                        ((uut.mem_stage_inst.alu_result_in - 32'h00000100) >> 2)) begin
                        load_mismatch_count <= load_mismatch_count + 1;
                        last_bad_addr <= uut.mem_stage_inst.alu_result_in;
                        last_bad_val <= uut.mem_stage_inst.load_data;
                        last_bad_exp <= ((uut.mem_stage_inst.alu_result_in - 32'h00000100) >> 2);
                        load_error_sum <= load_error_sum +
                                          ( (uut.mem_stage_inst.alu_result_in - 32'h00000100) >> 2 ) -
                                          uut.mem_stage_inst.load_data;
                        if (load_mismatch_count == 0) begin
                            first_bad_addr <= uut.mem_stage_inst.alu_result_in;
                            first_bad_val <= uut.mem_stage_inst.load_data;
                            first_bad_exp <= ((uut.mem_stage_inst.alu_result_in - 32'h00000100) >> 2);
                        end
                    end
                end
            end
            if (uut.wb_write_reg && (uut.wb_register_d == 5'd2)) begin
                if (pending_load_valid) begin
                    expected_sum <= expected_sum + pending_load_val;
                    if (uut.wb_data_out !== (expected_sum + pending_load_val)) begin
                        wb_mismatch_count <= wb_mismatch_count + 1;
                        $display("[BUFFER_SUM][C%0d] SUM_MISMATCH idx=%0d val=0x%08h exp_sum=0x%08h got=0x%08h",
                                 cycle, pending_load_idx, pending_load_val,
                                 (expected_sum + pending_load_val), uut.wb_data_out);
                    end
                    pending_load_valid <= 1'b0;
                end
            end
        end
    end

    initial begin
        // Initialize instruction memory with NOPs
        for (i = 0; i < 4096; i = i + 1) begin
            uut.fetch_stage.memory_ins.instr_mem[i] = 32'h00000013;
        end

        // Initialize entire data memory to 0 to avoid X propagation
        for (i = 0; i < 4096; i = i + 1) begin
            uut.mem_stage_inst.data_mem.data_mem[i] = 32'h00000000;
        end
        // Initialize data memory: a[i] = i (128 words at 0x100)
        for (i = 0; i < 128; i = i + 1) begin
            uut.mem_stage_inst.data_mem.data_mem[16'h0040 + i] = i[31:0];
        end

        // Program @ 0x1000
        // x1 = 0x100 (base)
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h10000093;
        // x7 = 0x100 (ptr)
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h10000393;
        // x2 = 0 (sum)
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h00000113;
        // x3 = 0 (i)
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h00000193;
        // x4 = 128 (limit)
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h08000213;
        // loop:
        // NOPs to allow x7 to write back before next load
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'h00000013;
        // x8 = mem[x7]
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h0003A403;
        // x2 = x2 + x8
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h00810133;
        // x7 = x7 + 4
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h00438393;
        // x3 = x3 + 1
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'h00118193;
        // BLT x3, x4, loop (-0x18)
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'hFE41C4E3;
        // SW x2, 0x300(x0)
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h30202023;
        // JAL x0, 0
        uut.fetch_stage.memory_ins.instr_mem[16'h040D] = 32'h0000006F;

        // Release reset
        #20 reset = 0;

        // Let it run (MUL has artificial latency)
        #400000;

        $display("[BUFFER_SUM] sum(x2)=0x%08h mem[0x0300]=0x%08h",
                 uut.register_table.data_register[2],
                 uut.mem_stage_inst.data_mem.data_mem[16'h00C0]);
        if (start_cycle != -1 && end_cycle != -1) begin
            $display("[BUFFER_SUM] loop_cycles=%0d total_cycles=%0d",
                     (end_cycle - start_cycle + 1), cycle);
        end else begin
            $display("[BUFFER_SUM] loop_cycles=NA total_cycles=%0d", cycle);
        end
        if (load_mismatch_count != 0 || wb_mismatch_count != 0 || load_seen_count != 128) begin
            $display("[BUFFER_SUM] WARN: load_mismatch=%0d wb_mismatch=%0d loads_seen=%0d",
                     load_mismatch_count, wb_mismatch_count, load_seen_count);
        end
        for (i = 0; i < 128; i = i + 1) begin
            if (!load_seen[i]) begin
                missing_idx_sum = missing_idx_sum + i;
                if (missing_first == -1) missing_first = i;
            end
        end
        if (load_seen_count != 128) begin
            $display("[BUFFER_SUM] WARN: missing_first=%0d missing_idx_sum=%0d",
                     missing_first, missing_idx_sum);
        end

        if (uut.mem_stage_inst.data_mem.data_mem[16'h00C0] !== 32'd8128) begin
            $display("[BUFFER_SUM] FAIL");
        end else begin
            $display("[BUFFER_SUM] PASS");
        end

        $finish;
    end
endmodule
