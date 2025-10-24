module m_program_counter(
    input          clk,
    input  [31:0]  branch_target, // Address to jump to
    input          branch,        // Branch control
    input          reset,
    output [31:0]  pc_out         // Current PC
);

    // Registro para PC
    reg [31:0] PC_reg;



    always @(posedge clk or posedge reset) begin

        if(reset)
            PC_reg <= 0;
        else 
            PC_reg <= PC_reg + 4;
    end

    assign pc_out = PC_reg;

endmodule
