// lab5_practice.sv
module lab5_practice (
    input logic clk,
    input logic rst,

    // write port
    input logic we,
    input logic [6:0] w_addr,
    input logic [3:0] din,

    // read port
    input logic re,
    input logic [6:0] r_addr,
    output logic [3:0] dout,

    // Status output
    output logic [3:0] cnt_valid
);

// Add your design here.
// You may change the data types of the I/O signals.

    localparam MEM_SIZE = 8;

    logic [2:0] w_addr_mapped, r_addr_mapped;
    logic [3:0] memory [0:7];
    logic       valid  [0:7];

    assign w_addr_mapped = w_addr[2:0] ^ w_addr[6:4] ^ w_addr[3:1];
    assign r_addr_mapped = r_addr[2:0] ^ r_addr[6:4] ^ r_addr[3:1];

    integer mem_idx;
    always_ff @( posedge clk ) begin
        if (rst) begin
            for (mem_idx = 0 ; mem_idx < MEM_SIZE ; mem_idx = mem_idx + 1) begin
                memory[mem_idx] <= 4'b0000;
                valid[mem_idx] <= 0;
            end
            cnt_valid <= 0;
            dout <= 0;
        end else begin
            if (re) begin
                if (we && w_addr_mapped == r_addr_mapped)
                    dout <= din;
                else if (valid[r_addr_mapped])
                    dout <= memory[r_addr_mapped];
                else
                    dout <= 4'b0000;
            end else begin
                dout <= 0;
            end
            if (we) begin
                memory[w_addr_mapped] <= din;
                if (valid[w_addr_mapped] == 0)
                    cnt_valid <= cnt_valid + 1;
                valid[w_addr_mapped] <= 1;
            end
        end
    end

endmodule
