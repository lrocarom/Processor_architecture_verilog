module m_program_counter(
    input          clk,
    input  [12:0]  branch_target, // Address to jump to
    input          branch,        // Branch control
    input  [31:0]  jump_target,
    input          jump,           // Jump control
    input          reset,
    input          panic, 
    input          stall,          // NEW: Freeze PC when stall is HIGH
    output wire [31:0]  pc_out         // Current PC
);
    wire [31:0]  pc_out_2;
    // Registro para PC
    reg [31:0] PC_reg;
    
    initial begin
        PC_reg = 0;
    end



    always @(posedge clk or posedge reset) begin

        if(reset)
            PC_reg <= 0;
        else if (stall)
            PC_reg <= PC_reg; // Hold the value
        else if (branch)
            PC_reg <= PC_reg + {19'b0, branch_target, 2'b00};
        else if (jump)
            PC_reg <=  {jump_target, 2'b00};
        else if (panic)
            PC_reg <=  32'hffffff0;
        else
            PC_reg <= PC_reg + 4;
    end

    assign pc_out_2 = PC_reg;
    assign pc_out = PC_reg;


endmodule
