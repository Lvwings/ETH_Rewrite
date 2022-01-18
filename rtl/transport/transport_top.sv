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
    parameter       LOCAL_DP    =   16'd8080,
    //  FIFO parameter   
    parameter       CLOCKING_MODE       =   "common_clock",         //  common_clock, independent_clock   
    parameter       RELATED_CLOCKS      =   0,                      //  Specifies if the s_aclk and m_aclk are related having the same source but different clock ratios.  
    parameter       FIFO_DEPTH          =   512,                    //  Range: 16 - 4194304. Default value = 2048.   
    parameter       FIFO_MEMORY_TYPE    =   "auto",                 //  auto, block, distributed, ultra. Default value = auto
    parameter       FIFO_PACKET         =   "true",                 //  false, true. Default value = false.

    parameter       TDATA_WIDTH         =   8,                      //  Range: 8 - 2048. Default value = 32.  
                                                                    //  NOTE: The maximum FIFO size (width x depth) is limited to 150-Megabits. 
    parameter       TDEST_WIDTH         =   1,                      //  Range: 1 - 32. Default value = 1.   
    parameter       TID_WIDTH           =   1,                      //  Range: 1 - 32. Default value = 1. 
    parameter       TUSER_WIDTH         =   1,                      //  Range: 1 - 4086. Default value = 1.                                                                 

    parameter       USE_ADV_FEATURES    =   "0000",                 //  Setting USE_ADV_FEATURES[1] to 1 enables prog_full flag; Default value of this bit is 0    
                                                                    //  Setting USE_ADV_FEATURES[2] to 1 enables wr_data_count; Default value of this bit is 0           
                                                                    //  Setting USE_ADV_FEATURES[3] to 1 enables almost_full flag; Default value of this bit is 0    
                                                                    //  Setting USE_ADV_FEATURES[9] to 1 enables prog_empty flag; Default value of this bit is 0     
                                                                    //  Setting USE_ADV_FEATURES[10] to 1 enables rd_data_count; Default value of this bit is 0    
                                                                    //  Setting USE_ADV_FEATURES[11] to 1 enables almost_empty flag; Default value of this bit is 0    
    parameter       PROG_EMPTY_THRESH   =   10,                     //  Range: 5 - 4194301. Default value = 10. 
    parameter       PROG_FULL_THRESH    =   10,                     //  Range: 5 - 4194301. Default value = 10. 
    parameter       WR_DATA_COUNT_WIDTH =   1,                      //  Range: 1 - 23. Default value = 1.      
    parameter       RD_DATA_COUNT_WIDTH =   1,                      //  Range: 1 - 23. Default value = 1.
    parameter       ECC_MODE            =   "no_ecc",               //  no_ecc, en_ecc. Default value = no_ecc.  
    parameter       CDC_SYNC_STAGES     =   2                       //  Range: 2 - 8. Default value = 2.     
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
         .LOCAL_DP(LOCAL_DP),
         .CLOCKING_MODE(CLOCKING_MODE),
         .RELATED_CLOCKS(RELATED_CLOCKS),
         .FIFO_DEPTH(FIFO_DEPTH),
         .FIFO_MEMORY_TYPE(FIFO_MEMORY_TYPE),
         .FIFO_PACKET(FIFO_PACKET),
         .TDATA_WIDTH(TDATA_WIDTH),
         .TDEST_WIDTH(TDEST_WIDTH),
         .TID_WIDTH(TID_WIDTH),
         .TUSER_WIDTH(TUSER_WIDTH),
         .USE_ADV_FEATURES(USE_ADV_FEATURES),
         .PROG_EMPTY_THRESH(PROG_EMPTY_THRESH),
         .PROG_FULL_THRESH(PROG_FULL_THRESH),
         .WR_DATA_COUNT_WIDTH(WR_DATA_COUNT_WIDTH),
         .RD_DATA_COUNT_WIDTH(RD_DATA_COUNT_WIDTH),
         .ECC_MODE(ECC_MODE),
         .CDC_SYNC_STAGES(CDC_SYNC_STAGES)
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