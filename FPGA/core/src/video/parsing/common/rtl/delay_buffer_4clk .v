module delay_buffer_4clk #(parameter DATA_WIDTH = 10)
    (
    input wire clk,
    input wire reset_n,         // Active-low reset
    input wire [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
);
    reg [DATA_WIDTH-1:0] buffer [0:3];     // 4-word circular buffer
    reg [1:0] ptr;              // 2-bit pointer (wraps automatically)

    always @(negedge clk or negedge reset_n) begin
        if (!reset_n) begin
            ptr <= 2'd0;
        end else begin
            buffer[ptr] <= din;
            dout <= buffer[ptr - 2'd4];
            ptr <= ptr + 1;
        end
    end

    // assign dout = buffer[ptr];  // Read 4 cycles delayed

endmodule
