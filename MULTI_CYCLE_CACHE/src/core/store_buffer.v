module store_buffer (
    input  wire        clk,
    input  wire        reset,

    // Store request
    input  wire        store_op,
    input  wire [31:0] store_addr,
    input  wire [31:0] store_data,

    // Memory interface
    input  wire        mem_ready,
    output reg         mem_valid,
    output reg  [31:0] mem_addr,
    output reg  [31:0] mem_data,

    // Pipeline control
    output reg         stall_pipeline,

    // Status
    output reg         buffer_full
);

// 4-entry store buffer
reg [31:0] buffer_addr  [3:0];
reg [31:0] buffer_data  [3:0];
reg        buffer_valid [3:0];

integer i;

always @(posedge clk or posedge reset) begin
    if (reset) begin
        mem_valid      <= 1'b0;
        mem_addr       <= 32'b0;
        mem_data       <= 32'b0;
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
        if (store_op && !buffer_full) begin
            for (i = 0; i < 4; i = i + 1) begin
                if (!buffer_valid[i]) begin
                    buffer_addr[i]  <= store_addr;
                    buffer_data[i]  <= store_data;
                    buffer_valid[i] <= 1'b1;
                    disable for; // only one store per cycle
                end
            end
        end

        // -------------------------------------------------
        // 4) Drain store buffer to memory (ALWAYS)
        // -------------------------------------------------
        mem_valid <= 1'b0;
        for (i = 0; i < 4; i = i + 1) begin
            if (buffer_valid[i]) begin
                mem_valid <= 1'b1;
                mem_addr  <= buffer_addr[i];
                mem_data  <= buffer_data[i];
                if (mem_ready)
                    buffer_valid[i] <= 1'b0; // free entry
                disable for; // one store per cycle
            end
        end
    end
end

endmodule
