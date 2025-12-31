module hazard_unit(
    input  wire        ex_is_load,      // EX stage is a load
    input  wire [4:0]  ex_rd,           // destination register of EX
    input  wire [4:0]  id_rs1,          // source registers in ID stage
    input  wire [4:0]  id_rs2,
    output reg         stall
);

always @(*) begin
    stall = 0;

    if (ex_is_load && (ex_rd != 0) &&
       ((ex_rd == id_rs1) || (ex_rd == id_rs2))) begin
        stall = 1;
    end
end

endmodule
