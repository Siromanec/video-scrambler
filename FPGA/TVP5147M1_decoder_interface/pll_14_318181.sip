set_global_assignment -entity "pll_14_318181" -library "lib_pll_14_318181" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "pll_14_318181" -library "lib_pll_14_318181" -name IP_TOOL_VERSION "23.1"
set_global_assignment -entity "pll_14_318181" -library "lib_pll_14_318181" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_pll_14_318181" -name SPD_FILE [file join $::quartus(sip_path) "pll_14_318181.spd"]

set_global_assignment -library "lib_pll_14_318181" -name MISC_FILE [file join $::quartus(sip_path) "pll_14_318181_sim/pll_14_318181.vo"]
