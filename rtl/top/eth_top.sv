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
        parameter IODDR_STYLE       = "IODDR", 
        // Clock input style ("BUFG", "BUFR", "BUFIO")
        // Use BUFR for Virtex-6, 7-series
        // Use BUFG for Virtex-5, Spartan-6, Ultrascale
        parameter CLOCK_INPUT_STYLE = "BUFR",
        // IDELAY tap option : ("Training","Fixed")  
        // Use Training to find the range of valid tap
        // Use Fixed to fix the tap
        parameter IDELAY_TAP_OPTION = "Fixed" ,
        parameter LOCAL_IP          =   32'hC0A8_006E,
        parameter LOCAL_MAC         =   48'h00D0_0800_0002                  
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

        inout               mdio,
        output              mdio_clk_out,
        output              mdio_rstn_out
    //  The following ports are the internal GMII connections from IOB logic to mac

);

        logic                clk_locked;

        logic              phy_tx_clk;
        logic  [7:0]       phy_txd;
        logic              phy_tvalid;
        logic              phy_tready;
        logic              phy_terr;        //  user port

        logic  [7:0]       phy_rxd;
        logic              phy_rvalid;
        logic              phy_rready   =   '1;
        logic              phy_rerr;        //  user port

        logic  [7:0]       mac_tdata;
        logic              mac_tvalid;
        logic              mac_tready;
        logic              mac_tlast;        

        logic  [7:0]       mac_rdata;
        logic              mac_rvalid;
        logic              mac_rready;
        logic              mac_rlast;   

       
/*------------------------------------------------------------------------------
--  clock generate
------------------------------------------------------------------------------*/

  clk_wiz_0 clk_grt
   (
    // Clock out ports
    .clk_125m(clk_125m),     // output clk_125m
    .clk_125m90(clk_125m90),     // output clk_125m90
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

    phy_top #(
            .XILINX_FAMILY(XILINX_FAMILY),
            .IODDR_STYLE(IODDR_STYLE),
            .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
            .IDELAY_TAP_OPTION(IDELAY_TAP_OPTION)
        ) inst_phy_top (
            .clk_200m         (clk_200m),
            .sys_rst          (sys_rst),
            .rgmii_rxd_in     (rgmii_rxd_in),
            .rgmii_rxc_in     (rgmii_rxc_in),
            .rgmii_rx_ctl_in  (rgmii_rx_ctl_in),
            .rgmii_txd_out    (rgmii_txd_out),
            .rgmii_txc_out    (rgmii_txc_out),
            .rgmii_tx_ctl_out (rgmii_tx_ctl_out),
            .phy_tx_clk       (phy_tx_clk),
            .phy_tx_clk90     (phy_tx_clk90),
            .phy_txd_in       (phy_txd),
            .phy_tvalid_in    (phy_tvalid),
            .phy_tready_out   (phy_tready),
            .phy_terr_in      (phy_terr),
            .phy_rx_clk       (phy_rx_clk),
            .phy_rxd_out      (phy_rxd),
            .phy_rvalid_out   (phy_rvalid),
            .phy_rready_in    (phy_rready),
            .phy_rerr_out     (phy_rerr),
            .rgmii_clk_in     (rgmii_clk_in),
            .mdio             (mdio),
            .mdio_clk_out     (mdio_clk_out),
            .mdio_rstn_out    (mdio_rstn_out)
        );

assign  phy_tx_clk      = clk_125m;
assign  phy_tx_clk90    = clk_125m90;
assign  rgmii_clk_in    = rgmii_clk_out;
assign  sys_rst         = !clk_locked;

/*------------------------------------------------------------------------------
--  mac logic
------------------------------------------------------------------------------*/

    mac_top inst_mac_top
        (
            .logic_clk      (logic_clk),
            .logic_rst      (logic_rst),

            .phy_rx_clk     (phy_rx_clk),
            .phy_rxd_in     (phy_rxd),
            .phy_rvalid_in  (phy_rvalid),
            .phy_rerr_in    (phy_rerr),

            .mac_rdata_out  (mac_rdata),
            .mac_rvalid_out (mac_rvalid),
            .mac_rready_in  (mac_rready),
            .mac_rlast_out  (mac_rlast),

            .mac_tdata_in   (mac_tdata),
            .mac_tvalid_in  (mac_tvalid),
            .mac_tready_out (mac_tready),
            .mac_tlast_in   (mac_tlast),

            .phy_tx_clk     (phy_tx_clk),
            .phy_txd_out    (phy_txd),
            .phy_tvalid_out (phy_tvalid),
            .phy_terr_out   (phy_terr)
        );

    assign  logic_rst   =   !clk_locked;
/*------------------------------------------------------------------------------
--  network logic
------------------------------------------------------------------------------*/
    logic   [31:0]  arp_query_ip;
    logic   [47:0]  arp_response_mac;
    
    net_top #(
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC)
        ) inst_net_top (
            .logic_clk              (logic_clk),
            .logic_rst              (logic_rst),

            .net_rdata_in           (mac_rdata),
            .net_rvalid_in          (mac_rvalid),
            .net_rready_out         (mac_rready),
            .net_rlast_in           (mac_rlast),

            .net_tdata_out          (mac_tdata),
            .net_tvalid_out         (mac_tvalid),
            .net_tready_in          (mac_tready),
            .net_tlast_out          (mac_tlast),

            .trig_arp_qvalid_in     (trig_arp_qvalid),
            .trig_arp_ip_in         (trig_arp_ip),
            .trig_arp_qready_out    (trig_arp_qready),

            .arp_query_ip_in        (arp_query_ip),
            .arp_query_valid_in     (arp_query_valid),
            .arp_query_ready_out    (arp_query_ready),
            .arp_response_mac_out   (arp_response_mac),
            .arp_response_valid_out (arp_response_valid),
            .arp_response_ready_in  (arp_response_ready),
            .arp_response_err_out   (arp_response_err)
        );

    assign  logic_clk = clk_200m;

endmodule : eth_top