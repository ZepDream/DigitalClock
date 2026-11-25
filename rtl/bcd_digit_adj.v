//============================================================================
// 文件名  : bcd_digit_adj.v
// 功能    : 对 24 位 BCD 时间中的某一位做 +1 / -1（段内进位 / 借位）
// 说明    : 光标指向“个位”时：满 10 向本段的十位进 1；
//           分、秒满 60 归零（不跨段进位，00:59 再 +1 就是 00:00）；
//           时满 24 归零（23 再 +1 回 00）。
//           光标指向“十位”时：只在本段十位范围内循环（分/秒 0~5，时 0~2）。
//           减法与加法对称：00 减 1 借位成 59（分/秒）或 23（时）。
//           位序：cursor=0 时十位，1 时个位，2 分十位，3 分个位，
//                 4 秒十位，5 秒个位。
//============================================================================
module bcd_digit_adj(
    input  wire [23:0] bcd_in,      // 24 位 BCD 原值：{时十,时个,分十,分个,秒十,秒个}，范围 00:00:00~23:59:59
    input  wire [2:0]  cursor,      // 选择被修改的位 0~5；6/7 非法时保持原值
    input  wire        inc,         // 1=加（digit_inc），0=减（digit_dec）
    output reg  [23:0] bcd_out      // 调整后的 24 位 BCD，纯组合输出，作为编辑寄存器的下一状态
);
    // 6 个 4 位 BCD 位：ht/ho=时十/时个，mt/mo=分十/分个，st/so=秒十/秒个
    reg [3:0] ht, ho, mt, mo, st, so; // 拆位寄存器：先整体复制 bcd_in，再只改 cursor 涉及的位

    // 纯组合逻辑：拆位 → 改选中位（可能进位/借位到本段十位）→ 重新拼接
    always @(*) begin // 无时钟；输入一变输出立即更新，不会产生寄存器
        {ht, ho, mt, mo, st, so} = bcd_in; // 未选中的位保持原值，综合时不会推断出锁存器

        case (cursor)
            3'd0: begin // 时十位：本段十位范围内循环 0→1→2→0，不向更高位进位
                if (inc)
                    ht = (ht == 4'd2) ? 4'd0 : ht + 1'b1; // 2 再加回 0
                else
                    ht = (ht == 4'd0) ? 4'd2 : ht - 1'b1; // 0 再减回 2
                // 时十位变成 2 时，时个位最大只能是 3，否则会出现 24~29 时这种非法值
                if ((ht == 4'd2) && (ho > 4'd3))
                    ho = 4'd3;
            end

            3'd1: begin // 时个位：满 10 向时十位进 1；23 加 1 回 00；00 减 1 借位成 23
                if (inc) begin
                    if ({ht, ho} == 8'h23) begin      // 23:xx 再 +1 小时 → 00:xx（满 24 归零）
                        ht = 4'd0;
                        ho = 4'd0;
                    end
                    else if (ho == 4'd9) begin        // 个位满 10：本位回 0，十位 +1（段内进位）
                        ho = 4'd0;
                        ht = ht + 1'b1;
                    end
                    else begin                        // 普通情况：个位 +1
                        ho = ho + 1'b1;
                    end
                end
                else begin
                    if ({ht, ho} == 8'h00) begin      // 00:xx 再 -1 小时 → 23:xx（借位回绕）
                        ht = 4'd2;
                        ho = 4'd3;
                    end
                    else if (ho == 4'd0) begin        // 个位为 0：向十位借 1，本位变 9
                        ho = 4'd9;
                        ht = ht - 1'b1;
                    end
                    else begin                        // 普通情况：个位 -1
                        ho = ho - 1'b1;
                    end
                end
            end

            3'd2: begin // 分十位：本段十位范围内循环 0~5，不向时进位
                if (inc)
                    mt = (mt == 4'd5) ? 4'd0 : mt + 1'b1;
                else
                    mt = (mt == 4'd0) ? 4'd5 : mt - 1'b1;
            end

            3'd3: begin // 分个位：满 10 进分十位；59 加 1 归零（不向时进位）
                if (inc) begin
                    if ({mt, mo} == 8'h59) begin      // 59 分再 +1 → 00 分（满 60 归零，不进时）
                        mt = 4'd0;
                        mo = 4'd0;
                    end
                    else if (mo == 4'd9) begin        // 个位满 10：本位回 0，十位 +1
                        mo = 4'd0;
                        mt = mt + 1'b1;
                    end
                    else begin
                        mo = mo + 1'b1;
                    end
                end
                else begin
                    if ({mt, mo} == 8'h00) begin      // 00 分再 -1 → 59 分（借位）
                        mt = 4'd5;
                        mo = 4'd9;
                    end
                    else if (mo == 4'd0) begin
                        mo = 4'd9;
                        mt = mt - 1'b1;
                    end
                    else begin
                        mo = mo - 1'b1;
                    end
                end
            end

            3'd4: begin // 秒十位：本段十位范围内循环 0~5，不向分进位
                if (inc)
                    st = (st == 4'd5) ? 4'd0 : st + 1'b1;
                else
                    st = (st == 4'd0) ? 4'd5 : st - 1'b1;
            end

            3'd5: begin // 秒个位：满 10 进秒十位；59 加 1 归零（不向分进位）
                if (inc) begin
                    if ({st, so} == 8'h59) begin      // 59 秒再 +1 → 00 秒（满 60 归零，不进分）
                        st = 4'd0;
                        so = 4'd0;
                    end
                    else if (so == 4'd9) begin        // 个位满 10：本位回 0，十位 +1
                        so = 4'd0;
                        st = st + 1'b1;
                    end
                    else begin
                        so = so + 1'b1;
                    end
                end
                else begin
                    if ({st, so} == 8'h00) begin      // 00 秒再 -1 → 59 秒（借位）
                        st = 4'd5;
                        so = 4'd9;
                    end
                    else if (so == 4'd0) begin
                        so = 4'd9;
                        st = st - 1'b1;
                    end
                    else begin
                        so = so - 1'b1;
                    end
                end
            end

            default: begin // cursor 为 6/7：无对应位
                // 保持原值；bcd_out 与 bcd_in 相同
            end
        endcase

        bcd_out = {ht, ho, mt, mo, st, so}; // 按原顺序拼回 24 位 BCD
    end

endmodule
