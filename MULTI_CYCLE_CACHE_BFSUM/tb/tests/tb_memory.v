`timescale 1ns / 1ps

module tb_memory_subsystem;

    // Inputs to MEM Stage
    reg clk;
    reg reset;
    reg [31:0] alu_result_in;
    reg [31:0] write_data_in;
    reg is_load_in;
    reg is_store_in;
    
    // Outputs from MEM Stage
    wire [31:0] wb_data_out;
    wire stall_req;

    // Instantiate the Memory Stage (which contains Cache + Memory)
    memory_stage uut (
        .clk(clk),
        .reset(reset),
        
        .alu_result_in(alu_result_in), // Used as Address
        .write_data_in(write_data_in), // Used for Stores
        .rd_in(5'd0),                  // Unused in this test
        .is_load_in(is_load_in),
        .is_store_in(is_store_in),
        .is_write_in(1'b0),            // Unused in this test
        
        .wb_data_out(wb_data_out),
        .stall_req(stall_req)
    );

    // Clock Generation
    always #5 clk = ~clk;

    initial begin
        // 1. Initialize
        clk = 0;
        reset = 1;
        alu_result_in = 0;
        write_data_in = 0;
        is_load_in = 0;
        is_store_in = 0;

        #20 reset = 0;
        $display("--- SIMULATION START ---");

        // ------------------------------------------------------------
        // CASE 1: READ MISS (Load from 0x100)
        // ------------------------------------------------------------
        // We expect: 
        // 1. stall_req goes HIGH immediately.
        // 2. It stays HIGH for ~10 cycles.
        // 3. wb_data_out becomes 0xCAFEBABE (from data_memory initial block).
        
        @(posedge clk);
        $display("[T= %0t] Requesting Load at 0x100...", $time);
        is_load_in = 1;
        alu_result_in = 32'h100;

        // Wait one cycle to let combinatorial logic settle
        #1; 
        if (stall_req) $display("[PASS] Stall asserted immediately.");
        else           $display("[FAIL] Stall NOT asserted!");

        // Wait until stall clears
        while (stall_req) begin
            @(posedge clk); 
        end
        
        // Check Data
        #1;
        if (wb_data_out === 32'hCAFEBABE) 
            $display("[PASS] Data Loaded: 0x%h", wb_data_out);
        else 
            $display("[FAIL] Expected 0xCAFEBABE, got 0x%h", wb_data_out);

        // ------------------------------------------------------------
        // CASE 2: READ HIT (Load from 0x100 again)
        // ------------------------------------------------------------
        // We expect: NO STALL. Data available immediately.
        
        @(posedge clk);
        $display("\n[T= %0t] Requesting Load at 0x100 (Again)...", $time);
        // Inputs are still set to 0x100 from previous test
        
        #1;
        if (stall_req == 0 && wb_data_out === 32'hCAFEBABE)
             $display("[PASS] Hit! No Stall, Data valid.");
        else
             $display("[FAIL] Stall=%b (Expected 0), Data=%h", stall_req, wb_data_out);

        // ------------------------------------------------------------
        // CASE 3: STORE (Write 0x9999 to 0x100)
        // ------------------------------------------------------------
        // Your policy is Write-Through with Stalls on Stores.
        // We expect: Stall for 10 cycles, then memory update.
        
        @(posedge clk);
        is_load_in = 0;
        is_store_in = 1;
        write_data_in = 32'h9999;
        
        $display("\n[T= %0t] Storing 0x9999 to 0x100...", $time);
        
        @(posedge clk); // Step into the stall
        while (stall_req) @(posedge clk);
        
        $display("[PASS] Store Stall Finished.");

        // ------------------------------------------------------------
        // CASE 4: VERIFY WRITE (Load 0x100)
        // ------------------------------------------------------------
        is_store_in = 0;
        is_load_in = 1;
        
        @(posedge clk); // Give it a cycle to hit
        #1;
        if (wb_data_out === 32'h9999)
             $display("[PASS] Read back updated value: 0x9999");
        else
             $display("[FAIL] Read back error: %h", wb_data_out);

        $finish;
    end

endmodule