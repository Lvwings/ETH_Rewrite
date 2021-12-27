`timescale 1ns / 1ps
/* -----------------------------------------------------------------------------
 Copyright (c) 2014-2021 All rights reserved
 -----------------------------------------------------------------------------
 Author     : lwings    https://github.com/Lvwings
 File       : mac_lfsr.sv
 Create     : 2021-12-06 15:09:21
 Revise     : 2021-12-06 15:09:21
 Language   : Verilog 2001
 -----------------------------------------------------------------------------*/

 module mac_lfsr #(
     // width of LFSR
    parameter LFSR_WIDTH = 32,
    // LFSR polynomial
    parameter LFSR_POLY = 32'h04C11DB7,
    // LFSR configuration: "GALOIS", "FIBONACCI"
    parameter LFSR_CONFIG = "GALOIS",
    // LFSR feed forward enable
    parameter LFSR_FEED_FORWARD = 0,
    // LFSR initial state
    parameter LFSR_INITIAL_STATE = 32'hFFFFFFFF,
    // LFSR output xor state
    parameter LFSR_STATE_OUT_XOR = 32'hFFFFFFFF,
    // bit-reverse input and output
    parameter REVERSE = 0,
    // width of data input
    parameter DATA_WIDTH = 8
    )
    (
        input                       clk,
        input                       rst,
        input   [DATA_WIDTH-1 : 0]  data_in,
        input                       data_valid_in,
        output  [DATA_WIDTH-1 : 0]  data_out,
        output  [LFSR_WIDTH-1 : 0]  lfsr_state_out_comb,
        output  [LFSR_WIDTH-1 : 0]  lfsr_state_out_reg
 );
 /*------------------------------------------------------------------------------
 --  
 LFSR_CONFIG

Specify the LFSR configuration, either Fibonacci or Galois.  

- Fibonacci is generally used for linear-feedback shift registers (LFSR) 
for pseudorandom binary sequence (PRBS) generators, scramblers, and descrambers.

- while Galois is generally used for cyclic redundancy check generators and checkers.

Fibonacci style (example for 64b66b scrambler, 0x8000000001)

   DIN (LSB first)
    |
    V
   (+)<---------------------------(+)<-----------------------------.
    |                              ^                               |
    |  .----.  .----.       .----. |  .----.       .----.  .----.  |
    +->|  0 |->|  1 |->...->| 38 |-+->| 39 |->...->| 56 |->| 57 |--'
    |  '----'  '----'       '----'    '----'       '----'  '----'
    V
   DOUT

Galois style (example for CRC16, 0x8005)

    ,-------------------+-------------------------+----------(+)<-- DIN (MSB first)
    |                   |                         |           ^
    |  .----.  .----.   V   .----.       .----.   V   .----.  |
    `->|  0 |->|  1 |->(+)->|  2 |->...->| 14 |->(+)->| 15 |--+---> DOUT
       '----'  '----'       '----'       '----'       '----'

LFSR_FEED_FORWARD

Generate feed forward instead of feed back LFSR.  Enable this for PRBS checking and 
self-synchronous descrambling.

Fibonacci feed-forward style (example for 64b66b descrambler, 0x8000000001)

   DIN (LSB first)
    |
    |  .----.  .----.       .----.    .----.       .----.  .----.
    +->|  0 |->|  1 |->...->| 38 |-+->| 39 |->...->| 56 |->| 57 |--.
    |  '----'  '----'       '----' |  '----'       '----'  '----'  |
    |                              V                               |
   (+)<---------------------------(+)------------------------------'
    |
    V
   DOUT

