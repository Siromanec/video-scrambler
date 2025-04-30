# Create the data_clk as the base clock
create_clock -name data_clk -period 37.037 [get_ports data_clk]

# Create system clock for clk (assume 50MHz = 20ns period)
create_clock -name clk -period 20.0 [get_ports clk]

# Now specify that bt656_stream_in arrives relative to the **falling edge**
# How? Use -clock_fall option in set_input_delay

set_input_delay 6.0 -clock_fall -clock data_clk [get_ports bt656_stream_in[*]]

# Output still assumes rising edge unless you tell otherwise
set_output_delay 6.0 -clock data_clk [get_ports bt656_stream_out[*]]

# As before, treat reset_n as asynchronous
set_false_path -from [get_ports {reset_n}]

# Create clk_out as generated clock
create_generated_clock -name clk_div36  -master_clock data_clk -source [get_nets scrambler:scrambler_inst|sequence_generator:sequence_generator_inst|clk_div36:clkdiv0|clk] [get_nets {scrambler:scrambler_inst|sequence_generator:sequence_generator_inst|clk_div36:clkdiv0|clk_out}] -divide_by 36

# set_false_path -from [get_pins {rom_scrambler_config_reader.reset_n_scrambler}]

set_false_path -from [get_nets {scrambler:scrambler_inst|sync_parser:sync_parser_current|H}]

# derive PLL clocks to create the altpll0| clock referenced later
derive_pll_clocks
# derive clock uncertainty
derive_clock_uncertainty
