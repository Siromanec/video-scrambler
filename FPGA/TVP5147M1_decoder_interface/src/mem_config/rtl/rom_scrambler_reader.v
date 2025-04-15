module rom_scrambler_reader (
    input wire reset_n,
    input wire clk,
    output reg reset_n_scrambler,
    output reg MODE,
    output wire [255:0] seed,

    input wire [7:0] q,
    output reg [6:0] address
);

    localparam MODE_ADDR = 0;
    localparam SEED_ADDR_START = 32;
    localparam SEED_ADDR_END = 64;
    localparam ROM_SIZE = 64;
    localparam DELAY = 2;

    reg [7:0] seed_ram [0:31];
    reg init_done;

    assign seed = {
        seed_ram[00], seed_ram[01], seed_ram[02], seed_ram[03],
        seed_ram[04], seed_ram[05], seed_ram[06], seed_ram[07],
        seed_ram[08], seed_ram[09], seed_ram[10], seed_ram[11],
        seed_ram[12], seed_ram[13], seed_ram[14], seed_ram[15],
        seed_ram[16], seed_ram[17], seed_ram[18], seed_ram[19],
        seed_ram[20], seed_ram[21], seed_ram[22], seed_ram[23],
        seed_ram[24], seed_ram[25], seed_ram[26], seed_ram[27],
        seed_ram[28], seed_ram[29], seed_ram[30], seed_ram[31]
    };

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            init_done <= 0;
            reset_n_scrambler <= 0;
            address <= 0;
        end else begin
            if (!init_done) begin

                if (address - DELAY == MODE_ADDR) begin
                    MODE = q;
                end else if (SEED_ADDR_START <= address - DELAY && address - DELAY < SEED_ADDR_END) begin
                    seed_ram[address - DELAY - SEED_ADDR_START] <= q;
                end

                if (address - DELAY == ROM_SIZE - 1) begin
                    init_done <= 1;
                    reset_n_scrambler <= 1;
                end else begin
                    address <= address + 1;
                end
                
            end
        end
    end

    
    
endmodule