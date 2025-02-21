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

parameter   FetchStage   = 2'd0,
            IdleStage    = 2'd1,
            CommandStage = 2'd2,
            WriteStage   = 2'd3;

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
reg [1:0]   state;
reg [1:0]   next_state;

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
    end
    else begin
        
    end
end

always @(posedge clk) begin
    if (state == IdleStage) begin
        if (cmd == WriteCmd) $display("Command Name: WriteCmd");
        else if (cmd == ShiftUpCmd) $display("Command Name: ShiftUpCmd");
        else if (cmd == ShiftDownCmd) $display("Command Name: ShiftDownCmd");
        else if (cmd == ShiftLeftCmd) $display("Command Name: ShiftLeftCmd");
        else if (cmd == ShiftRightCmd) $display("Command Name: ShiftRightCmd");
        else if (cmd == MaxCmd) $display("Command Name: MaxCmd");
        else if (cmd == MinCmd) $display("Command Name: MinCmd");
        else if (cmd == AverageCmd) $display("Command Name: AverageCmd");
        else if (cmd == CCWRotateCmd) $display("Command Name: CCWRotateCmd");
        else if (cmd == CWRotateCmd) $display("Command Name: CWRotateCmd");
        else if (cmd == MirrorXCmd) $display("Command Name: MirrorXCmd");
        else if (cmd == MirrorYCmd) $display("Command Name: MirrorYCmd");
        else $display("No Command");
    end
    else begin
        
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
        RAM[IROM_A] <= IROM_Q;
        IROM_rd <= 1'b1;
    end
    else begin
        RAM[IROM_A] <= RAM[IROM_A];
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

reg [7:0] peep0, peep1, peep2, peep3;

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
        peep0 <= 0;
        peep1 <= 0;
        peep2 <= 0;
        peep3 <= 0;
    end
    else if (CommandStage && busy) begin
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
        peep0 <= RAM[OpIdx];
        peep1 <= RAM[OpIdx1];
        peep2 <= RAM[OpIdx2];
        peep3 <= RAM[OpIdx3];
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
        done <= 1'b1;
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
