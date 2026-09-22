`timescale 1ns/1ps

module lab2_2_practice (
    input  logic       clk,
    input  logic       rst,
    input  logic       load,
    input  logic [7:0] N,
    input  logic       reload,
    output logic [7:0] out,
    output logic       done
);

    logic [7:0] prev_N;

    always_ff @ ( posedge clk ) begin
        done = 0;
        if ( rst ) 
            out <= 0;
        else if ( load ) begin
            prev_N <= N;
            out <= N;
        end
        else if ( reload ) begin
            out <= prev_NN;
        end
        else if ( out > 1 )
            out <= out - 1;
        else if ( out == 1 ) begin
            out <= out - 1;
            done <= 1;
        end
    end

endmodule