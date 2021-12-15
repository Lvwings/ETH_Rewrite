`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : tb_arp_cache.sv
 Create     : 2021-12-14 14:31:52
 Revise     : 2021-12-14 14:31:52
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module tb_arp_cache (); /* this is automatically generated */

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

    localparam CHCHE_ADDR_WIDTH = 6;
    localparam      CHCHE_DEPTH = 1 << CHCHE_ADDR_WIDTH;

    logic        logic_clk;
    logic        logic_rst;
    logic        arp_cache_clear_in;
    logic [31:0] arp_write_ip_in;
    logic        arp_write_valid_in;
    logic        arp_write_ready_out;
    logic [47:0] arp_store_mac_in;
    logic        arp_store_valid_in;
    logic        arp_store_ready_out;
    logic        arp_bvalid_in;
    logic        arp_bready_out;
    logic [31:0] arp_query_ip_in;
    logic        arp_query_valid_in;
    logic        arp_query_ready_out;
    logic [47:0] arp_response_mac_out;
    logic        arp_response_valid_out;
    logic        arp_response_ready_in;
    logic        arp_response_err_out;

    arp_cache inst_arp_cache
        (
            .logic_clk              (logic_clk),
            .logic_rst              (logic_rst),
            .arp_cache_clear_in     (arp_cache_clear_in),
            .arp_write_ip_in        (arp_write_ip_in),
            .arp_write_valid_in     (arp_write_valid_in),
            .arp_write_ready_out    (arp_write_ready_out),
            .arp_store_mac_in       (arp_store_mac_in),
            .arp_store_valid_in     (arp_store_valid_in),
            .arp_store_ready_out    (arp_store_ready_out),
            .arp_bvalid_in          (arp_bvalid_in),
            .arp_bready_out         (arp_bready_out),
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
        arp_cache_clear_in    <= '0;
        arp_write_ip_in       <= '0;
        arp_write_valid_in    <= '0;
        arp_store_mac_in      <= '0;
        arp_store_valid_in    <= '0;
        arp_bvalid_in         <= '0;
        arp_query_ip_in       <= '0;
        arp_query_valid_in    <= '0;
        arp_response_ready_in <= '0;
    endtask


    initial begin
        // do something
        init();
    end

/*------------------------------------------------------------------------------
--  write arp cache
------------------------------------------------------------------------------*/
    typedef enum    logic [1:0]   {WIDLE,WRITE_ADDR,WRITE_DATA,RESPONSE}    state_w;
    state_w write_state,write_next;

    always_ff @(posedge logic_clk) begin
        if(logic_rst) begin
            write_state <= WIDLE;
        end else begin
            write_state <= write_next;
        end
    end

    logic   [6:0]       trig_start      =   '0;

    always_comb begin
        case (write_state)
            WIDLE       : write_next = (trig_start == '1)   ? WRITE_ADDR : WIDLE;                     
            WRITE_ADDR  : write_next = arp_write_ready_out  ? WRITE_DATA : WRITE_ADDR;
            WRITE_DATA  : write_next = arp_store_ready_out  ? RESPONSE : WRITE_DATA;
            RESPONSE    : write_next = arp_bready_out       ? WIDLE : RESPONSE;
            default :     write_next = WIDLE;
        endcase
    
    end

    //  axi flow control
    always_ff @(posedge logic_clk) begin 
        trig_start  <=  trig_start + 1;
        case (write_next)
            WRITE_ADDR : begin
                        arp_write_valid_in <=  1;
                        arp_write_ip_in    <=  32'hAAAA_AAAA + $random()%10;                        
            end // WRITE_ADDR 

            WRITE_DATA  : begin
                        arp_write_valid_in <=  0;
                        arp_store_valid_in <=  1;
                        arp_store_mac_in   <=  48'h0123_4567_abcd;                                               
            end // WRITE_DATA  

            RESPONSE    : begin                        
                        arp_store_valid_in <=  0;
                        arp_bvalid_in      <=  1;          
            end // RESPONSE

            default : begin
                        arp_write_valid_in <=  0;
                        arp_store_valid_in <=  0;
                        arp_write_ip_in    <=  '0;
                        arp_store_mac_in   <=  '0;
                        arp_bvalid_in      <=  0;
            end // default 
        endcase
    end   
    /*------------------------------------------------------------------------------
--  read arp cache
------------------------------------------------------------------------------*/
    typedef enum    logic [1:0]   {RIDLE,READ_ADDR,READ_DATA}    state_r;
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
            RIDLE       : read_next = (trig_start == 6'h0F)    ? READ_ADDR : RIDLE;
            READ_ADDR   : read_next = arp_query_ready_out      ? READ_DATA : READ_ADDR;
            READ_DATA   : read_next = arp_response_ready_in    ? RIDLE : READ_DATA;
            default :     read_next = RIDLE;  
        endcase
    end 

    always_ff @(posedge logic_clk) begin 
        case (read_next)
            READ_ADDR   : begin
                    arp_query_valid_in    <=  1;
                    arp_query_ip_in       <=  32'hAAAA_AAAA + $random()%10;
            end // READ_ADDR   

            READ_DATA   : begin
                    arp_query_valid_in    <=  0;
                    arp_response_ready_in <=  arp_response_valid_out;
            end // READ_DATA   
            default :   begin
                    arp_query_valid_in    <=  0;
                    arp_query_ip_in       <=  0;
                    arp_response_ready_in <=  0;
            end // default 
        endcase
    end    

/*------------------------------------------------------------------------------
--  arp cache clear
------------------------------------------------------------------------------*/
  logic     [7:0]   clear_cnt   =   '0;

  always_ff @(posedge logic_clk) begin 
          clear_cnt          <=  clear_cnt + 1;
          arp_cache_clear_in <=  (clear_cnt == '1);
       end
            

endmodule