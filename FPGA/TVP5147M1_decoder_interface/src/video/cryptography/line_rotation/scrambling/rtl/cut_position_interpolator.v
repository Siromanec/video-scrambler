module cut_position_interpolator(
   input [7:0] raw_cut_position,
   output [10:0] cut_position
   );
   // 360 is number of chroma samles
   // there are 4 values per point in 360
   // the resulting split must not break up CrYCbY
   // e.g. CrYCbY|CrYCbY|CrYCbY and not Cr|YCbY|CrY|CbYCrY|CbY
   // 256 is a ranbdom number for split
   // correct coefficient is 360/256 = 1.4
   // but best fit is 1.375 and has 3 fractional bits
   // 1.375 * 256 = 352
   // it is not split at 0 position and a last 8 samples
   // thus offset of 4 is added
   localparam SCALE = 14'b1011; // 1.011 = 1.375

   localparam UPSAMPLE_SCALE = 11'd4;
   localparam OFFSET = 11'd4;


   assign cut_position = ((((raw_cut_position * SCALE) >> 3) + OFFSET)) * UPSAMPLE_SCALE;



endmodule