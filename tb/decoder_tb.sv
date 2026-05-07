// =============================================================
// TESTBENCH : decoder
// PURPOSE   : Verify every control signal for every opcode.
//             Special attention to:
//             - I-type alu_op bug fix (ADDI with neg imm)
//             - New signals: alu_a_src, wb_sel, jalr, branch_op
// =============================================================

//systemverilog =============================================================
// TESTBENCH : decoder
// PURPOSE   : Verify every control signal for every opcode.
// =============================================================

module decoder_tb;

    logic [31:0] instr;

    logic [3:0]  alu_op;
    logic [1:0]  alu_a_src;
    logic        alu_src;
    logic        reg_write;
    logic        mem_write;
    logic        mem_read;
    logic [2:0]  mem_size;
    logic [1:0]  wb_sel;
    logic        branch;
    logic [2:0]  branch_op;
    logic        jump;
    logic        jalr;

    decoder dut (.*);

    int pass_count = 0;
    int fail_count = 0;

    // -------------------------------------------------------
    // chk1 : for 1-bit signals
    // -------------------------------------------------------
    task automatic chk1(input string name,
                        input logic   got,
                        input logic   exp);
        if (got === exp) begin
            $display("      OK   %-12s = %0b", name, got);
            pass_count++;
        end else begin
            $display("      FAIL %-12s = %0b  (expected %0b)", name, got, exp);
            fail_count++;
        end
    endtask

    // -------------------------------------------------------
    // chk4 : for multi-bit signals (2, 3, or 4 bits)
    // -------------------------------------------------------
    task automatic chk4(input string      name,
                        input logic [3:0] got,
                        input logic [3:0] exp);
        if (got === exp) begin
            $display("      OK   %-12s = %04b", name, got);
            pass_count++;
        end else begin
            $display("      FAIL %-12s = %04b  (expected %04b)", name, got, exp);
            fail_count++;
        end
    endtask

    initial begin
        $dumpfile("waves_decoder.vcd");
        $dumpvars(0, decoder_tb);

        $display("\n====== DECODER TEST ======");

        // ---------------------------------------------------
        // 1. R-TYPE : ADD x3, x1, x2   → 0x002080B3
        // ---------------------------------------------------
        $display("\n[1] R-TYPE  ADD x3, x1, x2");
        instr = 32'h002080B3; #1;
        chk4("alu_op",    alu_op,    4'b0000);  // ADD
        chk1("alu_src",   alu_src,   1'b0);     // rs2
        chk1("reg_write", reg_write, 1'b1);
        chk1("mem_write", mem_write, 1'b0);
        chk1("mem_read",  mem_read,  1'b0);
        chk4("wb_sel",    wb_sel,    2'b00);    // ALU result

        // ---------------------------------------------------
        // 2. I-TYPE POSITIVE : ADDI x1, x0, +5   → 0x00500093
        // ---------------------------------------------------
        $display("\n[2] I-TYPE  ADDI x1, x0, +5");
        instr = 32'h00500093; #1;
        chk4("alu_op",    alu_op,    4'b0000);  // ADD
        chk1("alu_src",   alu_src,   1'b1);     // immediate
        chk1("reg_write", reg_write, 1'b1);
        chk4("wb_sel",    wb_sel,    2'b00);

        // ---------------------------------------------------
        // 3. I-TYPE NEGATIVE : ADDI x1, x0, -1   → 0xFFF00093
        //    instr[30]=1 here — part of the immediate, NOT funct7.
        //    BUG FIX: alu_op must be ADD (0000), not SUB (1000).
        // ---------------------------------------------------
        $display("\n[3] I-TYPE  ADDI x1, x0, -1  (bug-fix: must be ADD not SUB)");
        instr = 32'hFFF00093; #1;
        chk4("alu_op",    alu_op,    4'b0000);  // ADD — would be 1000 without fix
        chk1("alu_src",   alu_src,   1'b1);
        chk1("reg_write", reg_write, 1'b1);

        // ---------------------------------------------------
        // 4. LOAD : LW x5, 0(x1)   → 0x0000A283
        // ---------------------------------------------------
        $display("\n[4] LOAD  LW x5, 0(x1)");
        instr = 32'h0000A283; #1;
        chk4("alu_op",    alu_op,    4'b0000);  // ADD (address calc)
        chk1("alu_src",   alu_src,   1'b1);
        chk1("mem_read",  mem_read,  1'b1);
        chk1("mem_write", mem_write, 1'b0);
        chk1("reg_write", reg_write, 1'b1);
        chk4("wb_sel",    wb_sel,    2'b01);    // memory data

        // ---------------------------------------------------
        // 5. STORE : SW x2, 0(x1)   → 0x0020A023
        // ---------------------------------------------------
        $display("\n[5] STORE  SW x2, 0(x1)");
        instr = 32'h0020A023; #1;
        chk4("alu_op",    alu_op,    4'b0000);
        chk1("alu_src",   alu_src,   1'b1);
        chk1("mem_write", mem_write, 1'b1);
        chk1("mem_read",  mem_read,  1'b0);
        chk1("reg_write", reg_write, 1'b0);    // no writeback

        // ---------------------------------------------------
        // 6. BRANCH : BNE x10, x0, +8   → 0x00051463
        // ---------------------------------------------------
        $display("\n[6] BRANCH  BNE x10, x0, +8");
        instr = 32'h00051463; #1;
        chk1("branch",    branch,    1'b1);
        chk4("branch_op", branch_op, 3'b001);  // BNE = funct3 001
        chk4("alu_op",    alu_op,    4'b1000);  // SUB (zero flag check)
        chk1("reg_write", reg_write, 1'b0);
        chk1("jump",      jump,      1'b0);
        chk1("mem_write", mem_write, 1'b0);

        // ---------------------------------------------------
        // 7. JAL : JAL x1, 0   → 0x000000EF
        // ---------------------------------------------------
        $display("\n[7] JAL  x1, 0");
        instr = 32'h000000EF; #1;
        chk1("jump",      jump,      1'b1);
        chk1("jalr",      jalr,      1'b0);    // JAL not JALR
        chk1("reg_write", reg_write, 1'b1);
        chk4("wb_sel",    wb_sel,    2'b10);   // PC+4 (return address)
        chk1("branch",    branch,    1'b0);

        // ---------------------------------------------------
        // 8. JALR : JALR x1, 0(x2)   → 0x000100E7
        // ---------------------------------------------------
        $display("\n[8] JALR  x1, 0(x2)");
        instr = 32'h000100E7; #1;
        chk1("jump",      jump,      1'b1);
        chk1("jalr",      jalr,      1'b1);    // is JALR
        chk1("alu_src",   alu_src,   1'b1);    // rs1 + imm for target
        chk1("reg_write", reg_write, 1'b1);
        chk4("wb_sel",    wb_sel,    2'b10);   // PC+4 (return address)

        // ---------------------------------------------------
        // 9. LUI : LUI x5, 0x12345   → 0x123452B7
        // ---------------------------------------------------
        $display("\n[9] LUI  x5, 0x12345");
        instr = 32'h123452B7; #1;
        chk4("alu_a_src", alu_a_src, 2'b10);  // A = 0 (so rd = 0 + imm)
        chk1("alu_src",   alu_src,   1'b1);
        chk1("reg_write", reg_write, 1'b1);
        chk4("wb_sel",    wb_sel,    2'b00);   // ALU result
        chk1("mem_write", mem_write, 1'b0);

        // ---------------------------------------------------
        // 10. AUIPC : AUIPC x5, 0x12345   → 0x12345297
        // ---------------------------------------------------
        $display("\n[10] AUIPC  x5, 0x12345");
        instr = 32'h12345297; #1;
        chk4("alu_a_src", alu_a_src, 2'b01);  // A = PC (so rd = PC + imm)
        chk1("alu_src",   alu_src,   1'b1);
        chk1("reg_write", reg_write, 1'b1);
        chk4("wb_sel",    wb_sel,    2'b00);

        // ---------------------------------------------------
        // Summary
        // ---------------------------------------------------
        $display("\n  %0d passed,  %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("  ALL PASSED\n");
        else                 $display("  FAILURES ABOVE ^^^\n");

        $finish;
    end

endmodule
