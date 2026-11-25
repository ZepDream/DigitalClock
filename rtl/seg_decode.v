//============================================================================
// 文件名  : seg_decode.v
// 功能    : 4 位字符码 -> 8 位七段码（低有效）
// 段序    : {g, f, e, d, c, b, a, dp}
// 字符码  : 0~9 数字；A=A；B=C；C=d；D=L；E=S；F=t
//============================================================================
module seg_decode( // 4 位字符码 → 8 位七段码
    input  wire [3:0] bcd, // 输入字符码：0~9 或 A/C/d/L/S/t
    input  wire       dp, // 小数点使能：1=点亮
    input  wire       blank, // 消隐使能：1=整位熄灭
    output reg  [7:0] seg_n // 输出段码，低有效（0 点亮）
);
    // 段序 {g,f,e,d,c,b,a,dp}：bit7=g … bit1=a，bit0=dp
    always @(*) begin // 组合查表
        case (bcd) // 按字符码得到低有效段码
            4'h0: seg_n = 8'h81; // 0
            4'h1: seg_n = 8'hF3; // 1
            4'h2: seg_n = 8'h49; // 2
            4'h3: seg_n = 8'h61; // 3
            4'h4: seg_n = 8'h33; // 4
            4'h5: seg_n = 8'h25; // 5
            4'h6: seg_n = 8'h05; // 6
            4'h7: seg_n = 8'hF1; // 7
            4'h8: seg_n = 8'h01; // 8
            4'h9: seg_n = 8'h21; // 9
            4'hA: seg_n = 8'h11; // A
            4'hB: seg_n = 8'h8D; // C
            4'hC: seg_n = 8'h43; // d
            4'hD: seg_n = 8'h8F; // L
            4'hE: seg_n = 8'h25; // S（与 5 相同）
            4'hF: seg_n = 8'h0F; // t（只亮 d,e,f,g；8'h07 会多点亮 c 段）
            default: seg_n = 8'hFF; // 非法字符码：全灭
        endcase
        // 先加小数点，再统一处理消隐
        // 小数点：dp=1 时点亮，低有效所以清 bit0
        if (dp) // dp=1 时点亮小数点
            seg_n = seg_n & 8'hFE; // 清 bit0，其余段不变

        // 闪烁消隐
        if (blank) // blank=1 时整位全灭
            seg_n = 8'hFF;
    end
    // 低有效段码：0 点亮，1 熄灭
endmodule
