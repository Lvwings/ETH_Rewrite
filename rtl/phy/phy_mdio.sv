`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author  : lwings    https://github.com/Lvwings
 File    : phy_mdio.sv
 Create  : 2021-11-18 14:32:32
 Revise  : 2021-12-24 15:18:03
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module phy_mdio (
 	input 	rgmii_clk_in,    	// Clock
 	input 	sys_rst,
   inout    mdio, 		
 	output 	mdio_clk_out, 
 	output 	mdio_rstn_out
 );
 
    logic [3:0] mdc_cnt = '0; // 2.5MHz
   (* IOB = "TRUE" *)   logic		 mdc_o	= 1'b0;

/*------------------------------------------------------------------------------
--  MDC
------------------------------------------------------------------------------*/
   always_ff @(posedge rgmii_clk_in) begin
   	if (mdc_cnt == 4) begin
   		mdc_cnt 	<= 0;
   		mdc_o 	<=	~mdc_o;
   	end
   	else begin
         mdc_cnt 	<= mdc_cnt + 1;
         mdc_o   	<= mdc_o;
   	end
   end

   // Route through the MDC clock
  OBUF mdc_obuf_i (
     .I              (mdc_o),
     .O              (mdio_clk_out)
  );
/*------------------------------------------------------------------------------
--  MRST
------------------------------------------------------------------------------*/
   (* IOB = "TRUE" *)   logic     mdrst_o   = 1'b0;
   always_ff @(posedge rgmii_clk_in or posedge sys_rst) begin 
      if(sys_rst) begin
         mdrst_o <= 0;
      end else begin
         mdrst_o <= 1;
      end
   end

   assign   mdio_rstn_out     = mdrst_o;
/*------------------------------------------------------------------------------
--  MDIO
------------------------------------------------------------------------------*/
   localparam  [31:0]   MDIO_PRE       =  32'hFFFF_FFFF;
   localparam  [15:0]   MDIO_WRITE     =  16'h5002;
   localparam  [15:0]   CONTROL_WORD   =  16'h1140;
   localparam  [63:0]   MDIO_DATA      =  {MDIO_PRE, MDIO_WRITE, CONTROL_WORD};

   logic                mdio_o         =  '0;
   logic                mdio_en        =  '0;
   logic       [5:0]    mdio_cnt       =  '1;
   logic                mdio_initial   =  '0;
   logic                mdio_t;

   always_ff @(negedge mdc_o) begin 
      if(!mdrst_o) begin
         mdio_cnt       <= '1;
         mdio_o         <= '0;
         mdio_en        <= '0;
         mdio_initial   <= '0;
      end else begin     

         if (mdio_initial) begin
            mdio_o   <= '0;
            mdio_en  <= '0;
            mdio_cnt <= '0;
         end
         else begin
            mdio_cnt <= mdio_cnt - !mdio_initial;
            mdio_o   <= MDIO_DATA[mdio_cnt];
            mdio_en  <= 1;
         end

         mdio_initial   <= (mdio_cnt == 0) ? 1 : mdio_initial;
      end
   end

   assign   mdio_t   =  ~mdio_en;

  IOBUF mdio_iobuf (
     .I              (mdio_o),
     .IO             (mdio),
     .O              (mdio_i),
     .T              (mdio_t)
  );
 endmodule : phy_mdio