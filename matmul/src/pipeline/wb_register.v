module wb_register( input     clk,
                    input     reset,
                    input  wire [31:0] new_register_data_in,
                    input  wire        is_write_in,
                    input  wire [3:0]  register_d_in,
                    output  reg [31:0] new_register_data_out,
                    output  reg        is_write_out,
                    output  reg [3:0]  register_d_out);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            new_register_data_out          <= 32'b0;
            is_write_out                <= 1'b0;
            register_d_out            <= 3'b0;
        end else begin
            new_register_data_out   <= new_register_data_in;
            is_write_out            <= is_write_in;
            register_d_out          <= register_d_in;
        end
    end

endmodule
