//============================================================================
// 文件名  : seg_decode.v
// 功能    : 4 位字符码 -> 8 位七段码（低有效）
// 段序    : {g, f, e, d, c, b, a, dp}
// 字符码  : 0~9 数字；A=A；B=C；C=d；D=L；E=S；F=t
//============================================================================
module seg_decode(
    input  wire [3:0] bcd,
    input  wire       dp,
    input  wire       blank,
    output reg  [7:0] seg_n
);

    always @(*) begin
        case (bcd)
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
            4'hF: seg_n = 8'h07; // t
            default: seg_n = 8'hFF;
        endcase

        // 小数点：dp=1 时点亮，低有效所以清 bit0
        if (dp)
            seg_n = seg_n & 8'hFE;

        // 闪烁消隐
        if (blank)
            seg_n = 8'hFF;
    end

endmodule
