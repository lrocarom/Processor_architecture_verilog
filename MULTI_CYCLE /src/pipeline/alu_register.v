module alu_register(
    input       clk,
    input       reset,
    
    input wire  is_write_in,
    input wire  is_load_in,
    input wire  is_store_in,
    //input wire  is_branch_in,

    input wire  [31:0] alu_result_in,
    input wire  [4:0] register_d_in,

    output reg  is_write_out,
    output reg  is_load_out,
    output reg  is_store_out,
    //output reg  is_branch_out,

    output reg  [31:0] alu_result_out,
    output reg  [4:0] register_d_out

);



always @(posedge clk or posedge reset) begin
    if (reset) begin
        is_write_out    <=  1'b0;
        is_load_out     <=  1'b0;
        is_store_out    <=  1'b0;
        //is_branch_out   <=  1'b0;
        alu_result_out  <=  32'b0;

    end else begin
        is_write_out    <= is_write_in;
        is_load_out     <= is_load_in;
        is_store_out    <= is_store_in;
        //is_branch_out   <= is_branch_in;
        alu_result_out  <= alu_result_in;
        register_d_out  <= register_d_in;

    end

end












endmodule