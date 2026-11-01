`timescale 1ns/1ps

module lab5_practice_tb;

    reg clk = 1'b0;
    reg rst = 1'b0;

    // write port
    reg we = 1'b0;
    reg [6:0] w_addr = 7'd0;
    reg [3:0] din = 4'd0;

    // read port
    reg re = 1'b0;
    reg [6:0] r_addr = 7'd0;

    wire [3:0] dout;
    wire [3:0] cnt_valid;

    integer error_count;
    integer total_error;

    // Clock period = 10ns
    always #5 clk = ~clk;

    // DUT
    lab5_practice practice (
        .clk(clk),
        .rst(rst),
        .we(we),
        .w_addr(w_addr),
        .din(din),
        .re(re),
        .r_addr(r_addr),
        .dout(dout),
        .cnt_valid(cnt_valid)
    );

    // Address mapping:
    // mapped_addr = addr[2:0] ^ addr[6:4] ^ addr[3:1]
    function [2:0] map_addr;
        input [6:0] addr;
        begin
            map_addr = addr[2:0] ^ addr[6:4] ^ addr[3:1];
        end
    endfunction

    task check_output;
        input [3:0] exp_dout;
        input [3:0] exp_cnt;
        input [255:0] msg;
        begin
            #1;
            if (dout !== exp_dout || cnt_valid !== exp_cnt) begin
                $display("[ERROR] %s", msg);
                $display("        expected dout=%0d, cnt_valid=%0d", exp_dout, exp_cnt);
                $display("        got      dout=%0d, cnt_valid=%0d", dout, cnt_valid);
                error_count = error_count + 1;
                total_error = total_error + 1;
            end
            else begin
                $display("[PASS ] %s | dout=%0d, cnt_valid=%0d", msg, dout, cnt_valid);
            end
        end
    endtask

    task do_reset;
        input [255:0] msg;
        begin
            @(negedge clk);
            rst = 1'b1;
            we = 1'b0;
            re = 1'b0;
            w_addr = 7'd0;
            r_addr = 7'd0;
            din = 4'd0;

            @(posedge clk);
            check_output(4'd0, 4'd0, msg);

            @(negedge clk);
            rst = 1'b0;
        end
    endtask

    task write_only;
        input [6:0] addr;
        input [3:0] data;
        input [3:0] exp_cnt;
        input [255:0] msg;
        begin
            @(negedge clk);
            rst = 1'b0;
            we = 1'b1;
            re = 1'b0;
            w_addr = addr;
            r_addr = 7'd0;
            din = data;

            @(posedge clk);
            check_output(4'd0, exp_cnt, msg);

            @(negedge clk);
            we = 1'b0;
            din = 4'd0;
        end
    endtask

    task read_only;
        input [6:0] addr;
        input [3:0] exp_data;
        input [3:0] exp_cnt;
        input [255:0] msg;
        begin
            @(negedge clk);
            rst = 1'b0;
            we = 1'b0;
            re = 1'b1;
            w_addr = 7'd0;
            r_addr = addr;
            din = 4'd0;

            @(posedge clk);
            check_output(exp_data, exp_cnt, msg);

            @(negedge clk);
            re = 1'b0;
        end
    endtask

    task idle_check_zero;
        input [3:0] exp_cnt;
        input [255:0] msg;
        begin
            @(negedge clk);
            rst = 1'b0;
            we = 1'b0;
            re = 1'b0;
            w_addr = 7'd0;
            r_addr = 7'd0;
            din = 4'd0;

            @(posedge clk);
            check_output(4'd0, exp_cnt, msg);
        end
    endtask

    task read_write_same_cycle;
        input [6:0] waddr;
        input [3:0] data;
        input [6:0] raddr;
        input [3:0] exp_dout;
        input [3:0] exp_cnt;
        input [255:0] msg;
        begin
            @(negedge clk);
            rst = 1'b0;
            we = 1'b1;
            re = 1'b1;
            w_addr = waddr;
            r_addr = raddr;
            din = data;

            @(posedge clk);
            check_output(exp_dout, exp_cnt, msg);

            @(negedge clk);
            we = 1'b0;
            re = 1'b0;
            w_addr = 7'd0;
            r_addr = 7'd0;
            din = 4'd0;
        end
    endtask

    task reset_with_active_controls;
        input [255:0] msg;
        begin
            @(negedge clk);
            rst = 1'b1;
            we = 1'b1;
            re = 1'b1;
            w_addr = 7'd5;
            r_addr = 7'd5;
            din = 4'd15;

            @(posedge clk);
            check_output(4'd0, 4'd0, msg);

            @(negedge clk);
            rst = 1'b0;
            we = 1'b0;
            re = 1'b0;
            w_addr = 7'd0;
            r_addr = 7'd0;
            din = 4'd0;
        end
    endtask

    initial begin
        $display("==== Simulation Starts ====");
        error_count = 0;
        total_error = 0;

        // ============================================================
        // Case 1: Basic reset
        // ============================================================
        error_count = 0;
        do_reset("Case 1: reset should clear dout and cnt_valid");

        if (error_count == 0)
            $display("==== Case 1 Passed: Basic reset ====");
        else
            $display("==== Error in Case 1 ====");

        // ============================================================
        // Case 2: Invalid read
        // Read from an address that has never been written.
        // Expected dout = 0, cnt_valid = 0.
        // ============================================================
        error_count = 0;
        read_only(7'd3, 4'd0, 4'd0, "Case 2: read invalid entry should return 0");

        if (error_count == 0)
            $display("==== Case 2 Passed: Invalid read ====");
        else
            $display("==== Error in Case 2 ====");

        // ============================================================
        // Case 3: Basic write/read
        // 7'd0 maps to index 0
        // 7'd1 maps to index 1
        // 7'd3 maps to index 2
        // ============================================================
        error_count = 0;

        write_only(7'd0, 4'd10, 4'd1, "Case 3-1: write addr 0, data 10");
        write_only(7'd1, 4'd4,  4'd2, "Case 3-2: write addr 1, data 4");
        write_only(7'd3, 4'd14, 4'd3, "Case 3-3: write addr 3, data 14");

        read_only(7'd0, 4'd10, 4'd3, "Case 3-4: read addr 0, expect 10");
        read_only(7'd1, 4'd4,  4'd3, "Case 3-5: read addr 1, expect 4");
        read_only(7'd3, 4'd14, 4'd3, "Case 3-6: read addr 3, expect 14");

        if (error_count == 0)
            $display("==== Case 3 Passed: Basic write/read ====");
        else
            $display("==== Error in Case 3 ====");

        // ============================================================
        // Case 4: Overwrite valid entry
        // cnt_valid should not increase.
        // ============================================================
        error_count = 0;

        write_only(7'd1, 4'd9, 4'd3, "Case 4-1: overwrite addr 1, cnt_valid should remain 3");
        read_only(7'd1, 4'd9, 4'd3, "Case 4-2: read overwritten addr 1, expect 9");

        if (error_count == 0)
            $display("==== Case 4 Passed: Overwrite valid entry ====");
        else
            $display("==== Error in Case 4 ====");

        // ============================================================
        // Case 5: Address mapping collision
        // 7'd3 and 7'd90 both map to index 2.
        // 7'd90 = 7'b1011010
        // addr[2:0] = 010
        // addr[6:4] = 101
        // addr[3:1] = 101
        // mapped = 010 ^ 101 ^ 101 = 010
        // ============================================================
        error_count = 0;

        write_only(7'd90, 4'd6, 4'd3, "Case 5-1: write addr 90, same mapped index as addr 3");
        read_only(7'd3,  4'd6, 4'd3, "Case 5-2: read addr 3 after writing addr 90, expect 6");
        read_only(7'd90, 4'd6, 4'd3, "Case 5-3: read addr 90, expect 6");

        if (error_count == 0)
            $display("==== Case 5 Passed: Address mapping collision ====");
        else
            $display("==== Error in Case 5 ====");

        // ============================================================
        // Case 6: Write-first on already valid entry
        // Same mapped index, different original addresses.
        // Old value at mapped index 2 is 6.
        // New din is 12.
        // Expected dout = 12 in the same clock edge.
        // ============================================================
        error_count = 0;

        read_write_same_cycle(
            7'd90,
            4'd12,
            7'd3,
            4'd12,
            4'd3,
            "Case 6-1: write-first valid entry, same mapped index"
        );

        read_only(7'd3, 4'd12, 4'd3, "Case 6-2: read after write-first, expect 12");

        if (error_count == 0)
            $display("==== Case 6 Passed: Write-first valid entry ====");
        else
            $display("==== Error in Case 6 ====");

        // ============================================================
        // Case 7: re = 0 should force dout to zero at next posedge.
        // This catches designs where dout holds old value when re = 0.
        // ============================================================
        error_count = 0;

        read_only(7'd0, 4'd10, 4'd3, "Case 7-1: read addr 0 before idle");
        idle_check_zero(4'd3, "Case 7-2: re=0, dout should become 0");

        if (error_count == 0)
            $display("==== Case 7 Passed: re=0 makes dout zero ====");
        else
            $display("==== Error in Case 7 ====");

        // ============================================================
        // Case 8: Reset after dout is nonzero
        // This specifically catches the bug:
        // reset clears memory/cnt_valid but forgets to clear dout.
        // ============================================================
        error_count = 0;

        read_only(7'd90, 4'd12, 4'd3, "Case 8-1: make dout nonzero before reset");
        do_reset("Case 8-2: reset after nonzero dout should clear dout to 0");

        if (error_count == 0)
            $display("==== Case 8 Passed: Reset clears dout ====");
        else
            $display("==== Error in Case 8 ====");

        // ============================================================
        // Case 9: Write-first on previously invalid entry
        // This catches implementations that do:
        // if(valid[ra]) dout <= memory[ra]; else dout <= 0;
        // without checking write-first first.
        //
        // After reset, mapped index 2 is invalid.
        // Same cycle: write addr 90 and read addr 3.
        // Both map to index 2.
        // Expected dout = din = 7, cnt_valid = 1.
        // ============================================================
        error_count = 0;

        read_write_same_cycle(
            7'd90,
            4'd7,
            7'd3,
            4'd7,
            4'd1,
            "Case 9-1: write-first should work even when entry was previously invalid"
        );

        read_only(7'd3, 4'd7, 4'd1, "Case 9-2: read newly written entry after invalid write-first");

        if (error_count == 0)
            $display("==== Case 9 Passed: Write-first invalid entry ====");
        else
            $display("==== Error in Case 9 ====");

        // ============================================================
        // Case 10: Same cycle read/write different mapped index
        //
        // Current valid entries:
        // index 2 = 7, cnt_valid = 1.
        //
        // Write addr 0, index 0, data 5.
        // Read addr 3, index 2.
        //
        // Expected dout should be old index 2 value = 7,
        // not din = 5.
        // cnt_valid should become 2.
        // ============================================================
        error_count = 0;

        read_write_same_cycle(
            7'd0,
            4'd5,
            7'd3,
            4'd7,
            4'd2,
            "Case 10-1: simultaneous read/write different mapped index"
        );

        read_only(7'd0, 4'd5, 4'd2, "Case 10-2: read newly written different index");
        read_only(7'd3, 4'd7, 4'd2, "Case 10-3: original read index should still hold 7");

        if (error_count == 0)
            $display("==== Case 10 Passed: Same cycle different mapped index ====");
        else
            $display("==== Error in Case 10 ====");

        // ============================================================
        // Case 11: we=1, re=0 should still write, but dout should be 0
        //
        // This catches designs where write operation accidentally drives dout,
        // or where dout keeps previous value when re=0.
        // ============================================================
        error_count = 0;

        read_only(7'd3, 4'd7, 4'd2, "Case 11-1: make dout nonzero before write-only");

        @(negedge clk);
        rst = 1'b0;
        we = 1'b1;
        re = 1'b0;
        w_addr = 7'd1;
        din = 4'd11;
        r_addr = 7'd3;

        @(posedge clk);
        check_output(4'd0, 4'd3, "Case 11-2: write-only should write but dout should be 0");

        @(negedge clk);
        we = 1'b0;
        din = 4'd0;

        read_only(7'd1, 4'd11, 4'd3, "Case 11-3: read back write-only data");

        if (error_count == 0)
            $display("==== Case 11 Passed: Write-only dout behavior ====");
        else
            $display("==== Error in Case 11 ====");

        // ============================================================
        // Case 12: rst priority over we/re
        //
        // If rst = 1 while we/re are also 1, reset must win.
        // Expected:
        // dout = 0
        // cnt_valid = 0
        // memory should be cleared
        // no write should survive reset
        // ============================================================
        error_count = 0;

        reset_with_active_controls("Case 12-1: reset priority over active we/re");

        read_only(7'd5, 4'd0, 4'd0, "Case 12-2: after reset priority test, addr 5 should be invalid");
        read_only(7'd3, 4'd0, 4'd0, "Case 12-3: after reset priority test, old addr 3 should be invalid");

        if (error_count == 0)
            $display("==== Case 12 Passed: Reset priority ====");
        else
            $display("==== Error in Case 12 ====");

        // ============================================================
        // Case 13: Fill all valid entries, then overwrite collision
        // cnt_valid should stop at 8 and should not exceed 8.
        //
        // Useful mapped examples:
        // 7'd0 -> index 0
        // 7'd1 -> index 1
        // 7'd3 -> index 2
        // 7'd2 -> index 3
        // 7'd7 -> index 4
        // 7'd6 -> index 5
        // 7'd4 -> index 6
        // 7'd5 -> index 7
        // ============================================================
        error_count = 0;

        write_only(7'd0, 4'd0,  4'd1, "Case 13-1: fill index 0");
        write_only(7'd1, 4'd1,  4'd2, "Case 13-2: fill index 1");
        write_only(7'd3, 4'd2,  4'd3, "Case 13-3: fill index 2");
        write_only(7'd2, 4'd3,  4'd4, "Case 13-4: fill index 3");
        write_only(7'd7, 4'd4,  4'd5, "Case 13-5: fill index 4");
        write_only(7'd6, 4'd5,  4'd6, "Case 13-6: fill index 5");
        write_only(7'd4, 4'd6,  4'd7, "Case 13-7: fill index 6");
        write_only(7'd5, 4'd7,  4'd8, "Case 13-8: fill index 7");

        write_only(7'd90, 4'd15, 4'd8, "Case 13-9: overwrite existing mapped index, cnt_valid should stay 8");
        read_only(7'd3, 4'd15, 4'd8, "Case 13-10: collision overwrite should update mapped index 2");

        if (error_count == 0)
            $display("==== Case 13 Passed: cnt_valid saturation by valid entries ====");
        else
            $display("==== Error in Case 13 ====");

        // ============================================================
        // Final result
        // ============================================================
        if (total_error == 0) begin
            $display("========================================");
            $display("==== All Test Cases Passed! ====");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("==== Simulation Failed, total errors = %0d ====", total_error);
            $display("========================================");
        end

        #20;
        $finish;
    end

endmodule