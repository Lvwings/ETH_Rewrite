/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author 	: lwings 	https://github.com/Lvwings
 File   	: phy_idelay.sv
 Create 	: 2021-11-03 14:23:14
 Revise 	: 2021-11-05 15:30:27
 Language : Verilog 2001
 -----------------------------------------------------------------------------*/

`timescale 1ns / 1ps

/*------------------------------------------------------------------------------
--  set idelay for rgmii rx
------------------------------------------------------------------------------*/

module phy_idelay #(
    // Width of register in bits
    parameter WIDTH = 4    	
	)
	(
		//	idelay reference clk
		input							clk_200m,
		input							sys_rst,
		//	rgmii rx interface
		input		[WIDTH-1 : 0]	signal_in,	
		//	rgmii to phy interface
		output	[WIDTH-1 : 0]	signal_out
);


   (* IODELAY_GROUP = "RGMII_RX" *) // Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
   IDELAYCTRL IDELAYCTRL_inst (
      .RDY(),       // 1-bit output: Ready output
      .REFCLK(clk_200m), // 1-bit input: Reference clock input
      .RST(sys_rst)        // 1-bit input: Active high reset input
   );


   genvar	i;

   generate
   		for (i = 0; i < WIDTH; i = i+1) begin
		   (* IODELAY_GROUP = "RGMII_RX" *) // Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
		   IDELAYE2 #(
		      .CINVCTRL_SEL("FALSE"),          // Enable dynamic clock inversion (FALSE, TRUE)
		      .DELAY_SRC("IDATAIN"),           // Delay input (IDATAIN, DATAIN)
		      .HIGH_PERFORMANCE_MODE("FALSE"), // Reduced jitter ("TRUE"), Reduced power ("FALSE")
		      .IDELAY_TYPE("FIXED"),           // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
		      .IDELAY_VALUE(10),                // Input delay tap setting (0-31)
		      .PIPE_SEL("FALSE"),              // Select pipelined mode, FALSE, TRUE
		      .REFCLK_FREQUENCY(200.0),        // IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
		      .SIGNAL_PATTERN("DATA")          // DATA, CLOCK input signal
		   )
		   IDELAYE2_inst (
		      .CNTVALUEOUT	(), 					// 5-bit output: Counter value output
		      .DATAOUT		(signal_out[i]),         // 1-bit output: Delayed data output
		      .C				(1'b0),                 // 1-bit input: Clock input
		      .CE			(1'b0),                 // 1-bit input: Active high enable increment/decrement input
		      .CINVCTRL	(1'b0),      	 		// 1-bit input: Dynamic clock inversion input
		      .CNTVALUEIN	(5'h0),   				// 5-bit input: Counter value input
		      .DATAIN		(1'b0),           		// 1-bit input: Internal delay data input
		      .IDATAIN		(signal_in[i]),        // 1-bit input: Data input from the I/O
		      .INC			(1'b0),                 // 1-bit input: Increment / Decrement tap delay input
		      .LD			(1'b0),                 // 1-bit input: Load IDELAY_VALUE input
		      .LDPIPEEN	(1'b0),       			// 1-bit input: Enable PIPELINE register to load data input
		      .REGRST		(1'b0)            		// 1-bit input: Active-high reset tap-delay input
		   );   			
   		end
   endgenerate

endmodule : phy_idelay