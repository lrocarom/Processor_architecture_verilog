module memory_register(
    input          clk,
    input          reset,
    input  wire [31:0] wb_data_in,  // data from memory or EX stage
    input  wire [4:0]  rd_in,       // register to write back
    input  wire        is_write_in, // write enable for WB stage
    input  wire        mov_rm_in,   // MOVRM indicator
    input  wire        kill_wb,
    input  wire        stall_hold,

    output reg  [31:0] wb_data_out, 
    output reg  [4:0]  rd_out,      
    output reg         is_write_out,
    output reg         mov_rm_out
);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            wb_data_out    <= 32'b0;
            rd_out         <= 5'b0;
            is_write_out   <= 1'b0;
            mov_rm_out     <= 1'b0;
        end else if (kill_wb) begin
            wb_data_out    <= 32'b0;
            rd_out         <= 5'b0;
            is_write_out   <= 1'b0;
            mov_rm_out     <= 1'b0;
        end else if (stall_hold) begin
            wb_data_out    <= wb_data_out;
            rd_out         <= rd_out;
            is_write_out   <= is_write_out;
            mov_rm_out     <= mov_rm_out;
        end else begin
            wb_data_out    <= wb_data_in;
            rd_out         <= rd_in;
            is_write_out   <= is_write_in;
            mov_rm_out     <= mov_rm_in;
        end
    end

endmodule
