module KeyboardDecoder(
	output logic [511:0] key_down,
	output logic [8:0] last_change,
	output logic key_valid,
	inout logic PS2_DATA,
	inout logic PS2_CLK,
	input logic rst,
	input logic clk
);
    
	typedef enum logic [1:0] {
		INIT,
		WAIT_FOR_SIGNAL,
		GET_SIGNAL_DOWN,
		WAIT_RELEASE
	} state_t;
    // parameter [1:0] INIT			   = 2'b00;
    // parameter [1:0] WAIT_FOR_SIGNAL = 2'b01;
    // parameter [1:0] GET_SIGNAL_DOWN = 2'b10;
    // parameter [1:0] WAIT_RELEASE    = 2'b11;
    
	parameter [7:0] IS_INIT			= 8'hAA;
    parameter [7:0] IS_EXTEND		= 8'hE0;
    parameter [7:0] IS_BREAK		= 8'hF0;
    
    logic [9:0] key;		// key = {been_extend, been_break, key_in}
    state_t state;
    logic been_ready, been_extend, been_break;
    logic pulse_been_ready;
    
    logic [7:0] key_in;
    logic is_extend;
    logic is_break;
    logic valid;
    logic err;
    
    logic [511:0] key_decode;
    assign key_decode = 512'b1 << last_change;
    assign last_change = {key[9], key[7:0]};
    
    KeyboardCtrl_0 inst (
		.key_in(key_in),
		.is_extend(is_extend),
		.is_break(is_break),
		.valid(valid),
		.err(err),
		.PS2_DATA(PS2_DATA),
		.PS2_CLK(PS2_CLK),
		.rst(rst),
		.clk(clk)
	);
	
	one_pulse op (
		.pb_out(pulse_been_ready),
		.pb_in(been_ready),
		.clk(clk)
	);
    
    always_ff @(posedge clk or posedge rst) begin
    	if (rst) begin
    		state <= INIT;
    		been_ready  <= 1'b0;
    		been_extend <= 1'b0;
    		been_break  <= 1'b0;
    		key <= 10'b0_0_0000_0000;
    	end else begin
    		state <= state;
			been_ready  <= been_ready;
			been_extend <= (is_extend) ? 1'b1 : been_extend;
			been_break  <= (is_break ) ? 1'b1 : been_break;
			key <= key;
    		case (state)
    			INIT : begin
					if (key_in == IS_INIT) begin
						state <= WAIT_FOR_SIGNAL;
						been_ready  <= 1'b0;
						been_extend <= 1'b0;
						been_break  <= 1'b0;
						key <= 10'b0_0_0000_0000;
					end else begin
						state <= INIT;
					end
				end
    			WAIT_FOR_SIGNAL : begin
					if (valid == 1'b0) begin
						state <= WAIT_FOR_SIGNAL;
						been_ready <= 1'b0;
					end else begin
						state <= GET_SIGNAL_DOWN;
					end
				end
    			GET_SIGNAL_DOWN : begin
					state <= WAIT_RELEASE;
					key <= {been_extend, been_break, key_in};
					been_ready  <= 1'b1;
				end
    			WAIT_RELEASE : begin
					if (valid == 1'b1) begin
						state <= WAIT_RELEASE;
					end else begin
						state <= WAIT_FOR_SIGNAL;
						been_extend <= 1'b0;
						been_break  <= 1'b0;
					end
				end
    			default : begin
					state <= INIT;
					been_ready  <= 1'b0;
					been_extend <= 1'b0;
					been_break  <= 1'b0;
					key <= 10'b0_0_0000_0000;
				end
    		endcase
    	end
    end
    
    always_ff @(posedge clk or posedge rst) begin
    	if (rst) begin
    		key_valid <= 1'b0;
    		key_down <= 512'b0;
    	end else if (key_decode[last_change] && pulse_been_ready) begin
    		key_valid <= 1'b1;
    		if (key[8] == 1'b0) begin
    			key_down <= key_down | key_decode;
    		end else begin
    			key_down <= key_down & (~key_decode);
    		end
    	end else begin
    		key_valid <= 1'b0;
			key_down <= key_down;
    	end
    end
endmodule
