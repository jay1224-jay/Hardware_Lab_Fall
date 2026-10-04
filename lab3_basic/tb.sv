`timescale 1ns / 1ps

module tb;

    // 1. Declare local signals to drive the DUT inputs and monitor outputs
    logic clk;
    logic rst;        // Maps to SW15
    logic slow;       // Maps to SW0
    logic fast;       // Maps to SW1
    logic end_light;  // Maps to SW2 
    logic [15:0] led;

    // 2. Instantiate the Design Under Test (DUT)
    lab3_practice uut (
        .clk(clk),
        .rst(rst),
        .slow(slow),
        .fast(fast),
        .end_light(end_light),
        .led(led)
    );

    // 3. Generate a 100MHz clock signal (Period = 10ns -> Toggle every 5ns)
    initial begin
        clk = 0;
    end
    always #5 clk = ~clk;

    // 4. Test stimulus generation
    initial begin
        // --- Step 4a: Initialize all input signals ---
        rst       = 0;
        slow      = 0;
        fast      = 0;
        end_light = 0;
        #15; // Wait a few nanoseconds

        // --- Step 4b: Trigger the hardware Reset (SW15) ---
        $display("[%0t ns] Asserting Reset...", $time);
        rst = 1; 
        #20; // Hold active high reset for 2 clock cycles
        rst = 0;
        $display("[%0t ns] Reset Released.", $time);
        #15;

        // --- Step 4c: Simulate Mode 1 - "Slow" operation (SW0) ---
        $display("[%0t ns] Enabling 'slow' mode (SW0)...", $time);
        slow = 1;
        #100; // Let it run for 10 clock cycles
        slow = 0;
        #40;

        // --- Step 4d: Simulate Mode 2 - "Fast" operation (SW1) ---
        $display("[%0t ns] Enabling 'fast' mode (SW1)...", $time);
        fast = 1;
        #100; // Let it run for 10 clock cycles
        fast = 0;
        #40;

        
        #1000;

        // --- Step 4e: Simulate Trigger - "End Light" condition (SW2) ---
        $display("[%0t ns] Triggering 'end_light' behavior (SW2)...", $time);
        end_light = 1;
        #50;
        end_light = 0;
        #4000

        // --- Step 4f: Finish Simulation ---
        $display("[%0t ns] Simulation finished successfully.", $time);
        $finish; // Pauses simulation so you can check waveforms in Vivado/ModelSim
    end

    // 5. Optional: Automatic output monitor in the transcript console
    initial begin
        $monitor("Time=%0t ns | rst=%b slow=%b fast=%b end_light=%b | LED = %b", 
                 $time, rst, slow, fast, end_light, led);
    end

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb); // Replace with your top-level module/testbench name
    end

endmodule
