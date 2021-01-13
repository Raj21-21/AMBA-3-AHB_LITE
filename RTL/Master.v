`timescale 1ns / 1ps

// Create Date:    14:11:45 08/25/2020 
// Design Name: 
// Module Name:    maste_1 

module Master #(parameter data_size = 32)(H_readyN,H_rsp,H_rstN,H_clk,R_data,//master input
				i_add,i_WR,i_size,i_burst,idle,busy,i_data,   //test input
				H_add,H_WR,H_size,H_burst,H_trans,W_data);    //master out
	
//tranfer responce from slave
input H_readyN;
input H_rsp;

//global signal
input H_rstN;
input H_clk;

//data from slave
input   [data_size-1 :0] R_data;

//address and control
output  [31:0] H_add;
output         H_WR;
output  [2:0]  H_size;
output  [3:0]  H_burst;
output  [1:0]  H_trans;

//data to slave
output  [data_size-1:0] W_data;

//Master internal input signals
input   [31:0] i_add;    // i_add,i_WR,i_size,i_burst,i_trans,i_data,
input          i_WR;
input   [2:0]  i_size;
input   [2:0]  i_burst;
//input [1:0]  i_trans;
input          busy;
input          idle;
input   [data_size-1:0] i_data;

//reg     [31:0] cal_add;//calculated 
reg     [1:0]  i_trans;
reg     [data_size-1:0] data_1;
reg     [31:0] add;
reg            WR;
reg     [2:0]  size;
reg     [3:0]  burst;
//reg     [1:0]  trans;
reg     [data_size-1:0] data;
reg     [6:0]  cal_size;
reg     [4:0]  cal_burst; //burst for address range calculation
//1kB = 8*1kb = 2**3(this is to store data) * 2**10(this is for pointing data)
// so every 1 address store 8 bit of data so actual address size is [9:0]  ie 2**10 
reg     [12:0] initial_add;
reg     [12:0] trans_size; //max 1024       
reg     [12:0] start_add;
reg     [12:0] wrap_bound;
//recieve  slg
reg     [data_size-1:0]rec_data;
reg     [3:0] counter;
reg     [3:0] shifty;
reg     [3:0] temp_counter;
reg     [1:0] trans_next;

	parameter HTRANS_IDLE    = 2'b00;
	parameter HTRANS_BUSY    = 2'b01; 
	parameter HTRANS_NONSEQ  = 2'b10;
	parameter HTRANS_SEQ     = 2'b11;

	parameter SINGLE   = 3'b000;
	parameter INCR     = 3'b001;
	parameter WRAP4    = 3'b010;
	parameter INCR4    = 3'b011;
	parameter WRAP8    = 3'b100;
	parameter INCR8    = 3'b101;
	parameter WRAP16   = 3'b110;
	parameter INCR16   = 3'b111;
	 
	parameter BYTE     = 3'b000;
	parameter BYTE_2   = 3'b001;
	parameter BYTE_4   = 3'b010;
	parameter BYTE_8   = 3'b011;
	parameter BYTE_16  = 3'b100;
	parameter BYTE_32  = 3'b101;
	parameter BYTE_64  = 3'b110;
	parameter BYTE_128 = 3'b111;
	//parameter data_size = cal_size<<3;


assign H_WR     = WR;
assign H_size   = size;
assign H_add    = add;  /////busy check
assign H_burst  = burst;
assign H_trans  = i_trans;
assign W_data   =  data  ;

always @ (negedge H_clk)
	rec_data <= R_data;

always @ (posedge H_clk , negedge H_rstN)
	begin
		if (!H_rstN)
			begin		
						WR     <= 1'b0; 
						size   <= 3'b0;
						burst  <= 4'b0;		
						data   <= 0;
						data_1 <= 0;
			end 
		else if (H_readyN)////responce check
			begin			
						WR     <= i_WR; 
						size   <= i_size;
						burst  <= i_burst;		
				if (i_WR && !busy)
					begin    	//data is chnaging in busy so i need control here
						data_1 <= i_data;//one cycle late data 
						data   <= data_1;
					end
				else		
						data   <= data_1; //also make it xx
			end
		else 	
			begin
						data_1 <= data_1; //one cycle late data 
						data   <= data;
			end
	end
	
always @ (posedge H_clk or negedge H_rstN)
begin
if (!H_rstN)                                                            
																		        add  <= 32'b0;
else if (H_readyN && trans_next == HTRANS_NONSEQ)   
	begin								 
																		initial_add  <= i_add [12:0];
																		        add  <= i_add;
																		temp_counter <= counter;
	end
else if(H_readyN &&(!busy) && trans_next == HTRANS_SEQ && i_burst == INCR )  //check dependency on H_readyN and also restrict 1024KB size for future
																		        add  <= add + cal_size;

else if(H_readyN &&(!busy) && temp_counter != 0 && trans_next == HTRANS_SEQ 
		&& (i_burst == WRAP4 | i_burst == WRAP8 | i_burst == WRAP16 ))
	begin 								
																		temp_counter <= temp_counter -1;
		if((add[12:0]+cal_size) >= wrap_bound)
																		        add  <={add[31:13],((add[12:0]+ cal_size) - trans_size)};
		else								 
																		        add  <={add[31:13],(add[12:0] + cal_size)};//size
	end		  
else if(H_readyN &&(!busy) && temp_counter != 0 && trans_next == HTRANS_SEQ 
		&& (i_burst == INCR4 | i_burst == INCR8 | i_burst == INCR16 ))
	begin	  		
																		        add  <= (add + cal_size);  //size
																		temp_counter <= temp_counter -1;
	end
else if ((i_burst == SINGLE)||(i_trans == HTRANS_IDLE)) 
																		temp_counter <= 0;
else
	begin
																		         add <= add;
																		temp_counter <= temp_counter;
	end
end


 
always @(posedge H_clk or negedge H_rstN )
	if (!H_rstN)        i_trans <= HTRANS_IDLE;//i_trans <= HTRANS_IDLE;
	else if (idle)      i_trans <= HTRANS_IDLE;
	else if (busy)      i_trans <= HTRANS_BUSY;
	else if (!H_readyN) i_trans <= i_trans;
	else                i_trans <= trans_next;
		
always @(i_trans,temp_counter,busy,idle,burst,H_rsp) // i want bust that should be clk dependent
begin
//i_trans = 2'bx;
 case(i_trans)
	HTRANS_IDLE  :				
																		trans_next = HTRANS_NONSEQ;  //ideal slg for stay in ideal mode we can use 
	HTRANS_BUSY  :	if (!busy)	
																		trans_next = HTRANS_SEQ; 
					else		
																		trans_next = HTRANS_BUSY;
	HTRANS_NONSEQ:	if((burst != SINGLE))    //&&(i_burst != INCR) i removed it 
																		trans_next = HTRANS_SEQ;  // change (!busy && H_readyN &&(i_burst != SINGLE)&&(i_burst != INCR)
					else if (!H_readyN && H_rsp) 					    
																		trans_next = HTRANS_IDLE;											    	
					else												trans_next = HTRANS_NONSEQ;
	HTRANS_SEQ   :	begin 
						if(burst != SINGLE && burst != INCR) 
							if (temp_counter == 0)
																		trans_next = HTRANS_NONSEQ;
							else
																		trans_next = HTRANS_SEQ;
						else if (!H_readyN && H_rsp) 				    
																		trans_next = HTRANS_IDLE;
						else 					   
																		trans_next = HTRANS_SEQ;
					end
 endcase
end		
			
always @(i_burst)  //used h_clk multiple driver problem
	case (i_burst)
		WRAP4 : begin counter = 4'd3; cal_burst = 5'd4;  end
		INCR4 : begin counter = 4'd3; cal_burst = 5'd0;  end 
		WRAP8 : begin counter = 4'd7; cal_burst = 5'd8;  end
		INCR8 : begin counter = 4'd7; cal_burst = 5'd0;  end 
		WRAP16: begin counter = 4'd15;cal_burst = 5'd16; end
		INCR16: begin counter = 4'd15;cal_burst = 5'd0;  end 
		default:begin counter = 4'd0; cal_burst = 5'd0;  end 
	endcase
	
//combination ADDRESS logic calculation
always @ (cal_burst,i_size,initial_add,shifty,cal_size)
begin 
	trans_size = cal_burst * cal_size;
	start_add  = ((initial_add >> shifty)*(trans_size)); //synthesis doesn't provide divide operator
	wrap_bound = start_add + trans_size ;
end
	
always @(i_size)    //cal size of transfer
 case(i_size)
	BYTE   : cal_size = 1;
	BYTE_2 : cal_size = 2;
	BYTE_4 : cal_size = 4;
	BYTE_8 : cal_size = 8;
	BYTE_16: cal_size = 16;
	BYTE_32: cal_size = 32;
	BYTE_64: cal_size = 64;
	BYTE_128:cal_size = 128;
	default: cal_size = 0;
 endcase
 
always @(trans_size)   //trans_size always  inside {8,16,32,64,128,256,512,1024,4096,8139}
	case(1'b1)  //one hot
		trans_size[3]: shifty = 3;//8
		trans_size[4]: shifty = 4; 
		trans_size[5]: shifty = 5;
		trans_size[6]: shifty = 6;
		trans_size[7]: shifty = 7;
		trans_size[8]: shifty = 8;//256
		trans_size[9]: shifty = 9;
		trans_size[10]:shifty = 10;//1024
	//	trans_size[11]:shifty = 11;
	//	trans_size[12]:shifty = 12;
		default:shifty =0;
	endcase
	
endmodule
