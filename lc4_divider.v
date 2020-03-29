/* TODO: Henry Garant(henrygar)
         Grace Brentano(brentano)
*/

`timescale 1ns / 1ps
`default_nettype none

module lc4_divider(input  wire [15:0] i_dividend,
                   input  wire [15:0] i_divisor,
                   output wire [15:0] o_remainder,
                   output wire [15:0] o_quotient);

      // 3 x (17 16-bit buses)
      wire [15:0] temp_dividend[16:0];
      wire [15:0] temp_quotient[16:0];
      wire [15:0] temp_remainder[16:0];
      
      assign temp_quotient[0] = 16'd0;
      assign temp_remainder[0] = 16'd0;
      assign temp_dividend[0] = i_dividend;

      // Wire together 16 lc4_divider_one_iter
      genvar i;
        for (i = 0; i < 16; i = i + 1) begin
          lc4_divider_one_iter l(.i_dividend(temp_dividend[i]),
                                 .i_divisor(i_divisor),
                                 .i_remainder(temp_remainder[i]),
                                 .i_quotient(temp_quotient[i]),
                                 .o_dividend(temp_dividend[i+1]),
                                 .o_remainder(temp_remainder[i+1]),
                                 .o_quotient(temp_quotient[i+1]));
        end

      assign o_remainder = temp_remainder[16];
      assign o_quotient = temp_quotient[16];

endmodule // lc4_divider

module lc4_divider_one_iter(input  wire [15:0] i_dividend,
                            input  wire [15:0] i_divisor,
                            input  wire [15:0] i_remainder,
                            input  wire [15:0] i_quotient,
                            output wire [15:0] o_dividend,
                            output wire [15:0] o_remainder,
                            output wire [15:0] o_quotient);

      wire [15:0] remainder_temp, quotient_temp, computed_remainder, computed_quotient;

      //interim computations
      assign remainder_temp = (i_dividend >> 15 & 1'b1) | i_remainder << 1;
      assign computed_remainder = (remainder_temp < i_divisor) ? remainder_temp : remainder_temp - i_divisor;

      assign quotient_temp = i_quotient << 1;
      assign computed_quotient = (remainder_temp < i_divisor) ? quotient_temp : quotient_temp | 1'b1;

      //check for 0 case
      assign o_remainder = (i_divisor == 0) ? 1'b0 : computed_remainder;
      assign o_quotient = (i_divisor == 0) ? 1'b0 : computed_quotient;
      assign o_dividend = i_dividend << 1;

endmodule
