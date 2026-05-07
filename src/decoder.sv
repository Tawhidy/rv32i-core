/*


31        25 24    20 19    15 14  12 11     7 6        0
 ┌──────────┬────────┬────────┬──────┬────────┬─────────┐
 │  funct7  │  rs2   │  rs1   │funct3│   rd   │ opcode  │
 │  [31:25] │[24:20] │[19:15] │[14:12│[11: 7] │ [6:0]   │
 └──────────┴────────┴────────┴──────┴────────┴─────────┘
    7bits     5bits    5bits    3bits   5bits    7bits

- The opcode field (bits [6:0]) is used to determine the instruction type and the specific operation to be performed.
- The funct3 field (bits [14:12]) and funct7 field
- (bits [31:25]) are used in conjunction with the opcode to further specify the exact operation, especially for R-type instructions.
- The rs1 and rs2 fields (bits [19:15] and [24:20]) specify the source registers, while the rd field (bits [11:7]) specifies the destination register for the result of the operation.
- The testbench for this module should verify that the decoder correctly identifies the opcode and sets the


*/

module decoder (
    input  logic [31:0] instr,

    // ALU control
    output logic [3:0]  alu_op,
    output logic [1:0]  alu_a_src,   // 00=rs1  01=PC  10=zero
    output logic        alu_src,     // 0=rs2   1=imm  (ALU B input)

    // Register file
    output logic        reg_write,

    // Data memory
    output logic        mem_write,   // 1 = store
    output logic        mem_read,    // 1 = load
    output logic [2:0]  mem_size,    // funct3: encodes width + sign for load/store

    // Writeback
    output logic [1:0]  wb_sel,      // 00=ALU  01=memory  10=PC+4

    // Branch / Jump
    output logic        branch,
    output logic [2:0]  branch_op,   // funct3 of branch → tells top module which condition
    output logic        jump,
    output logic        jalr         // 1=JALR, 0=JAL  (valid only when jump=1)
);

    // -------------------------------------------------------------------------
    // Instruction field extraction
    // -------------------------------------------------------------------------
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    // -------------------------------------------------------------------------
    // Opcode parameters
    // -------------------------------------------------------------------------
    localparam R_TYPE = 7'b0110011,
               I_TYPE = 7'b0010011,
               LOAD   = 7'b0000011,
               STORE  = 7'b0100011,
               BRANCH = 7'b1100011,
               JAL    = 7'b1101111,
               JALR   = 7'b1100111,
               LUI    = 7'b0110111,
               AUIPC  = 7'b0010111;

    // ALU A source encoding
    localparam ALU_A_RS1  = 2'b00,   // default
               ALU_A_PC   = 2'b01,   // AUIPC
               ALU_A_ZERO = 2'b10;   // LUI

    // Writeback select encoding
    localparam WB_ALU = 2'b00,
               WB_MEM = 2'b01,
               WB_PC4 = 2'b10;

    // -------------------------------------------------------------------------
    // Decode logic
    // -------------------------------------------------------------------------
    always_comb begin

        // Safe defaults — NOP behaviour
        alu_op    = 4'b0000;
        alu_a_src = ALU_A_RS1;
        alu_src   = 1'b0;
        reg_write = 1'b0;
        mem_write = 1'b0;
        mem_read  = 1'b0;
        mem_size  = 3'b010;          // word (SW/LW) as harmless default
        wb_sel    = WB_ALU;
        branch    = 1'b0;
        branch_op = 3'b000;
        jump      = 1'b0;
        jalr      = 1'b0;

        case (opcode)

            // -----------------------------------------------------------------
            // R-TYPE: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
            // alu_op = {funct7[5], funct3} — safe here, funct7 is a real field
            // -----------------------------------------------------------------
            R_TYPE: begin
                reg_write = 1'b1;
                alu_op    = {funct7[5], funct3};
                wb_sel    = WB_ALU;
            end

            // -----------------------------------------------------------------
            // I-TYPE: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
            //
            // BUG FIX: instr[30] is part of the immediate for most I-type ops.
            // Only SRLI vs SRAI (funct3 == 101) legitimately uses instr[30].
            // For all others, force the MSB of alu_op to 0.
            // -----------------------------------------------------------------
            I_TYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;    // ALU B = immediate
                wb_sel    = WB_ALU;
                // Use instr[30] only for shift-right to distinguish SRLI/SRAI
                alu_op    = (funct3 == 3'b101) ? {funct7[5], funct3}  // SRLI or SRAI
                                               : {1'b0,      funct3}; // all others: ignore bit[30]
            end

            // -----------------------------------------------------------------
            // LOAD: LB, LH, LW, LBU, LHU
            // funct3 encodes both width and signed/unsigned for data_mem
            // -----------------------------------------------------------------
            LOAD: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;       // addr = rs1 + sign_ext(imm)
                mem_read  = 1'b1;
                mem_size  = funct3;     // passed to data_mem for read decoding
                alu_op    = 4'b0000;    // ADD for address calculation
                wb_sel    = WB_MEM;
            end

            // -----------------------------------------------------------------
            // STORE: SB, SH, SW
            // -----------------------------------------------------------------
            STORE: begin
                alu_src   = 1'b1;       // addr = rs1 + sign_ext(imm)
                mem_write = 1'b1;
                mem_size  = funct3;     // passed to data_mem for byte-enable generation
                alu_op    = 4'b0000;    // ADD for address calculation
            end

            // -----------------------------------------------------------------
            // BRANCH: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // ALU computes comparison; top module evaluates the condition flag
            // branch_op (= funct3) tells the top module which flag to check
            // -----------------------------------------------------------------
            BRANCH: begin
                branch    = 1'b1;
                branch_op = funct3;
                // Select ALU op to produce the right comparison result
                case (funct3)
                    3'b000,
                    3'b001: alu_op = 4'b1000;  // BEQ / BNE  → SUB  → check zero flag
                    3'b100,
                    3'b101: alu_op = 4'b0010;  // BLT / BGE  → SLT  → check result[0]
                    3'b110,
                    3'b111: alu_op = 4'b0011;  // BLTU / BGEU → SLTU → check result[0]
                    default: alu_op = 4'b1000;
                endcase
            end

            // -----------------------------------------------------------------
            // JAL: rd = PC+4,  PC = PC + sign_ext(imm)
            // ALU is not used for target — target computed in top module
            // -----------------------------------------------------------------
            JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
                jalr      = 1'b0;
                wb_sel    = WB_PC4;     // write return address to rd
            end

            // -----------------------------------------------------------------
            // JALR: rd = PC+4,  PC = (rs1 + sign_ext(imm)) & ~1
            // ALU computes the target; top module clears LSB
            // -----------------------------------------------------------------
            JALR: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;       // ALU B = immediate
                alu_op    = 4'b0000;    // ADD: rs1 + imm = raw jump target
                jump      = 1'b1;
                jalr      = 1'b1;
                wb_sel    = WB_PC4;     // write return address to rd
            end

            // -----------------------------------------------------------------
            // LUI: rd = 0 + imm  (upper 20 bits, lower 12 zeroed by imm_gen)
            // Force ALU A input to 0 so result = 0 + imm = imm
            // -----------------------------------------------------------------
            LUI: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_a_src = ALU_A_ZERO; // A = 0
                alu_op    = 4'b0000;    // ADD: 0 + imm = imm
                wb_sel    = WB_ALU;
            end

            // -----------------------------------------------------------------
            // AUIPC: rd = PC + imm
            // Force ALU A input to PC
            // -----------------------------------------------------------------
            AUIPC: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_a_src = ALU_A_PC;   // A = PC
                alu_op    = 4'b0000;    // ADD: PC + imm
                wb_sel    = WB_ALU;
            end

            // -----------------------------------------------------------------
            // Unknown opcode — all signals stay at safe NOP defaults
            // -----------------------------------------------------------------
            default: ;

        endcase
    end

endmodule
