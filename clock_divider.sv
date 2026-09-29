module main (
    input clk,
    input rst,
    output div_clk
);

    parameter i = 5;

    logic [i:0] num;

    always_ff @( posedge clk ) begin
        if ( rst ) num <= 0;
        else if ( num[i] == 1 )
            num <= 0;
        else
            num <= num + 1;
    end

    assign div_clk = num[i];
    
endmodule

`define test_num 50

module test;
    timeunit 1ns;
    timeprecision 1ps;

    logic clk, div_clk, rst;

    main m(.clk(clk), .rst(rst), .div_clk(div_clk));

    logic [4:0] i;

    initial begin
        clk = 0;
        for ( i = 0 ; i < `test_num ; i = i + 1 ) begin
            #10
            clk = ~clk;
        end
    end

    initial begin
        rst = 1;
        #20
        rst = 0;
        #1000
        $finish;
    end

    initial begin
        for ( i = 0 ; i < `test_num ; i = i + 1 ) begin
            #10
            $display("clk = %b, div_clk = %b", clk, div_clk);
        end
    end

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, test); // Replace with your top-level module/testbench name
    end

endmodule