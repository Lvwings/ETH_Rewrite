`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : mac_top.sv
 Create     : 2021-12-13 14:48:16
 Revise     : 2021-12-13 14:48:16
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module mac_top #(
    parameter       LOCAL_MAC   =   48'hABCD_1234_5678
    )
 (
    input           logic_clk,
    input           logic_rst,

    //  phy rx data in
    input           phy_rx_clk,
    input   [7:0]   phy_rxd_in,
    input           phy_rvalid_in,
    input           phy_rerr_in,        
    
    //  mac rxdata out
    output  [7:0]   mac_rdata_out,
    output          mac_rvalid_out,
    input           mac_rready_in,
    output          mac_rlast_out,
    output  [2:0]   mac_rtype_out,   

    // mac tx data in
    input   [7:0]   mac_tdata_in,
    input           mac_tvalid_in,
    output          mac_tready_out,
    input           mac_tlast_in,

    // phy tx interface
    input           phy_tx_clk,
    output  [7:0]   phy_txd_out,
    output          phy_tvalid_out,
    output          phy_terr_out
     
 );
 
    mac_tx_crc_calculate inst_mac_tx_crc_calculate
        (
            .logic_clk      (logic_clk),
            .logic_rst      (logic_rst),
            .mac_tdata_in   (mac_tdata_in),
            .mac_tvalid_in  (mac_tvalid_in),
            .mac_tready_out (mac_tready_out),
            .mac_tlast_in   (mac_tlast_in),
            .phy_tx_clk     (phy_tx_clk),
            .phy_txd_out    (phy_txd_out),
            .phy_tvalid_out (phy_tvalid_out),
            .phy_terr_out   (phy_terr_out)
        );

    mac_rx_crc_verify #(
            .LOCAL_MAC(LOCAL_MAC)
        ) inst_mac_rx_crc_verify (
            .logic_clk      (logic_clk),
            .logic_rst      (logic_rst),
            .phy_rx_clk     (phy_rx_clk),
            .phy_rxd_in     (phy_rxd_in),
            .phy_rvalid_in  (phy_rvalid_in),
            .phy_rerr_in    (phy_rerr_in),
            .mac_rdata_out  (mac_rdata_out),
            .mac_rvalid_out (mac_rvalid_out),
            .mac_rready_in  (mac_rready_in),
            .mac_rlast_out  (mac_rlast_out),
            .mac_rtype_out  (mac_rtype_out)
        );


 endmodule : mac_top