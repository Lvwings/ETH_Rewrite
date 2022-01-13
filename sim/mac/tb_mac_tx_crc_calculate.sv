`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : tb_mac_tx_crc_calculate.sv
 Create     : 2021-12-13 11:15:18
 Revise     : 2021-12-13 11:15:18
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module tb_mac_tx_crc_calculate (); /* this is automatically generated */

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

    localparam PREAMBLE_REG = 64'h5555_5555_5555_55D5;


    logic       logic_clk;
    logic       logic_rst;
    logic [7:0] mac_rnet_data_in;
    logic       mac_rnet_valid_in;
    logic       mac_rnet_ready_out;
    logic       mac_rnet_last_in;
    logic       mac_tphy_clk;
    logic [7:0] mac_tphy_data_out;
    logic       mac_tphy_valid_out;
    logic       mac_tphy_err_out;

    mac_tx_crc_calculate inst_mac_tx_crc_calculate
        (
            .logic_clk          (logic_clk),
            .logic_rst          (logic_rst),
            .mac_rnet_data_in   (mac_rnet_data_in),
            .mac_rnet_valid_in  (mac_rnet_valid_in),
            .mac_rnet_ready_out (mac_rnet_ready_out),
            .mac_rnet_last_in   (mac_rnet_last_in),
            .mac_tphy_clk       (mac_tphy_clk),
            .mac_tphy_data_out  (mac_tphy_data_out),
            .mac_tphy_valid_out (mac_tphy_valid_out),
            .mac_tphy_err_out   (mac_tphy_err_out)
        );

        assign  logic_clk = clk;
        assign  logic_rst = srstb;

    initial begin
        mac_tphy_clk = '0;
        forever #(4) mac_tphy_clk = ~mac_tphy_clk;
    end   

    task init();
        mac_rnet_data_in  <= '0;
        mac_rnet_valid_in <= '0;
        mac_rnet_last_in  <= '0;
    endtask

    initial begin
        // do something
        init();

    end

    /*------------------------------------------------------------------------------
    --  initial test data
    ------------------------------------------------------------------------------*/
    localparam  FLIE_PATH   =   "D:/SourceTree/Soures/Git/sim/mac/mac_sim_data.txt";
    localparam  ADDR_START  =   8;
    localparam  ADDR_END    =   50;
    localparam  DATA_LENGTH =   ADDR_END - ADDR_START;

    reg [7:0]   data_ram    [ADDR_END - 1 : 0];

    initial begin
        $readmemh(FLIE_PATH,data_ram,0,ADDR_END-1);
    end

    /*------------------------------------------------------------------------------
    --  mac data
    ------------------------------------------------------------------------------*/

    logic   [7:0]   data_cnt    =   '0;

    always_ff @(posedge clk) begin 
        if (data_cnt < 10 || data_cnt >= 9 + DATA_LENGTH)
            data_cnt    <=  data_cnt + 1;
        else if (mac_tready_out)
            data_cnt    <=  data_cnt + 1;
        else
            data_cnt    <=  data_cnt;

        if (data_cnt >= 10 && data_cnt < 9 + DATA_LENGTH) begin
            mac_rnet_data_in    <= data_ram[data_cnt + ADDR_START - 9];
            mac_rnet_valid_in   <=  1;
        end
        else begin
            mac_rnet_data_in    <=  data_ram[ADDR_START];
            mac_rnet_valid_in   <=  0;
        end

        mac_rnet_last_in    <=  (data_cnt == 8 + DATA_LENGTH);
    end
    

endmodule