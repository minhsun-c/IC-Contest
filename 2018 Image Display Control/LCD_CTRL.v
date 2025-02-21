module LCD_CTRL(clk, reset, cmd, cmd_valid, IROM_Q, IROM_rd, IROM_A, IRAM_valid, IRAM_D, IRAM_A, busy, done);
input           clk;
input           reset;
input [3:0]     cmd;        // command
input           cmd_valid;  // is command enable
input [7:0]     IROM_Q;     // ROM data
// -------------------------------------------------------
output reg           IROM_rd;    // ROM data read enable
output reg  [5:0]    IROM_A;     // ROM Address
output reg           IRAM_valid;
output reg  [7:0]    IRAM_D;
output reg  [5:0]    IRAM_A;
output reg           busy;
output reg           done;

parameter   FetchStage   = 3'd0,
            IdleStage    = 3'd1,
            CommandStage = 3'd2,
            WriteStage   = 3'd3,
            EndStage     = 3'd4;

parameter   WriteCmd        = 4'h0,
            ShiftUpCmd      = 4'h1,
            ShiftDownCmd    = 4'h2,
            ShiftLeftCmd    = 4'h3,
            ShiftRightCmd   = 4'h4,
            MaxCmd          = 4'h5,
            MinCmd          = 4'h6,
            AverageCmd      = 4'h7,
            CCWRotateCmd    = 4'h8,
            CWRotateCmd     = 4'h9,
            MirrorXCmd      = 4'hA,
            MirrorYCmd      = 4'hB;

reg [7:0]   RAM [63:0];
reg [2:0]   state;
reg [2:0]   next_state;

/* 
===========================================================================================================
// Finite State Machine
===========================================================================================================
*/
always @(posedge clk or posedge reset) begin
    if (reset) 
        state <= FetchStage;
    else 
        state <= next_state;
