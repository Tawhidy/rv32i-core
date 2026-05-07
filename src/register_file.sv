/*
 * 32-bit Register File with 32 registers
 * 
 * Inputs:
 * - clk: Clock signal
 * - we: Write enable signal
 * - wd: Write destination register index (5 bits)
 * - rs1: Read source register 1 index (5 bits)
 * - rs2: Read source register 2 index (5 bits)
 * - wdata: Data to be written to the register file (32 bits)
 * 
 * Outputs:
 * - rd1: Data read from source register 1 (32 bits)
 * - rd2: Data read from source register 2 (32 bits)
 */



module register_file (
    input  logic        clk,
    input  logic        rst,
    input  logic        we,         // write enable
    input  logic [4:0]  rd,         // write address
    input  logic [4:0]  rs1,        // read address port 1
    input  logic [4:0]  rs2,        // read address port 2
    input  logic [31:0] wd,         // write data

    output logic [31:0] rd1,        // read data port 1
    output logic [31:0] rd2         // read data port 2
);

    logic [31:0] regfile [0:31];    // 32 registers, each 32 bits wide


    // Asynchronous read
    // x0 is always 0 — guard both read ports explicitly for safety

    assign rd1 = (rs1 == 5'd0) ? 32'b0 : regfile[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'b0 : regfile[rs2];


    // Synchronous write with synchronous reset

    always_ff @(posedge clk) begin
        if (rst) begin
            // Zero all registers on reset (aids simulation cleanliness)
            for (int i = 0; i < 32; i++)
                //regfile[i] <= 32'b0;
                regfile[i] = 32'b0;   // blocking — required by Verilator for array loops
        end
        else if (we && (rd != 5'd0)) begin
            // x0 is hardwired to 0; never write to it
            regfile[rd] <= wd;
        end
    end

endmodule
