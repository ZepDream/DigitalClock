//============================================================================
// 文件名  : time_counter.v
// 功能    : 正式时钟 + 时钟设置用的编辑缓冲
// 说明    : 正式时钟一直在走；设置时只改 edit_bcd，确认后才写回 time_bcd。
//============================================================================
module time_counter(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1hz,
    input  wire [1:0]  mode,
    input  wire        edit_load,
    input  wire        edit_commit,
    input  wire        digit_inc,
    input  wire        digit_dec,
    input  wire [2:0]  cursor,

    output wire [23:0] time_bcd,
    output wire [23:0] edit_bcd
);

    localparam [1:0] MODE_CL = 2'b00;

    reg [23:0] time_reg;
    reg [23:0] edit_reg;

    wire [23:0] edit_inc;
    wire [23:0] edit_dec;

    bcd_digit_adj u_edit_inc (
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b1), .bcd_out(edit_inc)
    );
    bcd_digit_adj u_edit_dec (
        .bcd_in(edit_reg), .cursor(cursor), .inc(1'b0), .bcd_out(edit_dec)
    );

    // 正式时钟：每秒加 1；确认时直接装载编辑值
    always @(posedge clk) begin
        if (!rst_n) begin
            time_reg <= 24'h000000;
            edit_reg <= 24'h000000;
        end
        else begin
            if ((mode == MODE_CL) && edit_commit)
                time_reg <= edit_reg;
            else if (tick_1hz)
                time_reg <= inc_time(time_reg);

            if ((mode == MODE_CL) && edit_load)
                edit_reg <= time_reg;
            else if ((mode == MODE_CL) && digit_inc)
                edit_reg <= edit_inc;
            else if ((mode == MODE_CL) && digit_dec)
                edit_reg <= edit_dec;
        end
    end

    assign time_bcd = time_reg;
    assign edit_bcd = edit_reg;

    // 24 位 BCD 时钟加 1 秒，23:59:59 回到 00:00:00
    function [23:0] inc_time;
        input [23:0] t;
        reg [3:0] ht, ho, mt, mo, st, so;
        begin
            {ht, ho, mt, mo, st, so} = t;

            if (so != 4'd9)
                so = so + 1'b1;
            else begin
                so = 4'd0;
                if (st != 4'd5)
                    st = st + 1'b1;
                else begin
                    st = 4'd0;
                    if (mo != 4'd9)
                        mo = mo + 1'b1;
                    else begin
                        mo = 4'd0;
                        if (mt != 4'd5)
                            mt = mt + 1'b1;
                        else begin
                            mt = 4'd0;
                            if ((ht == 4'd2) && (ho >= 4'd3)) begin
                                ht = 4'd0;
                                ho = 4'd0;
                            end
                            else if (ho == 4'd9) begin
                                ho = 4'd0;
                                ht = ht + 1'b1;
                            end
                            else begin
                                ho = ho + 1'b1;
                            end
                        end
                    end
                end
            end

            inc_time = {ht, ho, mt, mo, st, so};
        end
    endfunction

endmodule
