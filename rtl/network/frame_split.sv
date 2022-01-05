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
 
     //  net rx data in  -> from mac
    input   [7:0]   net_rdata_in,
    input           net_rvalid_in,
    output          net_rready_out,
    input           net_rlast_in, 
    input   [2:0]   net_rtype_in,       //  2'b01 ARP 2'b10 IP 

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


/*------------------------------------------------------------------------------
--  state
------------------------------------------------------------------------------*/
    
    typedef enum {IDLE,UDP_DATA,ICMP_DATA,ARP_DATA} state_f;
    (* fsm_encoding = "one-hot" *) state_f split_state,split_next;

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
    logic               flag_err_frame      =   '0;
    logic               flag_rx_over        =   '0;
    
    logic               trig_split_start    =   '0;
    logic               net_rvalid_d        =   '0;

    always_ff @(posedge logic_clk) begin
        net_rvalid_d        <= net_rvalid_in;
        trig_split_start    <= !net_rvalid_d & net_rvalid_in;
    end
    
    always_comb begin
        case (split_state)
            IDLE        :   if      (trig_split_start && net_rtype_in[0])   split_next  =   ARP_DATA;
                            else if (trig_split_start && net_rtype_in[1])   split_next  =   UDP_DATA;
                            else if (trig_split_start && net_rtype_in[2])   split_next  =   ICMP_DATA;
                            else                                            split_next  =   IDLE;            

            ICMP_DATA   :   if      (flag_err_frame)                        split_next  =   IDLE;                                   
                            else if (flag_rx_over)                          split_next  =   IDLE;
                            else                                            split_next  =   ICMP_DATA;  

            ARP_DATA    :   if      (flag_rx_over)                          split_next  =   IDLE;                                                                   
                            else                                            split_next  =   ARP_DATA;    
            
            UDP_DATA     :                                                  split_next  =   net_rlast_in ? IDLE : UDP_DATA;                   
            default :                                                       split_next  =   IDLE;
        endcase   
    end

/*------------------------------------------------------------------------------
--  rx mac data
------------------------------------------------------------------------------*/
    logic   [7:0]   length_cnt      =   '0;
    logic           net_rready_o    =   '0;   
    logic           udp_rready;

    always_ff @(posedge logic_clk) begin 
       case (split_next)
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

            UDP_DATA    :  begin
                        net_rready_o    <=  net_rvalid_in & !net_rlast_in;
            end 
   
           default : begin
                        length_cnt      <=  '0;
                        flag_rx_over    <=  '0;
                        flag_err_frame  <=  '0;
                        net_rready_o    <=  '0;

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
                udp_rlast     <=  net_rlast_in;    //  udp_data_length-1
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