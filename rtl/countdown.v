//============================================================================
// 文件名  : countdown.v
// 功能    : 倒计时，HH:MM:SS，最大 23:59:59
// 说明    : key1 启动/暂停，key2 复位到设定值（清零到 0 已取消，改为在设置里改）。
//           剩余时间为 0 时启动无效；只有 1 -> 0 才产生到期脉冲。
//============================================================================
module countdown(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,
    input  wire [1:0]  mode, // 模式输入；2'b11 = 倒计时模式（MODE_CD），其他模式不响应编辑和走时
    input  wire        edit_load, // 进入设置时装载：preset_reg -> edit_reg
    input  wire        edit_commit, // 确认设置：edit_reg -> preset_reg/remain_reg，并停机、清到期
    input  wire        digit_inc, // 设置时当前编辑位 +1，单周期脉冲
    input  wire        digit_dec, // 设置时当前编辑位 -1，单周期脉冲
    input  wire [2:0]  cursor, // 当前编辑位：0~5 对应 时十/时个/分十/分个/秒十/秒个
    input  wire        start_pause, // 键 1：启动/暂停，单周期脉冲
    input  wire        reset, // 键 2：恢复到设定值（清零功能已取消，端口不再叫 clear）

    output wire [23:0] preset_bcd, // 设定值 BCD：{时十,时个,分十,分个,秒十,秒个}，6 个 nibble
    output wire [23:0] remain_bcd, // 剩余值 BCD，格式同上，范围 00:00:00~23:59:59
    output wire [23:0] edit_bcd, // 设置缓冲 BCD，格式同上，供设置界面显示
    output wire        running, // 1 = 正在倒计时
    output wire        paused, // 1 = 被用户暂停，用于和“未启动”区分
    output wire        expired, // 1 = 已到期，保持到下次启动或恢复设定值
    output reg         expire_pulse // 到期单周期脉冲，只有 remain 由 1 变 0 的那一拍为高
);

    localparam [1:0] MODE_CD = 2'b11; // 倒计时模式编码，与顶层 mode 对齐

    reg [23:0] preset_reg; // 设定值寄存器，BCD；commit 时由 edit_reg 覆盖，reset 时复制给 remain_reg
    reg [23:0] remain_reg; // 剩余值寄存器，BCD；运行时每秒减 1，减到 0 触发到期
    reg [23:0] edit_reg; // 设置缓冲寄存器，BCD；load 时装载 preset，inc/dec 修改，commit 后生效
    reg        run_reg; // 运行标志：1 = 正在倒计时
    reg        paused_reg; // 暂停标志：仅用于显示区分暂停与未启动
    reg        expired_reg; // 到期标志：启动或恢复设定值时清 0

    wire [23:0] edit_inc; // 组合值：edit_reg 按 cursor 指定位加 1 后的 BCD
    wire [23:0] edit_dec; // 组合值：edit_reg 按 cursor 指定位减 1 后的 BCD

    bcd_digit_adj u_edit_inc ( // 加 1 调整器，内含 0~9 / 0~5 / 0~2 的位内回绕
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b1), .bcd_out(edit_inc)
    );
    bcd_digit_adj u_edit_dec ( // 减 1 调整器，内含 BCD 借位回绕
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b0), .bcd_out(edit_dec)
    );
    // 优先级：复位 > 设置提交 > 装载 > 加/减 > 恢复设定值 > 启停 > 每秒递减（前 4 项还要求 mode==MODE_CD）
    always @(posedge clk) begin // 50 MHz 上升沿更新，异步复位；复位值 00:05:00、停止、未到期
        if (!rst_n) begin
            preset_reg   <= 24'h000500; // 默认 00:05:00
            remain_reg   <= 24'h000500;
            edit_reg     <= 24'h000500;
            run_reg      <= 1'b0;
            paused_reg   <= 1'b0;
            expired_reg  <= 1'b0;
            expire_pulse <= 1'b0;
        end
        else begin
            expire_pulse <= 1'b0; // 每拍默认清脉冲；只有下面 remain 由 1 变 0 的分支会置 1，保证单周期

            if ((mode == MODE_CD) && edit_commit) begin // 设置提交最先处理：设置界面按确认优先于其他按键和走时
                preset_reg  <= edit_reg; // 设定值与剩余值同步更新，停机并清到期标志
                remain_reg  <= edit_reg;
                run_reg     <= 1'b0;
                paused_reg  <= 1'b0;
                expired_reg <= 1'b0;
            end
            else if ((mode == MODE_CD) && edit_load) begin // 进入设置：把当前设定值装进编辑缓冲
                edit_reg   <= preset_reg;
                paused_reg <= 1'b0;
            end
            else if ((mode == MODE_CD) && digit_inc) // 设置中加 1，组合结果直接写入缓冲
                edit_reg <= edit_inc;
            else if ((mode == MODE_CD) && digit_dec) // 设置中减 1
                edit_reg <= edit_dec;
            else if (reset) begin // 键 2：恢复到设定值并停机；优先于启动/暂停，且不再做清零
                remain_reg  <= preset_reg;
                run_reg     <= 1'b0;
                paused_reg  <= 1'b0;
                expired_reg <= 1'b0;
            end
            else if (start_pause) begin // 键 1 启停
                if (run_reg) begin // 正在运行：暂停并置暂停标志
                    run_reg    <= 1'b0;
                    paused_reg <= 1'b1;
                end
                else if ((!expired_reg) && (remain_reg != 24'h000000)) begin // 只有未到期且剩余非 0 才允许启动，避免 0 秒空转
                    run_reg    <= 1'b1;
                    paused_reg <= 1'b0;
                end
            end
            else if (tick_1hz && run_reg) begin // 每秒递减，只有运行中才消费 1 Hz 使能
                if (remain_reg == 24'h000001) begin // 单独判 1：这是唯一产生到期脉冲的边界，减到 0 的同一拍置脉冲
                    remain_reg   <= 24'h000000;
                    run_reg      <= 1'b0;
                    paused_reg   <= 1'b0;
                    expired_reg  <= 1'b1;
                    expire_pulse <= 1'b1;
                end
                else begin // 其余情况走 BCD 减 1 组合函数
                    remain_reg <= dec_time(remain_reg);
                end
            end
        end
    end

    assign preset_bcd = preset_reg; // 设定值 BCD 直连
    assign remain_bcd = remain_reg; // 剩余值 BCD 直连
    assign edit_bcd   = edit_reg; // 设置缓冲 BCD 直连
    assign running    = run_reg; // 运行标志直连
    assign paused     = paused_reg; // 暂停标志直连
    assign expired    = expired_reg; // 到期标志直连

    // 24 位 BCD 减 1 秒；调用前已保证当前值 > 0，纯组合逻辑
    function [23:0] dec_time; // 输入 24 位 BCD，输出减 1 秒后的 BCD；一层层 else 就是逐级借位链
        input [23:0] t; // t：{时十,时个,分十,分个,秒十,秒个}
        reg [3:0] ht, ho, mt, mo, st, so; // 拆开的 6 个 BCD 位，函数内临时变量
        begin
            {ht, ho, mt, mo, st, so} = t; // 先解包成 6 个 nibble

            if (so != 4'd0) // 秒个非 0：直接减 1，最短路径
                so = so - 1'b1;
            else begin // 秒个为 0：向秒十借位，本位补 9
                so = 4'd9;
                if (st != 4'd0) // 秒十非 0：直接借位
                    st = st - 1'b1;
                else begin // 秒十为 0：向分个借位，秒十补 5
                    st = 4'd5;
                    if (mo != 4'd0) // 分个非 0：直接借位
                        mo = mo - 1'b1;
                    else begin // 分个为 0：向分十借位，分个补 9
                        mo = 4'd9;
                        if (mt != 4'd0) // 分十非 0：直接借位
                            mt = mt - 1'b1;
                        else begin // 分十为 0：向时个借位，分十补 5
                            mt = 4'd5;
                            if (ho != 4'd0) // 时个非 0：直接借位
                                ho = ho - 1'b1;
                            else begin // 时个为 0：向时十借位，时个补 9
                                ho = 4'd9;
                                if (ht != 4'd0) // 时十非 0：直接借位
                                    ht = ht - 1'b1;
                                else begin // 时十为 0：整体从 00:00:00 回绕到 23:59:59
                                    ht = 4'd2; // 时十 = 2
                                    ho = 4'd3; // 时个 = 3
                                end
                            end
                        end
                    end
                end
            end

            dec_time = {ht, ho, mt, mo, st, so}; // 重新打包成 24 位 BCD 返回
        end
    endfunction

endmodule
