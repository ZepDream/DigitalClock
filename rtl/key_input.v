//============================================================================
// 文件名  : key_input.v
// 功能    : 模式 9 的 8 个 nibble 按键 + 核心板 K1~K4 的按键输入
// 输出    : key_press[0]~[7] 对应键 1~8，core_press[0]~[3] 对应 K1~K4
//============================================================================
module key_input(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick_1khz,
    input  wire [15:0] pi_in,
    input  wire [15:0] pio_in,
    input  wire [3:0]  key_core_n,
    output wire [7:0]  key_press,
    output wire [3:0]  core_press
);

    //------------------------------------------------------------------------
    // 模式 9：键 1~4 在 PI，键 5~8 在 PIO
    //------------------------------------------------------------------------
    nibble_key u_key1 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pi_in[3:0]),  .press(key_press[0])
    );
    nibble_key u_key2 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pi_in[7:4]),  .press(key_press[1])
    );
    nibble_key u_key3 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pi_in[11:8]), .press(key_press[2])
    );
    nibble_key u_key4 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pi_in[15:12]),.press(key_press[3])
    );
    nibble_key u_key5 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pio_in[3:0]), .press(key_press[4])
    );
    nibble_key u_key6 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pio_in[7:4]), .press(key_press[5])
    );
    nibble_key u_key7 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pio_in[11:8]),.press(key_press[6])
    );
    nibble_key u_key8 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .nibble_in(pio_in[15:12]),.press(key_press[7])
    );

    //------------------------------------------------------------------------
    // 核心板按键：低有效
    // K1 只复位，不连发；K2/K3 连发；K4 只做确认
    //------------------------------------------------------------------------
    core_key #(
        .REPEAT_EN(0)
    ) u_core_k1 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_n(key_core_n[0]), .press(core_press[0])
    );
    core_key #(
        .REPEAT_EN(1)
    ) u_core_k2 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_n(key_core_n[1]), .press(core_press[1])
    );
    core_key #(
        .REPEAT_EN(1)
    ) u_core_k3 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_n(key_core_n[2]), .press(core_press[2])
    );
    core_key #(
        .REPEAT_EN(0)
    ) u_core_k4 (
        .clk(clk), .rst_n(rst_n), .tick_1khz(tick_1khz),
        .key_n(key_core_n[3]), .press(core_press[3])
    );

endmodule
