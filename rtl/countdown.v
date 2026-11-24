//============================================================================
// 文件名  : countdown.v
// 功能    : 倒计时，HH:MM:SS，最大 23:59:59
// 说明    : key5 启动/暂停，key6 复位到设定值，key2 清零到 0。
//           剩余时间为 0 时启动无效；只有 1 -> 0 才产生到期脉冲。
//============================================================================
module countdown(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,
    input  wire [1:0]  mode,
    input  wire        edit_load,
    input  wire        edit_commit,
    input  wire        digit_inc,
    input  wire        digit_dec,
    input  wire [2:0]  cursor,
    input  wire        start_pause,
    input  wire        reset,
    input  wire        clear,

    output wire [23:0] preset_bcd,
    output wire [23:0] remain_bcd,
    output wire [23:0] edit_bcd,
    output wire        running,
    output wire        paused,
    output wire        expired,
    output reg         expire_pulse
);

    localparam [1:0] MODE_CD = 2'b11;

    reg [23:0] preset_reg;
    reg [23:0] remain_reg;
    reg [23:0] edit_reg;
    reg        run_reg;
    reg        paused_reg;
    reg        expired_reg;

    wire [23:0] edit_inc;
    wire [23:0] edit_dec;

    bcd_digit_adj u_edit_inc (
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b1), .bcd_out(edit_inc)
    );
    bcd_digit_adj u_edit_dec (
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b0), .bcd_out(edit_dec)
    );

    always @(posedge clk) begin
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
            expire_pulse <= 1'b0;

            if ((mode == MODE_CD) && edit_commit) begin
                preset_reg  <= edit_reg;
                remain_reg  <= edit_reg;
                run_reg     <= 1'b0;
                paused_reg  <= 1'b0;
                expired_reg <= 1'b0;
            end
            else if ((mode == MODE_CD) && edit_load) begin
                edit_reg   <= preset_reg;
                paused_reg <= 1'b0;
            end
            else if ((mode == MODE_CD) && digit_inc)
                edit_reg <= edit_inc;
            else if ((mode == MODE_CD) && digit_dec)
                edit_reg <= edit_dec;
            else if (clear) begin
                remain_reg  <= 24'h000000;
                run_reg     <= 1'b0;
                paused_reg  <= 1'b0;
                expired_reg <= 1'b0;
            end
            else if (reset) begin
                remain_reg  <= preset_reg;
                run_reg     <= 1'b0;
                paused_reg  <= 1'b0;
                expired_reg <= 1'b0;
            end
            else if (start_pause) begin
                if (run_reg) begin
                    run_reg    <= 1'b0;
                    paused_reg <= 1'b1;
                end
                else if ((!expired_reg) && (remain_reg != 24'h000000)) begin
                    run_reg    <= 1'b1;
                    paused_reg <= 1'b0;
                end
            end
            else if (tick_1hz && run_reg) begin
                if (remain_reg == 24'h000001) begin
                    remain_reg   <= 24'h000000;
                    run_reg      <= 1'b0;
                    paused_reg   <= 1'b0;
                    expired_reg  <= 1'b1;
                    expire_pulse <= 1'b1;
                end
                else begin
                    remain_reg <= dec_time(remain_reg);
                end
            end
        end
    end

    assign preset_bcd = preset_reg;
    assign remain_bcd = remain_reg;
    assign edit_bcd   = edit_reg;
    assign running    = run_reg;
    assign paused     = paused_reg;
    assign expired    = expired_reg;

    // 24 位 BCD 减 1 秒；调用前已保证当前值 > 0
    function [23:0] dec_time;
        input [23:0] t;
        reg [3:0] ht, ho, mt, mo, st, so;
        begin
            {ht, ho, mt, mo, st, so} = t;

            if (so != 4'd0)
                so = so - 1'b1;
            else begin
                so = 4'd9;
                if (st != 4'd0)
                    st = st - 1'b1;
                else begin
                    st = 4'd5;
                    if (mo != 4'd0)
                        mo = mo - 1'b1;
                    else begin
                        mo = 4'd9;
                        if (mt != 4'd0)
                            mt = mt - 1'b1;
                        else begin
                            mt = 4'd5;
                            if (ho != 4'd0)
                                ho = ho - 1'b1;
                            else begin
                                ho = 4'd9;
                                if (ht != 4'd0)
                                    ht = ht - 1'b1;
                                else begin
                                    ht = 4'd2;
                                    ho = 4'd3;
                                end
                            end
                        end
                    end
                end
            end

            dec_time = {ht, ho, mt, mo, st, so};
        end
    endfunction

endmodule
