/*
    Simple Instruction Memory Module for RISC-V Processor
    - 1024 words of 32 bits each (4KB total)
    - Addressable by byte, but returns word-aligned data
    - Initialized from an external hex file (program.hex)
    The testbench for this module should verify that the instruction memory correctly returns the expected data for a given set of addresses. It should also include waveform dumping for visualization in GTKWave and display the output data for verification.
    - The testbench should cover multiple addresses to ensure that the instruction memory is functioning correctly across its entire range. It should also verify that the instruction memory correctly handles word-aligned addresses and returns the correct data for each address.
    - The testbench should also include edge cases, such as the first and last addresses of the instruction memory, to ensure that the module behaves correctly at the boundaries of its address space.
    - The testbench should also verify that the instruction memory correctly initializes its contents from the external hex file and that the data returned matches the expected values based on the contents of the hex file.
    - The testbench should also include assertions to check for correct behavior and to catch any potential issues with the instruction memory module during simulation.
*/

module instruction_mem (
    input  logic [31:0] addr,
    output logic [31:0] instruction
);

    logic [31:0] mem [0:1023];  // 1024 words × 32 bits = 4 KB

    // addr[11:2] = word index (divide byte address by 4)
    // addr[1:0]  = byte offset (always 00 for aligned instructions)
    assign instruction = mem[addr[11:2]];

    initial begin
        $readmemh("program.hex", mem);
    end

endmodule
