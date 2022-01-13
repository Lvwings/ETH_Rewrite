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
    parameter          LOCAL_IP = 32'hC0A8_006E;
    parameter         LOCAL_MAC = 48'h00D0_0800_0002;

    logic       extern_clk_in;
    logic       extern_rstn_in;
    logic       rgmii_clk_out;
    logic [3:0] rgmii_rxd_in;
    logic       rgmii_rxc_in;
    logic       rgmii_rx_ctl_in;
    logic [3:0] rgmii_txd_out;
    logic       rgmii_txc_out;
    logic       rgmii_tx_ctl_out;
    wire        mdio;
    logic       mdio_clk_out;
    logic       mdio_rstn_out;
    logic [7:0] udp_rdata_out;
    logic       udp_rvalid_out;
    logic       udp_rready_in;
    logic       udp_rlast_out;

    eth_top #(
            .XILINX_FAMILY(XILINX_FAMILY),
            .IODDR_STYLE(IODDR_STYLE),
            .CLOCK_INPUT_STYLE(CLOCK_INPUT_STYLE),
            .IDELAY_TAP_OPTION(IDELAY_TAP_OPTION),
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC)
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
            .mdio             (mdio),
            .mdio_clk_out     (mdio_clk_out),
            .mdio_rstn_out    (mdio_rstn_out)
          //.udp_rdata_out    (udp_rdata_out),
          //.udp_rvalid_out   (udp_rvalid_out),
          //.udp_rready_in    (udp_rready_in),
          //.udp_rlast_out    (udp_rlast_out)
        );


    assign  extern_clk_in  = clk;
    assign  extern_rstn_in = srstb;

    task init();
        rgmii_rxd_in    <= '0;
        rgmii_rx_ctl_in <= '0;
        udp_rready_in   <=  '1;
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


    /*------------------------------------------------------------------------------
    --  initial test data
    ------------------------------------------------------------------------------*/
    localparam  ARP_FLIE_PATH   =   "D:/SourceTree/Soures/Git/sim/mac/mac_sim_data.txt";
    localparam  UDP_FLIE_PATH   =   "D:/SourceTree/Soures/Git/sim/top/sim_udp_data_ab16.txt";

    localparam  ARP_DATA_LENGTH =   72;
    localparam  UDP_DATA_LENGTH =   80;

        logic   [7:0]   udp_ram    [UDP_DATA_LENGTH-1 : 0];

        initial begin
            $readmemh(UDP_FLIE_PATH,udp_ram);
        end        

        logic   [7:0]   arp_ram    [ARP_DATA_LENGTH-1 : 0];

        initial begin
            $readmemh(ARP_FLIE_PATH,arp_ram);
        end


    /*------------------------------------------------------------------------------
    --  rgmii data
    ------------------------------------------------------------------------------*/
    localparam  DATA_DELAY  = 32;
    logic [7:0] rxc_cnt     = '0;
    logic [3:0] flag_arp    = '1;

    always_ff @(posedge rgmii_rxc_2x) begin 
        rxc_cnt <= rxc_cnt + 1;
        if (rxc_cnt == 8'hFF)
            flag_arp    <=  flag_arp << 1;
        else
            flag_arp    <=  flag_arp;

        if (flag_arp[3]) begin
            if (rxc_cnt >= DATA_DELAY*2 && rxc_cnt < (DATA_DELAY + ARP_DATA_LENGTH)*2) begin
                rgmii_rxd_in    <= rxc_cnt[0] ? arp_ram[rxc_cnt[7:1] - DATA_DELAY][7:4] : arp_ram[rxc_cnt[7:1] - DATA_DELAY][3:0];
                rgmii_rx_ctl_in <= 1;
            end
            else begin
                rgmii_rxd_in    <= 0;
                rgmii_rx_ctl_in <= 0;            
            end            
        end // if (flag_arp[3])
        else begin
            if (rxc_cnt >= DATA_DELAY*2 && rxc_cnt < (DATA_DELAY + UDP_DATA_LENGTH)*2) begin
                rgmii_rxd_in    <= rxc_cnt[0] ? udp_ram[rxc_cnt[7:1] - DATA_DELAY][7:4] : udp_ram[rxc_cnt[7:1] - DATA_DELAY][3:0];
                rgmii_rx_ctl_in <= 1;
            end
            else begin
                rgmii_rxd_in    <= 0;
                rgmii_rx_ctl_in <= 0;            
            end             
        end


    end
    
endmodule
