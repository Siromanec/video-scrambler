`timescale 1ns / 1ns
module master_hash_slave_hash_drbg_slave_tb;

   /*module master_hash_slave_hash_drbg(
	is_master_mode,
	reset_n,
	clk,
	next_seed,
	next_bits,
	init,
	entropy,
	init_ready,
	next_bits_ready,
	random_bits,
	reseed_counter
);*/

   reg is_master_mode;
   reg reset_n;
   reg clk;
   reg next_seed;
   reg next_bits;
   reg init;
   reg [255:0] entropy;
   wire init_ready;
   wire next_bits_ready;
   wire [255:0] random_bits;
   wire [63:0] reseed_counter;

   localparam SEED_GENERATOR_MAX_CYCLE = 3;
   localparam BITS_GENERATOR_MAX_CYCLE = 3;

   localparam TOTAL_CYCLES = BITS_GENERATOR_MAX_CYCLE * SEED_GENERATOR_MAX_CYCLE;
   // external_sequence = [1, 2, 3, 5, 20, 4, 5]
   master_hash_slave_hash_drbg master_hash_slave_hash_drbg_0 (
      .is_master_mode(is_master_mode),
      .reset_n(reset_n),
      .clk(clk),
      .next_seed(next_seed),
      .next_bits(next_bits),
      .init(init),
      .entropy(entropy),
      .init_ready(init_ready),
      .next_bits_ready(next_bits_ready),
      .random_bits(random_bits),
      .reseed_counter(reseed_counter),
      .catch_up_mode(0)
   );
   defparam master_hash_slave_hash_drbg_0.BITS_GENERATOR_MAX_CYCLE = BITS_GENERATOR_MAX_CYCLE;
       defparam master_hash_slave_hash_drbg_0.SEED_GENERATOR_MAX_CYCLE = SEED_GENERATOR_MAX_CYCLE;

   always begin
      clk = 1'b0;
      #1;
      clk = 1'b1;
      #1;
   end

   time reseed_counter_out;
   time generated_counter;

   initial begin
      reseed_counter_out = 0;
      reset_n = 1'b0;
      is_master_mode = 1'b0;
      init = 1'b0;
      next_seed = 1'b0;
      next_bits = 1'b0;
      entropy = 256'h0;
      generated_counter = 0;
      #5;
      reset_n = 1'b1;
      #5;
      init = 1'b1;
   end

   always @(posedge init_ready) begin

      if (reseed_counter_out < SEED_GENERATOR_MAX_CYCLE && generated_counter < TOTAL_CYCLES) begin
         reseed_counter_out = reseed_counter_out + 1;
         init = 1'b0;
         next_bits = 1'b1;

         $display("\nInit ready");
         $display("Current reseed: %d\n", reseed_counter);
      end else begin
         $display("\nWARNING: TOO MANY INITS\n");
         $stop;
      end

   end

   always @(negedge init_ready) begin
      $display("\nInit reset\n");
   end

   always @(posedge next_bits_ready) begin
      if (generated_counter < TOTAL_CYCLES) begin
         $display("\nRandom bits: 0x%h\n", random_bits[31:0]);
         generated_counter = generated_counter + 1;
         next_bits = 1'b0;
         #5 next_bits = 1'b1;
      end else begin
         $display("\nTestbench finished\n");
         $stop;
      end
   end

   always @(posedge clk) begin
      //    if (reseed_counter == )
   end
endmodule
