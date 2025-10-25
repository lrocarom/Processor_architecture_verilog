

module cpu(input  wire clk,
           input  wire reset);


    wire [31:0] program_counter;
    wire [31:0] instruction;
    wire [31:0] instruction_branch;
    wire [31:0] branch_target;


    wire [31:0] data_register_a;
    wire [31:0] data_register_b;
    wire [31:0] data_register_d;
    wire [31:0] alu_output;

    reg [31:0] adress_data;


    wire [3:0] alu_type;
    
    wire [31:0] memory_data;
    wire reg_write, mem_write_word, mem_read_word, alu_operation_write_register, branch;
    wire [3:0]  opcode;
    wire [4:0]  reg_a;
    wire [4:0]  reg_b;
    wire [4:0]  reg_d;
    wire [12:0] offset;

    reg [31:0] new_register_data;


    m_program_counter pc(   .clk (clk),
                            .branch_target (branch_target),       // Dirección de PC desde fuera (por ejemplo, para saltos)
                            .branch (branch),    
                            .reset (reset),           // Señal para elegir si actualizar PC normal o salto
                            .pc_out (program_counter)
                            );


    instruction_memory memory_ins( .program_counter (program_counter),
                                    .instruction_out (instruction) );

    decode_instruction decoder(   .instruction( instruction ),
                                    .opcode( opcode ),
                                    .reg_a( reg_a ),
                                    .reg_b( reg_b ),
                                    .reg_d( reg_d ),
                                    .offset( offset ));

    control_module control( .opcode( opcode ),
                            .alu_operation( alu_operation_write_register ),
                            .alu_operation_type(alu_type),
                            .write_register(reg_write),
                            .load_word_memory(mem_read_word),
                            .store_word_memory(mem_write_word),
                            .branch( branch )); 

    register_table register_table( .clk(clk),
                        .register_a( reg_a ),
                        .register_b( reg_b ),
                        .register_d( reg_d ),
                        .data_register_d_in( new_register_data ),
                        .write_register_d( reg_write ),
                        .data_register_a( data_register_a ),
                        .data_register_b( data_register_b ),
                        .data_register_d_out ( data_register_d ));

    alu alu  ( .reg_a( data_register_a ),
               .reg_b( data_register_b ),
               .alu_ctrl( alu_type ),
               .result_value( alu_output ));


    always @(*) begin    //might change to clocked
        adress_data  = data_register_b;   
    end

    data_memory mem_data(.clk(clk),
                         .store_instruction (mem_write_word),
                         .address (adress_data),
                         .data_memory_in (data_register_d),
                         .data_memory_out (memory_data));


    always @(*) begin   //might change to clocked
        if (mem_read_word)
            new_register_data = memory_data;
        else if(alu_operation_write_register)
            new_register_data = alu_output;
        
    end






endmodule