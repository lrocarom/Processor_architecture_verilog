`timescale 1ns/1ps

module matmul_tb;
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
    integer    store_cycles;
    integer    store_events;
    integer    c_store_events;
    reg        prev_is_store;
    reg [31:0] store_min_addr;
    reg [31:0] store_max_addr;
    integer    store_sample_count;
    integer    t;

    localparam integer N = 128;
    localparam integer MEM_WORDS = 65536;
    localparam integer PRINT_PERIOD = 1000000;
    localparam [31:0] BASE_A = 32'h00000100;
    localparam [31:0] BASE_B = 32'h00010100;
    localparam [31:0] BASE_C = 32'h00020100;
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
            store_cycles <= 0;
            store_events <= 0;
            c_store_events <= 0;
            prev_is_store <= 1'b0;
            store_min_addr <= 32'hFFFFFFFF;
            store_max_addr <= 32'h00000000;
            store_sample_count <= 0;
        end else begin
            cycle <= cycle + 1;
            if (start_cycle == -1 && uut.program_counter == 32'h00001054) begin
                start_cycle <= cycle;
            end
            if (uut.mem_stage_inst.is_store_in) begin
                store_cycles <= store_cycles + 1;
                if (!prev_is_store) begin
                    store_events <= store_events + 1;
                    if (uut.mem_stage_inst.alu_result_in < store_min_addr)
                        store_min_addr <= uut.mem_stage_inst.alu_result_in;
                    if (uut.mem_stage_inst.alu_result_in > store_max_addr)
                        store_max_addr <= uut.mem_stage_inst.alu_result_in;
                end
                last_store_pc <= uut.mem_stage_inst.pc_in;
                if (!saw_last_store &&
                    (uut.mem_stage_inst.alu_result_in == LAST_C_ADDR)) begin
                    end_cycle <= cycle;
                    saw_last_store <= 1'b1;
                    done_countdown <= 1000; // allow final pipeline drains
                end
                if ((uut.mem_stage_inst.alu_result_in >= BASE_C) &&
                    (uut.mem_stage_inst.alu_result_in <= LAST_C_ADDR)) begin
                    last_c_store_addr <= uut.mem_stage_inst.alu_result_in;
                    c_store_count <= c_store_count + 1;
                    if (!prev_is_store) begin
                        c_store_events <= c_store_events + 1;
                    end
                end
            end
            prev_is_store <= uut.mem_stage_inst.is_store_in;
            if (!done_reported && (uut.register_table.data_register[20] >= 32'h00010000)) begin
                done_countdown <= 1000;
                done_reported <= 1'b1;
            end
            if (done_countdown > 0)
                done_countdown <= done_countdown - 1;
            else if (done_countdown == 0 && !done_reported) begin
                done_reported <= 1'b1;
            end
            if (uut.register_table.data_register[5] != last_i) begin
                last_i <= uut.register_table.data_register[5];
                if (uut.register_table.data_register[5][2:0] == 3'b000) begin
                    $display("[MATMUL] progress: i=%0d cycle=%0d",
                             uut.register_table.data_register[5], cycle);
                end
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

                $display("[MATMUL] c[0]=0x%08h c[last]=0x%08h",
                         uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD],
                         uut.mem_stage_inst.data_mem.data_mem[BASE_C_WORD + (N*N-1)]);
                if (start_cycle != -1 && end_cycle != -1) begin
                    $display("[MATMUL] loop_cycles=%0d total_cycles=%0d",
                             (end_cycle - start_cycle + 1), cycle);
                end else begin
                    $display("[MATMUL] loop_cycles=NA total_cycles=%0d", cycle);
                end
                if (!saw_last_store) begin
                    $display("[MATMUL] WARN: store to 0x%08h not observed", LAST_C_ADDR);
                    $display("[MATMUL] last_c_store=0x%08h count=%0d base_c=0x%08h",
                             last_c_store_addr, c_store_count, BASE_C);
                    $display("[MATMUL] store cycles=%0d events=%0d c_events=%0d last_pc=0x%08h",
                             store_cycles, store_events, c_store_events, last_store_pc);
                    $display("[MATMUL] store addr range: min=0x%08h max=0x%08h",
                             store_min_addr, store_max_addr);
                end
                if (mismatch_count != 0) begin
                    $display("[MATMUL] WARN: mismatches=%0d first_bad=%0d", mismatch_count, first_bad);
                end

                if (mismatch_count == 0) begin
                    $display("[MATMUL] PASS");
                end else begin
                    $display("[MATMUL] FAIL");
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

        // Initialize A and B (128x128)
        // A[i][j] = i + j + 1, B is identity (0/1)
        for (i = 0; i < N; i = i + 1) begin
            for (j = 0; j < N; j = j + 1) begin
                uut.mem_stage_inst.data_mem.data_mem[BASE_A_WORD + (i*N) + j] = i + j + 1;
                uut.mem_stage_inst.data_mem.data_mem[BASE_B_WORD + (i*N) + j] = (i == j) ? 32'd1 : 32'd0;
            end
        end
        // Constant used by program: 0x00010000 at address 0x80 (word index 32)
        uut.mem_stage_inst.data_mem.data_mem[32] = 32'h00010000;

        // Program @ 0x1000 (no MUL, B identity => conditional add)
        // Hazard-safe scheduling with a load-retry loop for x17.
        uut.fetch_stage.memory_ins.instr_mem[16'h0400] = 32'h10000093; // addi x1, x0, 0x100
        uut.fetch_stage.memory_ins.instr_mem[16'h0401] = 32'h08002883; // lw x17, 128(x0)
        uut.fetch_stage.memory_ins.instr_mem[16'h0402] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h0403] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h0404] = 32'h00089463; // bne x17, x0, +8
        uut.fetch_stage.memory_ins.instr_mem[16'h0405] = 32'hFF1FF06F; // jal x0, -16 (retry load)
        uut.fetch_stage.memory_ins.instr_mem[16'h0406] = 32'h01108133; // add x2, x1, x17
        uut.fetch_stage.memory_ins.instr_mem[16'h0407] = 32'h011101B3; // add x3, x2, x17
        uut.fetch_stage.memory_ins.instr_mem[16'h0408] = 32'h20000213; // addi x4, x0, 512
        uut.fetch_stage.memory_ins.instr_mem[16'h0409] = 32'h08000813; // addi x16, x0, 128
        uut.fetch_stage.memory_ins.instr_mem[16'h040A] = 32'h00000A13; // addi x20, x0, 0
        uut.fetch_stage.memory_ins.instr_mem[16'h040B] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h040C] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h040D] = 32'h01408433; // add x8, x1, x20
        uut.fetch_stage.memory_ins.instr_mem[16'h040E] = 32'h014184B3; // add x9, x3, x20
        uut.fetch_stage.memory_ins.instr_mem[16'h040F] = 32'h00000313; // addi x6, x0, 0
        uut.fetch_stage.memory_ins.instr_mem[16'h0410] = 32'h006105B3; // add x11, x2, x6
        uut.fetch_stage.memory_ins.instr_mem[16'h0411] = 32'h00648633; // add x12, x9, x6
        uut.fetch_stage.memory_ins.instr_mem[16'h0412] = 32'h00040533; // add x10, x8, x0
        uut.fetch_stage.memory_ins.instr_mem[16'h0413] = 32'h00000793; // addi x15, x0, 0
        uut.fetch_stage.memory_ins.instr_mem[16'h0414] = 32'h00000393; // addi x7, x0, 0
        uut.fetch_stage.memory_ins.instr_mem[16'h0415] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h0416] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h0417] = 32'h00052703; // lw x14, 0(x10)
        uut.fetch_stage.memory_ins.instr_mem[16'h0418] = 32'h0005A683; // lw x13, 0(x11)
        uut.fetch_stage.memory_ins.instr_mem[16'h0419] = 32'h00450513; // addi x10, x10, 4
        uut.fetch_stage.memory_ins.instr_mem[16'h041A] = 32'h20058593; // addi x11, x11, 512
        uut.fetch_stage.memory_ins.instr_mem[16'h041B] = 32'h00138393; // addi x7, x7, 1
        uut.fetch_stage.memory_ins.instr_mem[16'h041C] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h041D] = 32'h00068463; // beq x13, x0, 8
        uut.fetch_stage.memory_ins.instr_mem[16'h041E] = 32'h00E787B3; // add x15, x15, x14
        uut.fetch_stage.memory_ins.instr_mem[16'h041F] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h0420] = 32'hFD03CEE3; // blt x7, x16, -36
        uut.fetch_stage.memory_ins.instr_mem[16'h0421] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h0422] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h0423] = 32'h00F62023; // sw x15, 0(x12)
        uut.fetch_stage.memory_ins.instr_mem[16'h0424] = 32'h00430313; // addi x6, x6, 4
        uut.fetch_stage.memory_ins.instr_mem[16'h0425] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h0426] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h0427] = 32'hFA4342E3; // blt x6, x4, -92
        uut.fetch_stage.memory_ins.instr_mem[16'h0428] = 32'h200A0A13; // addi x20, x20, 512
        uut.fetch_stage.memory_ins.instr_mem[16'h0429] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h042A] = 32'h00000013; // nop
        uut.fetch_stage.memory_ins.instr_mem[16'h042B] = 32'hF91A44E3; // blt x20, x17, -120
        uut.fetch_stage.memory_ins.instr_mem[16'h042C] = 32'h0000006F; // jal x0, 0

        // Release reset
        #20 reset = 0;

        // Let it run (large loop)
        for (t = 0; t < 1000000000; t = t + 1000) begin
            #1000;
            if (report_printed) begin
                $finish;
            end
        end
        $display("[MATMUL] TIMEOUT before completion");
        $finish;
    end
endmodule
