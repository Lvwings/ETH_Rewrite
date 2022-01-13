`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : tb_net_top.sv
 Create     : 2021-12-17 09:01:52
 Revise     : 2021-12-17 09:01:52
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/


module tb_net_top (); /* this is automatically generated */

    // clock
    logic clk;
    initial begin
        clk = '0;
        forever #(2.5) clk = ~clk;
    end

    // synchronous reset
    logic srstb;
    initial begin
        srstb <= '1;
        repeat(10)@(posedge clk);
        srstb <= '0;
    end

    // (*NOTE*) replace reset, clock, others

    parameter  LOCAL_IP = 32'hC0A8_006E;
    parameter LOCAL_MAC = 48'hABCD_1234_5678;

    logic        logic_clk;
    logic        logic_rst;
    logic  [7:0] net_rmac_data_in;
    logic        net_rmac_valid_in;
    logic        net_rmac_ready_out;
    logic        net_rmac_last_in;
    logic [34:0] net_rmac_type_in;
    logic  [7:0] net_tmac_data_out;
    logic        net_tmac_valid_out;
    logic        net_tmac_ready_in;
    logic        net_tmac_last_out;
    logic  [7:0] net_rtrans_data_in;
    logic        net_rtrans_valid_in;
    logic        net_rtrans_ready_out;
    logic        net_rtrans_last_in;
    logic  [7:0] udp_rdata_out;
    logic        udp_rvalid_out;
    logic        udp_rready_in;
    logic        udp_rlast_out;
    logic [31:0] udp_rip_out;
    logic        trig_arp_qvalid_in;
    logic [31:0] trig_arp_ip_in;
    logic        trig_arp_qready_out;
    logic [31:0] arp_query_ip_in;
    logic        arp_query_valid_in;
    logic        arp_query_ready_out;
    logic [47:0] arp_response_mac_out;
    logic        arp_response_valid_out;
    logic        arp_response_ready_in;
    logic        arp_response_err_out;

    net_tmac_op #(
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC)
        ) inst_net_tmac_op (
            .logic_clk              (logic_clk),
            .logic_rst              (logic_rst),
            .net_rmac_data_in       (net_rmac_data_in),
            .net_rmac_valid_in      (net_rmac_valid_in),
            .net_rmac_ready_out     (net_rmac_ready_out),
            .net_rmac_last_in       (net_rmac_last_in),
            .net_rmac_type_in       (net_rmac_type_in),
            .net_tmac_data_out      (net_tmac_data_out),
            .net_tmac_valid_out     (net_tmac_valid_out),
            .net_tmac_ready_in      (net_tmac_ready_in),
            .net_tmac_last_out      (net_tmac_last_out),
            .net_rtrans_data_in     (net_rtrans_data_in),
            .net_rtrans_valid_in    (net_rtrans_valid_in),
            .net_rtrans_ready_out   (net_rtrans_ready_out),
            .net_rtrans_last_in     (net_rtrans_last_in),
            .udp_rdata_out          (udp_rdata_out),
            .udp_rvalid_out         (udp_rvalid_out),
            .udp_rready_in          (udp_rready_in),
            .udp_rlast_out          (udp_rlast_out),
            .udp_rip_out            (udp_rip_out),
            .trig_arp_qvalid_in     (trig_arp_qvalid_in),
            .trig_arp_ip_in         (trig_arp_ip_in),
            .trig_arp_qready_out    (trig_arp_qready_out),
            .arp_query_ip_in        (arp_query_ip_in),
            .arp_query_valid_in     (arp_query_valid_in),
            .arp_query_ready_out    (arp_query_ready_out),
            .arp_response_mac_out   (arp_response_mac_out),
            .arp_response_valid_out (arp_response_valid_out),
            .arp_response_ready_in  (arp_response_ready_in),
            .arp_response_err_out   (arp_response_err_out)
        );

        assign  logic_clk   =   clk;
        assign  logic_rst   =   srstb;

    task init();
        net_rmac_data_in      <= '0;
        net_rmac_valid_in     <= '0;
        net_rmac_last_in      <= '0;
        trig_arp_qvalid_in    <= '0;
        trig_arp_ip_in        <= '0;
        arp_query_ip_in       <= '0;
        arp_query_valid_in    <= '0;
        arp_response_ready_in <= '0;
    endtask

    initial begin
        // do something
        init();
    end

/*------------------------------------------------------------------------------
--  state for FPGA
    1. FPGA receive arp query
    arp_rx_query -> write cache -> arp_tx_response

    2. FPAG wants to send frame but doesn't know MAC
    send_frame -> mac_query -> no match -> arp_tx_query -> arp_rx_response -> write cache -> mac_query
------------------------------------------------------------------------------*/
    typedef enum    logic [1:0]   {IDLE,ARP_QUERY,MAC_QUERY,ARP_RESPONSE}    state_w;
    state_w net_state,net_next;

    always_ff @(posedge logic_clk) begin
        if(logic_rst) begin
            net_state <= IDLE;
        end else begin
            net_state <= net_next;
        end 
    end
 
/*------------------------------------------------------------------------------
--  state jump
------------------------------------------------------------------------------*/
    logic           trig_arp_query;
    logic           trig_mac_query;
    logic   [7:0]   trig_cnt    =   '0;

    always_comb begin 
        case (net_state)                                
            IDLE        :   if      (trig_arp_query)                                    net_next = ARP_QUERY;
                            else if (trig_mac_query)                                    net_next = MAC_QUERY;
                            else                                                        net_next = IDLE;

            MAC_QUERY   :   if      (arp_response_ready_in && !arp_response_err_out)    net_next = IDLE;
                            else if (trig_arp_qvalid_in && net_tmac_last_out)               net_next = ARP_RESPONSE;
                            else                                                        net_next = MAC_QUERY;

            ARP_QUERY   :   net_next    =   net_rmac_last_in ? IDLE : ARP_QUERY;
            ARP_RESPONSE:   net_next    =   net_rmac_last_in ? IDLE : ARP_RESPONSE;
            default :       net_next    =   IDLE;
        endcase
    end

    always_ff @(posedge clk) begin 
        trig_cnt <= trig_cnt + 1;
    end

    assign  trig_arp_query  =   (trig_cnt == 8'h0F);
    assign  trig_mac_query  =   (trig_cnt == 8'h7F);
    
/*------------------------------------------------------------------------------
--  arp query & arp response
------------------------------------------------------------------------------*/
    localparam  QFLIE_PATH      =   "D:/SourceTree/Soures/Git/sim/network/sim_arp_query.txt";
    localparam  RFLIE_PATH      =   "D:/SourceTree/Soures/Git/sim/network/sim_arp_response.txt";
    localparam  DATA_LENGTH     =   60;

    logic [7:0] query_ram       [DATA_LENGTH-1 : 0];
    logic [7:0] response_ram    [DATA_LENGTH-1 : 0];

    logic [7:0] data_cnt    =   '0;    

    initial begin
        $readmemh(QFLIE_PATH,query_ram);
        $readmemh(RFLIE_PATH,response_ram);
    end    

    always_ff @(posedge logic_clk) begin 
        case (net_next)
            ARP_QUERY   : begin
                        data_cnt        <= data_cnt + (net_rmac_valid_in & net_rmac_ready_out);

                        net_rmac_valid_in   <=  1;

                        net_rmac_data_in    <=  net_rmac_ready_out ? query_ram[data_cnt+1] : query_ram[data_cnt];
                        net_rmac_last_in    <=  (data_cnt == DATA_LENGTH-2);
            end

            ARP_RESPONSE    : begin
                        data_cnt        <= data_cnt + (net_rmac_valid_in & net_rmac_ready_out);

                        net_rmac_valid_in   <=  1;
                        net_rmac_data_in    <=  net_rmac_ready_out ? response_ram[data_cnt+1] : response_ram[data_cnt];
                        net_rmac_last_in    <=  (data_cnt == DATA_LENGTH-2);                        
            end // ARP_RESPONSE    
            default : begin
                        data_cnt        <=  '0;
                        net_rmac_valid_in   <=  '0;
                        net_rmac_data_in    <=  '0;
                        net_rmac_last_in    <=  '0;            
            end // default 
        endcase
    end
 
/*------------------------------------------------------------------------------
--  mac query
    read arp cache  -> no match -> trig query -> arp_tx_query -> arp_rx_response

                    -> match -> idle
------------------------------------------------------------------------------*/
    //  read cache
    typedef enum    logic [1:0]   {RIDLE,READ_ADDR,READ_DATA,TRIG_QUERY}    state_r;
    state_r read_state,read_next;

    always_ff @(posedge logic_clk) begin 
        if(logic_rst) begin
            read_state <= RIDLE;
        end else begin
            read_state <= read_next;
        end
    end

    always_comb begin
        case (read_state)
            RIDLE       :                                   read_next = (net_next == MAC_QUERY)  ? READ_ADDR : RIDLE;
            READ_ADDR   :                                   read_next = arp_query_ready_out      ? READ_DATA : READ_ADDR;
            READ_DATA   :   if (arp_response_ready_in && arp_response_err_out)    
                                                            read_next = TRIG_QUERY;
                            else if (arp_response_ready_in) read_next = RIDLE;
                            else                            read_next = READ_DATA;
            TRIG_QUERY  :                                   read_next = trig_arp_qready_out     ? RIDLE : TRIG_QUERY;    
            default :     read_next = RIDLE;  
        endcase
    end 

    localparam  [31:0]      ASSUMPTIVE_IP   =   32'hC0A8_00FF;

    always_ff @(posedge logic_clk) begin 
        case (read_next)
            READ_ADDR   : begin
                        arp_query_valid_in    <=  1;
                        arp_query_ip_in       <=  ASSUMPTIVE_IP;        //  assumptive IP
            end // READ_ADDR   

            READ_DATA   : begin
                        arp_query_valid_in    <=  0;
                        arp_response_ready_in <=  arp_response_valid_out;
            end // READ_DATA   
            TRIG_QUERY   :   begin
                        arp_response_ready_in <=  0;
                        trig_arp_qvalid_in    <=  1;
                        trig_arp_ip_in        <=  ASSUMPTIVE_IP;
            end // TRIG_QUERY               
            default :   begin
                        arp_query_valid_in    <=  0;
                        arp_query_ip_in       <=  0;
                        arp_response_ready_in <=  0;
                        trig_arp_qvalid_in    <=  0;
                        trig_arp_ip_in        <=  0;                        
            end // default 
        endcase
    end 

/*------------------------------------------------------------------------------
-- net_tmac_ready_in
------------------------------------------------------------------------------*/
    logic   [5:0]   time_gap        =   '0;
    logic           flag_time_gap   =   '0;

    always_ff @(posedge logic_clk) begin 
        time_gap    <=  time_gap + flag_time_gap;

        if (net_tmac_last_out)
            flag_time_gap   <=  1;
        else if (time_gap == 6'h3F)
            flag_time_gap   <=  0;
        else
            flag_time_gap   <=  flag_time_gap;

        if (flag_time_gap)
            net_tmac_ready_in   <=  0;
        else
            net_tmac_ready_in   <=  net_tmac_valid_out & !net_tmac_last_out;
    end
    


endmodule
