`timescale 1ns / 1ps

module delay_buffer_4clk_tb;

    parameter DATA_WIDTH = 10;
    reg clk;
    reg reset_n;
    reg [DATA_WIDTH-1:0] din;
    wire [DATA_WIDTH-1:0] dout;

    // Instantiate the DUT (Device Under Test)
    delay_buffer_4clk #(.DATA_WIDTH(DATA_WIDTH)) uut (
        .clk(clk),
        .reset_n(reset_n),
        .din(din),
        .dout(dout)
    );

    // Clock generation: 10ns period

    integer i;

    initial begin
        $display("Time\tclk\tdin\tdout");
        $monitor("%0t\t%b\t%d\t%d", $time / 100, clk, din, dout);

        // Initialize
        reset_n = 0;
        din = 0;
        clk = 0;
        #5
        clk = 0;
        #5
        clk = 1;


        // Hold reset low for a few cycles

        reset_n = 1;
        #5
        clk = 0;
        #5
        clk = 1;
        // Apply input stimulus
        for (i = 0; i < 12; i = i + 1) begin
            din = i;

            #5
            clk = 0;
            #5
            clk = 1;
        end

        // Stop simulation
        #20;
        $finish;
    end

endmodule
