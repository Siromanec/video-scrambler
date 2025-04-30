`timescale 1ns / 1ns
module hash_drbg_sha256_randomness_tb;

   /*module hash_drbg_sha256(
	is_master_mode,
	reset_n,
	clk,
	next_seed,
	next_bits,
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
   reg [255:0] entropy;
   wire init_ready;
   wire next_bits_ready;
   wire [255:0] random_bits;
   wire [63:0] reseed_counter;
   wire busy;
   integer file;

   //localparam	SEED_GENERATOR_MAX_CYCLE = 8;
   //localparam	BITS_GENERATOR_MAX_CYCLE = 128; // 128 256-bit random numbers or 4096 random bytes
   //localparam  FILENAME = "random_output_hash_drbg_sha256.txt";

   localparam SEED_GENERATOR_MAX_CYCLE = 1;
   localparam BITS_GENERATOR_MAX_CYCLE = 512 * 8;  // 128 256-bit random numbers or 4096 random bytes
   localparam FILENAME = "data/random_output_hash_drbg.txt";

   localparam TOTAL_CYCLES = BITS_GENERATOR_MAX_CYCLE * SEED_GENERATOR_MAX_CYCLE;

   hash_drbg_sha256 hash_drbg_sha256_0 (
      .reset_n(reset_n),
      .clk(clk),
      .next_seed(next_seed),
      .next_bits(next_bits),
      .entropy(entropy),
      .init_ready(init_ready),
      .next_bits_ready(next_bits_ready),
      .random_bits(random_bits),
      .reseed_counter(reseed_counter),
      .catch_up_mode(0),
      .busy(busy)
   );
   defparam hash_drbg_sha256_0.BITS_GENERATOR_MAX_CYCLE = BITS_GENERATOR_MAX_CYCLE;
       defparam hash_drbg_sha256_0.SEED_GENERATOR_MAX_CYCLE = SEED_GENERATOR_MAX_CYCLE;


   always begin
      clk = 1'b0;
      #1;
      clk = 1'b1;
      #1;
   end

   time reseed_counter_out;
   time generated_counter;

   initial begin
      file = $fopen(FILENAME, "w");
      if (file == 0) begin
         $display("Error: Could not open file.");
         $finish;
      end
      reseed_counter_out = 0;
      reset_n = 1'b0;
      is_master_mode = 1'b1;
      next_seed = 1'b0;
      next_bits = 1'b0;
      entropy = 256'h0;
      generated_counter = 0;
      #5;
      reset_n = 1'b1;
      #5;
   end

   always @(posedge init_ready) begin

      if (reseed_counter_out < SEED_GENERATOR_MAX_CYCLE && generated_counter < TOTAL_CYCLES) begin
         reseed_counter_out = reseed_counter_out + 1;
         next_bits = 1'b1;

         $display("\nInit ready");
         $display("Current reseed: %d\n", reseed_counter);
      end else begin
         $display("\nWARNING: TOO MANY INITS\n");
      end

   end
   always @(negedge init_ready) begin
      $display("\nInit reset\n");
   end

   always @(posedge next_bits_ready) begin
      if (generated_counter < TOTAL_CYCLES) begin
         $display("\nRandom bits: 0x%h\n", random_bits[31:0]);
         $fwrite(file, "%h", random_bits);
         generated_counter = generated_counter + 1;
         next_bits = 1'b0;
         #5 next_bits = 1'b1;
      end else begin
         $fclose(file);
         $display("Data written to file successfully.");
         $display("\nTestbench finished\n");
         $finish;
      end
   end
endmodule
