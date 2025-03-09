
`define DEBUG

module i2c_master_controller #(
    parameter CLOCK_FREQ = 50_000_000, // System clock frequency (50 MHz)
    parameter I2C_FREQ = 400_000       // I2C clock frequency (400 kHz)
)(
    input wire clk,          // System clock
    input wire rst_n,        // Active-low reset
    input wire start,        // Start signal for transaction
    input wire rw,           // Read (1) / Write (0)
    input wire [7:0] sub_addr,   // Sub-address for read/write
    input wire [7:0] slave_addr,   // 7-bit I2C slave address
    input wire [7:0] data_in,// Data to send
    output reg [7:0] data_out, // Data received (for reads)
    output reg busy,         // Busy signal
    output reg ack_error,    // Acknowledge error
    inout wire sda,          // Serial Data
    output wire scl           // Serial Clock
);
    // Clock divider for scl_out
	`ifdef DEBUG
		localparam DIV_CLOCK_BIT = 0; 
	`else
	    localparam DIV_CLOCK_BIT = 7; // resulting frequency: CLOCK_FREQ / 2 ** DIV_CLOCK_BIT; Approx 400k
	`endif
	
	localparam SUBDIV_CLOCK_BITS = 2;
   
	localparam SLAVE_ADDRESS_MASK = 7'b1011100;
	 
	 // events at subdiv_clk
	 localparam SUBDIV_CLK_HIGH = 0,
			    SUBDIV_CLK_READ = 1,
				SUBDIV_CLK_LOW = 2,
				SUBDIV_CLK_WRITE = 3;
	 
	 
	reg [SUBDIV_CLOCK_BITS-1:0] subdiv_cnt;
   reg [DIV_CLOCK_BIT:0] clk_cnt;
   reg scl_enable;

    
    // sda_out Control (tristate buffer)
    reg sda_out;
    reg scl_out;
    
    assign (strong0, highz1) sda = sda_out; // Open-drain
	assign (strong0, highz1) scl = scl_out; // Open-drain

    // State machine definition
	 localparam [3:0] IDLE = 0,
		START = 1,
		SLAVE_ADDR = 2,
		RW = 3,
		ACK1 = 4,
		SUB_ADDR = 5,
		ACK2 = 6,
		DATA = 7,
		ACK3 = 8,
		STOP = 9,
		DONE = 10;
		
	 localparam RW_WRITE = 0,
				RW_READ = 1;
	 localparam RW_START = 1,
				RW_STOP = 0;
    
    reg [3:0] state;
	 
	 
    reg [3:0] bit_cnt;  // Bit counter
	 reg end_rw;
	 reg [7:0] tick_scl_and_do_rw_task_data;
	 reg tick_scl_and_do_rw_task_rw;
	 reg start_happened;
	 reg sent_sub_addr;
	 reg finished;


	 task incr_subdiv;
		/*Increments subdiv and clears clk_cnt*/
		begin
		    subdiv_cnt <= subdiv_cnt + 1;
		end
	 endtask

	 task tick_scl_task;
		/**
		 * tick scl_out. must be called before writing/reading
		 *
		 */
		begin
			 case (subdiv_cnt)
				  SUBDIV_CLK_HIGH: scl_out <= 1;
				  SUBDIV_CLK_LOW: scl_out <= 0;							
			 endcase
			 incr_subdiv;
		end
	 endtask
    
	 task tick_scl_and_do_rw_task;
		/**
		 *	stop condition should be when all the data is written/read
		 * user is responsible for responding to stop condition 'end_rw'
		 *	arguments:
		 *		tick_scl_and_do_rw_task_data
		 *		tick_scl_and_do_rw_task_rw
	 	 * modifies:
		 * 	scl_out
		 *		sda_out
		 *		end_rw
		 *		bit_cnt
		 *		data_out
		 * 	clk_cnt
		 *		subdiv_cnt
		 */
		begin

		case (subdiv_cnt)
			SUBDIV_CLK_HIGH: scl_out <= 1;
			SUBDIV_CLK_READ: begin
                 if (tick_scl_and_do_rw_task_rw) begin
                     if (bit_cnt < 8) begin
                          data_out[7 - bit_cnt] <= sda;
                          bit_cnt <= bit_cnt + 1;
                     end else begin
                          end_rw <= 0;
                          bit_cnt <= 0;
                     end
                 end
			end
			SUBDIV_CLK_LOW: scl_out <= 0;
			SUBDIV_CLK_WRITE: begin
                if (!tick_scl_and_do_rw_task_rw) begin
                    if (bit_cnt < 8) begin
                         sda_out <= tick_scl_and_do_rw_task_data[7 - bit_cnt];
                         bit_cnt <= bit_cnt + 1;
                    end else begin
                         bit_cnt <= 0;
                         end_rw <= 0;
                         //sda_out is set back to high impendance so the slave can send ACK back. If it does not, it is a NACK for the master, hence no further handling is required.
                         sda_out <= 1;
                    end
                end
			end							
		endcase
		incr_subdiv;
		end
	endtask

	 
	 always @(posedge clk or negedge rst_n) begin
	     if (!rst_n) begin
            sda_out <= 1;
            scl_out <= 1;
            bit_cnt <= 0;
            subdiv_cnt <= 0;
				clk_cnt <= 0;
            busy <= 0;
				finished <= 0;
				state <= IDLE;
			end else begin
			   clk_cnt <= clk_cnt + 1;
			end
	 end
	 
		
    always @(posedge clk_cnt[DIV_CLOCK_BIT]) begin
	 

            case (state)
                 IDLE: begin
                    if (start) begin
                        busy <= 1;
                        state <= START;
                        sda_out <= 0; // Start condition
                       
                        subdiv_cnt <= 0;
                        start_happened <= 0;
								finished <= 0;
								bit_cnt <= 0;
								subdiv_cnt <= 0;
                    end
                 end
                 START: begin

                        
						  scl_out <= 0;  // Pull scl_out low
						  sent_sub_addr <= 0;


						  state <= SLAVE_ADDR;

						  bit_cnt <= 0;
						  subdiv_cnt <= SUBDIV_CLK_WRITE; // this will force the next state to write the data first, and then tick the clock

						  end_rw <= RW_START; // resetting the stop condition for the task;
						  // if start happened is set before transition
						  if (!start_happened) begin
								tick_scl_and_do_rw_task_data <= slave_addr | 0;
						  end else begin
								// start can happen twice only if it was read
								tick_scl_and_do_rw_task_data <= slave_addr | 1; //pass argument for the task in the next state
						  end
						  tick_scl_and_do_rw_task_rw <= RW_WRITE; // write slave address
		
                    
                 end
                 SLAVE_ADDR: begin
                    if (end_rw == RW_START) begin
                        tick_scl_and_do_rw_task;
                    end else begin
                         //previous clock state was SUBDIV_CLK_WRITE so this is SUBDIV_CLK_HIGH and subdiv_cnt == SUBDIV_CLK_HIGH is always true, hence no need for the check
                         scl_out <= 1;
                         subdiv_cnt <= subdiv_cnt + 1;

                         state <= ACK1;
                    end
                 end
                 ACK1: begin

							//previous clock state was SUBDIV_CLK_HIGH so this is SUBDIV_CLK_READ and subdiv_cnt == SUBDIV_CLK_READ is always true, hence no need for the check

							incr_subdiv;
							end_rw <= RW_START;
							
							if (finished) begin
								state <= STOP;
								scl_out <= 1; // stop condition
								sda_out <= 0;
							end else if (tick_scl_and_do_rw_task_rw != RW_READ) begin // TODO: Check for NACK conditions
								 // tick_scl_and_do_rw_task_rw could be RW_READ only if the previous state was the last read
								 if (sda) ack_error <= 1; // Check for ACK
								 // set arguments before transition
								 // if prev = slave_addr
								 if (!sent_sub_addr) begin
									  tick_scl_and_do_rw_task_data <= sub_addr;
									  tick_scl_and_do_rw_task_rw <= RW_WRITE;
									  state <= SLAVE_ADDR;
									  sent_sub_addr <= 1;
								 end else /*if (sent_sub_addr)*/ begin
									  if (rw == RW_WRITE) begin
											tick_scl_and_do_rw_task_data <= data_in;
											tick_scl_and_do_rw_task_rw <= RW_WRITE;
											state <= SLAVE_ADDR;
											finished <= 1;
									  end else if (!start_happened /*&& rw == RW_READ*/) begin
											sda_out <= 0; // Start condition
											start_happened <= 1;
											state <= START;
									  end else if (start_happened /*&& rw == RW_READ*/) begin // Phase 1 read is done, Phase 2 address sent, now receive data
											tick_scl_and_do_rw_task_rw <= RW_READ;
											state <= SLAVE_ADDR;
											finished <= 1;
									  end

								 end

                        end
							end
					  STOP: begin
					      sda_out <= 1;
						   state <= IDLE;
					end
            endcase

	end
	 
endmodule