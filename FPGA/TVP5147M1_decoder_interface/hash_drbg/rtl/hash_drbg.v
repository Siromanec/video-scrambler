`include "../include/sha256_core.v"

module hash_drbg #(parameter SEEDLEN = 256,
                    parameter RESEED_INTERVAL = 60 * 625) (
    input [SEEDLEN-1:0] entropy,
    input update,
    input reset_n,

    input clk,
    input next,
    output next_ready,
    output init_ready,


    output do_reseed,
    output [255:0] random_bits,

    // ------------------------------------------------------------
    // SHA-256 core interface.
    // ------------------------------------------------------------
    output wire           sha_init,
    output wire [511 : 0] sha_block,

    input wire           sha_ready,
    input wire [255 : 0] sha_digest,
    input wire           sha_digest_valid
    );

    localparam  NBIT_SIZE = 64;
    localparam BLOCKSIZE = 512;
    localparam PERSONALIZATION_STRING_SIZE = BLOCKSIZE - SEEDLEN - NBIT_SIZE -1;
    localparam [PERSONALIZATION_STRING_SIZE-1:0] personalization_string = 256'h1E95B49C757C476AD85EA4A86FFD9;
    localparam [NBIT_SIZE-1:0] NBITS = SEEDLEN + PERSONALIZATION_STRING_SIZE;

    localparam PREPEND_SIZE = 8;
    localparam [NBIT_SIZE-1:0] NBITS_PREPEND = PREPEND_SIZE + SEEDLEN;
    localparam PREPEND_ZEROS_SIZE = BLOCKSIZE - NBITS_PREPEND - NBIT_SIZE -1;
    localparam [PREPEND_ZEROS_SIZE-1:0] PREPEND_ZEROS = 0;

    localparam PREPEND_INIT = 8'h00;
    localparam PREPEND_HASH = 8'h03;

    localparam DEFAULT_PAD_ZEROS_SIZE = BLOCKSIZE - SEEDLEN - NBIT_SIZE - 1;
    localparam [DEFAULT_PAD_ZEROS_SIZE-1:0] DEFAULT_ZEROS = 0;
    localparam NBITS_DEFAULT = SEEDLEN;

    wire seed_material [SEEDLEN-1:0];
    assign seed_material = {entropy, personalization_string, 1'b1, NBITS};

    reg [SEEDLEN-1:0] v;
    reg [SEEDLEN-1:0] c;

    localparam MODE_SHA_256   = 1'h1;


    reg [255:0] do_sha_digest;
    reg [511:0] do_sha_message;




    localparam  INIT_V_DONE = 0,
                INIT_C_DONE = 1;

    localparam GENERATE_RETURN_BITS_DONE = 0,
               GENERATE_UPDATE_H = 1,
               GENERATE_UPDATE_V = 2,
               GENERATE_UPDATE_CNT = 3;


    reg next_ready_new;
    reg init_ready_new;
    reg init_state;
    reg [1:0] generate_state;

    reg began_init;
    reg generate_next;
    reg [63:0] reseed_counter;

    reg [SEEDLEN-1:0] h;

    assign do_reseed = reseed_counter >= RESEED_INTERVAL;  // master will need to call reset, set new entropy and then call update

    assign init_ready = init_ready_new && !do_reseed;
    assign next_ready = next_ready_new && !do_reseed;

    reg do_sha_request;
    reg do_sha_began;

    always @* begin: do_sha

        if (do_sha_request) begin
            if (do_sha_began) begin
                sha_init <= 0;
                if (sha_digest_valid) begin
                    // set values
                    do_sha_digest <= sha_digest;
                    // reset internal state
                    do_sha_began <= 0;
                    // reset external state
                    do_sha_request <= 0;

                    // release the busses
                    sha_block <= 256'hz;
                    sha_init <= 1'bz;
                end
            end else begin // if (do_sha_began) begin
                if (sha_ready) begin
                    sha_block <= do_sha_message;
                    sha_init <= 1;
                    do_sha_began <= 1;
                end

            end // if (do_sha_began) begin
        end
    end

    always @ (posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // set working variables to 0
            v <= 0;
            c <= 0;
            h <= 0;
            // reset external state
            init_ready_new <= 0;
            next_ready_new <= 0;

            // reset do_sha
            do_sha_began <= 0;
            do_sha_request <= 0;
            // release the busses
            sha_block <= 256'hz;
            sha_init <= 1'bz;

            // reset internal state
            began_init <= 0;
            init_state <= INIT_V_DONE;
            generate_state <= GENERATE_RETURN_BITS_DONE;
            generate_next <= 0;

            reseed_counter <= 0;
        end else begin
            if (update && !began_init) begin
                began_init <= 1;
                // set the message for the next hash
                do_sha_message <= seed_material;
                // prepare control signals for do_sha
                do_sha_request <= 1;
            end else if (began_init) begin // if (update) begin

                if (!do_sha_request) begin // if not doing a request
                    case (init_state)
                        INIT_V_DONE: begin
                            // retrieve the the do_sha_digest
                            v <= do_sha_digest;
                            // set the message for the next hash
                            do_sha_message <= {PREPEND_INIT, v, 1'b1, PREPEND_ZEROS, NBITS_PREPEND};
                            // prepare control signals for do_sha
                            do_sha_request <= 1;
                            // set the next state
                            init_state <= INIT_C_DONE;
                        end
                        INIT_C_DONE: begin
                            // retrieve the the do_sha_digest
                            c <= do_sha_digest;
                            // indicate that the init is done
                            init_ready_new <= 1;
                            // reset the state
                            began_init <= 0;
                            init_state <= INIT_V_DONE; // skips INIT_IDLE because it is equivalent to began_init
                            // reset the reseed counter
                            do_reseed <= 0;
                            reseed_counter <= 1;
                        end
                    endcase // case (init_state)
                end // if (do_sha_end)
            end else if (init_ready && !generate_next && next) begin // if (update) begin
                // set the message for the next hash
                do_sha_message <= {v, DEFAULT_ZEROS, 1'b1, NBITS_DEFAULT};
                // prepare control signals for do_sha
                do_sha_request <= 1;
                // set the next state
                generate_next <= 1;
                // set external state
                next_ready_new <= 0;
            end else if (generate_next) begin // if (update) begin

                 if (!do_sha_request) begin // if not doing a request
                    case (generate_state)
                        GENERATE_RETURN_BITS_DONE: begin
                            // retrieve the the do_sha_digest
                            random_bits <= do_sha_digest;
                            // set the message for the next hash
                            do_sha_message <= {PREPEND_HASH, v, 1'b1, PREPEND_ZEROS, NBITS_PREPEND};
                            // prepare control signals for do_sha
                            do_sha_request <= 1;
                            // set the next state
                            generate_state <= GENERATE_UPDATE_V;
                        end // GENERATE_RETURN_BITS_DONE
                        GENERATE_UPDATE_V:
                            // retrieve the the do_sha_digest and use it as intermideate instead of h
                            v <= v + do_sha_digest + c + reseed_counter;
                        GENERATE_UPDATE_CNT: begin
                            reseed_counter <= reseed_counter + 1;
                            // reset state
                            generate_next <= 0;
                            // set external state
                            next_ready_new <= 1;
                        end
                    endcase // case (generate_state)
                 end // if (do_sha_end) else
            end // if (update) begin
        end // if (!reset_n) begin
    end // always @ (posedge clk or negedge reset_n) begin





endmodule