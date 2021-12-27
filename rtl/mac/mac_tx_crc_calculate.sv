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
    typedef enum    logic [2:0]   {IDLE,PREAMBLE,DATA,ATUO_FILL,CRC}    state_t;
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
    logic           flag_atuo_fill      =   '0;     //  data length < 46
    logic   [7:0]   fifo_tdata          =   '0;
    logic           fifo_tvalid         =   '0;
    logic           fifo_tready;
    logic           fifo_tlast          =   '0;

    always_comb begin 
        case (tcrc_state)
            IDLE    :                                       tcrc_next_state = mac_tvalid_in       ? PREAMBLE : IDLE;
            PREAMBLE:                                       tcrc_next_state = flag_preamble_over  ? DATA : PREAMBLE;
            DATA    : if (flag_data_over & flag_atuo_fill)  tcrc_next_state = ATUO_FILL;
                      else if (flag_data_over)              tcrc_next_state = CRC;
                      else                                  tcrc_next_state = DATA;
            ATUO_FILL :                                     tcrc_next_state = flag_data_over      ? CRC : ATUO_FILL;
            CRC     :                                       tcrc_next_state = fifo_tlast          ? IDLE : CRC;
            default :                                       tcrc_next_state = IDLE;
        endcase
    end
/*------------------------------------------------------------------------------
--  crc calculate
------------------------------------------------------------------------------*/
    logic   [7:0]       crc_data    =   '0;
    logic               crc_valid   =   '0;
    logic               crc_rst     =   '0;
    logic   [31:0]      crc_result;
    logic   [31:0]      crc_resultr;

    always_ff @(posedge logic_clk) begin 
        case (tcrc_next_state)
            IDLE    :   begin
                crc_data  <= 0;
                crc_valid <= 0;
                crc_rst   <= 1;              
            end
            DATA    :   begin
                crc_data  <=  (mac_tvalid_in && mac_tready_out && fifo_tready) ? mac_tdata_in : fifo_tdata;
                crc_valid <=  (mac_tvalid_in && mac_tready_out && fifo_tready);
            end
            ATUO_FILL : begin
                crc_data  <=  '0;
                crc_valid <=  fifo_tready;  
            end // ATUO_FILL 
            CRC     :   begin
                crc_data  <= 0;
                crc_valid <= 0;                
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
            .lfsr_state_out_reg    (crc_resultr)
        );    
    
/*------------------------------------------------------------------------------
-- FIFO data generate
    - Add ETH preamble 
    - Add CRC
    - Atuo fill frame (use 0) if PREAMBLE + eth head + data length < 68
ETH min length = eth head(14) + data(46) + crc(4) = 64
------------------------------------------------------------------------------*/
    localparam          PREAMBLE_REG        =   64'h5555_5555_5555_55D5;  
    localparam          MIN_BYTE_LENGTH     =   68; //  68
    localparam          MAX_BYTE_LENGTH     =   1522; //  1522
    logic   [10:0]      byte_cnt            =   '0;
    logic   [1:0]       crc_cnt             =   '0;
    logic               mac_tready_o        =   '0;

    always_ff @(posedge logic_clk) begin
        case (tcrc_next_state)

            PREAMBLE    : begin
                if (fifo_tready) begin
                    byte_cnt            <=  byte_cnt + 1;
                    fifo_tdata          <=  PREAMBLE_REG[8*(7-byte_cnt) +: 8];
                    fifo_tvalid         <=  1;
                    fifo_tlast          <=  0;
                    flag_preamble_over  <=  (byte_cnt == 7);
                end
            end
            DATA    : begin
                byte_cnt            <=  byte_cnt + (fifo_tvalid & fifo_tready);

                mac_tready_o        <=  !mac_tlast_in && mac_tvalid_in && fifo_tready;
                fifo_tdata          <=  (mac_tvalid_in && mac_tready_out && fifo_tready) ? mac_tdata_in : fifo_tdata;
                fifo_tvalid         <=  (mac_tvalid_in && mac_tready_out && fifo_tready);
                flag_preamble_over  <=  0;
                flag_data_over      <=  (mac_tlast_in && mac_tvalid_in && mac_tready_out) || (byte_cnt == MAX_BYTE_LENGTH-1);              
                flag_atuo_fill      <=  (byte_cnt < MIN_BYTE_LENGTH-1);
            end
            ATUO_FILL : begin
                byte_cnt            <=  byte_cnt + (fifo_tvalid & fifo_tready);

                fifo_tdata          <=  '0;
                fifo_tvalid         <=  fifo_tready;
                flag_data_over      <=  (byte_cnt == MIN_BYTE_LENGTH-1);
                mac_tready_o        <=  0;
            end // ATUO_FILL 
            CRC     : begin
                if (fifo_tready) begin
                    crc_cnt         <=  crc_cnt + 1;
                    fifo_tdata      <=  (crc_cnt == 0) ? crc_result[8*crc_cnt +: 8] : crc_resultr[8*crc_cnt +: 8];
                    fifo_tvalid     <=  1;
                    fifo_tlast      <=  (crc_cnt == 3);                    
                end
                mac_tready_o        <=  0;
                flag_data_over      <=  0;
            end
            default : begin
                byte_cnt           <=  '0;
                crc_cnt            <=  '0;
                mac_tready_o       <=  0;
                fifo_tdata         <=  '0;
                fifo_tvalid        <=  0;
                fifo_tlast         <=  0;
                flag_data_over     <=  0;
                flag_preamble_over <=  0;
                flag_atuo_fill     <=  0;
            end
        endcase
    end

    assign  mac_tready_out  =   mac_tready_o;

