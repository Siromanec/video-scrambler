module cut_position_interpolator_tb;
   reg [7:0] raw_cut_position_sig;
   wire [10:0] cut_position_sig;

   cut_position_interpolator cut_position_interpolator_inst(
            .raw_cut_position(raw_cut_position_sig),
            .cut_position(cut_position_sig)
   );

   initial begin
       raw_cut_position_sig = 69;
       #1;
       $display("Expected %d, actual %d", 392, cut_position_sig);
       raw_cut_position_sig = 255;
       #1;
       $display("Expected %d, actual %d", 1416, cut_position_sig);
       raw_cut_position_sig = 0;
       #1;
       $display("Expected %d, actual %d", 16, cut_position_sig);
       raw_cut_position_sig = 1;
       #1;
       $display("Expected %d, actual %d", 20, cut_position_sig);
       raw_cut_position_sig = 2;
       #1;
       $display("Expected %d, actual %d", 24, cut_position_sig);
       raw_cut_position_sig = 3;
       #1;
       $display("Expected %d, actual %d", 32, cut_position_sig);
       raw_cut_position_sig = 4;
       #1;
       $display("Expected %d, actual %d", 36, cut_position_sig);
       raw_cut_position_sig = 5;
       #1;
       $display("Expected %d, actual %d", 40, cut_position_sig);
   end

endmodule