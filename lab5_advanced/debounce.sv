module debounce(
    output logic pb_debounced,
    input  logic pb,
    input  logic clk
);

    logic [6:0] shift_reg;

    always_ff @(posedge clk) begin
        shift_reg[6:1] <= shift_reg[5:0];
        shift_reg[0] <= pb;
    end

    assign pb_debounced = shift_reg == 7'b111_1111 ? 1'b1 : 1'b0;

endmodule