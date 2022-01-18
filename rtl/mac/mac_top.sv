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
    parameter       LOCAL_IP    =   32'hC0A8_006E,
    parameter       LOCAL_MAC   =   48'hABCD_1234_5678,
    //  FIFO parameter   
    parameter       CLOCKING_MODE       =   "independent_clock",    //  common_clock, independent_clock   
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
 
    mac_tx_crc_calculate #(
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
        ) inst_mac_tx_crc_calculate (
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
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC),
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