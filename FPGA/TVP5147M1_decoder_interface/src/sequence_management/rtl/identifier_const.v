module identifier_const #(parameter ID_WIDTH=8, parameter ID_VALUE = 8'h3d) (
    output wire [ID_WIDTH-1:0] id
    );
    assign id = ID_VALUE;
endmodule