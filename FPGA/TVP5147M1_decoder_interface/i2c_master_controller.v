
module i2c_master_controller(input             i_clk,              //input clock to the module @100MHz (or whatever crystal you have on the board)
                             input             reset_n,            //reset for creating a known start condition
                             input      [7:0]  i_addr_w_rw,        //7 bit address, LSB is the read write bit, with 0 being write, 1 being read
                             input      [7:0] i_sub_addr,         //contains sub addr to send to slave, partition is decided on bit_sel
                             input      [7:0]  i_data_write,       //Data to write if performing write action
                             input             req_trans,          //denotes when to start a new transaction

                             /** For Reads **/
                             output reg [7:0]  data_out,
                             output reg        valid_out,

                             /** I2C Lines **/
                             inout             scl_o,              //i2c clck line, output by this module, 400 kHz
                             inout             sda_o,              //i2c data line, set to 1'bz when not utilized (resistors will pull it high)

                             /** Comms to Master Module **/
                             output reg        req_data_chunk ,    //Request master to send new data chunk in i_data_write
                             output reg        busy,               //denotes whether module is currently communicating with a slave
                             output reg        nack);

    i2c_master i2c_master_inst(.i_clk(i_clk),                     //input clock to the module @100MHz (or whatever crystal you have on the board)
                               .reset_n(reset_n),               //reset for creating a known start condition
                               .i_addr_w_rw(i_addr_w_rw),        //7 bit address, LSB is the read write bit, with 0 being write, 1 being read
                               .i_sub_addr({8'b0, i_sub_addr}),         //contains sub addr to send to slave, partition is decided on bit_sel FIXME: will it work??
                               .i_sub_len(0),           //denotes whether working with an 8 bit or 16 bit sub_addr, 0 is 8bit, 1 is 16 bit
                               .i_byte_len(1),         //denotes whether a single or sequential read or write will be performed (denotes number of bytes to read or write)
                               .i_data_write(i_data_write),     //Data to write if performing write action 
                               .req_trans(req_trans),    //denotes when to start a new transaction

                                  /** For Reads **/
                               .data_out(data_out),
                               .valid_out(valid_out),

                                  /** I2C Lines **/
                               .scl_o(scl_o),             //i2c clck line, output by this module, 400 kHz
                               .sda_o(sda_o),             //i2c data line, set to 1'bz when not utilized (resistors will pull it high)

                                  /** Comms to Master Module **/
                               .req_data_chunk(req_data_chunk),  //Request master to request new data chunk in i_data_write
                               .busy(busy),                      //denotes whether module is currently communicating with a slave
                               .nack(nack)                       //denotes whether module is encountering a nack from slave (only activates when master is attempting to contact device)
                               );

endmodule
