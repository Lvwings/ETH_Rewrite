`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : arp_tx.sv
 Create     : 2021-12-15 16:06:36
 Revise     : 2021-12-15 16:06:36
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module arp_tx #(
    parameter       LOCAL_IP    =   32'hC0A8_006E,
    parameter       LOCAL_MAC   =   48'hABCD_1234_5678
    )
 (
    input           logic_clk,
    input           logic_rst,

    //  arp query trigger
    input           trig_arp_qvalid_in,
    input   [31:0]  trig_arp_ip_in,
    output          trig_arp_qready_out,   //  arp query has been responded

     //  arp rx data in
    input   [7:0]   arp_rdata_in,
    input           arp_rvalid_in,
    output          arp_rready_out,
    input           arp_rlast_in,   

    //  cache write - store ip and mac
    //  axi-lite write
    output  [31:0]  arp_write_ip_out,
    output          arp_write_valid_out,
    input           arp_write_ready_in,

    output  [47:0]  arp_store_mac_out,
    output          arp_store_valid_out,
    input           arp_store_ready_in,
    
    output          arp_bvalid_out,
    input           arp_bready_in,

    //  arp frame to mac
    output  [7:0]   arp_tdata_out,
    output          arp_tvalid_out,
    input           arp_tready_in,
    output          arp_tlast_out
     
 );

/*------------------------------------------------------------------------------
--  arp frame parameter
------------------------------------------------------------------------------*/
    localparam          OPCODE_QUERY        =   16'h0001;
    localparam          OPCODE_RESPONSE     =   16'h0002;
    localparam          ARP_LENGTH          =   8'd28;
/*------------------------------------------------------------------------------
--  reveive state
------------------------------------------------------------------------------*/
    typedef enum    logic [2:0]   {RIDLE,RECEIVE,WRITE_ADDR,WRITE_DATA,RESPONSE}    state_ar;
    state_ar arp_rstate,arp_rnext;

    always_ff @(posedge logic_clk) begin 
        if(logic_rst) begin
            arp_rstate <= RIDLE;
        end else begin
            arp_rstate <= arp_rnext;
        end
    end
 
/*------------------------------------------------------------------------------
--  state jump
------------------------------------------------------------------------------*/
    logic   [15:0]  opcode      =   '0;
    logic   [31:0]  da_ip       =   '0;
    logic   [31:0]  sa_ip       =   '0;
    logic   [47:0]  sa_mac      =   '0;

    logic           flag_rerr   =   '0;
    logic           flag_rover  =   '0;

    always_comb begin 
        case (arp_rstate)                  
            RIDLE    :      if (arp_rvalid_in)                          arp_rnext    =   RECEIVE;
                            else                                        arp_rnext    =   RIDLE;
        
            RECEIVE :       if      (flag_rerr)                         arp_rnext    =   RIDLE;
                            else if (arp_rlast_in && flag_rover)        arp_rnext    =   WRITE_ADDR;
                            else                                        arp_rnext    =   RECEIVE;

            WRITE_ADDR  :   arp_rnext = arp_write_ready_in  ? WRITE_DATA     : WRITE_ADDR;
            WRITE_DATA  :   arp_rnext = arp_store_ready_in  ? RESPONSE       : WRITE_DATA;
            RESPONSE    :   arp_rnext = arp_bready_in       ? RIDLE   : RESPONSE;
        
            default :       arp_rnext =   RIDLE;
        endcase
    end

/*------------------------------------------------------------------------------
--  receive arp data 
------------------------------------------------------------------------------*/
    logic           arp_rready_o        =   '0;
    logic           trig_arp_qready_o   =   '0;
    logic   [7:0]   lenth_cnt           =   '0;

    always_ff @(posedge logic_clk) begin 
        case (arp_rnext)
            RIDLE        :   begin
                        opcode            <=  '0;
                        sa_mac            <=  '0;
                        sa_ip             <=  '0;
                        da_ip             <=  '0;  
                        lenth_cnt         <=  '0;
                        arp_rready_o      <=  '0; 
                        flag_rerr         <=  '0; 
                        flag_rover        <=  '0;
                        trig_arp_qready_o <=  '0;                                                    
            end // IDEL        
            RECEIVE     :   begin
                        arp_rready_o    <=  arp_rvalid_in;
                        lenth_cnt       <=  lenth_cnt + (arp_rready_out & arp_rvalid_in);

                        case (lenth_cnt)
                            8'd06   : opcode[15:08] <=  arp_rdata_in;
                            8'd07   : opcode[07:00] <=  arp_rdata_in;
                             // source mac
                            8'd08   : sa_mac[47:40] <= arp_rdata_in; 
                            8'd09   : sa_mac[39:32] <= arp_rdata_in; 
                            8'd10   : sa_mac[31:24] <= arp_rdata_in; 
                            8'd11   : sa_mac[23:16] <= arp_rdata_in; 
                            8'd12   : sa_mac[15:08] <= arp_rdata_in; 
                            8'd13   : sa_mac[07:00] <= arp_rdata_in;                 
                            // source ip
                            8'd14   : sa_ip[31:24]  <= arp_rdata_in; 
                            8'd15   : sa_ip[23:16]  <= arp_rdata_in; 
                            8'd16   : sa_ip[15:08]  <= arp_rdata_in; 
                            8'd17   : sa_ip[07:00]  <= arp_rdata_in; 
                            // target ip   
                            8'd24   : da_ip[31:24]  <= arp_rdata_in; 
                            8'd25   : da_ip[23:16]  <= arp_rdata_in; 
                            8'd26   : da_ip[15:08]  <= arp_rdata_in; 
                            8'd27   : da_ip[07:00]  <= arp_rdata_in;                                                        
                            default : begin
                                      opcode    <=  opcode;
                                      sa_mac    <=  sa_mac;
                                      sa_ip     <=  sa_ip;
                                      da_ip     <=  da_ip;
                            end
                        endcase

                        //  only response to local ip
                        if (lenth_cnt == ARP_LENGTH) begin
                            flag_rover            <=  1;
                            if (opcode == OPCODE_QUERY && da_ip == LOCAL_IP)
                                flag_rerr         <=  0;
                            else if (opcode == OPCODE_RESPONSE && da_ip == LOCAL_IP)
                                trig_arp_qready_o <=  (sa_ip == trig_arp_ip_in);
                            else
                                flag_rerr         <=  1;
                        end
                        else if (arp_rlast_in && !flag_rover)
                            flag_rerr             <=  1;
                        else begin
                            flag_rerr             <=  flag_rerr;
                            flag_rover            <=  flag_rover;
                            trig_arp_qready_o     <=  0;                           
                        end
                            
            end // RECEIVE 
            default : begin
                        opcode            <=  opcode;
                        sa_mac            <=  sa_mac;
                        sa_ip             <=  sa_ip;
                        da_ip             <=  da_ip;  
                        lenth_cnt         <=  '0;
                        arp_rready_o      <=  '0; 
                        flag_rerr         <=  '0;
                        flag_rover        <=  '0; 
                        trig_arp_qready_o <=  '0;            
            end // default 
        endcase
    end

    assign  arp_rready_out      =   arp_rready_o;
    assign  trig_arp_qready_out =   trig_arp_qready_o;

/*------------------------------------------------------------------------------
--  write arp cache
------------------------------------------------------------------------------*/
    logic           arp_write_valid_o   =   '0;
    logic           arp_store_valid_o   =   '0;
    logic   [31:0]  arp_write_ip_o      =   '0;
    logic   [47:0]  arp_store_mac_o     =   '0;
    logic           arp_bvalid_o        =   '0;

    always_ff @(posedge logic_clk) begin 
        case (arp_rnext)
            WRITE_ADDR : begin
                        arp_write_valid_o <=  1;
                        arp_write_ip_o    <=  sa_ip;                        
            end // WRITE_ADDR 

            WRITE_DATA  : begin
                        arp_write_valid_o <=  0;
                        arp_store_valid_o <=  1;
                        arp_store_mac_o   <=  sa_mac;                                               
            end // WRITE_DATA  

            RESPONSE    : begin                        
                        arp_store_valid_o <=  0;
                        arp_bvalid_o      <=  1;          
            end // RESPONSE

            default : begin
                        arp_write_valid_o <=  '0;
                        arp_store_valid_o <=  '0;
                        arp_write_ip_o    <=  '0;
                        arp_store_mac_o   <=  '0;
                        arp_bvalid_o      <=  '0;
            end // default 
        endcase
    end        
    
    assign  arp_write_valid_out =   arp_write_valid_o;
    assign  arp_write_ip_out    =   arp_write_ip_o;
    assign  arp_store_valid_out =   arp_store_valid_o;
    assign  arp_store_mac_out   =   arp_store_mac_o;
    assign  arp_bvalid_out      =   arp_bvalid_o;

/*------------------------------------------------------------------------------
--  send state
------------------------------------------------------------------------------*/
    typedef enum    logic [2:0]   {WIDLE,MASSAGE_LOAD,ARP_SEND}    state_as;
    state_as arp_sstate,arp_snext;

    always_ff @(posedge logic_clk) begin 
        if(logic_rst) begin
            arp_sstate <= WIDLE;
        end else begin
            arp_sstate <= arp_snext;
        end
    end

/*------------------------------------------------------------------------------
--  state jump
------------------------------------------------------------------------------*/  
    always_comb begin 
        case (arp_sstate)
            WIDLE    :      if     (trig_arp_qvalid_in || arp_bready_in) arp_snext    =   MASSAGE_LOAD;
                            else                                         arp_snext    =   WIDLE;
        
            MASSAGE_LOAD:   arp_snext = ARP_SEND;
            ARP_SEND    :   arp_snext = arp_tlast_out ? WIDLE : ARP_SEND;
        
            default :       arp_snext = WIDLE;
        endcase
    end
/*------------------------------------------------------------------------------
--  send arp

     Destination MAC address     6 octets
     Source MAC address          6 octets
     Ethertype (0x0806)          2 octets       14

     HTYPE (1)                   2 octets
     PTYPE (0x0800)              2 octets
     HLEN (6)                    1 octets
     PLEN (4)                    1 octets       20

     OPER                        2 octets         
     SHA Sender MAC              6 octets
     SPA Sender IP               4 octets       32

     THA Target MAC              6 octets
     TPA Target IP               4 octets       42
------------------------------------------------------------------------------*/
    localparam  [47:0]  ARP_PROTO       =   {16'h0001,16'h0800,8'h06,8'h04};
    localparam  [95:0]  ARP_QLOCAL      =   {OPCODE_QUERY, LOCAL_MAC, LOCAL_IP};
    localparam  [95:0]  ARP_RLOCAL      =   {OPCODE_RESPONSE, LOCAL_MAC, LOCAL_IP};
    

    logic       [7:0]   response_cnt    =   '0;
    logic       [7:0]   align_out;
    logic       [7:0]   arp_tdata_o     =   '0;
    logic               arp_tvalid_o    =   '0;
    logic               arp_tlast_o     =   '0; 
    
    logic       [111:0] arp_head        =   '0; 
    logic       [79:0]  arp_message     =   '0;
     

    always_ff @(posedge logic_clk) begin 
        case (arp_snext)
            MASSAGE_LOAD    :   begin
                            //  arp query
                            if (trig_arp_qvalid_in) begin
                                arp_head       <=  {48'hFFFF_FFFF_FFFF, LOCAL_MAC, 16'h0806};
                                arp_message    <=  {48'hFFFF_FFFF_FFFF, trig_arp_ip_in};                                    
                            end
                            //  arp response
                            else begin
                                arp_head       <=  {sa_mac, LOCAL_MAC, 16'h0806};
                                arp_message    <=  {sa_mac, sa_ip};                               
                            end

            end // MASSAGE_LOAD 

            ARP_SEND        :   begin
                            arp_tvalid_o    <=  1;
                            response_cnt    <=  response_cnt + (arp_tvalid_out & arp_tready_in);
                           

                            if      (align_out < 14)    arp_tdata_o <=  arp_head[(13-align_out)*8 +: 8];                                
                            else if (align_out < 20)    arp_tdata_o <=  ARP_PROTO[(19-align_out)*8 +: 8];                                
                            else if (align_out < 32)
                                if (trig_arp_qvalid_in) arp_tdata_o <=  ARP_QLOCAL[(31-align_out)*8 +: 8];                                   
                                else                    arp_tdata_o <=  ARP_RLOCAL[(31-align_out)*8 +: 8];                                       
                            else                        arp_tdata_o <=  arp_message[(41-align_out)*8 +: 8];                               

                            arp_tlast_o     <=  (align_out == 8'd41);
            end // ARP_SEND  

            default : begin
                            response_cnt <=   '0;
                            arp_tdata_o  <=   '0;
                            arp_tvalid_o <=   '0;
                            arp_tlast_o  <=   '0; 
                            arp_head     <=   '0; 
                            arp_message  <=   '0;
            end // default 
        endcase
    end

    assign  align_out       =   arp_tready_in ? response_cnt + 1 : response_cnt;    //  align data with tready
    assign  arp_tdata_out   =   arp_tdata_o;
    assign  arp_tvalid_out  =   arp_tvalid_o;
    assign  arp_tlast_out   =   arp_tlast_o;

 endmodule : arp_tx