

module cpu(input  wire clk,
           input  wire reset);

    // --- Pipeline Signals ---
    wire [31:0] program_counter;
    wire [31:0] instruction;
    wire [31:0] pc_pipeline;
    wire [31:0] instruction_pipeline;
    
    // --- Special Registers (rm0-rm4) ---
    reg [31:0] rm0;
    reg [31:0] rm1;
    reg [31:0] rm2;
    reg [31:0] rm3;
    reg [31:0] rm4;
    wire       vm_enable = ~rm4[0]; // VM enabled in user mode
    
    // --- Decode Signals ---
    wire [3:0]  branch_type_operation;
    wire [4:0]  reg_rs1;
    wire [4:0]  reg_rs2;
    wire [4:0]  reg_d;
    wire [31:0] data_register_rs1;
    wire [31:0] data_register_rs2;
    wire [31:0] data_register_d;//NDEED TO DELETE?

    // --- ALU/Exec Signals ---
    wire [31:0] alu_output;
    reg [31:0] adress_data;
    wire [3:0] alu_type;
    wire [31:0] memory_data;
    wire reg_write, mem_write_word, mem_read_word, alu_operation_write_register, branch, jump, panic;
    wire mov_rm, tlbwrite, iret;


    reg [31:0] new_register_data;
    wire [12:0] offset;

    // --- Stall Logic ---
    wire hazard_stall_req; // From Hazard Unit
    wire mem_stall_req;    // From Memory Stage
    wire if_stall_req; // From Fetch Stage
    wire hold_stall;   // Cache stall (hold pipeline)
    wire bubble_stall; // Hazard stall (insert bubble)
    wire flush_pipe;

    assign hold_stall   = mem_stall_req;
    assign bubble_stall = hazard_stall_req | flush_pipe;

    // Logic: We want to stall Fetch if Hazard says so, or if Data Memory says so.
    // We do NOT include 'if_stall_req' here, because m_fetch calculates that internally.
    wire stall_for_fetch_stage;
    /***************************************************************************************************************/
    /*****************************************FETCH STAGE***********************************************************/
    /***************************************************************************************************************/


    wire if_tlb_miss;
    wire [31:0] if_tlb_fault_addr;
    wire itlb_write_en;
    wire [31:0] itlb_write_va;
    wire [31:0] itlb_write_pa;
    wire vm_exception;
    wire [31:0] exception_target;
    wire        redirect_exception;

    // Jump target calculation (supports JAL and JALR)
    wire is_jal  = (instruction_pipeline[6:0] == 7'b1101111);
    wire is_jalr = (instruction_pipeline[6:0] == 7'b1100111);
    wire [31:0] imm_j_type = { {11{instruction_pipeline[31]}},
                               instruction_pipeline[31],
                               instruction_pipeline[19:12],
                               instruction_pipeline[20],
                               instruction_pipeline[30:21],
                               1'b0 };
    wire [31:0] jal_target  = pc_pipeline + imm_j_type;
    wire [31:0] jalr_target = (data_register_rs1 + imm_i_type) & 32'hFFFFFFFE;
    wire [31:0] jump_target = is_jal ? jal_target :
                              is_jalr ? jalr_target :
                              data_register_rs1;

    m_fetch fetch_stage(    .clk (clk),
                            .branch_target (offset),       // Dirección de PC desde fuera (por ejemplo, para saltos)
                            .branch (branch),
                            .jump_target(jump_target),
                            .jump (jump),   
                            .reset (reset),
                            .panic (panic),           // Señal para elegir si actualizar PC normal o salto
                            .exception (redirect_exception),
                            .exception_target (exception_target),
                            .vm_enable (vm_enable),
                            .itlb_write_en (itlb_write_en),
                            .itlb_write_va (itlb_write_va),
                            .itlb_write_pa (itlb_write_pa),
                            .external_stall (stall_for_fetch_stage), // NEW: Stall from Hazard or Memory Stage
                            .pc_out (program_counter),
                            .instruction_out (instruction),
                            .stall_fetch (if_stall_req),
                            .tlb_miss (if_tlb_miss),
                            .tlb_fault_addr (if_tlb_fault_addr)
                            );

    if_register fetch_register (.clk (clk),
                                .reset (reset),
                                .pc_in( program_counter ),
                                .instruction_in( instruction ),
                                .in_stall( if_stall_req | hazard_stall_req | hold_stall ),
                                .flush( flush_pipe ),
                                .pc_out( pc_pipeline ),
                                .instruction_out( instruction_pipeline )  );

    /***************************************************************************************************************/
    /*****************************************DECODE STAGE***********************************************************/
    /***************************************************************************************************************/
    wire alu_operation;
    wire write_reg;

    wire  [1:0] forwardA;
    wire  [1:0] forwardB;
    wire [4:0]  ex_reg_d;
    wire [31:0] ex_data_rs1, ex_data_rs2, ex_data_d;
    wire [3:0] ex_alu_type;
    wire ex_write_reg, ex_load_mem, ex_store_mem, ex_branch, ex_jump, ex_panic;
    wire [3:0] ex_branch_type;
    wire [1:0] ex_mem_size;
    wire ex_load_unsigned;

    wire [4:0]  ex_reg_rs1;
    wire [4:0]  ex_reg_rs2;

    wire [31:0] imm_i_type;
    wire [31:0] ex_imm_i_type;

    wire [31:0] imm_s_type;
    wire [31:0] ex_imm_s_type;

    wire [31:0] rm_read_value;
    wire ex_mov_rm;
    wire ex_tlbwrite;
    wire ex_iret;
    wire [31:0] ex_rm_value;
    wire [31:0] ex_pc;


    wire alu_use_imm;
    wire ex_alu_use_imm;

    wire [1:0] mem_size;
    wire load_unsigned;

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
                            .alu_use_imm( alu_use_imm ),
                            .write_register( write_reg ),
                            .load_word_memory(mem_read_word),
                            .store_word_memory(mem_write_word),
                            .mem_size(mem_size),
                            .load_unsigned(load_unsigned),
                            .branch( branch ),
                            .branch_operation_type( branch_type_operation ),
                            .jump( jump ),
                            .panic( panic ),
                            .mov_rm( mov_rm ),
                            .tlbwrite( tlbwrite ),
                            .iret( iret )
                            );

    // Read special registers for MOVRM
    assign rm_read_value = (reg_rs1[2:0] == 3'd0) ? rm0 :
                           (reg_rs1[2:0] == 3'd1) ? rm1 :
                           (reg_rs1[2:0] == 3'd2) ? rm2 :
                           (reg_rs1[2:0] == 3'd3) ? rm3 :
                           rm4;

    id_register decoder_register (
        .clk(clk),
        .reset(reset),
        .in_data_register_rs1(data_register_rs1),
        .in_data_register_rs2(data_register_rs2),
        .in_data_register_d(data_register_d),
        .in_reg_d(reg_d),
        .in_alu_operation_type(alu_type),
        .in_alu_use_imm(alu_use_imm),
        .in_write_register(write_reg),
        .in_load_word_memory(mem_read_word),
        .in_store_word_memory(mem_write_word),
        .in_mem_size(mem_size),
        .in_load_unsigned(load_unsigned),
        .in_branch(branch),
        .in_branch_operation_type(branch_type_operation),
        .in_jump(jump),
        .in_panic(panic),
        .in_reg_rs1( reg_rs1 ),
        .in_reg_rs2( reg_rs2 ),
        .in_imm_i_type( imm_i_type ),
        .in_imm_s_type( imm_s_type ),
        .in_pc( pc_pipeline ),
        .in_mov_rm( mov_rm ),
        .in_tlbwrite( tlbwrite ),
        .in_rm_value( rm_read_value ),
        .in_iret( iret ),
        .in_stall_hold( hold_stall ),
        .in_stall_bubble( bubble_stall ),
        .out_data_register_rs1(ex_data_rs1),
        .out_data_register_rs2(ex_data_rs2),
        .out_reg_rd(ex_reg_d),
        .out_alu_operation_type(ex_alu_type),
        .out_alu_use_imm(ex_alu_use_imm),
        .out_write_register(ex_write_reg),
        .out_load_word_memory(ex_load_mem),
        .out_store_word_memory(ex_store_mem),
        .out_mem_size(ex_mem_size),
        .out_load_unsigned(ex_load_unsigned),
        .out_branch(ex_branch),
        .out_branch_operation_type(ex_branch_type),
        .out_jump(ex_jump),
        .out_panic(ex_panic),
        .out_reg_rs1( ex_reg_rs1 ),
        .out_reg_rs2( ex_reg_rs2 ),
        .out_imm_i_type( ex_imm_i_type ),
        .out_imm_s_type( ex_imm_s_type ),
        .out_pc( ex_pc ),
        .out_mov_rm( ex_mov_rm ),
        .out_tlbwrite( ex_tlbwrite ),
        .out_iret( ex_iret ),
        .out_rm_value( ex_rm_value )
    );



    /***************************************************************************************************************/
    /*****************************************ALU STAGE***********************************************************/
    /***************************************************************************************************************/


    wire m_write_reg, m_load_mem, m_store_mem, m_jump, m_panic;
    wire [31:0] m_alu_output;
    wire m_mov_rm, m_tlbwrite, m_iret;
    wire [31:0] m_rm_value;
    wire [31:0] m_pc;
    wire [1:0] m_mem_size;
    wire m_load_unsigned;
    
    wire [4:0] m_register_d;//NDEED TO DELETE?


    wire [31:0] alu_op1_real;
    wire [31:0] alu_op2_real;

    wire [31:0] m_store_data; // Carries the data to be written to memory




    alu_stage alu_stage(    .clk (clk),
                            .rst(reset),
                            .alu_op1 (alu_op1_real),
                            .alu_op2 (alu_op2_real),
                            .alu_operation (ex_alu_type),
                            .alu_use_imm (ex_alu_use_imm),
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
                                .mem_size_in (ex_mem_size),
                                .load_unsigned_in (ex_load_unsigned),
                                .store_data_in (alu_op2_real),
                                .pc_in (ex_pc),
                                .mov_rm_in (ex_mov_rm),
                                .tlbwrite_in (ex_tlbwrite),
                                .iret_in (ex_iret),
                                .rm_value_in (ex_rm_value),
                                .alu_result_in (alu_output),
                                .register_d_in (ex_reg_d),
                                .flush (flush_pipe),
                                .stall_hold (mem_stall_req),
                                .is_write_out (m_write_reg),
                                .is_load_out (m_load_mem),
                                .is_store_out (m_store_mem),
                                .mem_size_out (m_mem_size),
                                .load_unsigned_out (m_load_unsigned),
                                .alu_result_out (m_alu_output),
                                .register_d_out (m_register_d),
                                .store_data_out (m_store_data),
                                .pc_out (m_pc),
                                .mov_rm_out (m_mov_rm),
                                .tlbwrite_out (m_tlbwrite),
                                .iret_out (m_iret),
                                .rm_value_out (m_rm_value)
                                );
    
    
    hazard_unit hazard_unit(
        .ex_is_load(ex_load_mem),      // EX stage is a load
        .ex_is_mov_rm(ex_mov_rm),      // EX stage is MOVRM
        .mem_is_mov_rm(m_mov_rm),      // MEM stage is MOVRM
        .ex_rd(ex_reg_d),           // destination register of EX
        .mem_rd(m_register_d),      // destination register of MEM
        .wb_is_mov_rm(wb_mov_rm),   // WB stage is MOVRM
        .wb_rd(wb_register_d),      // destination register of WB
        .id_rs1(reg_rs1),          // source registers in ID stage
        .id_rs2(reg_rs2),
        .stall(hazard_stall_req)
    );
   

    /***************************************************************************************************************/
    /*****************************************MEM STAGE***********************************************************/
    /***************************************************************************************************************/


    wire wb_write_reg;
    wire wb_mov_rm;

    wire [31:0] wb_data_in;
    wire [31:0] wb_data_out;

    wire [4:0] wb_register_d;//NDEED TO DELETE?

    wire [4:0] mem_rd_pass_through; // New wire for rd_out -> mem_reg
    wire mem_kill_wb;
    wire mem_tlb_miss;
    wire [31:0] mem_tlb_fault_addr;
    wire [31:0] mem_tlb_fault_pc;
    wire mem_tlbwrite_priv_fault;
    wire mem_iret_taken;
    wire mem_iret_priv_fault;


    memory_stage mem_stage_inst (
        .clk(clk),
        .reset(reset),
        .alu_result_in(m_alu_output),       // ALU result from EX stage
        .write_data_in(m_store_data),       // Data to store (rs2)
        .pc_in(m_pc),
        .rd_in(m_register_d),               // Destination register
        .is_load_in(m_load_mem ),           // control signal
        .is_store_in(m_store_mem ),         // control signal
        .is_write_in(m_write_reg),          // control signal
        .mem_size_in(m_mem_size),
        .load_unsigned_in(m_load_unsigned),
        .mov_rm_in(m_mov_rm),
        .tlbwrite_in(m_tlbwrite),
        .iret_in(m_iret),
        .rm_value_in(m_rm_value),
        .vm_enable(vm_enable),
        .wb_data_out(wb_data_in),           // data read from memory
        .stall_req(mem_stall_req),
        .rd_out(mem_rd_pass_through),              // Pass-through rd to MEM/WB
        .kill_wb(mem_kill_wb),
        .tlb_miss(mem_tlb_miss),
        .tlb_fault_addr(mem_tlb_fault_addr),
        .tlb_fault_pc(mem_tlb_fault_pc),
        .itlb_write_en(itlb_write_en),
        .itlb_write_va(itlb_write_va),
        .itlb_write_pa(itlb_write_pa),
        .tlbwrite_priv_fault(mem_tlbwrite_priv_fault),
        .iret_taken(mem_iret_taken),
        .iret_priv_fault(mem_iret_priv_fault)
    );

    // VM exception aggregation
    assign vm_exception = if_tlb_miss | mem_tlb_miss | mem_tlbwrite_priv_fault | mem_iret_priv_fault;
    assign redirect_exception = vm_exception | mem_iret_taken;
    assign flush_pipe = redirect_exception;
    assign stall_for_fetch_stage = (hazard_stall_req | mem_stall_req) & ~(vm_exception | mem_iret_taken);

    wire [31:0] exception_pc = mem_tlb_miss ? mem_tlb_fault_pc :
                               mem_tlbwrite_priv_fault ? m_pc :
                               mem_iret_priv_fault ? m_pc :
                               program_counter;
    wire [31:0] exception_addr = mem_tlb_miss ? mem_tlb_fault_addr :
                                 mem_tlbwrite_priv_fault ? m_alu_output :
                                 mem_iret_priv_fault ? m_alu_output :
                                 if_tlb_fault_addr;
    assign exception_target = vm_exception ? 32'h00002000 : rm0;

    // Special register updates (privilege + fault info)
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            rm0 <= 32'b0;
            rm1 <= 32'b0;
            rm2 <= 32'b0;
            rm3 <= 32'b0;
            rm4 <= 32'h00000001; // supervisor mode on reset
        end else if (vm_exception) begin
            rm0 <= exception_pc;
            rm1 <= exception_addr;
            rm2 <= exception_addr + 32'h00001000; // precompute PA = VA + 0x1000
            rm4[0] <= 1'b1; // switch to supervisor
        end else if (mem_iret_taken) begin
            rm4[0] <= 1'b0; // return to user
        end
    end

    memory_register mem_reg (   .clk(clk),
                                .reset(reset),
                                .wb_data_in(wb_data_in),
                                .rd_in(mem_rd_pass_through),
                                .is_write_in(m_write_reg),
                                .mov_rm_in(m_mov_rm),
                                .kill_wb(mem_kill_wb),
                                .stall_hold(mem_stall_req),
                                .wb_data_out(wb_data_out),
                                .rd_out(wb_register_d),
                                .is_write_out(wb_write_reg),
                                .mov_rm_out(wb_mov_rm)
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
    
    // Forwarding value from EX/MEM: use MOVRM value when applicable
    wire [31:0] ex_mem_forward_val = m_mov_rm ? m_rm_value : m_alu_output;

    assign alu_op1_real =
        (forwardA == 2'b10) ? ex_mem_forward_val :   // EX/MEM -> ALU
        (forwardA == 2'b01) ? wb_data_out         :  // MEM/WB -> ALU
                              ex_data_rs1;           // ID/EX (valor leído del banco)

    assign alu_op2_real =
        (forwardB == 2'b10) ? ex_mem_forward_val :
        (forwardB == 2'b01) ? wb_data_out         :
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