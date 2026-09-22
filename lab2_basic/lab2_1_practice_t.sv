module lab2_1_practice_tb;

    timeunit 1ns;
    timeprecision 1ps;

    localparam time CYCLE = 10ns;
    localparam int unsigned PATTERN_NUM = 32;

    logic clk;
    logic rst;
    logic signed [7:0] A;
    logic signed [7:0] B;
    logic signed [7:0] out;

    // Pattern layout: {rst, A[7:0], B[7:0], expected_out[7:0]}
    logic [24:0] patterns [0:PATTERN_NUM-1];
    logic expected_rst;
    logic signed [7:0] expected_out;
    int unsigned pattern_index;
    int unsigned pass_count;
    int unsigned failure_count = 0;
    integer pattern_file;
    bit timing_checks_enabled = 1'b0;
    realtime last_rising_edge = -1.0;

    lab2_1_practice dut (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .out(out)
    );

    initial begin
        clk = 1'b0;
        forever #(CYCLE/2) clk = ~clk;
    end

    always @(posedge clk)
        last_rising_edge = $realtime;

    // Check both clock phases, including early combinational and delayed updates.
    always @(out) begin
        #0;
        if (timing_checks_enabled && ($realtime != last_rising_edge)) begin
            failure_count = failure_count + 1;
            $display("<ERROR> out changed away from a rising edge at t=%0t", $time);
        end
    end

    initial begin
        #((PATTERN_NUM + 10) * CYCLE);
        $fatal(1, "Lab 2 Practice 1: FAIL (simulation timeout)");
    end

    initial begin
        rst = 1'b1;
        A = 8'sd0;
        B = 8'sd0;
        pass_count = 0;

        // Missing/short files must never turn an all-X design into a false PASS.
        pattern_file = $fopen("pattern_A_practice.dat", "r");
        if (pattern_file == 0)
            $fatal(1, "Lab 2 Practice 1: FAIL (cannot open pattern_A_practice.dat; add it as a simulation source with Copy sources into project)");
        $fclose(pattern_file);
        for (pattern_index = 0; pattern_index < PATTERN_NUM; pattern_index++)
            patterns[pattern_index] = 'x;
        $readmemb("pattern_A_practice.dat", patterns);
        for (pattern_index = 0; pattern_index < PATTERN_NUM; pattern_index++) begin
            if ((^patterns[pattern_index]) === 1'bx)
                $fatal(1, "Lab 2 Practice 1: FAIL (pattern %0d is missing or contains X/Z; expected %0d complete binary patterns)", pattern_index, PATTERN_NUM);
        end

        // Allow the first synchronous reset edge to resolve initial unknowns.
        @(posedge clk);
        #1ns;
        timing_checks_enabled = 1'b1;

        for (pattern_index = 0;
             pattern_index < PATTERN_NUM;
             pattern_index = pattern_index + 1) begin
            @(negedge clk);
            {expected_rst, A, B, expected_out} = patterns[pattern_index];
            rst = expected_rst;

            @(posedge clk);
            #1ns;
            if (out !== expected_out) begin
                failure_count = failure_count + 1;
                $display("<ERROR> pattern %0d: rst=%b A=%0d B=%0d out=%0d expected=%0d",
                         pattern_index, rst, $signed(A), $signed(B),
                         $signed(out), $signed(expected_out));
            end else begin
                pass_count = pass_count + 1;
            end
        end

        // Assert reset between edges after establishing a nonzero output.
        // An asynchronous-reset implementation must fail this synchronous lab.
        @(negedge clk);
        rst = 1'b0;
        A = 8'sd1;
        B = 8'sd2;
        @(posedge clk);
        #1ns;
        if (out !== 8'sd3) begin
            failure_count = failure_count + 1;
            $display("<ERROR> reset probe setup: expected out=3, got %0d", $signed(out));
        end
        #1ns rst = 1'b1;
        @(posedge clk);
        #1ns;
        if (out !== 8'sd0) begin
            failure_count = failure_count + 1;
            $display("<ERROR> synchronous reset: expected out=0, got %0d", $signed(out));
        end

        if ((pass_count == PATTERN_NUM) && (failure_count == 0)) begin
            $display("========================================");
            $display("  Lab 2 Practice 1: PASS (%0d/%0d)",
                     pass_count, PATTERN_NUM);
            $display("========================================");
        end else begin
            $fatal(1, "Lab 2 Practice 1: FAIL (%0d/%0d patterns, %0d errors)",
                   pass_count, PATTERN_NUM, failure_count);
        end
        $finish;
    end

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, lab2_1_practice_tb); // Replace with your top-level module/testbench name
    end

endmodule
