`timescale 1ns/1ps

module tb_cpu;

    reg clk;
    reg reset;

    // Instantiate CPU
    cpu mycpu(
        .clk(clk),
        .reset(reset)
    );

    // Clock generation: 10 ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Test sequence
    initial begin
        $dumpfile("build/cpu_wave.vcd");
        $dumpvars(0, tb_cpu);
        $dumpvars(0, tb_cpu.mycpu.mem_data.data_mem[3]);

        // Reset CPU
        reset = 1;
        #5 
        reset = 0;
        #10

        #20

        #40

        #70

        // Run simulation for a few cycles
        repeat (20) @(posedge clk);

        $finish;
    end

endmodule
