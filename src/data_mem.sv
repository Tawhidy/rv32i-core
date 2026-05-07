/*
@file data_mem.sv
Data Memory Module for RISC-V Processor
@author [Tawhid Alam]
@date 2024-05-10
@description
- Implements a 4 KB data memory (1024 words × 32 bits)
- Supports byte, halfword, and word accesses with proper sign/zero extension for loads
- Supports byte-lane selective writes for stores
- Synchronous write operations on the rising edge of the clock
- Asynchronous read operations with combinational logic for load data generation
- The testbench for this module should verify that the data memory correctly handles various load and store operations, including edge cases such as unaligned accesses and boundary conditions. It should also include waveform dumping for visualization in GTKWave and display the output data for verification.
- The testbench should cover multiple scenarios, such as storing and loading bytes, halfwords,
and words, as well as verifying that the correct sign or zero extension is applied for load operations. It should also verify that the byte-lane selective writes are functioning correctly by checking the contents of the memory after various store operations.
*/



module data_mem (
    input  logic        clk,
    input  logic        rst,
    input  logic        mem_write,
    input  logic        mem_read,
    input  logic [2:0]  mem_size,
    input  logic [31:0] addr,
    input  logic [31:0] data_in,
    output logic [31:0] data_out
);

    logic [31:0] mem [0:1023];

    logic [9:0] word_addr;
    logic [1:0] byte_offset;

    assign word_addr   = addr[11:2];
    assign byte_offset = addr[1:0];

    // =========================================================================
    // WRITE — synchronous
    // RISC-V rule: store data is ALWAYS in the lower bits of rs2 (data_in).
    //   SB: byte  to write is in data_in[7:0]  — route to selected byte lane
    //   SH: half  to write is in data_in[15:0] — route to selected halfword
    //   SW: word  to write is in data_in[31:0] — write all 4 bytes directly
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 1024; i++)
                mem[i] = 32'b0;
        end else if (mem_write) begin
            case (mem_size[1:0])

                // SB — always read from data_in[7:0]
                2'b00: case (byte_offset)
                    2'b00: mem[word_addr][ 7: 0] = data_in[7:0];
                    2'b01: mem[word_addr][15: 8] = data_in[7:0];
                    2'b10: mem[word_addr][23:16] = data_in[7:0];
                    2'b11: mem[word_addr][31:24] = data_in[7:0];
                endcase

                // SH — always read from data_in[15:0]
                2'b01: if (byte_offset[1] == 1'b0)
                    mem[word_addr][15: 0] = data_in[15:0];   // lower halfword
                else
                    mem[word_addr][31:16] = data_in[15:0];   // upper halfword

                // SW — full word
                default: mem[word_addr] = data_in;

            endcase
        end
    end

    // =========================================================================
    // READ — asynchronous (combinational), with sign/zero extension
    // =========================================================================
    logic [31:0] raw_word;
    assign raw_word = mem[word_addr];

    always_comb begin
        data_out = 32'b0;
        if (mem_read) begin
            case (mem_size)
                3'b000: case (byte_offset)          // LB  signed
                    2'b00: data_out = {{24{raw_word[ 7]}}, raw_word[ 7: 0]};
                    2'b01: data_out = {{24{raw_word[15]}}, raw_word[15: 8]};
                    2'b10: data_out = {{24{raw_word[23]}}, raw_word[23:16]};
                    2'b11: data_out = {{24{raw_word[31]}}, raw_word[31:24]};
                endcase
                3'b001: data_out = byte_offset[1]   // LH  signed
                    ? {{16{raw_word[31]}}, raw_word[31:16]}
                    : {{16{raw_word[15]}}, raw_word[15: 0]};
                3'b010: data_out = raw_word;         // LW
                3'b100: case (byte_offset)           // LBU unsigned
                    2'b00: data_out = {24'b0, raw_word[ 7: 0]};
                    2'b01: data_out = {24'b0, raw_word[15: 8]};
                    2'b10: data_out = {24'b0, raw_word[23:16]};
                    2'b11: data_out = {24'b0, raw_word[31:24]};
                endcase
                3'b101: data_out = byte_offset[1]   // LHU unsigned
                    ? {16'b0, raw_word[31:16]}
                    : {16'b0, raw_word[15: 0]};
                default: data_out = raw_word;
            endcase
        end
    end

endmodule
