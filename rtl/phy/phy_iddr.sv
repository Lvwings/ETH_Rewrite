/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author 	: lwings 	https://github.com/Lvwings
 File   	: phy_iddr.sv
 Create 	: 2021-11-02 10:54:03
 Revise 	: 2021-11-03 15:46:37
 Language : Verilog 2001
 -----------------------------------------------------------------------------*/

`timescale 1ns / 1ps

/*------------------------------------------------------------------------------
--  phy use RGMII interface
------------------------------------------------------------------------------*/

module phy_iddr#(
    // XILINX IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6 or lower vision
    parameter IODDR_STYLE = "IODDR",
    // Width of register in bits
    parameter WIDTH = 4    
    )
    (
        input                   phy_clk,
        input   [WIDTH-1 : 0]   d_in, 
        output  [WIDTH-1 : 0]   q1_out,
        output  [WIDTH-1 : 0]   q2_out           
    );

/*
Provides a consistent input DDR flip flop across multiple FPGA families
              _____       _____       _____       _____       ____
    clk  ____/     \_____/     \_____/     \_____/     \_____/
         _ _____ _____ _____ _____ _____ _____ _____ _____ _____ _
    d    _X_D0__X_D1__X_D2__X_D3__X_D4__X_D5__X_D6__X_D7__X_D8__X_
         _______ ___________ ___________ ___________ ___________ _
    q1   _______X___________X____D0_____X____D2_____X____D4_____X_
         _______ ___________ ___________ ___________ ___________ _
    q2   _______X___________X____D1_____X____D3_____X____D5_____X_
*/

genvar	i;

generate
		for (i = 0; i < WIDTH; i = i + 1) begin
			 // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
			if (IODDR_STYLE == "IODDR") begin
				   IDDR #(
				      .DDR_CLK_EDGE	("SAME_EDGE_PIPELINED"), 	// "OPPOSITE_EDGE", "SAME_EDGE" or "SAME_EDGE_PIPELINED"    
				      .INIT_Q1		(1'b0), 					// Initial value of Q1: 1'b0 or 1'b1
				      .INIT_Q2		(1'b0), 					// Initial value of Q2: 1'b0 or 1'b1
				      .SRTYPE		("ASYNC") 					// Set/Reset type: "SYNC" or "ASYNC" 
				   ) IDDR_inst (
				      .Q1			(q1_out[i]), 				// 1-bit output for positive edge of clock
				      .Q2			(q2_out[i]), 				// 1-bit output for negative edge of clock
				      .C			(phy_clk),   				// 1-bit clock input
				      .CE			(1'b1), 					// 1-bit clock enable input
				      .D			(d_in[i]),   				// 1-bit DDR data input
				      .R			(1'b0),   					// 1-bit reset
				      .S			(1'b0)    					// 1-bit set
				   );
			end
			else begin
				// Use IODDR2 for Spartan-6 or lower vision
				    IDDR2 #(
		                .DDR_ALIGNMENT("C0")
		            )
		            iddr_inst (
		                .Q0			(q1_out[i]),
		                .Q1			(q2_out[i]),
		                .C0			(phy_clk),
		                .C1			(~phy_clk),
		                .CE			(1'b1),
		                .D			(d_in[i]),
		                .R			(1'b0),
		                .S			(1'b0)
		            );
			end
		end
endgenerate


    
endmodule // phy_iddr