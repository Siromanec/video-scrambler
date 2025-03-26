module reseeder #(parameter SEQ_LEN = 16) (
        input clk,
        input [SEQ_LEN-1:0] external_sequence,
        input update,
    );


    input clk;
    input [255:0] entropy;
    input update;
    input reset_n;
    input next;
    output next_ready;
    output init_ready;
    output do_reseed;
    output [255:0] random_bits;
    wire sha_init;
    wire sha_reset_n;
    wire [511 : 0] sha_block;
    wire sha_ready;
    wire [255:0] sha_digest;
    wire sha_digest_valid;

    reg internal_sequence [SEQ_LEN-1:0];

    sha256_core sha256_core_0 (
        .clk(clk),
        .reset_n(sha_reset_n),
        .init(sha_init),
        .next(1'b0),
        .mode(MODE_SHA_256),
        .block(sha_block),
        .ready(sha_ready),
        .digest(sha_digest),
        .digest_valid(sha_digest_valid)
    );

    localparam MODE_SHA_256   = 1'h1;

    hash_drbg hash_drbg_slave (
        .entropy(entropy),
        .update(update),
        .reset_n(reset_n),
        .clk(clk),
        .next(next),
        .next_ready(next_ready),
        .init_ready(init_ready),
        .do_reseed(do_reseed),
        .random_bits(random_bits),
        .sha_init(sha_init),
        .sha_reset_n(sha_reset_n),
        .sha_block(sha_block),
        .sha_ready(sha_ready),
        .sha_digest(sha_digest),
        .sha_digest_valid(sha_digest_valid)
    );

    hash_drbg hash_drbg_master (
        .entropy(entropy),
        .update(update),
        .reset_n(reset_n),
        .clk(clk),
        .next(next),
        .next_ready(next_ready),
        .init_ready(init_ready),
        .do_reseed(do_reseed),
        .random_bits(random_bits),
        .sha_init(sha_init),
        .sha_reset_n(sha_reset_n),
        .sha_block(sha_block),
        .sha_ready(sha_ready),
        .sha_digest(sha_digest),
        .sha_digest_valid(sha_digest_valid)
    );

    reg internal_sequence_we;
    always @(posedge clk) begin
        if (update) begin
            if (internal_sequence_we) begin
                if (internal_sequence <= external_sequence) begin
                    internal_sequence <= internal_sequence + 1;
                end else begin
                    internal_sequence <= external_sequence;
                end
            end
        end
    end

    always @(internal_sequence) begin

    end

endmodule
