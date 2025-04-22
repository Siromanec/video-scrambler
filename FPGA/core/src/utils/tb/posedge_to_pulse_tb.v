module posedge_to_pulse_tb;

   localparam WIDTH = 3;
   reg clk;
   reg [WIDTH-1:0] signal_in_sig;
   reg reset_n;
   wire pulse_out_sig;

   posedge_to_pulse posedge_to_pulse_inst (
      .clk(clk),
      .signal_in(signal_in_sig),
      .pulse_out(pulse_out_sig),
      .reset_n(reset_n)
   );
   defparam posedge_to_pulse_inst.WIDTH = WIDTH;

   always begin
      clk = 1'b0;
      #1;
      clk = 1'b1;
      #1;
   end

   initial begin
      reset_n = 1'b0;
      #5;
      reset_n = 1'b1;
      #5;
   end
   always begin
      signal_in_sig = 3'b0;
      #10;
      signal_in_sig = 3'b010;
      #10;
      $stop;
   end


endmodule
