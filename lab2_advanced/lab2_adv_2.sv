`timescale 1ns/1ps
/*
Notes:
1. Inputs of val1 ~ val4 come from SW depending on the switch_inputtype

2. outputs are combinational, load vals are sequentials

*/

module lab2_adv_2 (
    input logic clk,
    input logic rst,
    input logic [7:0] switch_input, // -> val_1 ~ val_4
    input logic [1:0] switch_inputtype,
    input logic valid,
    output logic [3:0] out, // best-fit mask
    output logic [5:0] sum,
    output logic exact
);

    logic [3:0] val_1, val_2, val_3, val_4;
    logic [5:0] target;

    /* ======== solver ======== */
    lab2_adv_1 my_solver(
        .clk(clk), .rst(rst), 
        .val_1(val_1), .val_2(val_2), .val_3(val_3), .val_4(val_4), 
        .target(target), .exact(exact), .out(out)
    );
    subset_sum my_sum(
        .val_1(val_1), .val_2(val_2), .val_3(val_3), .val_4(val_4), 
        .subset_number(out), .sub_sum(sum)
    );
    /* ======== solver ======== */

    always_ff @( posedge clk, posedge rst ) begin
        if ( rst ) begin
            {val_1, val_2, val_3, val_4} <= 16'b0;
            target <= 0;
            // exact = ?
        end else if ( valid ) begin
            case (switch_inputtype)
                2'b00: begin
                    val_1 <= switch_input[7:4];
                    val_2 <= switch_input[3:0];
                end 
                2'b01: begin 
                    val_3 <= switch_input[7:4];
                    val_4 <= switch_input[3:0];
                end
                2'b10: begin
                    target <= switch_input[5:0];
                end
                2'b11: begin // Load nothing
                    ; // null line
                end
                default: ;
            endcase 
        end else begin
            ;
        end
    end

endmodule
