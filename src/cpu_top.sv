module cpu_top (
    input logic clk,
    input logic rst
);

    // SIGNAL DECLARATIONS

    //--- PC signals --- 
    logic [31:0] pc;           // current PC (output of PC register)
    logic [31:0] pc_next;      // selected next PC value
    logic [31:0] pc_plus4;     // PC + 4 (sequential next)
    logic [31:0] pc_branch;    // PC + imm (branch and JAL target)
    logic [31:0] pc_jalr;      // (rs1 + imm) & ~1 (JALR target)

    // --- Instruction and fields ---
    logic [31:0] instruction;
    logic [4:0]  rs1_addr, rs2_addr, rd_addr;

    // --- Immediate ---
    logic [31:0] imm_out;

    // --- Control signals from decoder ---
    logic [3:0]  alu_op;
    logic [1:0]  alu_a_src;    // 00=rs1  01=PC  10=zero
    logic        alu_src;      // 0=rs2   1=imm
    logic        reg_write;
    logic        mem_write;
    logic        mem_read;
    logic [2:0]  mem_size;
    logic [1:0]  wb_sel;       // 00=ALU  01=mem  10=PC+4
    logic        branch;
    logic [2:0]  branch_op;
    logic        jump;
    logic        jalr;

    // --- Register file ---
    logic [31:0] rd1, rd2;     // read data from regfile
    logic [31:0] wb_data;      // writeback data (after mux)

    // --- ALU ---
    logic [31:0] alu_a, alu_b; // ALU inputs (after muxes)
    logic [31:0] alu_result;
    logic        alu_zero;
    logic        alu_carry_out;
    logic        alu_overflow;
    logic        alu_negative;

    // --- Data memory ---
    logic [31:0] mem_data_out;

    // --- Branch ---
    logic        branch_taken;  // resolved branch condition


    // INSTRUCTION FIELD EXTRACTION

    assign rs1_addr = instruction[19:15];
    assign rs2_addr = instruction[24:20];
    assign rd_addr  = instruction[11:7];


    // PC ARITHMETIC

    assign pc_plus4  = pc + 32'd4;
    assign pc_branch = pc + imm_out;                  // JAL target and branch target
    assign pc_jalr   = {alu_result[31:1], 1'b0};      // JALR: clear LSB per spec


    // BRANCH CONDITION RESOLUTION
    // branch_op = funct3 of the branch instruction
    // ALU has already computed the comparison; we just read the right flag

    always_comb begin
        case (branch_op)
            3'b000:  branch_taken = alu_zero;           // BEQ  : rs1 == rs2
            3'b001:  branch_taken = ~alu_zero;          // BNE  : rs1 != rs2
            3'b100:  branch_taken = alu_result[0];      // BLT  : rs1 <  rs2 (signed)
            3'b101:  branch_taken = ~alu_result[0];     // BGE  : rs1 >= rs2 (signed)
            3'b110:  branch_taken = alu_result[0];      // BLTU : rs1 <  rs2 (unsigned)
            3'b111:  branch_taken = ~alu_result[0];     // BGEU : rs1 >= rs2 (unsigned)
            default: branch_taken = 1'b0;
        endcase
    end


    // PC NEXT MUX
    // Priority: JALR > JAL > Branch > Sequential

    always_comb begin
        if (jump && jalr)
            pc_next = pc_jalr;                         // JALR : (rs1 + imm) & ~1
        else if (jump && !jalr)
            pc_next = pc_branch;                       // JAL  : PC + imm
        else if (branch && branch_taken)
            pc_next = pc_branch;                       // Branch: PC + imm
        else
            pc_next = pc_plus4;                        // Default: sequential
    end


    // ALU INPUT MUXES

    // ALU A: rs1 (default), PC (AUIPC), or 0 (LUI)
    always_comb begin
        case (alu_a_src)
            2'b00:   alu_a = rd1;      // rs1
            2'b01:   alu_a = pc;       // PC  (AUIPC)
            2'b10:   alu_a = 32'b0;    // 0   (LUI: rd = 0 + imm = imm)
            default: alu_a = rd1;
        endcase
    end

    // ALU B: rs2 or immediate
    assign alu_b = alu_src ? imm_out : rd2;

    // WRITEBACK MUX
    always_comb begin
        case (wb_sel)
            2'b00:   wb_data = alu_result;    // R-type, I-type, LUI, AUIPC
            2'b01:   wb_data = mem_data_out;  // Load instructions
            2'b10:   wb_data = pc_plus4;      // JAL, JALR: return address
            default: wb_data = alu_result;
        endcase
    end

    // MODULE INSTANTIATIONS
    program_counter PC_REG (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );

    instruction_mem IMEM (
        .addr        (pc),
        .instruction (instruction)
    );

    decoder DECODE (
        .instr      (instruction),
        .alu_op     (alu_op),
        .alu_a_src  (alu_a_src),
        .alu_src    (alu_src),
        .reg_write  (reg_write),
        .mem_write  (mem_write),
        .mem_read   (mem_read),
        .mem_size   (mem_size),
        .wb_sel     (wb_sel),
        .branch     (branch),
        .branch_op  (branch_op),
        .jump       (jump),
        .jalr       (jalr)
    );

    immediate_gen IMM_GEN (
        .instr   (instruction),
        .imm_out (imm_out)
    );

    register_file REGFILE (
        .clk (clk),
        .rst (rst),
        .we  (reg_write),
        .rd  (rd_addr),
        .rs1 (rs1_addr),
        .rs2 (rs2_addr),
        .wd  (wb_data),
        .rd1 (rd1),
        .rd2 (rd2)
    );

    ALU_32bit ALU (
        .A         (alu_a),
        .B         (alu_b),
        .alu_op    (alu_op),
        .result    (alu_result),
        .zero      (alu_zero),
        .carry_out (alu_carry_out),
        .overflow  (alu_overflow),
        .negative  (alu_negative)
    );

    data_mem DMEM (
        .clk       (clk),
        .rst       (rst),
        .mem_write (mem_write),
        .mem_read  (mem_read),
        .mem_size  (mem_size),
        .addr      (alu_result),      // memory address = ALU output
        .data_in   (rd2),             // store data comes from rs2
        .data_out  (mem_data_out)
    );

endmodule