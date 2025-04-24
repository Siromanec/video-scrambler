`timescale 1 ps / 1 ps

module rom_scrambler_config_reader_tb;

reg reset_n;
reg clk;

wire [7:0] q;
wire [5:0] address;
wire reset_n_scrambler;
wire mode;
wire [255:0] seed;

rom_scrambler_config_reader rom_scrambler_config_reader0 (
    .reset_n(reset_n),
    .clk(clk),
    .reset_n_scrambler(reset_n_scrambler),
    .mode(mode),
    .seed(seed),

    .q(q),
    .address(address)
);

rom_scrambler_config_sim rom_scrambler_config0 (
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