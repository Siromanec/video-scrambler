module scrambler_mm #(
    parameter init_file = "./src/mem_config/cfg/scrambler.mif"
)
(
    input wire clk,
    input wire data_clk,
    input wire reset_n,
    input wire [9:0] bt656_stream_in,
    output wire [9:0] bt656_stream_out
);
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

    rom_scrambler rom_scrambler0 (
        .address(address),
        .clock(clk));
        defparam rom_scrambler0.init_file = init_file;

   scrambler scrambler_inst
   (
      .clk(clk) ,	// input  clk_sig
      .reset_n(reset_n_scrambler) ,	// input  reset_n_sig
      .bt656_stream_in(bt656_stream_in) ,	// input [9:0] bt656_stream_in_sig
      .seed(seed) ,	// input [255:0] seed_sig
      .bt656_stream_out(bt656_stream_out) 	// output [9:0] bt656_stream_out_sig
   );
endmodule