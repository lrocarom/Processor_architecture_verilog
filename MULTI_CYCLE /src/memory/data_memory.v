
module data_memory(input clk,
                   input  reset,
                   input  store_instruction,
                   input  [31:0]  address,
                   input  [31:0]  data_memory_in,
                   output [31:0]  data_memory_out);
    
    reg [31:0] data_mem [0:4096];

    initial begin
        data_mem[0] = 32'h00004430;
        data_mem[1] = 32'h00008610;
        data_mem[2] = 32'h00004430;
        data_mem[3] = 32'h00000193;
        data_mem[4] = 32'h00001111;
        data_mem[5] = 32'h00004555;
        data_mem[6] = 32'h00000666;
    end

    assign data_memory_out = data_mem[address[6:0]];

    always @(posedge clk) begin

        if(store_instruction)
            data_mem[address[6:0]] <= data_memory_in;

        if(store_instruction)
            $display("STORING  VALUE %h and mem[%h]", data_memory_in,address[6:0]);


    end


endmodule