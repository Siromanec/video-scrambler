// `define DEBUG;

module hash_drbg #(
   parameter SEEDLEN = 256,
   parameter RESEED_INTERVAL = 2 ** 32
) (
   input [SEEDLEN-1:0] entropy,
   input reset_n,

   input clk,
   input next,
   input wire reseed,
   output reg next_ready,
   output reg init_ready,


   output reg [255:0] random_bits,
   output wire [31:0] reseed_counter_out,
   output wire busy,

   // ------------------------------------------------------------
   // SHA-256 core interface.
   // ------------------------------------------------------------
   output wire           sha_init,
   output wire           sha_reset_n,
   output wire [511 : 0] sha_block,

   input wire           sha_ready,
   input wire [255 : 0] sha_digest,
   input wire           sha_digest_valid
);

   localparam NBIT_SIZE = 64;
   localparam BLOCKSIZE = 512;

   localparam PERSONALIZATION_STRING_SIZE = BLOCKSIZE - SEEDLEN - NBIT_SIZE - 1;
   localparam [PERSONALIZATION_STRING_SIZE-1:0] personalization_string = 256'h1E95B49C757C476AD85EA4A86FFD9;
   localparam [NBIT_SIZE-1:0] NBITS = SEEDLEN + PERSONALIZATION_STRING_SIZE;

   localparam PREPEND_SIZE = 8;
   localparam [NBIT_SIZE-1:0] NBITS_PREPEND = PREPEND_SIZE + SEEDLEN;
   localparam PREPEND_ZEROS_SIZE = BLOCKSIZE - NBITS_PREPEND - NBIT_SIZE - 1;
   localparam [PREPEND_ZEROS_SIZE-1:0] PREPEND_ZEROS = 0;

   localparam PREPEND_INIT = 8'h00;
   localparam PREPEND_HASH = 8'h03;

   localparam DEFAULT_PAD_ZEROS_SIZE = BLOCKSIZE - SEEDLEN - NBIT_SIZE - 1;
   localparam [DEFAULT_PAD_ZEROS_SIZE-1:0] DEFAULT_ZEROS = 0;
   localparam NBITS_DEFAULT = SEEDLEN;

   wire [BLOCKSIZE-1:0] seed_material;
   assign seed_material = {entropy, personalization_string, 1'b1, NBITS};

   reg [SEEDLEN-1:0] v;
   reg [SEEDLEN-1:0] c;



   reg [255:0] do_sha_digest;
   // reg [511:0] do_sha_message;







   localparam INIT_IDLE = 0, INIT_V_DONE = 1, INIT_C_DONE = 2;
   reg [1:0] init_state;

   reg generate_next;
   reg [31:0] reseed_counter;

   assign reseed_counter_out = reseed_counter;





   reg do_sha_request;

   // ------------------------------------------------------------
   // SHA-256 core interface and fsm
   // ------------------------------------------------------------
   reg do_sha_need_init_flag;
   reg accuire_sha_bus;
   reg do_sha_reset_n_flag;
   assign sha_block = accuire_sha_bus ? select_sha_message(sha_message_select) : 512'hz; // why would i ever release the bus if i am curenntly using it? (why i removed sha_ready). okay someone else may be using it
   assign sha_init = accuire_sha_bus ? do_sha_need_init_flag : 1'bz;
   assign sha_reset_n = do_sha_reset_n_flag;
   localparam SHA_IDLE = 0, SHA_INIT = 1, SHA_WAIT = 2, SHA_RELEASE = 3;
   reg [1:0] do_sha_state;
   integer data_cnt;
   reg reseeding;

   localparam SHA_MESSAGE_NONE = 0,
              SHA_MESSAGE_INIT = 1,
              SHA_MESSAGE_RANDOM_BITS = 2,
              SHA_MESSAGE_RESEED = 3,
              SHA_MESSAGE_SEED = 4;
   
   reg [$clog2(5)-1:0] sha_message_select;

   function [511:0] select_sha_message(input [$clog2(5)-1:0] select);
      case (select)
         SHA_MESSAGE_SEED: begin
            select_sha_message = seed_material;
         end
         SHA_MESSAGE_NONE: begin
            select_sha_message = 512'hz;
         end
         SHA_MESSAGE_INIT: begin
            select_sha_message = {PREPEND_INIT, do_sha_digest, 1'b1, PREPEND_ZEROS, NBITS_PREPEND};
         end
         SHA_MESSAGE_RANDOM_BITS: begin
            select_sha_message = {v + data_cnt, DEFAULT_ZEROS, 1'b1, NBITS_DEFAULT};
         end
         SHA_MESSAGE_RESEED: begin
            select_sha_message = {PREPEND_HASH, v, 1'b1, PREPEND_ZEROS, NBITS_PREPEND};
         end
      endcase
   endfunction

   // wire [511:0] init_sha_message = {PREPEND_INIT, do_sha_digest, 1'b1, PREPEND_ZEROS, NBITS_PREPEND};
   // wire [511:0] random_bits_sha_message = {v, DEFAULT_ZEROS, 1'b1, NBITS_DEFAULT};
   // wire [511:0] reseed_sha_message = {PREPEND_HASH, v, 1'b1, PREPEND_ZEROS, NBITS_PREPEND};



   task do_sha;
      begin
         case (do_sha_state)
            SHA_IDLE: begin
               if (sha_ready && !accuire_sha_bus && !sha_digest_valid) begin
                  do_sha_state <= SHA_WAIT;
                  do_sha_reset_n_flag <= 1;
                  do_sha_need_init_flag <= 1;
                  accuire_sha_bus <= 1;
               end
            end  // SHA_IDLE
            SHA_WAIT: begin
               if (sha_digest_valid && accuire_sha_bus) begin
                  // set values
                  do_sha_digest <= sha_digest;
                  // reset internal state
                  do_sha_need_init_flag <= 0;
                  // reset external state
                  do_sha_request <= 0;
                  // release the bus
                  accuire_sha_bus <= 0;
                  do_sha_reset_n_flag <= 0;

                  do_sha_state <= SHA_IDLE;
`ifdef DEBUG
                  $display("   hash=0x%0h", sha_digest[31:0]);
`endif
               end  // if (sha_digest_valid) begin
            end  // SHA_WAIT

         endcase
      end
   endtask

   // ------------------------------------------------------------
   // init fsm
   // ------------------------------------------------------------
   task do_init;
      begin
         case (init_state)
            INIT_V_DONE: begin
               // retrieve the the do_sha_digest
               v <= do_sha_digest;
               // set the message for the next hash
               // do_sha_message <= {PREPEND_INIT, do_sha_digest, 1'b1, PREPEND_ZEROS, NBITS_PREPEND};
               sha_message_select <= SHA_MESSAGE_INIT;
               // prepare control signals for do_sha
               do_sha_request <= 1;
               // set the next state
               init_state <= INIT_C_DONE;
`ifdef DEBUG
               $display("init_v=0x%0h", do_sha_digest[31:0]);
`endif
            end
            INIT_C_DONE: begin
               // retrieve the the do_sha_digest
               c <= do_sha_digest;
               // indicate that the init is done
               init_ready <= 1;
               // reset the state
               init_state <= INIT_IDLE;
               // reset the reseed counter
               reseed_counter <= 0;
`ifdef DEBUG
               $display("init_c=0x%0h", do_sha_digest[31:0]);
`endif
            end
         endcase  // case (init_state)
      end  // if began init and not doing a request
   endtask





   // ------------------------------------------------------------
   // function selection/ dispatch
   // ------------------------------------------------------------
   assign busy =  generate_next | !init_ready | reseeding;
   always @(posedge clk or negedge reset_n) begin
      if (!reset_n) begin
         // reset do_sha
         do_sha_state <= SHA_IDLE;
         do_sha_need_init_flag <= 0;
         accuire_sha_bus <= 0;
         do_sha_reset_n_flag <= 1'b0;
         sha_message_select <= SHA_MESSAGE_SEED;

         // set working variables to 0
         v <= 0;
         c <= 0;
         reseed_counter <= 0;

         // reset internal state
         generate_next <= 0;
         data_cnt <= 0;
         // set the message for the next hash
         // do_sha_message <= seed_material;
         // prepare control signals for do_sha
         do_sha_request <= 1;
         // set external state
         init_ready <= 0;
         next_ready <= 0;
         // set the next state
         init_state <= INIT_V_DONE;
         reseeding <= 0;

      end else begin
         if (do_sha_request) begin
             // while sha is perforing it is stuck here and gives control to the rest of the logic only when sha is done
            do_sha;
         end else if (!init_ready) begin
            do_init;
         end else if (!reseeding && reseed) begin
            // do_sha_message <= {PREPEND_HASH, v, 1'b1, PREPEND_ZEROS, NBITS_PREPEND};
            sha_message_select <= SHA_MESSAGE_RESEED;
            // prepare control signals for do_sha
            do_sha_request <= 1;
            // set the next state
            reseeding <= 1;
            reseed_counter <= reseed_counter + 1;
            data_cnt <= 0;
         end else if (reseeding) begin
            // do reseed
               // retrieve the the do_sha_digest and use it as intermideate instead of h
            v <= v + do_sha_digest + c + reseed_counter;
`ifdef DEBUG
            $display("new_v=0x%0h", v[31:0]);
`endif
            // reset state
            reseeding <= 0;
            // set external state
         end else if (!generate_next && next) begin 
            // set the message for the next hash
            // do_sha_message <= {v, DEFAULT_ZEROS, 1'b1, NBITS_DEFAULT};
            sha_message_select <= SHA_MESSAGE_RANDOM_BITS;
            // prepare control signals for do_sha
            do_sha_request <= 1;
            // set external state
            next_ready <= 0;
            // set the next state
            generate_next <= 1;

         end else if (generate_next) begin  // if generating next and not doing a request
            // do_next;
            // retrieve the the do_sha_digest
            random_bits <= do_sha_digest;
            // set the message for the next hash
            // set the next state
            next_ready <= 1;
            generate_next <= 0;
            data_cnt <= data_cnt + 1;

`ifdef DEBUG
            $display("old_v=0x%0h", v[31:0]);
`endif
         end

      end
   end  // always @ (posedge clk or negedge reset_n) begin

endmodule
