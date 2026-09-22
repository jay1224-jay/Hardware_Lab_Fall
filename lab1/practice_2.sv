`timescale 1ns/100ps

module practice_2 (
    input  logic G,
    input  logic D,
    output wire P,
    output wire Pn
);
    wire nandD, nandG, nand1, nand2, notD;
    not (notD, D);
    nand (nandD, G, D);
    nand (nandG, notD, G);
    nand (P, nandD, Pn);
    nand (Pn, nandG, P);

endmodule
