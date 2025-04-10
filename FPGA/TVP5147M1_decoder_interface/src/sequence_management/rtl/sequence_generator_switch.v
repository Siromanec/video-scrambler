module sequence_generator_switch(
      input wire clk,
      input wire reset_n,
      input wire H,
      input wire V,
      input wire [9:0] bt656_stream_in,
      input wire [9:0] sequence_in,
      output wire [9:0] bt656_stream_out,
      output wire V_out,
      output reg enable_generator,
      output reg load_generator
   );
   localparam ACTIVE_VIDEO_PIXELS = 2 * 720;
   reg prev_V, prev_H;
   wire V_fall = prev_V && !V;
   wire H_fall = prev_H && !H;
   wire V_rise = !prev_V && V;
   wire H_rise = !prev_H && H;

   reg V_internal;
   // does not actually change the vsync in the stream, it is a trick for line rotator to not do encryption
   assign V_out = V || V_internal;

   reg line_cnt;
   reg [$clog2(ACTIVE_VIDEO_PIXELS)-1:0] pixel_cnt;
   reg allow_counter;
   reg allow_out;
   reg sequence_done;
   assign bt656_stream_out = allow_out ? sequence_in : bt656_stream_in;


   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         prev_V <= V;
         prev_H <= H;
         load_generator <= 0;
         V_internal <= 0;
         pixel_cnt <= 0;
         allow_counter <= 0;
         sequence_done <= 0;
         enable_generator <= 0;
         allow_out <= 0;
      end else begin

         prev_V <= V;
         prev_H <= H;
   
         if (V) begin
            V_internal <= 1;
            sequence_done <= 0;
         end else if (H_rise && V_fall) begin
            load_generator <= 1;
            enable_generator <= 1;
//         end else if (H_rise && !sequence_done) begin

         end else if (H_fall && !sequence_done) begin
            load_generator <= 0;
            allow_counter <= 1;
            allow_out <= 1;
         end else if (!H && allow_counter) begin
            if (pixel_cnt < ACTIVE_VIDEO_PIXELS - 1) begin
               pixel_cnt <= pixel_cnt + 1;
            end else if (pixel_cnt < ACTIVE_VIDEO_PIXELS - 1 + 4) begin
               pixel_cnt <= pixel_cnt + 1;
               allow_out <= 0;
               enable_generator <= 0;
               sequence_done <= 1;
            end else begin
               V_internal <= 0;
               allow_counter <= 0;
               pixel_cnt <= 0;
            end
         end
      end
   end
endmodule