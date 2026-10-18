// You can change anything in the template, except the module I/O of lab4_basic.
enum logic [1:0] {
    INIT,
    PLAY,
    FINAL
} state_t;

// parameter IDLE = 2'd0;
// parameter PLAY = 2'd1;
// parameter FINAL = 2'd2;

module LFSR (
    input logic clk,
    input logic rst,
    input logic [1:0] state,
    input logic enable,
    output logic [3:0] lfsr
);

    always_ff @( posedge clk, posedge rst ) begin
        if (rst || state == FINAL) lfsr <= 4'b0001;
        else if (enable) begin
            lfsr[0] <= lfsr[0] ^ lfsr[3];
            lfsr[1] <= lfsr[0];
            lfsr[2] <= lfsr[1];
            lfsr[3] <= lfsr[2];
        end
    end
    
endmodule

module lab4_basic (
    input logic clk,
    input logic rst,
    input logic btnL,
    input logic btnR,
    input logic btnD,
    input logic btnU,
    output logic [15:0] LED
);

    parameter ONE_SEC = 27'd100_000_000;
    
    logic [1:0] state, next_state, target_code;

    logic en_btnL, en_btnR, en_btnD, en_btnU;

    logic tick_3sec, wrong_input, advance_enable;

    logic [3:0] lfsr_output;

    timer #(.n(ONE_SEC * 3)) my_timer(clk, rst, state == FINAL, tick_3sec);

    deb_and_one deb_L(clk, btnL, en_btnL);
    deb_and_one deb_R(clk, btnR, en_btnR);
    deb_and_one deb_D(clk, btnD, en_btnD);
    deb_and_one deb_U(clk, btnU, en_btnU);

    LFSR my_LF(clk, rst, state, advance_enable, lfsr_output);

    assign target_code = lfsr_output[1:0];

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) state <= INIT;
        else state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            INIT: begin
                if (en_btnU)
                    next_state = PLAY;
            end
            PLAY: begin
                if (wrong_input)
                    next_state = FINAL;
            end
            FINAL: begin
                if (tick_3sec)
                    next_state = INIT;
            end
            default:
                next_state = INIT; 
        endcase
    end

    always_comb begin : LED_Decision
        case (state)
            INIT: begin
                LED[3:0] <= lfsr_output;
                LED[4] <= 1'b1;
                LED[6:5] <= 2'b00;
                LED[15:7] <= 0;
            end
            PLAY: begin
                LED[3:0] <= lfsr_output;
                LED[4] <= 1'b0;
                LED[6:5] <= lfsr_output[1:0];
                LED[15:7] <= 0;
            end
            FINAL: begin
                LED <= 16'hFFFF;
            end
            default:
                LED <= 0;
        endcase
    end

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) begin
            advance_enable <= 0;
            wrong_input <= 0;
        end else begin
            advance_enable <= 0;
            wrong_input <= 0;
            case (state)
                INIT: begin
                    if (en_btnR)
                        advance_enable <= 1;
                end
                PLAY: begin
                    case (target_code)
                        2'b00: begin
                            if (en_btnL) begin
                                advance_enable <= 1;
                            end
                            else if (en_btnD | en_btnR | en_btnU) begin
                                wrong_input <= 1;
                            end
                        end
                        2'b01: begin
                            if (en_btnR) begin
                                advance_enable <= 1;
                            end
                            else if (en_btnD | en_btnL | en_btnU) begin
                                wrong_input <= 1;
                            end
                        end
                        2'b10: begin
                            if (en_btnD) begin
                                advance_enable <= 1;
                            end
                            else if (en_btnR | en_btnL | en_btnU) begin
                                wrong_input <= 1;
                            end
                        end
                        2'b11: begin
                            if (en_btnU) begin
                                advance_enable <= 1;
                            end
                            else if (en_btnD | en_btnL | en_btnR) begin
                                wrong_input <= 1;
                            end
                        end
                        default:
                            ; 
                    endcase
                end
                FINAL: begin            
                    wrong_input <= 0;
                    advance_enable <= 0;
                end
                default:
                    ;
            endcase   
        end
    end
    
endmodule


module deb_and_one(
    input logic clk,
    input logic pb,
    output logic pb_deb_one
);

    logic [3:0] shift_reg;
    logic pb_delay;

    always_ff @( posedge clk ) begin
        shift_reg <= {shift_reg[2:0], pb};
        pb_delay <= &shift_reg;
    end

    assign pb_deb_one = (&shift_reg) & (~pb_delay);

endmodule

module timer #(
    parameter integer n = 100_000_000
) (
    input logic clk,
    input logic rst,
    input logic enable,
    output logic tick
);

    logic [31:0] counter;

    always_ff @( posedge clk, posedge rst ) begin
        if (rst) counter <= 0;
        else begin
            if (enable) begin
                if (counter >= n)
                    counter <= 0;
                else 
                    counter <= counter + 1;
            end
            else begin
                counter <= 0;
            end
        end
    end

    assign tick = enable && (counter == n);
    
endmodule
