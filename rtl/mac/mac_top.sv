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
    input           mac_rphy_clk,
    input   [7:0]   mac_rphy_data_in,
    input           mac_rphy_valid_in,
    input           mac_rphy_err_in,        

    // phy tx interface
    input           mac_tphy_clk,
    output  [7:0]   mac_tphy_data_out,
    output          mac_tphy_valid_out,
    output          mac_tphy_err_out,

    //  mac rxdata out
    output  [7:0]   mac_tnet_data_out,
    output          mac_tnet_valid_out,
    input           mac_tnet_ready_in,
    output          mac_tnet_last_out,
    output  [34:0]  mac_tnet_type_out,   

    // mac tx data in
    input   [7:0]   mac_rnet_data_in,
    input           mac_rnet_valid_in,
    output          mac_rnet_ready_out,
    input           mac_rnet_last_in 
 );
 
    mac_tx_crc_calculate inst_mac_tx_crc_calculate
        (
            .logic_clk          (logic_clk),
            .logic_rst          (logic_rst),
            .mac_rnet_data_in   (mac_rnet_data_in),
            .mac_rnet_valid_in  (mac_rnet_valid_in),
            .mac_rnet_ready_out (mac_rnet_ready_out),
            .mac_rnet_last_in   (mac_rnet_last_in),
            .mac_tphy_clk       (mac_tphy_clk),
            .mac_tphy_data_out  (mac_tphy_data_out),
            .mac_tphy_valid_out (mac_tphy_valid_out),
            .mac_tphy_err_out   (mac_tphy_err_out)
        );

    mac_rx_crc_verify #(
            .LOCAL_MAC(LOCAL_MAC)
        ) inst_mac_rx_crc_verify (
            .logic_clk          (logic_clk),
            .logic_rst          (logic_rst),
            .mac_rphy_clk       (mac_rphy_clk),
            .mac_rphy_data_in   (mac_rphy_data_in),
            .mac_rphy_valid_in  (mac_rphy_valid_in),
            .mac_rphy_err_in    (mac_rphy_err_in),
            .mac_tnet_data_out  (mac_tnet_data_out),
            .mac_tnet_valid_out (mac_tnet_valid_out),
            .mac_tnet_ready_in  (mac_tnet_ready_in),
            .mac_tnet_last_out  (mac_tnet_last_out),
            .mac_tnet_type_out  (mac_tnet_type_out)
        );


 endmodule : mac_top