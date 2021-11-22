/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author 	: lwings 	https://github.com/Lvwings
 File   	: tb_phy_top.sv
 Create 	: 2021-11-04 14:26:17
 Revise 	: 2021-11-04 14:41:22
 Language : Verilog 2001
 -----------------------------------------------------------------------------*/

`timescale 1ns/1ps

module tb_phy_top (); /* this is automatically generated */

	// clock
	logic clk;
	initial begin
		clk = '0;
		forever #(2.5) clk = ~clk;
	end

	// synchronous reset
	logic srstb;
	initial begin
		srstb <= '1;
		repeat(10)@(posedge clk);
		srstb <= '0;
	end

	// (*NOTE*) replace reset, clock, others

	parameter     XILINX_FAMILY = "7-series";
	parameter       IODDR_STYLE = "IODDR";
	parameter CLOCK_INPUT_STYLE = "BUFR";

	logic       sys_clk;
	logic       clk_200m;
	logic       sys_rst;
	logic [3:0] rgmii_rxd_in;
	logic       rgmii_rxc_in;
	logic       rgmii_rx_ctl_in;
	logic [3:0] rgmii_txd_out;
	logic       rgmii_txc_out;
	logic       rgmii_tx_ctl_out;
	logic       phy_tx_clk;
	logic [7:0] phy_txd_in;
	logic       phy_tvalid_in;
	logic       phy_tready_out;
	logic       phy_terr_in;
	logic       phy_rx_clk;
	logic [7:0] phy_rxd_out;
	logic       phy_rvalid_out;
	logic       phy_rready_in;
	logic       phy_rerr_out;

	phy_top #(
			.XILINX_FAMILY(XILINX_FAMILY),
			.IODDR_STYLE(IODDR_STYLE),
			.CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE)
		) inst_phy_top (
			.sys_clk          (sys_clk),
			.clk_200m         (clk_200m),
			.sys_rst          (sys_rst),
			.rgmii_rxd_in     (rgmii_rxd_in),
			.rgmii_rxc_in     (rgmii_rxc_in),
			.rgmii_rx_ctl_in  (rgmii_rx_ctl_in),
			.rgmii_txd_out    (rgmii_txd_out),
			.rgmii_txc_out    (rgmii_txc_out),
			.rgmii_tx_ctl_out (rgmii_tx_ctl_out),
			.phy_tx_clk       (phy_tx_clk),
			.phy_txd_in       (phy_txd_in),
			.phy_tvalid_in    (phy_tvalid_in),
			.phy_tready_out   (phy_tready_out),
			.phy_terr_in      (phy_terr_in),
			.phy_rx_clk       (phy_rx_clk),
			.phy_rxd_out      (phy_rxd_out),
			.phy_rvalid_out   (phy_rvalid_out),
			.phy_rready_in    (phy_rready_in),
			.phy_rerr_out     (phy_rerr_out)
		);

	assign	sys_clk  = clk;
	assign	clk_200m = clk;
	assign	sys_rst  = srstb;

	initial begin
		phy_tx_clk = '0;
		forever #(4) phy_tx_clk = ~phy_tx_clk;
	end	

	initial begin
		# 1;
		rgmii_rxc_in = '0;
		forever #(4) rgmii_rxc_in = ~rgmii_rxc_in;
	end

	logic rgmii_double_rxc;
	initial begin
		# 1;
		rgmii_double_rxc = '0;
		forever #(2) rgmii_double_rxc = ~rgmii_double_rxc;
	end	

	task init();
		rgmii_rxd_in    <= '0;
		rgmii_rx_ctl_in <= '1;
		phy_txd_in      <= '0;
		phy_tvalid_in   <= '0;
		phy_terr_in     <= '0;
		phy_rready_in   <= '1;
	endtask

	initial begin
		// do something
		init();
	end

	always_ff @(posedge rgmii_double_rxc) begin 
		rgmii_rxd_in <= rgmii_rxd_in + 1;
	end
	
	reg [7:0] txd_cnt = 0;
	always_ff @(posedge phy_tx_clk) begin 
		txd_cnt           <= txd_cnt + 1;

		if (txd_cnt > 100) begin
			phy_txd_in    <= txd_cnt;
			phy_tvalid_in <= 1;
			phy_terr_in   <= 0;
		end
		else begin
			phy_txd_in    <= 0;
			phy_tvalid_in <= 0;
			phy_terr_in   <= 1;           
		end
	end
	


endmodule
