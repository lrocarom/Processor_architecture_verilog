module data_memory(
    input           clk,
    input           reset,
    input           store_instruction, // Write Enable
    input  [31:0]   address,           // Byte Address
    input  [31:0]   data_memory_in,    // Write Data
    output [31:0]   data_memory_out    // Read Data
);

    // 4096 words = 16KB total memory
    reg [31:0] data_mem [0:4095];

    // Initialize with some test data
    initial begin
        // Address 0x0 -> Word 0
        data_mem[0] = 32'hDEADBEEF; 
        // Address 0x100 (Decimal 256) -> Word 64 (0x100 / 4 = 64)
        data_mem[64] = 32'hCAFEBABE;
        // Address 0x104 -> Word 65
        data_mem[65] = 32'h00000099;
    end

    // READ LOGIC
    // Use [13:2] to convert Byte Addr -> Word Index
    // Ignores bottom 2 bits (alignment) and upper bits (memory size limit)
    assign data_memory_out = data_mem[address[13:2]];

    // WRITE LOGIC
    always @(posedge clk) begin
        if (store_instruction) begin
            data_mem[address[13:2]] <= data_memory_in;
            // Debug print to help you see writes in simulation
            $display("[MEM] STORE: Addr=0x%h (Index %d) Val=0x%h", 
                     address, address[13:2], data_memory_in);
        end
    end

endmodule