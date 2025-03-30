
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
                counter <= counter + 1'd1;
            end
        end
    end
endmodule

module sequence_generator #(parameter BLACK_LEVEL = 10'd282, parameter WHITE_LEVEL = 10'd966, parameter CHROMA_NEUTRAL = 10'd512)(
        input	  clock,
        input	[31:0]  sequence,
        input	  enable,
        input	  load,
        output	  [9:0] sequence_out
    );

    wire [7:0] id;
    wire [39:0] data_sig;

    wire shiftout_sig;

    identifier_const idgen0(.id(id));

    // assuming that input clock is at data rate of 720 samples of CrCb and 720 samples of Y per line
    // to fit 40 bits in 1440 samples it requires the subdividion of 1440/40 = 36
    wire clk_div36;
    clk_div36 clkdiv0(.clk(clock), .rst(!enable), .clk_out(clk_div36));

    sequence_shiftreg_out	sequence_shiftreg_out_inst (
     	.clock ( clk_div36 ),
     	.data ( data_sig ),
     	.enable ( enable ),
     	.load ( load ),
     	.shiftout ( shiftout_sig )
     	);

    assign data_sig = {id[7:0], sequence[31:0]};

    reg chroma_flag;
    // black level should be applied instead of 0 level, because it will make the decoder think that it is blanking now.
    assign sequence_out = chroma_flag ? (shiftout_sig ? WHITE_LEVEL : BLACK_LEVEL) : CHROMA_NEUTRAL;
// wow typingg wit this keyboard is vey silent and button presses need very little pressure. overall it is very pleasant and smooth. perhaps i neede to take that bluetooth keyboard, but oh well
// i didn't have an the oportunity to compare and thought that this one is much crappier
// it even has all working buttons and fn thingy going on
// the laptop stand also seems ok, and does not wobble
// wow another keybord layout`   `
    always @(posedge clock or negedge enable) begin
        if (!enable)
            chroma_flag <= 1; // Cr Y Cb Y Cr Y Cb Y
        else
            chroma_flag <= !chroma_flag;
    end


endmodule