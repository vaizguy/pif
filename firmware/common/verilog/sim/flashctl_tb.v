
`include "pifdefs.v"

`timescale 1ns/1ps

module flashctl_tb;

parameter I2C_ADDR = 8'h82;

wire i2c_sda;
wire i2c_scl;
wire sys_rst;
wire ledr;
wire ledg;

reg i2c_scl_out;
reg i2c_sda_out;
reg i2c_ackn;
reg i2c_toggle;
reg i2c_addr;
reg [31:0] outBuf_count;
reg [7 :0] outBuf_data [249:0];

flasher i_flasher(

    // I2C interface
    /*inout*/  .SDA(i2c_sda) ,
    /*inout*/  .SCL(i2c_scl) ,
    
    // Global set/resetn
    /*input*/  .GSRn(sys_rst),

    // LED interface
    /*output*/ .LEDR(ledr),
    /*output*/ .LEDG(ledg)
);

reg i2c_clk;
reg clk_20mhz;

// I2C tasks 
// Generate I2C clock
initial begin: i2c_clk_gen
    #0 i2c_clk = 1'b0;
    forever begin
        #1250 i2c_clk = ~i2c_clk; // 2500 ns i2c clock =~ 400Khz
    end
end


// 20 Mhz clock
initial begin: clk_20mhz_gen
    #0 clk_20mhz = 1'b0;
      forever begin
        #25 clk_20mhz = ~clk_20mhz; // 50 ns clock =~ 20Mhz
    end
end    

// reset
reg GSRnX;
initial begin: reset_blk
    #0   GSRnX = 1'b0;
    #100 GSRnX = 1'b1;
end

assign sys_rst = GSRnX;

//---------------------------------------------
//--       <--- i2cStart ---->   or <-- Rep i2cStart ->
//-- time     |   |   |   |         |   |   |   |
//-- sda    ~~~~~~~~~~\_____      __/~~~~~~~\_____
//-- scl    __/~~~~~~~~~~~\__     ______/~~~~~~~\__
task i2c_start;

    output sda;
    output scl;
    begin
        @(posedge i2c_clk);
        sda = 1'b1;
        @(posedge i2c_clk);
        scl = 1'b1;
        @(posedge i2c_clk);
        sda = 1'b0;
        @(posedge i2c_clk);
        scl = 1'b0;
    end


endtask

//---------------------------------------------
//--       <--- i2cStop ---->   or <-- Rep i2cStop ->
//-- time     |   |   |   | or    |   |   |   |
//-- sda    __________/~~~    ~~~~\______/~~~
//-- scl    ______/~~~~~~~     ______/~~~~~~~
task i2c_stop;

    output sda;
    output scl;

    begin
        @(posedge i2c_clk);
        sda = 1'b0;
        @(posedge i2c_clk);
        scl = 1'b1;
        @(posedge i2c_clk);
        sda = 1'b1;
    end

endtask

//---------------------------------------------
//-- time     |   |   |   |
//-- sda     a bbbbbbbbbbb
//-- scl     _____/~~~\___
task i2c_sendbit;

    input bit;
    output sda;
    output scl;

    begin
        @(posedge i2c_clk);
        sda = bit;
        @(posedge i2c_clk);
        scl = 1'b1;
        @(posedge i2c_clk);
        scl = 1'b0;
    end
endtask

//---------------------------------------------
task i2c_doclock;

    output scl;
    
    begin
        @(posedge i2c_clk);
        scl = 1'b0;
        @(posedge i2c_clk);
        scl = 1'b1;
        @(posedge i2c_clk);
        scl = 1'b0;
    end

endtask

//---------------------------------------------
task i2c_sendbyte;

    output sda;
    output scl;
    output ack;
    input  i2c_din;
    output i2c_toggle;
    input [7:0] byte;
   
    integer i;
    begin
        for (i = 0; i < 8; i = i +1) begin
          	$display ("Sending Byte no: %d , val: %b", i, byte[i]);
            i2c_sendbit(byte[i], sda, scl);
        end

        // After this ack=0/nack=1 in i2c_din
        i2c_doclock(scl);
        // wait for 2 clock cycles
        @(posedge i2c_clk);
        ack = i2c_din;
        i2c_toggle = ~i2c_toggle;
    end

endtask

