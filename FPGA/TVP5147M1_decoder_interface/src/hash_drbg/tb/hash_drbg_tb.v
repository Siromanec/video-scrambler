`timescale 10ns / 1ns
module hash_drgb_tb();

    localparam MODE_SHA_256   = 1'h1;

    reg clk;
    wire sha_init;
    wire sha_ready;
    wire sha_digest_valid;
    wire [255:0] sha_digest;
    wire [511 : 0] sha_block;


    reg [255:0] entropy;
    reg update;
    reg reset_n;
    reg next;
    wire do_reseed;
    wire [255:0] random_bits;
    wire init_ready;
    wire next_ready;
    wire sha_reset_n;
    wire sha_reset_n_common;
    reg sha_reset_n_internal;
    assign sha_reset_n_common = sha_reset_n_internal ? sha_reset_n_internal : sha_reset_n;
    sha256_core sha256_core_0 (
        .clk(clk),
        .reset_n(sha_reset_n),
        .init(sha_reset_n_common),
        .next(1'b0),
        .mode(MODE_SHA_256),
        .block(sha_block),
        .ready(sha_ready),
        .digest(sha_digest),
        .digest_valid(sha_digest_valid)
    );



    hash_drbg hash_drbg_0 (
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
    reg [7:0] generated_counter;
    always begin
        clk = 1'b0;
        #1;
        clk = 1'b1;
        #1;
    end
    initial begin
        entropy = 256'h0;
        update = 1'b0;
        reset_n = 1'b0;
        sha_reset_n_internal = 1'b0;
        next = 1'b0;
        generated_counter <= 8'h0;

        #10;
        sha_reset_n_internal = 1'b1;
        reset_n = 1'b1;
        #10;
        update = 1'b1;
    end
    always @(posedge init_ready) begin
        $display("init_ready");
        next = 1'b1;


    end

    always @(posedge next_ready) begin
        if (generated_counter < 10) begin
            generated_counter = generated_counter + 1;
            $display("next_ready, bits=0x%0h", random_bits[31:0]);

            next = 1'b0;
            #5
            next = 1'b1;



        end else begin
            next = 1'b0;
            $display("next_ready, bits=0x%0h", random_bits[31:0]);
            $display("next_ready, done");
            $stop;
        end


    end
endmodule