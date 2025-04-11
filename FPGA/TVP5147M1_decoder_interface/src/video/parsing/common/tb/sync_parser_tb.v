`timescale 10ns / 1ns
module sync_parser_tb;
//   localparam VIDEO_FILE_LOCATION = "video_f60.bin";
// localparam VIDEO_FILE_LOCATION = "video_f60_scrambled.bin";
 localparam VIDEO_FILE_LOCATION = "video_f60_descrambled.bin";
   localparam LINE_SIZE = 2 * 858;

   localparam LINE_COUNT = 525;
//   localparam TOTAL_FRAMES = 60;
   localparam TOTAL_FRAMES = 10;
   localparam TOTAL_LINES = LINE_COUNT * TOTAL_FRAMES;
   localparam TOTAL_BYTES = LINE_SIZE * TOTAL_LINES;


   reg clk_sig;
   reg reset_n_sig;
   reg [9:0] bt_656_sig;
   wire H_sig;
   wire V_sig;
   wire F_sig;

   reg H_prev;
   reg V_prev;
   reg F_prev;

   time H_count;
   time V_count;
   time F_count;

   sync_parser sync_parser_inst (
      .clk(clk_sig),
      .reset_n(reset_n_sig),
      .bt_656 (bt_656_sig),
      .H(H_sig),
      .V(V_sig),
      .F(F_sig)
   );

//   reg [7:0] video_data [0:TOTAL_LINES-1];
   reg [7:0] video_value;
   integer fd;

   time i;
   initial begin
      fd = $fopen(VIDEO_FILE_LOCATION, "rb");
      if (fd == 0) begin
         $display("Error: Could not open file %s", VIDEO_FILE_LOCATION);
         $display("fd = %d", fd);
         $finish;
      end


      H_prev = 0;
      V_prev = 0;
      F_prev = 0;

      H_count = 0;
      V_count = 0;
      F_count = 0;

      clk_sig = 0;
      reset_n_sig = 0;
      bt_656_sig = 0;

      #1;
      reset_n_sig = 1;



      for (i = 0; i < TOTAL_BYTES; i = i + 1) begin
         $fgets(video_value, fd);
         bt_656_sig = {video_value, 2'b00};
         #1;
         clk_sig = 0;
         #1;
         clk_sig = 1;

         if (H_sig != H_prev) begin
            if (H_sig == 1) begin
               H_count = H_count + 1;
            end
            H_prev = H_sig;
         end
         if (V_sig != V_prev) begin
            if (V_sig == 1) begin
               V_count = V_count + 1;
            end
            V_prev = V_sig;
         end
         if (F_sig != F_prev) begin
            if (F_sig == 1) begin
               F_count = F_count + 1;
            end
            F_prev = F_sig;
         end
      end
      $fclose(fd);
      if (H_count != TOTAL_LINES) begin
         $display("ERROR: H count mismatch. Expected %d, got %d", TOTAL_LINES, H_count);
      end
      if (V_count != TOTAL_FRAMES) begin
         $display("ERROR: V count mismatch. Expected %d, got %d", TOTAL_FRAMES, V_count);
      end
      if (F_count != 0) begin
         $display("ERROR: F count mismatch. Expected %d, got %d", 0, F_count);
      end
   end

endmodule