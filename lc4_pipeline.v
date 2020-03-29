  
/* Henry Garant(henrygar)
 * Grace Brentano(brentano)
 *
 * lc4_single.v
 * Implements a fully bypassed scalar pipelined data path
 *
 */


`timescale 1ns / 1ps

// disable implicit wire declaration
`default_nettype none

module lc4_processor
   (input  wire        clk,                // main clock
    input wire         rst, // global reset
    input wire         gwe, // global we for single-step clock
                                    
    output wire [15:0] o_cur_pc, // Address to read from instruction memory
    input wire [15:0]  i_cur_insn, // Output of instruction memory
    output wire [15:0] o_dmem_addr, // Address to read/write from/to data memory
    input wire [15:0]  i_cur_dmem_data, // Output of data memory
    output wire        o_dmem_we, // Data memory write enable
    output wire [15:0] o_dmem_towrite, // Value to write to data memory
   
    output wire [1:0]  test_stall, // Testbench: is this is stall cycle? (don't compare the test values)
    output wire [15:0] test_cur_pc, // Testbench: program counter
    output wire [15:0] test_cur_insn, // Testbench: instruction bits
    output wire        test_regfile_we, // Testbench: register file write enable
    output wire [2:0]  test_regfile_wsel, // Testbench: which register to write in the register file 
    output wire [15:0] test_regfile_data, // Testbench: value to write into the register file
    output wire        test_nzp_we, // Testbench: NZP condition codes write enable
    output wire [2:0]  test_nzp_new_bits, // Testbench: value to write to NZP bits
    output wire        test_dmem_we, // Testbench: data memory write enable
    output wire [15:0] test_dmem_addr, // Testbench: address to read/write memory
    output wire [15:0] test_dmem_data, // Testbench: value read/writen from/to memory

    input wire [7:0]   switch_data, // Current settings of the Zedboard switches
    output wire [7:0]  led_data // Which Zedboard LEDs should be turned on?
    );
   
   // By default, assign LEDs to display switch inputs to avoid warnings about
   // disconnected ports. Feel free to use this for debugging input/output if
   // you desire.
   assign led_data = switch_data;

   
   /* DO NOT MODIFY THIS CODE */
   // Always execute one instruction each cycle (test_stall will get used in your pipelined processor)
   assign test_stall = 2'b0; 

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

   // Program counter register, starts at 8200h at bootup
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   /* END DO NOT MODIFY THIS CODE */

   //insn logic
   assign test_cur_insn = i_cur_insn;

   //decoder
   wire [2:0] r1sel, r2sel, wsel;
   wire r1we, r2we, regfile_we, nzp_we, select_pc_plus_one, is_load, is_store, is_branch, is_control_insn;
   lc4_decoder d (.insn(i_cur_insn),
                  .r1sel(r1sel),
                  .r1re(r1we),
                  .r2sel(r2sel),
                  .r2re(r2we),
                  .wsel(wsel),
                  .regfile_we(regfile_we),
                  .nzp_we(nzp_we),
                  .select_pc_plus_one(select_pc_plus_one),
                  .is_load(is_load),
                  .is_store(is_store),
                  .is_branch(is_branch),
                  .is_control_insn(is_control_insn));
   assign test_regfile_we = regfile_we;
   assign test_regfile_wsel = wsel;
   assign test_nzp_we = nzp_we;

   //make a register
   wire [15:0] reg_rs_out, reg_rt_out, reg_rd_out;
   lc4_regfile regFile(.clk(clk),
                       .gwe(gwe),
                       .rst(rst),
                       .i_rs(r1sel),
                       .o_rs_data(reg_rs_out),
                       .i_rt(r2sel),
                       .o_rt_data(reg_rt_out),
                       .i_rd(wsel),
                       .i_wdata(test_regfile_data),
                       .i_rd_we(regfile_we));

    //make the alu jawn
    wire [15:0] alu_out;
    lc4_alu alu (.i_insn(i_cur_insn),
                 .i_pc(pc),
                 .i_r1data(reg_rs_out),
                 .i_r2data(reg_rt_out),
                 .o_result(alu_out));

    //LOAD + STORE
    wire [15:0] temp_dmem_addr, temp_dmem_data;
    assign o_dmem_we = i_cur_insn[15:12] == 4'b0111 ? 1'b1 : 1'b0;
    assign test_dmem_we = o_dmem_we;
    
    assign temp_dmem_addr = is_load || is_store ? alu_out : 16'b0;
    assign o_dmem_addr = temp_dmem_addr;
    assign test_dmem_addr = temp_dmem_addr;

    assign temp_dmem_data = is_load ? i_cur_dmem_data : (is_store ? reg_rt_out : 16'b0);
    assign test_dmem_data = temp_dmem_data;
    assign o_dmem_towrite = is_store ? reg_rt_out : 16'b0;

    //extra pc_plus_one for trap
    wire [15:0] pc_plus_one;
    cla16 pc_cla0 (.a(pc), .b(16'b0), .cin(1'd1), .sum(pc_plus_one));
    
    //figure out what needs to be stored on next pc cycle
    assign test_regfile_data = is_load ? test_dmem_data : (i_cur_insn[15:12] == 4'b1111 || i_cur_insn[15:12] == 4'b0100 ? pc_plus_one : alu_out);

    //BRANCH LOGIC
    wire [2:0] nzp, nzp_reg_out;
    assign nzp = $signed(test_regfile_data) < $signed(16'b0) ? 3'b100 : ($signed(test_regfile_data) > $signed(16'b0) ? 3'b001 : 3'b010);
    assign test_nzp_new_bits = nzp;
    //nzp register
    Nbit_reg #(3) nzp_reg (.in(nzp), .out(nzp_reg_out), .clk(clk), .we(nzp_we), .gwe(gwe), .rst(rst));
    
    wire should_branch;
    assign should_branch = (i_cur_insn[11] & nzp_reg_out[2]) | (i_cur_insn[10] & nzp_reg_out[1]) | (i_cur_insn[9] & nzp_reg_out[0]);
    wire [15:0] pc_offset, imm9, imm11;
    assign imm9 = {{7{i_cur_insn[8]}}, i_cur_insn[8:0]};
    assign imm11 = {{5{i_cur_insn[10]}}, i_cur_insn[10:0]};
    assign pc_offset = (should_branch == 1'b1 && is_branch) ? imm9 : (i_cur_insn[15:11] == 5'b11001 ? imm11 : 16'b0);
    
    //NEXT PC LOGIC
    wire [15:0] next_pc_temp_branch, next_pc_temp_rs, next_pc_temp_rti;
    cla16 pc_cla (.a(pc), .b(pc_offset), .cin(1'd1), .sum(next_pc_temp_branch));

    //compare to jsrr and jmpr mux
    assign next_pc_temp_rs =  (i_cur_insn[15:11] == 5'b11000 || i_cur_insn[15:11] == 5'b01000) ? reg_rs_out : next_pc_temp_branch;

    //finally if a trap and jsr use alu output
    assign next_pc_temp_rti = (i_cur_insn[15:12] == 4'b1111 ||  i_cur_insn[15:11] == 5'b01001) ? alu_out : next_pc_temp_rs;
    assign next_pc = (i_cur_insn[15:12] == 4'b1000) ? reg_rs_out : next_pc_temp_rti;
    assign test_cur_pc = pc;
    assign o_cur_pc = pc;

   /* Add $display(...) calls in the always block below to
    * print out debug information at the end of every cycle.
    * 
    * You may also use if statements inside the always block
    * to conditionally print out information.
    *
    * You do not need to resynthesize and re-implement if this is all you change;
    * just restart the simulation.
    */
`ifndef NDEBUG
   always @(posedge gwe) begin
      // $display("%d %h %h %h %h %h", $time, f_pc, d_pc, e_pc, m_pc, test_cur_pc);
      // if (o_dmem_we)
      //   $display("%d STORE %h <= %h", $time, o_dmem_addr, o_dmem_towrite);

      // Start each $display() format string with a %d argument for time
      // it will make the output easier to read.  Use %b, %h, and %d
      // for binary, hex, and decimal output of additional variables.
      // You do not need to add a \n at the end of your format string.
      // $display("%d ...", $time);

      // Try adding a $display() call that prints out the PCs of
      // each pipeline stage in hex.  Then you can easily look up the
      // instructions in the .asm files in test_data.

      // basic if syntax:
      // if (cond) begin
      //    ...;
      //    ...;
      // end

      // Set a breakpoint on the empty $display() below
      // to step through your pipeline cycle-by-cycle.
      // You'll need to rewind the simulation to start
      // stepping from the beginning.

      // You can also simulate for XXX ns, then set the
      // breakpoint to start stepping midway through the
      // testbench.  Use the $time printouts you added above (!)
      // to figure out when your problem instruction first
      // enters the fetch stage.  Rewind your simulation,
      // run it for that many nano-seconds, then set
      // the breakpoint.

      // In the objects view, you can change the values to
      // hexadecimal by selecting all signals (Ctrl-A),
      // then right-click, and select Radix->Hexadecimal.

      // To see the values of wires within a module, select
      // the module in the hierarchy in the "Scopes" pane.
      // The Objects pane will update to display the wires
      // in that module.

      //$display(); 
   end
`endif
endmodule
