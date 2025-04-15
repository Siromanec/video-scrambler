`timescale 1 ps / 1 ps

module rom_scrambler_reader_tb;

reg reset_n;
reg clk;

wire [7:0] q;
wire [5:0] address;
wire reset_n_scrambler;
wire MODE;
wire [255:0] seed;

rom_scrambler_reader rom_scrambler_reader0 (
    .reset_n(reset_n),
    .clk(clk),
    .reset_n_scrambler(reset_n_scrambler),
    .MODE(MODE),
    .seed(seed),

    .q(q),
    .address(address)
);

rom_scrambler_sim rom_scrambler0 (
	.address(address),
	.clock(clk),
	.q(q));



localparam CLK_PERIOD = 2;
initial begin
      clk = 0;
      forever #(CLK_PERIOD / 2) clk = ~clk;
end
initial begin
    reset_n = 0;
    # (CLK_PERIOD);
    reset_n = 1;
    # (CLK_PERIOD * 72);
    $stop;
end
endmodule