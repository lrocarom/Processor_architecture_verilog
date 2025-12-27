module if_register(
    input          clk,
    input          reset,
    input [31:0]  pc_in,                 // Current PC
    input [31:0]  instruction_in,         // Current PC
    input in_stall,
    output reg [31:0]  pc_out,                 // Current PC
    output reg [31:0]  instruction_out         // Current PC
);


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_out          <= 32'b0;
            instruction_out <= 32'b0;
        end 
        else if (in_stall) begin
            pc_out          <= pc_out;
            instruction_out <= instruction_out;
        end 
        else begin
            pc_out          <= pc_in;
            instruction_out <= instruction_in;
        end
    end


endmodule