`timescale 1ps / 1ps
// monitored signal copypaste
// sim:/sequence_generator_tb/sequence_generator_inst/shiftout_sig sim:/sequence_generator_tb/sequence_generator_inst/clk_div36 sim:/sequence_generator_tb/clock_sig sim:/sequence_generator_tb/sequence_sig sim:/sequence_generator_tb/enable_sig sim:/sequence_generator_tb/load_sig sim:/sequence_generator_tb/sequence_out_sig sim:/sequence_generator_tb/identifier_const_id sim:/sequence_generator_tb/i sim:/sequence_generator_tb/j sim:/sequence_generator_tb/idx sim:/sequence_generator_tb/val sim:/sequence_generator_tb/expected_val sim:/sequence_generator_tb/actual_val
module sequence_generator_tb;

    reg clock_sig;
    reg [31:0] sequence_sig;
    reg enable_sig;
    reg load_sig;
    wire [9:0] sequence_out_sig;
    wire [7:0] identifier_const_id;

    sequence_generator sequence_generator_inst
    (
        .clock(clock_sig) ,	// input  clock_sig
        .sequence(sequence_sig) ,	// input [31:0] sequence_sig
        .enable(enable_sig) ,	// input  enable_sig
        .load(load_sig) ,	// input  load_sig
        .sequence_out(sequence_out_sig) 	// output [9:0] sequence_out_sig
    );
    identifier_const identifier_const_inst
    (
        .id(identifier_const_id) 	// output wire [31:0] sequence_sig
    );
    time i;
    time j;
    time idx;
    reg val;
    reg [39:0] expected_val;
    reg [39:0] actual_val;
    initial begin
        clock_sig = 0;
        sequence_sig = 0;
        enable_sig = 0;
        load_sig = 0;
        #1;
        enable_sig = 1;
//        sequence_sig = 32'b10010001;
        sequence_sig = 32'b10101010;
        expected_val = {identifier_const_id, sequence_sig};

        load_sig = 1;



        for (i=0; i < 40; i=i+1) begin
            if (i == 1) begin
                load_sig = 0;
            end
            for (j=0; j < 36; j=j+1) begin
                #1;
                clock_sig = 1;
                #1;
                clock_sig = 0;

                if (j  == 17) begin
//                    $display("sequence_out_sig: %d", sequence_out_sig);
                      if (sequence_out_sig != 512) begin
                            if (sequence_out_sig < 512)
                                val = 0;
                            else
                                val = 1;
                      end
                      else begin
                        val = 1'bx;
                        $display("ERROR: encountered illegal value");
                      end
                end

            end
            idx = 39 - i;
            actual_val[idx] = val;
            if (val != expected_val[idx] || val == 1'bx) begin
                $display("Error at 0b%b: expected 0b%b, got 0b%b", idx, expected_val[idx], val);
//                $stop;
            end else begin
                $display("Success at %d: expected %d, got %d", idx, expected_val[idx], val);
            end

        end
        $display("Expected: 0b%b", expected_val);
        $display("Actual: 0b%b", actual_val);
        if (expected_val != actual_val) begin
            $display("ERROR:\n\texpected\t0b%b\n\tgot\t0b%b", expected_val, actual_val);
        end else begin
            $display("SUCCESS!");
        end
        $stop;
    end
endmodule