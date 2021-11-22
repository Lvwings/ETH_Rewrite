`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author 	: lwings 	https://github.com/Lvwings
 File   	: phy_idelay_top.sv
 Create 	: 2021-11-15 14:33:28
 Revise 	: 2021-11-16 09:15:08
 Language 	: Verilog 2001
 -----------------------------------------------------------------------------*/

 module phy_idelay_top #(
    // Width of register in bits
    parameter WIDTH = 4     
    )
    (
        //  idelay reference clk
        input                         clk_200m,
        input                         sys_rst,
        //  idelay interface
        input                         idelay_clk_in,

        //  rgmii rx interface
        input   [WIDTH-1 : 0]         signal_in,  
        //  rgmii to phy interface
        output  [WIDTH-1 : 0]         signal_out,

        //  rgmii rx interface
        input           phy_rx_clk,
        input   [7:0]   phy_rxd_in,
        input           phy_rvalid_in 
    );

    wire	[4:0]	idelay_counter_value_in, idelay_counter_value_out;
    
	phy_idelay_check inst_phy_idelay_check
		(
			.sys_rst                 (sys_rst),
			.idelay_ld_out           (idelay_ld_out),
			.idelay_ce_out           (idelay_ce_out),
			.idelay_inc_out          (idelay_inc_out),
			.idealyctrl_rdy_in       (idealyctrl_rdy_in),
			.idelay_counter_value_in (idelay_counter_value_in),
			.phy_rx_clk              (phy_rx_clk),
			.phy_rxd_in              (phy_rxd_in),
			.phy_rvalid_in           (phy_rvalid_in)
		);


	phy_idelay_training #(
			.WIDTH(WIDTH)
		) inst_phy_idelay_training (
			.clk_200m                 (clk_200m),
			.sys_rst                  (sys_rst),
			.idelay_clk_in            (idelay_clk_in),
			.idelay_ld_in             (idelay_ld_in),
			.idelay_ce_in             (idelay_ce_in),
			.idelay_inc_in            (idelay_inc_in),
			.idelayctrl_rdy_out       (idelayctrl_rdy_out),
			.signal_in                (signal_in),
			.signal_out               (signal_out),
			.idelay_counter_value_out (idelay_counter_value_out)
		);


 	assign	idelay_ld_in = idelay_ld_out;
 	assign	idelay_ce_in = idelay_ce_out;
 	assign	idelay_inc_in = idelay_inc_out;

 	assign 	idealyctrl_rdy_in = idelayctrl_rdy_out;
 	assign	idelay_counter_value_in = idelay_counter_value_out;

 endmodule : phy_idelay_top