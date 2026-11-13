module one_pulse (
    input  logic clk,
    input  logic pb_in,
    output logic pb_out
);

    logic pb_in_delay;

    always_ff @(posedge clk) begin
        if (pb_in == 1'b1 && pb_in_delay == 1'b0) begin
            pb_out <= 1'b1;
        end else begin
            pb_out <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        pb_in_delay <= pb_in;
    end

endmodule