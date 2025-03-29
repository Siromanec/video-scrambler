module clk_div36 (
    input wire clk,        // Input clock
    input wire rst,        // Active-high reset
    output reg clk_out     // Divided clock output
);

    reg [4:0] counter = 0;  // 5-bit counter (max count 18 requires log2(18) ≈ 5 bits)

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            clk_out <= 0;
        end else begin
            if (counter == 17) begin  // Toggle at 18th cycle
                counter <= 0;
                clk_out <= ~clk_out;
            end else begin
                counter <= counter + 1;
            end
        end
    end
endmodule

module sequence_detector#(parameter BLACK_LEVEL = 282, parameter WHITE_LEVEL = 966, parameter TRIGGER_WIDTH = 256)(
    input	  clock,

    input	  [9:0] sequence_in,
    input           enable_in,
    output	[31:0]  sequence_out,
    output	  enable_out,
    output	  load_out
    );



   reg chroma_flag;
   localparam LOW = 0,
              HIGH = 1;
   reg current_value;

    always @(posedge clock or negedge enable_in) begin
        if (!enable_in) begin
            chroma_flag = 1;
        end
        else begin
            chroma_flag <= ~chroma_flag;

        end
    end

    reg clear_shiftreg;
    sequence_shiftreg_in	sequence_shiftreg_in_inst (
        .aclr (!enable_in),
    	.clock ( clock_sig ),
    	.enable ( enable_sig ),
    	.shiftin ( current_value ),
    	.q ( sequence_out )
    	);


    // schmidt trigger
    always @(negedge chroma_flag or negedge enable_in) begin
        if (!enable_in) begin
            current_value = LOW;
        end else begin
            case (current_value)
                LOW: begin
                    if (current_value > WHITE_LEVEL - TRIGGER_WIDTH)
                        current_value <= HIGH;
                end
                HIGH: begin
                    if (current_value < BLACK_LEVEL + TRIGGER_WIDTH)
                        current_value <= LOW;
                end
            endcase
        end
    end




endmodule