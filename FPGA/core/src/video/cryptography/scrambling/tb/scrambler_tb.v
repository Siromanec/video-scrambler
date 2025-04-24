`timescale 1ns/100ps

/*
modelsim waves
sim:/line_rotator_descrambler_drbg_tb/clk_sig sim:/line_rotator_descrambler_drbg_tb/reset_n_sig sim:/line_rotator_descrambler_drbg_tb/reset_n_drbg_sig sim:/line_rotator_descrambler_drbg_tb/cut_position sim:/line_rotator_descrambler_drbg_tb/next_seed sim:/line_rotator_descrambler_drbg_tb/next_bits sim:/line_rotator_descrambler_drbg_tb/init sim:/line_rotator_descrambler_drbg_tb/entropy sim:/line_rotator_descrambler_drbg_tb/init_ready sim:/line_rotator_descrambler_drbg_tb/next_bits_ready sim:/line_rotator_descrambler_drbg_tb/random_bits sim:/line_rotator_descrambler_drbg_tb/random_bits_serial sim:/line_rotator_descrambler_drbg_tb/random_bits_serial_valid sim:/line_rotator_descrambler_drbg_tb/reseed_counter sim:/line_rotator_descrambler_drbg_tb/generator_busy sim:/line_rotator_descrambler_drbg_tb/prev_V sim:/line_rotator_descrambler_drbg_tb/V_rising sim:/line_rotator_descrambler_drbg_tb/reset_n_consumer sim:/line_rotator_descrambler_drbg_tb/H_sig sim:/line_rotator_descrambler_drbg_tb/V_sig sim:/line_rotator_descrambler_drbg_tb/F_sig sim:/line_rotator_descrambler_drbg_tb/bt656_scramled sim:/line_rotator_descrambler_drbg_tb/video_value sim:/line_rotator_descrambler_drbg_tb/fd sim:/line_rotator_descrambler_drbg_tb/fd_out sim:/line_rotator_descrambler_drbg_tb/i sim:/line_rotator_descrambler_drbg_tb/j
*/


// ---------------- USER DEFINED ----------------------

// `define DEBUG
`define DATA_DIR "data"

`ifdef V1
   `define BASE_VIDEO_NAME "church"
   `define VIDEO_FRAME_CNT_RAW 218
`elsif V2
   `define BASE_VIDEO_NAME "aperol"
   `define VIDEO_FRAME_CNT_RAW 84
`else
   `define BASE_VIDEO_NAME "church"
   `define VIDEO_FRAME_CNT_RAW 218
`endif

`define SEED 0


// ---------------- INTERNAL ----------------------


`ifndef DEBUG
   `define VIDEO_FRAME_CNT `VIDEO_FRAME_CNT_RAW
`else
   `define VIDEO_FRAME_CNT 10
`endif


`ifndef DESCRAMBLER
   `define DST_POSTFIX "scrambled"
`else
   `define SRC_POSTFIX "scrambled"
   `define DST_POSTFIX "descrambled"
`endif // SCRAMBLER


// ---------------- MODULE START ----------------------
`ifndef DESCRAMBLER
module scrambler_tb;
`else
module descrambler_tb;
`endif
   reg [8*255:0] SRC_FILE_LOCATION;
   reg [8*255:0] DST_FILE_LOCATION;


   parameter CLK_PERIOD = 2;

   localparam LINE_SIZE = 2 * 858;

   localparam LINE_COUNT = 525;

   localparam TOTAL_FRAMES = `VIDEO_FRAME_CNT;
   
   localparam TOTAL_LINES = LINE_COUNT * TOTAL_FRAMES;
   localparam TOTAL_BYTES = LINE_SIZE * TOTAL_LINES;

   reg clk;
   reg reset_n_sig;
   reg [9:0] bt656_stream_in_sig;
   reg [255:0] seed;
   wire [9:0] bt656_stream_out_sig;
