`define DEBUG
module line_rotator #(parameter MODE = 0)(
    input wire clk,
    input wire reset_n,
    input wire [9:0] data_in,
    input wire [7:0] raw_cut_position,
    input wire V,
    input wire H,
    output reg [9:0] data_out,
    output reg data_valid
);
    localparam ACTIVE_LINE_SIZE = 2 * 720;
    localparam MAX_BUFFER_SIZE = 2048;
    localparam ADDRESS_BITS = 11;
	 localparam MODE_SCRAMBLER = 0,
				   MODE_DESCRAMBLER = 1;

	// TODO: add data valid flag
    reg [9:0] line_buffer [0:1][0:MAX_BUFFER_SIZE-1];

    wire [ADDRESS_BITS-1:0] cut_position_wire;
    reg [ADDRESS_BITS-1:0] cut_position;


    cut_position_interpolator cut_position_interpolator_inst(
               .raw_cut_position(raw_cut_position),
               .cut_position(cut_position_wire)
    );


    reg [ADDRESS_BITS-1:0] write_index; // 12 bits because 2**11 < ACTIVE_LINE_SIZE + ACTIVE_LINE_SIZE < 2**12  and (a + b) mod 2048 mod 1440 != (a + b) mod 1440
    reg switch_buffer;
    reg prev_H;

	 function [ADDRESS_BITS-1:0] get_read_idx (input [ADDRESS_BITS:0] write_index,
															 input [ADDRESS_BITS-1:0] cut_position,
															 input H,
															 input V);
		begin
			if (write_index < ACTIVE_LINE_SIZE && !H && !V) begin
				if (write_index + cut_position < ACTIVE_LINE_SIZE)
					get_read_idx = write_index + cut_position;
				else
					get_read_idx = write_index + cut_position - ACTIVE_LINE_SIZE;
			end else
				get_read_idx = write_index;
		end
	 endfunction
	 localparam GARBAGE_LINES = 2;
    reg [1:0] line_switch_count;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin

            switch_buffer <= 0;
            data_out <= 0;
            prev_H <= H;
            data_valid <= 0;
            line_switch_count <=0;

				if (!H)
					write_index <= 0;
				else
					write_index <= ACTIVE_LINE_SIZE;

        end else begin
            if (prev_H!=H && !H) begin // at negative edge reset counters. Has to be done on the same cloock tick

					if (MODE == MODE_SCRAMBLER) begin
						line_buffer[!switch_buffer][0] <= data_in;
						data_out <= line_buffer[switch_buffer][get_read_idx(0, cut_position_wire, H, V)];
					end else if (MODE == MODE_DESCRAMBLER) begin
						line_buffer[!switch_buffer][get_read_idx(0, cut_position_wire, H, V)] <= data_in;
						data_out <= line_buffer[switch_buffer][0];
					end

					if (line_switch_count < GARBAGE_LINES)
					   line_switch_count <= line_switch_count + 1;
					else
					   data_valid <= 0;
               cut_position <= cut_position_wire;
					switch_buffer <= !switch_buffer;
					write_index <= 1;
					prev_H <= H;
            end else begin
					if (MODE == MODE_SCRAMBLER) begin
						line_buffer[switch_buffer][write_index] <= data_in;
						data_out <= line_buffer[!switch_buffer][get_read_idx(write_index, cut_position, H, V)];
					end else if (MODE == MODE_DESCRAMBLER) begin
						line_buffer[switch_buffer][get_read_idx(write_index, cut_position, H, V)] <= data_in;
						data_out <= line_buffer[!switch_buffer][write_index];
					end

					write_index <= write_index + 1;
					prev_H <= H;
				end
        end
    end

endmodule