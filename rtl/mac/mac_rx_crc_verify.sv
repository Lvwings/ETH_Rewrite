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

 module mac_rx_crc_verify 
    (
    input               logic_clk,
    input               logic_rst,

    //  phy data in
    input               phy_rx_clk,
    input   [7:0]       phy_rxd_in,
    input               phy_rvalid_in,
    input               phy_rerr_in,        
    
    //  mac data out
    output  [7:0]       mac_rdata_out,
    output              mac_rvalid_out,
    input               mac_rready_in,
    output              mac_rlast_out

 );
/*------------------------------------------------------------------------------
--  logic reset cdc
------------------------------------------------------------------------------*/
    reg                 phy_rx_rst      =   1'b0;

    sync_reset #(
        .SYNC_DEPTH(3)
    ) inst_sync_reset (
        .sys_clk      (phy_rx_clk),
        .async_rst    (logic_rst),
        .sync_rst_out (phy_rx_rst)
    );

/*------------------------------------------------------------------------------
--  rx data delay
------------------------------------------------------------------------------*/
    reg         [7:0]   phy_rxd_d5      =   '0;
    reg                 phy_rvalid_d5   =   1'b0;

    //  rx data delay 5 clk to fifo
    sync_signal #(
            .SIGNAL_WIDTH(9),
            .SYNC_DEPTH(5)
        ) inst_sync_signal (
            .sys_clk    (phy_rx_clk),
            .sys_rst    (phy_rx_rst),
            .signal_in  ({phy_rxd_in,phy_rvalid_in}),
            .signal_out ({phy_rxd_d5,phy_rvalid_d5})
        );

/*------------------------------------------------------------------------------
--  ETH preamble+SFD detect
------------------------------------------------------------------------------*/
    localparam          PREAMBLE        =   64'h5555_5555_5555_55D5;
    reg         [63:0]  preamble_reg    =   '0;
    wire                trig_crc_start;

    always_ff @(posedge phy_rx_clk) begin 
        if (phy_rvalid_d5)
            preamble_reg    <=  {preamble_reg[55:0],phy_rxd_d5};
        else
            preamble_reg    <=  '0;
    end

    assign  trig_crc_start  =   (preamble_reg == PREAMBLE);

/*------------------------------------------------------------------------------
--  crc state parameter
------------------------------------------------------------------------------*/
    typedef enum    reg [0:0]   {IDLE,CRC}    state_r;
    state_r rcrc_state,rcrc_next_state;

    always_ff @(posedge phy_rx_clk) begin 
        if(phy_rx_rst) begin
            rcrc_state <= IDLE;
        end else begin
            rcrc_state <= rcrc_next_state;
        end
    end

/*------------------------------------------------------------------------------
--  crc calculate
------------------------------------------------------------------------------*/
    wire        [31:0]  crc_result;
    reg         [7:0]   crc_data     =   '0;
    reg                 crc_valid    =   1'b0;
    reg                 crc_last     =   1'b0;
    reg                 crc_rst      =   1'b0;
    reg                 phy_rvalid_d1=   1'b0;

    always_ff @(posedge phy_rx_clk) begin 
        phy_rvalid_d1   <= phy_rvalid_in;
        case (rcrc_next_state)
            CRC     : begin
                    crc_valid <= phy_rvalid_d1 && phy_rvalid_d5;
                    crc_data  <= phy_rxd_d5;   
                    crc_last  <= phy_rvalid_d1 && !phy_rvalid_in;               
            end // CRC     
            default : begin
                    crc_data  <= 0;
                    crc_valid <= 0;
                    crc_last  <= 0;
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
        ) inst_mac_rx_crc (
            .clk                   (phy_rx_clk),
            .rst                   (crc_rst),
            .data_in               (crc_data),
            .data_valid_in         (crc_valid),
            .data_out              (),
            .lfsr_state_out_comb   (crc_result),
            .lfsr_state_out_reg    ()
        );
/*------------------------------------------------------------------------------
--  if phy data receive error or crc verify faild, reset rx fifo
------------------------------------------------------------------------------*/
    reg                 trig_crc_reset  =   1'b0; 
    reg                 flag_good_crc   =   1'b0;
    reg     [31:0]      phy_rx_crc      =   '0;

    always_ff @(posedge phy_rx_clk) begin 

        case (rcrc_next_state)
            CRC     : begin
                phy_rx_crc  <=  phy_rvalid_in ? {phy_rxd_in,phy_rx_crc[31:8]} : phy_rx_crc;

                if (phy_rerr_in)
                    trig_crc_reset     <= 1;
                else if (crc_last)
                    if (crc_result == phy_rx_crc)
                        flag_good_crc <= 1;
                    else 
                        trig_crc_reset  <= 1;
                else
                    trig_crc_reset     <= trig_crc_reset;
            end // CRC     

            default : begin
                 trig_crc_reset <=  0;
                 flag_good_crc  <=  0;
             end
        endcase
    end

/*------------------------------------------------------------------------------
--  crc reset & fifo reset
------------------------------------------------------------------------------*/
    reg             fifo_reset_n  =   1'b1;

    always_ff @(posedge phy_rx_clk) begin
        if(phy_rx_rst || trig_crc_reset) begin
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

    always_comb begin 
        case (rcrc_state)
            IDLE    :   rcrc_next_state = trig_crc_start ? CRC : IDLE;

            CRC     :   if (trig_crc_reset || flag_good_crc)
                            rcrc_next_state = IDLE;
                        else
                            rcrc_next_state = CRC;

            default :   rcrc_next_state = IDLE;
        endcase    
    end

/*------------------------------------------------------------------------------
--  mac recive phy data fifo
------------------------------------------------------------------------------*/
    
 

 mac_rx_fifo mac_rx_fifo (
  .s_axis_aresetn   (fifo_reset_n),     // input wire s_axis_aresetn

  .s_axis_aclk      (phy_rx_clk),       // input wire s_axis_aclk
  .s_axis_tvalid    (crc_valid),        // input wire s_axis_tvalid
  .s_axis_tready    (),                 // output wire s_axis_tready
  .s_axis_tdata     (crc_data),         // input wire [7 : 0] s_axis_tdata
  .s_axis_tlast     (crc_last),         // input wire s_axis_tlast

  .m_axis_aclk      (logic_clk),        // input wire m_axis_aclk
  .m_axis_tvalid    (mac_rvalid_out),    // output wire m_axis_tvalid
  .m_axis_tready    (mac_rready_in),     // input wire m_axis_tready
  .m_axis_tdata     (mac_rdata_out),     // output wire [7 : 0] m_axis_tdata
  .m_axis_tlast     (mac_rlast_out)      // output wire m_axis_tlast
);  

 endmodule : mac_crc_verify