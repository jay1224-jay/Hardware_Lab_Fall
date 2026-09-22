module lab2_2_practice_tb;

    timeunit 1ns;
    timeprecision 1ps;

    localparam time CYCLE = 10ns;
    localparam int unsigned PATTERN_NUM = 32;

    logic clk;
    logic rst;
    logic load;
    logic [7:0] N;
    logic [7:0] out;
    logic reload;
    logic done;

    // Pattern layout: {rst, load, N[7:0], expected_out[7:0], expected_done}
    logic [18:0] patterns [0:PATTERN_NUM-1];
    logic expected_rst;
    logic expected_load;
    logic [7:0] expected_out;
    logic expected_done;

    int unsigned pattern_index;
    int unsigned pass_count;
    int unsigned failure_count = 0;
    integer pattern_file;
    bit timing_checks_enabled = 1'b0;
    realtime last_rising_edge = -1.0;

    lab2_2_practice dut (
        .clk(clk),
        .rst(rst),
        .load(load),
        .N(N),
        .out(out),
        .done(done),
        .reload(reload)
    );

    initial begin
        clk = 1'b0;
        forever #(CYCLE/2) clk = ~clk;
    end

    always @(posedge clk)
        last_rising_edge = $realtime;

    always @(out or done) begin
        #0;
        if (timing_checks_enabled && ($realtime != last_rising_edge)) begin
            failure_count = failure_count + 1;
            $display("<ERROR> out/done changed away from a rising edge at t=%0t", $time);
        end
    end

    initial begin
        #((PATTERN_NUM + 10) * CYCLE);
        $fatal(1, "Lab 2 Practice 2: FAIL (simulation timeout)");
    end

    initial begin
        rst = 1'b1;
        load = 1'b0;
        N = 8'd0;
        pass_count = 0;
        $display("Load pattern file %d", N);
        pattern_file = $fopen("pattern_B_practice.dat", "r");
        if (pattern_file == 0)
            $fatal(1, "Lab 2 Practice 2: FAIL (cannot open pattern_B_practice.dat; add it as a simulation source with Copy sources into project)");
        $fclose(pattern_file);
        for (pattern_index = 0; pattern_index < PATTERN_NUM; pattern_index++)
            patterns[pattern_index] = 'x;
        $readmemb("pattern_B_practice.dat", patterns);
        for (pattern_index = 0; pattern_index < PATTERN_NUM; pattern_index++) begin
            if ((^patterns[pattern_index]) === 1'bx)
                $fatal(1, "Lab 2 Practice 2: FAIL (pattern %0d is missing or contains X/Z; expected %0d complete binary patterns)", pattern_index, PATTERN_NUM);
        end

        @(posedge clk);
        #1ns;
        timing_checks_enabled = 1'b1;

        for (pattern_index = 0;
             pattern_index < PATTERN_NUM;
             pattern_index = pattern_index + 1) begin
            @(negedge clk);
            {expected_rst, expected_load, N, expected_out, expected_done}
                = patterns[pattern_index];
            rst = expected_rst;
            load = expected_load;

            @(posedge clk);
            #1ns;
            if ((out !== expected_out) || (done !== expected_done)) begin
                failure_count = failure_count + 1;
                $display("<ERROR> pattern %0d: rst=%b load=%b N=%0d out=%0d done=%b expected_out=%0d expected_done=%b",
                         pattern_index, rst, load, N, out, done,
                         expected_out, expected_done);
            end else begin
                pass_count = pass_count + 1;
            end
        end

        // Load a positive value, then assert reset away from a rising edge.
        @(negedge clk);
        rst = 1'b0;
        load = 1'b1;
        N = 8'd3;
        @(posedge clk);
        #1ns;
        if ((out !== 8'd3) || (done !== 1'b0)) begin
            failure_count = failure_count + 1;
            $display("<ERROR> reset probe setup: expected out=3 done=0, got out=%0d done=%b", out, done);
        end
        #1ns rst = 1'b1;
        @(negedge clk);
        load = 1'b0;
        @(posedge clk);
        #1ns;
        if ((out !== 8'd0) || (done !== 1'b0)) begin
            failure_count = failure_count + 1;
            $display("<ERROR> synchronous reset: expected out=0 done=0, got out=%0d done=%b", out, done);
        end

        if ((pass_count == PATTERN_NUM) && (failure_count == 0)) begin
            $display("========================================");
            $display("  Lab 2 Practice 2: PASS (%0d/%0d)",
                     pass_count, PATTERN_NUM);
            $display("========================================");
        end else begin
            $fatal(1, "Lab 2 Practice 2: FAIL (%0d/%0d patterns, %0d errors)",
                   pass_count, PATTERN_NUM, failure_count);
        end
        $finish;
    end

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, lab2_2_practice_tb); // Replace with your top-level module/testbench name
    end

endmodule
