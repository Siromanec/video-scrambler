`timescale 10ns / 1ns
/*
modelsim wave
sim:/drbg_consumer_tb/drbg_consumer_inst/first_read_iteration sim:/drbg_consumer_tb/drbg_consumer_inst/first_write_iteration sim:/drbg_consumer_tb/drbg_consumer_inst/read_done sim:/drbg_consumer_tb/drbg_consumer_inst/write_done sim:/drbg_consumer_tb/drbg_consumer_inst/do_read sim:/drbg_consumer_tb/drbg_consumer_inst/do_write sim:/drbg_consumer_tb/clk_sig sim:/drbg_consumer_tb/reset_n_sig sim:/drbg_consumer_tb/H_sig sim:/drbg_consumer_tb/V_sig sim:/drbg_consumer_tb/V_rising sim:/drbg_consumer_tb/bt_656_sig sim:/drbg_consumer_tb/next_bits sim:/drbg_consumer_tb/generator_busy sim:/drbg_consumer_tb/init_ready sim:/drbg_consumer_tb/next_bits_ready sim:/drbg_consumer_tb/next_seed sim:/drbg_consumer_tb/init sim:/drbg_consumer_tb/entropy sim:/drbg_consumer_tb/random_bits sim:/drbg_consumer_tb/random_bits_serial sim:/drbg_consumer_tb/random_bits_serial_valid sim:/drbg_consumer_tb/reseed_counter sim:/drbg_consumer_tb/i
*/
module drbg_consumer_tb;


   localparam VIDEO_FILE_LOCATION = "video_f60.bin";
   localparam NUMBERS_FILE = "drbg_consumer_numbers.bin";
   localparam LINE_SIZE = 2 * 858;

   localparam LINE_COUNT = 525;
   //   localparam TOTAL_FRAMES = 60;
   localparam TOTAL_FRAMES = 10;
   localparam TOTAL_LINES = LINE_COUNT * TOTAL_FRAMES;
   localparam TOTAL_BYTES = LINE_SIZE * TOTAL_LINES;


   reg clk_sig;
   reg reset_n_sig;
   reg reset_n_drbg_sig;
   reg [9:0] bt_656_sig;
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
   wire [63:0] reseed_counter;
   wire generator_busy;
   reg prev_V;
   wire V_rising = V_sig && !prev_V;

   master_hash_slave_hash_drbg master_hash_slave_hash_drbg_0 (
      .is_master_mode(0),
      .reset_n(reset_n_drbg_sig),
      .clk(clk_sig),
      .next_seed(next_seed),
      .next_bits(next_bits),
      .entropy(entropy),
      .init_ready(init_ready),
      .next_bits_ready(next_bits_ready),
      .random_bits(random_bits),
      .reseed_counter(reseed_counter),
      .busy(generator_busy)
   );
   //    defparam master_hash_slave_hash_drbg_0.BITS_GENERATOR_MAX_CYCLE = BITS_GENERATOR_MAX_CYCLE; // irrelevant
   ///defparam master_hash_slave_hash_drbg_0.SEED_GENERATOR_MAX_CYCLE = 2;

   sync_parser sync_parser_inst (
      .clk(clk_sig),
      .reset_n(reset_n_sig),
      .bt_656(bt_656_sig),
      .H(H_sig),
      .V(V_sig),
      .F(F_sig)
   );
   wire reset_n_consumer = !V_rising;

   drbg_consumer drbg_consumer_inst (
      .H(H_sig),  // input  H_sig
      .V(V_sig),  // input  V_sig
      .clk(clk_sig),  // input  clk_sig
      .reset_n(reset_n_consumer),  // input  reset_n_sig
      .data_in(random_bits),  // input [(DATA_WIDTH_IN-1):0] data_in_sig
      .data_in_valid(next_bits_ready),  // input  data_in_valid_sig
      .generator_busy(generator_busy),
      .data_out(random_bits_serial),  // output [(DATA_WIDTH_OUT-1):0] data_out_sig
      .data_out_valid(random_bits_serial_valid),  // output  data_out_valid_sig
      .need_next(next_bits)  // output  need_next_sig
   );

   defparam drbg_consumer_inst.DATA_WIDTH_IN = 256; defparam drbg_consumer_inst.DATA_WIDTH_OUT = 8;

   //   reg [7:0] video_data [0:TOTAL_LINES-1];
   reg [7:0] video_value;
   integer fd;
   integer fd_out;

   time i;
   time j;
   reg [31:0] seed;

   reg [7:0] line_store[0:(LINE_SIZE - 1)];
   initial begin
      //      cut_position = $random(seed) % 256;
      fd = $fopen(VIDEO_FILE_LOCATION, "rb");
      if (fd == 0) begin
         $display("Error: Could not open file %s", VIDEO_FILE_LOCATION);
         $display("fd = %d", fd);
         $finish;
      end

      fd_out = $fopen(NUMBERS_FILE, "wb");
      if (fd_out == 0) begin
         $display("Error: Could not open file %s", NUMBERS_FILE);
         $display("fd_out = %d", fd_out);
         $finish;
      end


      clk_sig = 0;
      reset_n_sig = 0;
      reset_n_drbg_sig = 0;
      bt_656_sig = 0;


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
      reset_n_sig = 1;

      for (i = 0; i < TOTAL_BYTES / LINE_SIZE; i = i + 1) begin
         for (j = 0; j < LINE_SIZE; j = j + 1) begin
            $fgets(video_value, fd);
            line_store[j] = video_value;
         end
         /*         if (!V_sig) begin // potential bug if it is vsync at the beginning of read line
            cut_position = {$random(seed)} % 256;
         end*/

         cut_position = random_bits_serial;
         if (!V_sig) begin
            $fwrite(fd_out, "%c", cut_position);
         end

         $display("cut_position: %d", cut_position);
         for (j = 0; j < LINE_SIZE; j = j + 1) begin
            prev_V = V_sig;

            //            $display("cut_position: %d", cut_position);
            video_value = line_store[j];

            bt_656_sig = {video_value, 2'b00};

            #1;
            clk_sig = 0;
            #1;
            clk_sig = 1;
         end

      end
      $fclose(fd);
      $fclose(fd_out);
      $stop;

   end

endmodule
