module hazard_unit(
    input  wire        ex_is_load,      // EX stage is a load
    input  wire        ex_is_mov_rm,     // EX stage is MOVRM (data available in MEM)
    input  wire        mem_is_mov_rm,    // MEM stage is MOVRM (data writes in WB)
    input  wire [4:0]  ex_rd,           // destination register of EX
    input  wire [4:0]  mem_rd,          // destination register of MEM
    input  wire        wb_is_mov_rm,    // WB stage is MOVRM (data just written)
    input  wire [4:0]  wb_rd,           // destination register of WB
    input  wire [4:0]  id_rs1,          // source registers in ID stage
    input  wire [4:0]  id_rs2,
    output reg         stall
);

always @(*) begin
    stall = 0;

    if ((ex_is_load || ex_is_mov_rm) && (ex_rd != 0) &&
       ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
        stall = 1;
    end

    if (mem_is_mov_rm && (mem_rd != 0) &&
       ((mem_rd == id_rs1) || (mem_rd == id_rs2))) begin
        stall = 1;
    end

    if (wb_is_mov_rm && (wb_rd != 0) &&
       ((wb_rd == id_rs1) || (wb_rd == id_rs2))) begin
        stall = 1;
    end
end

endmodule
