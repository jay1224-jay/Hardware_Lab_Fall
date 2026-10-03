module mux (
    input  logic [15:0] in0,
    input  logic [15:0] in1,
    input  logic [15:0] in2,
    input  logic [15:0] in3,
    input  logic [1:0]  sel,
    output logic [15:0] out
);

    always_comb begin
        case (sel)
            2'b00:
                out = in0;
            2'b01:
                out = in1;
            2'b10:
                out = in2;
            2'b11:
                out = in3; 
            default: 
                out = 0;
        endcase
    end
    

endmodule

module LOAD_led (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic [1:0] state,
    output logic end_load,
    output logic [15:0] led_out
);

    logic [15:0] next_led;

    always_ff @( posedge clk, posedge rst ) begin
        if ( rst || state != 2'b01 ) begin
            led_out <= 0;
            next_led <= 0;
        end
        else if ( enable ) begin
            led_out <= next_led;
            next_led <= (led_out << 1) + 1'b1;
        end
    end

endmodule

module PLAY_led_slow (
    input  logic clk,
    input  logic rst,
    input  logic [1:0] state,
    output logic end_load
);

endmodule

module PLAY_led_fast (
    input  logic clk,
    input  logic rst,
    input  logic [1:0] state,
    output logic end_load
);

endmodule

module FINAl_led (
    input  logic clk,
    input  logic rst,
    input  logic [1:0] state,
    output logic end_load
);

endmodule

module lab3_practice (
    input logic clk,
    input logic rst,        // SW15
    input logic slow,       // SW0
    input logic fast,       // SW1
    input logic end_light,  // SW2 
    output logic [15:0] led
);

    // led_out
    logic [15:0] load_out, play_out, final_out;
    logic [7:0]  slow_out, fast_out;

    // States
    logic [1:0] state, next_state;
    logic end_load;
    parameter INIT  = 2'b00;
    parameter LOAD  = 2'b01;
    parameter PLAY  = 2'b10;
    parameter FINAL = 2'b11;

    // Timers
    logic p25_enable, p25_clk;
    logic p5_enable, p5_clk;

    assign p25_enable = (state == LOAD)  ? 1 : 0;
    assign p5_enable  = (state == FINAL) ? 1 : 0;        
    timer #(.COUNT(25_000_000)) p25_timer   (.clk(clk), .rst(rst), .enable(p25_enable), .tick(p25_clk));
    timer p5_timer (.clk(clk), .rst(rst), .enable(p5_enable), .tick(p5_clk));

    // State register
    always_ff @( posedge clk, posedge rst ) begin
        if ( rst ) begin
            state <= INIT;
        end else begin 
            state <= next_state;
        end
    end

    // Next state logic 
    always_comb begin
        next_state = state;

        case (state) 
            INIT: begin
                next_state = LOAD;
            end
            LOAD: begin
                ;
            end
            PLAY: begin
                ;
            end
            FINAL: begin
                ;
            end
            default: next_state = INIT;
        endcase
    end

    LOAD_led my_load(.clk(clk), .rst(rst), .enable(p25_clk), .state(state), .end_load(end_load), .led_out(led));
    
    // mux my_mux(.in0({16{1'b1}}), .in1(load_out), .in2(play_out), .in3(final_out), .sel(state), .out(led));

endmodule

module timer #(
    parameter integer COUNT = 100_000_000
)(
    input logic clk,
    input logic rst,
    input logic enable,
    output logic tick
);

    logic [31:0] num;
    logic [31:0] next_num;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            num <= 32'd0;
        end else begin
            num <= next_num;
        end
    end

    assign next_num = (enable == 1'b0) ? 32'd0 :
                      (num == COUNT - 1) ? 32'd0 :
                      num + 1'b1;
    assign tick = enable && (num == COUNT - 1);
endmodule

module clock_divider #(
    parameter n = 10
)(
    input logic clk,
    input logic rst,
    input logic enable,
    output logic clk_div
);

    logic [n-1:0] num;
    logic [n-1:0] next_num;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            num <= {n{1'b0}};
        end else begin
            num <= next_num;
        end
    end

    assign next_num = (enable == 1'b1) ? num + 1'b1 : {n{1'b0}};
    assign clk_div = num[n-1];
endmodule
