
module DownCounter (Clk, LoadN, CE, InitialVal, zero);

parameter BITS = 10;

input             Clk;
input             LoadN;
input             CE;
input  [BITS-1:0] InitialVal;
output            zero;

reg [BITS:0] Ctr;

always @(posedge Clk) begin: Ctr_gen_blk

    if (CE == 1'b1) begin
        if (LoadN == 1'b0)
            Ctr <= 'b0 & InitialVal;
        else
            Ctr <= Ctr - 1'd1;
    end
end

assign zero = (Ctr[BITS] == 1'b1);

endmodule 

module osch (

    input  stdby,
    output osc,
    output sedstdby
);

parameter NOM_FREQ = 2.08;

reg osc_clk;

initial begin
    #0 osc_clk = 0;
end

always begin
    #(NOM_FREQ) osc_clk = ~osc_clk;
end

assign osc = osc_clk;

endmodule

module pif_flasher (

    // LED interface
    output red  ,
    output green,

    // LED clock
    output xclk
);

parameter FREQ = 2.08;
parameter OSC_RATE = (26600*1000);
parameter OSC_STR = 26.60;
parameter TICK_RATE = 150;
parameter B = 5;
parameter FREQ_DIV = OSC_RATE/TICK_RATE;
parameter TICK_LEN = FREQ_DIV 
// synthesis translate_off
    - FREQ_DIV + 8; // make sim reasonable!
// synthesis translate_on
parameter CLEN = numBits(TICK_LEN);

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

always @(posedge osc) begin : DeltaReg_cnt_blk
    if (Tick)
        DeltaReg <= DeltaReg + 1'd1;
end

always @(posedge osc) begin : Accum_blk
    if (Tick)
        Accum <= 'd0;
    else begin
        Acc <= 'b0 & Accum[B-1:0];
        Delt <= 'b0 & Delta;
        Accum <= Acc + Delt;
    end
end

always @(posedge osc) begin : LED_trigg_blk
    
    LedOn <= (Accum[B] == 1'b1);
    R <= !(to_sl(((LedPhase==0) & LedOn) | ((LedPhase==1) & !LedOn)));
    G <= !(to_sl(((LedPhase==2) & LedOn) | ((LedPhase==3) & !LedOn)));
end

assign red = R;
assign green = G;
assign xclk = osc;

osch #(.NOM_FREQ(OSC_STR)) i_osch (

    /*input */ .stdby   (1'b0), // could use stdby signal
    /*output*/ .osc     (osc ), 
    /*output*/ .sedstdby(    )  // for sim, use stdby sed sig
);

assign LoadN = Tick ? 0 : 1;

DownCounter #(.BITS(CLEN)) i_DownCounter (

    /*input            */ .Clk       (osc  ),
    /*input            */ .LoadN     (LoadN),
    /*input            */ .CE        (1'b1 ),
    /*input  [BITS-1:0]*/ .InitialVal(DIV  ),
    /*output           */ .zero      (Tick ) 
);

function to_sl (input b);

    begin
        to_sl = b ? 1'b1 : 1'b0;
    end        
endfunction

function [31:0] numBits (input arg);

    begin
        case (1)
            (arg == 1'd1): numBits = 1;
            (arg == 1'd0): numBits = 1;
            default: numBits = 1'd1 + numBits(arg/2'd2);
        endcase
    end
endfunction


endmodule

