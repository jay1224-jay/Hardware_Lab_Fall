`timescale 1ns/1ps

module lab2_1_practice (
    input  logic              clk,
    input  logic              rst,
    input  logic signed [7:0] A,
    input  logic signed [7:0] B,
    output logic signed [7:0] out
);

    logic signed [8:0] inter_sum;

    always_comb begin
        inter_sum = A + B;
    end

    always_ff @( posedge clk ) begin
        if ( rst ) out <= 0;
        else if ( inter_sum > 127 ) 
            out <= 127;
        else if ( inter_sum < -128 ) 
            out <= -128;
        else
            out <= inter_sum;
    end

endmodule
