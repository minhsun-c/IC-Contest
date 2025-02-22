`timescale 1ns/10ps

module  CONV(
	input					clk,
	input					reset,
	output reg				busy,	
	input					ready,	
			
	output reg 		[11:0] 	iaddr,
	input  signed	[19:0] 	idata,	
	
	output reg	 			cwr,
	output reg		[11:0] 	caddr_wr,
	output reg		[19:0] 	cdata_wr,
	
	output reg	 			crd,
	output reg		[11:0] 	caddr_rd,
	input  signed 	[19:0] 	cdata_rd,
	
	output reg		[2:0] 	csel
);

parameter 	InputStage	= 3'd0,
			L0Stage 	= 3'd1,
			L1Stage 	= 3'd2,
			PoolStage	= 3'd3,
			EndStage 	= 3'd4;

parameter 	kernel0 	= 20'h0A89E, 
		 	kernel1 	= 20'h092D5, 
		 	kernel2 	= 20'h06D43, 
		 	kernel3 	= 20'h01004, 
		 	kernel4 	= 20'hF8F71, 
		 	kernel5 	= 20'hF6E54, 
		 	kernel6 	= 20'hFA6D7, 
		 	kernel7 	= 20'hFC834, 
		 	kernel8 	= 20'hFAC19; 

parameter	bias 		= 40'h0013100000;

reg 	[2:0] state;
reg 	[2:0] nx_state;

/*
============================================================
Layer 0: CONV
============================================================
*/

reg 	[11:0] 	ConvIdx4;
wire 	[11:0] 	ConvIdx0, ConvIdx1, ConvIdx2, ConvIdx3, ConvIdx5, ConvIdx6, ConvIdx7, ConvIdx8;

assign	ConvIdx0 = {ConvIdx4[11:6] - 6'd1, ConvIdx4[5:0] - 6'd1};
assign	ConvIdx1 = {ConvIdx4[11:6] - 6'd1, ConvIdx4[5:0]	   };
assign	ConvIdx2 = {ConvIdx4[11:6] - 6'd1, ConvIdx4[5:0] + 6'd1};
assign	ConvIdx3 = {ConvIdx4[11:6], 	   ConvIdx4[5:0] - 6'd1};
assign	ConvIdx5 = {ConvIdx4[11:6], 	   ConvIdx4[5:0] + 6'd1};
assign	ConvIdx6 = {ConvIdx4[11:6] + 6'd1, ConvIdx4[5:0] - 6'd1};
assign	ConvIdx7 = {ConvIdx4[11:6] + 6'd1, ConvIdx4[5:0]	   };
assign	ConvIdx8 = {ConvIdx4[11:6] + 6'd1, ConvIdx4[5:0] + 6'd1};

reg 	[3:0] 	count9;

always @(posedge clk or posedge reset) begin
	if (reset) begin
		ConvIdx4 <= 12'd0;
		count9 <= 4'd0;
	end
	else if (state == InputStage && busy) begin
		ConvIdx4 <= ConvIdx4;
		count9 <= count9 + 1;
		case (count9)
			4'd0: iaddr <= ConvIdx0;
			4'd1: iaddr <= ConvIdx1;
			4'd2: iaddr <= ConvIdx2;
			4'd3: iaddr <= ConvIdx3;
			4'd4: iaddr <= ConvIdx4;
			4'd5: iaddr <= ConvIdx5;
			4'd6: iaddr <= ConvIdx6;
			4'd7: iaddr <= ConvIdx7;
			4'd8: iaddr <= ConvIdx8;
			default: iaddr <= iaddr;
		endcase
	end
	else if (state == L0Stage && busy) begin
		ConvIdx4 <= ConvIdx4 + 12 'd1;
		count9 <= 4'd0;
	end
	else begin
		
	end
end

reg signed 	[19:0] 	kernel;
always @(posedge clk or posedge reset) begin
	if (reset) begin
		kernel <= 20'd0;
	end
	else begin
		case (count9)
			4'd1: kernel <= kernel0;
			4'd2: kernel <= kernel1;
			4'd3: kernel <= kernel2;
			4'd4: kernel <= kernel3;
			4'd5: kernel <= kernel4;
			4'd6: kernel <= kernel5;
			4'd7: kernel <= kernel6;
			4'd8: kernel <= kernel7;
			4'd9: kernel <= kernel8;
			default: kernel <= 20'd0;
		endcase
	end
end

reg signed	[19:0] 	idata_tmp;
always @(posedge clk or posedge reset) begin
	if (reset) begin
		idata_tmp <= 40'd0;
	end
	else if (state == InputStage && busy) begin
		case (count9)
			4'd1: 
				idata_tmp <= (ConvIdx4[11:6] == 6'd0  || ConvIdx4[5:0] == 6'd0	) ?  20'd0 : idata;
			4'd2: 
				idata_tmp <= (ConvIdx4[11:6] == 6'd0							) ?  20'd0 : idata;
			4'd3: 
				idata_tmp <= (ConvIdx4[11:6] == 6'd0  || ConvIdx4[5:0] == 6'd63	) ?  20'd0 : idata;
			4'd4: 
				idata_tmp <= (						     ConvIdx4[5:0] == 6'd0 	) ?  20'd0 : idata;
			4'd5: 
				idata_tmp <=  															 	 idata;
			4'd6: 
				idata_tmp <= (						     ConvIdx4[5:0] == 6'd63	) ?  20'd0 : idata;
			4'd7: 
				idata_tmp <= (ConvIdx4[11:6] == 6'd63 || ConvIdx4[5:0] == 6'd0 	) ?  20'd0 : idata;
			4'd8: 
				idata_tmp <= (ConvIdx4[11:6] == 6'd63							) ?  20'd0 : idata;
			4'd9: 
				idata_tmp <= (ConvIdx4[11:6] == 6'd63 || ConvIdx4[5:0] == 6'd63	) ?  20'd0 : idata;
			default: 
				idata_tmp <= 20'd0;
		endcase
	end
	else begin
		
	end
end

wire signed [39:0] mulresult;
assign mulresult = idata_tmp * kernel;

reg signed	[39:0] sumtemp;
wire signed	[19:0] roundsum;
always @(posedge clk or reset) begin
	if (reset) begin
		sumtemp <= 40'd0;
	end
	else if (state == InputStage && busy) begin

		if (count9 == 4'd0) begin
			sumtemp <= bias;
		end
		else if (count9 <= 4'd10) begin
			sumtemp <= sumtemp + mulresult;
		end
		else begin
			sumtemp <= sumtemp;	
		end
	end
	else begin
		
	end
end

// round at 17th bit -> guard bit: 16th bit
assign roundsum = sumtemp[35:16] + sumtemp[15];

/*
============================================================
Layer 1: Max Pooling
============================================================
*/

reg 		[11:0] 	PoolIdx0;
wire 		[11:0] 	PoolIdx1, PoolIdx2, PoolIdx3;

assign 	PoolIdx1 = PoolIdx0 + 12'd1;
assign 	PoolIdx2 = PoolIdx0 + 12'd64;
assign 	PoolIdx3 = PoolIdx0 + 12'd65;

reg signed	[19:0] 	MaxData;
always @(*) begin
	if (PoolData0 >= PoolData1 && PoolData0 >= PoolData2 && PoolData0 >= PoolData3) 
		MaxData = PoolData0;
	else if (PoolData1 >= PoolData0 && PoolData1 >= PoolData2 && PoolData1 >= PoolData3) 
		MaxData = PoolData1;
	else if (PoolData2 >= PoolData1 && PoolData2 >= PoolData0 && PoolData2 >= PoolData3) 
		MaxData = PoolData2;
	else 
		MaxData = PoolData3;
end

reg 		[2:0] 	count4;
reg 		[11:0] 	PoolWrIdx;
reg signed	[19:0]	PoolData0, PoolData1, PoolData2, PoolData3;

always @(posedge clk or posedge reset) begin
	if (reset) begin
		PoolWrIdx <= 12'h0;
		PoolIdx0 <= 12'd0;
		count4 <= 3'd0;
	end
	else if (state == L1Stage && busy) begin
		if (count4 == 3'd5) begin
			count4 <= 3'd0;
			if (PoolIdx0[5:0] == 6'd62) begin
				PoolIdx0[11:6] <= PoolIdx0[11:6] + 6'd2;
				PoolIdx0[5:0] <= 6'd0;
			end
			else begin
				PoolIdx0[5:0] <= PoolIdx0[5:0] + 6'd2;
			end
			PoolWrIdx <= PoolWrIdx + 12'd1;
		end
		else begin
		end
	end
	else if (state == PoolStage && busy) begin
		count4 <= count4 + 3'd1;
		case (count4)
			3'd0:	
				caddr_rd <= PoolIdx0;
			3'd1: 	begin
				caddr_rd <= PoolIdx1;
				PoolData0 <= cdata_rd;
			end
			3'd2: 	begin
				caddr_rd <= PoolIdx2;
				PoolData1 <= cdata_rd;
			end
			3'd3: 	begin
				caddr_rd <= PoolIdx3;
				PoolData2 <= cdata_rd;
			end
			3'd4:
				PoolData3 <= cdata_rd;
			default: 	
				caddr_rd <= caddr_rd;
		endcase
	end
	else begin
		
	end
end

/*
============================================================
Finite State Machine
============================================================
*/

always @(posedge clk or posedge reset) begin
	if (reset) begin
		state <= InputStage;
	end
	else begin
		state <= nx_state; 
	end
end

always @(*) begin
	if (state == InputStage) begin
		if (count9 == 4'd10)
			nx_state = L0Stage;
		else 
			nx_state = InputStage;
	end
	else if (state == L0Stage) begin
		if (ConvIdx4 == 12'hfff) begin
			nx_state = L1Stage;
		end
		else begin
			nx_state = InputStage;
		end
	end
	else if (state == L1Stage) begin
		if (PoolWrIdx == 12'h3ff && count4 == 3'd5) begin
			nx_state = EndStage;
		end
		else if (count4 < 3'd4) begin
			nx_state = PoolStage;
		end
		else begin
			nx_state = L1Stage;
		end
	end
	else if (state == PoolStage) begin
		if (count4 < 3'd4) begin
			nx_state = PoolStage;
		end
		else begin
			nx_state = L1Stage;
		end
	end
	else begin
		nx_state = nx_state;
	end
end

/*
============================================================
Control Signals
============================================================
*/

always @(posedge clk or posedge reset) begin
	if (reset) begin
		busy <= 1'b0;
	end
	else if (ready) begin
		busy <= 1'b1;
	end
	else if (state == EndStage) begin
		busy <= 1'b0;
	end
	else begin
		
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		caddr_wr <= 12'hfff;
		cdata_wr <= 20'd0;
	end
	else if (state == InputStage && busy) begin
		cwr <= 1'b0;
		csel <= 3'd0;
	end
	else if (state == L0Stage && busy) begin
		caddr_wr <= caddr_wr + 12'd1;
		cdata_wr <= (roundsum[19]) ? 20'd0 : roundsum;
		cwr <= 1'b1;
		csel <= 3'd1;
	end
	else if (state == L1Stage && busy) begin
		if (count4 == 3'd0) begin
			cwr <= 1'b0;
			caddr_wr <= PoolWrIdx;
		end
		else if (count4 == 3'd5) begin
			cwr <= 1'b1;
			crd <= 1'b0;
			csel <= 3'd3;
			cdata_wr <= MaxData;
		end
		else begin
		end
	end
	else if (state == PoolStage && busy) begin
		cwr <= 1'b0;
		crd <= 1'b1;
		csel <= 3'd1;
	end
	else begin
		
	end
end

endmodule
