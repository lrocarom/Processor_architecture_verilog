
module data_memory(inout clk,
                   input  store_instruction,
                   input  [31:0]  adress,
                   input  [31:0]  data_memory_in,
                   output [31:0]  data_memory_out);
    
    reg [31:0] data_mem [0:4096];

    initial begin
        data_mem[0] = 32'h00004430;
        data_mem[1] = 32'h00008610;
        data_mem[2] = 32'h00004430;
        data_mem[3] = 32'h00000193;
    end

    assign data_memory_out = data_mem[adress[6:0]];

    always @(posedge clk) begin
    if(store_instruction)
        data_mem[adress[6:0]] <= data_memory_in;
    end


endmodule