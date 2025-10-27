
module register_table(input          clk,
                      input          reset,
                      input  [4:0]  register_a,
                      input  [4:0]  register_b,
                      input  [4:0]  register_d,
                      input  [31:0]  data_register_d_in,
                      input  write_register_d,
                      output  [31:0]  data_register_a,
                      output  [31:0]  data_register_b,
                      output  [31:0]  data_register_d_out
                      );
    

    reg [31:0] data_register [0:31];
    integer i;

    reg [31:0] rm0_pc_exception;
    reg [31:0] rm1_address_exception;

    reg [31:0] rm4_privilege_level;
    

    initial begin
        data_register[0] = 32'h00000001;
        data_register[1] = 32'h00000007;
        data_register[2] = 32'h00000004;
        data_register[3] = 32'h00000004;
    end

    assign data_register_a = data_register[register_a[4:0]];
    assign data_register_b = data_register[register_b[4:0]];
    assign data_register_d_out = data_register[register_d[4:0]];

    always @(posedge clk or reset) begin
    if(write_register_d)
        data_register[register_d[4:0]] <= data_register_d_in;
    else if (reset)
        for (i = 0; i < 32; i++) data_register[i] = 32'h0;
     end


endmodule