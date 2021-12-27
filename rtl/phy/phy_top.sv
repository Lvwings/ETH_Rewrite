/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author 	: lwings 	https://github.com/Lvwings
 File   	: phy_top.sv
 Create 	: 2021-11-03 10:42:15
 Revise 	: 2021-11-10 15:42:26
 Language : Verilog 2001
 -----------------------------------------------------------------------------*/
`timescale 1ns / 1ps

module phy_top#(
    	//	xilinx family : Virtex-5, Virtex-6, 7-Series, Ultrascale, Spartan-6 or lower vision
    	parameter	XILINX_FAMILY	= "7-series",
    	// XILINX IODDR style ("IODDR", "IODDR2")
    	// Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    	// Use IODDR2 for Spartan-6 or lower vision
    	parameter IODDR_STYLE = "IODDR", 
	    // Clock input style ("BUFG", "BUFR", "BUFIO")
	    // Use BUFR for Virtex-6, 7-series
	    // Use BUFG for Virtex-5, Spartan-6, Ultrascale
	    parameter CLOCK_INPUT_STYLE = "BUFR",
	    // IDELAY tap option : ("Training","Fixed")  
	    // Use Training to find the range of valid tap
	    // Use Fixed to fix the tap
	    parameter IDELAY_TAP_OPTION = "Training"	   	
	) 
	(
		input			clk_200m,
		input			sys_rst,
    // The following ports are the RGMII physical interface: these will be at pins on the FPGA
		input	[3:0]	rgmii_rxd_in,	
		input			rgmii_rxc_in,
		input			rgmii_rx_ctl_in,

		output	[3:0]	rgmii_txd_out,
		output			rgmii_txc_out,
		output			rgmii_tx_ctl_out,
		
	//	The following ports are the internal GMII connections from IOB logic to mac
		input			phy_tx_clk,
		input			phy_tx_clk90,
		input 	[7:0]	phy_txd_in,
		input			phy_tvalid_in,
		output			phy_tready_out,
		input			phy_terr_in,		//	user port

		output			phy_rx_clk,
		output	[7:0]	phy_rxd_out,
		output			phy_rvalid_out,
		input			phy_rready_in,
		output			phy_rerr_out,		//	user port

	//	The following ports are the internal GMII connections from IOB logic to mac
 		input 			rgmii_clk_in,    	// Clock
    	inout   		mdio, 		
 		output 			mdio_clk_out, 
 		output 			mdio_rstn_out		

);								
	logic	phy_rx_rst;
/*------------------------------------------------------------------------------
--  reset cdc
------------------------------------------------------------------------------*/
	sync_reset #(
			.SYNC_DEPTH(16)
		) inst_sync_reset (
			.sys_clk      (phy_rx_clk),
			.async_rst    (sys_rst),
			.sync_rst_out (phy_rx_rst)
		);
/*------------------------------------------------------------------------------
--  Route rgmii_rxc through a BUFIO/BUFR and onto regional clock routing
------------------------------------------------------------------------------*/
		phy_iddr_rclk #(
			.CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE)
		) inst_phy_iddr_rclk (
			.rgmii_rxc_in     (rgmii_rxc_in),
			.phy_iddr_clk_out (phy_iddr_clk_out),
			.phy_rx_clk_out   (phy_rx_clk)
		);
/*------------------------------------------------------------------------------
--  Drive input RGMII Rx signals from PADS through IODELAYS.
------------------------------------------------------------------------------*/
	logic	[3:0]	rgmii_rxd_delay;
	logic			rgmii_rx_ctl_delay;

	generate
		if (IDELAY_TAP_OPTION == "Training")
			phy_idelay_top #(
					.WIDTH(5)
				) inst_phy_idelay_top (
					.clk_200m                 (clk_200m),
					.sys_rst                  (phy_rx_rst),
					.idelay_clk_in            (phy_rx_clk),
					.signal_in                ({rgmii_rxd_in, rgmii_rx_ctl_in}),
					.signal_out               ({rgmii_rxd_delay, rgmii_rx_ctl_delay}),
					.phy_rx_clk               (phy_rx_clk),
					.phy_rxd_in               (phy_rxd_out),
					.phy_rvalid_in            (phy_rvalid_out)
				);
		else
			phy_idelay #(
				.WIDTH(5)
			) inst_phy_idelay (
				.clk_200m   (clk_200m),
				.sys_rst    (phy_rx_rst),
				.signal_in  ({rgmii_rxd_in, rgmii_rx_ctl_in}),
				.signal_out ({rgmii_rxd_delay, rgmii_rx_ctl_delay})
			);
	endgenerate
/*------------------------------------------------------------------------------
--  RGMII Receiver Logic : receive signals through IOBs from RGMII interface
------------------------------------------------------------------------------*/
	logic	rgmii_rx_ctl_reg;

		phy_iddr #(
			.IODDR_STYLE(IODDR_STYLE),
			.WIDTH(4)
		) inst_rgmii_rxd (
			.phy_clk (phy_iddr_clk_out),
			.d_in    (rgmii_rxd_delay),
			.q1_out  (phy_rxd_out[3:0]),	//	rising  edge
			.q2_out  (phy_rxd_out[7:4])		//	falling edge
		);		

		phy_iddr #(
			.IODDR_STYLE(IODDR_STYLE),
			.WIDTH(1)
		) inst_rgmii_rx_ctl (
			.phy_clk (phy_iddr_clk_out),
			.d_in    (rgmii_rx_ctl_delay),
			.q1_out  (phy_rvalid_out),
			.q2_out  (rgmii_rx_ctl_reg)
		);	

	assign	phy_rerr_out = 	phy_rvalid_out ^ rgmii_rx_ctl_reg;	
/*------------------------------------------------------------------------------
--  RGMII Transmitter Logic : drive TX signals through IOBs onto RGMII interface
------------------------------------------------------------------------------*/
	logic	rgmii_tx_ctl_reg;
	logic	rgmii_txc_outbuf;


		phy_oddr #(
			.IODDR_STYLE(IODDR_STYLE),
			.WIDTH(4)
		) inst_rgmii_txd (
			.phy_clk (phy_tx_clk),
			.d1_in   (phy_txd_in[3:0]),		//	rising  edge
			.d2_in   (phy_txd_in[7:4]),		//	falling edge
			.q_out   (rgmii_txd_out)
		);

		phy_oddr #(
			.IODDR_STYLE(IODDR_STYLE),
			.WIDTH(1)
		) inst_rgmii_tx_ctl (
			.phy_clk (phy_tx_clk),
			.d1_in   (phy_tvalid_in),
			.d2_in   (rgmii_tx_ctl_reg),
			.q_out   (rgmii_tx_ctl_out)
		);

		phy_oddr #(
			.IODDR_STYLE(IODDR_STYLE),
			.WIDTH(1)
		) inst_rgmii_txc (
			.phy_clk (phy_tx_clk90),
			.d1_in   (1),
			.d2_in   (0),
			.q_out   (rgmii_txc_outbuf)
		);

		OBUF rgmii_txc_obuf (
			.I	(rgmii_txc_outbuf),
			.O	(rgmii_txc_out)
		);

	assign	rgmii_tx_ctl_reg	= phy_tvalid_in ^ phy_terr_in;	
	assign	phy_tready_out		= 1'b1;

/*------------------------------------------------------------------------------
--  MDIO interface
------------------------------------------------------------------------------*/

    phy_mdio inst_phy_mdio
        (
            .rgmii_clk_in  (rgmii_clk_in),
            .sys_rst       (sys_rst),
            .mdio          (mdio),
            .mdio_clk_out  (mdio_clk_out),
            .mdio_rstn_out (mdio_rstn_out)
        );
endmodule : phy_top