`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : tb_eth_top.sv
 Create     : 2021-11-18 14:20:46
 Revise     : 2021-11-18 14:20:46
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

module tb_eth_top (); 

    // clock
    logic clk;
    initial begin
        clk = '0;
        forever #(10) clk = ~clk;
    end

    // synchronous reset
    logic srstb;
    initial begin
        srstb <= '0;
        repeat(10)@(posedge clk);
        srstb <= '1;
    end

    // (*NOTE*) replace reset, clock, others

    parameter     XILINX_FAMILY = "7-series";
    parameter       IODDR_STYLE = "IODDR";
    parameter CLOCK_INPUT_STYLE = "BUFR";
    parameter IDELAY_TAP_OPTION = "Fixed";

    logic       extern_clk_in;
    logic       extern_rstn_in;
    logic       rgmii_clk_out;
    logic [3:0] rgmii_rxd_in;
    logic       rgmii_rxc_in;
    logic       rgmii_rx_ctl_in;
    logic [3:0] rgmii_txd_out;
    logic       rgmii_txc_out;
    logic       rgmii_tx_ctl_out;
    logic       mdio_clk_out;
    logic       mdio_rstn_out;
    logic       phy_tx_clk;
    logic [7:0] phy_txd_in;
    logic       phy_tvalid_in;
    logic       phy_tready_out;
    logic       phy_terr_in;
    logic       phy_rx_clk;
    logic [7:0] phy_rxd_out;
    logic       phy_rvalid_out;
    logic       phy_rready_in;
    logic       phy_rerr_out;

    eth_top #(
            .XILINX_FAMILY(XILINX_FAMILY),
            .IODDR_STYLE(IODDR_STYLE),
            .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
            .IDELAY_TAP_OPTION(IDELAY_TAP_OPTION)
        ) inst_eth_top (
            .extern_clk_in    (extern_clk_in),
            .extern_rstn_in   (extern_rstn_in),
            .rgmii_clk_out    (rgmii_clk_out),
            .rgmii_rxd_in     (rgmii_rxd_in),
            .rgmii_rxc_in     (rgmii_rxc_in),
            .rgmii_rx_ctl_in  (rgmii_rx_ctl_in),
            .rgmii_txd_out    (rgmii_txd_out),
            .rgmii_txc_out    (rgmii_txc_out),
            .rgmii_tx_ctl_out (rgmii_tx_ctl_out),
            .mdio_clk_out     (mdio_clk_out),
            .mdio_rstn_out    (mdio_rstn_out),
            .phy_tx_clk       (phy_tx_clk),
            .phy_txd_in       (phy_txd_in),
            .phy_tvalid_in    (phy_tvalid_in),
            .phy_tready_out   (phy_tready_out),
            .phy_terr_in      (phy_terr_in),
 //           .phy_rx_clk       (phy_rx_clk),
            .phy_rxd_out      (phy_rxd_out),
            .phy_rvalid_out   (phy_rvalid_out),
            .phy_rready_in    (phy_rready_in),
            .phy_rerr_out     (phy_rerr_out)
        );

    assign  extern_clk_in  = clk;
    assign  extern_rstn_in = srstb;

    task init();
        rgmii_rxd_in    <= '0;
        rgmii_rx_ctl_in <= '0;

    endtask


    initial begin
        // do something
        init();
    end

    initial begin
        #(3);
        rgmii_rxc_in = '0;
        forever #(4) rgmii_rxc_in = ~rgmii_rxc_in;
    end

    logic rgmii_rxc_2x;
    initial begin
        #(1);
        rgmii_rxc_2x = '0;
        forever #(2) rgmii_rxc_2x = ~rgmii_rxc_2x;
    end

    assign  phy_tx_clk     = rgmii_rxc_in;
    assign  phy_txd_in     = 8'hAB;
    assign  phy_tvalid_in  = 1'b1;
    assign  phy_terr_in    = 1'b0;     

    reg [5:0] rxc_cnt = 0;

    always_ff @(posedge rgmii_rxc_2x) begin 
        rxc_cnt <= rxc_cnt + 1;

        if (rxc_cnt > 16) begin
            rgmii_rxd_in    <= rxc_cnt;
            rgmii_rx_ctl_in <= rxc_cnt[0];
        end
        else begin
            rgmii_rxd_in    <= 0;
            rgmii_rx_ctl_in <= 0;            
        end
    end
    
endmodule
