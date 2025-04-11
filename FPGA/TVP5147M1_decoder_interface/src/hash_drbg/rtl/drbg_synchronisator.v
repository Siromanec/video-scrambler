module drbg_synchronisator (
   input wire clk,
   input wire reset_n,

   input wire init_done,

   input wire [31:0] sequence_internal,
   input wire [31:0] sequence_external,
   input wire sequence_external_valid,
   input wire V,

   output reg catch_up_mode,
   output reg get_next_seed,
   output reg do_init,

   output wire reset_n_drbg,
   output reg  block_drbg_reseed
);

   //   localparam RESEED_EXECUTTION_TIME = 139;
   //   localparam ACTIVE_LINES = 480;
   //   localparam SAMPLES_BEFORE_RESEED = 
   //   localparam MAX_ALLOWED_LEADING_RESEED = 139;
   localparam MAX_ALLOWED_INTERNAL_LEADING_RESEED = 60;
   reg [31:0] sequence_external_store;
   reg allow_compare;
   reg sequence_external_valid_prev;
   reg reset_n_drbg_command;
   wire sequence_external_valid_rise = !sequence_external_valid_prev & sequence_external_valid;
   wire sequence_external_valid_fall = sequence_external_valid_prev & !sequence_external_valid;
   assign reset_n_drbg = reset_n & reset_n_drbg_command;


   localparam SYNC_STATE_IDLE = 0,
              SYNC_STATE_CATCH_UP = 1,
              SYNC_STATE_RESET = 2,
              SYNC_STATE_RESET_DO_INIT = 3,
              SYNC_STATE_WAIT = 4;

   reg [$clog2(5) - 1:0] sync_state;

   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         sequence_external_store <= 0;
         allow_compare <= 0;
         reset_n_drbg_command <= 1;
         do_init <= 0;
         sync_state <= SYNC_STATE_IDLE;
         catch_up_mode <= 0;
         get_next_seed <= 0;
         block_drbg_reseed <= 0;
         sequence_external_valid_prev <= 0;

      end else begin
         sequence_external_valid_prev <= sequence_external_valid
         if (allow_compare) begin
            if (sequence_internal < sequence_external_store) begin
               sync_state <= SYNC_STATE_CATCH_UP;
            end else if (sequence_internal > sequence_external_store) begin
               if (sequence_internal - sequence_external_store > MAX_ALLOWED_INTERNAL_LEADING_RESEED) begin
                  // reset drbg
                  sync_state <= SYNC_STATE_RESET;
               end else begin
                  // wait and do not increment drbg 
                  // lets hope it never happens
                  sync_state <= SYNC_STATE_WAIT;
               end
            end
            allow_compare <= 0;
         end else if (sequence_external_valid_rise) begin
            sequence_external_store <= sequence_external;
            allow_compare <= 1;
         end else begin
            case (sync_state)
               SYNC_STATE_IDLE: begin
               end
               SYNC_STATE_CATCH_UP: begin

                  if (((sequence_internal == sequence_external_store) && V) || 
                      ((sequence_internal == sequence_external_store - 1) && !V)) begin // next iteration will update on its own
                     catch_up_mode <= 0;
                     get_next_seed <= 0;
                     sync_state <= SYNC_STATE_IDLE;
                  end else begin
                     catch_up_mode <= 1;
                     get_next_seed <= 1;
                  end
               end
               SYNC_STATE_RESET: begin
                  reset_n_drbg_command <= 0;  // it also needs to do init and all that stuff
                  sync_state <= SYNC_STATE_RESET_DO_INIT;
               end
               SYNC_STATE_RESET_DO_INIT: begin
                  if (init_done) begin
                     sync_state <= SYNC_STATE_IDLE;
                     do_init <= 0;
                  end else begin
                     reset_n_drbg_command <= 1;
                     do_init <= 1;
                  end
               end
               SYNC_STATE_WAIT: begin
                  if (((sequence_internal == sequence_external_store) && V) || 
                      ((sequence_internal == sequence_external_store - 1) && !V)) begin // next iteration will update on its own
                     get_next_seed <= 0;
                     sync_state <= SYNC_STATE_IDLE;
                  end else begin
                     block_drbg_reseed <= 0;
                  end
               end

            endcase
         end
      end
   end

endmodule
