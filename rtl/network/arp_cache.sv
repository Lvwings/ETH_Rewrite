`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : arp_cache.sv
 Create     : 2021-12-14 09:09:55
 Revise     : 2021-12-14 09:09:55
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module arp_cache (
    input           logic_clk,
    input           logic_rst,
    input           arp_cache_clear_in,
    //  cache write - store ip and mac
    //  axi-lite write
    input   [31:0]  arp_write_ip_in,
    input           arp_write_valid_in,
    output          arp_write_ready_out,

    input   [47:0]  arp_store_mac_in,
    input           arp_store_valid_in,
    output          arp_store_ready_out,

    input           arp_bvalid_in,
    output          arp_bready_out,  

    //  cache query - find mac address match ip
    //  axi-lite read    
    input   [31:0]  arp_query_ip_in,
    input           arp_query_valid_in,
    output          arp_query_ready_out,

    output  [47:0]  arp_response_mac_out,
    output          arp_response_valid_out,
    input           arp_response_ready_in,
    output          arp_response_err_out    //  no mac match arp_query_ip_in
 );

 /*------------------------------------------------------------------------------
 --  cache initial
     CACHE_ADDR_WIDTH = 6 -> 64 depth
     arp_mark_mem marks the ip that has been stored. when arp_cache_clear_in enable,
     arp_mark_mem will be cleared and ip query returns err_out asking for arp query.
 ------------------------------------------------------------------------------*/
    localparam      CACHE_ADDR_WIDTH    =   6;
    localparam      CACHE_DEPTH         =   1 << CACHE_ADDR_WIDTH;

    logic   [31:0]  arp_ip_mem      [CACHE_DEPTH-1 : 0];      
    logic   [47:0]  arp_mac_mem     [CACHE_DEPTH-1 : 0];
    logic   [CACHE_DEPTH-1 : 0]     arp_mark_mem   = '0;

    initial begin
        for (int i = 0; i < CACHE_DEPTH; i = i+1) begin
            arp_ip_mem[i]   =   '0;
            arp_mac_mem[i]  =   '0;
        end
    end
 
 /*------------------------------------------------------------------------------
 --  write & read pointer
     to reduce memory space, use lfsr(CRC-6/ITU) to generate pointer as memory address.
 ------------------------------------------------------------------------------*/
    logic   [CACHE_ADDR_WIDTH-1 : 0]    write_pointer;
    logic   [CACHE_ADDR_WIDTH-1 : 0]    read_pointer;

/*------------------------------------------------------------------------------
--  write arp cache
------------------------------------------------------------------------------*/
    typedef enum    logic [2:0]   {WIDLE,WRITE_ADDR,WRITE_DATA,RESPONSE,WCLEAR}    state_w;
    state_w write_state,write_next;

    always_ff @(posedge logic_clk) begin
        if(logic_rst) begin
            write_state <= WIDLE;
        end else begin
            write_state <= write_next;
        end
    end

    logic               arp_write_ready_o   =   '0;
    logic               arp_store_ready_o   =   '0;
    logic               arp_bready_o        =   '0;
    logic               lfsr_wrst           =   '0;
    logic               flag_rst_over       =   '0;

    always_comb begin
        case (write_state)
            WIDLE       : if (arp_cache_clear_in)       write_next  =   WCLEAR;
                          else if (arp_write_valid_in)  write_next  =   WRITE_ADDR;
                          else                          write_next  =   WIDLE;

            WRITE_ADDR  : write_next = arp_write_ready_out  ? WRITE_DATA : WRITE_ADDR;
            WRITE_DATA  : write_next = arp_store_ready_out  ? RESPONSE : WRITE_DATA;
            RESPONSE    : write_next = arp_bready_out       ? WIDLE : RESPONSE;
            WCLEAR      : write_next = flag_rst_over        ? WIDLE : WCLEAR;
            default :     write_next = WIDLE;
        endcase
    
    end

    //  axi flow control
    always_ff @(posedge logic_clk) begin 
        
        case (write_next)
            WRITE_ADDR : begin
                        arp_write_ready_o           <=  1;                        
            end // WRITE_ADDR 

            WRITE_DATA  : begin
                        arp_write_ready_o           <=  0;
                        arp_store_ready_o           <=  arp_store_valid_in;                                               
            end // WRITE_DATA  

            RESPONSE    : begin
                        arp_store_ready_o           <=  0;
                        arp_bready_o                <=  arp_bvalid_in;          
            end // RESPONSE

            default : begin
                        arp_write_ready_o           <=  0;
                        arp_store_ready_o           <=  0;
                        arp_bready_o                <=  0;
            end // default 
        endcase
    end
    
    //  memory store
    always_ff @(posedge logic_clk) begin 
        if (arp_write_ready_out && arp_write_valid_in) begin
            arp_ip_mem[write_pointer]   <=  arp_write_ip_in;
        end

        if (arp_store_ready_out && arp_store_valid_in) begin
            arp_mac_mem[write_pointer]  <=  arp_store_mac_in; 
        end

        case (write_next)
            WRITE_DATA  :   begin
                        arp_mark_mem[write_pointer] <=  1;
            end // WRITE_ADDR

            WCLEAR      :   begin
                        arp_mark_mem                <=  0;
                        flag_rst_over               <=  1;
            end // WCLEAR    

            default : begin
                        flag_rst_over               <=  0;
            end // default 
        endcase

        lfsr_wrst  <=  arp_bready_out && arp_bvalid_in;
    end
       
    //  CRC-6/ITU    
    mac_lfsr #(
            .LFSR_WIDTH         (CACHE_ADDR_WIDTH),
            .LFSR_POLY          (03),
            .LFSR_CONFIG        ("GALOIS"),
            .LFSR_FEED_FORWARD  (0),
            .LFSR_INITIAL_STATE (0),
            .LFSR_STATE_OUT_XOR (0),
            .REVERSE            (1),
            .DATA_WIDTH         (32)
        ) inst_write_lfsr (
            .clk                 (logic_clk),
            .rst                 (lfsr_wrst),
            .data_in             (arp_write_ip_in),
            .data_valid_in       (arp_write_ready_out),
            .data_out            (),
            .lfsr_state_out_comb (write_pointer),
            .lfsr_state_out_reg  ()
        );

    assign  arp_write_ready_out =   arp_write_ready_o;
    assign  arp_store_ready_out =   arp_store_ready_o;
    assign  arp_bready_out      =   arp_bready_o;    
    
/*------------------------------------------------------------------------------
--  read arp cache
------------------------------------------------------------------------------*/
    typedef enum    logic [1:0]   {RIDLE,READ_ADDR,READ_DATA,RCLEAR_HOLD}    state_r;
    state_r read_state,read_next;

    always_ff @(posedge logic_clk) begin 
        if(logic_rst) begin
            read_state <= RIDLE;
        end else begin
            read_state <= read_next;
        end
    end

    logic           arp_query_ready_o   =   '0;
    logic           arp_response_valid_o=   '0;
    logic   [47:0]  arp_response_mac_o  =   '0;
    logic           lfsr_rrst           =   '0;
    logic           arp_response_err_o  =   '0;

    always_comb begin
        case (read_state)
            RIDLE       : if (arp_cache_clear_in)       read_next = RCLEAR_HOLD;
                          else if (arp_query_valid_in)  read_next = READ_ADDR;
                          else                          read_next = RIDLE;

            READ_ADDR   : read_next = arp_query_ready_out                               ? READ_DATA : READ_ADDR;
            READ_DATA   : read_next = arp_response_ready_in && arp_response_valid_out   ? RIDLE : READ_DATA;
            RCLEAR_HOLD : read_next = flag_rst_over                                     ? RIDLE : RCLEAR_HOLD;
            default :     read_next = RIDLE;  
        endcase
    end

    //  axi flow control
    always_ff @(posedge logic_clk) begin 
        case (read_next)
            READ_ADDR   : begin
                    arp_query_ready_o    <=  1;
            end // READ_ADDR   

            READ_DATA   : begin
                    arp_query_ready_o    <=  0;
                    arp_response_valid_o <=  1;
                    arp_response_mac_o   <=  arp_mac_mem[read_pointer];
            end // READ_DATA   
            default :   begin
                    arp_query_ready_o    <=  0;
                    arp_response_valid_o <=  0;
                    arp_response_mac_o   <=  0;
            end // default 
        endcase
    end
    
    //  read judge
    always_ff @(posedge logic_clk) begin
        lfsr_rrst   <=  arp_response_ready_in && arp_response_valid_out;

        if (arp_query_valid_in && arp_query_ready_out)
            // check if mac has been stored
            if ((arp_query_ip_in == arp_ip_mem[read_pointer]) && arp_mark_mem[read_pointer])
                arp_response_err_o <=  0;
            else
                arp_response_err_o <=  1;
        else if (arp_response_ready_in && arp_response_valid_out)
            arp_response_err_o     <=  0;
        else
            arp_response_err_o     <=  arp_response_err_o;
    end

    //  CRC-6/ITU    
    mac_lfsr #(
            .LFSR_WIDTH         (CACHE_ADDR_WIDTH),
            .LFSR_POLY          (03),
            .LFSR_CONFIG        ("GALOIS"),
            .LFSR_FEED_FORWARD  (0),
            .LFSR_INITIAL_STATE (0),
            .LFSR_STATE_OUT_XOR (0),
            .REVERSE            (1),
            .DATA_WIDTH         (32)
        ) inst_read_lfsr (
            .clk                 (logic_clk),
            .rst                 (lfsr_rrst),
            .data_in             (arp_query_ip_in),
            .data_valid_in       (arp_query_ready_out),
            .data_out            (),
            .lfsr_state_out_comb (read_pointer),
            .lfsr_state_out_reg  ()
        );     

    assign  arp_query_ready_out     =   arp_query_ready_o;
    assign  arp_response_valid_out  =   arp_response_valid_o;
    assign  arp_response_mac_out    =   arp_response_mac_o;
    assign  arp_response_err_out    =   arp_response_err_o; 

 endmodule : arp_cache