module store_buffer (
    input  wire        clk,
    input  wire        reset,

    // Store request
    input  wire        store_op,
    input  wire [31:0] store_addr,
    input  wire [31:0] store_data,
    input  wire [3:0]  store_byte_en,
    // Load bypass lookup
    input  wire        lookup_valid,
    input  wire [31:0] lookup_addr,
    input  wire [1:0]  lookup_byte_off,
    input  wire        lookup_word,
    output reg         lookup_hit,
    output reg  [31:0] lookup_data,
    output reg  [3:0]  lookup_byte_en,

    // Memory interface
    input  wire        mem_ready,
    output reg         mem_valid,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_data,
    output reg  [3:0]  mem_byte_en,

    // Pipeline control
    output reg         stall_pipeline,

    // Status
    output reg         buffer_full
);

// 4-entry store buffer
reg [31:0] buffer_addr     [3:0];
reg [31:0] buffer_data     [3:0];
reg [3:0]  buffer_byte_en  [3:0];
reg        buffer_valid    [3:0];

integer i;
integer j;
reg accepted;
reg [1:0] drain_idx;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        mem_valid      <= 1'b0;
        mem_addr       <= 32'b0;
        mem_data       <= 32'b0;
        mem_byte_en    <= 4'b0;
        buffer_full    <= 1'b0;
        stall_pipeline <= 1'b0;
        for (i = 0; i < 4; i = i + 1)
            buffer_valid[i] <= 1'b0;
    end else begin
        // -------------------------------------------------
        // 1) Buffer full calculation (SIEMPRE)
        // -------------------------------------------------
        buffer_full <= buffer_valid[0] &
                       buffer_valid[1] &
                       buffer_valid[2] &
                       buffer_valid[3];

        // -------------------------------------------------
        // 2) Stall logic
        // -------------------------------------------------
        stall_pipeline <= store_op && buffer_full;

        // -------------------------------------------------
        // 3) Accept store (only if not stalled)
        // -------------------------------------------------
        accepted = 1'b0;
        if (store_op && !buffer_full) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (!buffer_valid[i] && !accepted) begin
                    buffer_addr[i]    <= store_addr;
                    buffer_data[i]    <= store_data;
                    buffer_byte_en[i] <= store_byte_en;
                    buffer_valid[i]   <= 1'b1;
                    accepted = 1'b1;
                end
            end
        end

        // -------------------------------------------------
        // 4) Drain store buffer to memory (selection is combinational)
        // -------------------------------------------------
        if (mem_ready && mem_valid)
            buffer_valid[drain_idx] <= 1'b0; // free entry
    end
end

// Combinational drain selection (oldest = lowest index)
always @(*) begin
    mem_valid = 1'b0;
    mem_addr = 32'b0;
    mem_data = 32'b0;
    mem_byte_en = 4'b0;
    drain_idx = 2'd0;
    for (j = 0; j < 4; j = j + 1) begin
        if (buffer_valid[j] && !mem_valid) begin
            mem_valid = 1'b1;
            mem_addr = buffer_addr[j];
            mem_data = buffer_data[j];
            mem_byte_en = buffer_byte_en[j];
            drain_idx = j[1:0];
        end
    end
end

// Combinational lookup for load bypass (store-to-load forwarding)
always @(*) begin
    lookup_hit = 1'b0;
    lookup_data = 32'b0;
    lookup_byte_en = 4'b0000;
    if (lookup_valid) begin
        for (j = 0; j < 4; j = j + 1) begin
            if (buffer_valid[j] && (buffer_addr[j][31:2] == lookup_addr[31:2]) && !lookup_hit) begin
                if (lookup_word && (buffer_byte_en[j] == 4'b1111)) begin
                    lookup_hit = 1'b1;
                    lookup_data = buffer_data[j];
                    lookup_byte_en = buffer_byte_en[j];
                end else if (!lookup_word && buffer_byte_en[j][lookup_byte_off]) begin
                    lookup_hit = 1'b1;
                    lookup_data = buffer_data[j];
                    lookup_byte_en = buffer_byte_en[j];
                end
            end
        end
    end
end

endmodule
