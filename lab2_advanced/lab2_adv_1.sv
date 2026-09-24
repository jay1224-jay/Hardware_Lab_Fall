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
Comparator
*/
module comp(
    input  logic [5:0]  a,
    input  logic [5:0]  b,
    output logic        out
);

    assign out = (a > b) ? 1 : 0;

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
    output logic [5:0] sub_sum
);

    logic [3:0] selected_val1, selected_val2, selected_val3, selected_val4;

    mux m1(.a(4'b0), .b(val_1), .sel(subset_number[0]), .out(selected_val1));
    mux m2(.a(4'b0), .b(val_2), .sel(subset_number[1]), .out(selected_val2));
    mux m3(.a(4'b0), .b(val_3), .sel(subset_number[2]), .out(selected_val3));
    mux m4(.a(4'b0), .b(val_4), .sel(subset_number[3]), .out(selected_val4));

    assign sub_sum = selected_val1 + selected_val2 + selected_val3 + selected_val4;

endmodule

module target_filter(
    input  logic [3:0] target,
    input  logic [3:0] sum,
    output logic [3:0] out
);

    assign out = (sum <= target) ? sum : 4'b0000;

endmodule

module check_max_among(
    input  [5:0] filtered_data [15:0],
    input  [3:0] index,
    output is_max
);

    logic [15:0] is_max_array;
    genvar i;
    for ( i = 0 ; i < 16 ; i = i + 1 ) begin
        assign is_max_array[i] = (filtered_data[index] >= filtered_data[i] && index != i) ? 1 : 0;
    end

    assign is_max = &is_max_array; // and all bits -> 1 bit

endmodule

module find_max_fit(
    input  logic [5:0] filtered_data [15:0],
    input  logic [5:0] target,
    output logic [3:0] out // best-fit mask
);

    logic [15:0] is_max;

    genvar i;
    for ( i = 0 ; i < 16 ; i = i + 1 )
        check_max_among my_check(filtered_data, 4'(i), is_max[i]);

    always @(*) begin 
        if ( is_max[0] ) begin
            out = 0;
        end else if ( is_max[1] ) begin
            out = 1;
        end else if ( is_max[2] ) begin
            out = 2;
        end else if ( is_max[3] ) begin
            out = 3;
        end else if ( is_max[4] ) begin
            out = 4;
        end else if ( is_max[5] ) begin
            out = 5;
        end else if ( is_max[6] ) begin
            out = 6;
        end else if ( is_max[7] ) begin
            out = 7;
        end else if ( is_max[8] ) begin
            out = 8;
        end else if ( is_max[9] ) begin
            out = 9;
        end else if ( is_max[10] ) begin
            out = 10;
        end else if ( is_max[11] ) begin
            out = 11;
        end else if ( is_max[12] ) begin
            out = 12;
        end else if ( is_max[13] ) begin
            out = 13;
        end else if ( is_max[14] ) begin
            out = 14;
        end else if ( is_max[15] ) begin
            out = 15;
        end else 
            out = 0;
    end

endmodule

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

    
    genvar  i;
    for ( i = 0 ; i < 16 ; i = i + 1 ) begin
        subset_sum my_subset_sum(
            val_1, val_2, val_3, val_4, 4'(i), sub_sum_arr
        );
    end

    logic [5:0] filtered_data [15:0];

    genvar  j;
    for ( j = 0 ; j < 16 ; j = j + 1 ) begin
        target_filter my_tf(
            val_1, val_2, val_3, val_4, 4'(i), target
        );
    end

    logic [3:0] low_mask;
    find_max_fit my_find(filtered_data, target, low_mask);

    always_ff @( posedge clk ) begin
        if ( rst ) begin 
            out <= 0;
            exact <= 0;
        end
        else begin
            out <= low_mask;
        end
    end

endmodule