`ifndef DESCRAMBLER
   localparam mode = 0;
`else
   localparam mode = 1;
`endif
   scrambler scrambler_inst
   (  
      .mode(mode),
      .clk(clk) ,	// input  clk_sig
      .reset_n(reset_n_sig) ,	// input  reset_n_sig
      .bt656_stream_in(bt656_stream_in_sig) ,	// input [9:0] bt656_stream_in_sig
      .seed(seed) ,	// input [255:0] seed_sig
      .bt656_stream_out(bt656_stream_out_sig) 	// output [9:0] bt656_stream_out_sig
   );

   integer fd;
   integer fd_out;
   integer code;
   reg [7:0] line_store[0:TOTAL_BYTES / LINE_SIZE - 1][0:(LINE_SIZE - 1)];

   time i;
   time j;
   time frame;
   time frame_cnt;

    // Clock generation
   initial begin
      clk = 0;
      forever #(CLK_PERIOD / 2) clk = ~clk;
   end

   initial begin
`ifndef DESCRAMBLER
      $sformat(SRC_FILE_LOCATION, "%0s/%0s_f%0d.bin", `DATA_DIR, `BASE_VIDEO_NAME, `VIDEO_FRAME_CNT_RAW);
`else
   `ifdef SPLIT
      // localparam SRC_FILE_LOCATION = "data/video_f60_scrambled_scrambler2.bin";
      // localparam DST_FILE_LOCATION = "data/video_f60_descrambled_scrambler2.bin";
   `else
         $sformat(SRC_FILE_LOCATION, "%0s/%0s_f%0d_%0s_seed%0d.bin", `DATA_DIR, `BASE_VIDEO_NAME, `VIDEO_FRAME_CNT, `SRC_POSTFIX, `SEED);
   `endif // SPLIT
`endif // SCRAMBLER
      $sformat(DST_FILE_LOCATION, "%0s/%0s_f%0d_%0s_seed%0d.bin", `DATA_DIR, `BASE_VIDEO_NAME, `VIDEO_FRAME_CNT, `DST_POSTFIX, `SEED);
      seed = `SEED;

      fd = $fopen(SRC_FILE_LOCATION, "rb");
      if (fd == 0) begin
         $display("Error: Could not open file %s", SRC_FILE_LOCATION);
         $display("fd = %d", fd);
         $finish;
      end


      code = $fread(line_store[0][0], fd, 0, TOTAL_BYTES);
      if (code == 0) begin
         $display("Error: Could not read data.");
         $stop;
      end else begin
         $display("Read %0d bytes of data.", code);
      end
      $fclose(fd);
      $display("\nInit ready");
      reset_n_sig = 0;
      #(CLK_PERIOD * 10);
      reset_n_sig = 1;
      frame = 0;

      for (i = 0; i < code / LINE_SIZE; i = i + 1) begin
         if (i % LINE_COUNT == 0) begin
            frame = frame + 1;
         end
         for (j = 0; j < LINE_SIZE; j = j + 1) begin
            bt656_stream_in_sig = {line_store[i][j], 2'b00};
            line_store[i][j] = bt656_stream_out_sig[9:2];
            #(CLK_PERIOD);
         end
      end

      fd_out = $fopen(DST_FILE_LOCATION, "wb");
      if (fd_out == 0) begin
         $display("Error: Could not open file %s", DST_FILE_LOCATION);
         $display("fd_out = %d", fd_out);
         $finish;
      end
      $display("Begining to write results...");
      for (i = 0; i < code / LINE_SIZE; i = i + 1) begin
         for (j = 0; j < LINE_SIZE; j = j + 1) begin
            $fwrite(fd_out, "%c", line_store[i][j]);

         end
      end
      $display("Results written");
      $fclose(fd_out);
      $stop;

   end

   initial begin
      $monitor("frame: %d/%d", frame, (code/LINE_SIZE)/LINE_COUNT);
   end
endmodule
