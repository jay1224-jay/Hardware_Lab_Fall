`timescale 1ns/1ps
/*
Multiplexer
*/
module mux (
    input  logic [3:0] a, // 0
    input  logic [3:0] b, // 1
    input  logic       sel,
    output logic [3:0] out
);

    assign out = (sel) ? b : a;

endmodule

/*
Check subset_sum == target
*/
module subset_sum (
    input  logic [3:0] val_1, // 0
    input  logic [3:0] val_2,
    input  logic [3:0] val_3,
    input  logic [3:0] val_4, // 3
    input  logic [3:0] subset_number,
    input  logic [5:0] target,
    output logic match
);

    logic [5:0] inter_sum;
    logic [3:0] selected_val1, selected_val2, selected_val3, selected_val4;


    mux m1(.a(4'b0), .b(val_1), .sel(subset_number[3]), .out(selected_val1));
    mux m2(.a(4'b0), .b(val_2), .sel(subset_number[2]), .out(selected_val2));
    mux m3(.a(4'b0), .b(val_3), .sel(subset_number[1]), .out(selected_val3));
    mux m4(.a(4'b0), .b(val_4), .sel(subset_number[0]), .out(selected_val4));

    assign inter_sum = selected_val1 + selected_val2 + selected_val3 + selected_val4;

    assign match = ( inter_sum == target ) ? 1 : 0;

endmodule


/*
Output the position (decimal) of the first 1-bit in an array (like p_decoder)
*/
/*
module priorty_decoder(
    input  logic [15:0] arr,
    output logic [3:0]  pos  
);

endmodule
*/

/*
Main module
*/
module lab2_adv_1 (
    input  logic       clk,
    input  logic       rst,
    input  logic [3:0] val_1,
    input  logic [3:0] val_2,
    input  logic [3:0] val_3,
    input  logic [3:0] val_4,
    input  logic [5:0] target,
    output logic       exact,
    output logic [3:0] out
);

    logic [15:0] match;

    generate
        genvar i;
        for ( i = 0 ; i < 16 ; i = i + 1 ) begin
            subset_sum my_subset_sum(
                val_1, val_2, val_3, val_4, i, target, match[i]
            );
        end                
    endgenerate


    always_ff @( posedge clk ) begin
        if ( match != 0 ) 
            exact <= 1;
        else 
            exact <= 0;
    end

    always_ff @( posedge clk ) begin
        if ( rst ) out <= 0;
        else begin
            if ( match[0] ) begin
                out <= 0;
            end else if ( match[1] ) begin
                out <= 1;
            end else if ( match[2] ) begin
                out <= 2;
            end else if ( match[3] ) begin
                out <= 3;
            end else if ( match[4] ) begin
                out <= 4;
            end else if ( match[5] ) begin
                out <= 5;
            end else if ( match[6] ) begin
                out <= 6;
            end else if ( match[7] ) begin
                out <= 7;
            end else if ( match[8] ) begin
                out <= 8;
            end else if ( match[9] ) begin
                out <= 9;
            end else if ( match[10] ) begin
                out <= 10;
            end else if ( match[11] ) begin
                out <= 11;
            end else if ( match[12] ) begin
                out <= 12;
            end else if ( match[13] ) begin
                out <= 13;
            end else if ( match[14] ) begin
                out <= 14;
            end else if ( match[15] ) begin
                out <= 15;
            end
        end
    end

endmodule
