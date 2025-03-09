module cfg_reader (
      input clk,
      input [7:0] data,
		input i2c_busy;
		
		input reset_n,
      
      output reg [7:0] i_addr_w_rw,
      output reg [7:0] i_sub_addr,
      output reg [7:0] i_data_write,
      output req_trans,
      output data_clk,
      output reg [5:0] rd_address
      );
		
		localparam I2C_OFFSET = 6'h10;
		localparam NI2C_SLAVES = 2;
		reg [5:0] byte_cnt;
		reg [5:0] cfg_size;
		
		localparam DATA_CLK_CYCLE_BEFORE_VALID = 2'd2;
		reg read_valid;
		reg [1:0] data_clk_cnt;
		
		task read_byte;
			// reads byte at rd_address
		begin
			if (data_clk_cnt == DATA_CLK_CYCLE_BEFORE_VALID) begin
				read_valid <= 1;
				data_clk_cnt <= 0;
			end else
				if (data_clk) data_clk_cnt <= data_clk_cnt + 1;
			
			data_clk = ~data_clk;
		end
		endtask
		
		always @(posedge clk or negedge reset_n) begin
			if (!reset_n) begin
				req_trans <= 0;
				byte_cnt <= 0;
				data_clk <= 0;
				read_valid <= 0;
				data_clk_cnt <= 0;
				rd_address <= I2C_OFFSET;
				cfg_size <= 0;
			end else if () begin
				if (!read_valid)
					read_byte;
				else if (!i2c_busy) begin
					read_valid <= 0;
					rd_address <= rd_address + 1;
					if (byte_cnt == 0) begin
						i_addr_w_rw <= data | 1'b0;
						byte_cnt <= byte_cnt + 1;
					end else if (byte_cnt == 1) begin
						cfg_size <= data + 2 + 1;
						byte_cnt <= byte_cnt + 1;
					end else if (byte_cnt != cfg_size && byte_cnt % 2 == 0) begin
						byte_cnt <= byte_cnt + 1;
						i_sub_addr <= data;
						req_trans <= 0;
					end else if (byte_cnt != cfg_size && byte_cnt % 2 == 1) begin
						byte_cnt <= byte_cnt + 1;
						i_data_write <= data;
						req_trans <= 1;
					end
				end
				
				
			end
		end
endmodule