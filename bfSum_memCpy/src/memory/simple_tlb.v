// --------------------------------------------------------------
// simple_tlb.v
//
// Direct-mapped TLB with 4 entries.
//  - VA: 32-bit, Page size: 4KB -> VPN = [31:12]
//  - PA: 20-bit, PPN = [19:12]
//  - Index: VPN[1:0] (bits [13:12])
// --------------------------------------------------------------
module simple_tlb (
    input         clk,
    input         reset,

    // Lookup
    input  [31:0] lookup_va,
    input         lookup_valid,
    output        lookup_hit,
    output [31:0] lookup_pa,

    // Write (TLBWRITE)
    input         write_en,
    input  [31:0] write_va,
    input  [31:0] write_pa
);

    localparam ENTRY_COUNT = 4;
    localparam INDEX_BITS  = 2; // log2(4)
    localparam VPN_BITS    = 20;
    localparam PPN_BITS    = 8; // 20-bit PA - 12-bit offset

    wire [VPN_BITS-1:0] lookup_vpn = lookup_va[31:12];
    wire [INDEX_BITS-1:0] lookup_idx = lookup_vpn[1:0];
    wire [VPN_BITS-INDEX_BITS-1:0] lookup_tag = lookup_vpn[VPN_BITS-1:INDEX_BITS];

    wire [VPN_BITS-1:0] write_vpn = write_va[31:12];
    wire [INDEX_BITS-1:0] write_idx = write_vpn[1:0];
    wire [VPN_BITS-INDEX_BITS-1:0] write_tag = write_vpn[VPN_BITS-1:INDEX_BITS];
    wire [PPN_BITS-1:0] write_ppn = write_pa[19:12];

    reg [VPN_BITS-INDEX_BITS-1:0] tag_array   [0:ENTRY_COUNT-1];
    reg [PPN_BITS-1:0]            ppn_array   [0:ENTRY_COUNT-1];
    reg                           valid_array [0:ENTRY_COUNT-1];

    wire entry_valid = valid_array[lookup_idx];
    wire [VPN_BITS-INDEX_BITS-1:0] entry_tag = tag_array[lookup_idx];
    wire [PPN_BITS-1:0] entry_ppn = ppn_array[lookup_idx];

    assign lookup_hit = lookup_valid && entry_valid && (entry_tag == lookup_tag);
    assign lookup_pa  = {12'b0, entry_ppn, lookup_va[11:0]};

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < ENTRY_COUNT; i = i + 1) begin
                tag_array[i]   <= { (VPN_BITS-INDEX_BITS){1'b0} };
                ppn_array[i]   <= { PPN_BITS{1'b0} };
                valid_array[i] <= 1'b0;
            end
        end else if (write_en) begin
            tag_array[write_idx]   <= write_tag;
            ppn_array[write_idx]   <= write_ppn;
            valid_array[write_idx] <= 1'b1;
        end
    end

endmodule
