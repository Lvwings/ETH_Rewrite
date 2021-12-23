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
    output          arp_rlast_out
    //  udp
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
    typedef enum logic [2:0] {IDLE,ETH_HEAD,IP_HEAD,UDP_HEAD,ICMP_DATA,UDP_DATA,ARP_DATA} state_f;
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

    always_comb begin
        case (split_state)
            IDLE        :                                                   split_next  =   net_rvalid_in ? ETH_HEAD : IDLE;
            ETH_HEAD    :   if      (flag_err_frame || net_rlast_in)        split_next  =   IDLE;
                            else if (flag_rx_over && eth_type == ARP_TYPE)  split_next  =   ARP_DATA;
                            else if (flag_rx_over && eth_type == IP_TYPE)   split_next  =   IP_HEAD;
                            else                                            split_next  =   ETH_HEAD;
            
            IP_HEAD     :   if      (flag_err_frame)                        split_next  =   IDLE;
                            else if (flag_rx_over && ip_proto == ICMP_PROTO)split_next  =   ICMP_DATA;
                            else if (flag_rx_over && ip_proto == UDP_PROTO) split_next  =   UDP_HEAD;
                            else                                            split_next  =   IP_HEAD;

            UDP_HEAD    :   if      (flag_err_frame)                        split_next  =   IDLE;
                            else if (flag_rx_over)                          split_next  =   UDP_DATA;
                            else                                            split_next  =   UDP_HEAD;

            UDP_DATA    :   if      (flag_err_frame)                        split_next  =   IDLE;
                            else if (flag_rx_over)                          split_next  =   IDLE;
                            else                                            split_next  =   UDP_DATA;

            ICMP_DATA   :   if      (flag_err_frame)                        split_next  =   IDLE;                                   
                            else if (flag_rx_over)                          split_next  =   IDLE;
                            else                                            split_next  =   ICMP_DATA;  

            ARP_DATA    :   if      (flag_rx_over)                          split_next  =   IDLE;                                                                   
                            else                                            split_next  =   ARP_DATA;    
                                
            default :                                                       split_next  =   IDLE;
        endcase   
    end

/*------------------------------------------------------------------------------
--  rx mac data
------------------------------------------------------------------------------*/
    (* MARK_DEBUG="true" *) logic   [7:0]   length_cnt      =   '0;
    (* MARK_DEBUG="true" *) logic   [47:0]  eth_da_mac      =   '0;
    (* MARK_DEBUG="true" *) logic   [31:0]  ip_da_ip        =   '0;    
    logic           net_rready_o    =   '0;

    always_ff @(posedge logic_clk) begin 
       case (split_next)
            ETH_HEAD    : begin
                        if (length_cnt == ETH_HEAD_LENGTH) begin
                            flag_rx_over    <=  1;
                            length_cnt      <=  0;
                            net_rready_o    <=  0;
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
                            flag_err_frame  <=  !(ip_da_ip == LOCAL_IP);
                        end
                        else begin
                            flag_rx_over    <=  0;
                            net_rready_o    <=  net_rvalid_in & (length_cnt < IP_HEAD_LENGTH-1);
                            length_cnt      <=  length_cnt + (net_rready_out & net_rvalid_in);

                            case (length_cnt)
                                8'd9    :   ip_proto        <=  net_rdata_in;
                                8'd16   :   ip_da_ip[31:24] <=  net_rdata_in;
                                8'd17   :   ip_da_ip[23:16] <=  net_rdata_in;
                                8'd18   :   ip_da_ip[15:08] <=  net_rdata_in;
                                8'd19   :   ip_da_ip[07:00] <=  net_rdata_in;                                                       
                                default :   begin
                                            ip_proto        <=  ip_proto;
                                            ip_da_ip        <=  ip_da_ip;
                                end // default 
                            endcase                           
                        end                        
            end // IP_HEAD 

            UDP_HEAD    :   begin
                        if (length_cnt == UDP_HEAD_LENGTH) begin
                            flag_rx_over    <=  1;
                            length_cnt      <=  0;
                            net_rready_o    <=  0;
                        end
                        else begin
                            flag_rx_over    <=  0;
                            net_rready_o    <=  net_rvalid_in & (length_cnt < UDP_HEAD_LENGTH-1);
                            length_cnt      <=  length_cnt + (net_rready_out & net_rvalid_in);                            
                        end
            end // UDP_HEAD

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

           default : begin
                        length_cnt      <=  '0;
                        flag_rx_over    <=  '0;
                        flag_err_frame  <=  '0;
                        net_rready_o    <=  '0;
                        eth_type        <=  '0;
                        eth_da_mac      <=  '0;
                        ip_da_ip        <=  '0;
                        ip_proto        <=  '0;
           end
       endcase
    end

    assign  net_rready_out  =   net_rready_o;
    
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

 endmodule : frame_split