
module decode_tb;


    reg [31:0] instruction;

    wire [3:0] opcode ;
    wire [4:0] reg_a ;
    wire [4:0] reg_b ;
    wire [4:0] reg_d ;
    wire [12:0] offset ;


    // Memoria de instrucciones (por simplicidad, tamaño 256 instrucciones)
    reg [31:0] instr0;
    reg [31:0] instr1;
    reg [31:0] instr2;
    reg [31:0] instr3;

 
    initial begin
        instr0 = 32'h00008610;
        instr1 = 32'h00008610;
        instr2 = 32'h0001C670;
        instr3 = 32'h00308193;
    end

    //First step will be to increase the program counter

    decode_instruction decode(  .instruction( instruction ),
                                .opcode( opcode ),
                                .reg_a( reg_a ),
                                .reg_b( reg_b ),
                                .reg_d( reg_d ),
                                .offset( offset ));
            


    initial begin 
        // $dumpfile("build/decode_wave.vcd");
        // $dumpvars(0, pc_tb);

        $display("Time | Instruction   | opcode | reg_a | reg_b | reg_d | offset");

            
        #10 

        instruction = instr0;
        $display("%0t | %h | %h | %h | %h | %h | %h", 
                 $time, instruction, opcode, reg_a, reg_b, reg_d, offset);

        #10 
    
        instruction =  instr1;        
        $display("%0t | %h | %h | %h | %h | %h | %h", 
                $time, instruction, opcode, reg_a, reg_b, reg_d, offset);


        
        #10 
        
        instruction =  instr2;
        $display("%0t | %h | %h | %h | %h | %h | %h", 
                $time, instruction, opcode, reg_a, reg_b, reg_d, offset);


        
        #10 
        
        instruction =  instr3;
        $display("%0t | %h | %h | %h | %h | %h | %h", 
                $time, instruction, opcode, reg_a, reg_b, reg_d, offset);

        #10 
$display("%0t | %h | %h | %h | %h | %h | %h", 
                $time, instruction, opcode, reg_a, reg_b, reg_d, offset);

        $finish;
    end

endmodule