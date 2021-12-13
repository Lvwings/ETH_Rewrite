`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : phy_idelay_check.sv
 Create     : 2021-11-15 10:29:41
 Revise     : 2021-11-15 10:29:41
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

module phy_idelay_check(
        input           sys_rst,
        //  idelay interface
        output          idelay_ld_out,
        output          idelay_ce_out,
        output          idelay_inc_out,
        input           idealyctrl_rdy_in,
        input	[4:0]	idelay_counter_value_in,
        //  rgmii rx interface
        input           phy_rx_clk,
        input   [7:0]   phy_rxd_in,
        input           phy_rvalid_in       
    );
/*------------------------------------------------------------------------------
--  idealyctrl_rdy_in CDC
------------------------------------------------------------------------------*/
	wire	idealyctrl_rdy;	

	sync_signal #(
			.SIGNAL_WIDTH(1),
			.SYNC_DEPTH(2)
		) inst_sync_signal (
			.sys_clk    (phy_rx_clk),
			.sys_rst    (sys_rst),
			.signal_in  (idealyctrl_rdy_in),
			.signal_out (idealyctrl_rdy)
		);

/*------------------------------------------------------------------------------
--  IDELAY load IDELAY_VALUE
------------------------------------------------------------------------------*/
(* MARK_DEBUG="true" *)	reg		idelay_ld_o			= 1'b0;
	reg		idealyctrl_rdy_d	= 1'b0;				

    always_ff @(posedge phy_rx_clk) begin
    	idealyctrl_rdy_d <= idealyctrl_rdy;
        
        if (!idealyctrl_rdy && idealyctrl_rdy_d) 	//	falling edge: start IDEALY LD
        	idelay_ld_o <= 1;
        else
        	idelay_ld_o <= 0;
    end

    assign	idelay_ld_out = idelay_ld_o;
/*------------------------------------------------------------------------------
--  IDELAY ROM
	arp data 48 byte, use first 36 byte to exclude arp probe
------------------------------------------------------------------------------*/
(* MARK_DEBUG="true" *)	reg	[5:0]	idelay_rom_addr	=	6'h0;
(* MARK_DEBUG="true" *)	wire [7:0]	idelay_rom_data;

	dist_mem_gen_1 idelay_rom (
	  .a	(idelay_rom_addr),      // input wire [5 : 0] a
	  .spo	(idelay_rom_data)  		// output wire [7 : 0] spo
	);

/*------------------------------------------------------------------------------
--  DATA CHACK
------------------------------------------------------------------------------*/
(* MARK_DEBUG="true" *)	reg			flag_check_err			=	1'b0;
(* MARK_DEBUG="true" *)	reg			flag_first_hit			=	1'b0;
(* MARK_DEBUG="true" *)	reg			flag_reach_max_counter	=	1'b0;
(* MARK_DEBUG="true" *)	reg	[7:0]	phy_rxd_in_d			=	0;
(* MARK_DEBUG="true" *)	reg			flag_arp				=	1'b0;			
(* MARK_DEBUG="true" *)	reg			flag_valid_frame		=	1'b1;

	always_ff @(posedge phy_rx_clk) begin
		phy_rxd_in_d	<=	phy_rxd_in;
		
		if(phy_rvalid_in) begin
			if (idelay_rom_addr < 36) begin
				idelay_rom_addr	<=	idelay_rom_addr + 1;

				//	first time find right encode
				if (!flag_first_hit) begin
					if (idelay_rom_data == phy_rxd_in) 
						flag_check_err	<=	flag_check_err;					
					else 
						flag_check_err	<=	1;					
				end
				//	after find counter_value_min, we should find the arp frame to match rom data
				else begin					
					if (idelay_rom_addr == 6'd21 && {phy_rxd_in_d,phy_rxd_in} == 16'h0806)	// arp type
						flag_arp	<=	1;
					else 
						flag_arp	<=	flag_arp;

					if (idelay_rom_addr < 8) begin							//	leading code
						if (idelay_rom_data == phy_rxd_in) 
							flag_valid_frame	<=	flag_valid_frame;					
						else 
							flag_valid_frame	<=	0;	
					end
					else begin
						if (flag_valid_frame) begin
							if (flag_arp) begin								//	arp only valid when receive valid frame
								if (idelay_rom_data == phy_rxd_in) 
									flag_check_err	<=	flag_check_err;					
								else 
									flag_check_err	<=	1;					//	check err only valid when receive arp frame or err frame
							end
							else
								flag_check_err	<=	0;							
						end
						else begin
							flag_check_err	<=	1;	
						end						
					end
				end							
			end
			else begin
				idelay_rom_addr	<=	idelay_rom_addr;
			end
		end
		else begin
				flag_arp		<=	0;
				flag_valid_frame<=	1;
				flag_check_err	<=	0;					
				idelay_rom_addr	<=	0;			
		end
	end

/*------------------------------------------------------------------------------
--  phy rx count
------------------------------------------------------------------------------*/
(* MARK_DEBUG="true" *)	reg	[15:0]	rvalid_cnt		=	0;
	reg			phy_rvalid_d 	=	1'b0;

	always_ff @(posedge phy_rx_clk) begin 
		if (sys_rst) begin
			rvalid_cnt	<= 0;
		end
		else begin
			phy_rvalid_d <= phy_rvalid_in;
			rvalid_cnt   <= rvalid_cnt + (!phy_rvalid_d && phy_rvalid_in);			
		end
	end
	
/*------------------------------------------------------------------------------
--  counter_value
------------------------------------------------------------------------------*/
(* MARK_DEBUG="true" *)	reg	[4:0]	counter_value_min	=	0;
(* MARK_DEBUG="true" *)	reg	[4:0]	counter_value_max	=	0;
(* MARK_DEBUG="true" *)	reg			flag_turn_back		=	1'b0;
(* MARK_DEBUG="true" *)	reg			flag_check_over		=	1'b0;

	always_ff @(posedge phy_rx_clk) begin
		if (sys_rst) begin
			flag_first_hit       <=  0;
			flag_turn_back         <=  0;
			flag_check_over        <=  0;
			flag_reach_max_counter <=  0;
		end
		else begin
			// reach counter_value_min
			if ((phy_rvalid_d && !phy_rvalid_in) && !flag_check_err && !flag_first_hit) 	//	first hit
			    flag_first_hit  <=  1;              
			 else 
			    flag_first_hit  <=  flag_first_hit;

			 if ((phy_rvalid_d && !phy_rvalid_in) && flag_check_err && flag_turn_back && !flag_check_over) begin
			    flag_check_over   <=  1;
			    counter_value_min <=  idelay_counter_value_in + 1;
			 end
			 else begin
			    flag_check_over   <=  flag_check_over;
			    counter_value_min <=  counter_value_min;
			 end			 	

			 //	reach counter_value_max
			 if ((phy_rvalid_d && !phy_rvalid_in) && flag_check_err && flag_first_hit && !flag_reach_max_counter) 
			    flag_reach_max_counter <=  1;                 
			 else 
			    flag_reach_max_counter <=  flag_reach_max_counter;                

			 if ((phy_rvalid_d && !phy_rvalid_in) && !flag_check_err && flag_arp && flag_reach_max_counter && !flag_turn_back) begin
			    flag_turn_back         <= 1; 
			    counter_value_max      <= idelay_counter_value_in;
			 end
			 else begin
			    flag_turn_back         <= flag_turn_back;    
			    counter_value_max      <= counter_value_max;             
			 end
		end		 
	end
/*------------------------------------------------------------------------------
--  IDELAY INC
------------------------------------------------------------------------------*/
(* MARK_DEBUG="true" *)	reg			idelay_ce_o		=	1'b0;
(* MARK_DEBUG="true" *)	reg			idelay_inc_o	=	1'b0;

	typedef enum  reg [2:0]	{NOT_REACH_MIN, FISRT_HIT_INCREASE, OVER_MAX, TURN_BACK_DECREASE, CHECK_OVER} state;
(* MARK_DEBUG="true" *)	state idelay_state;

	always_ff @(posedge phy_rx_clk) begin 
		if (flag_check_over && !flag_check_err) begin
			idelay_ce_o			<=	0;
			idelay_inc_o		<=	0;	
			idelay_state		<= 	CHECK_OVER;	
		end
		else if ((phy_rvalid_d && !phy_rvalid_in) && flag_reach_max_counter && flag_check_err) begin	//	over counter_value_max : decrease tap
			idelay_ce_o			<=	1;
			idelay_inc_o		<=	0;
			idelay_state		<= 	OVER_MAX;	
		end
		else if ((phy_rvalid_d && !phy_rvalid_in) && flag_turn_back && !flag_check_over && flag_arp) begin	//	turn back : decrease tap
			idelay_ce_o			<=	1;
			idelay_inc_o		<=	0;
			idelay_state		<= 	TURN_BACK_DECREASE;	
		end
		else if ((phy_rvalid_d && !phy_rvalid_in) && !flag_reach_max_counter && flag_arp) begin	//	betweeen counter_value_min and counter_value_max : increase tap
			idelay_ce_o			<=	1;
			idelay_inc_o		<=	1;	
			idelay_state		<= 	FISRT_HIT_INCREASE;					
		end
		else if (!phy_rvalid_in && flag_check_err && !flag_first_hit) begin					//	not reach counter_value_min : increase tap
			idelay_ce_o			<=	1;
			idelay_inc_o		<=	1;	
			idelay_state		<= 	NOT_REACH_MIN;			
		end
		else begin
			idelay_ce_o			<=	0;
			idelay_inc_o		<=	0;			
		end
	end

	assign	idelay_ce_out 	= idelay_ce_o;
	assign	idelay_inc_out 	= idelay_inc_o;		
	
endmodule
