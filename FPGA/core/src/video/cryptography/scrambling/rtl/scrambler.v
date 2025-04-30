// `define DEBUG
module scrambler (
`ifdef DEBUG
    output wire [9:0] bt656_stream_in_delayed_out_debug,
    output wire [9:0] bt656_stream_switch_out_debug,
    output wire V_debug,
    output wire H_debug,
    output wire [7:0] raw_cut_position_out_debug,
    output wire SEQUENCE_GENERATOR_ENABLE_debug,
    output wire SEQUENCE_GENERATOR_LOAD_debug,
`endif
    (* keep = "true" *) input wire  mode,// 0: scrambler, 1: descrambler
    input wire clk,
    input wire reset_n,
    input wire [9:0] bt656_stream_in,
    input wire [255:0] seed,
    output wire [9:0] bt656_stream_out

);
   localparam MODE_SCRAMBLER = 0;
   localparam MODE_DESCRAMBLER = 1;



   /* 
   ----------------------------------------
      SYNC CONTROL
   ----------------------------------------
   */
   wire H;
   wire F;
   wire V;

   /* 
   ----------------------------------------
      DRBG IN WIRES
   ----------------------------------------
   */
   wire DRBG_GET_NEXT_BITS;
   wire DRBG_NEXT_SEED = V;

   /* 
   ----------------------------------------
      DRBG OUT WIRES
   ----------------------------------------
   */
   wire DRBG_BUSY;
   wire DRBG_INIT_READY;
   wire DRBG_NEXT_BITS_READY;
   wire [31:0] DRBG_RESEED_COUNTER;
   wire [255:0] DRBG_RANDOM_BITS;
   /* 
   ----------------------------------------
      SEQUENCE GENERATOR IN WIRES
   ----------------------------------------
   */
   wire SEQUENCE_GENERATOR_ENABLE;
   wire SEQUENCE_GENERATOR_LOAD;
   /* 
   ----------------------------------------
      SEQUENCE GENERATOR OUT WIRES
   ----------------------------------------
   */
   wire [9:0] SEQUENCE_GENERATOR_OUT;

   /* 
   ----------------------------------------
      SEQUENCE SWITCH OUT WIRES
   ----------------------------------------
   */
   wire [9:0] SWITCH_DATA_OUT;
   wire SWITCH_V;

   /* 
   ----------------------------------------
      SEQUENCE DETECTOR OUT WIRES
   ----------------------------------------
   */
   wire SEQUENCE_DETECTOR_SEQUENCE_EXTERAL_VALID;
   wire [31:0] SEQUENCE_DETECTOR_SEQUENCE_EXTERNAL;

   /* 
   ----------------------------------------
      DRBG SYNCHRONISATOR OUT WIRES
   ----------------------------------------
   */
   wire drbg_synchronizer_CATCH_UP_MODE;
   wire drbg_synchronizer_GET_NEXT_SEED;
   wire drbg_synchronizer_DRBG_RESET_N;
   wire drbg_synchronizer_BLOCK_DRBG_RESEED;

   /* 
   ----------------------------------------
      DRBG CONSUMER OUT WIRES
   ----------------------------------------
   */
   wire [7:0] CONSUMER_RAW_CUT_POSITION;

   /* 
   ----------------------------------------
      LINE ROTATOR OUT WIRES
   ----------------------------------------
   */
   wire [9:0] ROTATOR_DATA_OUT;
   wire ROTATOR_DATA_OUT_VALID;

   /* 
   ----------------------------------------
      MODULE OUTPUT
   ----------------------------------------
   */

   assign bt656_stream_out = ROTATOR_DATA_OUT_VALID ? ROTATOR_DATA_OUT : 0;


   /* 
   ----------------------------------------
      SYNC DETECTOR INSTANTIATION
      detects control signals H, V, F in bt656_stream_in
   ----------------------------------------
   */
   wire H_current;
   wire V_current;
   wire F_current;
   wire H_delayed;
   wire V_delayed;
   wire F_delayed;
   wire [9:0] bt656_stream_in_delayed;

   assign H = H_current | H_delayed;
   assign V = V_current;
   assign F = F_current;

