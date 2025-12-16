
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
        data_register[0] = 32'h00000001;
        data_register[1] = 32'h00000007;
        data_register[2] = 32'h00000005;
        data_register[3] = 32'h00000004;
        data_register[4] = 32'h00000001;
        data_register[5] = 32'h00000004;
        data_register[6] = 32'h00000012;
        data_register[7] = 32'h00000013;
        data_register[8] = 32'h00000014;
    end

    assign data_register_rs1 = data_register[register_rs1[4:0]];
    assign data_register_rs2 = data_register[register_rs2[4:0]];
    assign data_register_d_out = data_register[register_d[4:0]];

    always @(posedge clk or reset) begin
    if(write_register_d)
        data_register[register_d[4:0]] <= data_register_d_in;
    else if (reset)
        for (i = 0; i < 32; i++) data_register[i] = 32'h0;
     end


endmodule