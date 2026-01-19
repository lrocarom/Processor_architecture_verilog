module m_fetch(
    input          clk,
    input  [31:0]  branch_target, 
    input          branch,        
    input  [31:0]  jump_target,
    input          jump,           
    input          reset,
    input          panic, 
    input          exception,
    input  [31:0]  exception_target,
    input          vm_enable,
    input          itlb_write_en,
    input  [31:0]  itlb_write_va,
    input  [31:0]  itlb_write_pa,

    // NEW INPUT: Stall request from Hazard Unit or Memory Stage
    input          external_stall,
    
    // Outputs
    output [31:0]  pc_out,        
    output [31:0]  instruction_out,
    output         stall_fetch,     // NEW: Tells the CPU to freeze while refilling
    output         tlb_miss,
    output [31:0]  tlb_fault_addr
);

    wire [31:0] current_pc;
    wire        icache_stall;
    wire        itlb_hit;
    wire [31:0] itlb_pa;
    wire [31:0] pc_phys;

    // Combined Stall: Stall PC if Cache is busy OR if CPU is stalled
    wire        final_pc_stall = (icache_stall | external_stall) & ~exception;
    // Latch branch when fetch is stalled so it isn't lost
    reg         branch_pending;
    reg [31:0]  branch_target_pending;
    
    // Wires between Cache and Memory
    wire        mem_read_en;
    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;

    // 1. Program Counter
    wire branch_to_pc = branch_pending | branch;
    wire [31:0] branch_target_to_pc = branch_pending ? branch_target_pending : branch_target;

    m_program_counter pc (   
        .clk (clk),
        .branch_target (branch_target_to_pc), 
        .branch (branch_to_pc),
        .jump_target(jump_target),
        .jump (jump),   
        .reset (reset),
        .panic (panic),
        .exception (exception),
        .exception_target (exception_target),
        .stall (final_pc_stall),  // NEW: Freeze PC when cache is busy
        .pc_out (current_pc)
        // NOTE: You should eventually add a .stall(stall_fetch) input here 
        // so the PC stops counting when the cache is busy!
    );

    // 2. The Instruction TLB (iTLB)
    simple_tlb itlb (
        .clk(clk),
        .reset(reset),
        .lookup_va(current_pc),
        .lookup_valid(1'b1),
        .lookup_hit(itlb_hit),
        .lookup_pa(itlb_pa),
        .write_en(itlb_write_en),
        .write_va(itlb_write_va),
        .write_pa(itlb_write_pa)
    );

    assign pc_phys = (vm_enable && itlb_hit) ? itlb_pa : current_pc;
    assign tlb_miss = vm_enable && !itlb_hit;
    assign tlb_fault_addr = current_pc;

    // 3. The Instruction Cache (The New Middleman)
    instruction_cache icache (
        .clk(clk),
        .reset(reset),
        
        // CPU Side
        .pc(pc_phys),                 // Cache asks: "What address?"
        .instruction(instruction_out), // Cache answers: "Here is the instruction"
        .stall(icache_stall),         // Cache says: "Wait, I'm fetching from RAM"
        
        // Memory Side
        .mem_read_en(mem_read_en),
        .mem_addr(mem_addr),
        .mem_rdata(mem_rdata),
        .mem_ready(1'b1)
    );

    // 4. The Backing Memory
    // Notice: It listens to 'mem_addr' (from Cache), NOT 'current_pc'
    instruction_memory memory_ins ( 
        .address (mem_addr),         // Address requested by Cache
        .instruction_out (mem_rdata) // Data returned to Cache
    );

    always @(posedge clk or posedge reset) begin
        if (reset || exception) begin
            branch_pending <= 1'b0;
            branch_target_pending <= 32'b0;
        end else if (branch && final_pc_stall) begin
            branch_pending <= 1'b1;
            branch_target_pending <= branch_target;
        end else if (!final_pc_stall) begin
            branch_pending <= 1'b0;
        end
    end

    assign pc_out = current_pc;
    assign stall_fetch = icache_stall | tlb_miss; 

endmodule