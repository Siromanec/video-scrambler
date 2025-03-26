`default_nettype none

module posedge_to_pulse #(parameter WIDTH=1) (
    input wire clk,
    input wire [WIDTH-1:0] signal_in,  // Level-based input
    input wire reset_n,  // Active-low reset
    output wire pulse_out   // Single-clock pulse output
);

    reg [WIDTH-1:0] signal_d;  // Delayed version of input signal
	reg [WIDTH-1:0] mult_pulse_out;
	
	assign pulse_out = |mult_pulse_out;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            mult_pulse_out <= 0;
            signal_d <= 0;
        end else begin
		    mult_pulse_out <= signal_in & ~signal_d; // Detect rising edge
		    signal_d  <= signal_in;  // Store previous state
		end
    end

endmodule