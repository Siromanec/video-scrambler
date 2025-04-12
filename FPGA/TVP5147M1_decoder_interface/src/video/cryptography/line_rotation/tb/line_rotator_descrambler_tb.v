`timescale 10ns / 1ns

module line_rotator_descrambler_tb;


   localparam VIDEO_FILE_LOCATION = "data/video_f60_scrambled.bin";
   localparam SCRAMBLED_VIDEO_FILE_LOCATION = "data/video_f60_descrambled.bin";
   localparam LINE_SIZE = 2 * 858;

   localparam LINE_COUNT = 525;
   //   localparam TOTAL_FRAMES = 60;
   localparam TOTAL_FRAMES = 10;
   localparam TOTAL_LINES = LINE_COUNT * TOTAL_FRAMES;
   localparam TOTAL_BYTES = LINE_SIZE * TOTAL_LINES;


   reg clk_sig;
   reg reset_n_sig;
   reg [9:0] bt656_sig;
   wire [9:0] bt656_scramled;
   wire H_sig;
   wire V_sig;
   wire F_sig;
   reg [7:0] cut_position;
   wire data_valid;
   reg prev_H;
   wire H_rise;
   assign H_rise = !prev_H & H_sig;

   localparam CUT_POSITION = 128;
   //   localparam CUT_POSITION = 0;
   sync_parser sync_parser_inst (
      .clk(clk_sig),
      .reset_n(reset_n_sig),
      .bt656(bt656_sig),
      .H(H_sig),
      .V(V_sig),
      .F(F_sig)
   );

   line_rotator line_rotator_inst (
      .clk(clk_sig),  // input  clk_sig
      .reset_n(reset_n_sig),  // input  reset_n_sig
      .data_in(bt656_sig),  // input [9:0] data_in_sig
      .raw_cut_position(cut_position),  // input [7:0] raw_cut_position_sig
      .V(V_sig),  // input  V_sig
      .H(H_sig),  // input  H_sig
      .data_out(bt656_scramled),  // output [9:0] data_out_sig
      .data_valid(data_valid)
   );
   defparam line_rotator_inst.MODE = 1;


   //   reg [7:0] video_data [0:TOTAL_LINES-1];
   reg [7:0] video_value;
   integer fd;
   integer fd_out;

   time i;
   time j;
   reg [31:0] seed;

   reg [7:0] line_store[0:(LINE_SIZE - 1)];
   reg [7:0] line_store_out[0:(LINE_SIZE - 1)];
   initial begin
      //      cut_position = $random(seed) % 256;
      seed = 42;
      fd   = $fopen(VIDEO_FILE_LOCATION, "rb");
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

      clk_sig = 0;
      reset_n_sig = 0;
      bt656_sig = 0;
      cut_position = {$random(seed)} % 256;
      #1;
      clk_sig = 0;
      #1;
      clk_sig = 1;
      reset_n_sig = 1;
      #1



      for (i = 0; i < TOTAL_BYTES / LINE_SIZE; i = i + 1) begin
         for (j = 0; j < LINE_SIZE; j = j + 1) begin
            $fgets(video_value, fd);
            line_store[j] = video_value;
            //            line_store_out[j] = 0;
         end

         for (j = 0; j != (LINE_SIZE - 1); j = j + 1) begin
            if (H_rise && !V_sig) cut_position = {$random(seed)} % 256;
            video_value = line_store[j];

            bt656_sig  = {video_value, 2'b00};

            #1;
            clk_sig = 0;
            #1;
            clk_sig = 1;
            // resulting video will be shifted by one line
            // because the initial output is an empty line
            // but i don't care because it will be a part of a stream
            // and happens only once and is solved by iterating further
            // the only consideration is when the encoder receives zeros and has to do something with it
            if (data_valid) line_store_out[j] = bt656_scramled[9:2];
            prev_H = H_sig;
         end
         for (j = 0; j < LINE_SIZE; j = j + 1) begin
            video_value = line_store_out[j];

            $fwrite(fd_out, "%c", video_value);
            //            line_store[j] = 0;

         end

      end
      $fclose(fd);
      $fclose(fd_out);
      $stop;

   end


endmodule
