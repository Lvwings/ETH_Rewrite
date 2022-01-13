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

    parameter         LOCAL_IP = 32'hC0A8_006E;
    parameter        LOCAL_MAC = 48'hABCD_1234_5678;

    logic        logic_clk;
    logic        logic_rst;
    logic        mac_rphy_clk;
    logic  [7:0] mac_rphy_data_in;
    logic        mac_rphy_valid_in;
    logic        mac_rphy_err_in;
    logic  [7:0] mac_tnet_data_out;
    logic        mac_tnet_valid_out;
    logic        mac_tnet_ready_in;
    logic        mac_tnet_last_out;
    logic [34:0] mac_tnet_type_out;

    mac_rx_crc_verify #(
            .LOCAL_IP(LOCAL_IP),
            .LOCAL_MAC(LOCAL_MAC)
        ) inst_mac_rx_crc_verify (
            .logic_clk          (logic_clk),
            .logic_rst          (logic_rst),
            .mac_rphy_clk       (mac_rphy_clk),
            .mac_rphy_data_in   (mac_rphy_data_in),
            .mac_rphy_valid_in  (mac_rphy_valid_in),
            .mac_rphy_err_in    (mac_rphy_err_in),
            .mac_tnet_data_out  (mac_tnet_data_out),
            .mac_tnet_valid_out (mac_tnet_valid_out),
            .mac_tnet_ready_in  (mac_tnet_ready_in),
            .mac_tnet_last_out  (mac_tnet_last_out),
            .mac_tnet_type_out  (mac_tnet_type_out)
        );

    task init();
        mac_rphy_data_in    <= '0;
        mac_rphy_valid_in <= '0;
        mac_rphy_err_in   <= '0;
        mac_ready_in  <= '1;
    endtask

    assign  logic_clk = clk;
    assign  logic_rst = srstb;

     initial begin
        mac_rphy_clk = '0;
        forever #(4) mac_rphy_clk = ~mac_rphy_clk;
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
    reg [0:0]   mac_rphy_rst  =   '1;


    always_ff @(posedge mac_rphy_clk or posedge logic_rst) begin
        if(logic_rst) begin
            mac_rphy_rst <= 1;
        end else begin
            mac_rphy_rst <= 0;
        end
    end

    reg [1:0]   rx_cnt  =   '0;
    always_ff @(posedge mac_rphy_clk) begin 
        if(mac_rphy_rst) begin
            data_cnt <= 0;
        end else begin
            if (data_cnt == 90)
                data_cnt <= 0;
            else
                data_cnt <= data_cnt + 1;

            if (data_cnt >= 10 && data_cnt < 10 + DATA_LENGTH) begin
                mac_rphy_data_in      <=  data_ram[data_cnt - 10];
                mac_rphy_valid_in   <=  1;
            end
            else begin
                mac_rphy_data_in      <=  8'hDD;
                mac_rphy_valid_in   <=  0;
            end

            rx_cnt  <=  rx_cnt + (data_cnt == 90);

            mac_rphy_err_in <= (data_cnt == 50) && (rx_cnt == 1);
        end
    end

endmodule