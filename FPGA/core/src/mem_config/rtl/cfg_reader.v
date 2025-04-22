module cfg_reader (
      input clk, // clock signal
      input [7:0] data, // data from ROM
      input i2c_busy, // denotes whether i2c_master_controller is busy
      
      input reset_n, // reset signal
      
      output reg [7:0] o_addr_w_rw, // 7 bit address, LSB is the read write bit, with 0 being write, 1 being read. Is fed to i2c_master_controller
      output reg [7:0] o_sub_addr, // contains sub addr to send to slave, partition is decided on bit_sel. Is fed to i2c_master_controller
      output reg [7:0] o_data_write, // Data to write if performing write action. Is fed to i2c_master_controller
      output reg req_trans, // denotes when to start a new transaction. Is fed to i2c_master_controller
      output reg data_clk, // data clock. Is fed to the ROM with configuration data
      output reg [5:0] rd_address // address of the data in the ROM
      );
      
      localparam I2C_OFFSET = 6'h10;
      localparam NI2C_SLAVES = 2;
      reg [1:0] inited_devices; // number of inited devices

      reg [5:0] byte_cnt; // byte counter
      reg [5:0] cfg_size; // size of the configuration data
      
      localparam DATA_CLK_CYCLE_BEFORE_VALID = 2'd2;
      reg read_valid; // read valid signal
      reg [1:0] data_clk_cnt; // data clock counter

      task read_byte;
         // reads byte at rd_address from ROM after DATA_CLK_CYCLE_BEFORE_VALID cycles
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
            inited_devices <= 0;
         end else if (!i2c_busy && inited_devices != NI2C_SLAVES) begin
            if (!read_valid)
               read_byte;
            else begin
               read_valid <= 0;
               rd_address <= rd_address + 1;
               if (byte_cnt == 0) begin
                  o_addr_w_rw <= data | 1'b0; // write mode
                  byte_cnt <= byte_cnt + 1;
               end else if (byte_cnt == 1) begin
                  cfg_size <= data + 2 + 1;
                  byte_cnt <= byte_cnt + 1;
               end else if (byte_cnt != cfg_size && byte_cnt % 2 == 0) begin
                  byte_cnt <= byte_cnt + 1;
                  o_sub_addr <= data;
                  req_trans <= 0;
               end else if (byte_cnt != cfg_size && byte_cnt % 2 == 1) begin
                  byte_cnt <= byte_cnt + 1;
                  o_data_write <= data;
                  req_trans <= 1;
               end else begin
                  byte_cnt <= 0;
                  inited_devices <= inited_devices + 1;
               end
            end
            
            
         end
      end
endmodule