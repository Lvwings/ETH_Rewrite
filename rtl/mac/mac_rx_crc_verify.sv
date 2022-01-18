`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : mac_crc_verify.sv
 Create     : 2021-12-08 14:52:33
 Revise     : 2021-12-08 14:52:33
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module mac_rx_crc_verify #(
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
    parameter       TUSER_WIDTH         =   35,                     //  Range: 1 - 4086. Default value = 1.                                                                 

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
    input               logic_clk,
    input               logic_rst,

    //  phy data in
    input               mac_rphy_clk,
    input   [7:0]       mac_rphy_data_in,
    input               mac_rphy_valid_in,
    input               mac_rphy_err_in,        
    
    //  mac data out
    output  [7:0]       mac_tnet_data_out,
    output              mac_tnet_valid_out,
    input               mac_tnet_ready_in,
    output              mac_tnet_last_out,
    output  [34:0]      mac_tnet_type_out       //  [34:3] ip    3'b100 ICMP, 3'b010 UDP, 3'b001 ARP
 );
/*------------------------------------------------------------------------------
--  logic reset cdc
------------------------------------------------------------------------------*/
    logic                 mac_rphy_rst;

    sync_reset #(
        .SYNC_DEPTH(3)
    ) inst_sync_reset (
        .sys_clk      (mac_rphy_clk),
        .async_rst    (logic_rst),
        .sync_rst_out (mac_rphy_rst)
    );

/*------------------------------------------------------------------------------
--  rx data delay
------------------------------------------------------------------------------*/
    logic         [7:0]   mac_rphy_data_d4;    
    logic                 mac_rphy_valid_d4; 

    //  rx data delay 4 clk to fifo
    sync_signal #(
            .SIGNAL_WIDTH(9),
            .SYNC_DEPTH(4)
        ) inst_sync_signal (
            .sys_clk    (mac_rphy_clk),
            .sys_rst    (mac_rphy_rst),
            .signal_in  ({mac_rphy_data_in,mac_rphy_valid_in}),
            .signal_out ({mac_rphy_data_d4,mac_rphy_valid_d4})
        );

/*------------------------------------------------------------------------------
--  ETH preamble+SFD detect
------------------------------------------------------------------------------*/
    localparam      PREAMBLE            =   64'h5555_5555_5555_55D5;
    logic [63:0]    preamble_reg        =   '0;
    logic           trig_crc_start;

    always_ff @(posedge mac_rphy_clk) begin               
        if (mac_rphy_valid_d4)
            preamble_reg    <=  {preamble_reg[55:0],mac_rphy_data_d4};
        else
            preamble_reg    <=  '0;
    end

    assign  trig_crc_start  =   (preamble_reg == PREAMBLE);

/*------------------------------------------------------------------------------
--  crc state parameter
------------------------------------------------------------------------------*/
    typedef enum  {IDLE,ETH_HEAD,IP_HEAD,UDP_HEAD,UDP_DATA,PADDING,CRC}    state_r;
    (* fsm_encoding = "one-hot" *) state_r rcrc_state,rcrc_next;

    always_ff @(posedge mac_rphy_clk) begin 
        if(mac_rphy_rst) begin
            rcrc_state <= IDLE;
        end else begin
            rcrc_state <= rcrc_next;
        end
    end
 /*------------------------------------------------------------------------------
 --  eth frame paramter
 ------------------------------------------------------------------------------*/
    localparam  GLOBAL_MAC      =   48'hFFFF_FFFF_FFFF;
    localparam  ARP_TYPE        =   16'h0806;
    localparam  IP_TYPE         =   16'h0800;
    localparam  ETH_HEAD_LENGTH =   8'd14;

    localparam  UDP_PROTO       =   8'h11;
    localparam  ICMP_PROTO      =   8'h01;

    localparam  IP_HEAD_LENGTH  =   8'd20;    
    localparam  UDP_HEAD_LENGTH =   8'd8;
    localparam  UDP_MIN_LENGTH  =   8'd26;  //  UDP_HEAD_LENGTH + MIN_DATA_LENGTH

/*------------------------------------------------------------------------------
--  receive phy frame
------------------------------------------------------------------------------*/
    logic   [15:0]  length_cnt      =   '0;
    logic   [47:0]  eth_da_mac      =   '0;
    logic           flag_rx_over    =   '0;
    logic           flag_err_frame  =   '0;

    logic   [7:0]   ip_proto        =   '0;
    logic   [15:0]  ip_rx_checksum  =   '0;
    logic   [31:0]  ip_checksum     =   '0;     //  for calcualte   
    logic   [31:0]  ip_da_ip        =   '0; 
    logic   [31:0]  ip_sa_ip        =   '0; 
    logic   [1:0]   flag_ip_proto   =   '0; 

    logic   [15:0]  udp_length      =   '0;  
    logic   [15:0]  udp_data_length =   '0;   
    logic   [15:0]  udp_rx_checksum =   '0;   
    logic   [31:0]  udp_checksum    =   '0;
    logic           flag_padding    =   '0;     

    logic   [7:0]   mac_rphy_data_d5    =   '0;    
    logic           mac_rphy_valid_d5   =   '0; 

    always_ff @(posedge mac_rphy_clk) begin
        mac_rphy_valid_d5   <= mac_rphy_valid_d4;
        mac_rphy_data_d5    <= mac_rphy_data_d4;     
           
        case (rcrc_next)
        /*------------------------------------------------------------------------------
        --  ETH head check
        ------------------------------------------------------------------------------*/            
            ETH_HEAD    : begin
                        if (length_cnt == ETH_HEAD_LENGTH-1) begin
                            flag_rx_over    <=  1;
                            length_cnt      <=  0;                            
                            flag_err_frame  <=  (eth_da_mac != LOCAL_MAC) & (eth_da_mac != GLOBAL_MAC);
                        end
                        else begin
                            length_cnt      <=  length_cnt + 1;

                            if (length_cnt < 6)
                                eth_da_mac[8*(5-length_cnt) +: 8]   <=  mac_rphy_data_d4;
                            else
                                eth_da_mac                          <=  eth_da_mac;                           
                        end
            end // ETH_HEAD       
        /*------------------------------------------------------------------------------
        --  IP head
        ------------------------------------------------------------------------------*/
            IP_HEAD     : begin
                if (length_cnt == IP_HEAD_LENGTH) begin
                    flag_rx_over    <=  1;
                    length_cnt      <=  0;
                    flag_ip_proto   <=  {(ip_proto == UDP_PROTO),(ip_proto == ICMP_PROTO)};
                    flag_err_frame  <=  !(ip_da_ip == LOCAL_IP) || (ip_rx_checksum != ~(ip_checksum[31:16] + ip_checksum[15:0]));
                end
                else begin
                    flag_rx_over    <=  0;
                    length_cnt      <=  length_cnt + 1;

                    case (length_cnt)
                        16'd9    :   ip_proto              <=  mac_rphy_data_d4;
                        16'd10   :   ip_rx_checksum[15:08] <=  mac_rphy_data_d4;
                        16'd11   :   ip_rx_checksum[07:00] <=  mac_rphy_data_d4;
                        16'd12   :   ip_sa_ip[31:24]       <=  mac_rphy_data_d4;
                        16'd13   :   ip_sa_ip[23:16]       <=  mac_rphy_data_d4;
                        16'd14   :   ip_sa_ip[15:08]       <=  mac_rphy_data_d4;
                        16'd15   :   ip_sa_ip[07:00]       <=  mac_rphy_data_d4;                                   
                        16'd16   :   ip_da_ip[31:24]       <=  mac_rphy_data_d4;
                        16'd17   :   ip_da_ip[23:16]       <=  mac_rphy_data_d4;
                        16'd18   :   ip_da_ip[15:08]       <=  mac_rphy_data_d4;
                        16'd19   :   ip_da_ip[07:00]       <=  mac_rphy_data_d4;                                                     
                        default :   begin
                                    ip_proto              <=  ip_proto;
                                    ip_sa_ip              <=  ip_sa_ip;
                                    ip_da_ip              <=  ip_da_ip;
                                    ip_rx_checksum        <=  ip_rx_checksum;
                        end // default 
                    endcase                           
                end                        
            end // IP_HEAD 
        /*------------------------------------------------------------------------------
        --  UDP DATA
        ------------------------------------------------------------------------------*/
            UDP_HEAD    :   begin
                        if (length_cnt == UDP_HEAD_LENGTH) begin
                            flag_rx_over    <=  1;
                            length_cnt      <=  1;
                            flag_padding    <=  udp_length < UDP_MIN_LENGTH;
                            udp_data_length <=  udp_length - UDP_HEAD_LENGTH;
                        end
                        else begin
                            flag_rx_over    <=  0;
                            length_cnt      <=  length_cnt + 1; 

                            case (length_cnt)
                                16'd4    :   udp_length[15:8]        <=  mac_rphy_data_d5;   
                                16'd5    :   udp_length[07:0]        <=  mac_rphy_data_d5;
                                16'd6    :   udp_rx_checksum[15:8]   <=  mac_rphy_data_d5;
                                16'd7    :   udp_rx_checksum[07:0]   <=  mac_rphy_data_d5;
                                default :   begin
                                            udp_length              <=  udp_length;
                                            udp_rx_checksum         <=  udp_rx_checksum;
                                end 
                            endcase
                        end
            end // UDP_HEAD

            UDP_DATA    :   begin
                        if (length_cnt == udp_data_length) begin
                            flag_rx_over    <=  1;
                            length_cnt      <=  0;
                            flag_err_frame  <=  (udp_rx_checksum != ~(udp_checksum[31:16] + udp_checksum[15:0]));
                        end
                        else begin
                            flag_rx_over    <=  0;
                            length_cnt      <=  length_cnt + 1;                             
                        end
            end // UDP_DATA 
            default : begin
                        length_cnt      <=  '0;
                        eth_da_mac      <=  '0;  
                        flag_rx_over    <=  '0;
                        flag_err_frame  <=  '0;
                        ip_da_ip        <=  '0;
                        ip_sa_ip        <=  '0;
                        ip_proto        <=  '0;
                        ip_rx_checksum  <=  '0; 
                        udp_length      <=  '0;
                        udp_data_length <=  '0;
                        udp_rx_checksum <=  '0; 
                        flag_padding    <=  '0;                                                                          
            end // default 
        endcase
    end

/*------------------------------------------------------------------------------
--  ip check sum
------------------------------------------------------------------------------*/

    logic   [15:0]  ip_sum_data    =   '0;

    always_ff @(posedge mac_rphy_clk) begin 
        case (rcrc_next)
            IP_HEAD : begin
                case (length_cnt)
                    //  when receive ip head, set ip check sum to 0
                    16'h0A,16'h0B :   begin 
                                    ip_sum_data <=  '0;
                                    ip_checksum <=  !length_cnt[0] ? (ip_checksum + ip_sum_data) : ip_checksum;
                    end 
                    //  ip_checksum is rewrited to reduce 1 clk
                    IP_HEAD_LENGTH-1:   begin
                                    ip_sum_data <=  '0;
                                    ip_checksum <=  ip_checksum + {ip_sum_data[7:0], mac_rphy_data_d4};
                    end
                    default : begin
                                    ip_sum_data <=  mac_rphy_valid_d4  ? {ip_sum_data[7:0], mac_rphy_data_d4} : ip_sum_data;
                                    ip_checksum <=  !length_cnt[0] ? (ip_checksum + ip_sum_data) : ip_checksum;
                    end       
                endcase
            end // IP_HEAD 
            default : begin
                ip_sum_data <=   '0;
                ip_checksum <=   '0;
            end // default 
        endcase
    end  

/*------------------------------------------------------------------------------
--  udp check sum
    check range : pseudo header + udp header + data

    pseudo header
    source ip (4 octets) destination ip (4 octets) 0 (1 octet) 11 (1 octet) udp length (2 octet)
------------------------------------------------------------------------------*/
    logic   [15:0]  udp_sum_data    =   '0;

    always_ff @(posedge mac_rphy_clk) begin 
        case (rcrc_next)
            UDP_HEAD    : begin
                udp_sum_data    <=  {udp_sum_data[7:0], mac_rphy_data_d5};

                //  pseudo header is calculated in this part
                case (length_cnt)
                    16'd1    :   udp_checksum   <=  udp_checksum + ip_sa_ip[31:16];
                    16'd2    :   udp_checksum   <=  udp_checksum + udp_sum_data;     // + ip_sa_ip[31:16] + ip_sa_ip[15:0];  
                    16'd3    :   udp_checksum   <=  udp_checksum + ip_sa_ip[15:0];
                    16'd4    :   udp_checksum   <=  udp_checksum + udp_sum_data;     // + ip_da_ip[31:16] + ip_da_ip[15:0]; 
                    16'd5    :   udp_checksum   <=  udp_checksum + ip_da_ip[31:16];
                    16'd6    :   udp_checksum   <=  udp_checksum + udp_length + udp_length;
                    16'd7    :   udp_checksum   <=  udp_checksum + ip_da_ip[15:0];
                    16'd8    :   udp_checksum   <=  udp_checksum + {8'h00,8'h11};
                    default  :   udp_checksum   <=  udp_checksum;
                endcase    
            end // UDP_HEAD   

            UDP_DATA    : begin
                udp_sum_data    <=  {udp_sum_data[7:0], mac_rphy_data_d5};

                //  if udp data length is odd, {8'h00} should be added behind data to make up 16-bit. 
                if (length_cnt == (udp_data_length-1))  udp_checksum   <=  !length_cnt[0] ? (udp_checksum + udp_sum_data + {mac_rphy_data_d5, 8'h00}) : (udp_checksum + {udp_sum_data[7:0], mac_rphy_data_d5});                                       
                else                                    udp_checksum   <=  !length_cnt[0] ? (udp_checksum + udp_sum_data) : udp_checksum; 
            end // UDP_DATA    
                
            default : begin
                udp_checksum    <=  '0;
                udp_sum_data    <=  '0;
            end // default 
        endcase
    end          
/*------------------------------------------------------------------------------
--  crc calculate
------------------------------------------------------------------------------*/
    logic       [31:0]  crc_result;
    logic       [7:0]   crc_data        =   '0;
    logic               crc_valid       =   '0;
    logic               crc_last        =   '0;
    logic               crc_rst         =   '0;
    logic               mac_rphy_valid_d1   =   '0;

    always_ff @(posedge mac_rphy_clk) begin 
        mac_rphy_valid_d1   <= mac_rphy_valid_in;

        case (rcrc_next)
            IDLE     : begin
                    crc_data  <= 0;
                    crc_valid <= 0;
                    crc_last  <= 0;               
            end //    
            default : begin
                    crc_valid <= mac_rphy_valid_d1 && mac_rphy_valid_d5 && !trig_crc_start;
                    crc_data  <= mac_rphy_data_d5;   
                    crc_last  <= mac_rphy_valid_d1 && !mac_rphy_valid_in;               
            end
        endcase 
    end

    mac_lfsr #(
            .LFSR_WIDTH         (32),
            .LFSR_POLY          (32'h04C11DB7),
            .LFSR_CONFIG        ("GALOIS"),
            .LFSR_FEED_FORWARD  (0),
            .LFSR_INITIAL_STATE (32'hFFFFFFFF),
            .LFSR_STATE_OUT_XOR (32'hFFFFFFFF),
            .REVERSE            (1),
            .DATA_WIDTH         (8)
        ) inst_mac_tx_crc (
            .clk                   (mac_rphy_clk),
            .rst                   (crc_rst),
            .data_in               (crc_data),
            .data_valid_in         (crc_valid),
            .data_out              (),
            .lfsr_state_out_comb   (crc_result),
            .lfsr_state_out_reg    ()
        );
/*------------------------------------------------------------------------------
--  if phy data receive error or crc verify faild or system reset, reset rx fifo
------------------------------------------------------------------------------*/
    reg                 trig_crc_reset  =   1'b0; 
    reg                 flag_good_crc   =   1'b0;
    reg     [31:0]      mac_rx_crc      =   '0;

    always_ff @(posedge mac_rphy_clk) begin 
        mac_rx_crc  <=  mac_rphy_valid_in ? {mac_rphy_data_in,mac_rx_crc[31:8]} : mac_rx_crc;

        if (mac_rphy_err_in || flag_err_frame)
            trig_crc_reset     <= 1;
        else if (crc_last)
            if (crc_result == mac_rx_crc)
                flag_good_crc   <= 1;
            else 
                trig_crc_reset  <= 1;
        else begin
            trig_crc_reset      <= 0;
            flag_good_crc       <= 0;
        end        
    end
/*------------------------------------------------------------------------------
--  crc reset & fifo reset
------------------------------------------------------------------------------*/
    reg             fifo_reset_n  =   1'b1;

    always_ff @(posedge mac_rphy_clk) begin
        if(trig_crc_reset || mac_rphy_rst) begin
            fifo_reset_n    <= 0;
            crc_rst         <= 1;
        end else if (flag_good_crc) begin
            crc_rst         <= 1;
        end
        else begin
            fifo_reset_n    <= 1;
            crc_rst         <= 0;            
        end
    end
/*------------------------------------------------------------------------------
--  crc state jump
------------------------------------------------------------------------------*/
    logic   [34:0]   mac_tnet_type   =   '0;    //  IP[34:3]    ICMP[2] UDP[1]  ARP[0]

    always_comb begin 
        case (rcrc_state)
            IDLE    :                                                   rcrc_next = trig_crc_start ? ETH_HEAD : IDLE;
            
            ETH_HEAD:   if      (flag_err_frame)                        rcrc_next = IDLE;                                         
                        else if (flag_rx_over && mac_tnet_type[1])      rcrc_next = IP_HEAD;
                        else if (flag_rx_over && mac_tnet_type[0])      rcrc_next = CRC;
                        else                                            rcrc_next = ETH_HEAD;

            IP_HEAD :   if      (flag_err_frame)                        rcrc_next = IDLE;
                        else if (flag_rx_over && flag_ip_proto[1])      rcrc_next = UDP_HEAD;
                        else if (flag_rx_over && flag_ip_proto[0])      rcrc_next = CRC;
                        else if (flag_rx_over)                          rcrc_next = IDLE;
                        else                                            rcrc_next = IP_HEAD;

            UDP_HEAD:   if      (flag_err_frame)                        rcrc_next =  IDLE;
                        else if (flag_rx_over)                          rcrc_next =  UDP_DATA;
                        else                                            rcrc_next =  UDP_HEAD;
    
            UDP_DATA:   if      (flag_err_frame)                        rcrc_next =  IDLE;
                        else if (flag_rx_over && flag_padding)          rcrc_next =  PADDING;
                        else if (flag_rx_over)                          rcrc_next =  IDLE;
                            else                                        rcrc_next =  UDP_DATA;

            PADDING :                                                   rcrc_next =  !mac_rphy_valid_in ? CRC : PADDING;                                   

            CRC     :   if (trig_crc_reset || flag_good_crc)            rcrc_next = IDLE;                            
                        else                                            rcrc_next = CRC;                            
        
            default :                                                   rcrc_next = IDLE;
        endcase    
    end
/*------------------------------------------------------------------------------
--  mac recive phy data fifo
------------------------------------------------------------------------------*/
    logic   [7:0]   mac_tnet_data   =   '0;
    logic           mac_tnet_valid  =   '0;
    logic           mac_tnet_last   =   '0;

    always_ff @(posedge mac_rphy_clk) begin 
        if (length_cnt == ETH_HEAD_LENGTH-1 && rcrc_state == ETH_HEAD)  
            mac_tnet_type     <=    {32'h0,1'b0,({mac_rphy_data_d5, mac_rphy_data_d4} == IP_TYPE),({mac_rphy_data_d5, mac_rphy_data_d4} == ARP_TYPE)};
        else if (flag_rx_over & rcrc_state == IP_HEAD)
            mac_tnet_type     <=    {ip_sa_ip ,flag_ip_proto[0], flag_ip_proto[1], 1'b0};
        else if (rcrc_state == IDLE)
            mac_tnet_type     <=    '0;
        else 
            mac_tnet_type     <=    mac_tnet_type;

    end

    state_r rcrc_state_d;

    always_ff @(posedge mac_rphy_clk) begin 
        rcrc_state_d    <=  rcrc_state;
        mac_tnet_data   <=  crc_data;
        mac_tnet_valid  <=  ((rcrc_next == UDP_DATA) || (rcrc_state_d == CRC && !mac_tnet_type[1])) & crc_valid;
        mac_tnet_last   <=  (rcrc_state == UDP_DATA && length_cnt == udp_data_length) || (crc_last && !mac_tnet_type[1]);   
    end    

// mac_rx_fifo mac_rx_fifo (
//  .s_axis_aresetn   (fifo_reset_n),         // input wire s_axis_aresetn
//
//  .s_axis_aclk      (mac_rphy_clk),         // input wire s_axis_aclk
//  .s_axis_tvalid    (mac_tnet_valid),        // input wire s_axis_tvalid
//  .s_axis_tready    (),                     // output wire s_axis_tready
//  .s_axis_tdata     (mac_tnet_data),         // input wire [7 : 0] s_axis_tdata
//  .s_axis_tlast     (mac_tnet_last),         // input wire s_axis_tlast
//  .s_axis_tuser     (mac_tnet_type),        // input wire [34 : 0] s_axis_tuser
//
//  .m_axis_aclk      (logic_clk),                // input wire m_axis_aclk
//  .m_axis_tvalid    (mac_tnet_valid_out),    // output wire m_axis_tvalid
//  .m_axis_tready    (mac_tnet_ready_in),     // input wire m_axis_tready
//  .m_axis_tdata     (mac_tnet_data_out),     // output wire [7 : 0] m_axis_tdata
//  .m_axis_tlast     (mac_tnet_last_out),      // output wire m_axis_tlast
//  .m_axis_tuser     (mac_tnet_type_out)      // output wire [34 : 0] m_axis_tuser
//);  


   xpm_fifo_axis #(
        .CLOCKING_MODE          (CLOCKING_MODE),        // String
        .RELATED_CLOCKS         (RELATED_CLOCKS),       // DECIMAL
        .FIFO_DEPTH             (FIFO_DEPTH),           // DECIMAL
        .FIFO_MEMORY_TYPE       (FIFO_MEMORY_TYPE),     // String
        .PACKET_FIFO            (FIFO_PACKET),          // String

        .TDATA_WIDTH            (TDATA_WIDTH),          // DECIMAL
        .TDEST_WIDTH            (TDEST_WIDTH),          // DECIMAL
        .TID_WIDTH              (TID_WIDTH),            // DECIMAL
        .TUSER_WIDTH            (TUSER_WIDTH),          // DECIMAL

        .USE_ADV_FEATURES       (USE_ADV_FEATURES),     // String
        .PROG_EMPTY_THRESH      (PROG_EMPTY_THRESH),    // DECIMAL
        .PROG_FULL_THRESH       (PROG_FULL_THRESH),     // DECIMAL
        .WR_DATA_COUNT_WIDTH    (WR_DATA_COUNT_WIDTH),  // DECIMAL
        .RD_DATA_COUNT_WIDTH    (RD_DATA_COUNT_WIDTH),  // DECIMAL
        .CDC_SYNC_STAGES        (CDC_SYNC_STAGES),      // DECIMAL     
        .ECC_MODE               (ECC_MODE),             // String      
        .SIM_ASSERT_CHK         (0)                     // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
   )
   mac_rx_fifo (
    //  axis slave
        .s_aclk         (mac_rphy_clk),                        
        .s_aresetn      (fifo_reset_n),                 
        .s_axis_tdata   (mac_tnet_data), 
        .s_axis_tvalid  (mac_tnet_valid), 
        .s_axis_tready  (mac_tnet_ready), 
        .s_axis_tlast   (mac_tnet_last),
        .s_axis_tuser   (mac_tnet_type), 

    //  axis master    
        .m_aclk         (logic_clk),                                                                      
        .m_axis_tdata   (mac_tnet_data_out),           
        .m_axis_tvalid  (mac_tnet_valid_out),
        .m_axis_tready  (mac_tnet_ready_in), 
        .m_axis_tlast   (mac_tnet_last_out), 
        .m_axis_tuser   (mac_tnet_type_out)
   );   
 endmodule : mac_rx_crc_verify