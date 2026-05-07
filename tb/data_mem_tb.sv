// =============================================================
// TESTBENCH : data_mem
// PURPOSE   : Verify byte-enable writes and sign/zero-ext reads.
//             Covers SW/LW, SH/LH/LHU, SB/LB/LBU.
// =============================================================

module data_mem_tb;

    logic        clk, rst;
    logic        mem_write, mem_read;
    logic [2:0]  mem_size;
    logic [31:0] addr, data_in, data_out;

    // DUT
    data_mem dut (.*);

    // 10 MHz clock
    always #5 clk = ~clk;

    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input string name, input logic [31:0] expected);
        if (data_out === expected) begin
            $display("  PASS | %-30s | 0x%08X", name, data_out);
            pass_count++;
        end else begin
            $display("  FAIL | %-30s | got 0x%08X  expected 0x%08X",
                     name, data_out, expected);
            fail_count++;
        end
    endtask

    // Helper: do a 1-cycle write, then read back
    task automatic write_word(input [31:0] a, input [31:0] d, input [2:0] sz);
        @(negedge clk);
        addr      = a;
        data_in   = d;
        mem_write = 1;
        mem_read  = 0;
        mem_size  = sz;
        @(posedge clk); #1;   // write commits on rising edge
        mem_write = 0;
    endtask

    task automatic read_word(input [31:0] a, input [2:0] sz);
        @(negedge clk);
        addr     = a;
        mem_read = 1;
        mem_size = sz;
        #1;                   // combinational — data_out valid immediately
    endtask

    initial begin

        $dumpfile("waves_data_mem.vcd");
        $dumpvars(0, data_mem_tb);

        // Init
        clk = 0; rst = 1; mem_write = 0; mem_read = 0;
        addr = 0; data_in = 0; mem_size = 3'b010;

        repeat(2) @(posedge clk); rst = 0;

        $display("\n====== DATA MEMORY TEST ======");

        // ---------------------------------------------------
        // TEST 1: SW / LW  (full word)
        // Write 0xDEADBEEF to address 0x100, read back
        // ---------------------------------------------------
        $display("\n[1] SW / LW at addr=0x100");
        write_word(32'h100, 32'hDEADBEEF, 3'b010);   // SW
        read_word(32'h100, 3'b010);                    // LW
        check("LW 0xDEADBEEF", 32'hDEADBEEF);

        mem_read = 0;

        // ---------------------------------------------------
        // TEST 2: SH / LH / LHU  (lower halfword)
        // Write 0xABCD to lower halfword of address 0x200.
        // LH  should sign-extend (bit15=1) → 0xFFFFABCD
        // LHU should zero-extend           → 0x0000ABCD
        // ---------------------------------------------------
        $display("\n[2] SH / LH / LHU at addr=0x200");
        write_word(32'h200, 32'h0000ABCD, 3'b001);    // SH (lower)
        read_word(32'h200, 3'b001);
        check("LH  0xFFFFABCD (signed)", 32'hFFFFABCD);
        read_word(32'h200, 3'b101);
        check("LHU 0x0000ABCD (unsigned)", 32'h0000ABCD);

        mem_read = 0;

        // ---------------------------------------------------
        // TEST 3: SB / LB / LBU  (byte at offset 1)
        // Write 0xFF to byte address 0x301 (word=0x300, byte_offset=1)
        // LB  should sign-extend → 0xFFFFFFFF
        // LBU should zero-extend → 0x000000FF
        // ---------------------------------------------------
        $display("\n[3] SB / LB / LBU at addr=0x301 (byte offset 1)");
        write_word(32'h301, 32'h000000FF, 3'b000);    // SB
        read_word(32'h301, 3'b000);
        check("LB  0xFFFFFFFF (signed)", 32'hFFFFFFFF);
        read_word(32'h301, 3'b100);
        check("LBU 0x000000FF (unsigned)", 32'h000000FF);

        mem_read = 0;

        // ---------------------------------------------------
        // TEST 4: Verify SB only touched byte 1, not byte 0 or 2
        // Word at 0x300 should have: byte0=0x00, byte1=0xFF, byte2=0x00, byte3=0x00
        // ---------------------------------------------------
        $display("\n[4] Check SB did not corrupt adjacent bytes");
        read_word(32'h300, 3'b010);                   // LW
        check("LW word = 0x0000FF00", 32'h0000FF00);

        mem_read = 0;

        // --- SUMMARY ---
        $display("\n  %0d passed,  %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("  ALL PASSED\n");
        else                 $display("  FAILURES ABOVE ^^^\n");

        $finish;
    end

endmodule