`ifdef DEBUG
    assign bt656_stream_in_delayed_out_debug = bt656_stream_in_delayed;
    assign bt656_stream_switch_out_debug = SWITCH_DATA_OUT;
    assign V_debug = V;
    assign H_debug = H;
    assign raw_cut_position_out_debug = CONSUMER_RAW_CUT_POSITION;
    assign SEQUENCE_GENERATOR_ENABLE_debug = SEQUENCE_GENERATOR_ENABLE;
    assign SEQUENCE_GENERATOR_LOAD_debug = SEQUENCE_GENERATOR_LOAD;
`endif

   sync_parser sync_parser_current (
      .clk(clk),
      .reset_n(reset_n),
      .bt656(bt656_stream_in),
      .H(H_current),
      .V(V_current),
      .F(F_current)
   );

   delay_buffer_4clk #(.DATA_WIDTH(10)) delay_stream (
      .clk(clk),
      .reset_n(reset_n),
      .din(bt656_stream_in),
      .dout(bt656_stream_in_delayed)
   );
   sync_parser sync_parser_delayed (
      .clk(clk),
      .reset_n(reset_n),
      .bt656(bt656_stream_in_delayed),
      .H(H_delayed),
      .V(V_delayed),
      .F(F_delayed)
   );


   /* 
   ----------------------------------------
      DRBG INSTANTIATION
      generates random number DRBG_RANDOM_BITS
      V reseeds the drbg with new number from internal master drbg

   ----------------------------------------
   */
   hash_drbg_sha256 hash_drbg_sha256_0 (
      .reset_n(mode ? drbg_synchronizer_DRBG_RESET_N & reset_n : reset_n),
      .clk(clk),
      .next_seed(mode ?
                        ((drbg_synchronizer_GET_NEXT_SEED | DRBG_NEXT_SEED)
                           & !drbg_synchronizer_BLOCK_DRBG_RESEED)
                        :
                        DRBG_NEXT_SEED),
      .next_bits(DRBG_GET_NEXT_BITS),
      .entropy(seed),
      .init_ready(DRBG_INIT_READY),
      .next_bits_ready(DRBG_NEXT_BITS_READY),
      .random_bits(DRBG_RANDOM_BITS),
      .reseed_counter(DRBG_RESEED_COUNTER),
      .busy(DRBG_BUSY),
      .catch_up_mode(mode ? drbg_synchronizer_CATCH_UP_MODE : 1'b0)
   );

   /* 
   ----------------------------------------
      SEQUENCE MANAGEMENT
      This section is responsible for managing the sequence generator and detector,
      and synchronizing the DRBG on the descrambler side with the scrambler's DRBG.
   ----------------------------------------
   */

// generate

   // case (mode)
      // MODE_SCRAMBLER:  begin

         /* 
         ----------------------------------------
            SEQUENCE GENERATOR
            transforms DRBG_RESEED_COUNTER from a number to bt656 compatible stream SEQUENCE_GENERATOR_OUT
         ----------------------------------------
         */

         sequence_generator sequence_generator_inst (
            .clock(clk),  // input  clock_sig
            .reseed_count(DRBG_RESEED_COUNTER),  // input [31:0] sequence_sig
            .enable(mode ? 1'b0 : SEQUENCE_GENERATOR_ENABLE),  // input  enable_sig
            .load(SEQUENCE_GENERATOR_LOAD),  // input  load_sig
            .sequence_out(SEQUENCE_GENERATOR_OUT)  // output [9:0] sequence_out_sig
         );
         // Generated by Quartus Prime Version 23.1 (Build Build 993 05/14/2024)
         // Created on Thu Apr 10 19:26:15 2025
         /* 
         ----------------------------------------
            SEQUENCE GENERATOR SWITCH
            Inserts the bt656 compatible stream SEQUENCE_GENERATOR_OUT into bt656_stream_in_delayed 
            and outputs it as SWITCH_DATA_OUT that goes to LINE ROTATOR.

            Disables the line rotation of inserted SEQUENCE_GENERATOR_OUT via SWITCH_V.
         ----------------------------------------
         */
         sequence_generator_switch sequence_generator_switch_inst (
            .clk(clk),  // input  clk
            .reset_n(mode ? 1'b0 : reset_n),  // input  reset_n
            .H(H),  // input  H
            .V(V),  // input  V
            .bt656_stream_in(bt656_stream_in_delayed),  // input [9:0] bt656_stream_in_sig
            .sequence_in(SEQUENCE_GENERATOR_OUT),  // input [9:0] sequence_in_sig
            .bt656_stream_out(SWITCH_DATA_OUT),  // output [9:0] bt656_stream_out_sig
            .V_out(SWITCH_V),  // output  SWITCH_V
            .enable_generator(SEQUENCE_GENERATOR_ENABLE),  // output  SEQUENCE_GENERATOR_ENABLE
            .load_generator(SEQUENCE_GENERATOR_LOAD)  // output  SEQUENCE_GENERATOR_LOAD
         );
      // end
      // MODE_DESCRAMBLER: begin
         /* 
         ----------------------------------------
         SEQUENCE DETECTOR
         Detects external sequence inserted by SEQUENCE GENERATOR SWITCH and
         transforms it to 32-bit value SEQUENCE_DETECTOR_SEQUENCE_EXTERNAL
         ----------------------------------------
         */
         sequence_detector sequence_detector_inst (
            .clock(clk),  // input  clock_sig
            .sequence_in(bt656_stream_in),  // input [9:0] sequence_in_sig
            .reset_n(mode ? !H : 1'b0),  // input  reset_n_sig
            .sequence_out(SEQUENCE_DETECTOR_SEQUENCE_EXTERNAL),  // output [31:0] sequence_out_sig
            .ready(SEQUENCE_DETECTOR_SEQUENCE_EXTERAL_VALID)  // output  ready_sig
         );
         /* 
         ----------------------------------------
         DRBG SYNCHRONISATOR
         Synchronizes the DRBG with the external sequence inserted by SEQUENCE GENERATOR SWITCH

         If the external sequence bigger than the internal sequence (reseed counter),
         it will make DRBG catch up with it.

         If the external sequence smaller than the internal sequence, 
         but the difference is small it will stop the DRBG and
         wait for the external sequence to catch up.

         If the external sequence smaller than the internal sequence, 
         and the difference is big it will reset the DRBG and make the DRBG catch up with it.
         ----------------------------------------
         */
         drbg_synchronizer drbg_synchronizer0 (
            .clk(clk),
            .reset_n(mode ? reset_n : 1'b0),
            .init_done(DRBG_INIT_READY),
            .sequence_internal(DRBG_RESEED_COUNTER),
            .sequence_external(SEQUENCE_DETECTOR_SEQUENCE_EXTERNAL),
            .sequence_external_valid(SEQUENCE_DETECTOR_SEQUENCE_EXTERAL_VALID),
            .V(V),
            .catch_up_mode(drbg_synchronizer_CATCH_UP_MODE),
            .get_next_seed(drbg_synchronizer_GET_NEXT_SEED),
            .reset_n_drbg(drbg_synchronizer_DRBG_RESET_N),
            .block_drbg_reseed(drbg_synchronizer_BLOCK_DRBG_RESEED)
         );
      // end

   // endcase

// endgenerate


   /* 
   ----------------------------------------
      DRBG CONSUMER
      Transforms 256-bit vector DRBG_RANDOM_BITS into 32 8-bit values CONSUMER_RAW_CUT_POSITION
      and outputs each one @posedge H.
      
      When it runs out of values it queries DRBG with DRBG_GET_NEXT_BITS to get next 32 values.

      @posedge DRBG_NEXT_BITS_READY it writes the contents of the vector to internal storage every clock 
      until it is done


   ----------------------------------------
   */
   drbg_consumer drbg_consumer_inst (
      .H(H),  // input  H
      .V(V),  // input  V
      .clk(clk),  // input  clk
      .reset_n(reset_n),  // input  reset_n
      .data_in(DRBG_RANDOM_BITS),  // input [(DATA_WIDTH_IN-1):0] data_in_sig
      .data_in_valid(DRBG_NEXT_BITS_READY),  // input  data_in_valid_sig
      .generator_busy(DRBG_BUSY),
      .data_out(CONSUMER_RAW_CUT_POSITION),  // output [(DATA_WIDTH_OUT-1):0] data_out_sig
      .need_next(DRBG_GET_NEXT_BITS)  // output  need_next_sig
   );
   /* 
   ----------------------------------------
      LINE ROTATOR
      Performs the line rotation algorithm
      Delays the signal by the duration of the line
      Can be broken in O(n^2) time where n is the number of samples in the line,
      which is enough to deny real-time access, but not enough for long-term security.

   ----------------------------------------
   */
   line_rotator line_rotator_inst (
      .mode(mode),  // input  mode
      .clk(clk),  // input  clk
      .reset_n(reset_n),  // input  reset_n
      .data_in(mode ? bt656_stream_in_delayed : SWITCH_DATA_OUT),  // input [9:0] data_in_sig
      .raw_cut_position(CONSUMER_RAW_CUT_POSITION),  // input [7:0] raw_cut_position_sig
      .V(mode ? V : SWITCH_V),  // input  V
      .H(H),  // input  H
      .data_out(ROTATOR_DATA_OUT),  // output [9:0] data_out_sig
      .data_out_valid(ROTATOR_DATA_OUT_VALID)
   );

endmodule