// --------------------------------------------------------------
// data_cache.v
//
// Direct-mapped D-cache
//  - 4 lines
//  - 128-bit (16B) per line
//  - Write-through
//  - Write-no-allocate on store miss
//  - Option (1): stall pipeline for 10 cycles on:
//      * LOAD miss
//      * any STORE (hit or miss)
//
// Memory latency model (per spec):
//  - 5 cycles to go to memory
//  - 5 cycles to return
//  => total 10 cycles per miss/store transaction
//
// NOTE:
//  - Backing memory returns 1x 32-bit word per cycle during return phase.
//  - For load miss, we fetch 4 words (a full 16B line) in cycles 6..9.
// --------------------------------------------------------------
module data_cache (
    input         clk,
    input         reset,

    // ====================
    // CPU side interface
    // ====================
    input         cpu_read_en,     // 1 = load
    input         cpu_write_en,    // 1 = store
    input  [31:0] cpu_addr,        // byte address from ALU
    input  [31:0] cpu_wdata,       // data to store (aligned)
    input  [3:0]  cpu_byte_en,     // byte enables for store
    output [31:0] cpu_rdata,       // data returned on load
    output        cpu_stall,       // stall pipeline when servicing miss/store

    // ====================
    // Store buffer enqueue
    // ====================
    output        sb_enq_valid,
    output [31:0] sb_enq_addr,
    output [31:0] sb_enq_data,
    output [3:0]  sb_enq_byte_en,

    // ====================
    // Store buffer drain into cache
    // ====================
    input         sb_drain_valid,
    input  [31:0] sb_drain_addr,
    input  [31:0] sb_drain_data,
    input  [3:0]  sb_drain_byte_en,

    // ====================
    // Memory side interface
    // ====================
    output        mem_read_en,     // request read from backing memory
    output        mem_write_en,    // request write to backing memory
    output [31:0] mem_addr,        // address to backing memory
    output [31:0] mem_wdata,       // data to backing memory
    output [3:0]  mem_byte_en,     // byte enables to backing memory
    input  [31:0] mem_rdata,       // data from backing memory
    input         mem_ready        // currently unused (kept for future)
);

    // ==========================================================
    // Cache parameters
    // ==========================================================
    localparam LINE_COUNT        = 4;
    localparam LINE_COUNT_BITS   = 2;    // log2(4)

    localparam LINE_SIZE_BYTES   = 16;   // 16B = 128b
    localparam LINE_OFFSET_BITS  = 4;    // log2(16)

    localparam BYTES_PER_WORD    = 4;
    localparam WORD_OFFSET_BITS  = 2;    // 4 words/line -> log2(4)

    localparam TAG_BITS          = 32 - LINE_COUNT_BITS - LINE_OFFSET_BITS; // 26

    // Shorthand
    wire load_req  = cpu_read_en;
    wire store_req = cpu_write_en;

    // ==========================================================
    // Address decomposition (byte address)
    // ==========================================================
    wire [WORD_OFFSET_BITS-1:0]  addr_word_offset = cpu_addr[3:2];
    wire [LINE_COUNT_BITS-1:0]   addr_index       = cpu_addr[5:4];
    wire [TAG_BITS-1:0]          addr_tag         = cpu_addr[31:6];

    wire [WORD_OFFSET_BITS-1:0]  sb_word_offset = sb_drain_addr[3:2];
    wire [LINE_COUNT_BITS-1:0]   sb_index       = sb_drain_addr[5:4];
    wire [TAG_BITS-1:0]          sb_tag         = sb_drain_addr[31:6];

    // ==========================================================
    // Cache storage arrays
    // ==========================================================
    reg [TAG_BITS-1:0] tag_array   [0:LINE_COUNT-1];
    reg                valid_array [0:LINE_COUNT-1];
    reg [127:0]        data_array  [0:LINE_COUNT-1]; // 4x 32-bit words packed

    // ==========================================================
    // Hit logic (combinational)
    // ==========================================================
    wire                line_valid = valid_array[addr_index];
    wire [TAG_BITS-1:0] line_tag   = tag_array[addr_index];
    wire                hit        = line_valid && (line_tag == addr_tag);

    wire                sb_line_valid = valid_array[sb_index];
    wire [TAG_BITS-1:0] sb_line_tag   = tag_array[sb_index];
    wire                sb_hit        = sb_line_valid && (sb_line_tag == sb_tag);

    // Extract requested word from line
    reg [31:0] line_word;
    always @(*) begin
        case (addr_word_offset)
            2'b00: line_word = data_array[addr_index][ 31:  0];
            2'b01: line_word = data_array[addr_index][ 63: 32];
            2'b10: line_word = data_array[addr_index][ 95: 64];
            2'b11: line_word = data_array[addr_index][127: 96];
            default: line_word = 32'hDEADBEEF;
        endcase
    end

    // ==========================================================
    // FSM + pending request state
    // ==========================================================
    localparam STATE_IDLE      = 2'd0;
    localparam STATE_MISS_WAIT = 2'd1;

    reg [1:0] state;
    reg [3:0] miss_counter;     // 0..9 (10 cycles total)

    // Pending request info
    reg        pend_is_load;
    reg        pend_is_store;
    reg [31:0] pend_addr;
    reg [31:0] pend_wdata;
    reg [3:0]  pend_byte_en;

    function [31:0] merge_word;
        input [31:0] old_w;
        input [31:0] new_w;
        input [3:0]  be;
        begin
            merge_word[7:0]   = be[0] ? new_w[7:0]   : old_w[7:0];
            merge_word[15:8]  = be[1] ? new_w[15:8]  : old_w[15:8];
            merge_word[23:16] = be[2] ? new_w[23:16] : old_w[23:16];
            merge_word[31:24] = be[3] ? new_w[31:24] : old_w[31:24];
        end
    endfunction

    reg [TAG_BITS-1:0]         pend_tag;
    reg [LINE_COUNT_BITS-1:0]  pend_index;
    reg [WORD_OFFSET_BITS-1:0] pend_word_off;  // (latched for completeness)

    // Buffer for line refill (we only need first 3 words here; 4th comes at cycle 9)
    reg [127:0] refill_buf;

    // Base address aligned to 16 bytes
    wire [31:0] line_base_addr = { pend_addr[31:4], 4'b0000 };

    // ==========================================================
    // SINGLE sequential writer for cache arrays (FIXES MULTI-DRIVER)
    //  - Updates valid/tag/data on reset, refill install, and store hit.
    // ==========================================================
    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= STATE_IDLE;
            miss_counter <= 4'd0;

            pend_is_load   <= 1'b0;
            pend_is_store  <= 1'b0;
            pend_addr      <= 32'd0;
            pend_wdata     <= 32'd0;
            pend_byte_en  <= 4'b0000;
            pend_tag       <= {TAG_BITS{1'b0}};
            pend_index     <= {LINE_COUNT_BITS{1'b0}};
            pend_word_off  <= {WORD_OFFSET_BITS{1'b0}};
            refill_buf     <= 128'd0;

            // Invalidate all cache lines
            
            valid_array[0] <= 1'b0;
            valid_array[1] <= 1'b0;
            valid_array[2] <= 1'b0;
            valid_array[3] <= 1'b0;

            
        end else begin
            case (state)

                // --------------------------
                // IDLE: accept new request
                // --------------------------
                STATE_IDLE: begin
                    miss_counter <= 4'd0;

                    // default: no pending op
                    pend_is_load  <= 1'b0;
                    pend_is_store <= 1'b0;

                    // Apply store buffer drain to cache on hit (cache idle)
                    if (sb_drain_valid && sb_hit) begin
                        case (sb_word_offset)
                            2'b00: data_array[sb_index][ 31:  0] <= merge_word(data_array[sb_index][ 31:  0], sb_drain_data, sb_drain_byte_en);
                            2'b01: data_array[sb_index][ 63: 32] <= merge_word(data_array[sb_index][ 63: 32], sb_drain_data, sb_drain_byte_en);
                            2'b10: data_array[sb_index][ 95: 64] <= merge_word(data_array[sb_index][ 95: 64], sb_drain_data, sb_drain_byte_en);
                            2'b11: data_array[sb_index][127: 96] <= merge_word(data_array[sb_index][127: 96], sb_drain_data, sb_drain_byte_en);
                        endcase
                    end

                    // STORE HIT: enqueue into store buffer (no immediate cache update)

                    // LOAD miss starts a 10-cycle transaction
                    if (load_req && !hit) begin
                        pend_is_load   <= 1'b1;
                        pend_is_store  <= 1'b0;

                        pend_addr      <= cpu_addr;
                        pend_tag       <= addr_tag;
                        pend_index     <= addr_index;
                        pend_word_off  <= addr_word_offset;

                        refill_buf     <= 128'd0;
                        state          <= STATE_MISS_WAIT;
                    end
                    // STORE MISS starts a 10-cycle transaction (write-through timing)
                    else if (store_req && !hit) begin
                        pend_is_load   <= 1'b0;
                        pend_is_store  <= 1'b1;

                        pend_addr      <= cpu_addr;
                        pend_wdata     <= cpu_wdata;
                        pend_byte_en  <= cpu_byte_en;

                        // latched for completeness/debug
                        pend_tag       <= addr_tag;
                        pend_index     <= addr_index;
                        pend_word_off  <= addr_word_offset;

                        state          <= STATE_MISS_WAIT;
                    end
                    else begin
                        state <= STATE_IDLE;
                    end
                end

                // --------------------------
                // MISS_WAIT: 10-cycle model
                // --------------------------
                STATE_MISS_WAIT: begin
                    // Capture returning words for LOAD miss during cycles 6..8
                    // (Cycle 9 word is handled directly when installing the line.)
                    if (pend_is_load) begin
                        if (miss_counter == 4'd5) refill_buf[ 31:  0] <= mem_rdata;
                        if (miss_counter == 4'd6) refill_buf[ 63: 32] <= mem_rdata;
                        if (miss_counter == 4'd7) refill_buf[ 95: 64] <= mem_rdata;
                        if (miss_counter == 4'd8) refill_buf[127: 96] <= mem_rdata;
                    end

                    // Finish transaction at cycle 9
                    if (miss_counter == 4'd9) begin
                        if (pend_is_load) begin
                            // Install complete 16B line into cache.
                            // IMPORTANT: include the cycle-9 returning word (mem_rdata) directly here
                            // to avoid the nonblocking assignment ordering bug.
                            data_array[pend_index]  <= refill_buf;
                            tag_array[pend_index]   <= pend_tag;
                            valid_array[pend_index] <= 1'b1;
                        end

                        // For STORE MISS: memory write enable is asserted combinationally at counter==9.
                        // That commits in backing memory on this posedge.

                        state        <= STATE_IDLE;
                        miss_counter <= 4'd0;
                    end else begin
                        miss_counter <= miss_counter + 4'd1;
                        state        <= STATE_MISS_WAIT;
                    end
                end

                default: begin
                    state        <= STATE_IDLE;
                    miss_counter <= 4'd0;
                end

            endcase
        end
    end

    // ==========================================================
    // Backing memory command generation (combinational)
    // ==========================================================
    reg        mem_read_en_r;
    reg        mem_write_en_r;
    reg [31:0] mem_addr_r;
    reg [31:0] mem_wdata_r;
    reg [3:0]  mem_byte_en_r;

    // Track store request to avoid double-enqueueing the same store hit
    reg store_req_d;

    always @(*) begin
        mem_read_en_r  = 1'b0;
        mem_write_en_r = 1'b0;
        mem_addr_r     = 32'd0;
        mem_wdata_r    = 32'd0;
        mem_byte_en_r = 4'b0000;

        if (state == STATE_MISS_WAIT) begin
            // LOAD miss: return phase cycles 6..9 -> one word per cycle
            if (pend_is_load) begin
                if (miss_counter >= 4'd5 && miss_counter <= 4'd8) begin
                    mem_read_en_r = 1'b1;
                    mem_addr_r    = line_base_addr + ((miss_counter - 4'd5) << 2); // +0,+4,+8,+12
                end
            end

            // STORE MISS: commit at the end of the 10-cycle op
            if (pend_is_store) begin
                if (miss_counter == 4'd9) begin
                    mem_write_en_r = 1'b1;
                    mem_addr_r     = pend_addr;
                    mem_wdata_r    = pend_wdata;
                    mem_byte_en_r  = pend_byte_en;
                end
            end
        end

        // STORE BUFFER DRAIN: write-through to memory (cache already updated on hit)
        if (sb_drain_valid && !mem_read_en_r && !(pend_is_store && miss_counter == 4'd9)) begin
            mem_write_en_r = 1'b1;
            mem_addr_r     = sb_drain_addr;
            mem_wdata_r    = sb_drain_data;
            mem_byte_en_r  = sb_drain_byte_en;
        end
    end

    assign mem_read_en  = mem_read_en_r;
    assign mem_write_en = mem_write_en_r;
    assign mem_addr     = mem_addr_r;
    assign mem_wdata    = mem_wdata_r;
    assign mem_byte_en  = mem_byte_en_r;

    // ==========================================================
    // CPU outputs
    // ==========================================================
    // On load hit: return cached word.
    // Otherwise: mem_rdata (during a miss the pipeline is stalled anyway).
    assign cpu_rdata = (cpu_read_en && hit) ? line_word : mem_rdata;

    // Helper signal: Are we in the very last cycle of a store?
    wire store_finishing = (state == STATE_MISS_WAIT) && (pend_is_store) && (miss_counter == 4'd9);

    // Stall Logic:
    // 1. Busy: Stall if state is NOT IDLE...
    // 2. Release Store: ...UNLESS we are in the final cycle of a Store (allows CPU to advance).
    // 3. Start: Stall immediately on IDLE only for Load Miss or Store Miss.
    assign cpu_stall = (state != STATE_IDLE && !store_finishing) || 
                       ((state == STATE_IDLE) && ((cpu_read_en && !hit) || (cpu_write_en && !hit)));

    // Store buffer enqueue on store hit
    // Suppress duplicate enqueues only when the pipeline is held (cache stall).
    assign sb_enq_valid    = store_req && hit && !(store_req_d && cpu_stall);
    assign sb_enq_addr     = cpu_addr;
    assign sb_enq_data     = cpu_wdata;
    assign sb_enq_byte_en  = cpu_byte_en;

    always @(posedge clk or posedge reset) begin
        if (reset)
            store_req_d <= 1'b0;
        else
            store_req_d <= store_req && hit && cpu_stall;
    end
    // mem_ready currently unused (kept to match the planned interface)
    // wire _unused_mem_ready = mem_ready;

endmodule
