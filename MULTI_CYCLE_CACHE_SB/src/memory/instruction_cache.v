module instruction_cache (
    input          clk,
    input          reset,

    // CPU Side
    input  [31:0]  pc,             // Address from PC
    output [31:0]  instruction,    // Instruction to CPU
    output         stall,          // Stall signal to Fetch Stage

    // Memory Side
    output reg     mem_read_en,    // Request to Instruction Memory
    output reg [31:0] mem_addr,    // Address to Instruction Memory
    input  [31:0]  mem_rdata,      // Data from Instruction Memory
    input          mem_ready       // Unused (assumed 1 for now)
);

    // Cache Parameters
    localparam LINE_COUNT       = 4;
    localparam LINE_COUNT_BITS  = 2;
    localparam WORD_OFFSET_BITS = 2;
    localparam TAG_BITS         = 32 - LINE_COUNT_BITS - 4; // 26 bits

    // Address Decomposition
    wire [1:0]  addr_word_offset = pc[3:2];
    wire [1:0]  addr_index       = pc[5:4];
    wire [25:0] addr_tag         = pc[31:6];

    // Storage
    reg [25:0]  tag_array   [0:3];
    reg         valid_array [0:3];
    reg [127:0] data_array  [0:3]; // 16 Bytes per line

    // Refill Buffer
    reg [127:0] refill_buf;
    reg [3:0]   miss_counter;
    wire [31:0] line_base_addr = { pc[31:4], 4'b0000 };

    // FSM States
    localparam STATE_IDLE      = 1'b0;
    localparam STATE_MISS_WAIT = 1'b1;
    reg state;

    // Hit Logic
    wire valid = valid_array[addr_index];
    wire [25:0] tag = tag_array[addr_index];
    wire hit = valid && (tag == addr_tag);

    // Data Selection (Mux)
    reg [31:0] cache_word;
    always @(*) begin
        case (addr_word_offset)
            2'b00: cache_word = data_array[addr_index][31:0];
            2'b01: cache_word = data_array[addr_index][63:32];
            2'b10: cache_word = data_array[addr_index][95:64];
            2'b11: cache_word = data_array[addr_index][127:96];
        endcase
    end

    // Output Generation
    // If Hit: return cached instruction. If Miss: return 0 (bubble) or wait.
    assign instruction = (hit) ? cache_word : 32'h00000013; // NOP (ADDI x0, x0, 0) on miss
    
    // Stall Logic: Stall if we miss!
    assign stall = (state == STATE_MISS_WAIT) || (!hit);

    // =====================================================
    // FSM (Read Only Refill)
    // =====================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            state <= STATE_IDLE;
            miss_counter <= 0;
            valid_array[0] <= 0; valid_array[1] <= 0;
            valid_array[2] <= 0; valid_array[3] <= 0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (!hit) begin
                        state <= STATE_MISS_WAIT;
                        miss_counter <= 0;
                        refill_buf <= 0;
                    end
                end

                STATE_MISS_WAIT: begin
                    // 1. Capture Data from Memory (Cycles 5-8)
                    // Adjusted timing for async memory (Request 5..8, Latch 5..8)
                    if (miss_counter == 4'd5) refill_buf[31:0]   <= mem_rdata;
                    if (miss_counter == 4'd6) refill_buf[63:32]  <= mem_rdata;
                    if (miss_counter == 4'd7) refill_buf[95:64]  <= mem_rdata;
                    if (miss_counter == 4'd8) refill_buf[127:96] <= mem_rdata;

                    // 2. Install Line (Cycle 9)
                    if (miss_counter == 4'd9) begin
                        data_array[addr_index]  <= refill_buf;
                        tag_array[addr_index]   <= addr_tag;
                        valid_array[addr_index] <= 1'b1;
                        
                        state <= STATE_IDLE;
                        miss_counter <= 0;
                    end else begin
                        miss_counter <= miss_counter + 1;
                    end
                end
            endcase
        end
    end

    // =====================================================
    // Memory Interface Logic
    // =====================================================
    always @(*) begin
        mem_read_en = 0;
        mem_addr = 0;

        if (state == STATE_MISS_WAIT) begin
            if (miss_counter >= 5 && miss_counter <= 8) begin
                mem_read_en = 1;
                // Calculate address for the specific word in the burst
                mem_addr = line_base_addr + ((miss_counter - 5) << 2);
            end
        end
    end

endmodule