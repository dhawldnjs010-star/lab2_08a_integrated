`timescale 1ns/1ps
// Main clock: B6 at 1 kHz. K4 reset, N8 mode, N4 step.
module lab2_integrated #(
    parameter integer STABLE_CYCLES = 20,
    parameter integer DIVISOR = 1000,
    parameter integer LCD_POWER_WAIT = 50
) (
    input wire clk, rst, mode_button, step_button,
    input wire [7:0] sw,
    output reg [7:0] led,
    output wire [7:0] seg_data, seg_com,
    output wire lcd_e, lcd_rs, lcd_rw,
    output wire [7:0] lcd_data
);
    wire reset, mode_press, step_press;
    wire [7:0] switches;
    reg [2:0] mode;
    input_frontend #(.STABLE_CYCLES(STABLE_CYCLES)) inputs(
        clk, rst, mode_button, sw, reset, mode_press, switches);
    button_onepulse #(.STABLE_CYCLES(STABLE_CYCLES)) step_input(
        clk, reset, step_button, step_press);
    always @(posedge clk) begin
        if (reset) mode <= 0;
        else if (mode_press) mode <= mode + 1'b1;
    end
    // Each new mode starts from its initial state, even if step is pressed too.
    wire circuit_reset = reset || mode_press;
    wire [3:0] count, stored, registered, shifted, parallel;
    wire divided, tick, div2, div10, div50, serial_out, mealy_state;
    wire [1:0] moore_value, mealy_value;
    wire [7:0] selected, segments;
    wire [2:0] scan_index;
    counter4 counter(clk, circuit_reset, step_press && mode==0, switches[0], count);
    clock_divider #(.DIVISOR(DIVISOR)) divider(clk, circuit_reset, divided, tick);
    clock_divider #(.DIVISOR(2)) ratio2(.clk(clk), .rst(circuit_reset), .divided(div2), .tick());
    clock_divider #(.DIVISOR(10)) ratio10(.clk(clk), .rst(circuit_reset), .divided(div10), .tick());
    clock_divider #(.DIVISOR(50)) ratio50(.clk(clk), .rst(circuit_reset), .divided(div50), .tick());
    register_pair registers(clk, circuit_reset,
        step_press && mode==2 && switches[0],
        step_press && mode==2 && switches[1], switches[7:4], stored, registered);
    shift_register4 shift(clk, circuit_reset, step_press && mode==3, switches[7], shifted);
    piso4 piso(clk, circuit_reset, step_press && mode==4 && switches[0],
        step_press && mode==4 && !switches[0], switches[7:4], serial_out, parallel);
    moore_cycle moore(clk, circuit_reset, step_press && mode==5, switches[7], moore_value);
    mealy_toggle mealy(clk, circuit_reset, step_press && mode==6, switches[7], mealy_state, mealy_value);
    segment_scan8 scan(clk, circuit_reset, mode==7,
        {28'h7654321, switches[7:4]}, selected, segments, scan_index);
    assign seg_data = (mode==7) ? segments : 8'h00;
    assign seg_com = (mode==7) ?
        ~{selected[0],selected[1],selected[2],selected[3],
          selected[4],selected[5],selected[6],selected[7]} : 8'hff;
    always @* begin
        led = 0;
        case (mode)
            0: led = {4'b0, count};
            1: led = {3'b0, tick, divided, div50, div10, div2};
            2: led = {stored, registered};
            3: led = {4'b0, shifted};
            4: led = {parallel, 3'b0, serial_out};
            5: led = {6'b0, moore_value};
            6: led = {5'b0, mealy_state, mealy_value};
            7: led = {5'b0, scan_index};
        endcase
    end
    lcd_lab2_modes #(.POWER_WAIT(LCD_POWER_WAIT)) display(
        clk, reset, {1'b0,mode}, lcd_e, lcd_rs, lcd_rw, lcd_data);
endmodule
