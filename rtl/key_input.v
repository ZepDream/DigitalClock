//============================================================================
// 文件名  : key_input.v
// 功能    : 模式 9 的 8 个 nibble 按键 + 核心板 K1~K4 的按键输入
// 输出    : key_press[0]~[7] 对应键 1~8，core_press[0]~[3] 对应 K1~K4
//============================================================================
module key_input(
    input  wire        clk,                   // 系统 50 MHz 时钟，直通给 12 个消抖实例
    input  wire        rst_n,                 // 同步复位，低有效，直通给所有实例
    input  wire        tick_1khz,             // 1 ms 使能，来自 clk_gen，作为各实例消抖与连发的时基
    input  wire [15:0] pi_in,                 // PI 口 16 位输入，每 4 位接一个 nibble 密钥，对应键 1~4
    input  wire [15:0] pio_in,                // PIO 口 16 位输入，对应键 5~8
    input  wire [3:0]  key_core_n,            // 核心板 K1~K4 输入，低有效，每一位一个键
    output wire [7:0]  key_press,             // 8 路 nibble 键的按下事件，每位一个单周期脉冲，送顶层键值处理
    output wire [3:0]  core_press             // 4 路核心键的按下事件，每位一个单周期脉冲，按 K1~K4 顺序对应
);
    // 例化约定：clk/rst_n/tick_1khz 三根公共信号直通，只有 nibble_in 与 press 按位分配
    //------------------------------------------------------------------------
    // 模式 9：键 1~4 在 PI，键 5~8 在 PIO
    //------------------------------------------------------------------------
    nibble_key u_key1 (                       // 键 1：PI[3:0] → key_press[0]
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pi_in[3:0]),  .press(key_press[0])
    );
    nibble_key u_key2 (                       // 键 2：PI[7:4] → key_press[1]
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pi_in[7:4]),  .press(key_press[1])
    );
    nibble_key u_key3 (                       // 键 3：PI[11:8] → key_press[2]
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pi_in[11:8]), .press(key_press[2])
    );
    nibble_key u_key4 (                       // 键 4：PI[15:12] → key_press[3]
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pi_in[15:12]),.press(key_press[3])
    );
    nibble_key u_key5 (                       // 键 5：PIO[3:0] → key_press[4]
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pio_in[3:0]), .press(key_press[4])
    );
    nibble_key u_key6 (                       // 键 6：PIO[7:4] → key_press[5]
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pio_in[7:4]), .press(key_press[5])
    );
    nibble_key u_key7 (                       // 键 7：PIO[11:8] → key_press[6]
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pio_in[11:8]),.press(key_press[6])
    );
    nibble_key u_key8 (                       // 键 8：PIO[15:12] → key_press[7]
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pio_in[15:12]),.press(key_press[7])
    );
    // 低有效按键不在这里取反，core_key 内部按低有效判断
    //------------------------------------------------------------------------
    // 核心板按键：低有效，每键一个 core_key 实例，输出 core_press[0]~[3]
    // K1 只复位，不连发；K2/K3 连发；K4 只做确认
    //------------------------------------------------------------------------
    core_key #(
        .REPEAT_EN(0)                         // K1 的 REPEAT_EN=0：不连发
    ) u_core_k1 (                             // K1：核心板 K1，只出单次按下脉冲
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_n(key_core_n[0]), .press(core_press[0])
    );
    core_key #(
        .REPEAT_EN(1)                         // K2 的 REPEAT_EN=1：使能连发
    ) u_core_k2 (                             // K2：按住 0.5 s 后每 100 ms 一个 press，供加操作
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_n(key_core_n[1]), .press(core_press[1])
    );
    core_key #(
        .REPEAT_EN(1)                         // K3 的 REPEAT_EN=1：使能连发
    ) u_core_k3 (                             // K3：按住 0.5 s 后每 100 ms 一个 press，供减操作
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_n(key_core_n[2]), .press(core_press[2])
    );
    core_key #(
        .REPEAT_EN(0)                         // K4 的 REPEAT_EN=0：不连发
    ) u_core_k4 (                             // K4：确认键，单次按下
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_n(key_core_n[3]), .press(core_press[3])
    );

endmodule
