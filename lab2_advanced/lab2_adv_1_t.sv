module lab2_adv_1_tb;

    timeunit 1ns;
    timeprecision 1ps;

    logic clk;
    logic rst;
    logic [3:0] val_1;
    logic [3:0] val_2;
    logic [3:0] val_3;
    logic [3:0] val_4;
    logic [5:0] target;
    logic exact;
    logic [3:0] out;

    logic [3:0] test_val_1 [0:7];
    logic [3:0] test_val_2 [0:7];
    logic [3:0] test_val_3 [0:7];
    logic [3:0] test_val_4 [0:7];
    logic [5:0] test_target [0:7];
    int unsigned test_index;

    logic [3:0] expected_result [0:7];
    logic [3:0] expected_out;

    lab2_adv_1 dut (
        .clk(clk),
        .rst(rst),
        .val_1(val_1),
        .val_2(val_2),
        .val_3(val_3),
        .val_4(val_4),
        .target(target),
        .exact(exact),
        .out(out)
    );

    // Starting high places falling edges at 5, 15, 25, ... ns and rising
    // edges at 10, 20, 30, ... ns.
    initial begin
        clk = 1'b1;
        forever #5ns clk = ~clk;
    end

    initial begin
        rst = 1'b0;
        #15ns rst = 1'b1;
        #20ns rst = 1'b0;
    end

    initial begin
        test_val_1[0] = 4'd3;  test_val_2[0] = 4'd5;
        test_val_3[0] = 4'd9;  test_val_4[0] = 4'd11;
        test_target[0] = 6'd14;

        test_val_1[1] = 4'd3;  test_val_2[1] = 4'd5;
        test_val_3[1] = 4'd9;  test_val_4[1] = 4'd11;
        test_target[1] = 6'd0;

        test_val_1[2] = 4'd2;  test_val_2[2] = 4'd4;
        test_val_3[2] = 4'd6;  test_val_4[2] = 4'd8;
        test_target[2] = 6'd5;

        test_val_1[3] = 4'd1;  test_val_2[3] = 4'd2;
        test_val_3[3] = 4'd3;  test_val_4[3] = 4'd4;
        test_target[3] = 6'd63;

        test_val_1[4] = 4'd7;  test_val_2[4] = 4'd7;
        test_val_3[4] = 4'd7;  test_val_4[4] = 4'd7;
        test_target[4] = 6'd14;

        test_val_1[5] = 4'd15; test_val_2[5] = 4'd15;
        test_val_3[5] = 4'd1;  test_val_4[5] = 4'd1;
        test_target[5] = 6'd16;

        test_val_1[6] = 4'd0;  test_val_2[6] = 4'd0;
        test_val_3[6] = 4'd0;  test_val_4[6] = 4'd0;
        test_target[6] = 6'd0;

        test_val_1[7] = 4'd4;  test_val_2[7] = 4'd6;
        test_val_3[7] = 4'd8;  test_val_4[7] = 4'd10;
        test_target[7] = 6'd13;

        val_1 = 4'd0;
        val_2 = 4'd0;
        val_3 = 4'd0;
        val_4 = 4'd0;
        target = 6'd0;

        
        expected_result = '{4'b0110, 4'b0000, 4'b0010, 4'b1111, 4'b0011, 4'b0101, 4'b0110, 4'b1010};

        // The first post-reset input change occurs at the falling edge at
        // 35 ns. Each later set is applied at the next falling edge.
        #35ns;
        for (test_index = 0; test_index < 8; test_index = test_index + 1) begin
            val_1 = test_val_1[test_index];
            val_2 = test_val_2[test_index];
            val_3 = test_val_3[test_index];
            val_4 = test_val_4[test_index];
            target = test_target[test_index];

            @(posedge clk);
            #1ns;
            // TODO: Implement your expected-result checks here, after the sampled rising edge.
            // TODO: Also verify that both outputs change only at rising edges.
            if ( expected_result[test_index] != out ) begin
                $display("== FAIL == (see below)");
            end
            
            if (test_index < 7)
                @(negedge clk);
        end
    end

    always @(posedge clk) begin
        #1ns;
        $display("t=%0t rst=%b values={%0d,%0d,%0d,%0d} target=%0d out=%b, exact=%b",
                 $time, rst, val_1, val_2, val_3, val_4, target, out, exact);
    end

    // Required total duration: exactly 120 ns.
    initial begin
        #120ns;
        $finish;
    end

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, lab2_adv_1_tb); // Replace with your top-level module/testbench name
    end

endmodule
