module hash_drgb_tb();

    localparam MODE_SHA_256   = 1'h1;

    reg clk;
    reg sha_init;
    reg sha_ready;
    reg sha_digest_valid;
    reg [255:0] sha_digest;
    reg [511 : 0] sha_block;

    sha256_core sha256_core_0 (
        .clk(clk),
        .reset_n(1'b1),
        .init(sha_init),
        .next(1'b0),
        .mode(MODE_SHA_256),
        .block(sha_block),
        .ready(sha_ready),
        .digest(sha_digest),
        .digest_valid(sha_digest_valid)
    );

    reg [255:0] entropy;
    reg update;
    reg reset_n;
    reg next;
    wire do_reseed;
    wire [255:0] random_bits;

    hash_drbg hash_drbg_0 (
        .entropy(entropy),
        .update(update),
        .reset_n(reset_n),
        .clk(clk),
        .next(next),
        .do_reseed(do_reseed),
        .random_bits(random_bits),


        .sha_init(sha_init),
        .sha_block(sha_block),
        .sha_ready(sha_ready),
        .sha_digest(sha_digest),
        .sha_digest_valid(sha_digest_valid)
    );

    always begin
        clk = 1'b0;
        #5;
        clk = 1'b1;
        #5;
    end
    initial begin
        entropy = 256'h0;
        update = 1'b0;
        reset_n = 1'b0;
        next = 1'b0;
    end
    always begin
        #10;
        reset_n = 1'b1;
        #10;
        update = 1'b1;
        #10;
        update = 1'b0;
        #10;
        next = 1'b1;
        #10;
        next = 1'b0;
        #10;

        $finish;
    end
endmodule