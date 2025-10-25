
module pc_tb;

    reg [31:0] branch_target_in;
    wire [31:0] program_counter_out;
    reg clk;
    reg rst;
    reg branch;


    //First step will be to increase the program counter

    m_program_counter pc(   .clk (clk),
                            .branch_target (branch_target_in),       // Dirección de PC desde fuera (por ejemplo, para saltos)
                            .branch (branch),    
                            .reset (rst),           // Señal para elegir si actualizar PC normal o salto
                            .pc_out (program_counter_out)
                            );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk; // 10 ns clock period

    initial begin 
        // $dumpfile("build/pc_wave.vcd");
        // $dumpvars(0, pc_tb);
        

        rst = 1;
        branch = 0;
        branch_target_in = 0;
        #5 
        rst = 0;
        #20

        branch = 0;

        #40

        $finish;
    end

endmodule