`timescale 1ns/1ps
// Board source: 2022 CHARACTER LCD guide p13/p30, 1 kHz clock, 16x2, 8-bit bus.
// Each byte has 1 ms setup, 1 ms enable-high and >=2 ms recovery.
module lcd_lab2_modes #(parameter integer POWER_WAIT=50)(
 input wire clk,rst, input wire [3:0] mode,
 output reg lcd_e,lcd_rs, output wire lcd_rw, output reg [7:0] lcd_data);
 reg [1:0] phase;
 integer power_count;
 reg [5:0] index;
 reg [3:0] shown_mode;
 reg [127:0] name;
 assign lcd_rw=1'b0;
 always @* begin
  case(shown_mode)
 0:name="UP DOWN COUNTER ";
 1:name="CLOCK DIVIDER   ";
 2:name="REGISTER PAIR   ";
 3:name="SHIFT REGISTER  ";
 4:name="PISO            ";
 5:name="MOORE FSM       ";
 6:name="MEALY FSM       ";
 7:name="8 DIGIT SCAN    ";
 default:name="RESET REQUIRED  ";
  endcase
 end
 always @(posedge clk or posedge rst) begin
  if(rst) begin
   phase<=0; power_count<=0; index<=0; shown_mode<=0;
   lcd_e<=0; lcd_rs<=0; lcd_data<=0;
  end else if(power_count<POWER_WAIT) power_count<=power_count+1;
  else case(phase)
   0:begin
    lcd_e<=0; lcd_rs<=0;
    case(index)
     0,1,2:lcd_data<=8'h38;
     3:lcd_data<=8'h0c;
     4:lcd_data<=8'h06;
     5:begin lcd_data<=8'h80; shown_mode<=mode; end
     6:begin lcd_rs<=1; lcd_data<="M"; end
     7:begin lcd_rs<=1; lcd_data<="O"; end
     8:begin lcd_rs<=1; lcd_data<="D"; end
     9:begin lcd_rs<=1; lcd_data<="E"; end
     10:begin lcd_rs<=1; lcd_data<=" "; end
     11:begin lcd_rs<=1; lcd_data<="0"; end
     12:begin lcd_rs<=1; lcd_data<=("1"+shown_mode); end
     22:lcd_data<=8'hc0;
     default:begin
      lcd_rs<=1;
      if(index>=23 && index<=38) lcd_data<=name[127-(index-23)*8 -: 8];
      else lcd_data<=" ";
     end
    endcase
    phase<=1;
   end
   1:begin lcd_e<=1; phase<=2; end
   2:begin lcd_e<=0; phase<=3; end
   3:begin
    // First function-set recovery is 6 ms including setup of the next byte.
    if(index==0 && power_count<POWER_WAIT+2) power_count<=power_count+1;
    else begin phase<=0; index<=(index==38)?5:index+1; end
   end
  endcase
 end
endmodule
