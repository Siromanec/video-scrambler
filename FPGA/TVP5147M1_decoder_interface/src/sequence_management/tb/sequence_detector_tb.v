`timescale 1ps / 1ps
module sequence_detector_tb;
   reg clock_sig;
   reg [31:0] generator_sequence_sig;
   reg enable_sig;
   reg load_sig;
   wire [9:0] generator_sequence_out_sig;
   wire [7:0] identifier_const_id;
   reg [9:0] detector_sequence_in_sig;
   wire [31:0] detector_sequence_out_sig;
   wire ready_sig;
   reg enable_detector;
   
   sequence_detector sequence_detector_inst
   (
      .clock(clock_sig) ,	// input  clock_sig
      .sequence_in(generator_sequence_out_sig) ,	// input [9:0] sequence_in_sig
      .reset_n(enable_detector) ,	// input  reset_n_sig
      .sequence_out(detector_sequence_out_sig) ,	// output [31:0] sequence_out_sig
      .ready(ready_sig) 	// output  ready_sig
   );
   sequence_generator sequence_generator_inst
   (
        .clock(clock_sig) ,	// input  clock_sig
        .sequence(generator_sequence_sig) ,	// input [31:0] sequence_sig
        .enable(enable_sig) ,	// input  enable_sig
        .load(load_sig) ,	// input  load_sig
        .sequence_out(generator_sequence_out_sig) 	// output [9:0] sequence_out_sig
   );
   identifier_const identifier_const_inst
   (
        .id(identifier_const_id) 	// output wire [31:0] sequence_sig
   );
   time i;
   time j;
   time idx;
   initial begin
        clock_sig = 0;
        generator_sequence_sig = 0;
        enable_sig = 0;
        load_sig = 0;
        enable_detector = 0;
        #1;
        enable_sig = 1;
//        sequence_sig = 32'b10010001;
        generator_sequence_sig = 32'b10101010;

        load_sig = 1;
        for (i=0; i < 40 + 4; i=i+1) begin
            if (i == 1) begin
                load_sig = 0;
                enable_detector = 1;

            end
            for (j=0; j < 36; j=j+1) begin
                #1;
                clock_sig = 1;
                #1;
                clock_sig = 0;
            end
        end
   end

   always @(posedge ready_sig) begin
      $display("The sequence id was specified correctly");
      $display("\tActual sequence\t0b%b", generator_sequence_sig);
      $display("\tDetected sequence\t0b%b", detector_sequence_out_sig);
      if (generator_sequence_sig != generator_sequence_sig)
         $display("ERROR: sequences do not match");
      $stop;
   end

   
   


endmodule