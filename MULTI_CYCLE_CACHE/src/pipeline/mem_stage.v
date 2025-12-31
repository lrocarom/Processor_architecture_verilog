module memory_stage(


    input           clk,
    input           reset,

    //signals from EX stage
    input  [31:0]   alu_result_in,           //address from ALU
    input  [31:0]   write_data_in,           //data to store in memory
    input  [4:0]    rd_in,                   //register to write back to

    input           is_load_in,                       //control signal
    input           is_store_in,                      //control signal
    input           is_write_in,                      //control signal 

    //signals MEM/WB

    output [31:0]   wb_data_out,              //data read from memory
    output [4:0]    rd_out,                     //register to write back to
    //output         is_write_out             
    output          stall_req         // 1 = Cache needs pipeline to freeze
);


// ------------------------------
// Wires between MEM stage and cache (CPU side of cache)
// ------------------------------
wire [31:0]     cache_rdata;
wire            cache_stall;   // not used yet, but will be important for stalling on miss
 // ------------------------------
// Wires between cache and memory (memory side of cache)
// ------------------------------
wire            mem_read_en;
wire            mem_write_en;
wire [31:0]     mem_addr;
wire [31:0]     mem_wdata;
wire [31:0]     mem_rdata;
wire            mem_ready;

// For now, assume memory is "always ready" in 1 cycle.
// Later, if you want to emulate longer latency, you can make this a counter/FSM.
assign          mem_ready = 1'b1;

// ==============================
//  Data Cache instance
// ==============================
data_cache dcache (
    .clk        (clk),
    .reset      (reset),
    // CPU side (from EX/MEM stage)
    .cpu_read_en    (is_load_in),       // 1 = load
    .cpu_write_en   (is_store_in),      // 1 = store
    .cpu_addr       (alu_result_in),    // byte address from ALU
    .cpu_wdata      (write_data_in),    // data to be written on store
    .cpu_rdata      (cache_rdata),      // data returned on load
    .cpu_stall      (cache_stall),      // 1 = stall pipeline (miss being served)
    // Memory side (to backing data_memory)
    .mem_read_en    (mem_read_en),      // request read from backing memory
    .mem_write_en   (mem_write_en),     // request write to backing memory
    .mem_addr       (mem_addr),         // address to backing memory
    .mem_wdata      (mem_wdata),        // data to backing memory
    .mem_rdata      (mem_rdata),        // data from backing memory
    .mem_ready      (mem_ready)         // 1 = memory completed operation
);


data_memory data_mem (
    .clk               (clk),
    .reset             (reset),
    .address           (mem_addr),
    .data_memory_in    (mem_wdata),
    .store_instruction (mem_write_en),
    .data_memory_out   (mem_rdata)
    );

    

//decide what to write back to register file
assign wb_data_out = (is_load_in) ? cache_rdata : alu_result_in; 
assign stall_req   = cache_stall;

//might just have it in mem register and not here 
assign rd_out = rd_in;
//assign is_write_out = is_write_in;




endmodule