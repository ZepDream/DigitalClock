//============================================================================
// 文件名  : key_ctrl.v
// 功能    : 模式/设置状态机，把按键脉冲翻译成各模块的动作
// 说明    : key_press[0]~[7] 对应键 1~8；core_press[0]~[3] 对应 K1~K4。
//           K1 只做全局复位，本模块不处理 core_press[0]。
//============================================================================
module key_ctrl(
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] key_press,
    input  wire [3:0] core_press,
    input  wire       cd_running,
    input  wire       cd_expired,

    output reg  [1:0] mode,
    output reg        setting,
    output reg  [2:0] cursor,

    output reg        edit_load,
    output reg        edit_commit,
    output reg        digit_inc,
    output reg        digit_dec,

    output reg        alarm_en_toggle,
    output reg        sw_start_pause,
    output reg        sw_clear,
    output reg        cd_start_pause,
    output reg        cd_reset,
    output reg        cd_clear,
    output reg        beep_silence
);

    localparam [1:0] MODE_CL = 2'b00;
    localparam [1:0] MODE_AL = 2'b01;
    localparam [1:0] MODE_ST = 2'b10;
    localparam [1:0] MODE_CD = 2'b11;

    wire enter_req;
    assign enter_req = key_press[6] | core_press[3]; // 键 7 或 K4

    // 下一个模式：CL -> AL -> St -> Cd -> CL
    function [1:0] next_mode;
        input [1:0] m;
        begin
            case (m)
                MODE_CL: next_mode = MODE_AL;
                MODE_AL: next_mode = MODE_ST;
                MODE_ST: next_mode = MODE_CD;
                MODE_CD: next_mode = MODE_CL;
                default: next_mode = MODE_CL;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            mode           <= MODE_CL;
            setting        <= 1'b0;
            cursor         <= 3'd0;

            edit_load      <= 1'b0;
            edit_commit    <= 1'b0;
            digit_inc      <= 1'b0;
            digit_dec      <= 1'b0;

            alarm_en_toggle <= 1'b0;
            sw_start_pause  <= 1'b0;
            sw_clear        <= 1'b0;
            cd_start_pause  <= 1'b0;
            cd_reset        <= 1'b0;
            cd_clear        <= 1'b0;
            beep_silence    <= 1'b0;
        end
        else begin
            // 默认每周期清零，需要时置一个时钟周期的脉冲
            edit_load       <= 1'b0;
            edit_commit     <= 1'b0;
            digit_inc       <= 1'b0;
            digit_dec       <= 1'b0;

            alarm_en_toggle <= 1'b0;
            sw_start_pause  <= 1'b0;
            sw_clear        <= 1'b0;
            cd_start_pause  <= 1'b0;
            cd_reset        <= 1'b0;
            cd_clear        <= 1'b0;

            // 任意按键都可以提前静音
            beep_silence <= (|key_press) | (|core_press);

            //----------------------------------------------------------------
            // 键 8：优先处理。设置中先取消，再切模式。
            //----------------------------------------------------------------
            if (key_press[7]) begin
                setting <= 1'b0;
                cursor  <= 3'd0;
                mode    <= next_mode(mode);
            end

            //----------------------------------------------------------------
            // 键 7 / K4：进入设置或确认退出
            //----------------------------------------------------------------
            else if (enter_req) begin
                if (setting) begin
                    edit_commit <= 1'b1;
                    setting     <= 1'b0;
                    cursor      <= 3'd0;
                end
                else if ((mode == MODE_CL) ||
                         (mode == MODE_AL) ||
                         ((mode == MODE_CD) && (!cd_running) && (!cd_expired))) begin
                    edit_load <= 1'b1;
                    setting   <= 1'b1;
                    cursor    <= 3'd0;
                end
            end

            //----------------------------------------------------------------
            // 设置状态：光标移动、加、减
            //----------------------------------------------------------------
            else if (setting) begin
                if (key_press[3]) begin
                    // 键 4：光标左移，0~5 循环
                    if (cursor == 3'd0)
                        cursor <= 3'd5;
                    else
                        cursor <= cursor - 1'b1;
                end
                else if (key_press[2]) begin
                    // 键 3：光标右移，0~5 循环
                    if (cursor == 3'd5)
                        cursor <= 3'd0;
                    else
                        cursor <= cursor + 1'b1;
                end
                else if (key_press[1] | core_press[1]) begin
                    // 键 2 或 K2：加 1
                    digit_inc <= 1'b1;
                end
                else if (key_press[0] | core_press[2]) begin
                    // 键 1 或 K3：减 1
                    digit_dec <= 1'b1;
                end
            end

            //----------------------------------------------------------------
            // 正常显示状态：各模式自己的按键
            //----------------------------------------------------------------
            else begin
                case (mode)
                    MODE_CL: begin
                        // 键 1~6 无操作
                    end

                    MODE_AL: begin
                        if (key_press[0])
                            alarm_en_toggle <= 1'b1;
                    end

                    MODE_ST: begin
                        if (key_press[0])
                            sw_start_pause <= 1'b1;
                        else if (key_press[1])
                            sw_clear <= 1'b1;
                    end

                    MODE_CD: begin
                        if (key_press[4])
                            cd_start_pause <= 1'b1;
                        else if (key_press[5] && (!cd_running))
                            cd_reset <= 1'b1;
                        else if (key_press[1] && (!cd_running))
                            cd_clear <= 1'b1;
                    end

                    default: begin
                        // 保持
                    end
                endcase
            end
        end
    end

endmodule
