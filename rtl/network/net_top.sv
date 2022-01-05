`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : net_top.sv
 Create     : 2021-12-16 16:39:18
 Revise     : 2021-12-16 16:39:18
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module net_top #(
    parameter       LOCAL_IP    =   32'hC0A8_006E,
    parameter       LOCAL_MAC   =   48'hABCD_1234_5678
    )
    (
    input           logic_clk,
    input           logic_rst,   
 
     //  net rx data in -> from mac
    input   [7:0]   net_rdata_in,
    input           net_rvalid_in,
    output          net_rready_out,
    input           net_rlast_in,
    input   [2:0]   net_rtype_in,

    //  net tx data out -> to mac
    output  [7:0]   net_tdata_out,
    output          net_tvalid_out,
    input           net_tready_in,
    output          net_tlast_out,   

    //  udp rx data out
    output  [7:0]   udp_rdata_out,
    output          udp_rvalid_out,
    input           udp_rready_in,
    output          udp_rlast_out,

     //  arp query trigger
    input           trig_arp_qvalid_in,
    input   [31:0]  trig_arp_ip_in,
    output          trig_arp_qready_out,   //  arp query has been responded

    //  cache query - find mac address match ip
    //  axi-lite read    
    input   [31:0]  arp_query_ip_in,
    input           arp_query_valid_in,
    output          arp_query_ready_out,

    output  [47:0]  arp_response_mac_out,
    output          arp_response_valid_out,
    input           arp_response_ready_in,
    output          arp_response_err_out    //  no mac match arp_query_ip_in    
 );

    wire    [7:0]   arp_rdata;
    wire    [7:0]   arp_tdata;
    wire    [31:0]  arp_write_ip;
    wire    [47:0]  arp_store_mac;

    frame_split #(
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC)
        ) inst_frame_split (
            .logic_clk      (logic_clk),
            .logic_rst      (logic_rst),

            .net_rdata_in   (net_rdata_in),
            .net_rvalid_in  (net_rvalid_in),
            .net_rready_out (net_rready_out),
            .net_rlast_in   (net_rlast_in),
            .net_rtype_in   (net_rtype_in),

            .arp_rdata_out  (arp_rdata),
            .arp_rvalid_out (arp_rvalid),
            .arp_rready_in  (arp_rready),
            .arp_rlast_out  (arp_rlast),

            .udp_rdata_out  (udp_rdata_out),
            .udp_rvalid_out (udp_rvalid_out),
            .udp_rready_in  (udp_rready_in),
            .udp_rlast_out  (udp_rlast_out)
        );

    arp_tx #(
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC)
        ) inst_arp_tx (
            .logic_clk           (logic_clk),
            .logic_rst           (logic_rst),

            .trig_arp_qvalid_in  (trig_arp_qvalid_in),
            .trig_arp_ip_in      (trig_arp_ip_in),
            .trig_arp_qready_out (trig_arp_qready_out),

            .arp_rdata_in        (arp_rdata),
            .arp_rvalid_in       (arp_rvalid),
            .arp_rready_out      (arp_rready),
            .arp_rlast_in        (arp_rlast),

            .arp_write_ip_out    (arp_write_ip),
            .arp_write_valid_out (arp_write_valid),
            .arp_write_ready_in  (arp_write_ready),
            .arp_store_mac_out   (arp_store_mac),
            .arp_store_valid_out (arp_store_valid),
            .arp_store_ready_in  (arp_store_ready),
            .arp_bvalid_out      (arp_bvalid),
            .arp_bready_in       (arp_bready),

            .arp_tdata_out       (arp_tdata),
            .arp_tvalid_out      (arp_tvalid),
            .arp_tready_in       (arp_tready),
            .arp_tlast_out       (arp_tlast)
        );

    arp_cache inst_arp_cache
        (
            .logic_clk              (logic_clk),
            .logic_rst              (logic_rst),
            .arp_cache_clear_in     (arp_cache_clear_in),

            .arp_write_ip_in        (arp_write_ip),
            .arp_write_valid_in     (arp_write_valid),
            .arp_write_ready_out    (arp_write_ready),
            .arp_store_mac_in       (arp_store_mac),
            .arp_store_valid_in     (arp_store_valid),
            .arp_store_ready_out    (arp_store_ready),
            .arp_bvalid_in          (arp_bvalid),
            .arp_bready_out         (arp_bready),

            .arp_query_ip_in        (arp_query_ip_in),
            .arp_query_valid_in     (arp_query_valid_in),
            .arp_query_ready_out    (arp_query_ready_out),
            .arp_response_mac_out   (arp_response_mac_out),
            .arp_response_valid_out (arp_response_valid_out),
            .arp_response_ready_in  (arp_response_ready_in),
            .arp_response_err_out   (arp_response_err_out)
        );

    assign          net_tdata_out   =   arp_tdata;
    assign          net_tvalid_out  =   arp_tvalid;
    assign          net_tlast_out   =   arp_tlast;
    assign          arp_tready      =   net_tready_in;
    
 endmodule : net_top