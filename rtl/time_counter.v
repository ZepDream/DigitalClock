//============================================================================
// 文件名  : time_counter.v
// 功能    : 正式时钟 + 时钟设置用的编辑缓冲
// 说明    : 正式时钟一直在走；设置时只改 edit_bcd，确认后才写回 time_bcd。
//============================================================================
module time_counter(
    input  wire        clk, // 50 MHz 系统时钟，所有寄存器在上升沿更新
    input  wire        rst_n, // 低有效同步复位，正式时钟与编辑缓冲都清 00:00:00
    input  wire        tick_1hz, // 1 Hz 单周期使能，来自 clk_gen；高有效仅一拍
    input  wire [1:0]  mode, // 当前模式，仅 CL(00) 允许 edit_load/edit_commit/digit_inc/digit_dec 生效
    input  wire        edit_load, // 进入设置：把 time_reg 装入 edit_reg
    input  wire        edit_commit, // 确认设置：把 edit_reg 写回 time_reg
    input  wire        digit_inc, // 光标位加 1 脉冲，只在 CL 设置态有效
    input  wire        digit_dec, // 光标位减 1 脉冲，只在 CL 设置态有效
    input  wire [2:0]  cursor, // 编辑光标 0~5，选择 bcd_digit_adj 修改哪位

    output wire [23:0] time_bcd, // 正式时钟 BCD，组合输出，供显示与闹钟比较
    output wire [23:0] edit_bcd // 编辑缓冲 BCD，设置时显示，确认前不影响正式时钟
);
    // 模式编码，只有 CL 模式允许编辑时间
    localparam [1:0] MODE_CL = 2'b00; // CL 时钟模式
    // 两个 24 位 BCD 寄存器：正式时钟与编辑缓冲
    reg [23:0] time_reg; // 正式时钟寄存器，每秒 +1、24 小时回绕，只在本模块 always 中写
    reg [23:0] edit_reg; // 编辑缓冲寄存器，进入设置时装载正式值，按键只改它，确认才写回
    // 光标位 +1 / -1 的组合结果
    wire [23:0] edit_inc; // 光标位 +1 的候选值
    wire [23:0] edit_dec; // 光标位 -1 的候选值
    // 两个调整实例共享 cursor，分别产生加/减候选值
    bcd_digit_adj u_edit_inc ( // 加 1 调整实例：inc 恒 1
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b1), .bcd_out(edit_inc)
    );
    bcd_digit_adj u_edit_dec ( // 减 1 调整实例：inc 恒 0
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b0), .bcd_out(edit_dec)
    );
    // 实例化：cursor 选位，inc 选择加/减方向
    // 正式时钟：每秒加 1；确认时直接装载编辑值；edit_reg 只在 CL 模式被改写
    always @(posedge clk) begin // 正式时钟与编辑缓冲共用一个 always，clk 上升沿更新；用 <= 让两寄存器独立更新
        if (!rst_n) begin // 同步复位：两个寄存器都清 00:00:00
            time_reg <= 24'h000000; // 正式时钟复位为 00:00:00
            edit_reg <= 24'h000000; // 编辑缓冲复位为 00:00:00
        end
        else begin // 复位撤销后：先处理正式时钟，再处理编辑缓冲
            if ((mode == MODE_CL) && edit_commit) // 确认优先：设置态确认当拍即使 tick 到来，也以编辑值为准
                time_reg <= edit_reg;
            else if (tick_1hz) // 正常走时：每个 1 Hz 使能把时间加 1 秒
                time_reg <= inc_time(time_reg);
            // 编辑缓冲：装载/加减都只在 CL 模式生效
            if ((mode == MODE_CL) && edit_load) // 装载：进入设置时把正式时间复制到编辑缓冲
                edit_reg <= time_reg;
            else if ((mode == MODE_CL) && digit_inc) // 设置态加 1，写入组合调整结果
                edit_reg <= edit_inc;
            else if ((mode == MODE_CL) && digit_dec) // 设置态减 1，写入组合调整结果
                edit_reg <= edit_dec;
        end
    end
    // 输出只读镜像：正式值给显示/闹钟，编辑值给设置界面
    assign time_bcd = time_reg; // 正式时钟输出
    assign edit_bcd = edit_reg; // 编辑缓冲输出
    // 走时函数：纯组合，不依赖时钟，只在 always 中被调用
    // 24 位 BCD 时钟加 1 秒，23:59:59 回到 00:00:00
    function [23:0] inc_time; // 输入 t 为当前 24 位 BCD，返回 +1 秒后的值；逐级进位，23:59:59 回绕到 00:00:00
        input [23:0] t; // t：待加 1 的 24 位 BCD 时间
        reg [3:0] ht, ho, mt, mo, st, so; // 函数内局部变量，保存拆开的 6 位 BCD
        begin
            {ht, ho, mt, mo, st, so} = t; // 拆成时十/时个/分十/分个/秒十/秒个

            if (so != 4'd9) // 秒个位未满 9 直接加 1，不进位
                so = so + 1'b1;
            else begin
                so = 4'd0;
                if (st != 4'd5) // 秒十位未满 5 只加 1，不进位到分
                    st = st + 1'b1;
                else begin
                    st = 4'd0;
                    if (mo != 4'd9) // 分个位未满 9 只加 1，不进位到分十位
                        mo = mo + 1'b1;
                    else begin
                        mo = 4'd0;
                        if (mt != 4'd5) // 分十位未满 5 只加 1，不进位到时
                            mt = mt + 1'b1;
                        else begin
                            mt = 4'd0;
                            if ((ht == 4'd2) && (ho >= 4'd3)) begin // 到 23:59:59：时十位=2 且时个位>=3，整体回绕到 00:00:00
                                ht = 4'd0;
                                ho = 4'd0;
                            end
                            else if (ho == 4'd9) begin // 时个位满 9 进位到时十位
                                ho = 4'd0;
                                ht = ht + 1'b1;
                            end
                            else begin // 否则时个位直接加 1
                                ho = ho + 1'b1;
                            end
                        end
                    end
                end
            end

            inc_time = {ht, ho, mt, mo, st, so}; // 拼回 24 位 BCD 作为函数返回值
        end
    endfunction

endmodule
