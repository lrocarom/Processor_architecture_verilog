`timescale 1ns / 1ps

module cpu_cache_tb;

    reg clk;
    reg reset;
    
    // Instantiate CPU
    cpu uut (
        .clk(clk),
        .reset(reset)
    );

    // Clock Setup
    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        #20 reset = 0;
        
        $display("--- Simulation Start ---");
        $display("Expectation: High latency at start (Miss), then low latency (Hits).");

        // Run for enough time to see the refill and subsequent hits
        #500;
        $finish;
    end

    // Monitor
    always @(posedge clk) begin
        if (!reset) begin
            $display("Time: %t | PC: %h | Instr: %h | Stall: %b | Hit/Miss: %s", 
                     $time, 
                     uut.program_counter, 
                     uut.instruction, 
                     uut.global_stall,
                     (uut.global_stall && uut.fetch_stage.icache_stall) ? "MISS (Refilling)" : "HIT / RUN"
                     );
        end
    end

endmodule