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
    input   [7:0]   net_rmac_data_in,
    input           net_rmac_valid_in,
    output          net_rmac_ready_out,
    input           net_rmac_last_in, 
    input   [34:0]  net_rmac_type_in,       //  3'b100 ICMP, 3'b010 UDP, 3'b001 ARP

    //  arp rx data out
    output  [7:0]   arp_rdata_out,
    output          arp_rvalid_out,
    input           arp_rready_in,
    output          arp_rlast_out,

    //  udp
    output  [7:0]   udp_rdata_out,
    output          udp_rvalid_out,
    input           udp_rready_in,
    output          udp_rlast_out,
    output  [31:0]  udp_rip_out   
 );

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
    logic               trig_split_start    =   '0;
    logic               net_rmac_valid_d        =   '0;

    always_ff @(posedge logic_clk) begin
        net_rmac_valid_d        <= net_rmac_valid_in;
        trig_split_start    <= !net_rmac_valid_d & net_rmac_valid_in;
    end
    
    always_comb begin
        case (split_state)
            IDLE        :   if      (trig_split_start && net_rmac_type_in[0])   split_next  =   ARP_DATA;
                            else if (trig_split_start && net_rmac_type_in[1])   split_next  =   UDP_DATA;
                            else if (trig_split_start && net_rmac_type_in[2])   split_next  =   ICMP_DATA;
                            else                                                split_next  =   IDLE;            
    
            ICMP_DATA   :                                                       split_next  =   net_rmac_last_in ? IDLE : ICMP_DATA;  
                                
            ARP_DATA    :                                                       split_next  =   arp_rlast_out ? IDLE : ARP_DATA;  
                
            UDP_DATA    :                                                       split_next  =   udp_rlast_out ? IDLE : UDP_DATA;                   
            default :                                                           split_next  =   IDLE;
        endcase   
    end

/*------------------------------------------------------------------------------
--  rx mac data
------------------------------------------------------------------------------*/
    logic           net_rmac_ready_o    =   '0;   

    always_ff @(posedge logic_clk) begin 
       case (split_next)
            ARP_DATA    :   begin
                        net_rmac_ready_o    <=  net_rmac_valid_in & arp_rready_in & !net_rmac_last_in;                
            end // ARP_DATA   

            UDP_DATA    :  begin
                        net_rmac_ready_o    <=  net_rmac_valid_in & udp_rready_in & !net_rmac_last_in;
            end 
   
           default : begin
                        net_rmac_ready_o    <=  '0;
           end
       endcase
    end

    assign  net_rmac_ready_out  =   net_rmac_ready_o;
 
/*------------------------------------------------------------------------------
--  arp rx data 
------------------------------------------------------------------------------*/
    logic   [7:0]   arp_rdata_o     =   '0;
    logic           arp_rvalid_o    =   '0;
    logic           arp_rlast_o     =   '0;

    always_ff @(posedge logic_clk) begin 
        case (split_next)
            ARP_DATA    :   begin
                        arp_rvalid_o    <=  net_rmac_valid_in;
                        arp_rdata_o     <=  net_rmac_data_in;
                        arp_rlast_o     <=  net_rmac_last_in;   
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
    logic   [7:0]   udp_rdata     = '0;
    logic           udp_rvalid    = '0;
    logic           udp_rlast     = '0;
    logic   [31:0]  udp_rip       = '0;

    always_ff @(posedge logic_clk) begin 
        case (split_next)
            UDP_DATA    : begin
                udp_rdata  <=  net_rmac_data_in;
                udp_rvalid <=  net_rmac_valid_in & net_rmac_ready_out;
                udp_rlast  <=  net_rmac_last_in;
                udp_rip    <=  net_rmac_type_in[34:3]; 
            end // UDP_DATA    
            default : begin
                udp_rdata  <=  '0;
                udp_rvalid <=  '0;
                udp_rlast  <=  '0;    
                udp_rip    <=  '0;        
            end // default 
        endcase
    end   

    assign      udp_rdata_out   =   udp_rdata;
    assign      udp_rvalid_out  =   udp_rvalid;
    assign      udp_rlast_out   =   udp_rlast;  
    assign      udp_rip_out     =   udp_rip;  
/*
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
);*/
 endmodule : frame_split