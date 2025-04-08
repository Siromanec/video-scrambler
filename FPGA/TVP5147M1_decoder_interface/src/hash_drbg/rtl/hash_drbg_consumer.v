module hash_drbg_consumer #(parameter DATA_WIDTH_IN = 256,
                            parameter DATA_WIDTH_OUT = 8)
                           (input wire H,
                            input wire V,
                            input wire clk,
                            input wire reset_n,
                            input wire [DATA_WIDTH_IN-1:0] data_in,
                            input wire data_in_valid,
                            input wire generator_busy,
                            output reg [DATA_WIDTH_OUT-1:0] data_out,
                            output reg data_out_valid,
                            output reg need_next
                            );

   localparam BUFFER_SIZE = DATA_WIDTH_IN/DATA_WIDTH_OUT;
   localparam BUFFER_ADDRESS_BITS = $clog2(BUFFER_SIZE);
   reg [DATA_WIDTH_OUT-1:0] data_buffer [0:1][0:BUFFER_SIZE - 1];
   reg current_write_buffer;

   reg [BUFFER_ADDRESS_BITS-1:0] wa;
   reg [BUFFER_ADDRESS_BITS-1:0] ra;
   localparam GET_NEW_DATA_IDLE = 0,
              GET_NEW_DATA_NEXT = 1,
              GET_NEW_DATA_WAIT = 2,
              GET_NEW_DATA_FILL = 3;
   reg [$clog2(4) - 1:0] get_new_data_state;

   reg first_read_iteration;
   reg first_write_iteration;

   reg read_done;
   reg write_done;

   reg do_read;
   reg do_write;
	/*
	-----------------------------------
		WRITE CONTROL
	-----------------------------------
	*/
   always @(posedge clk or negedge reset_n) begin : get_new_data
      if (!reset_n) begin
         // DOES NOT MODIFY DO_READ
         // MODIFIES WRITE_DONE
         get_new_data_state <= GET_NEW_DATA_IDLE;
         need_next <= 0;
         wa <= 0;
         write_done <= 0;
      end else begin
         case (get_new_data_state)
            GET_NEW_DATA_IDLE: begin
               if(do_write && !generator_busy) begin
                  write_done <= 0;
                  need_next <= 1;
                  get_new_data_state <= GET_NEW_DATA_WAIT;
               end
            end
            GET_NEW_DATA_WAIT: begin
               need_next <= 0;
               if (data_in_valid)
                  get_new_data_state <= GET_NEW_DATA_FILL;
            end
            GET_NEW_DATA_FILL: begin
               data_buffer[current_write_buffer][wa] <= data_in[wa * DATA_WIDTH_OUT +: DATA_WIDTH_OUT];
               if (wa != BUFFER_SIZE - 1)
                  wa <= wa + 1;
               else begin
                  get_new_data_state <= GET_NEW_DATA_IDLE;
                  wa <= 0;
                  write_done <= 1;
               end
            end
         endcase
      end
   end
	/*
	-----------------------------------
		READ CONTROL
	-----------------------------------
	*/
   always @(posedge H or negedge reset_n) begin
      if (!reset_n) begin
         ra <= 0;
         data_out_valid <= 0;
         read_done <= 0;
      end else if (!V && do_read) begin
         data_out_valid <= 1;
         data_out <= data_buffer[!current_write_buffer][ra];
         if (ra != BUFFER_SIZE - 1) begin
            ra <= ra + 1;
            read_done <= 0;
         end else begin
            ra <= 0;
            read_done <= 1;
         end
      end else begin
         read_done <= 0;
      end
   end

	
	/*
	-----------------------------------
		LOGIC CONTROL
	-----------------------------------
	*/
	reg do_write_lock;
	reg prev_write_done, prev_read_done, prev_V, prev_H;
	wire write_done_rise =  write_done && !prev_write_done;
	wire read_done_rise  =  read_done  && !prev_read_done;
	wire V_rise = V && !prev_V;
	wire V_fall = !V && prev_V;
	wire H_rise = H && !prev_H;
	always @(posedge clk or negedge reset_n) begin
		if (!reset_n) begin
			prev_write_done <= 0;
			prev_read_done <= 0;

			first_write_iteration <= 1;
			do_read <= 0;
			do_write <= 1;
			current_write_buffer <= 0;
			do_write_lock <= 0;
		end else begin
			prev_write_done <= write_done;
			prev_read_done <= read_done;
			prev_V <= V;
			prev_H <= H;
			if (write_done_rise || read_done_rise || first_write_iteration || H_rise || V_fall) begin
				if (write_done && (read_done || first_write_iteration)) begin
               // todo: lock do write until next hsync
					first_write_iteration <= 0;
					do_read <= 1;

				      if (H && !do_write_lock) begin
				         // lock until hsync is done
				         current_write_buffer <= ~current_write_buffer;
				         do_write_lock <= 1;
				         do_write <= 1;
				      end else if (!H) begin
				         do_write_lock <= 0;
				      end

				end else begin
					if (read_done)
						do_read <= 0;
					if (write_done)
						do_write <= 0;
				end
			end
		end
   end

endmodule