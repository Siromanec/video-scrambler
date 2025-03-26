module TVP5147M1_decoder(
            // Data signals
            output [9:0] o_Y,
            output [9:0] o_C,

            // Control signals
            output o_data_clk,
            output o_avid,
            output o_fid,
            output o_vsync,
            output o_hsync,

            // Input signals
            input i_pwdn,
            input i_resetb

            );

endmodule