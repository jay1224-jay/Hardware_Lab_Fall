module player_control (
	input logic clk, 
	input logic reset, 
	input logic _play, 
	input logic _slow, 
	input logic _mode, 
	output logic [11:0] ibeat
);
	parameter logic [11:0] LEN = 12'd4095;
    logic [11:0] next_ibeat;

	always_ff @(posedge clk or posedge reset) begin
		if (reset) begin
			ibeat <= 12'd0;
		end else begin
            ibeat <= next_ibeat;
		end
	end

    always_comb begin
        next_ibeat = (ibeat + 12'd1 < LEN) ? (ibeat + 12'd1) : 12'd1;
    end
endmodule
