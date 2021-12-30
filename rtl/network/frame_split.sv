`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : frame_split.sv
 Create     : 2021-12-15 13:34:29
 Revise     : 2021-12-15 13:34:29
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module frame_split #(
    parameter       LOCAL_IP    =   32'hC0A8_006E,
    parameter       LOCAL_MAC   =   48'hABCD_1234_5678
    )
    (
    input           logic_clk,
    input           logic_rst,   
 
     //  net rx data in
    input   [7:0]   net_rdata_in,
    input           net_rvalid_in,
    output          net_rready_out,
    input           net_rlast_in,   

    //  arp rx data out
    output  [7:0]   arp_rdata_out,
    output          arp_rvalid_out,
    input           arp_rready_in,
    output          arp_rlast_out,

    //  udp
    output  [7:0]   udp_rdata_out,
    output          udp_rvalid_out,
    input           udp_rready_in,
    output          udp_rlast_out   
 );

 /*------------------------------------------------------------------------------
 --  eth frame paramter
 ------------------------------------------------------------------------------*/
    localparam  GLOBAL_MAC      =   48'hFFFF_FFFF_FFFF;
    localparam  ARP_TYPE        =   16'h0806;
    localparam  IP_TYPE         =   16'h0800;
    localparam  UDP_PROTO       =   8'h11;
    localparam  ICMP_PROTO      =   8'h01;

    localparam  ETH_HEAD_LENGTH =   8'd14;
    localparam  IP_HEAD_LENGTH  =   8'd20;
    localparam  UDP_HEAD_LENGTH =   8'd8;

/*------------------------------------------------------------------------------
--  state
------------------------------------------------------------------------------*/
    
    typedef enum {IDLE,ETH_HEAD,IP_HEAD,UDP_HEAD,ICMP_DATA,UDP_DATA,ARP_DATA,PADDING} state_f;
    state_f split_state,split_next;

    always_ff @(posedge logic_clk) begin 
        if(logic_rst) begin
            split_state <= IDLE;
        end else begin
            split_state <= split_next;
        end
    end

/*------------------------------------------------------------------------------
--  state jump
------------------------------------------------------------------------------*/
    logic       [15:0]  eth_type        =   '0;
    logic       [7:0]   ip_proto        =   '0;

    logic               flag_err_frame  =   '0;
    logic               flag_rx_over    =   '0;
    logic       [1:0]   flag_eth_type   =   '0;
    logic       [1:0]   flag_ip_proto   =   '0;

    always_comb begin
        case (split_state)
            IDLE        :                                                   split_next  =   net_rvalid_in ? ETH_HEAD : IDLE;
            ETH_HEAD    :   if      (flag_err_frame || net_rlast_in)        split_next  =   IDLE;
                            else if (flag_rx_over && flag_eth_type[0])      split_next  =   ARP_DATA;
                            else if (flag_rx_over && flag_eth_type[1])      split_next  =   IP_HEAD;
                            else                                            split_next  =   ETH_HEAD;
            
            IP_HEAD     :   if      (flag_err_frame)                        split_next  =   IDLE;
                            else if (flag_rx_over && flag_ip_proto[0])      split_next  =   ICMP_DATA;
                            else if (flag_rx_over && flag_ip_proto[1])      split_next  =   UDP_HEAD;
                            else                                            split_next  =   IP_HEAD;

            UDP_HEAD    :   if      (flag_err_frame)                        split_next  =   IDLE;
                            else if (flag_rx_over)                          split_next  =   UDP_DATA;
                            else                                            split_next  =   UDP_HEAD;

            UDP_DATA    :   if      (flag_err_frame)                        split_next  =   IDLE;
                            else if (flag_rx_over && net_rvalid_in)         split_next  =   PADDING;
                            else if (flag_rx_over)                          split_next  =   IDLE;
                            else                                            split_next  =   UDP_DATA;

            ICMP_DATA   :   if      (flag_err_frame)                        split_next  =   IDLE;                                   
                            else if (flag_rx_over)                          split_next  =   IDLE;
                            else                                            split_next  =   ICMP_DATA;  

            ARP_DATA    :   if      (flag_rx_over)                          split_next  =   IDLE;                                                                   
                            else                                            split_next  =   ARP_DATA;    
            
            PADDING     :                                                   split_next  =   net_rlast_in ? IDLE : PADDING;                   
            default :                                                       split_next  =   IDLE;
        endcase   
    end

/*------------------------------------------------------------------------------
--  rx mac data
------------------------------------------------------------------------------*/
    logic   [7:0]   length_cnt      =   '0;
    logic           net_rready_o    =   '0;

    logic   [47:0]  eth_da_mac      =   '0;  

    logic   [15:0]  ip_rx_checksum  =   '0;
    logic   [31:0]  ip_checksum     =   '0;     //  for calcualte   
    logic   [31:0]  ip_da_ip        =   '0; 
    logic   [31:0]  ip_sa_ip        =   '0;    

    logic   [15:0]  udp_length      =   '0;  
    logic   [15:0]  udp_data_length =   '0;   
    logic   [15:0]  udp_rx_checksum =   '0;   
    logic   [31:0]  udp_checksum    =   '0;
    logic           udp_rready;

    always_ff @(posedge logic_clk) begin 
       case (split_next)
            ETH_HEAD    : begin
                        if (length_cnt == ETH_HEAD_LENGTH) begin
                            flag_rx_over    <=  1;
                            length_cnt      <=  0;
                            net_rready_o    <=  0;
                            flag_eth_type   <=  {(eth_type == IP_TYPE),(eth_type == ARP_TYPE)};
                            flag_err_frame  <=  (eth_da_mac != LOCAL_MAC) & (eth_da_mac != GLOBAL_MAC);
                        end
                        else begin
                            net_rready_o    <=  net_rvalid_in & (length_cnt < ETH_HEAD_LENGTH-1);
                            length_cnt      <=  length_cnt + (net_rready_out & net_rvalid_in);
                            eth_type        <=  {eth_type[7:0], net_rdata_in};

                            if (length_cnt < 6)
                                eth_da_mac[8*(5-length_cnt) +: 8]   <=  net_rdata_in;
                            else
                                eth_da_mac                          <=  eth_da_mac;                           
                        end
            end // ETH_HEAD 

            IP_HEAD     : begin
                        if (length_cnt == IP_HEAD_LENGTH) begin
                            flag_rx_over    <=  1;
                            length_cnt      <=  0;
                            net_rready_o    <=  0;
                            flag_ip_proto   <=  {(ip_proto == UDP_PROTO),(ip_proto == ICMP_PROTO)};
                            flag_err_frame  <=  !(ip_da_ip == LOCAL_IP) || (ip_rx_checksum != ~(ip_checksum[31:16] + ip_checksum[15:0]));
                        end
                        else begin
                            flag_rx_over    <=  0;
                            net_rready_o    <=  net_rvalid_in & (length_cnt < IP_HEAD_LENGTH-1);
                            length_cnt      <=  length_cnt + (net_rready_out & net_rvalid_in);

                            case (length_cnt)
                                8'd9    :   ip_proto              <=  net_rdata_in;
                                8'd10   :   ip_rx_checksum[15:08] <=  net_rdata_in;
                                8'd11   :   ip_rx_checksum[07:00] <=  net_rdata_in;
                                8'd12   :   ip_sa_ip[31:24]       <=  net_rdata_in;
                                8'd13   :   ip_sa_ip[23:16]       <=  net_rdata_in;
                                8'd14   :   ip_sa_ip[15:08]       <=  net_rdata_in;
                                8'd15   :   ip_sa_ip[07:00]       <=  net_rdata_in;                                   
                                8'd16   :   ip_da_ip[31:24]       <=  net_rdata_in;
                                8'd17   :   ip_da_ip[23:16]       <=  net_rdata_in;
                                8'd18   :   ip_da_ip[15:08]       <=  net_rdata_in;
                                8'd19   :   ip_da_ip[07:00]       <=  net_rdata_in;                                                       
                                default :   begin
                                            ip_proto              <=  ip_proto;
                                            ip_sa_ip              <=  ip_sa_ip;
                                            ip_da_ip              <=  ip_da_ip;
                                            ip_rx_checksum        <=  ip_rx_checksum;
                                end // default 
                            endcase                           
                        end                        
            end // IP_HEAD 

            UDP_HEAD    :   begin
                        if (length_cnt == UDP_HEAD_LENGTH) begin
                            flag_rx_over    <=  1;
                            length_cnt      <=  0;
                            net_rready_o    <=  0;
                            udp_data_length <=  udp_length - 8;
                        end
                        else begin
                            flag_rx_over    <=  0;
                            net_rready_o    <=  net_rvalid_in & (length_cnt < UDP_HEAD_LENGTH-1);
                            length_cnt      <=  length_cnt + (net_rready_out & net_rvalid_in); 

                            case (length_cnt)
                                8'd4    :   udp_length[15:8]        <=  net_rdata_in;   
                                8'd5    :   udp_length[07:0]        <=  net_rdata_in;
                                8'd6    :   udp_rx_checksum[15:8]   <=  net_rdata_in;
                                8'd7    :   udp_rx_checksum[07:0]   <=  net_rdata_in;
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
                            net_rready_o    <=  0;
                            flag_err_frame  <=  (udp_rx_checksum != ~(udp_checksum[31:16] + udp_checksum[15:0]));
                        end
                        else begin
                            flag_rx_over    <=  0;
                            net_rready_o    <=  net_rvalid_in & (length_cnt < udp_data_length-1) & udp_rready;
                            length_cnt      <=  length_cnt + (net_rready_out & net_rvalid_in);                             
                        end
            end // UDP_DATA    

            ARP_DATA    :   begin
                        if (net_rlast_in) begin
                            flag_rx_over    <=  1;
                            net_rready_o    <=  0;
                        end
                        else begin
                            flag_rx_over    <=  0;
                            net_rready_o    <=  net_rvalid_in;
                        end                
            end // ARP_DATA    

            PADDING     :   begin
                        flag_rx_over    <=  0;
                        net_rready_o    <=  net_rvalid_in & !net_rlast_in;
            end // PADDING     

           default : begin
                        length_cnt      <=  '0;
                        flag_rx_over    <=  '0;
                        flag_err_frame  <=  '0;
                        net_rready_o    <=  '0;
                        eth_type        <=  '0;
                        eth_da_mac      <=  '0;
                        ip_da_ip        <=  '0;
                        ip_sa_ip        <=  '0;
                        ip_proto        <=  '0;
                        ip_rx_checksum  <=  '0;
                        udp_length      <=  '0;
                        udp_data_length <=  '0;
                        udp_rx_checksum <=  '0;
           end
       endcase
    end

    assign  net_rready_out  =   net_rready_o;
    
/*------------------------------------------------------------------------------
--  ip check sum
------------------------------------------------------------------------------*/

    logic   [15:0]  ip_sum_data    =   '0;

    always_ff @(posedge logic_clk) begin 
        case (split_next)
            IP_HEAD : begin
                case (length_cnt)
                    //  when receive ip head, set ip check sum to 0
                    8'h0A,8'h0B :   begin 
                                    ip_sum_data <=  '0;
                                    ip_checksum <=  !length_cnt[0] ? (ip_checksum + ip_sum_data) : ip_checksum;
                    end 
                    //  ip_checksum is rewrited to reduce 1 clk
                    IP_HEAD_LENGTH-1:   begin
                                    ip_sum_data <=  '0;
                                    ip_checksum <=  ip_checksum + {ip_sum_data[7:0], net_rdata_in};
                    end
                    default : begin
                                    ip_sum_data <=  net_rready_out ? {ip_sum_data[7:0], net_rdata_in} : ip_sum_data;
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

    always_ff @(posedge logic_clk) begin 
        case (split_next)
            UDP_HEAD    : begin
                udp_sum_data    <=  net_rready_out ? {udp_sum_data[7:0], net_rdata_in} : '0;

                //  pseudo header is calculated in this part
                case (length_cnt)
                    8'd1    :   udp_checksum   <=  udp_checksum + ip_sa_ip[31:16];
                    8'd2    :   udp_checksum   <=  udp_checksum + udp_sum_data;     // + ip_sa_ip[31:16] + ip_sa_ip[15:0];  
                    8'd3    :   udp_checksum   <=  udp_checksum + ip_sa_ip[15:0];
                    8'd4    :   udp_checksum   <=  udp_checksum + udp_sum_data;     // + ip_da_ip[31:16] + ip_da_ip[15:0]; 
                    8'd5    :   udp_checksum   <=  udp_checksum + ip_da_ip[31:16];
                    8'd6    :   udp_checksum   <=  udp_checksum + udp_length + udp_length;
                    8'd7    :   udp_checksum   <=  udp_checksum + ip_da_ip[15:0];
                    8'd8    :   udp_checksum   <=  udp_checksum + {8'h00,8'h11};
                    default :   udp_checksum   <=  udp_checksum;
                endcase    
            end // UDP_HEAD   

            UDP_DATA    : begin
                udp_sum_data    <=  net_rready_out ? {udp_sum_data[7:0], net_rdata_in} : udp_sum_data;

                case (length_cnt) 
                    //  if udp data length is odd, {8'h00} should be added behind data to make up 16-bit.      
                    udp_data_length-1 : udp_checksum   <=  !length_cnt[0] ? (udp_checksum + udp_sum_data + {net_rdata_in, 8'h00}) : (udp_checksum + {udp_sum_data[7:0], net_rdata_in});                                       
                    default :           udp_checksum   <=  !length_cnt[0] ? (udp_checksum + udp_sum_data) : udp_checksum; 
                endcase

            end // UDP_DATA    
                
            default : begin
                udp_checksum    <=  '0;
                udp_sum_data    <=  '0;
            end // default 
        endcase
    end

/*------------------------------------------------------------------------------
--  arp rx data 
------------------------------------------------------------------------------*/
    logic   [7:0]   arp_rdata_o     =   '0;
    logic           arp_rvalid_o    =   '0;
    logic           arp_rlast_o     =   '0;

    always_ff @(posedge logic_clk) begin 
        case (split_next)
            ARP_DATA    :   begin
                        arp_rvalid_o    <=  1;
                        arp_rdata_o     <=  net_rdata_in;
                        arp_rlast_o     <=  net_rlast_in;   
            end // ARP_DATA  

            default : begin
                        arp_rvalid_o    <=  0;
                        arp_rdata_o     <=  0;
                        arp_rlast_o     <=  0;                  
            end // default 
        endcase
    end

    assign  arp_rdata_out   =   arp_rdata_o;
    assign  arp_rvalid_out  =   arp_rvalid_o;
    assign  arp_rlast_out   =   arp_rlast_o;

/*------------------------------------------------------------------------------
--  udp rx data
------------------------------------------------------------------------------*/
    logic   [7:0]   udp_rdata     =   '0;
    logic           udp_rvalid    =   '0;
    logic           udp_rlast     =   '0;
    logic           udp_fifo_rstn =   '1;

    always_ff @(posedge logic_clk) begin 
        case (split_state)
            UDP_DATA    : begin
                udp_rdata     <=  net_rdata_in;
                udp_rvalid    <=  net_rvalid_in & net_rready_out;
                udp_rlast     <=  (length_cnt == udp_data_length-1);    //  udp_data_length-1
                udp_fifo_rstn <=  !flag_err_frame;
            end // UDP_DATA    
            default : begin
                udp_rdata     <=  '0;
                udp_rvalid    <=  '0;
                udp_rlast     <=  '0;
                udp_fifo_rstn <=  !logic_rst;                
            end // default 
        endcase
    end       

udp_rx_fifo udp_rx_fifo (
  .s_axis_aresetn   (udp_fifo_rstn),  // input wire s_axis_aresetn
  .s_axis_aclk      (logic_clk),        // input wire s_axis_aclk

  .s_axis_tvalid    (udp_rvalid),    // input wire s_axis_tvalid
  .s_axis_tready    (udp_rready),    // output wire s_axis_tready
  .s_axis_tdata     (udp_rdata),      // input wire [7 : 0] s_axis_tdata
  .s_axis_tlast     (udp_rlast),      // input wire s_axis_tlast

  .m_axis_tvalid    (udp_rvalid_out),    // output wire m_axis_tvalid
  .m_axis_tready    (udp_rready_in),    // input wire m_axis_tready
  .m_axis_tdata     (udp_rdata_out),      // output wire [7 : 0] m_axis_tdata
  .m_axis_tlast     (udp_rlast_out)      // output wire m_axis_tlast
);
 endmodule : frame_split