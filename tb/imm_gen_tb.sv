// =============================================================
// TESTBENCH : immediate_gen
// PURPOSE   : Verify all 5 immediate formats.
//             The J-type backward test is the critical one —
//             it catches the {11{...}} vs {12{...}} bug.
// =============================================================

module imm_gen_tb;

    logic [31:0] instr;
    logic [31:0] imm_out;

    // DUT
    immediate_gen dut (
        .instr(instr), 
        .imm_out(imm_out)
    );

    // -------------------------------------------------------
    // Scoreboard
    // -------------------------------------------------------
    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input string name, input logic [31:0] expected);
        #1;
        if (imm_out === expected) begin
            $display("  PASS | %-30s | 0x%08X", name, imm_out);
            pass_count++;
        end else begin
            $display("  FAIL | %-30s | got 0x%08X  expected 0x%08X",
                     name, imm_out, expected);
            fail_count++;
        end
    endtask

    initial begin
        $dumpfile("imm_gen_waves.vcd");          // filename — put wherever you want
        $dumpvars(0, imm_gen_tb);        // 0 = dump ALL signals, all hierarchy levels
        
        $display("\n====== IMMEDIATE GENERATOR TEST ======");

        // --- I-TYPE ---
        // ADDI x1, x0, 5   → imm = 5
        instr = 32'h00500093;
        check("I-type  +5", 32'd5);

        // ADDI x1, x0, -1  → imm = 0xFFFFFFFF
        // Also tests decoder bug: instr[30]=1 here is PART OF IMM
        instr = 32'hFFF00093;
        check("I-type  -1", 32'hFFFFFFFF);

        // --- S-TYPE ---
        // SW x2, 8(x1)  → imm = 8
        instr = 32'h0020A423;
        check("S-type  +8", 32'd8);

        // --- B-TYPE ---
        // BEQ x0, x0, +8  → imm = 8
        instr = 32'h00000463;
        check("B-type  +8", 32'd8);

        // BEQ x0, x0, -8  → imm = 0xFFFFFFF8
        instr = 32'hFE000CE3;
        check("B-type  -8", 32'hFFFFFFF8);

        // --- U-TYPE ---
        // LUI x1, 0x12345  → imm = 0x12345000
        instr = 32'h123450B7;
        check("U-type  0x12345000", 32'h12345000);

        // --- J-TYPE ---
        // JAL x0, +8  → imm = 8
        instr = 32'h0080006F;
        check("J-type  +8 (forward)", 32'd8);

        // JAL x0, -8  → imm = 0xFFFFFFF8
        // *** THIS IS THE BUG-FIX TEST ***
        // Old code ({11{...}}) gives 0x7FFFFFF8 here (WRONG)
        // Fixed code ({12{...}}) gives 0xFFFFFFF8 (CORRECT)
        instr = 32'hFF9FF06F;
        check("J-type  -8 (backward) <-- BUG FIX", 32'hFFFFFFF8);

        // --- SUMMARY ---
        $display("\n  %0d passed,  %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("  ALL PASSED\n");
        else                 $display("  FAILURES ABOVE ^^^\n");

        $finish;
    end

endmodule