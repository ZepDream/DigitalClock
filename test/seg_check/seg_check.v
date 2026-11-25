//============================================================================
// 文件名  : seg_check.v
// 功能    : 数码管段序 / 位序 / 极性自检（不依赖主工程，单独编译下载）
// 说明    : 1 秒一步，16 秒一轮：
//             第 0~7 秒 ：只使能“数码1”，seg_n 每次只拉低 1 位（走位）
//                         → 看哪一段亮，就知道 seg_n[0..7] 各是哪一段
//             第 8~15 秒：八段全亮（显示 "8."），dig_n 每次只拉低 1 位（走位）
//                         → 看哪一位亮，就知道 dig_n[0..7] 各是哪一位
//           同时 LED1 以 1 Hz 闪烁，用来确认程序在跑、复位正常。
//============================================================================
module seg_check (
    input  wire       clk50,     // M15, 50 MHz
    output wire [7:0] seg_n,     // 段选，低有效（按设计假设）
    output wire [7:0] dig_n,     // 位选，低有效（按设计假设）
    output wire [3:0] led_n      // LED1 心跳，低有效
);

    localparam integer DIV = 50_000_000;   // 50 MHz → 1 Hz

    reg [25:0] cnt_div;
    reg [3:0]  step;        // 0~15
    reg        heartbeat;

    // 1 秒一步的节拍 + LED1 心跳
    always @(posedge clk50) begin
        if (cnt_div == DIV - 1) begin
            cnt_div   <= 26'd0;
            step      <= step + 1'b1;
            heartbeat <= ~heartbeat;
        end
        else begin
            cnt_div <= cnt_div + 1'b1;
        end
    end

    // 第 0~7 秒：段走位。seg_n 只拉低 step 那一位，其余为 1
    // 第 8~15 秒：段全亮（seg_n = 0），改为位走位
    assign seg_n = (step < 4'd8) ? ~(8'b0000_0001 << step)
                                 : 8'h00;

    // 第 0~7 秒：只使能数码1（dig_n[0]=0，其余 1）
    // 第 8~15 秒：dig_n 只拉低 (step-8) 那一位
    assign dig_n = (step < 4'd8) ? 8'b1111_1110
                                 : ~(8'b0000_0001 << (step - 4'd8));

    assign led_n = {3'b111, ~heartbeat};

endmodule
