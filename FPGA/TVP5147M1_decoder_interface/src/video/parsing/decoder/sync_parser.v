module sync_parser (
   input wire clk,
   input wire reset_n,
   input wire [9:0] bt_656,
   output reg H,
   output reg V,
   output reg F
);

localparam PREAMBLE_0 = 8'hFF;
localparam PREAMBLE_1, PREAMBLE_2 = 8'h00;

localparam PREAMBLE_0_STATE = 0,
           PREAMBLE_1_STATE = 1,
           PREAMBLE_2_STATE = 2,
           DATA_STATE = 3;
reg [1:0] state;
always @(posedge clk or negedge reset_n) begin
   if (!reset_n) begin
      state <= PREAMBLE_0_STATE;
   end else begin
      if (bt_656 == PREAMBLE_0) begin
         state <= PREAMBLE_1_STATE;
      end else begin
         case (state)
            PREAMBLE_1_STATE: begin
               if(bt_656[9:2] == PREAMBLE_1)
                  state <= PREAMBLE_2_STATE;
               else
                  state <= PREAMBLE_1_STATE;
            end
            PREAMBLE_2_STATE: begin
               if(bt_656[9:2] == PREAMBLE_2)
                  state <= DATA_STATE;
               else
                  state <= PREAMBLE_1_STATE;
            end
            DATA_STATE: begin
               F <= bt_656[8];
               V <= bt_656[7];
               H <= bt_656[6];
               // TODO error correction codes
            end
         endcase
      end
   end
end
endmodule