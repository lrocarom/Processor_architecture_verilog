`timescale 1ns / 1ps

module tb_memory_subsystem_rigorous;

    // Inputs to MEM Stage
    reg clk;
    reg reset;
    reg [31:0] alu_result_in;
    reg [31:0] write_data_in;
    reg is_load_in;
    reg is_store_in;
    
    // Outputs
    wire [31:0] wb_data_out;
    wire stall_req;
    wire [4:0] rd_out;

    // Instantiate the Unit Under Test (UUT)
    memory_stage uut (
        .clk(clk),
        .reset(reset),
        .alu_result_in(alu_result_in), 
        .write_data_in(write_data_in), 
        .rd_in(5'd0),                  
        .is_load_in(is_load_in),
        .is_store_in(is_store_in),
        .is_write_in(1'b0),            
        .wb_data_out(wb_data_out),
        .stall_req(stall_req),
        .rd_out(rd_out)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Helper Task: READ
    task check_read(input [31:0] addr, input [31:0] expected_val, input expect_stall, input [127:0] test_name);
    begin
        // Setup inputs
        @(posedge clk);
        is_load_in = 1;
        is_store_in = 0;
        alu_result_in = addr;
        
        // Wait for potential stall combinatorial logic
        #1; 
        
        // Verify Stall Behavior
        if (stall_req !== expect_stall) 
            $display("[FAIL] %0s: Addr 0x%h | Expected Stall=%b | Got Stall=%b", test_name, addr, expect_stall, stall_req);
        else if (expect_stall) 
            $display("[INFO] %0s: Stall asserted correctly.", test_name);

        // If stalled, wait it out
        while (stall_req) @(posedge clk);

        // Check Data on the cycle it becomes valid
        #1;
        if (wb_data_out === expected_val) 
            $display("[PASS] %0s: Read 0x%h = %h", test_name, addr, wb_data_out);
        else 
            $display("[FAIL] %0s: Addr 0x%h | Expected %h | Got %h", test_name, addr, expected_val, wb_data_out);
    end
    endtask

    // Helper Task: WRITE
    task perform_write(input [31:0] addr, input [31:0] data, input [127:0] test_name);
    begin
        @(posedge clk);
        is_load_in = 0;
        is_store_in = 1;
        alu_result_in = addr;
        write_data_in = data;

        // Wait for stall (Stores always stall in your design)
        @(posedge clk);
        while (stall_req) @(posedge clk);

        $display("[PASS] %0s: Wrote %h to 0x%h", test_name, data, addr);
        
        // Clear signals
        is_store_in = 0;
    end
    endtask

    // =========================================================
    // MAIN TEST SEQUENCE
    // =========================================================
    initial begin
        // 1. Initialize
        clk = 0;
        reset = 1;
        is_load_in = 0;
        is_store_in = 0;
        alu_result_in = 0;
        write_data_in = 0;

        // 2. Backdoor Memory Initialization (Loading Test Vectors)
        // Accessing the internal array of data_memory directly
        // Base Addr 0x1000 (Index 1024) -> Set 0
        uut.data_mem.data_mem[1024] = 32'hAAAA_0000; // Offset 0
        uut.data_mem.data_mem[1025] = 32'hAAAA_1111; // Offset 4
        uut.data_mem.data_mem[1026] = 32'hAAAA_2222; // Offset 8
        uut.data_mem.data_mem[1027] = 32'hAAAA_3333; // Offset 12

        // Base Addr 0x2000 (Index 2048) -> Set 0 (CONFLICT with 0x1000)
        uut.data_mem.data_mem[2048] = 32'hBBBB_0000;

        // Base Addr 0x3000 (Index 3072) -> Set 0 (For Write Miss)
        uut.data_mem.data_mem[3072] = 32'hCCCC_0000; 

        #20 reset = 0;
        $display("\n--- RIGOROUS TEST START ---");

        // ---------------------------------------------------------
        // TEST 1: Word Offset & Spatial Locality
        // ---------------------------------------------------------
        // Load 0x1000. Should Miss (Stall). 
        // Then load 0x1004, 0x1008. Should HIT (No Stall) because they are in the same line.
        check_read(32'h1000, 32'hAAAA_0000, 1'b1, "T1_Load_Miss");
        check_read(32'h1004, 32'hAAAA_1111, 1'b0, "T1_Offset_Hit_1");
        check_read(32'h1008, 32'hAAAA_2222, 1'b0, "T1_Offset_Hit_2");

        // ---------------------------------------------------------
        // TEST 2: Cache Eviction (Conflict Miss)
        // ---------------------------------------------------------
        // Load 0x2000. This maps to Set 0 (same as 0x1000). 
        // It should force an eviction of the 0x1000 line.
        check_read(32'h2000, 32'hBBBB_0000, 1'b1, "T2_Eviction_Load");

        // Now, try to read 0x1000 again. 
        // If eviction worked, 0x1000 is gone. This MUST be a MISS (Stall).
        check_read(32'h1000, 32'hAAAA_0000, 1'b1, "T2_ReLoad_After_Evict");

        // ---------------------------------------------------------
        // TEST 3: Store Hit (Write-Through)
        // ---------------------------------------------------------
        // 0x1000 is now in cache (from step above).
        // Write new value to it. Should update Cache AND Memory.
        perform_write(32'h1000, 32'hDEAD_BEEF, "T3_Store_Hit");

        // Read it back. Should be the new value.
        check_read(32'h1000, 32'hDEAD_BEEF, 1'b0, "T3_Read_After_Write");

        // Check Backing Memory (Backdoor Check)
        if (uut.data_mem.data_mem[1024] === 32'hDEAD_BEEF)
            $display("[PASS] T3_Memory_Consistency: Main RAM updated.");
        else
            $display("[FAIL] T3_Memory_Consistency: RAM has %h", uut.data_mem.data_mem[1024]);

        // ---------------------------------------------------------
        // TEST 4: Store Miss (Write-No-Allocate)
        // ---------------------------------------------------------
        // Write to 0x3000. This address is NOT in the cache.
        // Policy: Write to memory, but DO NOT bring line into cache.
        perform_write(32'h3000, 32'hFACE_FEED, "T4_Store_Miss");

        // Now Read 0x3000.
        // If we allocated (Wrong), it would be a HIT.
        // If we did NOT allocate (Correct), it must be a MISS (Stall).
        check_read(32'h3000, 32'hFACE_FEED, 1'b1, "T4_Read_Verify_NoAlloc");

        $display("--- SIMULATION FINISHED ---");
        $finish;
    end

endmodule