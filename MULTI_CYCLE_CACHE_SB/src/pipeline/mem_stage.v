module memory_stage(


    input           clk,
    input           reset,

    //signals from EX stage
    input  [31:0]   alu_result_in,           //address from ALU
    input  [31:0]   write_data_in,           //data to store in memory
    input  [31:0]   pc_in,                   // PC of instruction in MEM
    input  [4:0]    rd_in,                   //register to write back to

    input           is_load_in,                       //control signal
    input           is_store_in,                      //control signal
    input           is_write_in,                      //control signal 
    input  [1:0]    mem_size_in,                      // 2'b00=byte, 2'b10=word
    input           load_unsigned_in,                 // 1=zero-extend for byte loads
    input           mov_rm_in,                        // MOVRM instruction
    input           tlbwrite_in,                      // TLBWRITE instruction
    input           iret_in,                          // IRET instruction
    input  [31:0]   rm_value_in,                      // value from rmX (for MOVRM)
    input           vm_enable,

    //signals MEM/WB

    output [31:0]   wb_data_out,              //data read from memory
    output [4:0]    rd_out,                     //register to write back to
    //output         is_write_out             
    output          stall_req,        // 1 = Cache needs pipeline to freeze
    output          kill_wb,
    output          tlb_miss,
    output [31:0]   tlb_fault_addr,
    output [31:0]   tlb_fault_pc,
    output          itlb_write_en,
    output [31:0]   itlb_write_va,
    output [31:0]   itlb_write_pa,
    output          tlbwrite_priv_fault,
    output          iret_taken,
    output          iret_priv_fault
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
wire [3:0]      mem_byte_en;
wire [31:0]     mem_rdata;
wire            mem_ready;

// For now, assume memory is "always ready" in 1 cycle.
// Later, if you want to emulate longer latency, you can make this a counter/FSM.
assign          mem_ready = 1'b1;

// ==============================
//  Data TLB (dTLB)
// ==============================
wire        dtlb_hit;
wire [31:0] dtlb_pa;
wire        dtlb_lookup_valid = (is_load_in || is_store_in);

wire tlbwrite_allowed = tlbwrite_in && !vm_enable;
assign tlbwrite_priv_fault = tlbwrite_in && vm_enable;
assign iret_priv_fault = iret_in && vm_enable;
assign iret_taken = iret_in && !vm_enable;

simple_tlb dtlb (
    .clk(clk),
    .reset(reset),
    .lookup_va(alu_result_in),
    .lookup_valid(dtlb_lookup_valid),
    .lookup_hit(dtlb_hit),
    .lookup_pa(dtlb_pa),
    .write_en(tlbwrite_allowed),
    .write_va(alu_result_in),
    .write_pa(write_data_in)
);

wire [31:0] phys_addr = (vm_enable && dtlb_hit) ? dtlb_pa : alu_result_in;
assign tlb_miss = vm_enable && dtlb_lookup_valid && !dtlb_hit;
assign tlb_fault_addr = alu_result_in;
assign tlb_fault_pc = pc_in;

assign itlb_write_en = tlbwrite_allowed;
assign itlb_write_va = alu_result_in;
assign itlb_write_pa = write_data_in;

// ==============================
//  Data Cache instance
// ==============================
wire [1:0] addr_byte_off = alu_result_in[1:0];
wire [3:0] store_byte_en = (mem_size_in == 2'b00) ? (4'b0001 << addr_byte_off) : 4'b1111;
wire [31:0] store_wdata_aligned = (mem_size_in == 2'b00) ?
                                  ({24'b0, write_data_in[7:0]} << (addr_byte_off * 8)) :
                                  write_data_in;

data_cache dcache (
    .clk        (clk),
    .reset      (reset),
    // CPU side (from EX/MEM stage)
    .cpu_read_en    (is_load_in && !tlb_miss),       // 1 = load
    .cpu_write_en   (is_store_in && !tlb_miss),      // 1 = store
    .cpu_addr       (phys_addr),    // byte address from ALU (translated)
    .cpu_wdata      (store_wdata_aligned),    // data to be written on store
    .cpu_byte_en    (store_byte_en),
    .cpu_rdata      (cache_rdata),      // data returned on load
    .cpu_stall      (cache_stall),      // 1 = stall pipeline (miss being served)
    // Store buffer enqueue (store hit)
    .sb_enq_valid    (sb_enq_valid),
    .sb_enq_addr     (sb_enq_addr),
    .sb_enq_data     (sb_enq_data),
    .sb_enq_byte_en  (sb_enq_byte_en),
    // Store buffer drain into cache
    .sb_drain_valid  (sb_mem_valid),
    .sb_drain_addr   (sb_mem_addr),
    .sb_drain_data   (sb_mem_data),
    .sb_drain_byte_en(sb_mem_byte_en),
    // Memory side (to backing data_memory)
    .mem_read_en    (mem_read_en),      // request read from backing memory
    .mem_write_en   (mem_write_en),     // request write to backing memory
    .mem_addr       (mem_addr),         // address to backing memory
    .mem_wdata      (mem_wdata),        // data to backing memory
    .mem_byte_en    (mem_byte_en),
    .mem_rdata      (mem_rdata),        // data from backing memory
    .mem_ready      (mem_ready)         // 1 = memory completed operation
);


// Store buffer between cache and backing memory
wire        sb_mem_valid;
wire [31:0] sb_mem_addr;
wire [31:0] sb_mem_data;
wire [3:0]  sb_mem_byte_en;
wire        sb_enq_valid;
wire [31:0] sb_enq_addr;
wire [31:0] sb_enq_data;
wire [3:0]  sb_enq_byte_en;
wire        sb_lookup_hit;
wire [31:0] sb_lookup_data;
wire [3:0]  sb_lookup_be;
wire        sb_stall;
wire        sb_ready = ~cache_stall; // pause draining while cache is busy

store_buffer sb(
    .clk(clk),
    .reset(reset),
    .store_op(sb_enq_valid),
    .store_addr(sb_enq_addr),
    .store_data(sb_enq_data),
    .store_byte_en(sb_enq_byte_en),
    .lookup_valid(is_load_in && !tlb_miss),
    .lookup_addr(phys_addr),
    .lookup_byte_off(addr_byte_off),
    .lookup_word(mem_size_in == 2'b10),
    .lookup_hit(sb_lookup_hit),
    .lookup_data(sb_lookup_data),
    .lookup_byte_en(sb_lookup_be),
    .mem_ready(sb_ready),
    .mem_valid(sb_mem_valid),
    .mem_addr(sb_mem_addr),
    .mem_data(sb_mem_data),
    .mem_byte_en(sb_mem_byte_en),
    .stall_pipeline(sb_stall),
    .buffer_full()
);

data_memory data_mem (
    .clk               (clk),
    .reset             (reset),
    .address           (mem_addr),
    .data_memory_in    (mem_wdata),
    .byte_en           (mem_byte_en),
    .store_instruction (mem_write_en),
    .data_memory_out   (mem_rdata)
    );

    

//decide what to write back to register file
wire [7:0] load_byte = cache_rdata >> (addr_byte_off * 8);
wire [7:0] sb_load_byte = sb_lookup_data >> (addr_byte_off * 8);
wire sb_byte_match = sb_lookup_hit && sb_lookup_be[addr_byte_off];
wire sb_word_match = sb_lookup_hit && (sb_lookup_be == 4'b1111);

// Store-to-load bypass: prefer buffered store data when it covers the requested bytes.
// For word loads, only bypass if the buffered store writes all 4 bytes.
// For byte loads, bypass if the corresponding byte is valid.
wire [31:0] load_data_bypassed = (mem_size_in == 2'b00) ?
                                 (sb_byte_match ? {24'b0, sb_load_byte} : cache_rdata) :
                                 (sb_word_match ? sb_lookup_data : cache_rdata);

wire [7:0] final_load_byte = load_data_bypassed >> (addr_byte_off * 8);
wire [31:0] load_data = (mem_size_in == 2'b00) ?
                        (load_unsigned_in ? {24'b0, final_load_byte} : {{24{final_load_byte[7]}}, final_load_byte}) :
                        load_data_bypassed;

assign wb_data_out = mov_rm_in ? rm_value_in :
                     (is_load_in ? load_data : alu_result_in); 
assign stall_req   = cache_stall | sb_stall;
assign kill_wb     = tlb_miss | tlbwrite_priv_fault | iret_priv_fault;

//might just have it in mem register and not here 
assign rd_out = rd_in;
//assign is_write_out = is_write_in;




endmodule