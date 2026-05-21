create_clock -name CLK125 -period 8 -waveform {0 4} [get_ports {clk}] -add

derive_pll_clocks -use_tan_name