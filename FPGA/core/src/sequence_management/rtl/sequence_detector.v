

module sequence_detector #(
   parameter BLACK_LEVEL   = 10'h040,
   parameter WHITE_LEVEL   = 10'h3AC,
   parameter TRIGGER_WIDTH = 10'h040
) (
   input             clock,
   input      [ 9:0] sequence_in,
   input             reset_n,
   output reg [31:0] sequence_out,
   output reg        ready
);


   localparam [5:0] TOTAL_BITS = 40;
   localparam [5:0] SAMPLES_PER_BIT = 2 * 720 / TOTAL_BITS;
   localparam [0:0] LOW = 0, HIGH = 1;
   localparam MIN_HOLD = SAMPLES_PER_BIT / 8;

   reg chroma_flag;
   reg current_value;
   reg shift_reg_clk;
   reg break;

   // counters
   reg [5:0] sample_counter;
   reg [5:0] held_for;
   reg [5:0] read_bits;

   wire [TOTAL_BITS-1:0] sequence_internal;

   sequence_shiftreg_in sequence_shiftreg_in_inst (
      .aclr(!reset_n),
      .clock(shift_reg_clk),
      .enable(reset_n | !break),
      .shiftin(current_value),
      .q(sequence_internal)
   );
   // id 
   wire [7:0] id;
   wire [TOTAL_BITS-1:0] id_mask;
   assign id_mask = {id[7:0], 32'b0};
   identifier_const idgen0 (.id(id));


   always @(negedge clock or negedge reset_n) begin
      if (!reset_n) begin
         chroma_flag <= 1;
      end else begin
         chroma_flag <= ~chroma_flag;
      end
   end

   // schmidt trigger
   always @(negedge chroma_flag or negedge reset_n) begin
      if (!reset_n) begin
         current_value = LOW;
      end else begin
         case (current_value)
            LOW: begin
               if (sequence_in > WHITE_LEVEL - TRIGGER_WIDTH) current_value <= HIGH;
            end
            HIGH: begin
               if (sequence_in < BLACK_LEVEL + TRIGGER_WIDTH) current_value <= LOW;
            end
         endcase
      end
   end

   reg current_value_prev;
   // counter and output management
   always @(posedge clock or negedge reset_n) begin
      if (!reset_n) begin
         sample_counter <= 0;
         read_bits <= 0;
         ready <= 0;
         shift_reg_clk <= 0;
         current_value_prev <= current_value;
         break <= 0;
         held_for <= 0;
      end else begin
         if (sample_counter == SAMPLES_PER_BIT - 1) begin
            sample_counter <= 0;
            shift_reg_clk  <= 0;
            current_value_prev <= current_value;
            held_for <= 0;
            if (read_bits == TOTAL_BITS - 1) begin
               read_bits <= 0;
               break <= 0;
               if (sequence_internal[39:32] == id_mask) begin  // assert that it is not some random signal
                  ready <= 1;
                  sequence_out <= sequence_internal[31:0];
               end else begin
                  ready <= 0;
               end
            end else begin
               read_bits <= read_bits + 1;
            end
         end else begin
            if (sample_counter == SAMPLES_PER_BIT / 2 - 1) begin
               shift_reg_clk <= 1;  // sample at half point when everything should be settled
               if (held_for < MIN_HOLD) begin
                  // break if value did not hold
                  break <= 1;
               end
            end
            if (current_value_prev == current_value) begin
               held_for <= held_for + 1;
            end else begin
               held_for <= 0;
            end

            current_value_prev <= current_value;
            sample_counter <= sample_counter + 1;
         end
      end
   end




endmodule
