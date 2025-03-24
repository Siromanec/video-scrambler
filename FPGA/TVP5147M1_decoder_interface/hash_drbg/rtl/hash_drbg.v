

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
    output reg [255:0] random_bits,

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

    wire [BLOCKSIZE-1:0] seed_material;
    assign seed_material = {BLOCKSIZE-1{entropy, personalization_string, 1'b1, NBITS}};

    reg [SEEDLEN-1:0] v;
    reg [SEEDLEN-1:0] c;



    reg [255:0] do_sha_digest;
    reg [511:0] do_sha_message;






    localparam GENERATE_IDLE = 0,
               GENERATE_RETURN_BITS_DONE = 1,
               GENERATE_UPDATE_V = 2,
               GENERATE_UPDATE_CNT = 3;


    reg next_ready_new;
    reg init_ready_new;
    localparam  INIT_IDLE = 0,
                INIT_V_DONE = 1,
                INIT_C_DONE = 2;
    reg [1:0] init_state;
    reg [1:0] generate_state;

    reg begin_init;
    reg generate_next;
    reg [63:0] reseed_counter;


    assign do_reseed = reseed_counter >= RESEED_INTERVAL;  // master will need to call reset, set new entropy and then call update

    assign init_ready = init_ready_new && !do_reseed;
    assign next_ready = next_ready_new && !do_reseed;

    reg do_sha_request;

    // ------------------------------------------------------------
    // SHA-256 core interface.
    // ------------------------------------------------------------
    reg do_sha_need_init_flag;
    reg accuire_sha_bus;
    reg do_sha_reset_n_flag;
    assign sha_block = accuire_sha_bus ? do_sha_message : 512'hz; // why would i ever release the bus if i am curenntly using it? (why i removed sha_ready). okay someone else may be using it
    assign sha_init = accuire_sha_bus ? do_sha_need_init_flag : 1'bz;
    assign sha_reset_n = do_sha_reset_n_flag;
    localparam SHA_IDLE = 0,
               SHA_INIT = 1,
               SHA_WAIT = 2,
               SHA_RELEASE = 3;
    reg [1:0] do_sha_state;

    always @(posedge clk or negedge reset_n or posedge do_sha_request or posedge sha_digest_valid) begin: do_sha
        if (!reset_n) begin
            // reset do_sha
            do_sha_state <= SHA_IDLE;
            do_sha_request <= 0;
            do_sha_need_init_flag <= 0;
            accuire_sha_bus <= 0;
            do_sha_reset_n_flag <= 1'b0;
        end else if (do_sha_request) begin
            case (do_sha_state)
                SHA_IDLE: begin
                    if (sha_ready && !accuire_sha_bus && !sha_digest_valid) begin
                        do_sha_state <= SHA_WAIT;
                        do_sha_reset_n_flag <= 1;
                        do_sha_need_init_flag <= 1;
                        accuire_sha_bus <= 1;
                    end
                end // SHA_IDLE
                SHA_INIT: begin
                    do_sha_need_init_flag <= 0;
                    do_sha_state <= SHA_WAIT;
                end // SHA_INIT
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
                        $display("hash=0x%0h", sha_digest[31:0]);

                    end  // if (sha_digest_valid) begin
                end // SHA_WAIT

            endcase
        end

    end

    // ------------------------------------------------------------
    // function selection/ dispatch
    // ------------------------------------------------------------

    always @ (posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // set working variables to 0
            v <= 0;
            c <= 0;
            reseed_counter <= 0;
        end else begin
            if (update && !begin_init && !do_sha_request) begin
                // set the message for the next hash
                do_sha_message <= seed_material;
                // prepare control signals for do_sha
                do_sha_request <= 1;
                // set external state
                init_ready_new <= 0;
                // set the next state
                begin_init <= 1;
                init_state <= INIT_V_DONE;
            end else if (init_ready && !generate_next && next && !do_sha_request) begin // if (update) begin
                // set the message for the next hash
                do_sha_message <= {v, DEFAULT_ZEROS, 1'b1, NBITS_DEFAULT};
                // prepare control signals for do_sha
                do_sha_request <= 1;
                // set external state
                next_ready_new <= 0;
                // set the next state
                generate_next <= 1;
                generate_state <= GENERATE_RETURN_BITS_DONE;

            end // if (update) begin
        end // if (!reset_n) begin
    end // always @ (posedge clk or negedge reset_n) begin
    
    
    // ------------------------------------------------------------
    // init fsm
    // ------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin: do_init
        if (!reset_n) begin
            // reset external state
            init_ready_new <= 0;

            // reset internal state
            begin_init <= 0;
            init_state <= INIT_IDLE;
        end else if (begin_init && !do_sha_request && !init_ready) begin // if began init and not doing a request
                case (init_state)
                    INIT_V_DONE: begin
                        // retrieve the the do_sha_digest
                        v <= do_sha_digest;
                        // set the message for the next hash
                        do_sha_message <= {PREPEND_INIT, do_sha_digest, 1'b1, PREPEND_ZEROS, NBITS_PREPEND};
                        // prepare control signals for do_sha
                        do_sha_request <= 1;
                        // set the next state
                        init_state <= INIT_C_DONE;

                        $display("init_v=0x%0h", do_sha_digest[31:0]);
                    end
                    INIT_C_DONE: begin
                        // retrieve the the do_sha_digest
                        c <= do_sha_digest;
                        // indicate that the init is done
                        init_ready_new <= 1;
                        // reset the state
                        begin_init <= 0;
                        init_state <= INIT_IDLE; // skips INIT_IDLE because it is equivalent to begin_init
                        // reset the reseed counter
                        reseed_counter <= 1;

                        $display("init_c=0x%0h", do_sha_digest[31:0]);
                    end
                endcase // case (init_state)
        end // if began init and not doing a request
    end

    // ------------------------------------------------------------
    // generate fsm
    // ------------------------------------------------------------
    always @(posedge clk or negedge reset_n) begin: do_next
        if (!reset_n) begin
            // reset external state
            next_ready_new <= 0;
            // reset internal state
            generate_next <= 0;
            generate_state <= GENERATE_IDLE;
        end else if (generate_next && !do_sha_request && !next_ready) begin  // if generating next and not doing a request
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
                    $display("old_v=0x%0h", v[31:0]);
                end // GENERATE_RETURN_BITS_DONE
                GENERATE_UPDATE_V: begin
                    // retrieve the the do_sha_digest and use it as intermideate instead of h
                    v <= v + do_sha_digest + c + reseed_counter;
                    generate_state <= GENERATE_UPDATE_CNT;
                end // GENERATE_UPDATE_V
                GENERATE_UPDATE_CNT: begin
                    $display("new_v=0x%0h", v[31:0]);
                    reseed_counter <= reseed_counter + 1;
                    // reset state
                    generate_next <= 0;
                    // set external state
                    next_ready_new <= 1;
                    generate_state <= GENERATE_IDLE;
                end // GENERATE_UPDATE_CNT
            endcase // case (generate_state)
        end // if generating next and not doing a request
    end




endmodule