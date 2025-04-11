module drbg_consumer #(parameter DATA_WIDTH_IN = 256,
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
   reg [DATA_WIDTH_OUT-1:0] data_buffer [0:0][0:BUFFER_SIZE - 1];

   reg [BUFFER_ADDRESS_BITS-1:0] wa;
   reg [BUFFER_ADDRESS_BITS-1:0] ra;
   localparam GET_NEW_DATA_IDLE = 0,
              GET_NEW_DATA_NEXT = 1,
              GET_NEW_DATA_WAIT1 = 2,
              GET_NEW_DATA_WAIT2 = 3,
              GET_NEW_DATA_FILL = 4;
   reg [$clog2(5) - 1:0] get_new_data_state;

   reg first_read_iteration;
   reg first_write_iteration;

   reg read_done;
   reg write_done;

   reg do_read;
   reg do_write;


   reg [3:0] not_busy_cnt_after_do_write;
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
         not_busy_cnt_after_do_write <= 0;
      end else begin
         case (get_new_data_state)
            GET_NEW_DATA_IDLE: begin

               if(do_write) begin
                  write_done <= 0;
                  get_new_data_state <= GET_NEW_DATA_NEXT;
                  not_busy_cnt_after_do_write <= 0;
               end
            end
            GET_NEW_DATA_NEXT: begin
                if(!generator_busy && not_busy_cnt_after_do_write < 8) begin
                  not_busy_cnt_after_do_write <= not_busy_cnt_after_do_write + 1;
                end else if (generator_busy) begin
                  not_busy_cnt_after_do_write <= 0;
                end else begin
                  need_next <= 1;
                  get_new_data_state <= GET_NEW_DATA_WAIT1;
                end

            end
            GET_NEW_DATA_WAIT1: begin // wait for a reaction
               need_next <= 0;
               get_new_data_state <= GET_NEW_DATA_WAIT2;
            end
            GET_NEW_DATA_WAIT2: begin // wait for a valid data
               if (data_in_valid)
                  get_new_data_state <= GET_NEW_DATA_FILL;
            end
            GET_NEW_DATA_FILL: begin
               data_buffer[0][wa] <= data_in[wa * DATA_WIDTH_OUT +: DATA_WIDTH_OUT];
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
         data_out <= data_buffer[0][ra];
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
		end else begin
			prev_write_done <= write_done;
			prev_read_done <= read_done;
			prev_V <= V;
			prev_H <= H;
			if (read_done_rise || first_write_iteration) begin
			   do_write <= 1;
			   first_write_iteration <= 0;
			end else if (prev_write_done) begin
			   do_read <= 1;
			end else begin
            if (read_done)
               do_read <= 0;
            do_write <= 0;
			end
		end
   end

endmodule