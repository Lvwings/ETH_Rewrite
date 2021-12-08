/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : eth_top.sv
 Create     : 2021-11-04 16:18:18
 Revise     : 2021-11-10 15:45:51
 Language : Verilog 2001
 -----------------------------------------------------------------------------*/

`timescale 1ns / 1ps

module eth_top #(
        //  xilinx family : Virtex-5, Virtex-6, 7-Series, Ultrascale, Spartan-6 or lower vision
        parameter   XILINX_FAMILY   = "7-series",
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
        parameter IDELAY_TAP_OPTION = "Fixed"           
    )                                                   
    (
        input               extern_clk_in,      // Clock
        input               extern_rstn_in,         // Asynchronous reset active low
    
        output              rgmii_clk_out,
    // The following ports are the RGMII physical interface: these will be at pins on the FPGA
        input   [3:0]       rgmii_rxd_in,          
        input               rgmii_rxc_in,
        input               rgmii_rx_ctl_in,

        output  [3:0]       rgmii_txd_out,
        output              rgmii_txc_out,      
        output              rgmii_tx_ctl_out,

        output              mdio_clk_out,
        output              mdio_rstn_out,  
    //  The following ports are the internal GMII connections from IOB logic to mac

        input               phy_tx_clk,
        input   [7:0]       phy_txd_in,
        input               phy_tvalid_in,
        output              phy_tready_out,
        input               phy_terr_in,        //  user port

//      output              phy_rx_clk,
        output  [7:0]       phy_rxd_out,
        output              phy_rvalid_out,
        input               phy_rready_in,
        output              phy_rerr_out        //  user port       
);

        wire                clk_locked;
                
/*------------------------------------------------------------------------------
--  clock generate
------------------------------------------------------------------------------*/

  clk_wiz_0 clk_grt
   (
    // Clock out ports
    .clk_125m(clk_125m),     // output clk_125m
    .clk_200m(clk_200m),     // output clk_200m
    .clk_25m(rgmii_clk_out),     // output clk_25m
    // Status and control signals
    .reset(!extern_rstn_in), // input reset
    .locked(clk_locked),       // output locked
   // Clock in ports
    .clk_in(extern_clk_in));      // input clk_in



   
/*------------------------------------------------------------------------------
--  phy logic
------------------------------------------------------------------------------*/   
    phy_mdio inst_phy_mdio
        (
            .rgmii_clk_in  (rgmii_clk_in),
            .sys_rst       (sys_rst),
            .mdio_clk_out  (mdio_clk_out),
            .mdio_rstn_out (mdio_rstn_out)
        );

    phy_top #(
            .XILINX_FAMILY(XILINX_FAMILY),
            .IODDR_STYLE(IODDR_STYLE),
            .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
            .IDELAY_TAP_OPTION(IDELAY_TAP_OPTION)
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

assign  rgmii_clk_in    = rgmii_clk_out;
assign  sys_rst         = !clk_locked;


endmodule : eth_top