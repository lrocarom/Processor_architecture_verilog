`timescale 1ns/1ps

module matmul_small_tb;
    reg clk = 0;
    reg reset = 1;
    integer i;
    integer j;
    integer cycle;
    integer start_cycle;
    integer end_cycle;
    reg     saw_last_store;
    integer done_countdown;
    integer mismatch_count;
    integer first_bad;
    reg [31:0] last_i;
    reg        done_reported;
    reg        report_printed;
    reg [31:0] last_c_store_addr;
    integer    c_store_count;
    reg [31:0] last_store_pc;
    integer    store_events;
    reg        prev_is_store;
    integer    t;

    localparam integer N = 8;
    localparam integer MEM_WORDS = 65536;
    localparam [31:0] BASE_A = 32'h00000100;
    localparam [31:0] BASE_B = 32'h00000200;
    localparam [31:0] BASE_C = 32'h00000300;
    localparam [31:0] STRIDE = (N * 4);
    localparam integer NN = (N*N);
    localparam integer BASE_A_WORD = (BASE_A >> 2);
    localparam integer BASE_B_WORD = (BASE_B >> 2);
    localparam integer BASE_C_WORD = (BASE_C >> 2);
    localparam [31:0] LAST_C_ADDR = BASE_C + ((NN - 1) << 2);

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
            done_countdown <= -1;
            last_i <= 32'hFFFFFFFF;
            done_reported <= 1'b0;
            report_printed <= 1'b0;
            last_c_store_addr <= 32'b0;
            c_store_count <= 0;
            last_store_pc <= 32'hFFFFFFFF;
            store_events <= 0;
            prev_is_store <= 1'b0;
        end else begin
            cycle <= cycle + 1;
            if (start_cycle == -1 && uut.program_counter == 32'h00001040) begin
                start_cycle <= cycle;
            end

            if (uut.mem_stage_inst.is_store_in) begin
                if (!prev_is_store) begin
                    store_events <= store_events + 1;
                    $display("[MATMUL_SMALL] store: pc=0x%08h addr=0x%08h data=0x%08h i=%0d j=%0d j_b=%0d k=%0d sum=0x%08h",
                             uut.mem_stage_inst.pc_in,
                             uut.mem_stage_inst.alu_result_in,
                             uut.mem_stage_inst.write_data_in,
                             uut.register_table.data_register[5],
                             (uut.register_table.data_register[6] >> 2),
                             uut.register_table.data_register[6],
                             uut.register_table.data_register[7],
                             uut.register_table.data_register[15]);
                end
                last_store_pc <= uut.mem_stage_inst.pc_in;
                if (!saw_last_store &&
                    (uut.mem_stage_inst.alu_result_in == LAST_C_ADDR)) begin
                    end_cycle <= cycle;
                    saw_last_store <= 1'b1;
                    done_countdown <= 200; // allow final pipeline drains
                end
                if ((uut.mem_stage_inst.alu_result_in >= BASE_C) &&
                    (uut.mem_stage_inst.alu_result_in <= LAST_C_ADDR)) begin
                    last_c_store_addr <= uut.mem_stage_inst.alu_result_in;
                    c_store_count <= c_store_count + 1;
                end
            end
            prev_is_store <= uut.mem_stage_inst.is_store_in;

            if ((uut.mem_stage_inst.pc_in == 32'h00001044) &&
                (uut.register_table.data_register[5] < 2) &&
                ((uut.register_table.data_register[6] >> 2) < 2) &&
                (uut.register_table.data_register[7] < 3)) begin
                $display("[MATMUL_SMALL] load A: addr=0x%08h i=%0d j=%0d j_b=%0d k=%0d",
                         uut.mem_stage_inst.alu_result_in,
                         uut.register_table.data_register[5],
                         (uut.register_table.data_register[6] >> 2),
                         uut.register_table.data_register[6],
                         uut.register_table.data_register[7]);
            end
            if ((uut.mem_stage_inst.pc_in == 32'h00001030) &&
                (uut.register_table.data_register[5] < 2) &&
                ((uut.register_table.data_register[6] >> 2) < 3)) begin
                $display("[MATMUL_SMALL] jcalc: i=%0d j=%0d j_b=%0d x6=0x%08h x9=0x%08h",
                         uut.register_table.data_register[5],
                         (uut.register_table.data_register[6] >> 2),
                         uut.register_table.data_register[6],
                         uut.register_table.data_register[6],
                         uut.register_table.data_register[9]);
            end
            if ((uut.mem_stage_inst.pc_in == 32'h00001048) &&
                (uut.register_table.data_register[5] < 2) &&
                ((uut.register_table.data_register[6] >> 2) < 2) &&
                (uut.register_table.data_register[7] < 3)) begin
                $display("[MATMUL_SMALL] load B: addr=0x%08h i=%0d j=%0d j_b=%0d k=%0d",
                         uut.mem_stage_inst.alu_result_in,
                         uut.register_table.data_register[5],
                         (uut.register_table.data_register[6] >> 2),
                         uut.register_table.data_register[6],
                         uut.register_table.data_register[7]);
            end

            if (!done_reported && (uut.register_table.data_register[17] >= (N*4*8))) begin
                done_countdown <= 200;
                done_reported <= 1'b1;
            end
            if (done_countdown > 0)
                done_countdown <= done_countdown - 1;
            else if (done_countdown == 0 && !done_reported) begin
                done_reported <= 1'b1;
            end

            if (uut.register_table.data_register[5] != last_i) begin
                last_i <= uut.register_table.data_register[5];
                $display("[MATMUL_SMALL] progress: i=%0d cycle=%0d", uut.register_table.data_register[5], cycle);
            end

            if (done_reported && !report_printed) begin
                // Check results: with identity B, C should equal A
                for (i = 0; i < (N*N); i = i + 1) begin
                    if (uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD + i] !==
                        uut.mem_stage_inst.data_mem.data_mem[BASE_A_WORD + i]) begin
                        mismatch_count = mismatch_count + 1;
                        if (first_bad == -1) first_bad = i;
                    end
                end

                $display("[MATMUL_SMALL] c[0]=0x%08h c[last]=0x%08h",
                         uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD],
                         uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD + (N*N-1)]);
                if (start_cycle != -1 && end_cycle != -1) begin
                    $display("[MATMUL_SMALL] loop_cycles=%0d total_cycles=%0d",
                             (end_cycle - start_cycle + 1), cycle);
                end else begin
                    $display("[MATMUL_SMALL] loop_cycles=NA total_cycles=%0d", cycle);
                end
                if (!saw_last_store) begin
                    $display("[MATMUL_SMALL] WARN: store to 0x%08h not observed", LAST_C_ADDR);
                    $display("[MATMUL_SMALL] last_c_store=0x%08h count=%0d base_c=0x%08h",
                             last_c_store_addr, c_store_count, BASE_C);
                    $display("[MATMUL_SMALL] store events=%0d last_pc=0x%08h",
                             store_events, last_store_pc);
                end
                if (mismatch_count != 0) begin
                    $display("[MATMUL_SMALL] WARN: mismatches=%0d first_bad=%0d", mismatch_count, first_bad);
                end

                if (mismatch_count == 0) begin
                    $display("[MATMUL_SMALL] PASS");
                end else begin
                    $display("[MATMUL_SMALL] FAIL");
                end
                report_printed <= 1'b1;
            end
        end
    end

    initial begin
        mismatch_count = 0;
        first_bad = -1;

        // Initialize entire data memory to 0 to avoid X propagation
        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            uut.mem_stage_inst.data_mem.data_mem[i] = 32'h00000000;
        end

        // Initialize A and B (NxN)
        // A[i][j] = i + j + 1, B is identity (0/1)
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                uut.mem_stage_inst.data_mem.data_mem[BASE_A_WORD + (i*N) + j] = i + j + 1;
                uut.mem_stage_inst.data_mem.data_mem[BASE_B_WORD + (i*N) + j] = (i == j) ? 32'd1 : 32'd0;
            end
        end

        // Program @ 0x1000 (no MUL, B identity => conditional add)
        // Base addresses are direct immediates for small N.
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h10000093;
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h20000113;
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h30000193;
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h02000213;
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h00800813;
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'h00000893;
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'h10000993;
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h01108433;
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'h011184B3;
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'h00000313;
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h006105B3;
        uut.fetch_stage.memory_ins.instr_mem[16'h040D] = 32'h00648633;
        uut.fetch_stage.memory_ins.instr_mem[16'h040E] = 32'h00040533;
        uut.fetch_stage.memory_ins.instr_mem[16'h040F] = 32'h00000793;
        uut.fetch_stage.memory_ins.instr_mem[16'h0410] = 32'h00000393;
        uut.fetch_stage.memory_ins.instr_mem[16'h0411] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0412] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0413] = 32'h00052703;
        uut.fetch_stage.memory_ins.instr_mem[16'h0414] = 32'h0005A683;
        uut.fetch_stage.memory_ins.instr_mem[16'h0415] = 32'h00450513;
        uut.fetch_stage.memory_ins.instr_mem[16'h0416] = 32'h02058593;
        uut.fetch_stage.memory_ins.instr_mem[16'h0417] = 32'h00138393;
        uut.fetch_stage.memory_ins.instr_mem[16'h0418] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0419] = 32'h00068463;
        uut.fetch_stage.memory_ins.instr_mem[16'h041A] = 32'h00E787B3;
        uut.fetch_stage.memory_ins.instr_mem[16'h041B] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h041C] = 32'hFD03CEE3;
        uut.fetch_stage.memory_ins.instr_mem[16'h041D] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h041E] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h041F] = 32'h00F62023;
        uut.fetch_stage.memory_ins.instr_mem[16'h0420] = 32'h00430313;
        uut.fetch_stage.memory_ins.instr_mem[16'h0421] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0422] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0423] = 32'hFA4342E3;
        uut.fetch_stage.memory_ins.instr_mem[16'h0424] = 32'h02088893;
        uut.fetch_stage.memory_ins.instr_mem[16'h0425] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0426] = 32'h00000013;
        uut.fetch_stage.memory_ins.instr_mem[16'h0427] = 32'hF938C4E3;
        uut.fetch_stage.memory_ins.instr_mem[16'h0428] = 32'h0000006F;

        // Release reset
        #20 reset = 0;

        // Let it run
        for (t = 0; t < 800000; t = t + 1000) begin
            #1000;
            if (report_printed) begin
                $finish;
            end
        end
        $display("[MATMUL_SMALL] TIMEOUT before completion");
        $finish;
    end
endmodule
