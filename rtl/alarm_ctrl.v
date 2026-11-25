//============================================================================
// 文件名  : alarm_ctrl.v
// 功能    : 闹钟时间设置、开关、到点比较和单次触发
// 说明    : 闹钟精确到秒；time_bcd == alarm_bcd 且开启时产生一个脉冲。
//============================================================================
module alarm_ctrl(
    input  wire        clk, // 50 MHz 系统时钟，所有寄存器在上升沿更新
    input  wire        rst_n, // 低有效同步复位，闹钟值与开关都回默认
    input  wire [1:0]  mode, // 当前模式，仅 MODE_AL(01) 允许装载/确认/加减闹钟
    input  wire [23:0] time_bcd, // 当前正式时间 BCD，用于与闹钟整体比较
    input  wire        edit_load, // 进入设置：把 alarm_reg 装入 edit_reg
    input  wire        edit_commit, // 确认设置：把 edit_reg 写回 alarm_reg
    input  wire        digit_inc, // 光标位加 1 脉冲，只在 AL 设置态有效
    input  wire        digit_dec, // 光标位减 1 脉冲，只在 AL 设置态有效
    input  wire [2:0]  cursor, // 编辑光标 0~5，选择 bcd_digit_adj 修改哪位
    input  wire        alarm_en_toggle, // 闹钟开关翻转单周期脉冲，来自 key_ctrl 的键 1

    output wire [23:0] alarm_bcd, // 已确认的闹钟时间 BCD，复位 00:00:00，供比较与显示
    output wire [23:0] alarm_edit_bcd, // 闹钟编辑缓冲 BCD，设置时显示，确认前不影响 alarm_reg
    output wire        alarm_en, // 闹钟使能当前值，en_reg 的组合输出
    output reg         alarm_trigger // 到点单周期脉冲，match 上升沿时高一拍，送蜂鸣器
);
    // 模式编码，只有 AL 模式允许编辑闹钟
    localparam [1:0] MODE_AL = 2'b01; // AL 闹钟模式
    // 正式闹钟、编辑缓冲、开关、上一拍比较值
    reg [23:0] alarm_reg; // 正式闹钟寄存器，24 位 BCD，只在 AL 设置态确认时写
    reg [23:0] edit_reg; // 闹钟编辑缓冲，进入设置时装载，按键只改它
    reg        en_reg; // 闹钟开关，alarm_en_toggle 每来一次翻转一次
    reg        match_d; // 上一拍 match 值，用于上升沿检测，保证到点只触发一次
    // 光标位调整结果与整体相等标志
    wire [23:0] edit_inc; // 光标位 +1 的候选值
    wire [23:0] edit_dec; // 光标位 -1 的候选值
    wire        match; // 使能且 24 位 BCD 完全相等时为 1，精确到秒
    // 两个调整实例：cursor 选位，inc 定方向
    bcd_digit_adj u_edit_inc ( // 加 1 调整实例：inc 恒 1
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b1), .bcd_out(edit_inc)
    );
    bcd_digit_adj u_edit_dec ( // 减 1 调整实例：inc 恒 0
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b0), .bcd_out(edit_dec)
    );
    // 组合比较：不只看时间相等，还必须闹钟已开启
    assign match = en_reg && (time_bcd == alarm_reg); // 整体相等比较：时、分、秒六位 BCD 全部相同才算到点
    // 时序主体：clk 上升沿更新，低有效同步复位
    always @(posedge clk) begin // 开关、闹钟值、触发脉冲统一在 clk 上升沿更新；用 <= 并行更新
        if (!rst_n) begin // 同步复位：关闭闹钟并清触发状态
            alarm_reg    <= 24'h000000; // 复位闹钟时间为 00:00:00
            edit_reg     <= 24'h000000; // 复位编辑缓冲
            en_reg       <= 1'b0; // 复位关闭闹钟
            match_d      <= 1'b0; // 清上一拍比较值
            alarm_trigger <= 1'b0; // 清到点脉冲
        end
        else begin // 复位撤销后：按优先级更新开关、闹钟值和触发
            if (alarm_en_toggle) // 开关翻转：每个 toggle 脉冲只翻转一次，与按键脉宽无关
                en_reg <= ~en_reg;

            if ((mode == MODE_AL) && edit_commit) // 确认优先：把编辑值写回正式闹钟
                alarm_reg <= edit_reg;
            else if ((mode == MODE_AL) && edit_load) // 进入设置：装载当前闹钟值
                edit_reg <= alarm_reg;
            else if ((mode == MODE_AL) && digit_inc) // 设置态加 1
                edit_reg <= edit_inc;
            else if ((mode == MODE_AL) && digit_dec) // 设置态减 1
                edit_reg <= edit_dec;

            // 相等时只产生一个脉冲；时间离开相等状态后 match_d 清零；用 match 的上升沿而不是电平，避免整秒内重复触发
            alarm_trigger <= match & ~match_d; // 本拍到点且上一拍未到点，才输出一个单拍脉冲
            match_d       <= match; // 保存本拍 match，供下一拍做边沿检测
        end
    end

    assign alarm_bcd      = alarm_reg; // 正式闹钟输出
    assign alarm_edit_bcd = edit_reg; // 闹钟编辑缓冲输出
    assign alarm_en       = en_reg; // 当前开关状态输出

endmodule
