`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author 	: lwings 	https://github.com/Lvwings
 File   	: tb_mac_crc.sv
 Create 	: 2021-12-01 16:09:47
 Revise 	: 2021-12-07 16:28:39
 Language 	: Verilog 2001
 -----------------------------------------------------------------------------*/

module tb_mac_crc (); /* this is automatically generated */

	// clock
	logic clk;
	initial begin
		clk = '0;
		forever #(1) clk = ~clk;
	end

	// synchronous reset
	logic srstb;
	initial begin
		srstb <= '1;
		repeat(10)@(posedge clk);
		srstb <= '0;
	end

	// (*NOTE*) replace reset, clock, others

	parameter        LFSR_WIDTH = 5;
	parameter         LFSR_POLY = 5'h15;
	parameter       LFSR_CONFIG = "GALOIS";
	parameter LFSR_FEED_FORWARD = 0;
	parameter           REVERSE = 1;
	parameter        DATA_WIDTH = 8;
	parameter             STYLE = "LOOP";


	logic [DATA_WIDTH-1:0] data_in;
	logic [LFSR_WIDTH-1:0] state_in;
	logic [DATA_WIDTH-1:0] data_out;
	logic [LFSR_WIDTH-1:0] state_out;

	mac_crc #(
			.LFSR_WIDTH(LFSR_WIDTH),
			.LFSR_POLY(LFSR_POLY),
			.LFSR_CONFIG(LFSR_CONFIG),
			.LFSR_FEED_FORWARD(LFSR_FEED_FORWARD),
			.REVERSE(REVERSE),
			.DATA_WIDTH(DATA_WIDTH),
			.STYLE(STYLE)
		) inst_mac_crc (
			.data_in   (data_in),
			.state_in  (state_in),
			.data_out  (data_out),
			.state_out (state_out)
		);

	task init();
		data_in  <= '0;
		state_in <= '0;
	endtask



	initial begin
		// do something

		init();
	end

	always_ff @(posedge clk) begin
		if(srstb) begin
			state_in <= 0;
		end else begin
			state_in <= state_out;
		end
	end

	always_ff @(posedge clk) begin 
		if(srstb) begin
			data_in <= 1;
		end else begin
			data_in <= data_in << 1;
		end
	end


endmodule
