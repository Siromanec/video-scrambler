module drbg_synchronisator_tb;

    // Parameters
    parameter CLK_PERIOD = 10;
   integer i;
    // Inputs
    reg clk;
    reg reset_n;
    wire init_done;
    reg [31:0] sequence_external;
    reg sequence_external_valid;
    reg V;

    // Outputs
    wire reset_n_drbg;
    wire catch_up_mode;
    reg catch_up_mode_tb_ctrl;
    wire get_next_seed;
    reg need_next;
    wire block_drbg_reseed;
   wire [63:0] reseed_counter;
   wire [255:0] random_bits;
    // Instantiate the Unit Under Test (UUT)
    drbg_synchronisator drbg_synchronisator0 (
        .clk(clk),
        .reset_n(reset_n),
        .init_done(init_done),
        .sequence_internal(reseed_counter[31:0]),
        .sequence_external(sequence_external),
        .sequence_external_valid(sequence_external_valid),
        .V(V),
        .catch_up_mode(catch_up_mode),
        .get_next_seed(get_next_seed),
        .reset_n_drbg(reset_n_drbg),
        .block_drbg_reseed(block_drbg_reseed)
    );


   master_hash_slave_hash_drbg master_hash_slave_hash_drbg_0 (
      .is_master_mode(1'b0),
      .reset_n(reset_n_drbg),
      .clk(clk),
      .next_seed((get_next_seed | need_next) & !block_drbg_reseed),
      .next_bits(1'b0),
      .entropy(256'b0),
      .init_ready(init_done),
      .reseed_counter(reseed_counter),
      .catch_up_mode(catch_up_mode | catch_up_mode_tb_ctrl)
   );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize inputs
        reset_n = 0;
        sequence_external = 0;
        sequence_external_valid = 0;
        V = 0;

        // Apply reset
        #(CLK_PERIOD * 2);
        reset_n = 1;

        // Wait for reseed_counter to stabilize
        #(CLK_PERIOD * 2);
         need_next = 1;
         catch_up_mode_tb_ctrl = 1;
        while (reseed_counter[31:0] != 10) begin
          #(CLK_PERIOD);
        end
        catch_up_mode_tb_ctrl = 0;
        need_next = 0;

        // Test case 1: Catch-up mode (sequence_internal < sequence_external)
        sequence_external = reseed_counter + 10; // Ensure external is smaller
        sequence_external_valid = 1;
        V = 1;
        #(CLK_PERIOD);
        sequence_external_valid = 0;

        // Wait until sequences match
        while (reseed_counter[31:0] != sequence_external - 1) begin
            #(CLK_PERIOD);
        end
        $display("TC1A Success: Reseed counter incremented as expected.");
        #(CLK_PERIOD * 10);
                // Test case 1: Catch-up mode (sequence_internal < sequence_external)
        sequence_external = reseed_counter + 10; // Ensure external is smaller
        sequence_external_valid = 1;
        V = 0;
        #(CLK_PERIOD);
        sequence_external_valid = 0;

        // Wait until sequences match
        while (reseed_counter[31:0] != sequence_external) begin
            #(CLK_PERIOD);
        end

        #(CLK_PERIOD * 10);
                // Test case 1: Catch-up mode (sequence_internal < sequence_external)
        sequence_external = reseed_counter + 60; // Ensure external is smaller
        sequence_external_valid = 1;
        #(CLK_PERIOD);
        sequence_external_valid = 0;

        // Wait until sequences match
        while (reseed_counter[31:0] != sequence_external) begin
            #(CLK_PERIOD);
        end
        $display("TC1B Success: Reseed counter incremented as expected.");
        #(CLK_PERIOD * 10);

        // Test case 2a: Small difference (sequence_internal > sequence_external)
         // the reseed counter should not be incremented despite the calls for next_seed

        sequence_external = reseed_counter - 1; // Small difference
        sequence_external_valid = 1;
        #(CLK_PERIOD);
        sequence_external_valid = 0;
         need_next = 1;
         for (i = 0; i < 500; i = i + 1) begin
            #(CLK_PERIOD);
            need_next = ~need_next;
         end
         need_next = 0;
        #(CLK_PERIOD );
         // difference restored
         if (sequence_external != reseed_counter - 1) begin
            $display("TC2A.1 Error: Reseed counter should not be incremented.");
            $stop;
         end else begin
            $display("TC2A.1 Success: Reseed counter not incremented as expected.");
         end
         
        sequence_external = reseed_counter; 
        sequence_external_valid = 1;
        #(CLK_PERIOD);
        sequence_external_valid = 0;
        #(CLK_PERIOD * 150);
         if (sequence_external != reseed_counter) begin
            $display("TC2A.2 Error: Reseed counter should be incremented.");
            $stop;
         end else begin
            $display("TC2A.2 Success: Incremented as expected.");
         end

        // Test case 2b: Large difference (sequence_internal > sequence_external)
        // internal sequence is reset and incremented until they match
        sequence_external = reseed_counter - 61; // Large difference
        sequence_external_valid = 1;
        #(CLK_PERIOD);
        sequence_external_valid = 0;

        // Wait until sequences match
        while (reseed_counter[31:0] != sequence_external) begin
            #(CLK_PERIOD);
        end
        $display("TC2B Success: Reseed counter incremented as expected.");
        #(CLK_PERIOD * 10);

        // Test case 3: External value equals internal value
        sequence_external = reseed_counter; // Match internal value
        sequence_external_valid = 1;
        #(CLK_PERIOD);
        sequence_external_valid = 0;

        // Wait until sequences match
        while (reseed_counter[31:0] != sequence_external) begin
            #(CLK_PERIOD);
        end
        $display("TC3 Success: Reseed counter incremented as expected.");
        #(CLK_PERIOD * 10);

        // Test case 4: Reset and reinitialize
        reset_n = 0;
        #(CLK_PERIOD * 2);
        reset_n = 1;
        sequence_external = 0;
        sequence_external_valid = 0;
        #(CLK_PERIOD * 10);

        // Finish simulation
        $stop;
    end

    // Monitor outputs
    initial begin
        $monitor("Time: %0t | reset_n: %b | init_done: %b | reseed_counter: %d | sequence_external: %d | sequence_external_valid: %b | V: %b | catch_up_mode: %b | get_next_seed: %b | reset_n_drbg: %b | block_drbg_reseed: %b",
                 $time, reset_n, init_done, reseed_counter, sequence_external, sequence_external_valid, V, catch_up_mode, get_next_seed, reset_n_drbg, block_drbg_reseed);
    end

endmodule