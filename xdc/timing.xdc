#-----------------------------------------------------------
# RX Clock period Constraints              
#-----------------------------------------------------------
set rgmii_rxc       [get_clocks -of [get_ports rgmii_rxc_in]]

#-----------------------------------------------------------
# Obtain input clocks from top level XDC              
#-----------------------------------------------------------
set ip_logic_clk    [get_clocks -of [get_pins logic_clk]]

#-----------------------------------------------------------
# For Setup and Hold time analysis on RGMII inputs              
#-----------------------------------------------------------

#   rgmii rx signal cross DDR flip flop
#              _____       _____       _____       _____       ____
#    clk  ____/     \_____/     \_____/     \_____/     \_____/
#         _ _____ _____ _____ _____ _____ _____ _____ _____ _____ _
#    d    _X_D0__X_D1__X_D2__X_D3__X_D4__X_D5__X_D6__X_D7__X_D8__X_
#         _______ ___________ ___________ ___________ ___________ _
#    q1   _______X___________X____D0_____X____D2_____X____D4_____X_
#         _______ ___________ ___________ ___________ ___________ _
#    q2   _______X___________X____D1_____X____D3_____X____D5_____X_
             
# define a virtual clock to simplify the timing constraints
create_clock -name rgmii_rx_clk -period 8

# Identify RGMII Rx Pads only.  
# This prevents setup/hold analysis being performed on false inputs  
# For VSC8601 [D0 to clk rising edge] min 1.0 typical 1.8 max 2.6 

set_input_delay -clock [get_clocks $rgmii_rx_clk] -max 2.6 [get_ports {rgmii_rxd_in[*] rgmii_rx_ctl_in}]
set_input_delay -clock [get_clocks $rgmii_rx_clk] -min 1.0 [get_ports {rgmii_rxd_in[*] rgmii_rx_ctl_in}]
set_input_delay -clock [get_clocks $rgmii_rx_clk] -clock_fall -max 2.6 -add_delay [get_ports {rgmii_rxd_in[*] rgmii_rx_ctl_in}]
set_input_delay -clock [get_clocks $rgmii_rx_clk] -clock_fall -min 1.0 -add_delay [get_ports {rgmii_rxd_in[*] rgmii_rx_ctl_in}] 


