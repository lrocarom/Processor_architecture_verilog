module m_fetch(
    input          clk,
    input  [12:0]  branch_target, 
    input          branch,        
    input  [31:0]  jump_target,
    input          jump,           
    input          reset,
    input          panic, 

    // NEW INPUT: Stall request from Hazard Unit or Memory Stage
    input          external_stall,
    
    // Outputs
    output [31:0]  pc_out,        
    output [31:0]  instruction_out,
    output         stall_fetch     // NEW: Tells the CPU to freeze while refilling
);

    wire [31:0] current_pc;
    wire        icache_stall;

    // Combined Stall: Stall PC if Cache is busy OR if CPU is stalled
    wire        final_pc_stall = icache_stall | external_stall;
    
    // Wires between Cache and Memory
    wire        mem_read_en;
    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;

    // 1. Program Counter
    m_program_counter pc (   
        .clk (clk),
        .branch_target (branch_target), 
        .branch (branch),
        .jump_target(jump_target),
        .jump (jump),   
        .reset (reset),
        .panic (panic),
        .stall (final_pc_stall),  // NEW: Freeze PC when cache is busy
        .pc_out (current_pc)
        // NOTE: You should eventually add a .stall(stall_fetch) input here 
        // so the PC stops counting when the cache is busy!
    );

    // 2. The Instruction Cache (The New Middleman)
    instruction_cache icache (
        .clk(clk),
        .reset(reset),
        
        // CPU Side
        .pc(current_pc),              // Cache asks: "What address?"
        .instruction(instruction_out), // Cache answers: "Here is the instruction"
        .stall(icache_stall),         // Cache says: "Wait, I'm fetching from RAM"
        
        // Memory Side
        .mem_read_en(mem_read_en),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_ready(1'b1)
    );

    // 3. The Backing Memory
    // Notice: It listens to 'mem_addr' (from Cache), NOT 'current_pc'
    instruction_memory memory_ins ( 
        .address (mem_addr),         // Address requested by Cache
        .instruction_out (mem_rdata) // Data returned to Cache
    );

    assign pc_out = current_pc;
    assign stall_fetch = icache_stall; 

endmodule