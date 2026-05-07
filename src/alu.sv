/*
explanation of the code:
This code defines a 32-bit ALU (Arithmetic Logic Unit) in SystemVerilog.
The ALU takes two 32-bit inputs (A and B), 
a 4-bit opcode to specify the operation, and a carry-in signal. 
It produces a 32-bit result and several flags (zero, carry_out, overflow, negative) based on the operation performed.
The ALU supports the following operations based on the opcode:  
- ADD (0000)
- SUB (1000)    
- AND (0111)
- OR (0110)
- XOR (0100)
- SLL (0001)
- SRL (0101)
- SRA (1101)
- SLT (0010)
- SLTU (0011)

*/

module ALU_32bit (
    input  logic [31:0] A,
    input  logic [31:0] B,
    input  logic [3:0]  alu_op,

    output logic [31:0] result,
    output logic        zero,
    output logic        carry_out,
    output logic        overflow,
    output logic        negative
);

    localparam ADD_OP  = 4'b0000,
               SUB_OP  = 4'b1000,
               SLL_OP  = 4'b0001,
               SLT_OP  = 4'b0010,
               SLTU_OP = 4'b0011,
               XOR_OP  = 4'b0100,
               SRL_OP  = 4'b0101,
               SRA_OP  = 4'b1101,
               OR_OP   = 4'b0110,
               AND_OP  = 4'b0111;

    // 33-bit: bit[32] captures carry out of bit[31]
    logic [32:0] adder_result;

    always_comb begin
        case (alu_op)
            ADD_OP:  adder_result = {1'b0, A} + {1'b0, B};
            SUB_OP:  adder_result = {1'b0, A} - {1'b0, B};
            default: adder_result = 33'b0;
        endcase
    end

    // Result mux
    always_comb begin
        case (alu_op)
            ADD_OP:  result = adder_result[31:0];
            SUB_OP:  result = adder_result[31:0];
            SLL_OP:  result = A << B[4:0];                            // lower 5 bits = shift amount
            SLT_OP:  result = ($signed(A) < $signed(B)) ? 32'd1 : 32'd0;
            SLTU_OP: result = (A < B)                   ? 32'd1 : 32'd0;
            XOR_OP:  result = A ^ B;
            SRL_OP:  result = A >> B[4:0];
            SRA_OP:  result = $signed(A) >>> B[4:0];                  // sign-extending shift
            OR_OP:   result = A | B;
            AND_OP:  result = A & B;
            default: result = 32'b0;
        endcase
    end

    // Flags
    assign zero      = (result == 32'b0);
    assign negative  =  result[31];
    assign carry_out = ((alu_op == ADD_OP) || (alu_op == SUB_OP)) ? adder_result[32] : 1'b0;

    // ADD overflow: same-sign inputs produce opposite-sign result
    // SUB overflow: different-sign inputs, result sign differs from A
    assign overflow =
        (alu_op == ADD_OP) ? ( A[31] ==  B[31] && result[31] != A[31]) :
        (alu_op == SUB_OP) ? ( A[31] !=  B[31] && result[31] != A[31]) :
        1'b0;

endmodule
