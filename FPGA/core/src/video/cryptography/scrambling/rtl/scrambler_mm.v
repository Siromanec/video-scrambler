// `define DEBUG
module scrambler_mm #(
    parameter init_file = "./src/mem_config/cfg/config.mif"
)
(
`ifdef DEBUG
    output wire [9:0] bt656_stream_in_delayed_out_debug,
    output wire [9:0] bt656_stream_switch_out_debug,
    output wire V_debug,
    output wire H_debug,
    output wire [7:0] raw_cut_position_out_debug,
    output wire SEQUENCE_GENERATOR_ENABLE_debug,
    output wire SEQUENCE_GENERATOR_LOAD_debug,
`endif
    input wire clk,
    (* useioff = 1 *) input wire data_clk,
    input wire reset_n,
    (* useioff = 1 *) input wire [9:0] bt656_stream_in,
    (* useioff = 1 *) output wire [9:0] bt656_stream_out

);
    wire [7:0] q;
    wire [5:0] address;
    wire reset_n_scrambler;
    wire mode;
    wire [255:0] seed;

    /* CONFIG ROM READER */
    rom_scrambler_config_reader rom_scrambler_config_reader0 (
        .reset_n(reset_n),
        .clk(clk),
        .reset_n_scrambler(reset_n_scrambler),
        .mode(mode),
        .seed(seed),
        .q(q),
        .address(address)
    );
    /* CONFIG ROM*/
    rom_scrambler_config rom_scrambler_config0 (
		  .q(q),
        .address(address),
        .clock(clk));
        defparam rom_scrambler_config0.init_file = init_file;

    /* SCRAMBLER*/
   scrambler scrambler_inst
   (
`ifdef DEBUG
    .bt656_stream_in_delayed_out_debug(bt656_stream_in_delayed_out_debug),
    .bt656_stream_switch_out_debug(bt656_stream_switch_out_debug),
    .V_debug(V_debug),
    .H_debug(H_debug),
    .raw_cut_position_out_debug(raw_cut_position_out_debug),
    .SEQUENCE_GENERATOR_ENABLE_debug(SEQUENCE_GENERATOR_ENABLE_debug),
    .SEQUENCE_GENERATOR_LOAD_debug(SEQUENCE_GENERATOR_LOAD_debug),
`endif 
      .clk(clk) ,	// input  clk_sig
      .reset_n(reset_n && reset_n_scrambler) ,	// input  reset_n_sig
      .bt656_stream_in(bt656_stream_in) ,	// input [9:0] bt656_stream_in_sig
      .seed(seed) ,	// input [255:0] seed_sig
      .bt656_stream_out(bt656_stream_out), // output [9:0] bt656_stream_out_sig
		(* keep = "true" *).mode(mode)
   );
   
endmodule