`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : tb_mac_crc_verify.sv
 Create     : 2021-12-09 10:16:42
 Revise     : 2021-12-09 10:16:42
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module tb_mac_crc_verify (); /* this is automatically generated */

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

    localparam PREAMBLE = 64'h5555_5555_5555_55D5;
    localparam GOOD_CRC = 32'hFFFFFFFF;

    logic       logic_clk;
    logic       logic_rst;
    logic       phy_rx_clk;
    logic [7:0] phy_rxd_in;
    logic       phy_rvalid_in;
    logic       phy_rerr_in;
    logic [7:0] mac_data_out;
    logic       mac_valid_out;
    logic       mac_ready_in;
    logic       mac_last_out;
    logic       mac_user_out;

    mac_rx_crc_verify inst_mac_crc_verify
        (
            .logic_clk     (logic_clk),
            .logic_rst     (logic_rst),
            .phy_rx_clk    (phy_rx_clk),
            .phy_rxd_in    (phy_rxd_in),
            .phy_rvalid_in (phy_rvalid_in),
            .phy_rerr_in   (phy_rerr_in),
            .mac_data_out  (mac_data_out),
            .mac_valid_out (mac_valid_out),
            .mac_ready_in  (mac_ready_in),
            .mac_last_out  (mac_last_out),
            .mac_user_out  (mac_user_out)
        );

    task init();
        phy_rxd_in    <= '0;
        phy_rvalid_in <= '0;
        phy_rerr_in   <= '0;
        mac_ready_in  <= '1;
    endtask

    assign  logic_clk = clk;
    assign  logic_rst = srstb;

     initial begin
        phy_rx_clk = '0;
        forever #(4) phy_rx_clk = ~phy_rx_clk;
    end   

    initial begin
        // do something
        init();
    end

    /*------------------------------------------------------------------------------
    --  initial test data
    ------------------------------------------------------------------------------*/
    localparam  FLIE_PATH   =   "D:/SourceTree/Soures/Git/sim/mac/mac_sim_data.txt";
    localparam  DATA_LENGTH =   72;

    reg [7:0]   data_ram    [DATA_LENGTH-1 : 0];

    initial begin
        $readmemh(FLIE_PATH,data_ram);
    end

    /*------------------------------------------------------------------------------
    --  phy data
    ------------------------------------------------------------------------------*/
    reg [6:0]   data_cnt    =   '0;
    reg [0:0]   phy_rx_rst  =   '1;


    always_ff @(posedge phy_rx_clk or posedge logic_rst) begin
        if(logic_rst) begin
            phy_rx_rst <= 1;
        end else begin
            phy_rx_rst <= 0;
        end
    end

    reg [1:0]   rx_cnt  =   '0;
    always_ff @(posedge phy_rx_clk) begin 
        if(phy_rx_rst) begin
            data_cnt <= 0;
        end else begin
            if (data_cnt == 90)
                data_cnt <= 0;
            else
                data_cnt <= data_cnt + 1;

            if (data_cnt >= 10 && data_cnt < 10 + DATA_LENGTH) begin
                phy_rxd_in      <=  data_ram[data_cnt - 10];
                phy_rvalid_in   <=  1;
            end
            else begin
                phy_rxd_in      <=  8'hDD;
                phy_rvalid_in   <=  0;
            end

            rx_cnt  <=  rx_cnt + (data_cnt == 90);

            phy_rerr_in <= (data_cnt == 50) && (rx_cnt == 1);
        end
    end

endmodule