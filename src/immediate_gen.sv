/*
@Author: Tawhid Alam
@Date: 2024-06-01 12:00:00
@Last Modified by: Tawhid Alam
@Last Modified time: 2024-06-01 12:00:00

== Description ==
-parameterized immediate generator for RISC-V instructions
-Generates the correct immediate value based on the instruction type (I, S, B, U, J)
-Supports sign-extension for negative immediates

== Inputs ==
-instr: 32-bit instruction from which the immediate value will be extracted
== Outputs ==
-imm_out: 32-bit immediate value generated based on the instruction type

== Local Parameters ==
    I_TYPE = 7'b0010011,
    LOAD   = 7'b0000011,
    STORE  = 7'b0100011,
    BRANCH = 7'b1100011,
    JAL    = 7'b1101111,
    JALR   = 7'b1100111,
    LUI    = 7'b0110111,
    AUIPC  = 7'b0010111;

== Instruction Types immediate values ==
    I-type: instr[31:20]
    S-type: instr[31:25] & instr[11:7]
    B-type: instr[7] & instr[30:25] & instr[11:8] & 1'b0
    U-type: instr[31:12] & 12'b0
    J-type: instr[19:12] & instr[20] & instr[30:21] & 1'b0
*/

module immediate_gen (
    input  logic [31:0] instr,
    output logic [31:0] imm_out
);

    logic [6:0] opcode;
    assign opcode = instr[6:0];

    localparam I_TYPE = 7'b0010011,   // ADDI, SLTI, XORI, ORI, ANDI, SLLI, SRLI, SRAI
               LOAD   = 7'b0000011,   // LB, LH, LW, LBU, LHU
               STORE  = 7'b0100011,   // SB, SH, SW
               BRANCH = 7'b1100011,   // BEQ, BNE, BLT, BGE, BLTU, BGEU
               JAL    = 7'b1101111,
               JALR   = 7'b1100111,
               LUI    = 7'b0110111,
               AUIPC  = 7'b0010111;

    always_comb begin
        case (opcode)
            // I-type: 12-bit signed immediate
            I_TYPE,
            LOAD,
            JALR   : imm_out = {{20{instr[31]}}, instr[31:20]};

            // S-type: split across two fields
            STORE  : imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: branch offset (bit-1 to bit-12, bit-0 always 0)
            BRANCH : imm_out = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};

            // U-type: upper 20 bits, lower 12 zeroed
            LUI,
            AUIPC  : imm_out = {instr[31:12], 12'b0};

            // J-type: jump offset (bit-1 to bit-20, bit-0 always 0)
            JAL    : imm_out = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};

            default: imm_out = 32'b0;
        endcase
    end

endmodule
