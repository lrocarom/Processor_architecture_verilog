

module cpu(input  wire clk,
           input  wire reset);


    wire [31:0] program_counter;
    wire [31:0] instruction;
    
    wire [31:0] pc_pipeline;
    wire [31:0] instruction_pipeline;
    
    wire [3:0]  branch_type_operation;
    
    wire [4:0]  reg_rs1;
    wire [4:0]  reg_rs2;
    wire [4:0]  reg_d;

    wire [31:0] data_register_rs1;
    wire [31:0] data_register_rs2;
    wire [31:0] data_register_d;//NDEED TO DELETE?
    wire [31:0] alu_output;

    reg [31:0] adress_data;
    


    wire [3:0] alu_type;

    
    wire [31:0] memory_data;
    wire reg_write, mem_write_word, mem_read_word, alu_operation_write_register, branch, jump, panic;


    reg [31:0] new_register_data;
    wire [12:0] offset;

    wire stall;

    /***************************************************************************************************************/
    /*****************************************FETCH STAGE***********************************************************/
    /***************************************************************************************************************/


    m_fetch fetch_stage(    .clk (clk),
                            .branch_target (offset),       // Dirección de PC desde fuera (por ejemplo, para saltos)
                            .branch (branch),
                            .jump_target(data_register_rs1),
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
                                .in_stall( stall ),
                                .pc_out( pc_pipeline ),
                                .instruction_out( instruction_pipeline )  );

    /***************************************************************************************************************/
    /*****************************************DECODE STAGE***********************************************************/
    /***************************************************************************************************************/
    wire alu_operation;
    wire write_reg;

    wire reg  [1:0] forwardA;
    wire reg  [1:0] forwardB;
    wire [4:0]  ex_reg_d;
    wire [31:0] ex_data_rs1, ex_data_rs2, ex_data_d;
    wire [3:0] ex_alu_type;
    wire ex_write_reg, ex_load_mem, ex_store_mem, ex_branch, ex_jump, ex_panic;
    wire [3:0] ex_branch_type;

    wire [4:0]  ex_reg_rs1;
    wire [4:0]  ex_reg_rs2;

    wire [31:0] imm_i_type;
    wire [31:0] ex_imm_i_type;

    wire [31:0] imm_s_type;
    wire [31:0] ex_imm_s_type;


    decode_stage decoder_stage(   .clk (clk),
                            .reset (reset),
                            .instruction( instruction_pipeline ),
                            .reg_rs1( reg_rs1 ),
                            .reg_rs2( reg_rs2 ),
                            .reg_d ( reg_d ),
                            .imm_i_type( imm_i_type ),
                            .imm_s_type( imm_s_type ),
                            .alu_operation( alu_operation ),
                            .alu_operation_type(alu_type),
                            .write_register( write_reg ),
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
        .in_data_register_rs1(data_register_rs1),
        .in_data_register_rs2(data_register_rs2),
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
        .in_reg_rs1( reg_rs1 ),
        .in_reg_rs2( reg_rs2 ),
        .in_imm_i_type( imm_i_type ),
        .in_imm_s_type( imm_s_type ),
        .in_stall( stall ),
        .out_data_register_rs1(ex_data_rs1),
        .out_data_register_rs2(ex_data_rs2),
        .out_reg_rd(ex_reg_d),
        .out_alu_operation_type(ex_alu_type),
        .out_write_register(ex_write_reg),
        .out_load_word_memory(ex_load_mem),
        .out_store_word_memory(ex_store_mem),
        .out_branch(ex_branch),
        .out_branch_operation_type(ex_branch_type),
        .out_jump(ex_jump),
        .out_panic(ex_panic),
        .out_reg_rs1( ex_reg_rs1 ),
        .out_reg_rs2( ex_reg_rs2 ),
        .out_imm_i_type( ex_imm_i_type ),
        .out_imm_s_type( ex_imm_s_type )
    );



    /***************************************************************************************************************/
    /*****************************************ALU STAGE***********************************************************/
    /***************************************************************************************************************/


    wire m_write_reg, m_load_mem, m_store_mem, m_jump, m_panic;
    wire [31:0] m_alu_output;
    
    wire [4:0] m_register_d;//NDEED TO DELETE?


    wire [31:0] alu_op1_real;
    wire [31:0] alu_op2_real;




    alu_stage alu_stage(    .clk (clk),
                            .rst(rst),
                            .alu_op1 (alu_op1_real),
                            .alu_op2 (alu_op2_real),
                            .alu_operation (ex_alu_type),
                            .is_write_in (ex_write_reg),
                            .is_store_in (ex_store_mem),
                            .is_load_in (ex_load_mem),
                            .is_branch (ex_branch),
                            .imm_i_type( ex_imm_i_type ),
                            .imm_s_type( ex_imm_s_type ),
                            .alu_result (alu_output)
                            );

    alu_register alu_register ( .clk (clk),
                                .reset (reset),
                                .is_write_in (ex_write_reg),
                                .is_load_in (ex_load_mem),
                                .is_store_in (ex_store_mem),
                                .alu_result_in (alu_output),
                                .register_d_in (ex_reg_d),
                                .is_write_out (m_write_reg),
                                .is_load_out (m_load_mem),
                                .is_store_out (m_store_mem),
                                .alu_result_out (m_alu_output),
                                .register_d_out (m_register_d)
                                );
    
    
    hazard_unit hazard_unit(
        .ex_is_load(ex_load_mem),      // EX stage is a load
        .ex_rd(ex_reg_d),           // destination register of EX
        .id_rs1(reg_rs1),          // source registers in ID stage
        .id_rs2(reg_rs1),
        .stall(stall)
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
        .write_data_in(m_alu_output), // Data to store (rs2)
        .is_load_in(m_load_mem ),       // control signal
        .is_store_in(m_store_mem ),     // control signal
        .is_write_in(m_write_reg), // control signal
        .wb_data_out(wb_data_in)        // data read from memory
    );

    memory_register mem_reg (   .clk(clk),
                                .reset(reset),
                                .wb_data_in(wb_data_in),
                                .rd_in(m_register_d),
                                .is_write_in(m_write_reg),
                                .wb_data_out(wb_data_out),
                                .rd_out(wb_register_d),
                                .is_write_out(wb_write_reg)
                            );

    forwarding_unit m_forwarding_unit(
        .id_ex_rs1(ex_reg_rs1),
        .id_ex_rs2(ex_reg_rs2),
        .ex_mem_rd(m_register_d),
        .ex_mem_regwrite(m_write_reg) ,
        .mem_wb_rd(wb_register_d),
        .mem_wb_regwrite(wb_write_reg),
        .forwardA(forwardA),
        .forwardB(forwardB)
    );
    
    assign alu_op1_real =
        (forwardA == 2'b10) ? m_alu_output :   // EX/MEM -> ALU
        (forwardA == 2'b01) ? wb_data_out   :  // MEM/WB -> ALU
                            ex_data_rs1;      // ID/EX (valor leído del banco)

    assign alu_op2_real =
        (forwardB == 2'b10) ? m_alu_output :
        (forwardB == 2'b01) ? wb_data_out   :
                          ex_data_rs2;


    /***************************************************************************************************************/
    /*****************************************WB STAGE***********************************************************/
    /***************************************************************************************************************/

    
    
    register_table register_table(  .clk(clk),
                                    .reset(reset),
                                    .register_rs1( reg_rs1 ),
                                    .register_rs2( reg_rs2 ),
                                    .register_d( wb_register_d ),
                                    .data_register_d_in( wb_data_out ),
                                    .write_register_d( wb_write_reg ),
                                    .data_register_rs1( data_register_rs1 ),
                                    .data_register_rs2( data_register_rs2 ),
                                    .data_register_d_out ( data_register_d ));



endmodule