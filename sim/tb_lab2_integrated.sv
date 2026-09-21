`timescale 1ns/1ps
module tb_lab2_integrated;
    reg clk=0, rst=0, mode_button=0, step_button=0;
    reg [7:0] sw=0;
    wire [7:0] led, seg_data, seg_com, lcd_data;
    wire lcd_e, lcd_rs, lcd_rw;
    // Accelerated debounce/divider; LCD byte timing keeps the default cycle counts.
    lab2_integrated #(.STABLE_CYCLES(3), .DIVISOR(10)) dut(
        clk,rst,mode_button,step_button,sw,led,seg_data,seg_com,
        lcd_e,lcd_rs,lcd_rw,lcd_data);
    always #5 clk=~clk;
    integer checks=0, address=0, i, pulses=0, active_slots=0, blank_slots=0;
    reg [7:0] screen[0:31];
    reg [127:0] names[0:7];
    time last_data_change=0, last_enable_rise=0;
    reg saw_enable=0;
    task step; begin @(posedge clk); #1; end endtask
    task check(input condition, input [8*100-1:0] description);
    begin
        checks=checks+1;
        if(condition!==1'b1) begin
            $display("LAB2_INTEGRATED_FAIL %0s time=%0t",description,$time);
            $fatal(1,"check failed");
        end
    end endtask
    // Decode the actual LCD bus rather than reading the controller's name ROM.
    always @(lcd_data or lcd_rs) begin
        if(lcd_e===1'b1) $fatal(1,"LCD data changed while enable high");
        last_data_change=$time;
    end
    always @(posedge lcd_e) begin
        check(lcd_rw===0,"LCD is write only");
        check($time-last_data_change>=10,"LCD setup at least one main clock");
        last_enable_rise=$time; saw_enable=1;
    end
    always @(negedge lcd_e) if(saw_enable) begin
        check($time-last_enable_rise>=10,"LCD enable high at least one main clock");
        saw_enable=0;
        if(lcd_rs) begin
            if(address<32) screen[address]=lcd_data;
            address=address+1;
        end else if(lcd_data==8'h80) address=0;
        else if(lcd_data==8'hc0) address=16;
    end
    task switches(input [7:0] value);
    begin sw=value; repeat(4) step; end endtask
    task push_step;
    begin
        step_button=1; step; step_button=0; repeat(3) step;
        step_button=1; repeat(10) step;
        step_button=0; repeat(10) step;
    end endtask
    task next_mode(input [2:0] expected);
    begin
        mode_button=1; step; mode_button=0; repeat(3) step;
        mode_button=1; repeat(10) step;
        mode_button=0; repeat(10) step;
        check(dut.mode===expected,"mode advances exactly once despite bounce");
        if(expected!=7) check(seg_com===8'hff && seg_data===0,"array off outside scan mode");
    end endtask
    task check_lcd(input integer mode_number);
    integer c;
    begin
        repeat(300) step;
        check({screen[0],screen[1],screen[2],screen[3],screen[4]}==="MODE ","LCD first line prefix");
        check(screen[5]==="0" && screen[6]===(8'h31+mode_number),"LCD displayed mode number");
        for(c=7;c<16;c=c+1) check(screen[c]===" ","LCD first line padded");
        for(c=0;c<16;c=c+1) check(screen[16+c]===names[mode_number][127-c*8 -: 8],"LCD full second line");
    end endtask
    initial begin $dumpfile("wave.vcd"); $dumpvars(0,tb_lab2_integrated); end
    initial begin #1000000; $fatal(1,"watchdog"); end
    initial begin
        names[0]="UP DOWN COUNTER "; names[1]="CLOCK DIVIDER   ";
        names[2]="REGISTER PAIR   "; names[3]="SHIFT REGISTER  ";
        names[4]="PISO            "; names[5]="MOORE FSM       ";
        names[6]="MEALY FSM       "; names[7]="8 DIGIT SCAN    ";
        for(i=0;i<32;i=i+1) screen[i]=0;
        #2; rst=1; repeat(3) step; rst=0; repeat(4) step;
        check(dut.mode===0 && led===0,"power reset to first mode");
        switches(0); push_step; check(led===1,"counter increments once");
        switches(1); push_step; check(led===0,"counter decrements");
        push_step; check(led===15,"counter wraps down"); check_lcd(0);

        next_mode(1); check_lcd(1);
        pulses=0;
        repeat(30) begin step; if(led[4]) pulses=pulses+1; end
        check(pulses===3,"divider ticks three times in thirty clocks");

        next_mode(2); switches(8'ha1); push_step; check(led===8'ha0,"register load");
        switches(8'h33); push_step; check(led===8'h3a,"register old-value transfer");
        push_step; check(led===8'h33,"register next transfer"); check_lcd(2);

        next_mode(3); switches(8'h80); push_step; check(led===8'h08,"shift input 1");
        switches(0); push_step; check(led===8'h04,"shift input 0"); check_lcd(3);

        next_mode(4); switches(8'ha1); push_step; check(led===8'ha1,"PISO load");
        switches(8'ha0); push_step; check(led===8'h40,"PISO first shift");
        push_step; check(led===8'h81,"PISO second shift"); check_lcd(4);

        next_mode(5); switches(8'h80); check(led===0,"Moore input cannot advance alone");
        push_step; check(led===1,"Moore first transition");
        push_step; check(led===2,"Moore second transition");
        push_step; check(led===0,"Moore wraps"); check_lcd(5);

        next_mode(6); switches(0); check(led===0,"Mealy input zero");
        switches(8'h80); check(led===2,"Mealy changes without step");
        push_step; check(led===5,"Mealy new state and output");
        switches(0); check(led===4,"Mealy input zero preserves state"); check_lcd(6);

        next_mode(7); switches(8'h90); check_lcd(7);
        repeat(64) begin
            step;
            if(seg_com==8'hff) blank_slots=blank_slots+1;
            else begin
                active_slots=active_slots+1;
                check(seg_com===(8'hff ^ (8'h80>>led[2:0])),"scan COM polarity and index");
                if(led[2:0]==0) check(seg_data===8'hf6,"scan DIP digit 9");
            end
        end
        check(active_slots===32 && blank_slots===32,"scan blanking duty");
        next_mode(0); check(led===0,"mode wrap resets previous counter value"); check_lcd(0);
        // Simultaneous mode and step: reset has priority over a core update.
        mode_button=1; step_button=1; repeat(12) step;
        mode_button=0; step_button=0; repeat(12) step;
        check(dut.mode===1 && dut.count===0,"simultaneous controls reset old core");
        rst=1; repeat(4) step;
        check(dut.mode===0 && led===0 && lcd_e===0 && seg_com===8'hff,"reset during operation");
        $display("LAB2_INTEGRATED_PASS modes=8 checks=%0d",checks);
        $finish;
    end
endmodule
