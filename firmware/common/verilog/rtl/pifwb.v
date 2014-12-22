`include "pifdefs.v"

module pifwb (

    inout       i2c_SCL,
    inout       i2c_SDA,

    input       xclk   ,

    //XIrec       XI     , // works only with sv

    output                                 XI_PWr,         /*: boolean;      -- registered single-clock write strobe*/ 
    output  [2**`XA_BITS-1:0             ] XI_PRWA,        /*: TXA;          -- registered incoming addr bus        */
    output                                 XI_PRdFinished, /*: boolean;      -- registered in clock PRDn goes off   */ 
    output  [`XSUBA_MAX   :0             ] XI_PRdSubA,     /*: TXSubA;       -- read sub-address                    */
    output  [7            :`I2C_TYPE_BITS] XI_PD,          /*: TwrData;      -- registered incoming data bus        */

    input [7:0] XO
);

// WB state machine encoding 
parameter WBstart  = 4'd0;
parameter WBinit1  = 4'd1;
parameter WBinit2  = 4'd2;
parameter WBinit3  = 4'd3;
parameter WBinit4  = 4'd4;
parameter WBidle   = 4'd5;
parameter WBwaitTR = 4'd6;
parameter WBin0    = 4'd7;
parameter WBout0   = 4'd8;
parameter WBout1   = 4'd9;
parameter WBwr     = 4'd10;
parameter WBrd     = 4'd11;

// wishbone/EFB addresses
parameter [7:0]  I2C1_CR    = 8'h40;
parameter [7:0]  I2C1_CMDR  = 8'h41;
parameter [7:0]  I2C1_BR0   = 8'h42;
parameter [7:0]  I2C1_BR1   = 8'h43;
parameter [7:0]  I2C1_TXDR  = 8'h44;
parameter [7:0]  I2C1_SR    = 8'h45;
parameter [7:0]  I2C1_GCDR  = 8'h46;
parameter [7:0]  I2C1_RXDR  = 8'h47;
parameter [7:0]  I2C1_IRQ   = 8'h48;
parameter [7:0]  I2C1_IRQEN = 8'h49;

parameter [7:0]  I2C2_CR    = 8'h4A;
parameter [7:0]  I2C2_CMDR  = 8'h4B;
parameter [7:0]  I2C2_BR0   = 8'h4C;
parameter [7:0]  I2C2_BR1   = 8'h4D;
parameter [7:0]  I2C2_TXDR  = 8'h4E;
parameter [7:0]  I2C2_SR    = 8'h4F;
parameter [7:0]  I2C2_GCDR  = 8'h50;
parameter [7:0]  I2C2_RXDR  = 8'h51;
parameter [7:0]  I2C2_IRQ   = 8'h52;
parameter [7:0]  I2C2_IRQEN = 8'h53;
               
parameter [7:0]  CFG_CR     = 8'h70;
parameter [7:0]  CFG_TXDR   = 8'h71;
parameter [7:0]  CFG_SR     = 8'h72;
parameter [7:0]  CFG_RXDR   = 8'h73;
parameter [7:0]  CFG_IRQ    = 8'h74;
parameter [7:0]  CFG_IRQEN  = 8'h75;

wire [7:0] wbDat_o;

reg [7:0] wbDat_i;
reg [7:0] wbAddr;
reg [7:0] wbOutBuff;

reg busy; 
reg txReady; 
reg rxReady; 
reg lastTxNak; 
reg isAddr; 
reg isData;

reg wbCyc;
reg wbStb;
reg wbWe;

wire wbAck_o;

reg [3:0] WBstate;
reg [3:0] rwReturn;

reg hitI2CSR;
reg hitI2CRXDR;
reg hitCFGRXDR;
reg cfgBusy;
reg [`XSUBA_MAX:0] RdSubAddr;
reg [`XSUBA_MAX:0] WrSubAddr;
reg [2**`XA_BITS -1:0] rwAddr;
reg [`I2C_DATA_BITS:0] inData;

