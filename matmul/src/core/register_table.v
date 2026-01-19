
module register_table(input          clk,
                      input          reset,
                      input  [4:0]  register_rs1,
                      input  [4:0]  register_rs2,
                      input  [4:0]  register_d,
                      input  [31:0]  data_register_d_in,
                      input  write_register_d,
                      output  [31:0]  data_register_rs1,
                      output  [31:0]  data_register_rs2,
                      output  [31:0]  data_register_d_out
                      );
    

    reg [31:0] data_register [0:31];
    integer i;
    

    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            data_register[i] = 32'h0;
        end
    end

    assign data_register_rs1 = data_register[register_rs1[4:0]];
    assign data_register_rs2 = data_register[register_rs2[4:0]];
    assign data_register_d_out = data_register[register_d[4:0]];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1) begin
                data_register[i] <= 32'h0;
            end
        end else if (write_register_d && (register_d != 5'd0)) begin
            // x0 is hardwired to zero
            data_register[register_d[4:0]] <= data_register_d_in;
        end
    end


endmodule