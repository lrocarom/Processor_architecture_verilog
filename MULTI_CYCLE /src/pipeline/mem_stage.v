module memory_stage(


    input          clk,
    input          reset,

    //signals from EX stage
    input  [31:0]  alu_result_in,           //address from ALU
    input  [31:0]  write_data_in,           //data to store in memory

    input is_load_in,                       //control signal
    input is_store_in,                      //control signal
    input is_write_in,                      //control signal 

    //signals MEM/WB

    output [31:0]  wb_data_out              //data read from memory
    //output [4:0]   rd_out,                //register to write back to
    //output         is_write_out             
);


wire [31:0] read_data_out;


data_memory data_mem (
    .clk                (clk),
    .reset              (reset),
    .address            (alu_result_in),
    .data_memory_in     (write_data_in),
    .store_instruction  (is_store_in),
    .data_memory_out    (read_data_out)
);
    

//decide what to write back to register file
assign wb_data_out = (is_load_in) ? read_data_out : alu_result_in; 

//might just have it in mem register and not here 
//assign rd_out = rd_in;
//assign is_write_out = is_write_in;











endmodule