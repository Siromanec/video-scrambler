
module i2c_master_controller_tb;
	reg clk;
    reg rst_n;
    reg start;
    reg rw;
    reg [7:0] sub_addr;
    reg [7:0] slave_addr;
    reg [7:0] data_in;
    wire [7:0] data_out;
    wire busy;
	 wire scl;
	 wire sda;

    i2c_master_controller i2c_master_controller_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .rw(rw),
        .sub_addr(sub_addr),
        .slave_addr(slave_addr),
        .data_in(data_in),
        .data_out(data_out),
        .busy(busy),
        .scl(scl),
        .sda(sda)
    );


    initial begin
		  start = 0;
        rst_n = 0;
		  
		  #9 rw = 0;
        #9 slave_addr = 8'h0A;
        #9 sub_addr = 8'h0B;
        #9 data_in = 8'h0C;
		  
        #10 clk = 0;
        #10 rst_n = 1;

        
        #10 start = 1;

    end
    always begin
        #1 clk = ~clk;
    end

endmodule