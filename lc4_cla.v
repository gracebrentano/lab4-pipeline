/* TODO: Henry Garant(henrygar)
         Grace Brentano(brentano)
*/

/**
 * @param a first 1-bit input
 * @param b second 1-bit input
 * @param g whether a and b generate a carry
 * @param p whether a and b would propagate an incoming carry
 */
module gp1(input wire a, b,
           output wire g, p);
   assign g = a & b;
   assign p = a | b;
endmodule

/**
 * Computes aggregate generate/propagate signals over a 4-bit window.
 * @param gin incoming generate signals 
 * @param pin incoming propagate signals
 * @param cin the incoming carry
 * @param gout whether these 4 bits collectively generate a carry (ignoring cin)
 * @param pout whether these 4 bits collectively would propagate an incoming carry (ignoring cin)
 * @param cout the carry outs for the low-order 3 bits
 */
module gp4(input wire [3:0] gin, pin,
           input wire cin,
           output wire gout, pout,
           output wire [2:0] cout);

    assign pout = (& pin);
    assign cout[0] = gin[0] | pin[0] & cin;
    assign cout[1] = gin[1] | pin[1] & gin[0] | pin[1] & pin[0] & cin;
    assign cout[2] = gin[2] | pin[2] & gin[1] | pin[2] & pin[1] & gin[0] | pin[2] & pin[1] & pin[0] & cin;
    assign gout = gin[3] | pin[3] & gin[2] | pin[3] & pin[2] & gin[1] | pin[3] & pin[2] & pin[1] & gin[0];

    // extra |(P[3] & P[2] & P[1] & P[0] & cin);
   
endmodule

/**
 * 16-bit Carry-Lookahead Adder
 * @param a first input
 * @param b second input
 * @param cin carry in
 * @param sum sum of a + b + carry-in
 */
module cla16
  (input wire [15:0]  a, b,
   input wire         cin,
   output wire [15:0] sum);
	
	wire [15:0] g,p,cout;
	wire [3:0] gout;
	wire [3:0] pout;
	wire gtemp;

	genvar i; 
	for (i=0; i<16; i = i+1) begin
		gp1 f(.a(a[i]), .b(b[i]), .g(g[i]), .p(p[i]));
	end

	assign cout[0] = cin;
	gp4 h(.gin(g[3:0]), .pin(p[3:0]), .cin(cin), .gout(gout[0]), .pout(pout[0]), .cout(cout[3:1]));

	assign cout[4] = gout[0] | p[3] & p[2] & p[1] & p[0] & cin;
	gp4 h1(.gin(g[7:4]), .pin(p[7:4]), .cin(gout[0] | p[3] & p[2] & p[1] & p[0] & cin), .gout(gout[1]), .pout(pout[1]), .cout(cout[7:5]));

	assign cout[8] = gout[1] | p[7] & p[6] &p[5] & p[4] & cout[4];
	gp4 h2(.gin(g[11:8]), .pin(p[11:8]), .cin(gout[1] | p[7] & p[6] & p[5] & p[4] & cout[4]), .gout(gout[2]), .pout(pout[2]), 
.cout(cout[11:9]));

	assign cout[12] = gout[2]| p[11] & p[10] & p[9] & p[8] & cout[8];
	gp4 h3(.gin(g[15:12]), .pin(p[15:12]), .cin(gout[2] | p[11] & p[10] & p[9] & p[8] & cout[8]), .gout(gout[3]), .pout(pout[3]), 
.cout(cout[15:13]));


	assign sum = a ^ b ^ cout;
	
endmodule
