`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : udp_tx.sv
 Create     : 2022-01-10 10:13:13
 Revise     : 2022-01-10 10:13:13
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module udp_tx #(
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
 
/*------------------------------------------------------------------------------
--  udp data receive
------------------------------------------------------------------------------*/
    logic           udp_tready_o    =   '0;
    logic           fifo_sready;

    always_ff @(posedge logic_clk) begin
       udp_tready_o  <= !udp_tlast_in && fifo_sready;
    end
    
    logic           m_axis_tready   =   '0;
    logic   [7:0]   m_axis_tdata;

udp_tx_fifo udp_tx_fifo (

  .s_axis_aresetn   (!logic_rst),  // input wire s_axis_aresetn
  .s_axis_aclk      (logic_clk),        // input wire s_axis_aclk

  .s_axis_tvalid    (udp_tvalid_in),    // input wire s_axis_tvalid
  .s_axis_tready    (fifo_sready),    // output wire s_axis_tready
  .s_axis_tdata     (udp_tdata_in),      // input wire [7 : 0] s_axis_tdata
  .s_axis_tlast     (udp_tlast_in),      // input wire s_axis_tlast

  .m_axis_tvalid    (m_axis_tvalid),    // output wire m_axis_tvalid
  .m_axis_tready    (m_axis_tready),    // input wire m_axis_tready
  .m_axis_tdata     (m_axis_tdata),      // output wire [7 : 0] m_axis_tdata
  .m_axis_tlast     (m_axis_tlast)      // output wire m_axis_tlast
);

assign  udp_tready_out  =   udp_tready_o;
 /*------------------------------------------------------------------------------
 --  eth frame paramter
 ------------------------------------------------------------------------------*/
    localparam  GLOBAL_MAC      =   48'hFFFF_FFFF_FFFF;
    localparam  IP_TYPE         =   16'h0800;
    //  IP HEAD
    localparam  IP_VISION_TOS   =   16'h4500;   //  vision 4, length 5, tos 00
    localparam  IP_FLAG_OFFSET  =   16'h4000;   //  dont fragment flag = 1
    localparam  IP_TTL_PROTO    =   16'h8011;   //  TTL 80, proto 11 (udp)

    localparam  ETH_HEAD_LENGTH =   8'd14;
    localparam  IP_HEAD_LENGTH  =   8'd20;    
    localparam  UDP_HEAD_LENGTH =   8'd8;
    localparam  UDP_MIN_LENGTH  =   8'd26;  //  UDP_HEAD_LENGTH + MIN_DATA_LENGTH 
/*------------------------------------------------------------------------------
--  udp data sum calculate
------------------------------------------------------------------------------*/

    logic   [31:0]  udp_datasum     =   '0;
    logic   [15:0]  udp_word        =   '0;
    logic   [15:0]  udp_cnt         =   '0;
    logic           flag_data_over  =   '0;
    logic   [15:0]  ip_length       =   '0;
    logic   [15:0]  udp_length      =   '0;

    always_ff @(posedge logic_clk) begin 

        if (trans_tnet_last_out) begin
            udp_datasum <=  '0;
            udp_word    <=  '0;
            udp_cnt     <=  '0;
        end
        else begin
            flag_data_over  <=  udp_tready_out && udp_tlast_in && udp_tvalid_in;
            udp_cnt         <=  udp_cnt + (udp_tready_out && udp_tvalid_in);

            if (flag_data_over) begin
                udp_datasum <=  !udp_cnt[0] ? (udp_datasum + udp_word) : (udp_datasum + {udp_word[7:0],8'h0});
                ip_length   <=  udp_cnt + UDP_HEAD_LENGTH + IP_HEAD_LENGTH;
                udp_length  <=  udp_cnt + UDP_HEAD_LENGTH;
            end 
            else if (udp_tready_out && udp_tvalid_in) begin
                udp_word    <=  {udp_word[7:0], udp_tdata_in};
                udp_datasum <=  !udp_cnt[0] ? (udp_datasum + udp_word) : udp_datasum;
            end
            else begin
                udp_word    <=  udp_word;
                udp_datasum <=  udp_datasum;
            end            
        end 
    end

/*------------------------------------------------------------------------------
--  UDP tx state
------------------------------------------------------------------------------*/
    typedef enum   {IDLE,ARP_QUERY,ETH_HEAD,IP_HEAD,UDP_HEAD,UDP_DATA}    state_t;
    state_t udp_state,udp_next;

    always_ff @(posedge logic_clk) begin 
        if(logic_rst) begin
            udp_state <= IDLE;
        end else begin
            udp_state <= udp_next;
        end
    end
/*------------------------------------------------------------------------------
--  udp state jump
------------------------------------------------------------------------------*/
    logic           flag_mac_ready  =   '0;
    logic           flag_tx_start   =   '0;
    logic           flag_tx_over    =   '0;
    logic           udp_tvalid_d    =   '0;
    logic           trig_arp_query  =   '0;

    always_ff @(posedge logic_clk) begin 
       udp_tvalid_d     <= udp_tvalid_in;
       trig_arp_query   <= !udp_tvalid_d && udp_tvalid_in;
    end
    

    always_comb begin 
        case (udp_state)
            IDLE        :   udp_next    =   trig_arp_query  ? ARP_QUERY : IDLE;
            ARP_QUERY   :   udp_next    =   flag_tx_start   ? ETH_HEAD  : ARP_QUERY;
            ETH_HEAD    :   udp_next    =   flag_tx_over    ? IP_HEAD   : ETH_HEAD;
            IP_HEAD     :   udp_next    =   flag_tx_over    ? UDP_HEAD  : IP_HEAD;
            UDP_HEAD    :   udp_next    =   flag_tx_over    ? UDP_DATA  : UDP_HEAD;
            UDP_DATA    :   udp_next    =   flag_tx_over    ? IDLE      : UDP_DATA;
            default :       udp_next    =   IDLE;
        endcase
    end    
/*------------------------------------------------------------------------------
--  get target mac
------------------------------------------------------------------------------*/

    logic   [31:0]  target_ip       =   '0;
    logic   [47:0]  target_mac      =   '0;

    always_ff @(posedge logic_clk) begin 
        case (udp_next)
            IDLE        : begin
                    target_ip       <=  '0;
                    target_mac      <=  '0;            
            end // IDLE        
            
            ARP_QUERY   : begin
                    target_ip           <=  udp_tip_in;
                    flag_tx_start       <=  flag_mac_ready & udp_tlast_in;

                    if (arp_response_valid_in && !arp_response_err_in && arp_response_ready_out) begin
                        target_mac      <=  arp_response_mac_in;
                        flag_mac_ready  <=  1;
                    end
                    else begin
                        target_mac      <=  target_mac;
                        flag_mac_ready  <=  flag_mac_ready;
                    end                                   
            end // ARP_QUERY   
            default : begin
                    target_ip       <=  target_ip;
                    target_mac      <=  target_mac;
                    flag_mac_ready  <=  '0;     
                    flag_tx_start   <=  '0;           
            end // default 
        endcase
    end

/*------------------------------------------------------------------------------
--  eth head 
------------------------------------------------------------------------------*/
    logic   [15:0]  octec_cnt           =   '0;
    logic   [7:0]   trans_tnet_data_o   =   '0;
    logic           trans_tnet_valid_o  =   '0;
    logic           trans_tnet_last_o   =   '0;

    assign          trans_tnet_data_out =   trans_tnet_data_o;
    assign          trans_tnet_valid_out=   trans_tnet_valid_o;
    assign          trans_tnet_last_out =   trans_tnet_last_o;

    logic   [15:0]  ip_identify         =   '0;
    logic   [31:0]  ip_checksum         =   '0;
    logic   [31:0]  udp_checksum        =   '0;

    always_ff @(posedge logic_clk) begin 
        case (udp_next)
            ETH_HEAD    : begin
                    if (octec_cnt == ETH_HEAD_LENGTH-1) begin
                        octec_cnt           <=  0;
                        flag_tx_over        <=  1;
                    end
                    else begin
                        octec_cnt           <=  octec_cnt + (trans_tnet_valid_out && trans_tnet_ready_in);
                        flag_tx_over        <=  0;                                             
                    end
                    
                    trans_tnet_valid_o  <=  1;
                    if (trans_tnet_ready_in) 
                        case (octec_cnt)
                                16'd00  :   trans_tnet_data_o   <=  target_mac[39:32];
                                16'd01  :   trans_tnet_data_o   <=  target_mac[31:24];
                                16'd02  :   trans_tnet_data_o   <=  target_mac[23:16];
                                16'd03  :   trans_tnet_data_o   <=  target_mac[15:08];
                                16'd04  :   trans_tnet_data_o   <=  target_mac[07:00];
                                16'd05  :   trans_tnet_data_o   <=  LOCAL_MAC[47:40];
                                16'd06  :   trans_tnet_data_o   <=  LOCAL_MAC[39:32];
                                16'd07  :   trans_tnet_data_o   <=  LOCAL_MAC[31:24];
                                16'd08  :   trans_tnet_data_o   <=  LOCAL_MAC[23:16];
                                16'd09  :   trans_tnet_data_o   <=  LOCAL_MAC[15:08];
                                16'd10  :   trans_tnet_data_o   <=  LOCAL_MAC[07:00];
                                16'd11  :   trans_tnet_data_o   <=  IP_TYPE[15:08];
                                16'd12  :   trans_tnet_data_o   <=  IP_TYPE[07:00];
                                16'd13  :   trans_tnet_data_o   <=  IP_VISION_TOS[15:8];    //  next data
                                default :   trans_tnet_data_o   <=  '0;
                        endcase                                                               
                    else 
                        trans_tnet_data_o   <=  target_mac[47:40];  
                    
            end // ETH_HEAD    

            IP_HEAD     : begin
                    if (octec_cnt == IP_HEAD_LENGTH-1) begin
                        octec_cnt           <=  0;
                        flag_tx_over        <=  1;                        
                    end
                    else begin
                        octec_cnt           <=  octec_cnt + (trans_tnet_valid_out && trans_tnet_ready_in);
                        flag_tx_over        <=  0;                       
                    end

                    trans_tnet_valid_o  <=  1;  

                    case (octec_cnt)
                            16'd00  :   trans_tnet_data_o   <=  IP_VISION_TOS[7:0];
                            16'd01  :   trans_tnet_data_o   <=  ip_length[15:8];
                            16'd02  :   trans_tnet_data_o   <=  ip_length[07:0];
                            16'd03  :   trans_tnet_data_o   <=  ip_identify[15:8];
                            16'd04  :   trans_tnet_data_o   <=  ip_identify[07:0];
                            16'd05  :   trans_tnet_data_o   <=  IP_FLAG_OFFSET[15:8];
                            16'd06  :   trans_tnet_data_o   <=  IP_FLAG_OFFSET[07:0];
                            16'd07  :   trans_tnet_data_o   <=  IP_TTL_PROTO[15:8];
                            16'd08  :   trans_tnet_data_o   <=  IP_TTL_PROTO[07:0];
                            16'd09  :   trans_tnet_data_o   <=  ip_checksum[15:8];
                            16'd10  :   trans_tnet_data_o   <=  ip_checksum[07:0];
                            16'd11  :   trans_tnet_data_o   <=  LOCAL_IP[31:24];
                            16'd12  :   trans_tnet_data_o   <=  LOCAL_IP[23:16];
                            16'd13  :   trans_tnet_data_o   <=  LOCAL_IP[15:8];
                            16'd14  :   trans_tnet_data_o   <=  LOCAL_IP[07:0];
                            16'd15  :   trans_tnet_data_o   <=  target_ip[31:24];
                            16'd16  :   trans_tnet_data_o   <=  target_ip[23:16];
                            16'd17  :   trans_tnet_data_o   <=  target_ip[15:8];
                            16'd18  :   trans_tnet_data_o   <=  target_ip[07:0];
                            16'd19  :   trans_tnet_data_o   <=  LOCAL_SP[15:8];     //  next data                 
                            default :   trans_tnet_data_o   <=  '0;
                    endcase  
            end // IP_HEAD    

            UDP_HEAD    : begin
                    if (octec_cnt == UDP_HEAD_LENGTH-1) begin
                        octec_cnt           <=  0;
                        flag_tx_over        <=  1;                                             
                    end
                    else begin
                        octec_cnt           <=  octec_cnt + (trans_tnet_valid_out && trans_tnet_ready_in);
                        flag_tx_over        <=  0;                       
                    end

                    trans_tnet_valid_o  <=  1;  

                    case (octec_cnt)
                            16'd00  :       trans_tnet_data_o   <=  LOCAL_SP[7:0];
                            16'd01  :       trans_tnet_data_o   <=  LOCAL_DP[15:8];
                            16'd02  :       trans_tnet_data_o   <=  LOCAL_DP[07:0];
                            16'd03  :       trans_tnet_data_o   <=  udp_length[15:8];
                            16'd04  :       trans_tnet_data_o   <=  udp_length[07:0];
                            16'd05  :       trans_tnet_data_o   <=  udp_checksum[15:8];
                            16'd06  : begin trans_tnet_data_o   <=  udp_checksum[07:0];  m_axis_tready <=  '1;    end
                            16'd07  :       trans_tnet_data_o   <=  m_axis_tdata;       //  next data                   
                            default :       trans_tnet_data_o   <=  '0;
                    endcase
            end // UDP_HEAD 

            UDP_DATA    : begin
                    if (trans_tnet_last_out) begin
                        octec_cnt           <=  0;
                        flag_tx_over        <=  1;
                    end
                    else begin
                        octec_cnt           <=  octec_cnt + (trans_tnet_valid_out && trans_tnet_ready_in);
                        flag_tx_over        <=  0;                       
                    end
                    m_axis_tready       <=  m_axis_tvalid && !m_axis_tlast; 
                    trans_tnet_valid_o  <=  m_axis_tvalid;
                    trans_tnet_data_o   <=  m_axis_tdata;
                    trans_tnet_last_o   <=  m_axis_tlast;

            end // UDP_DATA    
            default : begin
                    octec_cnt           <=  '0;
                    flag_tx_over        <=  '0;
                    m_axis_tready       <=  '0;
                    trans_tnet_data_o   <=  '0;
                    trans_tnet_valid_o  <=  '0;
                    trans_tnet_last_o   <=  '0;               
            end // default 
        endcase
    end
    
/*------------------------------------------------------------------------------
--  IP check sum
------------------------------------------------------------------------------*/
    localparam  [31:0]  IP_LOCAL_SUM    =   IP_VISION_TOS + IP_FLAG_OFFSET + IP_TTL_PROTO + LOCAL_IP[31:16] + LOCAL_IP[15:0];

   always_ff @(posedge logic_clk) begin 
       case (udp_next)
            IDLE        : begin
                    ip_checksum <=  IP_LOCAL_SUM;
            end // IDLE       

            ETH_HEAD    : begin
                    case (octec_cnt)
                        16'h01  :   ip_checksum <=  ip_checksum + ip_length;
                        16'h02  :   ip_checksum <=  ip_checksum + ip_identify;
                        16'h03  :   ip_checksum <=  ip_checksum + target_ip[31:16];
                        16'h04  :   ip_checksum <=  ip_checksum + target_ip[15:0];
                        16'h05  :   ip_checksum <=  ~(ip_checksum[31:16] + ip_checksum[15:0]);                       
                        default :   ip_checksum <=  ip_checksum;
                    endcase                    
            end // ETH_HEAD    

           default : begin
                    ip_checksum <=  ip_checksum;
           end
       endcase
   end
/*------------------------------------------------------------------------------
--  udp check sum
    check range : pseudo header + udp header + data

    pseudo header
    source ip (4 octets) destination ip (4 octets) 0 (1 octet) 11 (1 octet) udp length (2 octet)
------------------------------------------------------------------------------*/
    localparam  [31:0]  UDP_LOCAL_SUM   =   LOCAL_IP[31:16] + LOCAL_IP[15:0] + {8'h00,8'h11} + LOCAL_SP + LOCAL_DP;

    always_ff @(posedge logic_clk) begin 
        case (udp_next)
            IDLE    : begin
                    udp_checksum    <=  UDP_LOCAL_SUM;
            end // IDLE    

            ETH_HEAD : begin
                    case (octec_cnt)
                        16'h06  :   udp_checksum <=  udp_checksum + target_ip[31:16];
                        16'h07  :   udp_checksum <=  udp_checksum + target_ip[15:0];
                        16'h08  :   udp_checksum <=  udp_checksum + udp_length + udp_length;
                        16'h09  :   udp_checksum <=  udp_checksum + udp_datasum;
                        16'h0A  :   udp_checksum <=  ~(udp_checksum[31:16] + udp_checksum[15:0]);                       
                        default :   udp_checksum <=  udp_checksum;
                    endcase                                         
            end // ETH_HEAD 

            default : begin
                    udp_checksum    <=  udp_checksum;
            end // default 
        endcase
    end        
/*------------------------------------------------------------------------------
--  ARP query state
------------------------------------------------------------------------------*/
    typedef enum   {AIDLE,ARP_IP,ARP_MAC,TRIG_ARP}    state_q;
    (* fsm_encoding = "one-hot" *) state_q arp_query_state,arp_query_next;

    always_ff @(posedge logic_clk) begin 
        if(logic_rst) begin
            arp_query_state <= AIDLE;
        end else begin
            arp_query_state <= arp_query_next;
        end
    end

    always_comb begin 
        case (arp_query_state)
            AIDLE   :   arp_query_next  =   trig_arp_query      ? ARP_IP    : AIDLE;
            ARP_IP  :   arp_query_next  =   arp_query_ready_in  ? ARP_MAC   : ARP_IP;
            ARP_MAC :   arp_query_next  =   arp_response_err_in ? TRIG_ARP  : (arp_response_ready_out ? AIDLE : ARP_MAC);
            TRIG_ARP:   arp_query_next  =   trig_arp_qready_in  ? ARP_IP    : TRIG_ARP;
            default :   arp_query_next  =   AIDLE;
        endcase
    end  

/*------------------------------------------------------------------------------
--  do ARP query 
------------------------------------------------------------------------------*/
    logic   [31:0]  arp_query_ip_o          =   '0;
    logic           arp_query_valid_o       =   '0;
    logic           arp_response_ready_o    =   '0;
    logic   [31:0]  trig_arp_ip_o           =   '0;
    logic           trig_arp_qvalid_o       =   '0;

    assign          arp_query_ip_out        =   arp_query_ip_o;
    assign          arp_query_valid_out     =   arp_query_valid_o;
    assign          arp_response_ready_out  =   arp_response_ready_o;
    assign          trig_arp_ip_out         =   trig_arp_ip_o;
    assign          trig_arp_qvalid_out     =   trig_arp_qvalid_o;

    always_ff @(posedge logic_clk) begin
        case (arp_query_next)
            ARP_IP  :   begin
                    arp_query_ip_o          <=  udp_tip_in;
                    arp_query_valid_o       <=  1;
            end // ARP_IP  

            ARP_MAC :   begin
                    arp_query_ip_o          <=  '0;
                    arp_query_valid_o       <=  '0;                 
                    arp_response_ready_o    <=  arp_response_valid_in;                    
            end // ARP_MAC 

            TRIG_ARP    : begin
                    arp_response_ready_o    <=  '0;
                    trig_arp_ip_o           <=  target_ip;
                    trig_arp_qvalid_o       <=  1;
            end // TRIG_ARP

            default : begin
                    arp_query_ip_o          <=   '0;
                    arp_query_valid_o       <=   '0;
                    arp_response_ready_o    <=   '0;
                    trig_arp_ip_o           <=   '0;
                    trig_arp_qvalid_o       <=   '0;                
            end // default 
        endcase
    end
    
 endmodule : udp_tx