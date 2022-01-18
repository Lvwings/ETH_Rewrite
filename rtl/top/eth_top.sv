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
        parameter   XILINX_FAMILY       = "7-series",
        // XILINX IODDR style ("IODDR", "IODDR2")
        // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
        // Use IODDR2 for Spartan-6 or lower vision
        parameter IODDR_STYLE           = "IODDR", 
        // Clock input style ("BUFG", "BUFR", "BUFIO")
        // Use BUFR for Virtex-6, 7-series
        // Use BUFG for Virtex-5, Spartan-6, Ultrascale
        parameter CLOCK_INPUT_STYLE     = "BUFR",
        // IDELAY tap option : ("Training","Fixed")  
        // Use Training to find the range of valid tap
        // Use Fixed to fix the tap
        parameter IDELAY_TAP_OPTION     = "Fixed" ,
        parameter LOCAL_IP              =   32'hC0A8_006E,
        parameter LOCAL_MAC             =   48'h00D0_0800_0002,
        parameter LOCAL_SP              =   16'd8080,
        parameter LOCAL_DP              =   16'd8080,
        //  FIFO parameter   
        parameter FIFO_DEPTH            =   512,                    //  Range: 16 - 4194304. Default value = 2048.   
        parameter FIFO_MEMORY_TYPE      =   "auto",                 //  auto, block, distributed, ultra. Default value = auto
        parameter FIFO_PACKET           =   "true",                 //  false, true. Default value = false.
    
        parameter TDATA_WIDTH           =   8,                      //  Range: 8 - 2048. Default value = 32.  
                                                                    //  NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits.                                                                 
    
        parameter USE_ADV_FEATURES      =   "0000",                 //  Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 0    
                                                                    //  Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 0           
                                                                    //  Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0    
                                                                    //  Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 0     
                                                                    //  Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 0    
                                                                    //  Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0    
        parameter PROG_EMPTY_THRESH     =   10,                     //  Range: 5 - 4194301. Default value = 10. 
        parameter PROG_FULL_THRESH      =   10,                     //  Range: 5 - 4194301. Default value = 10. 
        parameter WR_DATA_COUNT_WIDTH   =   1,                      //  Range: 1 - 23. Default value = 1.      
        parameter RD_DATA_COUNT_WIDTH   =   1,                      //  Range: 1 - 23. Default value = 1.
        parameter ECC_MODE              =   "no_ecc",               //  no_ecc, en_ecc. Default value = no_ecc.  
        parameter CDC_SYNC_STAGES       =   2                       //  Range: 2 - 8. Default value = 2.                                   
    )                                                   
    (
        input               extern_clk_in,          // Clock
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
    //  The following ports are the internal connections from ETH module to others logic module
        //  udp rx data out

);

        logic              clk_locked;

        logic              phy_tx_clk;
        logic  [7:0]       phy_txd;
        logic              phy_tvalid;
        logic              phy_tready;
        logic              phy_terr;        //  user port

        logic  [7:0]       phy_rxd;
        logic              phy_rvalid;
        logic              phy_rready   =   '1;
        logic              phy_rerr;        //  user port

        logic  [7:0]       udp_rdata;
        logic              udp_rvalid;
        logic              udp_rready;
        logic              udp_rlast;
        logic  [31:0]      udp_rip;

       
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
    logic   [7:0]   mac_tnet_data;
    logic   [34:0]  mac_tnet_type;
    logic   [7:0]   mac_rnet_data;

    mac_top #(
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC),
            .CLOCKING_MODE("independent_clock"),
            .RELATED_CLOCKS(0),
            .FIFO_DEPTH(FIFO_DEPTH),
            .FIFO_MEMORY_TYPE(FIFO_MEMORY_TYPE),
            .FIFO_PACKET(FIFO_PACKET),
            .TDATA_WIDTH(TDATA_WIDTH),
            .TDEST_WIDTH(1),
            .TID_WIDTH(1),
            .TUSER_WIDTH(35),
            .USE_ADV_FEATURES(USE_ADV_FEATURES),
            .PROG_EMPTY_THRESH(PROG_EMPTY_THRESH),
            .PROG_FULL_THRESH(PROG_FULL_THRESH),
            .WR_DATA_COUNT_WIDTH(WR_DATA_COUNT_WIDTH),
            .RD_DATA_COUNT_WIDTH(RD_DATA_COUNT_WIDTH),
            .ECC_MODE(ECC_MODE),
            .CDC_SYNC_STAGES(CDC_SYNC_STAGES)
        ) inst_mac_top (
            .logic_clk          (logic_clk),
            .logic_rst          (logic_rst),

            .mac_rphy_clk       (phy_rx_clk),
            .mac_rphy_data_in   (phy_rxd),
            .mac_rphy_valid_in  (phy_rvalid),
            .mac_rphy_err_in    (phy_rerr),

            .mac_tphy_clk       (phy_tx_clk),
            .mac_tphy_data_out  (phy_txd),
            .mac_tphy_valid_out (phy_tvalid),
            .mac_tphy_err_out   (phy_terr),

            .mac_tnet_data_out  (mac_tnet_data),
            .mac_tnet_valid_out (mac_tnet_valid),
            .mac_tnet_ready_in  (mac_tnet_ready),
            .mac_tnet_last_out  (mac_tnet_last),
            .mac_tnet_type_out  (mac_tnet_type),

            .mac_rnet_data_in   (mac_rnet_data),
            .mac_rnet_valid_in  (mac_rnet_valid),
            .mac_rnet_ready_out (mac_rnet_ready),
            .mac_rnet_last_in   (mac_rnet_last)
        );

    assign  logic_rst   =   !clk_locked;
