`timescale 1ns / 1ps

module cfg_reader_tb;
   // inits rom_1 and cfg_reader and i2c_master_controller
localparam CLK_PERIOD = 2;
   initial begin
         clk = 0;
         forever #(CLK_PERIOD / 2) clk = ~clk;
   end
   reg clk;
   reg data_clk;
   reg [7:0] data;
   reg i2c_busy;
   reg reset_n;
   reg [7:0] i_addr_w_rw;
   reg [7:0] i_sub_addr;
   reg [7:0] i_data_write;
   reg req_trans;
   reg [5:0] rd_address;
   reg [5:0] byte_cnt;
   reg [5:0] cfg_size;
   reg [1:0] inited_devices;
   reg [1:0] data_clk_cnt;
   reg read_valid;


   rom_1 rom_1_inst(.address(rd_address), .clock(data_clk), .q(data));
   i2c_master_controller i2c_master_controller_inst(.i_clk(clk),
                                                    .reset_n(reset_n),
                                                    .i_addr_w_rw(i_addr_w_rw),
                                                    .i_sub_addr(i_sub_addr),
                                                    .i_data_write(i_data_write),
                                                    .req_trans(req_trans),
                                                    .data_out(data),
                                                    .valid_out(read_valid),
                                                    .scl_o(data_clk),
                                                    .sda_o(data_clk),
                                                    .busy(i2c_busy));

   cfg_reader cfg_reader_inst(.clk(clk),
                              .reset_n(reset_n),
                              .i2c_busy(i2c_busy),
                              .i_addr_w_rw(i_addr_w_rw),
                              .i_sub_addr(i_sub_addr),
                              .i_data_write(i_data_write),
                              .data_clk(data_clk),
                              .rd_address(rd_address),
                              .data(data),
                              .req_trans(req_trans));
   initial begin
      clk = 0;
      reset_n = 1;
      i_addr_w_rw = 8'b0;
      i_sub_addr = 8'b0;
      i_data_write = 8'b0;
      reset_n = 0;
      #1 reset_n = 1;

   end
   always begin
      #1 clk = ~clk;
   end





endmodule