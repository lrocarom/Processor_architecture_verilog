

module cpu(input  wire clk,
           input  wire reset);


    wire [31:0] program_counter;
    wire [31:0] instruction;
    
    wire [31:0] pc_pipeline;
    wire [31:0] instruction_pipeline;
    
    wire [3:0]  branch_type_operation;
    
    wire [4:0]  reg_a;
    wire [4:0]  reg_b;
    wire [4:0]  reg_d;

    wire [31:0] data_register_a;
    wire [31:0] data_register_b;
    wire [31:0] data_register_d;//NDEED TO DELETE?
    wire [31:0] alu_output;

    reg [31:0] adress_data;
    


    wire [3:0] alu_type;

    
    wire [31:0] memory_data;
    wire reg_write, mem_write_word, mem_read_word, alu_operation_write_register, branch, jump, panic;


    reg [31:0] new_register_data;
    wire [12:0] offset;

    wire [31:0] ex_data_a, ex_data_b, ex_data_d;
    wire [3:0] ex_alu_type;
    wire ex_write_reg, ex_load_mem, ex_store_mem, ex_branch, ex_jump, ex_panic;
    wire [3:0] ex_branch_type;

    /***************************************************************************************************************/
    /*****************************************FETCH STAGE***********************************************************/
    /***************************************************************************************************************/


    m_fetch fetch_stage(    .clk (clk),
                            .branch_target (offset),       // Dirección de PC desde fuera (por ejemplo, para saltos)
                            .branch (branch),
                            .jump_target(data_register_a),
                            .jump (jump),   
                            .reset (reset),
                            .panic (panic),           // Señal para elegir si actualizar PC normal o salto
                            .pc_out (program_counter),
                            .instruction_out (instruction)
                            );

    if_register fetch_register (.clk (clk),
                                .reset (reset),
                                .pc_in( program_counter ),
                                .instruction_in( instruction ),
                                .pc_out( pc_pipeline ),
                                .instruction_out( instruction_pipeline )  );

    /***************************************************************************************************************/
    /*****************************************DECODE STAGE***********************************************************/
    /***************************************************************************************************************/

    wire [4:0]  d_reg_d;

    decode_stage decoder_stage(   .clk (clk),
                            .reset (reset),
                            .instruction( instruction_pipeline ),
                            .reg_a( reg_a ),
                            .reg_b( reg_b ),
                            .reg_d ( reg_d ),
                            .alu_operation( alu_operation_write_register ),
                            .alu_operation_type(alu_type),
                            .load_word_memory(mem_read_word),
                            .store_word_memory(mem_write_word),
                            .branch( branch ),
                            .branch_operation_type( branch_type_operation ),
                            .jump( jump ),
                            .panic( panic )
                            );

    id_register decoder_register (
        .clk(clk),
        .reset(reset),
        .in_data_register_a(data_register_a),
        .in_data_register_b(data_register_b),
        .in_data_register_d(data_register_d),
        .in_reg_d(reg_d),
        .in_alu_operation_type(alu_type),
        .in_write_register(write_reg),
        .in_load_word_memory(mem_read_word),
        .in_store_word_memory(mem_write_word),
        .in_branch(branch),
        .in_branch_operation_type(branch_type_operation),
        .in_jump(jump),
        .in_panic(panic),
        .out_data_register_a(ex_data_a),
        .out_data_register_b(ex_data_b),
        .out_data_register_d(ex_data_d),
        .out_reg_d(d_reg_d),
        .out_alu_operation_type(ex_alu_type),
        .out_write_register(ex_write_reg),
        .out_load_word_memory(ex_load_mem),
        .out_store_word_memory(ex_store_mem),
        .out_branch(ex_branch),
        .out_branch_operation_type(ex_branch_type),
        .out_jump(ex_jump),
        .out_panic(ex_panic)
    );

    /***************************************************************************************************************/
    /*****************************************ALU STAGE***********************************************************/
    /***************************************************************************************************************/


    wire m_write_reg, m_load_mem, m_store_mem, m_jump, m_panic;
    wire [31:0] m_alu_output;
    
    wire [4:0] m_register_d;//NDEED TO DELETE?



    alu_stage alu_stage(    .clk (clk),
                            .alu_op1 (ex_data_a),
                            .alu_op2 (ex_data_b),
                            .alu_operation (ex_alu_type),
                            .is_write_in (ex_write_reg),
                            .is_store_in (ex_store_mem),
                            .is_load_in (ex_load_mem),
                            .is_branch (ex_branch),
                            .alu_result (alu_output)
                            );

    alu_register alu_register ( .clk (clk),
                                .reset (reset),
                                .is_write_in (ex_write_reg),
                                .is_load_in (ex_load_mem),
                                .is_store_in (ex_store_mem),
                                .alu_result_in (alu_output),
                                .register_d_in (d_reg_d),
                                .is_write_out (m_write_reg),
                                .is_load_out (m_load_mem),
                                .is_store_out (m_store_mem),
                                .alu_result_out (m_alu_output),
                                .register_d_out (m_register_d)
                                );

   

    /***************************************************************************************************************/
    /*****************************************MEM STAGE***********************************************************/
    /***************************************************************************************************************/


    wire wb_write_reg;

    wire [31:0] wb_data_in;
    wire [31:0] wb_data_out;

    wire [4:0] wb_register_d;//NDEED TO DELETE?


    memory_stage mem_stage_inst (
        .clk(clk),
        .reset(reset),
        .alu_result_in(m_alu_output),      // ALU result from EX stage
        .write_data_in(m_write_reg), // Data to store (rs2)
        .is_load_in(load_word_ex),       // control signal
        .is_store_in(m_load_mem),     // control signal
        .is_write_in(m_store_mem), // control signal
        .wb_data_out(wb_data_in)        // data read from memory
    );

    memory_register mem_reg (
                                .clk(clk),
                                .reset(reset),
                                .new_register_data_in(wb_data_in),
                                .is_write_in(m_write_reg),
                                .register_d_in(m_register_d),
                                .new_register_data_out(wb_data_out),
                                .is_write_out(wb_write_reg),
                                .register_d_out(wb_register_d)
                            );

    /***************************************************************************************************************/
    /*****************************************WB STAGE***********************************************************/
    /***************************************************************************************************************/

    
    wb_register write_back_register_inst (
        .clk(clk),
        .reset(reset),
        .new_register_data_in(wb_data_register_d), // from MEM stage
        .is_write_in(is_write_mem),         // control signal from MEM stage
        .register_d_in(rd_mem),             // destination register from MEM stage
        .new_register_data_out(new_register_data_out), 
        .is_write_out(is_write_out), 
        .register_d_out(register_d_out)
    );





    
    register_table register_table(  .clk(clk),
                                    .reset(reset),
                                    .register_a( reg_a ),
                                    .register_b( reg_b ),
                                    .register_d( wb_register_d ),
                                    .data_register_d_in( wb_data_out ),
                                    .write_register_d( reg_write ),
                                    .data_register_a( data_register_a ),
                                    .data_register_b( data_register_b ),
                                    .data_register_d_out ( data_register_d ));



    // decode_stage decoder(   .clk (clk),
    //                                 .instruction( instruction ),
    //                                 .opcode( opcode ),
    //                                 .reg_a( reg_a ),
    //                                 .reg_b( reg_b ),
    //                                 .reg_d( reg_d ),
    //                                 .offset( offset ));

    // control_module control( .opcode( opcode ),
    //                         .alu_operation( alu_operation_write_register ),
    //                         .alu_operation_type(alu_type),
    //                         .write_register(reg_write),
    //                         .load_word_memory(mem_read_word),
    //                         .store_word_memory(mem_write_word),
    //                         .branch( branch ),
    //                         .branch_operation_type( branch_type_operation ),
    //                         .jump( jump ),
    //                         .panic( panic )); 

    // register_table register_table( .clk(clk),
    //                     .register_a( reg_a ),
    //                     .register_b( reg_b ),
    //                     .register_d( reg_d ),
    //                     .data_register_d_in( new_register_data ),
    //                     .write_register_d( reg_write ),
    //                     .data_register_a( data_register_a ),
    //                     .data_register_b( data_register_b ),
    //                     .data_register_d_out ( data_register_d ));

    // alu alu  ( .reg_a( data_register_a ),
    //            .reg_b( data_register_b ),
    //            .alu_ctrl( alu_type ),
    //            .result_value( alu_output ));

    // branch_comparision branch_comp( .branch_operation (branch_type_operation),
    //                                 .data_register_a (data_register_a),
    //                                 .data_register_b (data_register_b),
    //                                 .branch (branch));


    // always @(*) begin    //might change to clocked
    //     adress_data  = data_register_b;   
    // end

    // data_memory mem_data(.clk(clk),
    //                      .store_instruction (mem_write_word),
    //                      .address (adress_data),
    //                      .data_memory_in (data_register_d),
    //                      .data_memory_out (memory_data));


    // always @(*) begin   //might change to clocked
    //     if (mem_read_word)
    //         new_register_data = memory_data;
    //     else
    //         new_register_data = alu_output;
    // end






endmodule