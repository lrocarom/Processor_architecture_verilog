module m_fetch(
    input          clk,
    input  [12:0]  branch_target, // Address to jump to
    input          branch,        // Branch control
    input  [31:0]  jump_target,
    input          jump,           // Jump control
    input          reset,
    input          panic, 
    output [31:0]  pc_out,                 // Current PC
    output [31:0] instruction_out         // Current PC
);

    m_program_counter pc(   .clk (clk),
                            .branch_target (branch_target),       // Dirección de PC desde fuera (por ejemplo, para saltos)
                            .branch (branch),
                            .jump_target(jump_target),
                            .jump (jump),   
                            .reset (reset),
                            .panic (panic),           // Señal para elegir si actualizar PC normal o salto
                            .pc_out (pc_out)
                            );

    instruction_memory memory_ins( .program_counter (pc_out),
                                    .instruction_out (instruction_out) );

endmodule
