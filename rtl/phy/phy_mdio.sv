`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author 	: lwings 	https://github.com/Lvwings
 File   	: phy_mdio.sv
 Create 	: 2021-11-18 14:32:32
 Revise 	: 2021-11-18 14:35:31
 Language 	: Verilog 2001
 -----------------------------------------------------------------------------*/

 module phy_mdio (
 	input 	rgmii_clk_in,    	// Clock
 	input 	sys_rst, 		
 	output 	mdio_clk_out, 
 	output 	mdio_rstn_out
 );
 
    reg [3:0] mdc_cnt = 0;
   (* IOB = "TRUE" *)
   reg		 mdc_o	= 1'b0;

   always_ff @(posedge rgmii_clk_in) begin
   	if (mdc_cnt == 10) begin
   		mdc_cnt 	<= 0;
   		mdc_o 	<=	0;
   	end
   	else if (mdc_cnt == 5) begin
   		mdc_cnt 	<= mdc_cnt + 1;
   		mdc_o 	<= 1;		
   	end
   	else begin
         mdc_cnt 	<= mdc_cnt + 1;
         mdc_o   	<= mdc_o;
   	end
   end

   	assign 	mdio_clk_out 	= mdc_o;
	assign	mdio_rstn_out  	= 1'b1;

 endmodule : phy_mdio