/*------------------------------------------------------------------------------
--  network logic
------------------------------------------------------------------------------*/
    logic   [31:0]  arp_query_ip;
    logic   [47:0]  arp_response_mac;
    logic   [31:0]  trig_arp_ip;
    logic   [7:0]   net_rtrans_data;

    net_top #(
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC)
        ) inst_net_top (
            .logic_clk              (logic_clk),
            .logic_rst              (logic_rst),

            .net_rmac_data_in       (mac_tnet_data),
            .net_rmac_valid_in      (mac_tnet_valid),
            .net_rmac_ready_out     (mac_tnet_ready),
            .net_rmac_last_in       (mac_tnet_last),
            .net_rmac_type_in       (mac_tnet_type),

            .net_tmac_data_out      (mac_rnet_data),
            .net_tmac_valid_out     (mac_rnet_valid),
            .net_tmac_ready_in      (mac_rnet_ready),
            .net_tmac_last_out      (mac_rnet_last),

            .net_rtrans_data_in     (net_rtrans_data),
            .net_rtrans_valid_in    (net_rtrans_valid),
            .net_rtrans_ready_out   (net_rtrans_ready),
            .net_rtrans_last_in     (net_rtrans_last),

            .udp_rdata_out          (udp_rdata),
            .udp_rvalid_out         (udp_rvalid),
            .udp_rready_in          (udp_rready),
            .udp_rlast_out          (udp_rlast),
            .udp_rip_out            (udp_rip),

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

/*------------------------------------------------------------------------------
--  transport logic
------------------------------------------------------------------------------*/

    trans_top #(
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC),
            .LOCAL_SP(LOCAL_SP),
            .LOCAL_DP(LOCAL_DP),
            .CLOCKING_MODE("common_clock"),
            .RELATED_CLOCKS(0),
            .FIFO_DEPTH(FIFO_DEPTH),
            .FIFO_MEMORY_TYPE(FIFO_MEMORY_TYPE),
            .FIFO_PACKET(FIFO_PACKET),
            .TDATA_WIDTH(TDATA_WIDTH),
            .TDEST_WIDTH(1),
            .TID_WIDTH(1),
            .TUSER_WIDTH(1),
            .USE_ADV_FEATURES(USE_ADV_FEATURES),
            .PROG_EMPTY_THRESH(PROG_EMPTY_THRESH),
            .PROG_FULL_THRESH(PROG_FULL_THRESH),
            .WR_DATA_COUNT_WIDTH(WR_DATA_COUNT_WIDTH),
            .RD_DATA_COUNT_WIDTH(RD_DATA_COUNT_WIDTH),
            .ECC_MODE(ECC_MODE),
            .CDC_SYNC_STAGES(CDC_SYNC_STAGES)
        ) inst_trans_top (
            .logic_clk              (logic_clk),
            .logic_rst              (logic_rst),

            .udp_tdata_in           (udp_rdata),
            .udp_tvalid_in          (udp_rvalid),
            .udp_tready_out         (udp_rready),
            .udp_tlast_in           (udp_rlast),
            .udp_tip_in             (udp_rip),

            .trans_tnet_data_out    (net_rtrans_data),
            .trans_tnet_valid_out   (net_rtrans_valid),
            .trans_tnet_ready_in    (net_rtrans_ready),
            .trans_tnet_last_out    (net_rtrans_last),

            .arp_query_ip_out       (arp_query_ip),
            .arp_query_valid_out    (arp_query_valid),
            .arp_query_ready_in     (arp_query_ready),

            .arp_response_mac_in    (arp_response_mac),
            .arp_response_valid_in  (arp_response_valid),
            .arp_response_ready_out (arp_response_ready),
            .arp_response_err_in    (arp_response_err),

            .trig_arp_qvalid_out    (trig_arp_qvalid),
            .trig_arp_ip_out        (trig_arp_ip),
            .trig_arp_qready_in     (trig_arp_qready)
        );


endmodule : eth_top