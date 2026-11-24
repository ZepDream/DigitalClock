//============================================================================
// 文件名  : bcd_digit_adj.v
// 功能    : 对 24 位 BCD 时间中的某一位做 +1 / -1
// 说明    : 只改选中位，不向相邻位进位；到边界后在本位内回绕。
//           位序：cursor=0 时十位，1 时个位，2 分十位，3 分个位，
//                 4 秒十位，5 秒个位。
//============================================================================
module bcd_digit_adj(
    input  wire [23:0] bcd_in,
    input  wire [2:0]  cursor,
    input  wire        inc,       // 1=加，0=减
    output reg  [23:0] bcd_out
);

    reg [3:0] ht, ho, mt, mo, st, so;

    always @(*) begin
        {ht, ho, mt, mo, st, so} = bcd_in;

        case (cursor)
            3'd0: begin // 时的十位，0~2
                if (inc)
                    ht = (ht == 4'd2) ? 4'd0 : ht + 1'b1;
                else
                    ht = (ht == 4'd0) ? 4'd2 : ht - 1'b1;

                // 时十位变成 2 时，时个位最大只能是 3
                if ((ht == 4'd2) && (ho > 4'd3))
                    ho = 4'd3;
            end

            3'd1: begin // 时的个位
                if (ht == 4'd2) begin
                    if (inc)
                        ho = (ho >= 4'd3) ? 4'd0 : ho + 1'b1;
                    else
                        ho = (ho == 4'd0) ? 4'd3 : ho - 1'b1;
                end
                else begin
                    if (inc)
                        ho = (ho == 4'd9) ? 4'd0 : ho + 1'b1;
                    else
                        ho = (ho == 4'd0) ? 4'd9 : ho - 1'b1;
                end
            end

            3'd2: begin // 分的十位，0~5
                if (inc)
                    mt = (mt == 4'd5) ? 4'd0 : mt + 1'b1;
                else
                    mt = (mt == 4'd0) ? 4'd5 : mt - 1'b1;
            end

            3'd3: begin // 分的个位，0~9
                if (inc)
                    mo = (mo == 4'd9) ? 4'd0 : mo + 1'b1;
                else
                    mo = (mo == 4'd0) ? 4'd9 : mo - 1'b1;
            end

            3'd4: begin // 秒的十位，0~5
                if (inc)
                    st = (st == 4'd5) ? 4'd0 : st + 1'b1;
                else
                    st = (st == 4'd0) ? 4'd5 : st - 1'b1;
            end

            3'd5: begin // 秒的个位，0~9
                if (inc)
                    so = (so == 4'd9) ? 4'd0 : so + 1'b1;
                else
                    so = (so == 4'd0) ? 4'd9 : so - 1'b1;
            end

            default: begin
                // 保持原值
            end
        endcase

        bcd_out = {ht, ho, mt, mo, st, so};
    end

endmodule