Galois feed-forward style

    ,-------------------+-------------------------+------------+--- DIN (MSB first)
    |                   |                         |            |
    |  .----.  .----.   V   .----.       .----.   V   .----.   V
    `->|  0 |->|  1 |->(+)->|  2 |->...->| 14 |->(+)->| 15 |->(+)-> DOUT
       '----'  '----'       '----'       '----'       '----'
 ------------------------------------------------------------------------------*/
 

 /*------------------------------------------------------------------------------
 --  define matrix
    state_matrix : [lfsr_state_reg]    = [state_matrix][state_in]      (without data)
    data_matrix  : [lfsr_state_out]    = [lfsr_state_reg] ^ [data_matrix][data_in]
 ------------------------------------------------------------------------------*/
 reg    [LFSR_WIDTH-1 : 0]  state_matrix    [LFSR_WIDTH-1 : 0];
 reg    [DATA_WIDTH-1 : 0]  data_matrix     [LFSR_WIDTH-1 : 0];

/*------------------------------------------------------------------------------
--  define inter registers
------------------------------------------------------------------------------*/
 // state_matrix shift row according to register shift 
 reg    [LFSR_WIDTH-1 : 0]  state_matrix_shift_reg       = '0;
 reg    [LFSR_WIDTH-1 : 0]  state_matrix_reverse_reg     = '0;

  // data_matrix shift row according to register shift 
 reg    [DATA_WIDTH-1 : 0]  data_matrix_shift_reg       = '0;
 reg    [DATA_WIDTH-1 : 0]  data_matrix_reverse_reg     = '0;

 // state
 reg    [LFSR_WIDTH-1 : 0]  lfsr_state_reg      =   '0;
 reg    [LFSR_WIDTH-1 : 0]  lfsr_state_o        =   '0;
 reg    [LFSR_WIDTH-1 : 0]  lfsr_state_in_reg   =   '0;

 /*------------------------------------------------------------------------------
 --  define parameters
 ------------------------------------------------------------------------------*/
 // feedback matrix
 localparam [LFSR_WIDTH-1 : 0]  FEEDBACK_MATRIX = {LFSR_POLY[LFSR_WIDTH-1 : 1],1'b0};

/*------------------------------------------------------------------------------
--  calculate state_matrix
------------------------------------------------------------------------------*/
 integer i,j;

 initial begin
    // initial 
    //  state_matrix : [I]  state is shifted as a whole
    //  data_matrix  : [0]  data is shifted one-bit by one-bit       
    for (i = 0; i < LFSR_WIDTH; i = i+1) begin
        state_matrix[i]     =   '0;
        state_matrix[i][i]  =   1;
        data_matrix[i]      =   '0;
    end
    
    for (j = DATA_WIDTH-1; j >= 0; j = j-1) begin

        // state_matrix shift
        state_matrix_shift_reg  =   state_matrix[LFSR_WIDTH-1];
        data_matrix_shift_reg   =   data_matrix[LFSR_WIDTH-1];

        //  when DATA_WIDTH > LFSR_WIDTH, data_in different parts will be shifted different times
        //  data_in[DATA_WIDTH-1            : DATA_WIDTH-  LFSR_WIDTH-1]     ceil(DATA_WIDTH/LFSR_WIDTH)    times
        //  data_in[DATA_WIDTH-LFSR_WIDTH-1 : DATA_WIDTH-2*LFSR_WIDTH-1]     ceil(DATA_WIDTH/LFSR_WIDTH)-1  times ...
        //  data_matrix mask data_in by (1 << j)
        data_matrix_shift_reg   =   data_matrix_shift_reg ^ (1 << j);

        for (i = LFSR_WIDTH-1; i > 0; i = i-1) begin
            state_matrix[i] =   state_matrix[i-1];
            data_matrix[i]  =   data_matrix[i-1];
        end
        state_matrix[0]     =   state_matrix_shift_reg;
        data_matrix[0]      =   data_matrix_shift_reg;

        //  lfsr states XOR MSB state shift-out
        for (i = LFSR_WIDTH-1; i > 0; i = i-1) begin
            if (FEEDBACK_MATRIX[i]) begin
                state_matrix[i] =   state_matrix[i] ^ state_matrix_shift_reg;
                data_matrix[i]  =   data_matrix[i] ^ data_matrix_shift_reg;
            end
            else begin
                state_matrix[i] =   state_matrix[i];
                data_matrix[i]  =   data_matrix[i];
            end                
        end          
    end

    // if REVERSE 
    if (REVERSE) begin
        // horizontal reverse 
        for (i = LFSR_WIDTH-1; i >= LFSR_WIDTH/2; i = i-1) begin
            //  state_matrix horizontal reverse
            state_matrix_reverse_reg        =   state_matrix[i];
            state_matrix[i]                 =   state_matrix[(LFSR_WIDTH-1)-i];
            state_matrix[(LFSR_WIDTH-1)-i]  =   state_matrix_reverse_reg;

            //  data_matrix horizontal reverse
            data_matrix_reverse_reg         =   data_matrix[i];
            data_matrix[i]                  =   data_matrix[(LFSR_WIDTH-1)-i];
            data_matrix[(LFSR_WIDTH-1)-i]   =   data_matrix_reverse_reg;
        end

        //  bit reverse
        for (i = LFSR_WIDTH-1; i >= 0; i = i-1) begin
            state_matrix_reverse_reg        =   '0;
            data_matrix_reverse_reg         =   '0;

            //  state_matrix bit reverse
            for (j = LFSR_WIDTH-1; j >= 0; j = j-1) begin
                state_matrix_reverse_reg[j] =   state_matrix[i][(LFSR_WIDTH-1)-j];
            end
            state_matrix[i]                 =   state_matrix_reverse_reg;

            //  data_matrix bit reverse
            for (j = DATA_WIDTH-1; j >= 0; j = j-1) begin
                data_matrix_reverse_reg[j]  =   data_matrix[i][(DATA_WIDTH-1)-j];
            end
            data_matrix[i]                  =   data_matrix_reverse_reg;
        end
    end // if (REVERSE)   
 end

/*------------------------------------------------------------------------------
--  calculate lfsr state
------------------------------------------------------------------------------*/
 integer m,n;

 always_comb begin 
        for (m = 0; m < LFSR_WIDTH; m = m+1) begin
            lfsr_state_reg[m]   =   0;

            //  XOR state_in
            for (n = 0; n < LFSR_WIDTH; n = n+1) begin
                if (state_matrix[m][n]) begin
                    lfsr_state_reg[m]   =   lfsr_state_reg[m] ^ lfsr_state_in_reg[n];
                end
            end

            //  XOR data_in
            for (n = 0; n < DATA_WIDTH; n = n+1) begin
                if (data_matrix[m][n]) begin
                    lfsr_state_reg[m]   =   lfsr_state_reg[m] ^ data_in[n];
                end
            end
        end
 end

/*------------------------------------------------------------------------------
--  output logic 
    state out xor specific LFSR_STATE_OUT_XOR according to different application scences
------------------------------------------------------------------------------*/
 always_ff @(posedge clk) begin
     if(rst) begin
        lfsr_state_in_reg  <= LFSR_INITIAL_STATE;
     end else begin
        lfsr_state_in_reg  <= data_valid_in ? lfsr_state_reg : lfsr_state_in_reg;
     end
 end

 assign lfsr_state_out_reg  = lfsr_state_in_reg ^ LFSR_STATE_OUT_XOR[LFSR_WIDTH-1 : 0];
 assign lfsr_state_out_comb = lfsr_state_reg ^ LFSR_STATE_OUT_XOR[LFSR_WIDTH-1 : 0];

 endmodule : mac_lfsr