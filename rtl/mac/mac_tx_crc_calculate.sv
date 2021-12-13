`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : mac_tx_crc_calculate.sv
 Create     : 2021-12-10 16:23:56
 Revise     : 2021-12-10 16:23:56
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module mac_tx_crc_calculate (
     input          logic_clk,      // Clock
     input          logic_rst,      // synchronous reset active high
     
     // mac tx data in
     input  [7:0]   mac_tdata_in,
     input          mac_tvalid_in,
     output         mac_tready_out,
     input          mac_tlast_in,

     // phy tx interface
     input          phy_tx_clk,
     output [7:0]   phy_txd_out,
     output         phy_tvalid_out,
     output         phy_terr_out
 );

/*------------------------------------------------------------------------------
--  mac tx state 
------------------------------------------------------------------------------*/
    typedef enum    logic [1:0]   {IDLE,PREAMBLE,DATA,CRC}    state_t;
    state_t tcrc_state,tcrc_next_state;

    always_ff @(posedge logic_clk) begin 
        if(logic_rst) begin
            tcrc_state <= IDLE;
        end else begin
            tcrc_state <= tcrc_next_state;
        end
    end

/*------------------------------------------------------------------------------
--  state jump
------------------------------------------------------------------------------*/
    logic           flag_preamble_over  =   '0;
    logic           flag_data_over      =   '0;
    logic   [7:0]   fifo_tdata          =   '0;
    logic           fifo_tvalid         =   '0;
    logic           fifo_tready;
    logic           fifo_tlast          =   '0;

    always_comb begin 
        case (tcrc_state)
            IDLE    : tcrc_next_state = mac_tvalid_in       ? PREAMBLE : IDLE;
            PREAMBLE: tcrc_next_state = flag_preamble_over  ? DATA : PREAMBLE;
            DATA    : tcrc_next_state = flag_data_over      ? CRC : DATA;
            CRC     : tcrc_next_state = fifo_tlast          ? IDLE : CRC;
            default : /* default */;
        endcase
    end
/*------------------------------------------------------------------------------
--  crc calculate
------------------------------------------------------------------------------*/
    logic   [7:0]       crc_data    =   '0;
    logic               crc_valid   =   '0;
    logic               crc_rst     =   '0;
    logic   [31:0]      crc_result;

    always_ff @(posedge logic_clk) begin 
        case (tcrc_next_state)
            DATA    :   begin
                crc_data  <=  (mac_tvalid_in && mac_tready_out && fifo_tready) ? mac_tdata_in : fifo_tdata;
                crc_valid <=  (mac_tvalid_in && mac_tready_out && fifo_tready);
            end
            CRC     :   begin
                crc_data  <= 0;
                crc_valid <= 0;                
                crc_rst   <= fifo_tlast;
            end
            default : begin
                crc_data  <= 0;
                crc_valid <= 0;
                crc_rst   <= logic_rst;
            end // default 
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
        ) inst_mac_tx_crc (
            .clk                   (logic_clk),
            .rst                   (crc_rst),
            .data_in               (crc_data),
            .data_valid_in         (crc_valid),
            .data_out              (),
            .lfsr_state_out_comb   (crc_result),
            .lfsr_state_out_reg    ()
        );    
    
/*------------------------------------------------------------------------------
-- FIFO data generate
    - Add ETH preamble 
    - Add CRC
------------------------------------------------------------------------------*/
    localparam          PREAMBLE_REG        =   64'h5555_5555_5555_55D5;   
    logic   [2:0]       byte_cnt            =   '1;
    logic               mac_tready_o        =   '0;

    always_ff @(posedge logic_clk) begin
        case (tcrc_next_state)

            PREAMBLE    : begin
                if (fifo_tready) begin
                    byte_cnt            <=  byte_cnt - 1;
                    fifo_tdata          <=  PREAMBLE_REG[8*byte_cnt +: 8];
                    fifo_tvalid         <=  1;
                    fifo_tlast          <=  0;
                    flag_preamble_over  <=  (byte_cnt == '0);
                end
            end
            DATA    : begin
                mac_tready_o        <=  fifo_tready;
                fifo_tdata          <=  (mac_tvalid_in && mac_tready_out && fifo_tready) ? mac_tdata_in : fifo_tdata;
                fifo_tvalid         <=  (mac_tvalid_in && mac_tready_out && fifo_tready);
                fifo_tlast          <=  0;
                flag_preamble_over  <=  0;
                flag_data_over      <=  mac_tlast_in && mac_tvalid_in && mac_tready_out;
            end
            CRC     : begin
                if (fifo_tready) begin
                    byte_cnt        <=  byte_cnt - 1;
                    fifo_tdata      <=  crc_result[8*(7-byte_cnt) +: 8];
                    fifo_tvalid     <=  1;
                    fifo_tlast      <=  (byte_cnt == 4);
                    mac_tready_o    <=  0;
                end
                flag_data_over      <=  0;
            end
            default : begin
                byte_cnt           <=  '1;
                mac_tready_o       <=  0;
                fifo_tdata         <=  '0;
                fifo_tvalid        <=  0;
                fifo_tlast         <=  0;
                flag_data_over     <=  0;
                flag_preamble_over <=  0;
            end
        endcase
    end

    assign  mac_tready_out  =   mac_tready_o;
/*------------------------------------------------------------------------------
--  mac tx data fifo
------------------------------------------------------------------------------*/
 mac_tx_fifo mac_tx_fifo (
  .s_axis_aresetn   (!logic_rst),        // input wire s_axis_aresetn
  .s_axis_aclk      (logic_clk),        // input wire s_axis_aclk

  .s_axis_tvalid    (fifo_tvalid),      // input wire s_axis_tvalid
  .s_axis_tready    (fifo_tready),      // output wire s_axis_tready
  .s_axis_tdata     (fifo_tdata),       // input wire [7 : 0] s_axis_tdata
  .s_axis_tlast     (fifo_tlast),       // input wire s_axis_tlast

  .m_axis_aclk      (phy_tx_clk),        // input wire m_axis_aclk
  .m_axis_tvalid    (phy_tvalid_out),    // output wire m_axis_tvalid
  .m_axis_tready    (1'b1),              // input wire m_axis_tready
  .m_axis_tdata     (phy_txd_out),       // output wire [7 : 0] m_axis_tdata
  .m_axis_tlast     ()                   // output wire m_axis_tlast
);

 assign phy_terr_out    =   0;

 endmodule : mac_tx_crc_calculate