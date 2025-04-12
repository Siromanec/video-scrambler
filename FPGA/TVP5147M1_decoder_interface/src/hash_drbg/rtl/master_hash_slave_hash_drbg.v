// Copyright (C) 2024  Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions 
// and other software and tools, and any partner logic 
// functions, and any output files from any of the foregoing 
// (including device programming or simulation files), and any 
// associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License 
// Subscription Agreement, the Intel Quartus Prime License Agreement,
// the Intel FPGA IP License Agreement, or other applicable license
// agreement, including, without limitation, that your use is for
// the sole purpose of programming logic devices manufactured by
// Intel and sold by Intel or its authorized distributors.  Please
// refer to the applicable agreement for further details, at
// https://fpgasoftware.intel.com/eula.

// PROGRAM		"Quartus Prime"
// VERSION		"Version 23.1std.1 Build 993 05/14/2024 SC Lite Edition"
// CREATED		"Wed Mar 26 18:02:51 2025"

module master_hash_slave_hash_drbg (
   is_master_mode,
   reset_n,
   clk,
   next_seed,
   next_bits,
   entropy,
   catch_up_mode,
   init_ready,
   next_bits_ready,
   random_bits,
   reseed_counter,
   busy
);

   parameter BITS_GENERATOR_MAX_CYCLE = 37500;
   parameter SEED_GENERATOR_MAX_CYCLE = 65536;

   input wire is_master_mode;
   input wire reset_n;
   input wire clk;
   input wire next_seed;
   input wire next_bits;
   input wire [255:0] entropy;
   input wire catch_up_mode;
   output wire init_ready;
   output wire next_bits_ready;
   output wire [255:0] random_bits;
   output wire [63:0] reseed_counter;
   output wire busy;


   wire MASTER_BUSY;
   wire SLAVE_BUSY;

   assign busy = MASTER_BUSY | SLAVE_BUSY;  // in master mode is always busy

   wire _SHA_RESET_N;
   wire CLOCK;
   wire MASTER_DRBG_DO_RESEED;
   wire [255:0] MASTER_DRBG_ENTROPY;
   wire MASTER_DRBG_INIT_READY;
   wire MASTER_DRBG_NEXT;
   wire [2:0] MASTER_DRBG_NEXT_IN;
   wire MASTER_DRBG_NEXT_OUT;
   wire MASTER_DRBG_NEXT_FINAL;
   wire MASTER_DRBG_NEXT_READY;
   wire [255:0] MASTER_DRBG_RANDOM_BITS;
   wire MASTER_DRBG_RESET_N;
   wire [63:0] MASTER_RESEED_COUNTER;
   wire MASTER_SHA_RESET_N;
   wire [511:0] SHA_BLOCK;
   wire [255:0] SHA_DIGEST;
   wire SHA_DIGEST_VALID;
   wire SHA_INIT;
   wire SHA_MODE;
   wire SHA_NEXT;
   wire SHA_READY;
   wire SHA_RESET_N;
   wire SLAVE_DRBG_DO_RESEED;
   wire SLAVE_DRBG_INIT_READY;
   wire SLAVE_DRBG_NEXT;
   wire SLAVE_DRBG_NEXT_READY;
   wire [255:0] SLAVE_DRBG_RANDOM_BITS;
   wire SLAVE_RESET_N;
   wire SLAVE_SHA_RESET_N;
   wire next_seed_pulse_out;




   assign MASTER_DRBG_NEXT_IN[2] = SLAVE_DRBG_DO_RESEED & is_master_mode;


   hash_drbg master_drbg (
      .reset_n(MASTER_DRBG_RESET_N),
      .clk(CLOCK),
      .next(MASTER_DRBG_NEXT_FINAL),
      .sha_ready(SHA_READY),
      .sha_digest_valid(SHA_DIGEST_VALID),
      .entropy(MASTER_DRBG_ENTROPY),
      .sha_digest(SHA_DIGEST),
      .next_ready(MASTER_DRBG_NEXT_READY),
      .init_ready(MASTER_DRBG_INIT_READY),
      .do_reseed(MASTER_DRBG_DO_RESEED),
      .busy(MASTER_BUSY),
      .sha_init(SHA_INIT),
      .sha_reset_n(MASTER_SHA_RESET_N),
      .random_bits(MASTER_DRBG_RANDOM_BITS),
      .reseed_counter_out(MASTER_RESEED_COUNTER),
      .sha_block(SHA_BLOCK)
   );
   defparam master_drbg.RESEED_INTERVAL = SEED_GENERATOR_MAX_CYCLE; defparam master_drbg.SEEDLEN = 256;

   assign MASTER_DRBG_RESET_N = reset_n;


   assign MASTER_DRBG_NEXT_IN[1] = MASTER_DRBG_INIT_READY;

   assign MASTER_DRBG_NEXT_FINAL = MASTER_DRBG_NEXT_OUT | (next_seed & catch_up_mode);

   posedge_to_pulse b2v_inst12 (
      .clk(CLOCK),
      .reset_n(reset_n),
      .signal_in(MASTER_DRBG_NEXT_IN),
      .pulse_out(MASTER_DRBG_NEXT_OUT)
   );
   defparam b2v_inst12.WIDTH = 3;


   assign MASTER_DRBG_NEXT_IN[0] = MASTER_DRBG_NEXT;



   assign _SHA_RESET_N = SLAVE_SHA_RESET_N | MASTER_SHA_RESET_N;


   hash_drbg slave_drbg (
      .reset_n(SLAVE_RESET_N),
      .clk(CLOCK),
      .next(SLAVE_DRBG_NEXT),
      .sha_ready(SHA_READY),
      .sha_digest_valid(SHA_DIGEST_VALID),
      .entropy(MASTER_DRBG_RANDOM_BITS),
      .sha_digest(SHA_DIGEST),
      .next_ready(SLAVE_DRBG_NEXT_READY),
      .init_ready(SLAVE_DRBG_INIT_READY),
      .do_reseed(SLAVE_DRBG_DO_RESEED),
      .busy(SLAVE_BUSY),
      .sha_init(SHA_INIT),
      .sha_reset_n(SLAVE_SHA_RESET_N),
      .random_bits(SLAVE_DRBG_RANDOM_BITS),
      .sha_block(SHA_BLOCK)
   );
   defparam slave_drbg.RESEED_INTERVAL = BITS_GENERATOR_MAX_CYCLE; defparam slave_drbg.SEEDLEN = 256;

   assign SHA_RESET_N = reset_n & _SHA_RESET_N;

   assign SHA_MODE = 1'b1;
   assign SHA_NEXT = 1'b0;

   sha256_core b2v_inst5 (
      .clk(CLOCK),
      .reset_n(SHA_RESET_N),
      .init(SHA_INIT),
      .next(SHA_NEXT),
      .mode(SHA_MODE),
      .block(SHA_BLOCK),
      .ready(SHA_READY),
      .digest_valid(SHA_DIGEST_VALID),
      .digest(SHA_DIGEST)
   );


   posedge_to_pulse b2v_inst14 (
      .clk(CLOCK),
      .reset_n(reset_n),
      .signal_in(next_seed),
      .pulse_out(next_seed_pulse_out)
   );
   defparam b2v_inst14.WIDTH = 1;

   assign SLAVE_RESET_N = reset_n & MASTER_DRBG_NEXT_READY & !next_seed_pulse_out;

   assign init_ready = MASTER_DRBG_INIT_READY & SLAVE_DRBG_INIT_READY;

   assign CLOCK = clk;
   assign SLAVE_DRBG_NEXT = next_bits;
   assign MASTER_DRBG_NEXT = next_seed;
   assign MASTER_DRBG_ENTROPY = entropy;
   assign next_bits_ready = SLAVE_DRBG_NEXT_READY;
   assign random_bits = SLAVE_DRBG_RANDOM_BITS;
   assign reseed_counter = MASTER_RESEED_COUNTER;

endmodule

