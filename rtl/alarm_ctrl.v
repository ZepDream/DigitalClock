//============================================================================
// 文件名  : alarm_ctrl.v
// 功能    : 闹钟时间设置、开关、到点比较和单次触发
// 说明    : 闹钟精确到秒；time_bcd == alarm_bcd 且开启时产生一个脉冲。
//============================================================================
module alarm_ctrl(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0]  mode,
    input  wire [23:0] time_bcd,
    input  wire        edit_load,
    input  wire        edit_commit,
    input  wire        digit_inc,
    input  wire        digit_dec,
    input  wire [2:0]  cursor,
    input  wire        alarm_en_toggle,

    output wire [23:0] alarm_bcd,
    output wire [23:0] alarm_edit_bcd,
    output wire        alarm_en,
    output reg         alarm_trigger
);

    localparam [1:0] MODE_AL = 2'b01;

    reg [23:0] alarm_reg;
    reg [23:0] edit_reg;
    reg        en_reg;
    reg        match_d;

    wire [23:0] edit_inc;
    wire [23:0] edit_dec;
    wire        match;

    bcd_digit_adj u_edit_inc (
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b1), .bcd_out(edit_inc)
    );
    bcd_digit_adj u_edit_dec (
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b0), .bcd_out(edit_dec)
    );

    assign match = en_reg && (time_bcd == alarm_reg);

    always @(posedge clk) begin
        if (!rst_n) begin
            alarm_reg    <= 24'h000000;
            edit_reg     <= 24'h000000;
            en_reg       <= 1'b0;
            match_d      <= 1'b0;
            alarm_trigger <= 1'b0;
        end
        else begin
            if (alarm_en_toggle)
                en_reg <= ~en_reg;

            if ((mode == MODE_AL) && edit_commit)
                alarm_reg <= edit_reg;
            else if ((mode == MODE_AL) && edit_load)
                edit_reg <= alarm_reg;
            else if ((mode == MODE_AL) && digit_inc)
                edit_reg <= edit_inc;
            else if ((mode == MODE_AL) && digit_dec)
                edit_reg <= edit_dec;

            // 相等时只产生一个脉冲；时间离开相等状态后 match_d 清零
            alarm_trigger <= match & ~match_d;
            match_d       <= match;
        end
    end

    assign alarm_bcd      = alarm_reg;
    assign alarm_edit_bcd = edit_reg;
    assign alarm_en       = en_reg;

endmodule
