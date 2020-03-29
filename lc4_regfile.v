/* Henry Garant(henrygar)
 * Grace Brentano(brentano)
 *
 * lc4_regfile.v
 * Implements an 8-register register file parameterized on word size.
 *
 */

`timescale 1ns / 1ps

// Prevent implicit wire declaration
`default_nettype none

module lc4_regfile #(parameter n = 16)
        (input wire clk,
        input wire gwe,
        input wire rst,
        input wire [2:0] i_rs,         // rs selector
        output wire [n-1:0] o_rs_data, // rs contents
        input wire [2:0] i_rt,         // rt selector
        output wire [n-1:0] o_rt_data, // rt contents
        input wire [2:0] i_rd,         // rd selector
        input wire [n-1:0] i_wdata,    // data to write
        input wire i_rd_we             // write enable
        );

    wire [n-1:0] r0v, r1v, r2v, r3v, r4v, r5v, r6v, r7v;

    Nbit_reg #(n) r0 (.in(i_wdata), .out(r0v), .clk(clk), .we((i_rd == 3'd0) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r1 (.in(i_wdata), .out(r1v), .clk(clk), .we((i_rd == 3'd1) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r2 (.in(i_wdata), .out(r2v), .clk(clk), .we((i_rd == 3'd2) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r3 (.in(i_wdata), .out(r3v), .clk(clk), .we((i_rd == 3'd3) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r4 (.in(i_wdata), .out(r4v), .clk(clk), .we((i_rd == 3'd4) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r5 (.in(i_wdata), .out(r5v), .clk(clk), .we((i_rd == 3'd5) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r6 (.in(i_wdata), .out(r6v), .clk(clk), .we((i_rd == 3'd6) & i_rd_we), .gwe(gwe), .rst(rst));
    Nbit_reg #(n) r7 (.in(i_wdata), .out(r7v), .clk(clk), .we((i_rd == 3'd7) & i_rd_we), .gwe(gwe), .rst(rst));

    Nbit_mux8to1 mux1 (.sel(i_rs), .ins0(r0v), .ins1(r1v), .ins2(r2v), .ins3(r3v), .ins4(r4v), .ins5(r5v), .ins6(r6v), .ins7(r7v), 
.mux_output(o_rs_data));
    Nbit_mux8to1 mux2 (.sel(i_rt), .ins0(r0v), .ins1(r1v), .ins2(r2v), .ins3(r3v), .ins4(r4v), .ins5(r5v), .ins6(r6v), .ins7(r7v), 
.mux_output(o_rt_data));

endmodule

module Nbit_mux8to1(input wire [2:0] sel,
                    input wire [15:0] ins0,
                    input wire [15:0] ins1,
                    input wire [15:0] ins2,
                    input wire [15:0] ins3,
                    input wire [15:0] ins4,
                    input wire [15:0] ins5,
                    input wire [15:0] ins6,
                    input wire [15:0] ins7,
                    output reg [15:0] mux_output); 
                    

    always @(ins0 or ins1 or ins2 or ins3 or ins4 or ins5 or ins6 or ins7 or sel) 
        begin 
        case (sel) 
        3'b000 : mux_output = ins0; 
        3'b001 : mux_output = ins1; 
        3'b010 : mux_output = ins2; 
        3'b011 : mux_output = ins3; 
        3'b100 : mux_output = ins4; 
        3'b101 : mux_output = ins5; 
        3'b110 : mux_output = ins6; 
        3'b111 : mux_output = ins7; 
        default : mux_output = 16'bx; 
        endcase 
    end 
endmodule 
