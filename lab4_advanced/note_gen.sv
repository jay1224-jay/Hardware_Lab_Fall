module note_gen(
    input logic clk, // clock from crystal
    input logic rst, // active high reset
    input logic [2:0] volume, 
    input logic [21:0] note_div_left, // div for note generation
    input logic [21:0] note_div_right,
    output logic signed [15:0] audio_left,
    output logic signed [15:0] audio_right
);

    // Declare internal signals
    logic [21:0] clk_cnt_next, clk_cnt;
    logic [21:0] clk_cnt_next_2, clk_cnt_2;
    logic b_clk, b_clk_next;
    logic c_clk, c_clk_next;

    // Note frequency generation
    // clk_cnt, clk_cnt_2, b_clk, c_clk
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_cnt <= 22'd0;
            clk_cnt_2 <= 22'd0;
            b_clk <= 1'b0;
            c_clk <= 1'b0;
        end else begin
            clk_cnt <= clk_cnt_next;
            clk_cnt_2 <= clk_cnt_next_2;
            b_clk <= b_clk_next;
            c_clk <= c_clk_next;
        end
    end

    // clk_cnt_next, b_clk_next
    always_comb begin
        if (clk_cnt + 22'd1 >= note_div_left) begin
            clk_cnt_next = 22'd0;
            b_clk_next = ~b_clk;
        end else begin
            clk_cnt_next = clk_cnt + 22'd1;
            b_clk_next = b_clk;
        end
    end

    // clk_cnt_next_2, c_clk_next
    always_comb begin
        if (clk_cnt_2 + 22'd1 >= note_div_right) begin
            clk_cnt_next_2 = 22'd0;
            c_clk_next = ~c_clk;
        end else begin
            clk_cnt_next_2 = clk_cnt_2 + 22'd1;
            c_clk_next = c_clk;
        end
    end

    // Assign the amplitude of the note
    // Volume is controlled here
    assign audio_left = (note_div_left == 22'd1) ? 16'sh0000 : 
                                (b_clk == 1'b0) ? -16'sh2000 : 16'sh2000;
    assign audio_right = (note_div_right == 22'd1) ? 16'sh0000 : 
                                (c_clk == 1'b0) ? -16'sh2000 : 16'sh2000;
endmodule
