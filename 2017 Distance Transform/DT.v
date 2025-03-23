module DT(
	input 			        clk, 
	input			        reset,
	output	reg		        done,

	output	   		        sti_rd,
	output	reg 	[9:0]	sti_addr,
	input		    [15:0]	sti_di,

	output	reg		        res_wr,
	output	reg		        res_rd,
	output	reg 	[13:0]	res_addr,
	output	reg 	[7:0]	res_do,
	input		    [7:0]	res_di
);

parameter 	Forward = 1'b0, 
			Backward = 1'b1;

parameter   InputState  = 3'd0,
            DupState    = 3'd1,
            InitState   = 3'd2,
            CheckState  = 3'd3,
            ExeState    = 3'd4,
			MinState	= 3'd5,
            StallState  = 3'd6,
            EndState    = 3'd7
            ;

reg 		isForwardBackward;
reg [2:0]   state, nx_state;

reg 	[6:0] 	cur_x, cur_y;
reg 	[6:0]	x [3:0];	
reg 	[6:0]	y [3:0];	

reg 	[7:0] 	min_data;

reg     [4:0]   counter_duplicate;

/*
counter_check:
    0:  change cur_x, cur_y
    1:  sent address
    2:  get data, check background / object
*/
reg     [1:0]   counter_check;
reg 	[2:0]   counter_exe;

wire [6:0] res_addrx = res_addr[13:7];
wire [6:0] res_addry = res_addr[6:0];

/*
=================================================
ROM -> RAM: input & duplicate
=================================================
*/

reg [15:0]  rom_input;

assign sti_rd = (state == InputState);

always @(posedge clk or negedge reset) begin
    if (~reset) 
        sti_addr <= 10'd0;
    else if (state == InputState) 
        sti_addr <= sti_addr + 10'd1;
    else 
        sti_addr <= sti_addr;
end

always @(posedge clk or negedge reset) begin
    if (~reset) 
        rom_input <= 16'd0;
    else if (state == InputState) 
        rom_input <= sti_di;
    else 
        rom_input <= rom_input;
end

always @(posedge clk or negedge reset) begin
    if (~reset) 
        counter_duplicate <= 5'd0;
    else if (state == InputState) 
        counter_duplicate <= 5'd0;
    else if (state == DupState)
        counter_duplicate <= counter_duplicate + 5'd1;
    else begin
        counter_duplicate <= counter_duplicate;
    end
end

/*
=================================================
Write: Duplicate & Exe
=================================================
*/

