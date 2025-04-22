`timescale 10ns / 1ns
/*
modelsim wave
sim:/line_rotator_drbg_tb/clk_sig sim:/line_rotator_drbg_tb/reset_n_sig sim:/line_rotator_drbg_tb/reset_n_drbg_sig sim:/line_rotator_drbg_tb/bt656_sig sim:/line_rotator_drbg_tb/bt656_scramled sim:/line_rotator_drbg_tb/H_sig sim:/line_rotator_drbg_tb/V_sig sim:/line_rotator_drbg_tb/F_sig sim:/line_rotator_drbg_tb/cut_position sim:/line_rotator_drbg_tb/next_seed sim:/line_rotator_drbg_tb/next_bits sim:/line_rotator_drbg_tb/init sim:/line_rotator_drbg_tb/entropy sim:/line_rotator_drbg_tb/init_ready sim:/line_rotator_drbg_tb/next_bits_ready sim:/line_rotator_drbg_tb/random_bits sim:/line_rotator_drbg_tb/random_bits_serial sim:/line_rotator_drbg_tb/random_bits_serial_valid sim:/line_rotator_drbg_tb/reseed_counter sim:/line_rotator_drbg_tb/generator_busy sim:/line_rotator_drbg_tb/prev_V sim:/line_rotator_drbg_tb/V_rising sim:/line_rotator_drbg_tb/reset_n_consumer sim:/line_rotator_drbg_tb/video_value sim:/line_rotator_drbg_tb/i sim:/line_rotator_drbg_tb/j
*/
module line_rotator_drbg_tb;


   localparam VIDEO_FILE_LOCATION = "data/video_f60.bin";
   localparam SCRAMBLED_VIDEO_FILE_LOCATION = "data/video_f60_scrambled_drbg.bin";
   localparam LINE_SIZE = 2 * 858;

   localparam LINE_COUNT = 525;
   //   localparam TOTAL_FRAMES = 60;
   localparam TOTAL_FRAMES = 10;
   localparam TOTAL_LINES = LINE_COUNT * TOTAL_FRAMES;
   localparam TOTAL_BYTES = LINE_SIZE * TOTAL_LINES;


   reg clk_sig;
   reg reset_n_sig;
   reg reset_n_drbg_sig;
   reg [9:0] bt656_sig;
   wire [9:0] bt656_scramled;
   wire H_sig;
   wire V_sig;
   wire F_sig;
   reg [7:0] cut_position;

   wire next_seed = V_sig;
   wire next_bits;
   reg init;
   reg [255:0] entropy;
   wire init_ready;
   wire next_bits_ready;
   wire [255:0] random_bits;
   wire [7:0] random_bits_serial;
   wire random_bits_serial_valid;
   wire [31:0] reseed_counter;
   wire generator_busy;
   reg prev_V;
   wire V_rising = V_sig && !prev_V;
   reg first_iter_done;
   wire data_out_valid;

   wire reset_n_consumer = !V_rising && first_iter_done;
   hash_drbg_sha256 hash_drbg_sha256_0 (
      .reset_n(reset_n_drbg_sig),
      .clk(clk_sig),
      .next_seed(next_seed),
      .next_bits(next_bits),
      .entropy(entropy),
      .init_ready(init_ready),
      .next_bits_ready(next_bits_ready),
      .random_bits(random_bits),
      .reseed_counter(reseed_counter),
      .busy(generator_busy),
      .catch_up_mode(0)
   );
   //    defparam hash_drbg_sha256_0.BITS_GENERATOR_MAX_CYCLE = BITS_GENERATOR_MAX_CYCLE; // irrelevant
   ///defparam hash_drbg_sha256_0.SEED_GENERATOR_MAX_CYCLE = 2;

   sync_parser sync_parser_inst (
      .clk(clk_sig),
      .reset_n(reset_n_sig),
      .bt656(bt656_sig),
      .H(H_sig),
      .V(V_sig),
      .F(F_sig)
   );


   drbg_consumer drbg_consumer_inst (
      .H(H_sig),  // input  H_sig
      .V(V_sig),  // input  V_sig
      .clk(clk_sig),  // input  clk_sig
      .reset_n(reset_n_drbg_sig),  // input  reset_n_sig
      .data_in(random_bits),  // input [(DATA_WIDTH_IN-1):0] data_in_sig
      .data_in_valid(next_bits_ready),  // input  data_in_valid_sig
      .generator_busy(generator_busy),
      .data_out(random_bits_serial),  // output [(DATA_WIDTH_OUT-1):0] data_out_sig
      .data_out_valid(random_bits_serial_valid),  // output  data_out_valid_sig
      .need_next(next_bits)  // output  need_next_sig
   );

   line_rotator line_rotator_inst (
      .MODE(0),
      .clk(clk_sig),  // input  clk_sig
      .reset_n(reset_n_sig),  // input  reset_n_sig
      .data_in(bt656_sig),  // input [9:0] data_in_sig
      .raw_cut_position(random_bits_serial),  // input [7:0] raw_cut_position_sig
      .V(V_sig),  // input  V_sig
      .H(H_sig),  // input  H_sig
      .data_out(bt656_scramled),  // output [9:0] data_out_sig
      .data_out_valid(data_out_valid)
   );

   defparam drbg_consumer_inst.DATA_WIDTH_IN = 256; defparam drbg_consumer_inst.DATA_WIDTH_OUT = 8;

   //   reg [7:0] video_data [0:TOTAL_LINES-1];
   reg [7:0] video_value;
   integer fd;
   integer fd_out;

   time i;
   time j;

   reg [7:0] line_store[0:(LINE_SIZE - 1)];
   reg [7:0] line_store_out[0:(LINE_SIZE - 1)];

   initial begin
      fd = $fopen(VIDEO_FILE_LOCATION, "rb");
      if (fd == 0) begin
         $display("Error: Could not open file %s", VIDEO_FILE_LOCATION);
         $display("fd = %d", fd);
         $finish;
      end

      fd_out = $fopen(SCRAMBLED_VIDEO_FILE_LOCATION, "wb");
      if (fd_out == 0) begin
         $display("Error: Could not open file %s", SCRAMBLED_VIDEO_FILE_LOCATION);
         $display("fd_out = %d", fd_out);
         $finish;
      end

      first_iter_done = 0;
      clk_sig = 0;
      reset_n_sig = 0;
      reset_n_drbg_sig = 0;
      bt656_sig = 0;

      init = 1'b0;

      entropy = 256'h0;


      #1;
      clk_sig = 0;
      #1;
      clk_sig = 1;
      reset_n_drbg_sig = 1;
      while (!init_ready) begin
         #1;
         clk_sig = 0;
         #1;
         clk_sig = 1;
      end
      $display("\nInit ready");
      first_iter_done  = 1;
      reset_n_sig = 1;

      for (i = 0; i < TOTAL_BYTES / LINE_SIZE; i = i + 1) begin
         for (j = 0; j < LINE_SIZE; j = j + 1) begin
            $fgets(video_value, fd);
            line_store[j] = video_value;
         end

         $display("line: %d  cut_position: %d", i, random_bits_serial);

         for (j = 0; j < LINE_SIZE; j = j + 1) begin
            prev_V = V_sig;

            video_value = line_store[j];

            bt656_sig = {video_value, 2'b00};

            #1;
            clk_sig = 0;
            #1;
            clk_sig = 1;
            if (data_out_valid) line_store_out[j] = bt656_scramled[9:2];
         end
         for (j = 0; j < LINE_SIZE; j = j + 1) begin
            video_value = line_store_out[j];

            $fwrite(fd_out, "%c", video_value);

         end

      end
      $fclose(fd);
      $fclose(fd_out);
      $stop;

   end

endmodule
