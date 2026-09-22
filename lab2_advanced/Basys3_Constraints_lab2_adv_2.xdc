## Basys3 rev B constraints for Lab 2 Advanced, Part 2

## 100 MHz clock
set_property PACKAGE_PIN W5 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} [get_ports clk]

## SW7-SW0: switch_input[7:0]
set_property PACKAGE_PIN V17 [get_ports {switch_input[0]}]
set_property PACKAGE_PIN V16 [get_ports {switch_input[1]}]
set_property PACKAGE_PIN W16 [get_ports {switch_input[2]}]
set_property PACKAGE_PIN W17 [get_ports {switch_input[3]}]
set_property PACKAGE_PIN W15 [get_ports {switch_input[4]}]
set_property PACKAGE_PIN V15 [get_ports {switch_input[5]}]
set_property PACKAGE_PIN W14 [get_ports {switch_input[6]}]
set_property PACKAGE_PIN W13 [get_ports {switch_input[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {switch_input[*]}]

## SW13-SW12: input type, SW14: valid, SW15: reset
set_property PACKAGE_PIN W2 [get_ports {switch_inputtype[0]}]
set_property PACKAGE_PIN U1 [get_ports {switch_inputtype[1]}]
set_property PACKAGE_PIN T1 [get_ports valid]
set_property PACKAGE_PIN R2 [get_ports rst]
set_property IOSTANDARD LVCMOS33 [get_ports {switch_inputtype[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports valid]
set_property IOSTANDARD LVCMOS33 [get_ports rst]

## LD3-LD0: best-fit mask
set_property PACKAGE_PIN U16 [get_ports {out[0]}]
set_property PACKAGE_PIN E19 [get_ports {out[1]}]
set_property PACKAGE_PIN U19 [get_ports {out[2]}]
set_property PACKAGE_PIN V19 [get_ports {out[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {out[*]}]

## LD9-LD4: best-fit sum
set_property PACKAGE_PIN W18 [get_ports {sum[0]}]
set_property PACKAGE_PIN U15 [get_ports {sum[1]}]
set_property PACKAGE_PIN U14 [get_ports {sum[2]}]
set_property PACKAGE_PIN V14 [get_ports {sum[3]}]
set_property PACKAGE_PIN V13 [get_ports {sum[4]}]
set_property PACKAGE_PIN V3 [get_ports {sum[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {sum[*]}]

## LD15: exact match
set_property PACKAGE_PIN L1 [get_ports exact]
set_property IOSTANDARD LVCMOS33 [get_ports exact]

## Basys3 configuration bank voltage (same as the course board)
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]

