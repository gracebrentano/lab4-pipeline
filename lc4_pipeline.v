  
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
   
   `include "include/lc4_prettyprint_errors.v"
   
   // By default, assign LEDs to display switch inputs to avoid warnings about
   // disconnected ports. Feel free to use this for debugging input/output if
   // you desire.
   assign led_data = switch_data;

   // pc wires attached to the PC register's ports
   wire [15:0]   pc;      // Current program counter (read out from pc_reg)
   wire [15:0]   next_pc; // Next program counter (you compute this and feed it into next_pc)

   //FETCH
   Nbit_reg #(16, 16'h8200) pc_reg (.in(next_pc), .out(pc), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   assign o_cur_pc = pc;

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
   
   //DECODE STAGE
   //Save all relevant decoded values in registers
   //so we only need to decode an isns once
   wire [15:0]   reg_insn_pc_out, reg_insn_ir_out;
   wire [2:0] reg_insn_r1sel_out, reg_insn_r2sel_out, reg_insn_wsel_out;
   wire [1:0] reg_insn_stall_out;
   wire reg_insn_we_out, reg_insn_is_load_out, reg_insn_is_store_out, reg_insn_is_branch_out, reg_insn_nzp_we_out, branch_stall;
   Nbit_reg #(16, 16'h8200) reg_insn_pc (.in(pc), .out(reg_insn_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) reg_insn_ir (.in(branch_stall ? 16'h0000 : i_cur_insn), .out(reg_insn_ir_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'h000) reg_insn_r1sel (.in(r1sel), .out(reg_insn_r1sel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'h000) reg_insn_r2sel (.in(r2sel), .out(reg_insn_r2sel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'h000) reg_insn_wsel (.in(wsel), .out(reg_insn_wsel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_insn_regfile_we (.in(branch_stall ? 1'h0 : regfile_we), .out(reg_insn_we_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_insn_nzp_we (.in(branch_stall ? 1'h0 : nzp_we), .out(reg_insn_nzp_we_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_insn_is_load (.in(is_load), .out(reg_insn_is_load_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_insn_is_store (.in(is_store), .out(reg_insn_is_store_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_insn_is_branch (.in(is_branch), .out(reg_insn_is_branch_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10) reg_insn_stall (.in(branch_stall ? 2'b10 : 2'b00), .out(reg_insn_stall_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

   //register file
   wire [15:0] reg_rs_out, reg_rt_out, reg_rd_out, rs_wd_bypassed, rt_wd_bypassed, pred_cur_alu_insn;
   wire should_wx_bypass_rs, should_wx_bypass_rt, should_wd_bypass_rs, should_wd_bypass_rt;
   lc4_regfile regFile(.clk(clk),
                       .gwe(gwe),
                       .rst(rst),
                       .i_rs(reg_insn_r1sel_out),
                       .o_rs_data(reg_rs_out),
                       .i_rt(reg_insn_r2sel_out),
                       .o_rt_data(reg_rt_out),
                       .i_rd(reg_w_wsel_out),
                       .i_wdata(test_regfile_data),
                       .i_rd_we(reg_w_we_out));
   //Handle WD Bypass
   assign rs_wd_bypassed = should_wd_bypass_rs ? test_regfile_data : reg_rs_out;
   assign rt_wd_bypassed = should_wd_bypass_rt ? test_regfile_data : reg_rt_out;  

   //Talu EXECUTE STAGE
   wire [15:0]   reg_alu_pc_out, reg_alu_ir_out, reg_alu_rs_out, reg_alu_rt_out;
   wire [2:0] reg_alu_r1sel_out, reg_alu_r2sel_out, reg_alu_wsel_out;
   wire [1:0] reg_alu_stall_out;
   wire reg_alu_is_load_out, reg_alu_is_store_out, reg_alu_is_branch_out, reg_alu_we_out, reg_alu_nzp_we_out;
   Nbit_reg #(16, 16'h8200) reg_alu_pc (.in(reg_insn_pc_out), .out(reg_alu_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) reg_alu_ir (.in(branch_stall ? 16'h0000 : reg_insn_ir_out), .out(reg_alu_ir_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) reg_alu_rs (.in(rs_wd_bypassed), .out(reg_alu_rs_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(16, 16'h0000) reg_alu_rt (.in(rt_wd_bypassed), .out(reg_alu_rt_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'h000) reg_alu_r1sel (.in(reg_insn_r1sel_out), .out(reg_alu_r1sel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'h000) reg_alu_r2sel (.in(reg_insn_r2sel_out), .out(reg_alu_r2sel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(3, 3'h000) reg_alu_wsel (.in(reg_insn_wsel_out), .out(reg_alu_wsel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_alu_regfile_we (.in(branch_stall ? 1'h0 : reg_insn_we_out), .out(reg_alu_we_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_alu_nzp_we (.in(branch_stall ? 1'h0 : reg_insn_nzp_we_out), .out(reg_alu_nzp_we_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_alu_is_load (.in(reg_insn_is_load_out), .out(reg_alu_is_load_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_alu_is_store (.in(reg_insn_is_store_out), .out(reg_alu_is_store_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(1, 1'h0) reg_alu_is_branch (.in(reg_insn_is_branch_out), .out(reg_alu_is_branch_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
   Nbit_reg #(2, 2'b10) reg_alu_stall (.in(branch_stall ? 2'b10 : reg_insn_stall_out), .out(reg_alu_stall_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

  //make the alu jawn
  wire [15:0] alu_out, rs_mx_bypassed, rt_mx_bypassed, pred_cur_mem_insn;
  wire should_mx_bypass_rs, should_mx_bypass_rt, should_branch;

  assign rs_mx_bypassed = should_mx_bypass_rs ? reg_mem_alu_out : (should_wx_bypass_rs ? reg_w_alu_out  : reg_alu_rs_out);
  assign rt_mx_bypassed = should_mx_bypass_rt ? reg_mem_alu_out : (should_wx_bypass_rt ? reg_w_alu_out  : reg_alu_rt_out);   
  lc4_alu alu (.i_insn(reg_alu_ir_out),
               .i_pc(reg_alu_pc_out),
               .i_r1data(rs_mx_bypassed),
               .i_r2data(rt_mx_bypassed),
               .o_result(alu_out));

  //BRANCH LOGIC
  //Bypass NZP bits to BR if needed
  wire [2:0] nzp_bypass, nzp_mem_bypass, nzp_mem_bypass_val;
  assign nzp_mem_bypass_val = $signed(reg_mem_alu_out) < $signed(16'b0) ? 3'b100 : ($signed(reg_mem_alu_out) > $signed(16'b0) ? 3'b001 : 3'b010);
  assign nzp_mem_bypass = (reg_alu_is_branch_out & reg_w_nzp_we_out) ? test_nzp_new_bits : nzp_reg_out;
  assign nzp_bypass = (reg_alu_is_branch_out & reg_mem_nzp_we_out) ? nzp_mem_bypass_val : nzp_mem_bypass;
  
  assign should_branch = reg_alu_is_branch_out && (reg_alu_ir_out[11] & nzp_bypass[2]) | (reg_alu_ir_out[10] & nzp_bypass[1]) | (reg_alu_ir_out[9] & nzp_bypass[0]);
  assign branch_stall = should_branch || reg_alu_ir_out[15:12] == 4'b1111 || reg_alu_ir_out[15:12] == 4'b1100 || reg_alu_ir_out[15:12] == 4'b1000 || reg_alu_ir_out[15:12] == 4'b0100;
  
  //NEXT PC SETUP
  wire [15:0] pc_offset, pc_branch_adjust, imm9, imm11, next_pc_temp_branch, next_pc_temp_rs, next_pc_temp_rti, next_pc_temp_final;
  assign imm9 = {{7{reg_alu_ir_out[8]}}, reg_alu_ir_out[8:0]};
  assign imm11 = {{5{reg_alu_ir_out[10]}}, reg_alu_ir_out[10:0]};
  assign pc_offset = should_branch ? imm9 : (reg_alu_ir_out[15:11] == 5'b11001 ? imm11 : 16'b0);
  cla16 pc_cla_a (.a(pc_offset), .b(branch_stall ? 16'hFFFE : 1'b0), .cin(1'd0), .sum(pc_branch_adjust));
  cla16 pc_cla (.a(o_cur_pc), .b(pc_branch_adjust), .cin(1'd1), .sum(next_pc_temp_branch));

  //NEXT PC DECISION
  //compare to jsrr and jmpr mux
  //finally if a trap and jsr use alu output
  assign next_pc_temp_rs =  (reg_alu_ir_out[15:11] == 5'b11000 || reg_alu_ir_out[15:11] == 5'b01000) ? rs_mx_bypassed : next_pc_temp_branch;
  assign next_pc_temp_rti = (reg_alu_ir_out[15:12] == 4'b1111 ||  reg_alu_ir_out[15:11] == 5'b01001) ? alu_out : next_pc_temp_rs;
  assign next_pc_temp_final = (reg_alu_ir_out[15:12] == 4'b1000) ? rs_mx_bypassed : next_pc_temp_rti;
  assign next_pc = next_pc_temp_final;

  //HANDLE BRANCH MISPREDICTION
   //assign pred_cur_mem_insn = (test_stall == 2'b10) && branch_mispredict ? 16'h0000 : reg_alu_ir_out;

  //MEMORY STAGE
  wire [15:0]   reg_mem_pc_out, reg_mem_ir_out, reg_mem_alu_out, reg_mem_rt_out, reg_mem_rs_out;
  wire [2:0] reg_mem_r1sel_out, reg_mem_r2sel_out, reg_mem_wsel_out;
  wire [1:0] reg_mem_stall_out;
  wire reg_mem_is_load_out, reg_mem_is_store_out, reg_mem_is_branch_out, reg_mem_we_out, reg_mem_nzp_we_out;
  Nbit_reg #(16, 16'h8200) reg_mem_pc (.in(reg_alu_pc_out), .out(reg_mem_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(16, 16'h0000) reg_mem_ir (.in(reg_alu_ir_out), .out(reg_mem_ir_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(16, 16'h0000) reg_mem_alu (.in(alu_out), .out(reg_mem_alu_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(16, 16'h0000) reg_mem_rs (.in(reg_alu_rs_out), .out(reg_mem_rs_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(16, 16'h0000) reg_mem_rt (.in(reg_alu_rt_out), .out(reg_mem_rt_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(3, 3'h000) reg_mem_r1sel (.in(reg_alu_r1sel_out), .out(reg_mem_r1sel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(3, 3'h000) reg_mem_r2sel (.in(reg_alu_r2sel_out), .out(reg_mem_r2sel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(3, 3'h000) reg_mem_wsel (.in(reg_alu_wsel_out), .out(reg_mem_wsel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_mem_nzp_we (.in(reg_alu_nzp_we_out), .out(reg_mem_nzp_we_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_mem_regfile_we (.in(reg_alu_we_out), .out(reg_mem_we_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_mem_is_load (.in(reg_alu_is_load_out), .out(reg_mem_is_load_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_mem_is_store (.in(reg_alu_is_store_out), .out(reg_mem_is_store_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_mem_is_branch (.in(reg_alu_is_branch_out), .out(reg_mem_is_branch_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(2, 2'b10) reg_mem_stall (.in(reg_alu_stall_out), .out(reg_mem_stall_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
 
  //MX BYPASS
  assign should_mx_bypass_rs = (reg_alu_r1sel_out == reg_mem_wsel_out && reg_mem_we_out && reg_mem_stall_out == 1'b0) ? 1'b1 : 1'b0;
  assign should_mx_bypass_rt = (reg_alu_r2sel_out == reg_mem_wsel_out && reg_mem_we_out && reg_mem_stall_out == 1'b0) ? 1'b1 : 1'b0;


  //Handle WM bypass
  wire [15:0]  wsel_wm_bypassed;
  wire should_wm_bypass_wsel;
  
  // Might be test_regfile_wsel instead of test_regfile_data
  // assign wsel_wm_bypassed = should_wm_bypass_wsel ? test_regfile_wsel : reg_mem_wsel_out;
  assign wsel_wm_bypassed = should_wm_bypass_wsel ? test_regfile_data : reg_mem_alu_out;

  //Memory Operations
  wire [15:0] temp_dmem_data; 
  assign o_dmem_we = reg_mem_ir_out[15:12] == 4'b0111 ? 1'b1 : 1'b0;
  assign o_dmem_addr = reg_mem_is_load_out || reg_mem_is_store_out ? reg_mem_alu_out : 16'b0;
  assign o_dmem_towrite = reg_mem_is_store_out ? reg_mem_rt_out : 16'b0;
  assign temp_dmem_data = reg_mem_is_load_out ? i_cur_dmem_data : (reg_mem_is_store_out ? reg_mem_rt_out : 16'b0);
    

  //WRITE STAGE
  wire [15:0]   reg_w_pc_out, reg_w_ir_out, reg_w_alu_out, reg_w_data_out, reg_w_rs_out, reg_w_data_addr_out;
  wire [2:0] reg_w_r1sel_out, reg_w_r2sel_out, reg_w_wsel_out;
  wire [1:0] reg_w_stall_out;
  wire reg_w_is_load_out, reg_w_is_branch_out, reg_w_we_out, reg_w_nzp_we_out, reg_w_dmem_we_out;
  Nbit_reg #(16, 16'h8200) reg_w_pc (.in(reg_mem_pc_out), .out(reg_w_pc_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(16, 16'h0000) reg_w_ir (.in(reg_mem_ir_out), .out(reg_w_ir_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(16, 16'h0000) reg_w_rs (.in(reg_mem_rs_out), .out(reg_w_rs_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  // Nbit_reg #(16, 16'h0000) reg_w_alu (.in(reg_mem_alu_out), .out(reg_w_alu_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(16, 16'h0000) reg_w_alu (.in(wsel_wm_bypassed), .out(reg_w_alu_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(16, 16'h0000) reg_w_data_addr (.in(o_dmem_addr), .out(reg_w_data_addr_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(16, 16'h0000) reg_w_data (.in(temp_dmem_data), .out(reg_w_data_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(3, 3'h000) reg_w_r1sel (.in(reg_mem_r1sel_out), .out(reg_w_r1sel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(3, 3'h000) reg_w_r2sel (.in(reg_mem_r2sel_out), .out(reg_w_r2sel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(3, 3'h000) reg_w_wsel (.in(reg_mem_wsel_out), .out(reg_w_wsel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  // Nbit_reg #(3, 3'h000) reg_w_wsel (.in(wsel_wm_bypassed), .out(reg_w_wsel_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_w_nzp_we (.in(reg_mem_nzp_we_out), .out(reg_w_nzp_we_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_w_regfile_we (.in(reg_mem_we_out), .out(reg_w_we_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_w_is_load (.in(reg_mem_is_load_out), .out(reg_w_is_load_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_w_is_branch (.in(reg_mem_is_branch_out), .out(reg_w_is_branch_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(1, 1'h0) reg_w_dmem_we (.in(o_dmem_we), .out(reg_w_dmem_we_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));
  Nbit_reg #(2, 2'b10) reg_w_stall (.in(reg_mem_stall_out), .out(reg_w_stall_out), .clk(clk), .we(1'b1), .gwe(gwe), .rst(rst));

  //WX BYPASS
  assign should_wx_bypass_rs = (reg_alu_r1sel_out == reg_w_wsel_out && reg_w_we_out && reg_w_stall_out == 1'b0) ? 1'b1 : 1'b0;
  assign should_wx_bypass_rt = (reg_alu_r2sel_out == reg_w_wsel_out && reg_w_we_out && reg_w_stall_out == 1'b0) ? 1'b1 : 1'b0;

  //WD BYPASS
  assign should_wd_bypass_rs = (reg_insn_r1sel_out == reg_w_wsel_out && reg_w_we_out && reg_w_stall_out == 1'b0) ? 1'b1 : 1'b0;
  assign should_wd_bypass_rt = (reg_insn_r2sel_out == reg_w_wsel_out && reg_w_we_out && reg_w_stall_out == 1'b0) ? 1'b1 : 1'b0;

  //WM BYPASS
  // Unlike other bypasses, only bypass if write destination matches store
  // data input.
  assign should_wm_bypass_wsel = (reg_mem_wsel_out == reg_w_wsel_out && reg_w_we_out && reg_w_stall_out == 1'b0) ? 1'b1 : 1'b0;  

  //TEST WIRE ASSIGNMENT
  wire [15:0] pc_plus_one; //extra pc_plus_one for trap
  cla16 pc_cla0 (.a(reg_w_pc_out), .b(16'b0), .cin(1'd1), .sum(pc_plus_one));
  assign test_regfile_data = reg_w_is_load_out ? reg_w_data_out : (reg_w_ir_out[15:12] == 4'b1111 || reg_w_ir_out[15:12] == 4'b0100 ? pc_plus_one : reg_w_alu_out);
  assign test_cur_pc = reg_w_pc_out;
  assign test_cur_insn = reg_w_ir_out;
  assign test_regfile_we = reg_w_we_out;
  assign test_regfile_wsel = reg_w_wsel_out;
  assign test_nzp_we = reg_w_nzp_we_out;
  assign test_dmem_we = reg_w_dmem_we_out;
  assign test_dmem_addr = reg_w_data_addr_out;
  assign test_dmem_data = reg_w_data_out;
  assign test_stall = reg_w_stall_out;

  //NZP
  wire [2:0] nzp_reg_out;
  assign test_nzp_new_bits = $signed(test_regfile_data) < $signed(16'b0) ? 3'b100 : ($signed(test_regfile_data) > $signed(16'b0) ? 3'b001 : 3'b010);
  Nbit_reg #(3) nzp_reg (.in(test_nzp_new_bits), .out(nzp_reg_out), .clk(clk), .we(reg_w_nzp_we_out), .gwe(gwe), .rst(rst));

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
      //USE THESE FOR DEBUGGING
      // $display("------------%h--------------------", test_cur_pc);

      // $display("***FETCH***");
      // pinstr(i_cur_insn);
      // $display("\n\tPC=%h", o_cur_pc);

      // $display("\n***DECODE***");
      // pinstr(reg_insn_ir_out);
      // $display("\n\tPC=%h \n\tRS=%d-%d \n\tRT=%d-%d \n\tRD=%d", reg_insn_pc_out, reg_insn_r1sel_out, rs_wd_bypassed, reg_insn_r2sel_out, rt_wd_bypassed, reg_insn_wsel_out);

      // $display("\n***EXECUTE***");
      // pinstr(reg_alu_ir_out);
      // $display("\n\tPC=%h \n\tRS=%d-%d \n\tRT=%d-%d \n\tRD=%d \n\tData=%d \n\tBR=%d", reg_alu_pc_out, reg_alu_r1sel_out, rs_mx_bypassed, reg_alu_r2sel_out, rt_mx_bypassed, reg_alu_wsel_out, alu_out, branch_stall);

      // $display("\n***MEM***");
      // pinstr(reg_mem_ir_out);
      // $display("\n\tPC=%h \n\tRS=%d \n\tRT=%d \n\tRD=%d \n\tData=%d", reg_mem_pc_out, reg_mem_r1sel_out, reg_mem_r2sel_out, reg_mem_wsel_out, reg_mem_alu_out);
      
      // $display("\n***WRITE***");
      // pinstr(reg_w_ir_out);
      // $display("\n\tPC=%h \n\tRS=%d \n\tRT=%d \n\tRD=%d \n\tData=%d \n\tNZP=%d \n\tnzpReg=%d", reg_w_pc_out, reg_w_r1sel_out, reg_w_r2sel_out, reg_w_wsel_out, test_regfile_data, test_nzp_new_bits, nzp_reg_out);

      // $display("\n-----------------------------------\n");
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