// Local XI registers 
//XIrec XIloc;
reg                                 XIloc_PWr;         /*: boolean;      -- registered single-clock write strobe*/ 
reg  [2**`XA_BITS-1:0             ] XIloc_PRWA;        /*: TXA;          -- registered incoming addr bus        */
reg                                 XIloc_PRdFinished; /*: boolean;      -- registered in clock PRDn goes off   */ 
reg  [`XSUBA_MAX   :0             ] XIloc_PRdSubA;     /*: TXSubA;       -- read sub-address                    */
reg  [7            :`I2C_TYPE_BITS] XIloc_PD;          /*: TwrData;      -- registered incoming data bus        */


// quasi-static data out from the USB
reg [15:0] rst_pipe = 16'hffff;
wire rst = rst_pipe[15];

//---------------------------------------------------------------------
// Power-Up Reset for 16 clocks
// assumes initialisers are honoured by the synthesiser
always @(posedge xclk) begin: reset_blk
    rst_pipe <= {rst_pipe[14:0], 1'b0};
end

// used in debug mode to reset the internal 16-bit counters
wire wbRst = 1'b0
// synthesis translate_off
               | rst
// synthesis translate_on
;

// Embedded function block (EFB)
efb myEFB (
    .wb_clk_i (xclk   ), 
    .wb_rst_i (wbRst  ), 
    .wb_cyc_i (wbCyc  ), 
    .wb_stb_i (wbStb  ), 
    .wb_we_i  (wbWe   ), 
    .wb_adr_i (wbAddr ), 
    .wb_dat_i (wbDat_i), 
    .wb_dat_o (wbDat_o), 
    .wb_ack_o (wbAck_o), 
    .i2c1_scl (i2c_SCL), 
    .i2c1_sda (i2c_SDA), 
    .i2c1_irqo(       )
);

//---------------------------------------------------------------------
// wishbone state machine

wire wbAck = (wbAck_o == 1'b1);

reg [3:0] nextState;
reg vSlaveTransmitting;
reg vTxRxRdy;
reg vBusy;
reg vTIP;
reg vRARC;
reg vTROE;
reg [7:0] vInst;


always @(posedge xclk) begin: wb_i2c_blk

    hitI2CSR   <= (wbAddr == I2C1_SR  );
    hitI2CRXDR <= (wbAddr == I2C1_RXDR);
    hitCFGRXDR <= (wbAddr == CFG_RXDR );
end
    
always @(posedge xclk) begin: wb_statemachine_blk_1

    if (rst) begin
        nextState <= WBstart;
        rwReturn  <= WBstart;
        wbStb     <= 1'b0;
        wbCyc     <= 1'b0;
        wbWe      <= 1'b0;
        busy      <= 1'b0;
        txReady   <= 1'b0;
        rxReady   <= 1'b0;
        lastTxNak <= 1'b0;
    end
    else begin

        case (WBstate)

            //-----------------------------------
            // initialise
            
            WBstart: 
            begin
                wbAddr    <= I2C1_CMDR;
                wbDat_i   <= 8'h04;
                rwReturn  <= WBinit1;
                nextState <= WBwr;
                // clock stretch disable
            end

            WBinit1:
            begin
                wbAddr    <= I2C1_SR;
                wbDat_i   <= 8'h0;
                rwReturn  <= WBinit2;
                nextState <= WBrd;
                // wait for not busy
            end

            WBinit2:
            begin
                if (busy)
                    nextState <= WBrd;
                else begin
                    wbAddr    <= I2C1_RXDR;
                    wbDat_i   <= 8'h0;
                    rwReturn  <= WBinit3;
                    nextState <= WBrd;
                    // read and discard RXDR, #1
                end
            end

            WBinit3:
            begin
                wbAddr    <= I2C1_RXDR;
                wbDat_i   <= 8'h0;
                rwReturn  <= WBinit4;
                nextState <= WBrd;
                // read and discard RXDR, #2
            end

            WBinit4: 
            begin
                wbAddr    <= I2C1_CMDR;
                wbDat_i   <= 'h00;
                rwReturn  <= WBidle;
                nextState <= WBwr;
                // clock stretch enable
            end

            //-----------------------------------
            // wait for I2C activity - "busy" is signalled

            WBidle :
            begin
                if (busy) begin
                    wbAddr   <= I2C1_SR;
                    wbDat_i  <= 8'h0;
                    rwReturn <= WBwaitTR;
                end
                else
                begin
                    wbAddr   <= I2C1_SR;
                    wbDat_i  <= 8'h0;
                    rwReturn <= WBidle;
                    // wait for I2C activity - "busy" is signalled
                end
                nextState <= WBrd;
            end

            //-----------------------------------
            // wait for TRRDY

            WBwaitTR:
            begin
                if (lastTxNak)                      // last read?
                    nextState <= WBstart;
                else if (txReady) begin
                    wbAddr    <= I2C1_TXDR;
                    wbDat_i   <= XO;
                    rwReturn  <= WBout0;
                    nextState <= WBwr;
                end
                else if (rxReady) begin
                    wbAddr    <= I2C1_RXDR;
                    wbDat_i   <= 8'h0;
                    rwReturn  <= WBin0;
                    nextState <= WBrd;
                end
                else if (!busy)
                    nextState <= WBstart;
                else
                    nextState <= WBrd;
            end

            //-----------------------------------
            // incoming data

            WBin0: nextState <= WBidle;              // incoming data

            //-----------------------------------
            // outgoing data

            WBout0:  nextState <= WBout1;            // outgoing data

            WBout1:  nextState <= WBidle;            // outgoing data

            //-----------------------------------
            // read cycle

            WBrd:
            begin
                if (wbAck) begin
                    wbStb <= 1'b0;
                    wbCyc <= 1'b0;

                    if (hitI2CSR) begin
                        vTIP               <= (wbDat_o[7] == 1'b1);
                        vBusy              <= (wbDat_o[6] == 1'b1);
                        vRARC              <= (wbDat_o[5] == 1'b1);
                        vSlaveTransmitting <= (wbDat_o[4] == 1'b1);
                        vTxRxRdy           <= (wbDat_o[2] == 1'b1);
                        vTROE              <= (wbDat_o[1] == 1'b1);
      
                        txReady   <= vBusy & (vTxRxRdy &  vSlaveTransmitting & !vTIP );
                        rxReady   <= vBusy & (vTxRxRdy & !vSlaveTransmitting         );
                        lastTxNak <= vBusy & (vRARC    &  vSlaveTransmitting &  vTROE);
                        busy      <= vBusy;
                    end 
                    else if (hitI2CRXDR) begin
                        isAddr  <= (wbDat_o[7:`I2C_DATA_BITS] == `A_ADDR);
                        isData  <= (wbDat_o[7:`I2C_DATA_BITS] == `D_ADDR);
                        inData  <=  wbDat_o[7:`I2C_DATA_BITS];
                    end
                    else if (hitCFGRXDR) begin
                        cfgBusy <= (wbDat_o[7] == 1'b1);
                    end
                        
                    wbOutBuff <= wbDat_o;
                    nextState <= rwReturn;
                end
                else begin
                    wbStb <= 1'b1;
                    wbCyc <= 1'b1;
                end
            end

            //-----------------------------------
            // write cycle

            WBwr:
            begin
                if (wbAck) begin
                    wbStb <= 1'b0;
                    wbCyc <= 1'b0;
                    wbWe  <= 1'b0;
                    nextState <= rwReturn;
                end
                else begin
                    wbStb <= 1'b1;
                    wbCyc <= 1'b1;
                    wbWe  <= 1'b1;
                end
            end

            // others
            default: nextState <= WBstart;

        endcase
    end
end

always @(posedge xclk) begin: wb_statemachine_blk_2

    if (rst) begin
        rwAddr            <= 'd0;
        RdSubAddr         <= 'd0;
        WrSubAddr         <= 'd0;
        XIloc_PD          <= 'd0;
        XIloc_PWr         <= 'd0;
        XIloc_PRdFinished <= 'd0;
    end 
    else begin 

        XIloc_PRdFinished <= (WBstate == WBout0);

        if ((WBstate == WBin0) & isAddr)
            rwAddr <= inData[`XA_BITS-1:0];

        if ((WBstate == WBin0) & isAddr)
            RdSubAddr <= 'd0;
        else if (XIloc_PRdFinished)
            RdSubAddr <= (RdSubAddr +1) % (`XSUBA_MAX+1);

        if ((WBstate == WBin0) & isAddr)
            WrSubAddr <= 'd0;
        else if (XIloc_PWr)
            WrSubAddr <= (WrSubAddr +1) % (`XSUBA_MAX+1);

        if ((WBstate == WBin0) & isData) begin
            XIloc_PD  <= inData;
            XIloc_PWr <= 1'b1;
        end
        else
            XIloc_PWr <= 1'b0;

        WBstate <= nextState;
    end
end

always @(posedge xclk) begin: wb_statemachine_blk_3

    if (rst) begin
        XIloc_PRWA    <= 'd0;
        XIloc_PRdSubA <= 'd0;        
    end
    else begin
        XIloc_PRWA    <= rwAddr;
        XIloc_PRdSubA <= RdSubAddr;
    end
end


//assign XI <= XIloc;

assign XI_PWr         = XIloc_PWr        ;
assign XI_PRWA        = XIloc_PRWA       ;
assign XI_PRdFinished = XIloc_PRdFinished;
assign XI_PRdSubA     = XIloc_PRdSubA    ;
assign XI_PD          = XIloc_PD         ;

   
endmodule
