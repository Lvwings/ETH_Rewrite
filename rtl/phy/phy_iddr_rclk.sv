/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author 	: lwings 	https://github.com/Lvwings
 File   	: phy_iddr_rclk.sv
 Create 	: 2021-11-02 16:33:28
 Revise 	: 2021-11-03 15:48:36
 Language : Verilog 2001
 -----------------------------------------------------------------------------*/

`timescale 1ns / 1ps

/*------------------------------------------------------------------------------
--  import rgmii rxc to FPGA logic
------------------------------------------------------------------------------*/

module phy_iddr_rclk #(
    // Clock input style ("BUFG", "BUFR", "BUFIO")
    // Use BUFR for Virtex-6, 7-series
    // Use BUFG for Virtex-5, Spartan-6, Ultrascale
    parameter CLOCK_INPUT_STYLE = "BUFR"
	)
	(
	//	RGMII RX
	input			rgmii_rxc_in,

	//	clk out
	output			phy_iddr_clk_out,
	output			phy_rx_clk_out
);

/*------------------------------------------------------------------------------
--  RGMII Receiver Clock Logic
------------------------------------------------------------------------------*/

	generate
		case (CLOCK_INPUT_STYLE)
			"BUFG"	: begin
					// pass through RX clock to logic
					BUFG rxc_bufg (
						.I (rgmii_rxc_in),
						.O (phy_rx_clk_out)
						);
					assign	phy_iddr_clk_out = phy_rx_clk_out;					
			end
			"BUFR"	: begin
					// Route rgmii_rxc through a BUFIO/BUFR and onto regional clock routing
					// pass through RX clock to input buffers
					BUFIO rxc_bufio(
						.I (rgmii_rxc_in),
						.O (phy_iddr_clk_out)
						);

			        // pass through RX clock to logic
			        BUFR #(
			            .BUFR_DIVIDE("BYPASS")
			        )
			        rxc_bufr (
			            .I(rgmii_rxc_in),
			            .O(phy_rx_clk_out),
			            .CE(1'b1),
			            .CLR(1'b0)
			        );						
			end
			default	: begin
					// pass through RX clock to input buffers
					BUFIO rxc_bufio(
						.I (rgmii_rxc_in),
						.O (phy_iddr_clk_out)
						);	
					// pass through RX clock to logic
					BUFG rxc_bufg (
						.I (rgmii_rxc_in),
						.O (phy_rx_clk_out)
						);						
			end
		endcase
	endgenerate

endmodule : phy_iddr_rclk