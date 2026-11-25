//============================================================================
// 文件名  : stopwatch.v
// 功能    : 秒表，MM:SS:CC，10 ms 分辨率，最大 99:59.99
// 说明    : key1 启动/暂停，key2 清零并暂停；到最大值自动停止。
//============================================================================
module stopwatch(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tick_100hz,     // 10 ms 单周期使能，秒表计数节拍
    input  wire       start_pause, // 键 1：启动/暂停，单周期按键脉冲
    input  wire       clear, // 键 2：清零并暂停，单周期按键脉冲

    output wire [7:0] min_bcd, // 分钟 BCD：{分十,分个}，范围 00~99
    output wire [7:0] sec_bcd, // 秒 BCD：{秒十,秒个}，秒十 0~5，整体 00~59
    output wire [7:0] cs_bcd, // 厘秒 BCD：{厘秒十,厘秒个}，00~99，1 个单位 = 10 ms
    output wire       running // 1 = 正在计时，供显示层做状态/闪烁判断
);

    reg [7:0] min_reg; // 分钟计数，{分十,分个} 两位 BCD，只由本块 tick_100hz 进位链写
    reg [7:0] sec_reg; // 秒计数，{秒十,秒个} 两位 BCD，秒十满 5 向分进位
    reg [7:0] cs_reg; // 厘秒计数，{十,个} 两位 BCD，10 ms 加 1，满 99 向秒进位
    reg       run_reg; // 运行标志：1 = 走时，0 = 暂停或未启动
    // 本块优先级：复位 > 清零 > 启停按键 > 10 ms 计数
    always @(posedge clk) begin // 50 MHz 上升沿更新；复位值全 0，等价于“未启动、显示 00:00.00”
        if (!rst_n) begin // 异步复位低有效，优先级最高
            min_reg <= 8'h00; // 复位值：分钟清零
            sec_reg <= 8'h00;
            cs_reg  <= 8'h00;
            run_reg <= 1'b0;
        end
        else if (clear) begin // 清零优先于按键：按下键 2 会同时停表
            min_reg <= 8'h00;
            sec_reg <= 8'h00;
            cs_reg  <= 8'h00;
            run_reg <= 1'b0;
        end
        else if (start_pause) begin // 启停键：运行中再按即暂停
            if (run_reg)
                run_reg <= 1'b0;
            else if (!((min_reg == 8'h99) && (sec_reg == 8'h59) && (cs_reg == 8'h99))) // 已到 99:59.99 时不允许重新启动
                run_reg <= 1'b1;
        end
        else if (tick_100hz && run_reg) begin // 只在运行中消费 10 ms 使能；切到其他模式仍继续跑，是因为本模块不感知模式
            if ((min_reg == 8'h99) && (sec_reg == 8'h59) && (cs_reg == 8'h99)) begin // 最大值边界：到 99:59.99 自动停表，保留显示不再进位
                run_reg <= 1'b0;       // 到最大值停止
            end
            else begin
                // 厘秒个位
                if (cs_reg[3:0] != 4'd9) begin // 厘秒个位 0~9，未满 9 直接加 1
                    cs_reg[3:0] <= cs_reg[3:0] + 1'b1;
                end
                else begin
                    cs_reg[3:0] <= 4'd0;
                    // 厘秒十位
                    if (cs_reg[7:4] != 4'd9) begin // 个位为 9：本位回 0，十位加 1，满 9 再向秒进位
                        cs_reg[7:4] <= cs_reg[7:4] + 1'b1;
                    end
                    else begin
                        cs_reg[7:4] <= 4'd0;
                        // 秒个位
                        if (sec_reg[3:0] != 4'd9) begin // 秒个位 0~9，到 9 向秒十进位
                            sec_reg[3:0] <= sec_reg[3:0] + 1'b1;
                        end
                        else begin
                            sec_reg[3:0] <= 4'd0;
                            // 秒十位 0~5
                            if (sec_reg[7:4] != 4'd5) begin // 秒十位 0~5，到 5 向分进位
                                sec_reg[7:4] <= sec_reg[7:4] + 1'b1;
                            end
                            else begin
                                sec_reg[7:4] <= 4'd0;
                                // 分个位
                                if (min_reg[3:0] != 4'd9) begin // 分个位 0~9，到 9 向分十进位
                                    min_reg[3:0] <= min_reg[3:0] + 1'b1;
                                end
                                else begin
                                    min_reg[3:0] <= 4'd0;
                                    // 分十位
                                    if (min_reg[7:4] != 4'd9) // 分十位 0~9，到 9 归零（无更高位）
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

    assign min_bcd = min_reg; // 显示输出：分/秒/厘秒各 8 位 BCD，直接给数码管译码
    assign sec_bcd = sec_reg; // 秒 BCD 直连
    assign cs_bcd  = cs_reg; // 厘秒 BCD 直连
    assign running = run_reg; // 运行标志直连

endmodule
