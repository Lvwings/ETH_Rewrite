/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : phy_oddr.sv
 Create     : 2021-11-02 10:08:43
 Revise     : 2021-11-02 10:08:43
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

`timescale 1ns / 1ps

/*------------------------------------------------------------------------------
--  phy use RGMII interface
------------------------------------------------------------------------------*/

module phy_oddr#(
    // XILINX IODDR style ("IODDR", "IODDR2")
    // Use IODDR for Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
    // Use IODDR2 for Spartan-6 or lower vision
    parameter IODDR_STYLE = "IODDR",
    // Width of register in bits
    parameter WIDTH = 4    
    )
    (
        input                   phy_clk,
        input   [WIDTH-1 : 0]   d1_in, 
        input   [WIDTH-1 : 0]   d2_in,
        output  [WIDTH-1 : 0]   q_out 
             
    );

/*
Provides a consistent output DDR flip flop with DDR_CLK_EDGE ("SAME_EDGE") 
              _____       _____       _____       _____
    clk  ____/     \_____/     \_____/     \_____/     \_____
         _ ___________ ___________ ___________ ___________ __
    d1   _X____D0_____X____D2_____X____D4_____X____D6_____X__
         _ ___________ ___________ ___________ ___________ __
    d2   _X____D1_____X____D3_____X____D5_____X____D7_____X__
         _______ _____ _____ _____ _____ _____ _____ _____ ___
    d    _______X_D0__X_D1__X_D2__X_D3__X_D4__X_D5__X_D6__X_D7
*/

genvar  i;

generate
        for (i = 0; i < WIDTH; i = i + 1) begin
            //  Virtex-4, Virtex-5, Virtex-6, 7 Series, Ultrascale
            if (IODDR_STYLE == "IODDR") begin
                
               ODDR #(
                  .DDR_CLK_EDGE ("SAME_EDGE"),  // "OPPOSITE_EDGE" or "SAME_EDGE" 
                  .INIT         (1'b0),         // Initial value of Q: 1'b0 or 1'b1
                  .SRTYPE       ("ASYNC")       // Set/Reset type: "SYNC" or "ASYNC" 
               ) ODDR_inst (
                  .Q            (q_out[i]),     // 1-bit DDR output
                  .C            (phy_clk),       // 1-bit clock input
                  .CE           (1'b1),         // 1-bit clock enable input
                  .D1           (d1_in[i]),     // 1-bit data input (positive edge)
                  .D2           (d2_in[i]),     // 1-bit data input (negative edge)
                  .R            (1'b0),         // 1-bit reset
                  .S            (1'b0)          // 1-bit set
               );
            end
            else begin
            // Use IODDR2 for Spartan-6 or lower vision  
                ODDR2 #(
                    .DDR_ALIGNMENT  ("C0"),
                    .SRTYPE         ("ASYNC")
                )
                oddr_inst (
                    .Q              (q_out[i]),
                    .C0             (phy_clk),
                    .C1             (~phy_clk),
                    .CE             (1'b1),
                    .D0             (d1_in[i]),
                    .D1             (d2_in[i]),
                    .R              (1'b0),
                    .S              (1'b0)
                );                
            end
        end
endgenerate

endmodule
