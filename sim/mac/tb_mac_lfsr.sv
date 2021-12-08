`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author 	: lwings 	https://github.com/Lvwings
 File   	: tb_mac_lfsr.sv
 Create 	: 2021-12-07 11:12:15
 Revise 	: 2021-12-08 10:21:51
 Language 	: Verilog 2001
 -----------------------------------------------------------------------------*/

module tb_mac_lfsr (); /* this is automatically generated */

	// clock
	logic clk;
	initial begin
		clk = '0;
		forever #(2) clk = ~clk;
	end

	// synchronous reset
	logic srstb;
	initial begin
		srstb <= '1;
		repeat(10)@(posedge clk);
		srstb <= '0;
	end

	// (*NOTE*) replace reset, clock, others

	parameter                          LFSR_WIDTH = 4;
	parameter                           LFSR_POLY = 4'h3;
	parameter                         LFSR_CONFIG = "GALOIS";
	parameter                   LFSR_FEED_FORWARD = 0;
	parameter                             REVERSE = 1;
	parameter                          DATA_WIDTH = 8;

	logic                    rst;
	logic [DATA_WIDTH-1 : 0] data_in;
	logic [DATA_WIDTH-1 : 0] data_out;
	logic [LFSR_WIDTH-1 : 0] lfsr_initial_state_in;
	logic [LFSR_WIDTH-1 : 0] lfsr_state_out;

	mac_lfsr #(
			.LFSR_WIDTH(LFSR_WIDTH),
			.LFSR_POLY(LFSR_POLY),
			.LFSR_CONFIG(LFSR_CONFIG),
			.LFSR_FEED_FORWARD(LFSR_FEED_FORWARD),
			.REVERSE(REVERSE),
			.DATA_WIDTH(DATA_WIDTH)
		) inst_mac_lfsr (
			.clk                   (clk),
			.rst                   (rst),
			.data_in               (data_in),
			.data_out              (data_out),
			.lfsr_initial_state_in (lfsr_initial_state_in),
			.lfsr_state_out        (lfsr_state_out)
		);


		assign rst = srstb;


	initial begin
		// do something

		lfsr_initial_state_in 	= 	0;
	end

	always_ff @(posedge clk) begin 
		if(rst) begin
			data_in <= 1;
		end else begin
			data_in <= data_in << 1;
		end
	end


endmodule