/*------------------------------------------------------------------------------
--  logic reset cdc
------------------------------------------------------------------------------*/
    logic                 phy_tx_rst;

    sync_reset #(
        .SYNC_DEPTH(3)
    ) inst_sync_reset (
        .sys_clk      (phy_tx_clk),
        .async_rst    (logic_rst),
        .sync_rst_out (phy_tx_rst)
    );
/*------------------------------------------------------------------------------
--  ETH GAP
------------------------------------------------------------------------------*/
    typedef enum logic [0:0]    {GIDLE,GAP_WAIT}    state_g;
    state_g gt_state,gt_next;

    localparam      ETH_GAP       =   16;
    logic   [7:0]   gap_cnt       =   '0;
    logic           phy_tlast;
    logic           phy_tvalid;
    logic           phy_tready    =   '0;
    logic           flag_gap_over =   '0;

    always_ff @(posedge phy_tx_clk) begin 
        if(phy_tx_rst) begin
           gt_state  <= GIDLE;
        end else begin
           gt_state  <= gt_next;
        end
    end

    always_comb begin  
        case (gt_state)
            GIDLE   :       gt_next =   phy_tlast & phy_tvalid ? GAP_WAIT : GIDLE;
            GAP_WAIT    :   gt_next =   flag_gap_over ? GIDLE : GAP_WAIT;
            default :       gt_next =   GIDLE;
        endcase 
    end

    always_ff @(posedge phy_tx_clk) begin 
        case (gt_next)
            GIDLE   : begin
                gap_cnt       <=  '0;
                flag_gap_over <=  0;
                phy_tready    <=  1;                
            end // GIDLE   
            GAP_WAIT: begin
                gap_cnt       <=  gap_cnt + 1;
                flag_gap_over <=  (gap_cnt == ETH_GAP);
                phy_tready    <=  0;
            end // GAP_WAIT   
            default : begin
                gap_cnt       <=  '0;
                flag_gap_over <=  0;
                phy_tready    <=  0;
            end // default 
        endcase
    end
/*------------------------------------------------------------------------------
--  mac tx data fifo
------------------------------------------------------------------------------*/
logic   [7:0]   phy_txd;

 mac_tx_fifo mac_tx_fifo (
  .s_axis_aresetn   (!logic_rst),        // input wire s_axis_aresetn
  .s_axis_aclk      (logic_clk),        // input wire s_axis_aclk

  .s_axis_tvalid    (fifo_tvalid),      // input wire s_axis_tvalid
  .s_axis_tready    (fifo_tready),      // output wire s_axis_tready
  .s_axis_tdata     (fifo_tdata),       // input wire [7 : 0] s_axis_tdata
  .s_axis_tlast     (fifo_tlast),       // input wire s_axis_tlast

  .m_axis_aclk      (phy_tx_clk),        // input wire m_axis_aclk
  .m_axis_tvalid    (phy_tvalid),    // output wire m_axis_tvalid
  .m_axis_tready    (phy_tready),        // input wire m_axis_tready
  .m_axis_tdata     (phy_txd),       // output wire [7 : 0] m_axis_tdata
  .m_axis_tlast     (phy_tlast)          // output wire m_axis_tlast
);

 assign phy_terr_out    =   0;
 assign phy_tvalid_out  =   phy_tvalid & phy_tready;
 assign phy_txd_out     =   phy_tvalid_out ? phy_txd : 0;

 endmodule : mac_tx_crc_calculate