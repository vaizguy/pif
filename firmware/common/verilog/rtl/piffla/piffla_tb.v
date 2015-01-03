
module piffla_tb;

wire red, green, xclk, sys_rst;
reg  rst;

pif_flasher i_pif_flasher(

    // LED interface
    /*output*/ .red  (red),
    /*output*/ .green(green),

    // LED clock
    /*output*/ .xclk(xclk),
   
    // system reset
    /*input*/  .sys_rst(sys_rst)
);

assign sys_rst = rst;

initial begin
    #0;
    //$deposit(i_pif_flasher.R, 1'b0);
    //$deposit(i_pif_flasher.G, 1'b0);
    //$deposit(i_pif_flasher.LedOn, 1'b0);
    //$deposit(i_pif_flasher.DeltaReg, 1'b0);
    //$deposit(i_pif_flasher.i_DownCounter.Ctr, 1'b0);
    rst = 1'b1;
    #100;
    rst = 1'b0;
    #100;
    rst = 1'b1;
end

initial begin
    #0;    
    $display($time,"TEST EXECUTION STARTED!");
`ifdef DUMP_FSDB
    $fsdbAutoSwitchDumpfile(500, "piffla_tb.fsdb", 10);
    $fsdbDumpvars(0,piffla_tb); 
`elsif DUMP_IRUN
    $recordfile("piffla_tb","incsize=500");
    $recordvars();
`else
    $dumpfile("piffla_vsim");
    $dumpvars();
`endif
    #999999;
    $display($time,"TEST EXECUTION FINISHED!");
    #1000000 $stop();
end


endmodule
