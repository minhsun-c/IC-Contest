`timescale 1ns/10ps
module LBP ( clk, reset, gray_addr, gray_req, gray_ready, gray_data, lbp_addr, lbp_valid, lbp_data, finish);
input   			clk;
input   			reset;

output  reg       	gray_req;
output  reg [13:0] 	gray_addr;
input   	    	gray_ready;
input   	[7:0] 	gray_data;

output  reg [13:0] 	lbp_addr;
output  reg 	    lbp_valid;
output  reg [7:0] 	lbp_data;
output  reg  	    finish;


reg [3:0] 	counter;

reg [13:0] 	pivot;
reg [7:0] 	pivot_data;
reg [13:0]	addr 	[7:0];

wire 		res_sub = (gray_data >= pivot_data);

always @(*) begin
	if (counter >= 4'd2 && counter <= 4'd9) begin
		lbp_data[counter - 2] = res_sub;
	end
	else begin
		lbp_data = lbp_data;
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		lbp_valid <= 1'b0;
		lbp_addr <= 14'd0;
	end
	else if (counter == 4'd10) begin
		lbp_valid <= 1'b1;
		lbp_addr <= pivot;
	end
	else begin
		lbp_valid <= 1'b0;
		lbp_addr <= lbp_addr;
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		counter <= 4'd0;
	end
	else if (gray_ready && counter == 4'd11) begin
		counter <= 4'd0;
	end
	else if (gray_ready) begin
		counter <= counter + 4'd1;
	end
	else begin
		counter <= counter;
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		pivot <= {7'd1, 7'd1};
	end
	else if (gray_ready && counter == 4'd10) begin
		if (pivot[6:0] == 7'd126) begin
			pivot <= {pivot[13:7] + 7'd1, 7'd1};
		end
		else begin
			pivot <= {pivot[13:7], pivot[6:0] + 7'd1};
		end
	end
	else begin
		pivot <= pivot;
	end
end

always @(*) begin
	addr[0] = {pivot[13:7] - 7'd1, pivot[6:0] - 7'd1};
	addr[1] = {pivot[13:7] - 7'd1, pivot[6:0]		};
	addr[2] = {pivot[13:7] - 7'd1, pivot[6:0] + 7'd1};
	addr[3] = {pivot[13:7]		 , pivot[6:0] - 7'd1};
	addr[4] = {pivot[13:7]		 , pivot[6:0] + 7'd1};
	addr[5] = {pivot[13:7] + 7'd1, pivot[6:0] - 7'd1};
	addr[6] = {pivot[13:7] + 7'd1, pivot[6:0]		};
	addr[7] = {pivot[13:7] + 7'd1, pivot[6:0] + 7'd1};
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		gray_addr <= 14'd0;
	end
	else if (gray_ready && counter == 4'd0) begin
		gray_addr <= pivot;
	end
	else if (gray_ready && counter <= 4'd8) begin
		gray_addr <= addr[counter - 4'd1];
	end
	else begin
		gray_addr <= gray_addr;
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		pivot_data <= 8'd0;
	end
	else if (counter == 4'd1) begin
		pivot_data <= gray_data;
	end
	else begin
		pivot_data <= pivot_data;
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) begin
		gray_req <= 1'b0;
	end
	else if (counter <= 4'd8) begin
		gray_req <= 1'b1;
	end
	else begin
		gray_req <= 1'b0;
	end
end

always @(posedge clk or posedge reset) begin
	if (reset) 
		finish <= 1'b0;
	else if (pivot == {7'd127, 7'd1}) 
		finish <= 1'b1;
	else 
		finish <= 1'b0;
end

endmodule