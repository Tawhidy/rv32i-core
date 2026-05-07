/*
    Simple Program Counter (PC) module for a RISC-V processor.
    The PC increments by 4 on each clock cycle to point to the next instruction.
    On reset, the PC is set to 0.
    - The testbench for this module should verify that the PC increments correctly on each clock cycle and resets to 0 when the reset signal is asserted.
    - The testbench should also include waveform dumping for visualization in GTKWave.
    - The testbench should display the value of the PC at each step for verification.
    - The testbench should cover multiple clock cycles to ensure the PC increments correctly over time.
    - The testbench should also verify that the PC does not increment when the reset signal is asserted.
*/

module program_counter (
    input  logic        clk,
    input  logic        rst,
    input  logic [31:0] pc_next,   // computed by cpu_top

    output logic [31:0] pc         // current PC, stable for the whole cycle
);

    always_ff @(posedge clk) begin
        if (rst)
            pc <= 32'h0000_0000;
        else
            pc <= pc_next;
    end

endmodule
