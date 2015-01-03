
module DownCounter (Clk, sys_rst, LoadN, CE, InitialVal, zero);

parameter BITS = 10;

input             Clk;
input             sys_rst;
input             LoadN;
input             CE;
input  [BITS-1:0] InitialVal;
output            zero;

reg [BITS:0] Ctr;

always @(posedge Clk or negedge sys_rst) begin: Ctr_gen_blk

    if (!sys_rst) 
        Ctr <= {BITS{1'b0}};
    else if (CE == 1'b1) begin
        if (LoadN == 1'b0)
            Ctr <= {1'b0, InitialVal};
        else
            Ctr <= Ctr - 1'd1;
    end
end

assign zero = (Ctr[BITS] == 1'b1);

endmodule 

// synthesis translate_off
module OSCH (

    input  STDBY,
    output OSC,
    output SEDSTDBY
);

parameter NOM_FREQ = 26.6;

reg osc_clk;

initial begin
    #0 osc_clk = 0;
end

always begin
    #((1000/NOM_FREQ)/2) osc_clk = ~osc_clk;
end

assign OSC = osc_clk;

endmodule
// synthesis translate_on

module pif_flasher (

    // LED interface
    output red  ,
    output green,

    // LED clock
    output xclk,

    // system reset
    input sys_rst
);

parameter SIM_OSC_STR = 2.08; // Using 2MHz for simulation purposes
parameter OSC_STR = 26.6
// synthesis translate_off
    -26.6 + SIM_OSC_STR
// synthesis translate_on
;
parameter OSC_RATE = (OSC_STR*(10**6)); // 26.6 MHz
parameter TICK_RATE = 150; // 150 Hz
parameter B = 5;

// divide down from 2MHz to approx 150Hz
parameter FREQ_DIV = OSC_RATE/TICK_RATE; // 26600000/150=177333.33

parameter SIM_TICK_LEN = 8; // 2Mhz / 8 (for easy debug)
parameter TICK_LEN = FREQ_DIV 
// synthesis translate_off
    - FREQ_DIV + SIM_TICK_LEN // make sim reasonable!
// synthesis translate_on
;

//parameter CLEN = numBits(TICK_LEN);
// TODO hardcoding for now as recursive function 
// numbits cannot be directly implemented in verilog.
// 32 should serve as an accommodative bit width.
parameter SIM_CLEN = 4;
parameter CLEN = 32
// synthesis translate_off
    - 32 + SIM_CLEN           // make sim reasonable!
// synthesis translate_on
;

wire [CLEN-1:0] DIV = TICK_LEN;

wire osc;
wire Tick;
wire LoadN;
wire [B-1:0] Delta;
wire [1:0] LedPhase;

reg LedOn;
reg R;
reg G;
reg [B:0] Accum;
reg [B+1:0] DeltaReg;
reg [B:0] Acc;
reg [B:0] Delt;

assign Delta = DeltaReg[B-1:0];
assign LedPhase = DeltaReg[B+1:B];

always @(posedge osc or negedge sys_rst) begin : DeltaReg_cnt_blk

    if (!sys_rst)
        DeltaReg <= 'd0;
    else if (Tick)
        DeltaReg <= DeltaReg + 1'd1;
end

always @(posedge osc or negedge sys_rst) begin : Accum_blk
    
    if (!sys_rst)  begin
        Accum <= {B{1'b0}};
        Acc   <= {B{1'b0}};
        Delt  <= {B{1'b0}};
    end
    else if (Tick)
        Accum <= {B{1'b0}};
    else begin
        Acc   <= {1'b0, Accum[B-1:0]};
        Delt  <= {1'b0, Delta       };
        Accum <= Acc + Delt;
    end
end

always @(posedge osc or negedge sys_rst) begin : LED_trigg_blk
    
    if (!sys_rst) begin
        LedOn <= 1'b0;
        R     <= 1'b0;
        G     <= 1'b0;
    end
    else begin
        LedOn <= (Accum[B] == 1'b1);
        R <= !(((LedPhase==0) & LedOn) | ((LedPhase==1) & !LedOn));
        G <= !(((LedPhase==2) & LedOn) | ((LedPhase==3) & !LedOn));
    end
end

assign red = R;
assign green = G;
assign xclk = osc;

OSCH  #(.NOM_FREQ(OSC_STR)) 
i_OSCH (

    /*input */ .STDBY   (1'b0), // could use stdby signal
    /*output*/ .OSC     (osc ), 
    /*output*/ .SEDSTDBY(    )  // for sim, use stdby sed sig
);

assign LoadN = Tick ? 0 : 1;

DownCounter #(.BITS(CLEN)) i_DownCounter (

    /*input            */ .Clk       (osc    ),
    /*input            */ .sys_rst   (sys_rst),
    /*input            */ .LoadN     (LoadN  ),
    /*input            */ .CE        (1'b1   ),
    /*input  [BITS-1:0]*/ .InitialVal(DIV    ),
    /*output           */ .zero      (Tick   ) 
);

// TODO Recursve functions do not work in verilog
// difficult to mimic VHDL code exactly
// mostly may not be required.
//function [31:0] numBits (input arg);
//
//    begin
//        case (1)
//            (arg == 1'd1): numBits = 1;
//            (arg == 1'd0): numBits = 1;
//            default: numBits = 1'd1 + numBits(arg/2'd2);
//        endcase
//    end
//endfunction


endmodule

