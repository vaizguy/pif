
`include "pifdefs.v"

`timescale 1ns/1ps

module flashctl_tb;

parameter I2C_ADDR = 8'h82;

wire i2c_sda;
wire i2c_scl;
wire i2c_sda_in;
wire i2c_scl_in;
wire sys_rst;
wire ledr;
wire ledg;

reg        i2c_scl_out;
reg        i2c_sda_out;
reg        i2c_ackn;
reg        i2c_din;
reg        i2c_toggle;
reg        i2c_addr;
reg [31:0] outBuf_count;
reg [31:0] obSig_count;
reg [7 :0] outBuf_data [249:0];
reg [7 :0] obSig_data [249:0];

// Fixes elaboration errors
PUR PUR_INST(.PUR(1'b1));
GSR GSR_INST(.GSR(1'b1));

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

    begin
        @(posedge i2c_clk);
        i2c_sda_out = 1'b1;
        @(posedge i2c_clk);
        i2c_scl_out = 1'b1;
        @(posedge i2c_clk);
        i2c_sda_out = 1'b0;
        @(posedge i2c_clk);
        i2c_scl_out = 1'b0;
    end


endtask

//---------------------------------------------
//--       <--- i2cStop ---->   or <-- Rep i2cStop ->
//-- time     |   |   |   | or    |   |   |   |
//-- sda    __________/~~~    ~~~~\______/~~~
//-- scl    ______/~~~~~~~     ______/~~~~~~~
task i2c_stop;

    begin
        @(posedge i2c_clk);
        i2c_sda_out = 1'b0;
        @(posedge i2c_clk);
        i2c_scl_out = 1'b1;
        @(posedge i2c_clk);
        i2c_sda_out = 1'b1;
    end

endtask

//---------------------------------------------
//-- time     |   |   |   |
//-- sda     a bbbbbbbbbbb
//-- scl     _____/~~~\___
task i2c_sendbit;

    input bit;

    begin
        @(posedge i2c_clk);
        i2c_sda_out = bit;
        @(posedge i2c_clk);
        i2c_scl_out = 1'b1;
        @(posedge i2c_clk);
        i2c_scl_out = 1'b0;
    end
endtask

//---------------------------------------------
task i2c_doclock;

    begin
        @(posedge i2c_clk);
        i2c_scl_out = 1'b0;
        @(posedge i2c_clk);
        i2c_scl_out = 1'b1;
        @(posedge i2c_clk);
        i2c_scl_out = 1'b0;
    end

endtask

//---------------------------------------------
task i2c_sendbyte;

    input [7:0] byte;
   
    integer i;
    begin
        $display($time, ": Begin transmitting byte over I2C.");
        for (i = 0; i < 8; i = i +1) begin
          	$display ("Sending Bit-%0d = %b", i, byte[i]);
            i2c_sendbit(byte[i]);
        end
        $display($time, ": Done transmitting byte over I2C.");

        // After this ack=0/nack=1 in i2c_din
        i2c_doclock();
        // wait for 2 clock cycles
        @(posedge i2c_clk);
        i2c_ackn = i2c_din;
        i2c_toggle = ~i2c_toggle;
    end

endtask

//---------------------------------------------
task i2c_recvbit;

    output [7:0] v;

    reg [7:0] bi;

    integer i;
    begin
        for (i = 0; i < 8; i = i +1) begin
            i2c_sendbit(1'b1);
            bi = {bi[6:0], i2c_din}; 
        end
          
        // send ack=0/nak=1
        i2c_sendbit(i2c_ackn);   

        // wait for 2 clock cycles
        @(posedge i2c_clk);
        v = bi;
        i2c_toggle = ~i2c_toggle;
    end

endtask

//---------------------------------------------
task i2c_wr_start;

    input [7:0] i2c_addr;

    begin
        i2c_start();
        i2c_sendbyte({i2c_addr[7:1], 1'b0});
    end
endtask

//---------------------------------------------
task i2c_rd_start;

    input [7:0] i2c_addr;

    begin
        i2c_start();
        i2c_sendbyte({i2c_addr[7:1], 1'b1});
    end
endtask

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
        n = outBuf_count;
        outBuf_data[n] = x;
        $display("%0d [8'b%B] Buffer item added. Write Buffer index: %0d", x, x, n);
        outBuf_count = outBuf_count+1;
        obSig_data[n] = outBuf_data[n];
        obSig_count = outBuf_count;        
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

    input [7:0] i2c_addr;
    
    integer n;
    integer i;

    reg [7:0] tmp;

    begin
        n = outBuf_count;

        if (n>0) begin
            waitfor(1);
            #5;
            $display($time, ": Flush write start.");
            i2c_wr_start(i2c_addr);

            $display($time, ": Begin flushing I2C test buffer.");
            for(i=0; i<=n-1; i=i+1) begin
                tmp = outBuf_data[i];
                i2c_sendbyte(tmp);
                $display("%0d [8'b%B] Buffer item extracted, Read buffer index: %0d", outBuf_data[i], outBuf_data[i], i);   
                outBuf_count  = outBuf_count-1;
                // Debugging bus
                obSig_data[i] = outBuf_data[i];
                obSig_count = outBuf_count;
            end
            $display($time, ": Done flushing I2C test buffer.");

            i2c_stop();
        end
    end
    
endtask
        
//---------------------------------------------
task read_reg; // unused but maybe useful for debug

    input [7:0] i2c_addr;
    input read_count;

    reg [7:0] v;

    integer i;
    begin
        i2c_rd_start(i2c_addr);

        for (i=0; i<=read_count; i=i+1) begin
            if (i < read_count-1) 
                i2c_ackn = 1'b0;
            else
                i2c_ackn = 1'b1;

            i2c_recvbit(v);
            $display("Read Value  %b ", v);
        end
    end
endtask

//---------------------------------------------

assign i2c_sda = i2c_sda_out ? 1'bz : 1'b0; 
assign i2c_scl = i2c_scl_out ? 1'bz : 1'b0; 

// VHDL map for easy ref
assign i2c_sda_in = i2c_sda;
assign i2c_scl_in = i2c_scl;

always @(posedge i2c_scl_in) begin: i2c_data_input
    i2c_din <= i2c_sda_in;
end

//---------------------------------------------

integer i;
// main test 
initial begin: main_test
    // Give some startup time for system
    #150;
    // Reset Buffer Count 
    outBuf_count = 32'd0;
    // Reset Buffer data
    for (i=0; i<250; i=i+1) 
        outBuf_data[i] <= 8'd0;

    // I2C toggle and address
    i2c_ackn     = 1'b0;
    i2c_toggle   = 1'b0;
    i2c_addr     = I2C_ADDR;

    // Begin sequence
    // Write Address
    write_addr(6'd2);
    
    // Write data
    write_data(6'd1); // LED Alternating to LED Sync
    
    // Flush test i2c buffer to DUT i2c lines for given addr
    flush(i2c_addr);

end

initial begin
    #0;    
    $display($time,"TEST EXECUTION STARTED!");
`ifdef DUMP_FSDB
    $fsdbAutoSwitchDumpfile(500, "flashctl_tb.fsdb", 10);
    $fsdbDumpvars(0,flashctl_tb); 
`elsif DUMP_IRUN
    $recordfile("flashctl_tb.trn","incsize=500");
    $recordvars();
`else
    $dumpfile("flashctl_tb.vcd");
    $dumpvars();
`endif
    #999999;
    $display($time,": TEST EXECUTION FINISHED!");
    #1;
    $stop();
end

endmodule 


