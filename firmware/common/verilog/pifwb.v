
module pifwb (

    inout       i2c_SCL,
    inout       i2c_SDA,

    input       xclk   ,

    XIrec       XI     ,
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

wire wbCyc;
wire wbStb;
wire wbWe;
wire wbAck_o;

wire [7:0] wbDat_o;
wire [7:0] wbDat_i;
wire [7:0] wbAddr;
wire [7:0] wbOutBuff;

wire [3:0] WBstate;
wire [3:0] rwReturn;

wire busy; 
wire txReady; 
wire rxReady; 
wire lastTxNak; 
wire wbAck; 
wire isAddr; 
wire isData;

// quasi-static data out from the USB
XIrec Xiloc;
reg [15:0] rst_pipe = 16'hffff;
wire rst = rst_pipe[15];

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

reg hitI2CSR;
reg hitI2CRXDR;
reg hitCFGRXDR;
reg cfgBusy;
reg [`XSUBA_MAX:0] RdSubAddr;
reg [`XSUBA_MAX:0] WrSubAddr;
reg [2**`XA_BITS -1:0] rwAddr;
reg [`I2C_DATA_BITS:0] inData;
reg wbRst;

// used in debug mode to reset the internal 16-bit counters
assign wbRst = 1'b0
// synthesis translate_off
               | rst
// synthesis translate_on
;

//---------------------------------------------------------------------
// Power-Up Reset for 16 clocks
// assumes initialisers are honoured by the synthesiser
always @(posedge xclk) begin: reset_blk
    rst <= {rst_pipe, 1'b0}

//---------------------------------------------------------------------
// wishbone state machine

assign wbAck = (wbAck_o == 1'b1);

reg [4:0] nextState;
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
    
always @(posedge xclk) begin: wb_statemachine_blk

    if rst begin
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
            
            WBstart: Wr(I2C1_CMDR, x"04", WBinit1); // clock stretch disable

            WBinit1: Rd(I2C1_SR, WBinit2);          // wait for not busy

            WBinit2: busy ? ReadRegAgain : Rd(I2C1_RXDR, WBinit3); // read and discard RXDR, #1

            WBinit3: Rd(I2C1_RXDR, WBinit4);        // read and discard RXDR, #2

            WBinit4: Wr(I2C1_CMDR, x"00", WBidle);  // clock stretch enable

            //-----------------------------------
            // wait for I2C activity - "busy" is signalled

            WBidle : busy ? Rd(I2C1_SR, WBwaitTR) : Rd(I2C1_SR, WBidle); // wait for I2C activity - "busy" is signalled

            //-----------------------------------
            // wait for TRRDY

            WBwaitTR:
            begin
                if lastTxNak                         // last read?
                    nextState <= WBstart;
                else if (txReady)
                    Wr(I2C1_TXDR, XO, WBout0);
                else if (rxReady) 
                    Rd(I2C1_RXDR, WBin0);
                else if (!busy)
                    nextState <= WBstart;
                else
                    ReadRegAgain;
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
                if wbAck begin
                    wbStb <= 1'b0;
                    wbCyc <= 1'b0;

                    if hitI2CSR begin
                        vTIP               <= (wbDat_o[7] == 1'b1);
                        vBusy              <= (wbDat_o[6] == 1'b1);
                        vRARC              <= (wbDat_o[5] == 1'b1);
                        vSlaveTransmitting <= (wbDat_o[4] == 1'b1);
                        vTxRxRdy           <= (wbDat_o[2] == 1'b1);
                        vTROE              <= (wbDat_o[1] == 1'b1);
      
                        txReady   <= vBusy & (vTxRxRdy &&  vSlaveTransmitting & !vTIP );
                        rxReady   <= vBusy & (vTxRxRdy && !vSlaveTransmitting         );
                        lastTxNak <= vBusy & (vRARC    &&  vSlaveTransmitting &  vTROE);
                        busy      <= vBusy;
                    end 
                    else if hitI2CRXDR begin
                        isAddr  <= (wbDat_o[7:`I2C_DATA_BITS] == `A_ADDR);
                        isData  <= (wbDat_o[7:`I2C_DATA_BITS] == `D_ADDR);
                        inData  <=  wbDat_o[7:`I2C_DATA_BITS];
                    end
                    else if hitCFGRXDR begin
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
                if wbAck begin
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

always @(posedge xclk) begin: wb_statemachine_blk

    if (rst) begin
        rwAddr    <= 'd0;
        RdSubAddr <= 'd0;
        WrSubAddr <= 'd0;
    end 
    else begin 

        XiLoc.PRdFinished <= (WBstate == WBout0);

        if ((WBstate == WBin0) & isAddr)
            rwAddr <= inData[XA_BITS-1:0];

        if ((WBstate == WBin0) & isAddr)
            RdSubAddr <= 'd0;
        else if XiLoc.PRdFinished 
            RdSubAddr <= (RdSubAddr +1) % (XSUBA_MAX+1);

        if ((WBstate == WBin0) & isAddr)
            WrSubAddr <= 'd0;
        else if XiLoc.PWr 
            WrSubAddr <= (WrSubAddr +1) % (XSUBA_MAX+1);

        if ((WBstate == WBin0) & isData) begin
            XiLoc.PD  <= inData;
            XiLoc.PWr <= 1'b1;
        end
        else
            XiLoc.PWr <= 1'b0;

        WBstate <= nextState;
    end

assign XI <= XIloc;

    
endmodule
