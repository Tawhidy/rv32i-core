// =============================================================
// TESTBENCH : cpu_top  (full integration)
// PURPOSE   : Run the Fibonacci program. After the loop:
//               x1 = fib(10) = 55   stored to DMEM[0]
//               x2 = fib(11) = 89   stored to DMEM[1]
// PROGRAM   : program.hex (see below)
//
// COMPILE WITH: --public-flat-rw  (so we can read internal state)
// =============================================================

module cpu_top_tb;

    logic clk, rst;

    // DUT
    cpu_top dut (.clk(clk), .rst(rst));

    // 10 MHz clock
    always #5 clk = ~clk;

    // Cycle counter
    int cycle = 0;
    always @(posedge clk) cycle++;

    int pass_count = 0;
    int fail_count = 0;

    task automatic check(input string name,
                         input logic [31:0] got,
                         input logic [31:0] expected);
        if (got === expected) begin
            $display("  PASS | %-25s | got %0d (0x%08X)", name, got, got);
            pass_count++;
        end else begin
            $display("  FAIL | %-25s | got %0d (0x%08X)  expected %0d (0x%08X)",
                     name, got, got, expected, expected);
            fail_count++;
        end
    endtask

    initial begin

        $dumpfile("waves_cpu_top.vcd");
        $dumpvars(0, cpu_top_tb);

        $display("\n====== CPU INTEGRATION TEST (Fibonacci) ======");
        $display("Program: 10 iterations, expects x1=55, x2=89\n");

        // Reset for 3 cycles
        clk = 0; rst = 1;
        repeat(3) @(posedge clk);
        rst = 0;

        @(posedge clk); #1;
        $display("DEBUG: instruction at mem[0] = 0x%08X", dut.IMEM.mem[0]);
        $display("DEBUG: instruction at mem[1] = 0x%08X", dut.IMEM.mem[1]);

        // ---------------------------------------------------------
        // Cycle monitor: print PC and register writes as they happen
        // ---------------------------------------------------------
        $display("  Cycle | PC     | Instruction | rd  | wb_data");
        $display("  ------+--------+-------------+-----+--------");

        // Run for 80 cycles — program finishes around cycle 56
        repeat(80) begin
            @(posedge clk); #1;

            // Print register write on every cycle where reg_write is asserted
            if (dut.reg_write && dut.rd_addr != 5'd0) begin
                $display("  %4d  | 0x%04X | 0x%08X  | x%-2d | 0x%08X",
                    cycle,
                    dut.pc,
                    dut.instruction,
                    dut.rd_addr,
                    dut.wb_data);
            end
        end

        // ---------------------------------------------------------
        // Check results in DATA MEMORY
        // SW instructions write x1→mem[0], x2→mem[1]
        // ---------------------------------------------------------
        $display("\n--- Checking data memory after 80 cycles ---");
        check("DMEM[0] = x1 = fib(10) = 55", dut.DMEM.mem[0], 32'd55);
        check("DMEM[1] = x2 = fib(11) = 89", dut.DMEM.mem[1], 32'd89);

        // Also check register file directly
        $display("\n--- Checking register file ---");
        check("x1  = 55",  dut.REGFILE.regfile[1],  32'd55);
        check("x2  = 89",  dut.REGFILE.regfile[2],  32'd89);
        check("x10 = 0 (counter exhausted)", dut.REGFILE.regfile[10], 32'd0);
        check("x0  = 0 (hardwired zero)",    dut.REGFILE.regfile[0],  32'd0);

        // --- SUMMARY ---
        $display("\n  %0d passed,  %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("  CPU IS WORKING — FIBONACCI CORRECT\n");
        else                 $display("  FAILURES ABOVE ^^^\n");

        $finish;
    end

endmodule