//---------------------------------------------
task i2c_recvbit;

    output sda;
    output scl;
    input  ack;
    input  i2c_din;
    output i2c_toggle;    
    output [7:0] v;

    reg [7:0] bi;

    integer i;
    begin
        for (i = 0; i < 8; i = i +1) begin
            i2c_sendbit(1'b1, sda, scl);
            bi = {bi[6:0], i2c_din}; 
        end
          
        // send ack=0/nak=1
        i2c_sendbit(ack, sda, scl);   

        // wait for 2 clock cycles
        @(posedge i2c_clk);
        v = bi;
        i2c_toggle = ~i2c_toggle;
    end

endtask

//---------------------------------------------
task i2c_wr_start;

    output sda;
    output scl;
    output ack;
    input  i2c_din;
    output i2c_toggle;    
    input [7:0] i2c_addr;

    begin
        i2c_start(sda, scl);
        i2c_sendbyte(sda, scl, ack, i2c_din, i2c_toggle, {i2c_addr[7:1], 1'b0});
    end
endtask

//---------------------------------------------
task i2c_rd_start;

    output sda;
    output scl;
    output ack;
    input  i2c_din;
    output i2c_toggle;
    input [7:0] i2c_addr;

    begin
        i2c_start(sda, scl);
        i2c_sendbyte(sda, scl, ack, i2c_din, i2c_toggle, {i2c_addr[7:1], 1'b1});
    end
endtask

//---------------------------------------------
reg i2c_din;
always @(posedge i2c_clk) begin: i2c_data_input
    i2c_din <= i2c_sda;
end


//---------------------------------------------
task waitfor;

    input [31:0] ticks;
    begin
        repeat(ticks) @(posedge clk_20mhz);
    end

endtask

//---------------------------------------------
task write_bus;

    input [7:0] x;
    integer n;

    begin
        outBuf_data[n] = x;
        outBuf_count = outBuf_count+1;
        waitfor(1);
    end
endtask

//---------------------------------------------
task write_data;

    input [`I2C_DATA_BITS-1:0] V;

    write_bus({`D_ADDR, V});
endtask

//---------------------------------------------
task write_addr;

    input [`I2C_DATA_BITS-1:0] Addr;

    write_bus({`A_ADDR, Addr});
endtask

//---------------------------------------------
task flush;

    output sda;
    output scl;
    output ack;
    input  i2c_din;
    output i2c_toggle;

    input [7:0] i2c_addr;
    
    integer n;
    integer i;

    begin
        n = outBuf_count;

        if (n>0) begin
            waitfor(1);
            #5;
            i2c_wr_start(sda, scl, ack, i2c_din, i2c_toggle, i2c_addr);

            for(i=0; i<n-1; i = i+1) begin
                i2c_sendbyte(sda, scl, ack, i2c_din, i2c_toggle, outBuf_data[i]);
                outBuf_count  = outBuf_count - 1;
            end
            i2c_stop(sda, scl);
        end
    end
    
endtask
        
//---------------------------------------------
task read_reg; // unused but maybe useful for debug

    output sda;
    output scl;
    output ack;
    input  i2c_din;
    output i2c_toggle;

    input [7:0] i2c_addr;
    input read_count;

    reg i2c_ack;
    reg [7:0] v;

    integer i;
    begin
        i2c_rd_start(sda, scl, ack, i2c_din, i2c_toggle, i2c_addr);

        for (i=0; i<=read_count; i=i+1) begin
            if (i < read_count-1) 
                i2c_ack = 1'b0;
            else
                i2c_ack = 1'b1;

            i2c_recvbit(sda, scl, i2c_ack, i2c_din, i2c_toggle, v);
            $display("Value  %b ", v);
        end
    end
endtask

integer i;
// main test 
initial begin: main_test
    // Give some startup time for system
    #150;
    // Reset Buffer Count 
    outBuf_count = 32'd0;
    // Reset Buffer data
    for (i=0; i<8; i=i+1) 
        outBuf_data[i] <= 8'd0;

    // I2C toggle and address
    i2c_ackn     = 1'b0;
    i2c_toggle   = 1'b0;
    i2c_addr     = 8'h82;

    // Begin sequence
    // Write Address
    write_addr(6'd2);
    // Write data
    write_data(6'd1); // LED Alternating to LED Sync
    #9850;
    // Flush test i2c buffer
    flush(i2c_sda_out, i2c_scl_out, i2c_ackn, i2c_din, i2c_toggle, i2c_addr);

end

initial begin
    #0;    
    $display($time,"TEST EXECUTION STARTED!");
`ifdef DUMP_FSDB
    $fsdbAutoSwitchDumpfile(500, "piffla_tb.fsdb", 10);
    $fsdbDumpvars(0,flashctl_tb); 
`elsif DUMP_IRUN
    $recordfile("flashctl_tb","incsize=500");
    $recordvars();
`else
    $dumpfile("flashctl_tb_vsim");
    $dumpvars();
`endif
    #19999;
    $display($time,"TEST EXECUTION FINISHED!");
    #20000 $stop();
end

endmodule 


