module m_program_counter(
    input          clk,
    input  [31:0]  branch_target, // Address to jump to
    input          branch,        // Branch control
    input  [31:0]  jump_target,
    input          jump,           // Jump control
    input          reset,
    input          panic, 
    input          stall,          // NEW: Freeze PC when stall is HIGH
    input          exception,
    input  [31:0]  exception_target,
    output wire [31:0]  pc_out         // Current PC
);
    wire [31:0]  pc_out_2;
    // Registro para PC
    reg [31:0] PC_reg;
    
    initial begin
        PC_reg = 32'h00001000;
    end



    always @(posedge clk or posedge reset) begin

        if(reset)
            PC_reg <= 32'h00001000;
        else if (exception)
            PC_reg <= exception_target;
        else if (branch)
            PC_reg <= branch_target;
        else if (jump)
            PC_reg <= jump_target;
        else if (panic)
            PC_reg <=  32'h00002000;
        else if (stall)
            PC_reg <= PC_reg; // Hold the value
        else
            PC_reg <= PC_reg + 4;
    end

    assign pc_out_2 = PC_reg;
    assign pc_out = PC_reg;


endmodule
