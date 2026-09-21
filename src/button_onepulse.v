`timescale 1ns/1ps
module button_onepulse #(parameter integer STABLE_CYCLES=20)(
  input wire clk,rst,button, output reg pulse);
  (* ASYNC_REG="TRUE" *) reg sync1,sync2;
  reg accepted;
  integer count;
  always @(posedge clk or posedge rst) begin
    if(rst) begin sync1<=0; sync2<=0; end
    else begin sync1<=button; sync2<=sync1; end
  end
  always @(posedge clk or posedge rst) begin
    if(rst) begin count<=0; accepted<=0; pulse<=0; end
    else begin
      pulse<=0;
      if(sync2==accepted) count<=0;
      else if(count==STABLE_CYCLES-1) begin
        accepted<=sync2; count<=0; pulse<=sync2;
      end else count<=count+1;
    end
  end
endmodule
