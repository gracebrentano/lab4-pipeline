/* TODO: Henry Garant(henrygar)
         Grace Brentano(brentano)
*/

`timescale 1ns / 1ps

`default_nettype none

module cla_box(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] cla_output);

    wire [15:0] insn_4, insn_5, insn_8, insn_10, inv_rt;
    assign insn_4 = { {11{i_insn[4]}}, i_insn[4:0] }; 
    assign insn_5 = { {10{i_insn[5]}}, i_insn[5:0] }; 
    assign insn_8 = { {8{i_insn[8]}}, i_insn[8:0] }; 
    assign insn_10 = { {6{i_insn[10]}}, i_insn[10:0] }; 
    assign inv_rt = ~i_r2data;

    wire [15:0] carry_in;
    assign carry_in = i_insn[15:12] == 4'b0000 || i_insn[15:12] == 4'b0100 || i_insn[15:12] == 4'b1100 || i_insn[15:12] == 4'b1111 || 
i_insn[15:12] == 4'b0001 && i_insn[5:3] == 3'b010 ? 1'b1 : 1'b0;

    wire [15:0] cla_a_in;
    assign cla_a_in = i_insn[15:12] == 4'b0000 || i_insn[15:12] == 4'b0100 || i_insn[15:12] == 4'b1100 || i_insn[15:12] == 4'b1111 ? i_pc : 
i_r1data;

    wire [15:0] cla_b_in;
    wire [7:0] check;
    assign check[0] = i_insn[15:12] == 4'b0000 ? 1'b1 : 1'b0; //nop and br
    assign check[1] = i_insn[15:12] == 4'b0001 && i_insn[5:3] == 3'b000 ? 1'b1 : 1'b0; //add
    assign check[2] = i_insn[15:12] == 4'b0001 && i_insn[5:3] == 3'b010 ? 1'b1 : 1'b0; //sub
    assign check[3] = i_insn[15:12] == 4'b0001 && i_insn[5] == 1'b1 ? 1'b1 : 1'b0; //add imm
    assign check[4] = i_insn[15:12] == 4'b0100 ? 1'b1 : 1'b0; //jsr
    assign check[5] = i_insn[15:12] == 4'b0110 || i_insn[15:12] == 4'b0111 ? 1'b1 : 1'b0; //ldr and str
    assign check[6] = i_insn[15:12] == 4'b1100 ? 1'b1 : 1'b0; //jmp
    assign check[7] = i_insn[15:12] == 4'b1111 ? 1'b1 : 1'b0; //trap
    
    wire [15:0] lev1_1, lev1_2, lev1_3, lev1_4;
    assign lev1_1 = check[0] ? insn_8 : i_r2data;
    assign lev1_2 = check[2] ? inv_rt : insn_4;
    assign lev1_3 = check[4] ? 1'b0 : insn_5;
    assign lev1_4 = check[6] ? insn_10 : 1'b0;

    wire [15:0] lev2_1, lev2_2;
    assign lev2_1 = check[0] || check[1] ? lev1_1 : lev1_2;
    assign lev2_2 = check[4] || check[5] ? lev1_3 : lev1_4;

    assign cla_b_in = check[0] || check[1] || check[2] || check[3] ? lev2_1 : lev2_2;

    cla16 cla(.a(cla_a_in), .b(cla_b_in), .cin(carry_in), .sum(cla_output));

endmodule

