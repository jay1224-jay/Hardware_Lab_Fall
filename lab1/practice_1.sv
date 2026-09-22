`timescale 1ns/100ps
module practice_1 (
    input  logic A,
    input  logic B,
    input  logic C,
    output wire out
);

    wire and_g, or_g;
    and (and_g, A, B);
    or  (or_g, A, B);
    mux my_mux(.a(and_g), .b(or_g), .c(C), .y(out));

endmodule

module mux (
    input  logic a,
    input  logic b,
    input  logic c,
    output wire y
);
    wire not_c, and1, and2;
    not (not_c, c);
    and (and1, a, not_c);
    and (and2, b, c);
    or  (y, and1, and2);

endmodule
