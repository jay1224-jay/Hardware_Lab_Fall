`timescale 1ns/1ps
/*
Multiplexer
*/
module mux (
    input logic [3:0] a, // 0
    input logic [3:0] b, // 1
    input logic       sel,
    input logic [3:0] out
);

    assign out = (sel) ? b : a;

endmodule

/*
Check subset_sum == target
*/
module subset_sum (
    input  logic [3:0] val_1,
    input  logic [3:0] val_2,
    input  logic [3:0] val_3,
    input  logic [3:0] val_4,
    input  logic [3:0] subset_number,
    input  logic [5:0] target,
    output logic match
);

endmodule


/*
Output the position (decimal) of the first 1-bit in an array (like p_decoder)
*/
module priorty_decoder(
    input  logic [15:0] arr,
    output logic [3:0]  pos  
);

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

    logic [15:0] match;

    always_comb begin
        
        for ( i = 0 ; i < 16 ; i = i + 1 ) begin
            subset_sum my_subset_sum(
                val_1, val_2, val_3, val_4, i, target, match[i]
            );
        end

        switch (match) begin
            casex (param)
                : 
                default: 
            endcase 

    end

    always_ff @( posedge clk ) begin
        if ( rst ) out <= 0;

    end

endmodule
