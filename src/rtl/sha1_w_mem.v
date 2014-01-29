//======================================================================
//
// sha256_w_mem_reg.v
// -----------------
// The W memory. This includes functionality to expand the block
// into 64 words.
//
//
// Copyright (c) 2013 Secworks Sweden AB
// All rights reserved.
// 
// Redistribution and use in source and binary forms, with or 
// without modification, are permitted provided that the following 
// conditions are met: 
// 
// 1. Redistributions of source code must retain the above copyright 
//    notice, this list of conditions and the following disclaimer. 
// 
// 2. Redistributions in binary form must reproduce the above copyright 
//    notice, this list of conditions and the following disclaimer in 
//    the documentation and/or other materials provided with the 
//    distribution. 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS 
// FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE 
// COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//======================================================================

module sha256_w_mem(
                    input wire           clk,
                    input wire           reset_n,

                    input wire           init,

                    input wire [511 : 0] block,
                    input wire  [5 : 0]  addr,

                    output wire          ready,
                    output wire [31 : 0] w
                   );

  
  //----------------------------------------------------------------
  // Internal constant and parameter definitions.
  //----------------------------------------------------------------
  parameter CTRL_IDLE   = 0;
  parameter CTRL_UPDATE = 1;
  
  
  //----------------------------------------------------------------
  // Registers including update variables and write enable.
  //----------------------------------------------------------------
  reg [31 : 0] w_mem [0 : 63];
  reg w_mem_we;
  reg w0_w15_we;
  
  reg [5 : 0] w_ctr_reg;
  reg [5 : 0] w_ctr_new;
  reg         w_ctr_we;
  reg         w_ctr_inc;
  reg         w_ctr_set;
  
  reg [1 : 0]  sha256_w_mem_ctrl_reg;
  reg [1 : 0]  sha256_w_mem_ctrl_new;
  reg          sha256_w_mem_ctrl_we;
  
  
  //----------------------------------------------------------------
  // Wires.
  //----------------------------------------------------------------
  reg [31 : 0] w_tmp;
  reg [31 : 0] w_new;

  reg [5 : 0] w_addr;
  
  reg [31 : 0] d1;
  reg [31 : 0] d0;
  reg [31 : 0] w_7;
  reg [31 : 0] w_16;
  
  reg w_init;
  reg w_update;
  
  reg ready_tmp;
  
  
  //----------------------------------------------------------------
  // Concurrent connectivity for ports etc.
  //----------------------------------------------------------------
  assign w = w_tmp;
  assign ready = ready_tmp;
  
  
  //----------------------------------------------------------------
  // reg_update
  // Update functionality for all registers in the core.
  // All registers are positive edge triggered with synchronous
  // active low reset. All registers have write enable.
  //----------------------------------------------------------------
  always @ (posedge clk)
    begin : reg_update
      if (!reset_n)
        begin
          w_ctr_reg       <= 6'h00;

          sha256_w_mem_ctrl_reg <= CTRL_IDLE;
        end
      else
        begin

          if (w0_w15_we)
            begin
              w_mem[00] <= block[511 : 480];
              w_mem[01] <= block[479 : 448];
              w_mem[02] <= block[447 : 416];
              w_mem[03] <= block[415 : 384];
              w_mem[04] <= block[383 : 352];
              w_mem[05] <= block[351 : 320];
              w_mem[06] <= block[319 : 288];
              w_mem[07] <= block[287 : 256];
              w_mem[08] <= block[255 : 224];
              w_mem[09] <= block[223 : 192];
              w_mem[10] <= block[191 : 160];
              w_mem[11] <= block[159 : 128];
              w_mem[12] <= block[127 :  96];
              w_mem[13] <= block[95  :  64];
              w_mem[14] <= block[63  :  32];
              w_mem[15] <= block[31  :   0];
            end

          if (w_mem_we)
            begin
              w_mem[w_addr] <= w_new;
            end
          
          if (w_ctr_we)
            begin
              w_ctr_reg <= w_ctr_new;
            end
          
          if (sha256_w_mem_ctrl_we)
            begin
              sha256_w_mem_ctrl_reg <= sha256_w_mem_ctrl_new;
            end
        end
    end // reg_update

  
  //----------------------------------------------------------------
  // external_addr_mux
  //
  // Mux for the external read operation. This is where we exract
  // the W variable.
  //----------------------------------------------------------------
  always @*
    begin : external_addr_mux
      w_tmp = w_mem[addr];
    end // external_addr_mux


  //----------------------------------------------------------------
  // w_7_logic
  //----------------------------------------------------------------
  always @*
    begin : w_7_logic
      reg [5 : 0] w_7_addr;

      w_7_addr = w_ctr_reg - 6'h07;
      w_7 = w_mem[w_7_addr];
    end // w_7_logic


  //----------------------------------------------------------------
  // w_16_logic
  //----------------------------------------------------------------
  always @*
    begin : w_16_logic
      reg [5 : 0] w_16_addr;

      w_16_addr = w_ctr_reg - 6'h10;
      w_16 = w_mem[w_16_addr];
    end // w_16_logic


  //----------------------------------------------------------------
  // d0_logic
  //----------------------------------------------------------------
  always @*
    begin : d0_logic
      reg [31 : 0] w_15;
      reg [5 : 0]  w_15_addr;

      w_15_addr = w_ctr_reg - 6'h0f;
      w_15 = w_mem[w_15_addr];

      d0 = {w_15[6  : 0], w_15[31 :  7]} ^ 
           {w_15[17 : 0], w_15[31 : 18]} ^ 
           {3'b000, w_15[31 : 3]};
    end // d0_logic


  //----------------------------------------------------------------
  // d1_logic
  //----------------------------------------------------------------
  always @*
    begin : d1_logic
      reg [31 : 0] w_2;
      reg [5 : 0]  w_2_addr;

      w_2_addr = w_ctr_reg - 6'h02;
      w_2 = w_mem[w_2_addr];

      d1 = {w_2[16 : 0], w_2[31 : 17]} ^ 
           {w_2[18 : 0], w_2[31 : 19]} ^ 
           {10'b0000000000, w_2[31 : 10]};
    end // d1_logic
  

  //----------------------------------------------------------------
  // w_schedule
  //----------------------------------------------------------------
  always @*
    begin : w_schedule
      w0_w15_we = 0;
      w_mem_we = 0;
      w_addr = 0;
      
      w_new = d1 + w_7 + d0 + w_16;
      
      if (w_init)
        begin
          w0_w15_we = 1;
        end

      if (w_update)
        begin
          w_mem_we = 1;
          w_addr = w_ctr_reg;
        end // if (w_update)
    end // w_schedule

  
  //----------------------------------------------------------------
  // w_ctr
  // W schedule adress counter. Counts from 0x10 to 0x3f and
  // is used to expand the block into words.
  //----------------------------------------------------------------
  always @*
    begin : w_ctr
      w_ctr_new = 0;
      w_ctr_we  = 0;
      
      if (w_ctr_set)
        begin
          w_ctr_new = 6'h10;
          w_ctr_we  = 1;
        end

      if (w_ctr_inc)
        begin
          w_ctr_new = w_ctr_reg + 6'h01;
          w_ctr_we  = 1;
        end
    end // w_ctr

  
  //----------------------------------------------------------------
  // sha256_w_mem_fsm
  // Logic for the w shedule FSM.
  //----------------------------------------------------------------
  always @*
    begin : sha256_w_mem_fsm
      w_ctr_set = 0;
      w_ctr_inc = 0;
      w_init    = 0;
      w_update  = 0;

      ready_tmp = 0;
      
      sha256_w_mem_ctrl_new = CTRL_IDLE;
      sha256_w_mem_ctrl_we  = 0;
      
      case (sha256_w_mem_ctrl_reg)
        CTRL_IDLE:
          begin
            ready_tmp = 1;
            
            if (init)
              begin
                w_init    = 1;
                w_ctr_set = 1;
                
                sha256_w_mem_ctrl_new = CTRL_UPDATE;
                sha256_w_mem_ctrl_we  = 1;
              end
          end
        
        CTRL_UPDATE:
          begin
            w_update  = 1;
            w_ctr_inc = 1;

            if (w_ctr_reg == 6'h3f)
              begin
                sha256_w_mem_ctrl_new = CTRL_IDLE;
                sha256_w_mem_ctrl_we  = 1;
              end
          end
      endcase // case (sha256_ctrl_reg)
    end // sha256_ctrl_fsm

endmodule // sha256_w_mem

//======================================================================
// sha256_w_mem.v
//======================================================================
