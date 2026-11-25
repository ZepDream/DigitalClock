//============================================================================
// 文件名  : beep_ctrl.v
// 功能    : 闹钟/倒计时的蜂鸣器节奏
// 说明    : 闹钟 3 下 x 2 组；倒计时 2 下 x 1 组；任意键可提前静音。
//           输出 beep_en 只控制“响/不响”，2.7 kHz 方波由 buzzer_tone 产生。
//============================================================================
module beep_ctrl(
    input  wire clk,
    input  wire rst_n,
    input  wire tick_1khz,     // 1 ms 单周期使能，节奏状态机的计时基准
    input  wire alarm_trigger, // 闹钟到点单周期脉冲，优先级高于倒计时到期
    input  wire cd_expire, // 倒计时到期单周期脉冲
    input  wire silence, // 任意键静音，优先级最高
    output wire beep_en // 1 = 正在响；送 buzzer_tone 做门控
);

    localparam [1:0] ST_IDLE = 2'd0; // 空闲：不响，等待触发
    localparam [1:0] ST_ON   = 2'd1; // 响：beep_en=1
    localparam [1:0] ST_OFF  = 2'd2; // 停：每一下“响”之间的静音段
    localparam [1:0] ST_GAP  = 2'd3; // 组间隔：仅闹钟两组之间使用

    localparam integer ALARM_ON_MS  = 150; // 闹钟每下响 150 ms
    localparam integer ALARM_OFF_MS = 150; // 闹钟每下之间停 150 ms
    localparam integer ALARM_GAP_MS = 600; // 闹钟两组之间间隔 600 ms
    localparam integer CD_ON_MS     = 200; // 倒计时每下响 200 ms
    localparam integer CD_OFF_MS    = 200; // 倒计时每下之间停 200 ms

    reg [1:0]  state; // 当前节奏状态，四态编码见上面 localparam
    reg        is_alarm; // 1 = 本次节奏属于闹钟，决定用 150/150 还是 200/200
    reg [2:0]  beep_cnt; // 已完成的“响”次数，0~5；闹钟 3+3 下，倒计时 2 下
    reg [15:0] timer; // 1 ms 定时计数器，单位 ms，到对应门限后切换状态

    assign beep_en = (state == ST_ON); // 只有 ST_ON 输出高，其余状态静音
    // 优先级：复位 > silence > alarm_trigger > cd_expire > 1 ms 定时推进
    always @(posedge clk) begin // 50 MHz 上升沿更新，复位回空闲
        if (!rst_n) begin
            state    <= ST_IDLE;
            is_alarm <= 1'b0;
            beep_cnt <= 3'd0;
            timer    <= 16'd0;
        end
        else if (silence) begin // 任意键静音：立即回空闲并清计数
            state    <= ST_IDLE;
            is_alarm <= 1'b0;
            beep_cnt <= 3'd0;
            timer    <= 16'd0;
        end
        else if (alarm_trigger) begin // 闹钟触发优先，会打断正在响的倒计时，并从第一下重新开始
            // 闹钟优先；如果正在响倒计时，也立即切换到闹钟
            state    <= ST_ON;
            is_alarm <= 1'b1;
            beep_cnt <= 3'd0;
            timer    <= 16'd0;
        end
        else if (cd_expire && (state == ST_IDLE)) begin // 倒计时到期只在空闲时启动，不打断正在响的闹钟
            state    <= ST_ON;
            is_alarm <= 1'b0;
            beep_cnt <= 3'd0;
            timer    <= 16'd0;
        end
        else if (tick_1khz) begin // 定时推进只在 1 ms 使能下走，状态机内部按 ms 计数
            case (state)
                ST_IDLE: begin // 空闲态空转，等触发
                    // 等待触发
                end

                ST_ON: begin // 响段计时，门限按 is_alarm 选 150/200 ms
                    if (timer == ((is_alarm ? ALARM_ON_MS : CD_ON_MS) - 1)) begin
                        state <= ST_OFF; // 响段结束进入停段
                        timer <= 16'd0;
                    end
                    else begin
                        timer <= timer + 1'b1;
                    end
                end

                ST_OFF: begin // 停段计时，门限同样按 is_alarm 选 150/200 ms
                    if (timer == ((is_alarm ? ALARM_OFF_MS : CD_OFF_MS) - 1)) begin // 停段结束，决定“继续下一下”还是“本组结束”
                        timer <= 16'd0;

                        if (is_alarm) begin
                            if (beep_cnt == 3'd2) begin // 第 3 下响完 -> 进入组间隔
                                state <= ST_GAP;       // 第一组 3 下结束
                            end
                            else if (beep_cnt == 3'd5) begin // 第 6 下响完 -> 全部结束
                                state <= ST_IDLE;      // 第二组 3 下结束
                            end
                            else begin // 未到 3/6 下：计数加 1 继续响
                                beep_cnt <= beep_cnt + 1'b1;
                                state    <= ST_ON;
                            end
                        end
                        else begin
                            if (beep_cnt == 3'd1) // 倒计时第 2 下响完即结束
                                state <= ST_IDLE;      // 倒计时 2 下结束
                            else begin // 否则计数加 1 再响一下
                                beep_cnt <= beep_cnt + 1'b1;
                                state    <= ST_ON;
                            end
                        end
                    end
                    else begin
                        timer <= timer + 1'b1;
                    end
                end

                ST_GAP: begin // 组间隔 600 ms
                    if (timer == (ALARM_GAP_MS - 1)) begin // 间隔结束，重新进入响段
                        timer    <= 16'd0;
                        beep_cnt <= 3'd3;              // 第二组从第 4 下开始
                        state    <= ST_ON;
                    end
                    else begin
                        timer <= timer + 1'b1;
                    end
                end

                default: begin // 非法状态兜底回空闲
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