always @(*) begin
    if (state == DupState && counter_duplicate >= 5'd2) begin
        res_wr = 1'b1;
    end
    else if (state == ExeState && counter_exe == 3'd6) begin
        res_wr = 1'b1;
    end
    else begin
        res_wr = 1'b0;
    end
end

wire 	[9:0] sti_addr_m1 = sti_addr - 10'd1;
wire 	[3:0] ctner_m1 = counter_duplicate - 5'd1;




always @(posedge clk or negedge reset) begin
    if (~reset) begin
        counter_exe <= 3'd0;
    end
    else if (state == InitState) begin
        counter_exe <= 3'd0;
    end
	else if (state == ExeState) begin
		counter_exe <= counter_exe + 3'd1;
	end
    else begin
        counter_exe <= counter_exe;
    end
end


always @(posedge clk or negedge reset) begin
    if (~reset) begin
        res_addr <= 4'd0;
    end
    else if (state == DupState) begin
        res_addr <= {sti_addr_m1, ctner_m1} ;
    end
    else if (state == CheckState) begin
        res_addr <= {cur_x, cur_y};
    end
	else if (state == ExeState) begin
		if (counter_exe < 3'd4)
			res_addr <= {x[counter_exe], y[counter_exe]};
		else 
			res_addr <= {cur_x, cur_y};
	end
    else begin
        res_addr <= res_addr;
    end
end

always @(posedge clk or negedge reset) begin
    if (~reset) begin
        res_do <= 8'd0;
    end
    else if (state == DupState) begin
        res_do <= {7'b0, rom_input[16 - counter_duplicate]};
    end
    else if (state == ExeState) begin
        if (isForwardBackward == Forward && counter_exe == 3'd5) 
            res_do <= min_data + 8'd1;
        else 
            res_do <= min_data;
    end
    else begin
        res_do <= res_do;
    end
end


/*
=================================================
Check Object or Background
=================================================
*/

always @(posedge clk or negedge reset) begin
    if (~reset) begin
        counter_check <= 2'd0;
    end
    else if (state == CheckState) begin
        if (counter_check == 2'd2)
            counter_check <= 2'd0;
        else
            counter_check <= counter_check + 2'd1;
    end
    else begin
        counter_check <= 2'd0;        
    end
end

/*
=================================================
Execute
=================================================
*/

always @(posedge clk or negedge reset) begin
	if (~reset) begin
		isForwardBackward <= Forward;
	end
	else if (state == StallState) begin
        isForwardBackward <= ~isForwardBackward;
    end
    else begin
        isForwardBackward <= isForwardBackward;
    end
end

always @(posedge clk or negedge reset) begin
	if (~reset) begin
		cur_x <= 7'b0;
        cur_y <= 7'b0;
	end
	else if (state == InitState) begin
        if (isForwardBackward == Forward) begin
            cur_x <= 7'd0;
            cur_y <= 7'd126;
        end
        else begin
            cur_x <= 7'd127;
            cur_y <= 7'd1;
        end
    end
    else if (state == CheckState && counter_check == 2'd0) begin
        if (isForwardBackward == Forward) begin
            if (cur_y == 7'd126) begin
                cur_x <= cur_x + 7'd1;
                cur_y <= 7'd1;
            end
            else begin
                cur_x <= cur_x;
                cur_y <= cur_y + 7'd1;
            end
        end
        else begin
            if (cur_y == 7'd1) begin
                cur_x <= cur_x - 7'd1;
                cur_y <= 7'd126;
            end
            else begin
                cur_x <= cur_x;
                cur_y <= cur_y - 7'd1;
            end
        end
    end
    else begin
        cur_x <= cur_x;
        cur_y <= cur_y;
    end
end

always @(*) begin
	if (isForwardBackward == Forward) begin
		{x[0], y[0]} = {cur_x - 7'd1, cur_y - 7'd1};
		{x[1], y[1]} = {cur_x - 7'd1, cur_y 	  };
		{x[2], y[2]} = {cur_x - 7'd1, cur_y + 7'd1};
		{x[3], y[3]} = {cur_x  		, cur_y - 7'd1};
	end
	else begin
		{x[0], y[0]} = {cur_x + 7'd1, cur_y + 7'd1};
		{x[1], y[1]} = {cur_x + 7'd1, cur_y 	  };
		{x[2], y[2]} = {cur_x + 7'd1, cur_y - 7'd1};
		{x[3], y[3]} = {cur_x  		, cur_y + 7'd1};
	end
end

always @(*) begin
    if (state == CheckState) begin
        res_rd = 1'b1;
    end
    else if (state == ExeState) begin
        if (counter_exe < 3'd5) res_rd = 1'd1;
        else res_rd = 1'd0;
    end
    else begin
        res_rd = 1'd0;
    end
end


always @(posedge clk or negedge reset) begin
	if (~reset) begin
        min_data <= 8'hff;
	end
	else if (state == ExeState) begin
		if (counter_exe == 3'd0) begin /* init min_data */
            if (isForwardBackward == Forward)
			    min_data <= 8'hff;
            else 
                min_data <= res_di;
		end
		else if (isForwardBackward == Forward) begin /* counter_exe: 1~4 */
			if (min_data > res_di) begin
				min_data <= res_di;
			end
			else begin
				min_data <= min_data;
			end
		end
		else if (isForwardBackward == Backward) begin /* counter_exe: 1~4 */
			if (min_data > res_di + 8'd1) begin
				min_data <= res_di + 8'd1;
			end
			else begin
				min_data <= min_data;
			end
		end
		else begin
			min_data <= min_data;
		end
	end
	else begin
		min_data <= min_data;
	end
end

/*
=================================================
Finite State Machine
=================================================
*/

always @(posedge clk or negedge reset) begin
    if (~reset) state <= InputState;
    else state <= nx_state;
end

always @(*) begin
    case (state)
        InputState: 
            begin
                nx_state = DupState;
            end
        DupState: 
            begin
                if (counter_duplicate == 5'd17) begin
                    if (sti_addr_m1 == 10'd1023) 
                        nx_state = InitState;
                    else
                        nx_state = InputState;
                end
                else begin
                    nx_state = DupState;
                end
            end
        InitState: 
            begin
                nx_state = CheckState;
            end
        CheckState:
            begin
                if (counter_check == 2'd2) begin
                    if (res_di != 8'd0)
                        nx_state = ExeState;
                    else if (isForwardBackward == Forward && cur_x == 7'd127 && cur_y == 7'd126)
                        nx_state = StallState;
                    else if (isForwardBackward == Backward && cur_x == 7'd0 && cur_y == 7'd1)
                        nx_state = EndState;
                    else
                        nx_state = CheckState;
                end
                else 
                    nx_state = CheckState;
            end
        ExeState: 
            begin
                if (counter_exe == 3'd6) begin
                    if (isForwardBackward == Forward) begin
                        if (cur_x == 7'd126 && cur_y == 7'd126) 
                            nx_state = StallState;
                        else 
                            nx_state = CheckState;
                    end
                    else begin
                        if (cur_x == 7'd1 && cur_y == 7'd1) 
                            nx_state = EndState;
                        else 
                            nx_state = CheckState;
                    end
                end
                else begin
                    nx_state = ExeState;
                end
            end
        StallState:
            begin
                nx_state = InitState;
            end
        default: 
            begin
                nx_state = nx_state;
            end
    endcase
end

always @(posedge clk or negedge reset) begin
    if (~reset) done <= 1'b0;
    else if (state == EndState) done <= 1'd1;
    else begin
        done <= 1'b0;
    end 
end

endmodule
