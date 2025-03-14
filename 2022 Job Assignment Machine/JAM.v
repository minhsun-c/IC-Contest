module JAM (
	input 				CLK,
	input 				RST,
	output reg 	[2:0] 	W,
	output reg 	[2:0] 	J,
	input 		[6:0] 	Cost,
	output reg 	[3:0] 	MatchCount,
	output reg 	[9:0] 	MinCost,
	output reg 			Valid 
);

parameter 	InitState		= 3'd0,
			PivotState		= 3'd1,
		 	SearchMinState	= 3'd2,
			ReverseState	= 3'd3,
		 	GetCostState	= 3'd4,
		 	MinCostState	= 3'd5,
		 	EndState		= 3'd6
			;

reg 	[2:0] state, nx_state;

reg 	[2:0] num 	[0:7];
reg 	[6:0] cost 	[0:7];

wire    [31:0]	nums = {
	1'b0, num[0], 1'b0, num[1], 1'b0, num[2], 1'b0, num[3],
	1'b0, num[4], 1'b0, num[5], 1'b0, num[6], 1'b0, num[7]
};

wire 	[9:0] CurCost = 
	cost[0] + cost[1]+ cost[2]+ cost[3]+ 
	cost[4] + cost[5]+ cost[6]+ cost[7];

reg 	[2:0] 	pivot_n;
reg 	[3:0] 	case_n;

reg 	[3:0] 	counter;
reg 	[2:0] 	min_num, min_idx;
wire 	[2:0] 	num_cnt = num[counter];
always @(posedge CLK or posedge RST) begin
	if (RST) begin
		for (integer i=0; i<8; i=i+1) 
        	num[i] <= i;
		counter <= 4'd0;
	end
	else if (state == InitState) begin
		if (counter <= 4'd7) begin
			W <= counter;
			J <= num[counter[2:0]];
		end
		if (counter >= 4'd1) begin
			cost[counter - 4'd1] <= Cost;
		end
		counter <= counter + 4'd1;
		MinCost <= cost[0] + cost[1]+ cost[2]+ cost[3]+ 
					cost[4] + cost[5]+ cost[6]+ cost[7];
		MatchCount <= 4'd1;
	end
	else if (state == PivotState) begin /* Algo Step. 1 */
		if (num[6] < num[7]) begin 
			case_n <= 4'd6;
			pivot_n <= 3'd6; counter <= 4'd7; min_idx <= 3'd7; min_num <= num[7]; 
		end
		else if (num[5] < num[6]) begin case_n <= 4'd5;
			pivot_n <= 3'd5; counter <= 4'd6; min_idx <= 3'd6; min_num <= num[6];  
		end 
		else if (num[4] < num[5]) begin case_n <= 4'd4;
			pivot_n <= 3'd4; counter <= 4'd5; min_idx <= 3'd5; min_num <= num[5];  
		end 
		else if (num[3] < num[4]) begin case_n <= 4'd3;
			pivot_n <= 3'd3; counter <= 4'd4; min_idx <= 3'd4; min_num <= num[4];  
		end 
		else if (num[2] < num[3]) begin case_n <= 4'd2;
			pivot_n <= 3'd2; counter <= 4'd3; min_idx <= 3'd3; min_num <= num[3];  
		end 
		else if (num[1] < num[2]) begin case_n <= 4'd1;
			pivot_n <= 3'd1; counter <= 4'd2; min_idx <= 3'd2; min_num <= num[2];  
		end 
		else if (num[0] < num[1]) begin case_n <= 4'd0;
			pivot_n <= 3'd0; counter <= 4'd1; min_idx <= 3'd1; min_num <= num[1];  
		end 
		else begin case_n <= 4'd8;
			pivot_n <= 3'd7; counter <= 4'd7; min_idx <= 3'd7; min_num <= num[7]; 
		end
	end
	else if (state == SearchMinState) begin /* Algo Step. 2: smallest greater than pivot */
		if (counter <= 4'd7) begin
			if (num[counter] < min_num && num[counter] > num[pivot_n]) begin
				min_num <= num[counter];
				min_idx <= counter;
			end 
			else begin
				min_num <= min_num;
				min_idx <= min_idx;
			end
		end
		else if (counter == 4'd8) begin
			num[pivot_n] <= num[min_idx];
			num[min_idx] <= num[pivot_n];
		end
		else begin
			
		end
		counter <= counter + 4'd1;
	end
	else if (state == ReverseState) begin
		case (pivot_n)
			3'd0: begin
				for (integer i=1; i<8; i=i+1) num[i] <= num[8-i];
			end 
			3'd1: begin
				for (integer i=2; i<8; i=i+1) num[i] <= num[9-i];
			end 
			3'd2: begin
				for (integer i=3; i<8; i=i+1) num[i] <= num[10-i];
			end 
			3'd3: begin
				for (integer i=4; i<8; i=i+1) num[i] <= num[11-i];
			end 
			3'd4: begin
				for (integer i=5; i<8; i=i+1) num[i] <= num[12-i];
			end 
			3'd5: begin
				for (integer i=6; i<8; i=i+1) num[i] <= num[13-i];
			end 
			default: begin
				
			end
		endcase
		counter <= 4'd0;
	end
	else if (state == GetCostState) begin
		if (counter < 4'd8) begin
			W <= counter;
			J <= num[counter];
		end
		else begin
			
		end
		if (counter > 0 && counter < 4'd9) begin
			cost[counter - 4'd1] <= Cost;
		end
		else begin
			
		end
		counter <= counter + 4'd1;
	end
	else if (state == MinCostState) begin
		if (MinCost > CurCost) begin
			MinCost <= CurCost;
			MatchCount <= 4'd1;
		end
		else if (MinCost == CurCost) begin
			MinCost <= MinCost;
			MatchCount <= MatchCount + 4'd1;
		end
		else begin
			MinCost <= MinCost;
			MatchCount <= MatchCount;
		end
		$display("nums: [%8h]", nums);
	end
	else begin
		
	end

end

always @(posedge CLK or posedge RST) begin
	if (RST) state <= InitState;
	else state <= nx_state;
end

always @(*) begin
	if (state == InitState) begin 
		if (counter == 4'd9) nx_state = PivotState;
		else nx_state = InitState;
	end
	else if (state == PivotState) begin 
		if (pivot_n == 3'd7) nx_state = EndState;
		else nx_state = SearchMinState;
	end
	else if (state == SearchMinState) begin
		if (counter == 4'd10) nx_state = ReverseState;
		else nx_state = nx_state;
	end
	else if (state == ReverseState) begin
		nx_state = GetCostState;
	end
	else if (state == GetCostState) begin
		if (counter == 4'd9)
			nx_state = MinCostState;
		else 
			nx_state = nx_state;
	end
	else if (state == MinCostState) begin
		nx_state = PivotState;
	end
	else begin
		
	end
end

always @(posedge CLK or posedge RST) begin
	if (RST) Valid <= 1'b0;
	else if (state == EndState) Valid <= 1'b1;
	else Valid <= Valid;
end

endmodule

