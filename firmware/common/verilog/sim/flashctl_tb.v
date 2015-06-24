
`include "pifdefs.v"

`timescale 1ns/1ps

module flashctl_tb;

// 7 bit address for EFB I2C slave is 7'h65
// as 8 bits it will be 7:1, 0 = 7b1000001, 1'b0
//                      7:0    = 8b10000010 = 8'h82
parameter I2C_ADDR = 8'h82;
parameter TEST_BUFFER_DEPTH = 5;

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
reg [7 :0] i2c_addr;
reg [31:0] outBuf_count;
reg [7 :0] outBuf_data [TEST_BUFFER_DEPTH-1:0];
reg [7 :0] inBuf_data  [TEST_BUFFER_DEPTH-1:0];
reg        flush_active;
reg [7 :0] serial_input;

// dbg 
reg i2c_active;

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
    #300 GSRnX = 1'b0;
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

        // dbg 
        i2c_active = 1'b1;
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

        //dbg
        i2c_active = 1'b0;
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
        for (i = 7; i >= 0; i = i-1) begin
          	$display ("Sending Bit-%0d = %b", i, byte[i]);
            i2c_sendbit(byte[i]);
        end
        $display($time, ": Done transmitting byte over I2C.");

        // After this ack=0/nack=1 in i2c_din
        i2c_doclock;
        // wait for 1 clock cycles
        //@(posedge i2c_clk);
        i2c_ackn = i2c_din;
        i2c_toggle = ~i2c_toggle;
    end

endtask

//---------------------------------------------
task i2c_recvbyte;

    output [7:0] v;

    integer i;
    begin
        serial_input = 8'd0;

        for (i = 7; i >= 0; i = i-1) begin
            i2c_sendbit(1'b1);
            serial_input = {serial_input[6:0], i2c_din}; 
        end
          
        // send ack=0/nak=1
        i2c_sendbit(i2c_ackn);   

        // wait for 2 clock cycles
        v = serial_input;
        i2c_toggle = ~i2c_toggle;
    end

endtask

//---------------------------------------------
task i2c_wr_start;

    input [7:0] i2c_addr_i;

    begin
        $display("I2C Write start on I2C Slave addr %b", i2c_addr_i[7:1]);
        i2c_start;
        i2c_sendbyte({i2c_addr_i[7:1], 1'b0});
    end
endtask

//---------------------------------------------
task i2c_rd_start;

    input [7:0] i2c_addr_i;

    begin
        $display("I2C Read start on I2C Slave addr %b", i2c_addr_i[7:1]);
        i2c_start;
        i2c_sendbyte({i2c_addr_i[7:1], 1'b1});
    end
endtask

//---------------------------------------------
task waitfor;

    input [31:0] ticks;
    begin
        $display("Wait %0d tick(s).", ticks);
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

    input [7:0] i2c_slv_addr;
    
    integer n;
    integer i;

    reg [7:0] byte;

    begin
        flush_active = 1'b1;

        n = outBuf_count;

        if (n>0) begin
            waitfor(1);
            #5;
            $display($time, ": Flush write start [I2C Slave Address:%h].", i2c_slv_addr);
            i2c_wr_start(i2c_slv_addr);

            $display($time, ": Begin flushing I2C test buffer.");
            for(i=0; i<=n-1; i=i+1) begin
                byte = outBuf_data[i];
                outBuf_data[i] = 8'd0; // flush bus mem after read
                i2c_sendbyte(byte);
                $display("%0d [8'b%B] Buffer item extracted, Read buffer index: %0d", byte, byte, i);   
                outBuf_count  = outBuf_count-1;
                // Debugging bus
                inBuf_data[i] = byte;
            end
            $display($time, ": Done flushing I2C test buffer.");

            i2c_stop;

            flush_active = 1'b0;
        end
    end
    
endtask
        
//---------------------------------------------
task read_reg; 

    input [7:0] i2c_addr_i;
    input read_count;

    reg [7:0] v;

    integer i;
    begin
        i2c_rd_start(i2c_addr_i);

        for (i=0; i<=read_count-1; i=i+1) begin
            if (i <= read_count-1) 
                i2c_ackn = 1'b0;
            else
                i2c_ackn = 1'b1;

            i2c_recvbyte(v);
            $display("Read Value %b ", v);
        end

        i2c_stop;
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
   
    // debug reg
    flush_active = 1'b0;

    // Reset Buffer Count 
    outBuf_count = 32'd0;

    // Reset In/Out Buffer memory
    for (i=0; i<TEST_BUFFER_DEPTH; i=i+1) begin
        outBuf_data[i] <= 8'd0;
        inBuf_data[i] <= 8'd0;
    end

    // I2C toggle and address
    i2c_ackn     = 1'b0;
    i2c_toggle   = 1'b0;
    i2c_addr     = I2C_ADDR;
    i2c_sda_out  = 1'b1;
    i2c_scl_out  = 1'b1;
    i2c_din      = 1'b0;
    serial_input = 1'b0;

    i2c_active = 1'b0;

    // Give some startup time for system
    // delay to allow test buffers to settle
    // before adding i2c test write values
    #30000;

    // Begin sequence
    // Write Address
    write_addr(6'd2);
    
    // Write data
    write_data(6'd1); // LED Alternating to LED Sync
    
    // Flush test i2c buffer to DUT i2c lines for given addr
    flush(i2c_addr);

    //// Read addr
    //write_addr(6'd2);
    //flush(i2c_addr);

    //// Read data
    //read_reg(i2c_addr, 1);

end

initial begin
    #0;  
  
    $display($time,"TEST EXECUTION STARTED!");

`ifdef DUMP_FSDB
    $fsdbAutoSwitchDumpfile(500, "flashctl_tb.fsdb", 10);
    $fsdbDumpvars(0,flashctl_tb); 
`endif

`ifdef DUMP_TRN
    $recordfile("flashctl_tb.trn","incsize=500");
    $recordvars();
`endif

`ifdef DUMP_VCD
    $dumpfile("flashctl_tb.vcd");
    $dumpvars();
`endif

    #999999;
    $display($time,": TEST EXECUTION FINISHED!");
    #1;
    $stop();
end

endmodule 


