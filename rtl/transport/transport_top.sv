`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : trans_top.sv
 Create     : 2022-01-10 15:57:04
 Revise     : 2022-01-10 15:57:04
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module trans_top #(
    parameter       LOCAL_IP    =   32'hC0A8_006E,
    parameter       LOCAL_MAC   =   48'hABCD_1234_5678,
    parameter       LOCAL_SP    =   16'd8080,
    parameter       LOCAL_DP    =   16'd8080
    )(
    input           logic_clk,    // Clock
    input           logic_rst,  // Asynchronous reset active high
    
    //  transfer data input - from logic
    input   [7:0]   udp_tdata_in, 
    input           udp_tvalid_in,
    output          udp_tready_out,
    input           udp_tlast_in,
    input   [31:0]  udp_tip_in,

    //  udp stream out - to net
    output  [7:0]   trans_tnet_data_out,
    output          trans_tnet_valid_out,
    input           trans_tnet_ready_in,
    output          trans_tnet_last_out,

    //  cache query - find mac address match ip  
    output  [31:0]  arp_query_ip_out,
    output          arp_query_valid_out,
    input           arp_query_ready_in,

    input   [47:0]  arp_response_mac_in,
    input           arp_response_valid_in,
    output          arp_response_ready_out,
    input           arp_response_err_in,    //  no mac match arp_query_ip_in   

    //  arp query trigger
    output          trig_arp_qvalid_out,
    output  [31:0]  trig_arp_ip_out,
    input           trig_arp_qready_in     //  arp query has been responded  
     
 );
 
    udp_tx #(
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC),
            .LOCAL_SP(LOCAL_SP),
            .LOCAL_DP(LOCAL_DP)
        ) inst_udp_tx (
            .logic_clk              (logic_clk),
            .logic_rst              (logic_rst),

            .udp_tdata_in           (udp_tdata_in),
            .udp_tvalid_in          (udp_tvalid_in),
            .udp_tready_out         (udp_tready_out),
            .udp_tlast_in           (udp_tlast_in),
            .udp_tip_in             (udp_tip_in),

            .trans_tnet_data_out    (trans_tnet_data_out),
            .trans_tnet_valid_out   (trans_tnet_valid_out),
            .trans_tnet_ready_in    (trans_tnet_ready_in),
            .trans_tnet_last_out    (trans_tnet_last_out),

            .arp_query_ip_out       (arp_query_ip_out),
            .arp_query_valid_out    (arp_query_valid_out),
            .arp_query_ready_in     (arp_query_ready_in),

            .arp_response_mac_in    (arp_response_mac_in),
            .arp_response_valid_in  (arp_response_valid_in),
            .arp_response_ready_out (arp_response_ready_out),
            .arp_response_err_in    (arp_response_err_in),
            
            .trig_arp_qvalid_out    (trig_arp_qvalid_out),
            .trig_arp_ip_out        (trig_arp_ip_out),
            .trig_arp_qready_in     (trig_arp_qready_in)
        );

 endmodule : trans_top