end
always @(*) begin
    if (state == FetchStage) begin
        next_state = (IROM_A == 6'd63) ? IdleStage : FetchStage;
    end
    else if (state == IdleStage) begin
        if (cmd_valid && cmd == WriteCmd) 
            next_state = WriteStage;
        else if (cmd_valid) 
            next_state = CommandStage;
        else 
            next_state = IdleStage;
    end
    else if (state == CommandStage) begin
        next_state = IdleStage;
    end
    else if (state == WriteStage) begin
        if (IRAM_A == 6'd63)
            next_state = EndStage;
        else
            next_state = WriteStage;
    end
    else begin
        next_state = next_state;
    end
end
/*
===========================================================================================================
Control Unit
===========================================================================================================
*/
always @(*) begin
    if (reset) begin
        busy <= 1'b1;
        done <= 1'b0;
        IRAM_valid <= 1'b0;
    end
    else if (state == FetchStage) begin
        busy <= 1'b1;
        done <= 1'b0;
        IRAM_valid <= 1'b0;
    end
    else if (state == IdleStage) begin
        busy <= 1'b0;
        done <= 1'b0;
        IRAM_valid <= 1'b0;
    end
    else if (state == CommandStage) begin
        busy <= 1'b1;
        done <= 1'b0;
        IRAM_valid <= 1'b0;
    end
    else if (state == WriteStage) begin
        busy <= 1'b1;
        IRAM_valid <= 1'b1;
        done <= 1'b0;
    end
    else if (state == EndStage) begin
        done <= 1'b1;
    end
end

/*      
===========================================================================================================
Fetch From ROM:
1. ROM address ++
2. Fetch Data: ROM -> RAM
=========================================================================================================== 
*/
always @(posedge clk or posedge reset) begin
    if (reset) begin
        IROM_A <= 0;
    end
    else if (state == FetchStage) begin
        IROM_A <= (IROM_A == 6'd63) ? IROM_A : IROM_A + 6'd1;
    end
    else begin
        IROM_A <= IROM_A;
    end
end
always @(posedge clk or posedge reset) begin
    if (reset) begin
        IROM_rd <= 1'b1;
    end
    else if (state == FetchStage) begin
        IROM_rd <= 1'b1;
    end
    else begin
        IROM_rd <= 1'b0;
    end
end

/*      
===========================================================================================================
Get Command
1. Operation Point starts at (4,4) -> 36, but (3,3) -> 28 is the real starting point 
2. Shift may out of bound
3. Addition for average may overflow 
===========================================================================================================
*/
reg [5:0] OpIdx;
wire [5:0] OpIdx1, OpIdx2, OpIdx3;
assign OpIdx1 = OpIdx + 6'd1;
assign OpIdx2 = OpIdx + 6'd8;
assign OpIdx3 = OpIdx + 6'd9;

/* Comparison */
reg [5:0] min_idx, max_idx;
wire [9:0] sum_val;
assign sum_val = (RAM[OpIdx] + RAM[OpIdx1] + RAM[OpIdx2] + RAM[OpIdx3]);
always @(*) begin
    if (RAM[OpIdx] >= RAM[OpIdx1] && RAM[OpIdx] >= RAM[OpIdx2] && RAM[OpIdx] >= RAM[OpIdx3])
        max_idx = OpIdx;
    else if (RAM[OpIdx1] >= RAM[OpIdx] && RAM[OpIdx1] >= RAM[OpIdx2] && RAM[OpIdx1] >= RAM[OpIdx3])
        max_idx = OpIdx1;
    else if (RAM[OpIdx2] >= RAM[OpIdx] && RAM[OpIdx2] >= RAM[OpIdx1] && RAM[OpIdx2] >= RAM[OpIdx3])
        max_idx = OpIdx2;
    else
        max_idx = OpIdx3;
end
always @(*) begin
    if (RAM[OpIdx] <= RAM[OpIdx1] && RAM[OpIdx] <= RAM[OpIdx2] && RAM[OpIdx] <= RAM[OpIdx3])
        min_idx = OpIdx;
    else if (RAM[OpIdx1] <= RAM[OpIdx] && RAM[OpIdx1] <= RAM[OpIdx2] && RAM[OpIdx1] <= RAM[OpIdx3])
        min_idx = OpIdx1;
    else if (RAM[OpIdx2] <= RAM[OpIdx] && RAM[OpIdx2] <= RAM[OpIdx1] && RAM[OpIdx2] <= RAM[OpIdx3])
        min_idx = OpIdx2;
    else
        min_idx = OpIdx3;
end

always @(posedge clk or posedge reset) begin
    if (reset) begin
        OpIdx <= 6'h1B;
    end
    else if (state == FetchStage && busy) begin
        RAM[IROM_A] <= IROM_Q;
    end
    else if (state == CommandStage && busy) begin
        case (cmd)
            ShiftUpCmd: 
                OpIdx[5:3] <= (OpIdx[5:3] == 3'd0) ? OpIdx[5:3] : OpIdx[5:3] - 3'd1;
            ShiftDownCmd: 
                OpIdx[5:3] <= (OpIdx[5:3] == 3'd6) ? OpIdx[5:3] : OpIdx[5:3] + 3'd1;
            ShiftLeftCmd: 
                OpIdx[2:0] <= (OpIdx[2:0] == 3'd0) ? OpIdx[2:0] : OpIdx[2:0] - 3'd1;
            ShiftRightCmd: 
                OpIdx[2:0] <= (OpIdx[2:0] == 3'd6) ? OpIdx[2:0] : OpIdx[2:0] + 3'd1;
            MaxCmd: begin
                RAM[OpIdx] <= RAM[max_idx];
                RAM[OpIdx1] <= RAM[max_idx];
                RAM[OpIdx2] <= RAM[max_idx];
                RAM[OpIdx3] <= RAM[max_idx];
            end
            MinCmd: begin
                RAM[OpIdx] <= RAM[min_idx];
                RAM[OpIdx1] <= RAM[min_idx];
                RAM[OpIdx2] <= RAM[min_idx];
                RAM[OpIdx3] <= RAM[min_idx];
            end
            AverageCmd: begin
                RAM[OpIdx] <= sum_val[9:2];
                RAM[OpIdx1] <= sum_val[9:2];
                RAM[OpIdx2] <= sum_val[9:2];
                RAM[OpIdx3] <= sum_val[9:2];
            end
            CWRotateCmd: begin
                RAM[OpIdx] <= RAM[OpIdx2];
                RAM[OpIdx1] <= RAM[OpIdx];
                RAM[OpIdx2] <= RAM[OpIdx3];
                RAM[OpIdx3] <= RAM[OpIdx1];
            end
            CCWRotateCmd: begin
                RAM[OpIdx] <= RAM[OpIdx1];
                RAM[OpIdx1] <= RAM[OpIdx3];
                RAM[OpIdx2] <= RAM[OpIdx];
                RAM[OpIdx3] <= RAM[OpIdx2];
            end
            MirrorXCmd: begin
                RAM[OpIdx] <= RAM[OpIdx2];
                RAM[OpIdx1] <= RAM[OpIdx3];
                RAM[OpIdx2] <= RAM[OpIdx];
                RAM[OpIdx3] <= RAM[OpIdx1];
            end
            MirrorYCmd: begin
                RAM[OpIdx] <= RAM[OpIdx1];
                RAM[OpIdx1] <= RAM[OpIdx];
                RAM[OpIdx2] <= RAM[OpIdx3];
                RAM[OpIdx3] <= RAM[OpIdx2];
            end
            default: begin
                OpIdx <= OpIdx;
            end
        endcase
    end
    else begin
        
    end
end

/*
===========================================================================================================
Write Back to RAM: check the timing 
===========================================================================================================
*/
reg [5:0] nx_idx;
always @(posedge clk or posedge reset) begin
    if (reset) begin 
        nx_idx <= 6'd0;
    end
    else if ((state == WriteStage && nx_idx < 6'd63)) begin
        nx_idx <= nx_idx + 6'd1;
    end
    else if ((state == WriteStage && nx_idx == 6'd63)) begin
        nx_idx <= 6'd63;
    end
end
always @(posedge clk or posedge reset) begin
    if (reset) begin 
        IRAM_A <= 6'd0;
    end
    else if ((state == WriteStage && IRAM_A < 6'd63)) begin
        IRAM_A <= nx_idx;
    end
    else if ((state == WriteStage && IRAM_A == 6'd63)) begin
        IRAM_A <= 6'd63;
    end
end
always @(posedge clk or posedge reset) begin
    if (reset) begin 
        IRAM_D <= 8'd0;
    end
    else if (state == WriteStage) begin
        IRAM_D <= RAM[nx_idx];
    end
end



endmodule