module lc4_alu(input  wire [15:0] i_insn,
               input wire [15:0]  i_pc,
               input wire [15:0]  i_r1data,
               input wire [15:0]  i_r2data,
               output wire [15:0] o_result);


      //rs is in r1data and rt is in r2data
      wire [15:0] and_o, andi_o, or_o, not_o, xor_o;
      wire [15:0] mul_o, div_o;
      wire [15:0] mod_o, sll_o, srl_o, sra_o, const_o, hiconst_o, cmp, cmpu, cmpi, cmpiu, trap_o, jsr_o;
      wire [15:0] cla_output;

      assign and_o = i_r1data & i_r2data;
      assign andi_o = i_r1data & { {11{i_insn[4]}}, i_insn[4:0] };
      assign or_o = i_r1data | i_r2data;
      assign xor_o = i_r1data ^ i_r2data;
      assign not_o = ~i_r1data;
      assign mul_o = i_r1data * i_r2data;

      lc4_divider a(.i_dividend(i_r1data), .i_divisor(i_r2data), .o_remainder(mod_o), .o_quotient(div_o));
      cla_box c(.i_insn(i_insn), .i_pc(i_pc), .i_r1data(i_r1data), .i_r2data(i_r2data), .cla_output(cla_output));

      wire signed [15:0] signed_shift;
      assign signed_shift = i_r1data;

      assign sll_o = i_r1data << i_insn[3:0];
      assign srl_o = i_r1data >> i_insn[3:0];
      assign sra_o = signed_shift >>> i_insn[3:0];
      assign const_o = { {7{i_insn[8]}}, i_insn[8:0] };
      assign hiconst_o = (i_r1data & 16'hFF) | (i_insn[7:0] << 4'h8);

      wire signed [15:0] signed_rs, signed_rt, signed_imm7;
      assign signed_rs = i_r1data;
      assign signed_rt = i_r2data;
      wire [15:0] imm7;
      assign imm7 = { {9{1'b0}}, i_insn[6:0] };
      assign signed_imm7 = { {9{i_insn[6]}}, i_insn[6:0] };

      assign cmpu = i_r1data < i_r2data ? 16'b1111111111111111 : (i_r1data > i_r2data ? 1'b1 : 1'b0);
      assign cmp = signed_rs < signed_rt ? 16'b1111111111111111 : (signed_rs > signed_rt ? 1'b1 : 1'b0);
      assign cmpiu = i_r1data < imm7 ? 16'b1111111111111111 : (i_r1data > imm7 ? 1'b1 : 1'b0);
      assign cmpi = signed_rs < signed_imm7 ? 16'b1111111111111111 : (signed_rs > signed_imm7 ? 1'b1 : 1'b0);

      assign trap_o = (16'b1000000000000000 | i_insn[7:0]);
      assign jsr_o = (i_pc & 16'b1000000000000000) | (i_insn[10:0] << 3'b100);

      wire [22:0] mux_ch;
	  assign mux_ch[0] = (i_insn[15:12] == 4'b0000 || (i_insn[15:12] == 4'b0001 && (i_insn[5:3] != 3'b001 && i_insn[5:3] != 3'b011)) || 
i_insn[15:12] == 4'b0110 || i_insn[15:12] == 4'b0111 || i_insn[15:11] == 5'b11001) ? 1'b1 : 1'b0; //cla black box 

	  assign mux_ch[1] = i_insn[15:12] == 4'b0101 && i_insn[5:3] == 3'b000 ? 1'b1 : 1'b0; //and
	  assign mux_ch[2] = i_insn[15:12] == 4'b0101 && i_insn[5:3] == 3'b001 ? 1'b1 : 1'b0; //not
	  assign mux_ch[3] = i_insn[15:12] == 4'b0101 && i_insn[5:3] == 3'b010 ? 1'b1 : 1'b0; //or
	  assign mux_ch[4] = i_insn[15:12] == 4'b0101 && i_insn[5:3] == 3'b011 ? 1'b1 : 1'b0; //xor
	  assign mux_ch[5] = i_insn[15:12] == 4'b0101 && i_insn[5] == 1'b1 ? 1'b1 : 1'b0; //and imm

	  assign mux_ch[6] = i_insn[15:12] == 4'b0001 && i_insn[5:3] == 3'b001 ? 1'b1 : 1'b0; //multiply
	  assign mux_ch[7] = i_insn[15:12] == 4'b0001 && i_insn[5:3] == 3'b011 ? 1'b1 : 1'b0; //divide

	  assign mux_ch[8] = i_insn[15:12] == 4'b1010 && i_insn[5:4] == 2'b00 ? 1'b1 : 1'b0; //sll
	  assign mux_ch[9] = i_insn[15:12] == 4'b1010 && i_insn[5:4] == 2'b01 ? 1'b1 : 1'b0; //sra
	  assign mux_ch[10] = i_insn[15:12] == 4'b1010 && i_insn[5:4] == 2'b10 ? 1'b1 : 1'b0; //srl
	  assign mux_ch[11] = i_insn[15:12] == 4'b1010 && i_insn[5:4] == 2'b11 ? 1'b1 : 1'b0; //mod

	  assign mux_ch[12] = i_insn[15:12] == 4'b0010 && i_insn[8:7] == 2'b00 ? 1'b1 : 1'b0; //cmp
	  assign mux_ch[13] = i_insn[15:12] == 4'b0010 && i_insn[8:7] == 2'b01 ? 1'b1 : 1'b0; //cmpu
	  assign mux_ch[14] = i_insn[15:12] == 4'b0010 && i_insn[8:7] == 2'b10 ? 1'b1 : 1'b0; //cmpi
	  assign mux_ch[15] = i_insn[15:12] == 4'b0010 && i_insn[8:7] == 2'b11 ? 1'b1 : 1'b0; //cmpiu

	  assign mux_ch[16] = i_insn[15:12] == 4'b1001 ? 1'b1 : 1'b0; //const
	  assign mux_ch[17] = i_insn[15:12] == 4'b1101 ? 1'b1 : 1'b0; //hiconst

	  assign mux_ch[18] = i_insn[15:12] == 4'b1000 ? 1'b1 : 1'b0; //rti
	  assign mux_ch[19] = i_insn[15:11] == 5'b11000 ? 1'b1 : 1'b0; //jmpr
	  assign mux_ch[20] = i_insn[15:12] == 4'b1111 ? 1'b1 : 1'b0; //trap

	  assign mux_ch[21] = i_insn[15:11] == 5'b01000 ? 1'b1 : 1'b0; //jsrr
	  assign mux_ch[22] = i_insn[15:11] == 5'b01001 ? 1'b1 : 1'b0; //jsr

	  wire [15:0] lev1_1, lev1_2, lev1_3, lev1_4, lev1_5, lev1_6, lev1_7, lev1_8, lev1_9, lev1_10, lev1_11;
      assign lev1_1 = mux_ch[0] ? cla_output : and_o;
      assign lev1_2 = mux_ch[2] ? not_o : or_o;
      assign lev1_3 = mux_ch[4] ? xor_o : andi_o;
      assign lev1_4 = mux_ch[6] ? mul_o : div_o;
      assign lev1_5 = mux_ch[8] ? sll_o : sra_o;
      assign lev1_6 = mux_ch[10] ? srl_o : mod_o;
      assign lev1_7 = mux_ch[12] ? cmp : cmpu; 
      assign lev1_8 = mux_ch[14] ? cmpi : cmpiu;
      assign lev1_9 = mux_ch[16] ? const_o : hiconst_o;
      assign lev1_10 = mux_ch[18] ? i_r1data : i_r1data; //rti or jmpr
      assign lev1_11 = mux_ch[21] ? i_r1data : jsr_o;

      wire [15:0] lev2_1, lev2_2, lev2_3, lev2_4;
      assign lev2_1 = mux_ch[0] || mux_ch[1] ? lev1_1 : lev1_2;
      assign lev2_2 = mux_ch[4] || mux_ch[5] ? lev1_3 : lev1_4;
      assign lev2_3 = mux_ch[8] || mux_ch[9] ? lev1_5 : lev1_6;
      assign lev2_4 = mux_ch[12] || mux_ch[13] ? lev1_7 : lev1_8;

      wire [15:0] lev3_1, lev3_2;
      assign lev3_1 = mux_ch[0] || mux_ch[1] || mux_ch[2] || mux_ch[3] ? lev2_1 : lev2_2;
      assign lev3_2 = mux_ch[8] || mux_ch[9] || mux_ch[10] || mux_ch[11] ? lev2_3 : lev2_4;

      wire [15:0] final, final_2, final_3, final_4;
      assign final = mux_ch[0] || mux_ch[1] || mux_ch[2] || mux_ch[3] || mux_ch[4] || mux_ch[5] || mux_ch[6] || mux_ch[7] ? lev3_1 : lev3_2;
      assign final_2 = mux_ch[18] || mux_ch[19] ? lev1_10 : final;
      assign final_3 = mux_ch[20] ? trap_o : final_2;
      assign final_4 = mux_ch[21] || mux_ch[22] ? lev1_11 : final_3;

      assign o_result = mux_ch[16] || mux_ch[17] ? lev1_9 : final_4;


endmodule
