module test_bench;

	// Inputs
	reg H_readyN;
	reg H_rsp;
	reg H_rstN;
	reg H_clk;
	reg [31:0] R_data;
	reg [31:0] i_add;
	reg i_WR;
	reg [2:0] i_size;
	reg [3:0] i_burst;
	reg busy;
	reg idle;
	reg [31:0] i_data;
	reg [4:0] beats;

	// Outputs
	wire [31:0] H_add;
	wire H_WR;
	wire [2:0] H_size;
	wire [3:0] H_burst;
	wire [1:0] H_trans;
	wire [31:0] W_data;

	// Instantiate the Unit Under Test (UUT)
	Master uut (
		.H_readyN(H_readyN), 
		.H_rsp(H_rsp), 
		.H_rstN(H_rstN), 
		.H_clk(H_clk), 
		.R_data(R_data), 
		.i_add(i_add), 
		.i_WR(i_WR), 
		.i_size(i_size), 
		.i_burst(i_burst), 
		.busy(busy), 
		.idle(idle),
		.i_data(i_data), 
		.H_add(H_add), 
		.H_WR(H_WR), 
		.H_size(H_size), 
		.H_burst(H_burst), 
		.H_trans(H_trans), 
		.W_data(W_data)
	);
    parameter SINGLE   = 3'b000;
    parameter INCR     = 3'b001;
    parameter WRAP4    = 3'b010;
    parameter INCR4    = 3'b011;
    parameter WRAP8    = 3'b100;
    parameter INCR8    = 3'b101;
    parameter WRAP16   = 3'b110;
    parameter INCR16   = 3'b111;
	
	initial begin
		// Initialize Inputs
		H_readyN = 0;
		H_rsp = 0;
		H_rstN = 0;
		H_clk = 0;
		R_data = 0;
		i_add = 0;
		i_WR = 0;
		i_size = 0;
		i_burst = 0;
		idle =0;
		busy = 0;
		i_data = 0;
		
		#1 H_rstN = 1;

		// Wait 100 ns for global reset to finish
	end
	
	task write_data;
	i_data [31:0] = $random % 1000;	
	endtask
	task start_address;
	i_add [31:0] = {$random} % 66;
	endtask
	task read_data;
	R_data [31:0] = $random % 1000;	
	endtask
	
	task burst_size;
	input [3:0] i_burst;
	  case (i_burst)
			 SINGLE: beats = 1;
			 INCR  : beats = 7;
			 WRAP4 : beats = 4;
			 INCR4 : beats = 4;
			 WRAP8 : beats = 8;
			 INCR8 : beats = 8;
			 WRAP16: beats = 16;
			 INCR16: beats = 16;
			default: beats = 0;
	   endcase
	endtask
	
 initial 
	begin
	  // @ ( H_clk);
		#2.5 ;//burst wrap4 size 4byte word
		H_readyN = 1;
		H_rsp = 0;
		i_size = 2;
		i_burst = 2;
		idle = 0;
		busy = 0;
		i_WR = 1;
		burst_size(i_burst);
		write_data();
		start_address();
		repeat (beats) begin @(negedge H_clk); write_data(); end //check 4 address
		// next incr4 4byte
		#3.5 ;
		start_address();
		H_readyN = 1;
		H_rsp = 0;
		i_size = 2;
		i_burst = 3;
		idle = 0;
		busy = 0;
		i_WR = 1;
		burst_size(i_burst);
		write_data();

		repeat (beats) begin @(negedge H_clk); write_data(); end//check 4 address
		
		#3.5 ;
		//wrap8
		start_address();
		H_readyN = 1;
		H_rsp = 0;
		i_size = 2;
		i_burst = 4;
		//idle = 0;
		busy = 0;
		i_WR = 1;
		burst_size(i_burst);
		write_data();
		fork
		repeat (beats+2) begin @(negedge H_clk); if (H_readyN)write_data(); end		//check 8 address
	//	#7.5 idle = 1;
		#5  H_readyN = 0;
		#25  H_readyN = 1;
		join
		//incr 8
		#3.5 ;
		start_address();
		H_readyN = 1;
		H_rsp = 0;
		i_size = 2;
		i_burst = 5;
		idle = 0;
		busy = 0;
		i_WR = 1;
		burst_size(i_burst);
		write_data();
		fork
		repeat (beats+3) begin @(negedge H_clk); if (!idle) write_data(); end//check 8 address
		# 10 idle = 1;
		# 10.1 H_readyN = 0;
		# 30 H_readyN = 1;
		#  20 idle = 0;
		join
		//wrap 16
		#3.5 ;
		start_address();
		H_readyN = 1;
		H_rsp = 0;
		i_size = 2;
		i_burst = 6;
		idle = 0;
		busy = 0;
		i_WR = 1;
		burst_size(i_burst);
		write_data();
		repeat (beats) begin @(negedge H_clk); write_data(); end //check 16 address
		
		#3.5 ;
		start_address();
		H_readyN = 1;
		H_rsp = 0;
		i_size = 2;
		i_burst = 7;
		idle = 0;
		busy = 0;
		i_WR = 1;
		burst_size(i_burst);
		write_data();
		fork
		repeat (beats+3) begin @(negedge H_clk); if (!busy) write_data(); end //check 16 address
		#2.5 busy = 1;
		#2.6 H_readyN = 0;
		#33 H_readyN = 1;
		#15 busy = 0;
		join
		#3.5 ;
		start_address();
		H_readyN = 1;
		H_rsp = 0;
		i_size = 2;
		i_burst = SINGLE;
		idle = 0;
		busy = 0;
		i_WR = 1;
		burst_size(i_burst);
		write_data();
		repeat (beats) begin @(negedge H_clk); write_data(); end //check 16 address
		
		start_address();
		H_readyN = 1;
		H_rsp = 0;
		i_size = 2;
		i_burst = 1;
		idle = 0;
		busy = 0;
		i_WR = 1;
		burst_size(i_burst);
		write_data();

		repeat (beats) begin @(negedge H_clk); write_data(); end
		
		
	$finish;
	end
	
  always #5 H_clk =~H_clk;    
endmodule
