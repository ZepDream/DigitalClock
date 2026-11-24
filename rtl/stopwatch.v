//============================================================================
// 文件名  : stopwatch.v
// 功能    : 秒表，MM:SS:CC，10 ms 分辨率，最大 99:59.99
// 说明    : key1 启动/暂停，key2 清零并暂停；到最大值自动停止。
//============================================================================
module stopwatch(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_100hz,     // 10 ms
    input  wire       start_pause,
    input  wire       clear,

    output wire [7:0] min_bcd,
    output wire [7:0] sec_bcd,
    output wire [7:0] cs_bcd,
    output wire       running
);

    reg [7:0] min_reg;
    reg [7:0] sec_reg;
    reg [7:0] cs_reg;
    reg       run_reg;

    always @(posedge clk) begin
        if (!rst_n) begin
            min_reg <= 8'h00;
            sec_reg <= 8'h00;
            cs_reg  <= 8'h00;
            run_reg <= 1'b0;
        end
        else if (clear) begin
            min_reg <= 8'h00;
            sec_reg <= 8'h00;
            cs_reg  <= 8'h00;
            run_reg <= 1'b0;
        end
        else if (start_pause) begin
            if (run_reg)
                run_reg <= 1'b0;
            else if (!((min_reg == 8'h99) && (sec_reg == 8'h59) && (cs_reg == 8'h99)))
                run_reg <= 1'b1;
        end
        else if (tick_100hz && run_reg) begin
            if ((min_reg == 8'h99) && (sec_reg == 8'h59) && (cs_reg == 8'h99)) begin
                run_reg <= 1'b0;       // 到最大值停止
            end
            else begin
                // 厘秒个位
                if (cs_reg[3:0] != 4'd9) begin
                    cs_reg[3:0] <= cs_reg[3:0] + 1'b1;
                end
                else begin
                    cs_reg[3:0] <= 4'd0;
                    // 厘秒十位
                    if (cs_reg[7:4] != 4'd9) begin
                        cs_reg[7:4] <= cs_reg[7:4] + 1'b1;
                    end
                    else begin
                        cs_reg[7:4] <= 4'd0;
                        // 秒个位
                        if (sec_reg[3:0] != 4'd9) begin
                            sec_reg[3:0] <= sec_reg[3:0] + 1'b1;
                        end
                        else begin
                            sec_reg[3:0] <= 4'd0;
                            // 秒十位 0~5
                            if (sec_reg[7:4] != 4'd5) begin
                                sec_reg[7:4] <= sec_reg[7:4] + 1'b1;
                            end
                            else begin
                                sec_reg[7:4] <= 4'd0;
                                // 分个位
                                if (min_reg[3:0] != 4'd9) begin
                                    min_reg[3:0] <= min_reg[3:0] + 1'b1;
                                end
                                else begin
                                    min_reg[3:0] <= 4'd0;
                                    // 分十位
                                    if (min_reg[7:4] != 4'd9)
                                        min_reg[7:4] <= min_reg[7:4] + 1'b1;
                                    else
                                        min_reg[7:4] <= 4'd0;
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    assign min_bcd = min_reg;
    assign sec_bcd = sec_reg;
    assign cs_bcd  = cs_reg;
    assign running = run_reg;

endmodule
