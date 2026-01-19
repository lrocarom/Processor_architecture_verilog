module alu_register(
    input       clk,
    input       reset,
    
    input wire  is_write_in,
    input wire  is_load_in,
    input wire  is_store_in,
    input wire  [1:0] mem_size_in,
    input wire        load_unsigned_in,
    //input wire  is_branch_in,

    input wire  [31:0] store_data_in,
    input wire  [31:0] pc_in,
    input wire         mov_rm_in,
    input wire         tlbwrite_in,
    input wire         iret_in,
    input wire  [31:0] rm_value_in,

    input wire  [31:0] alu_result_in,
    input wire  [4:0] register_d_in,
    input wire        flush,
    input wire        stall_hold,

    output reg  is_write_out,
    output reg  is_load_out,
    output reg  is_store_out,
    output reg  [1:0] mem_size_out,
    output reg        load_unsigned_out,
    //output reg  is_branch_out,

    output reg  [31:0] alu_result_out,
    output reg  [4:0] register_d_out,
    output reg  [31:0] store_data_out,
    output reg  [31:0] pc_out,
    output reg         mov_rm_out,
    output reg         tlbwrite_out,
    output reg         iret_out,
    output reg  [31:0] rm_value_out

);



always @(posedge clk or posedge reset) begin
    if (reset || flush) begin
        is_write_out    <=  1'b0;
        is_load_out     <=  1'b0;
        is_store_out    <=  1'b0;
        mem_size_out    <=  2'b10;
        load_unsigned_out <= 1'b0;
        //is_branch_out   <=  1'b0;
        alu_result_out  <=  32'b0;
        register_d_out  <=  5'b0;
        store_data_out  <=  32'b0;
        pc_out          <=  32'b0;
        mov_rm_out      <=  1'b0;
        tlbwrite_out    <=  1'b0;
        iret_out        <=  1'b0;
        rm_value_out    <=  32'b0;

    end else if (stall_hold) begin
        is_write_out    <= is_write_out;
        is_load_out     <= is_load_out;
        is_store_out    <= is_store_out;
        mem_size_out    <= mem_size_out;
        load_unsigned_out <= load_unsigned_out;
        alu_result_out  <= alu_result_out;
        register_d_out  <= register_d_out;
        store_data_out  <= store_data_out;
        pc_out          <= pc_out;
        mov_rm_out      <= mov_rm_out;
        tlbwrite_out    <= tlbwrite_out;
        iret_out        <= iret_out;
        rm_value_out    <= rm_value_out;
    end else begin
        is_write_out    <= is_write_in;
        is_load_out     <= is_load_in;
        is_store_out    <= is_store_in;
        mem_size_out    <= mem_size_in;
        load_unsigned_out <= load_unsigned_in;
        //is_branch_out   <= is_branch_in;
        alu_result_out  <= alu_result_in;
        register_d_out  <= register_d_in;
        store_data_out  <= store_data_in;
        pc_out          <= pc_in;
        mov_rm_out      <= mov_rm_in;
        tlbwrite_out    <= tlbwrite_in;
        iret_out        <= iret_in;
        rm_value_out    <= rm_value_in;

    end

end












endmodule