`include "pifdefs.v"

module pifwb (

    inout                        i2c_SCL,
    inout                        i2c_SDA,

    input                        xclk   ,

    //XIrec                        XI     ,      // works only with sv

    output  reg                      XI_PWr,         /*: boolean;      -- registered single-clock write strobe*/ 
    output  reg [`TXA            :0] XI_PRWA,        /*: TXA;          -- registered incoming addr bus        */
    output  reg                      XI_PRdFinished, /*: boolean;      -- registered in clock PRDn goes off   */ 
    output  reg [`TXSubA         :0] XI_PRdSubA,     /*: TXSubA;       -- read sub-address                    */
    output  reg [`I2C_DATA_BITS-1:0] XI_PD,          /*: TwrData;      -- registered incoming data bus        */

    input   [7               :0] XO,

    input                        sys_rst
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
// primary I2C
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
// secondary I2C
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

// Wires
wire [7:0] wbDat_o /* synthesis syn_keep = 1 */;
wire       wbAck_o;

// Registers
reg [7               :0] wbDat_i /* synthesis syn_keep = 1 */;
reg [7               :0] wbAddr  /* synthesis syn_keep = 1 */;
reg [7               :0] wbOutBuff;

reg                      busy; 
reg                      txReady; 
reg                      rxReady; 
reg                      lastTxNak; 
reg                      isAddr; 
reg                      isData;

reg                      wbCyc;
reg                      wbStb;
reg                      wbWe;

reg [3               :0] WBstate/* synthesis syn_keep = 1 */;
reg [3               :0] rwReturn;

reg                      hitI2CSR;
reg                      hitI2CRXDR;
reg                      hitCFGRXDR;
reg                      cfgBusy;
reg [`TXSubA         :0] RdSubAddr;
reg [`TXSubA         :0] WrSubAddr;
reg [`TXA            :0] rwAddr;
reg [`I2C_DATA_BITS-1:0] inData;

// Local XI registers 
//XIrec XIloc;
reg                       XIloc_PWr;         /*: boolean;      -- registered single-clock write strobe*/ 
reg  [`TXA            :0] XIloc_PRWA;        /*: TXA;          -- registered incoming addr bus        */
reg                       XIloc_PRdFinished; /*: boolean;      -- registered in clock PRDn goes off   */ 
reg  [`TXSubA         :0] XIloc_PRdSubA;     /*: TXSubA;       -- read sub-address                    */
reg  [`I2C_DATA_BITS-1:0] XIloc_PD;          /*: TwrData;      -- registered incoming data bus        */

reg                       read_active;
reg                       write_active;


//---------------------------------------------------------------------
// Power-Up Reset for 16 clocks
// assumes initialisers are honoured by the synthesiser
`ifndef NO_WB_16CLK_PUR
reg [15:0] rst_pipe;
wire rst = rst_pipe[15];

always @(posedge xclk or negedge sys_rst) begin: reset_blk

    if (~sys_rst)
        rst_pipe <= 16'hffff;
    else if (rst_pipe == 16'h0000)
        rst_pipe <= rst_pipe;   
    else
        rst_pipe <= {rst_pipe[14:0], 1'b0};
end
`else
reg rst;
reg nrst;
reg [3:0] rst_count;

always @(posedge xclk or negedge sys_rst) begin: reset_blk

    if (~sys_rst) begin
        rst <= 1'b0;
        nrst <= 1'b0;
        rst_count <= 1'd0;
    end
    else begin
        if (rst_count != 4'd15)
            rst_count = rst_count + 4'd1;
        else begin    
            nrst <= (rst_count==4'd15);
            rst <= !nrst;
        end
    end
end
`endif // POWER_UP_16CLK_RESET

// used in debug mode to reset the internal 16-bit counters
wire wbRst = ~sys_rst
// synthesis translate_off
             | rst
// synthesis translate_on
;

// Embedded function block (EFB)
defparam myEFB.EFBInst_0.DEV_DENSITY = `DEVICE_DENSITY;
myefb myEFB (
     
    .wb_clk_i    (xclk   ), 
    .wb_rst_i    (wbRst  ), 
    .wb_cyc_i    (wbCyc  ), 
    .wb_stb_i    (wbStb  ), 
    .wb_we_i     (wbWe   ), 
    .wb_adr_i    (wbAddr ), 
    .wb_dat_i    (wbDat_i), 
    .wb_dat_o    (wbDat_o), 
    .wb_ack_o    (wbAck_o), 
    .i2c1_scl    (i2c_SCL), 
    .i2c1_sda    (i2c_SDA), 
    .i2c1_irqo   (       ),
    .tc_clki     (xclk   ), 
    .tc_rstn     (~wbRst ), 
    .tc_ic       (1'b0   ), 
    .tc_int      (       ), 
    .tc_oc       (       ), 
    .wbc_ufm_irq (       )
) /* synthesis syn_black_box=True */; 

//---------------------------------------------------------------------
// wishbone state machine

wire wbAck = (wbAck_o == 1'b1);

reg [3:0] nextState;
reg       vSlaveTransmitting;
reg       vTxRxRdy;
reg       vBusy;
reg       vTIP;
reg       vRARC;
reg       vTROE;
//reg [7:0] vInst;


always @(posedge xclk or negedge sys_rst) begin: wb_i2c_blk

    if(~sys_rst) begin
        hitI2CSR   <= 1'b0;
        hitI2CRXDR <= 1'b0; 
        hitCFGRXDR <= 1'b0; 
    end
    else begin
        hitI2CSR   <= (wbAddr == I2C1_SR  );
        hitI2CRXDR <= (wbAddr == I2C1_RXDR);
        hitCFGRXDR <= (wbAddr == CFG_RXDR );
    end
end
    
always @(posedge xclk) begin: wb_fsm_rwReturn_blk

    if (rst) begin
        rwReturn  <= WBstart;
        wbStb     <= 1'b0;
        wbCyc     <= 1'b0;
        wbWe      <= 1'b0;
        busy      <= 1'b0;
        txReady   <= 1'b0;
        rxReady   <= 1'b0;
        lastTxNak <= 1'b0;

        wbAddr    <= 8'b00000000;
        wbDat_i   <= 8'b00000000;

        isAddr <= 1'b0;
        isData <= 1'b0;  
        inData <= {`I2C_DATA_BITS{1'b0}};

        cfgBusy <= 1'b0;

    end
    else begin

        case (WBstate)

            //-----------------------------------
            // initialise
            
            WBstart: 
            begin
                // Write I2C Command 
                // STA | STD | RD | WR | ACK | CKSDIS | rsvd | rsvd
                wbAddr    <= I2C1_CMDR;
                // clock stretch disable
                // clock streatching is not supported in this device.
                // this bit should be set to one for all writes
                // Page 8 of 78 of Using User Flash Memory and Hardened
                // Control Functions in MachXO2 Devices Reference Guide
                wbDat_i   <= 8'h04;      
                rwReturn  <= WBinit1;
            end

            WBinit1:
            begin
                // Read I2C Status registers   
                // TIP | BUSY | RARC | SRW | ARBL | TRRDY | TROE HGC                
                wbAddr    <= I2C1_SR;
                // wait for not busy
                wbDat_i   <= 8'h00;
                rwReturn  <= WBinit2;
            end

            WBinit2:
            begin
                if (!busy) begin
                    // Read I2C Receive data rgister - 8 bits             
                    wbAddr    <= I2C1_RXDR;
                    // read and discard RXDR, #1  
                    wbDat_i   <= 8'h00;
                    rwReturn  <= WBinit3;
                end
            end

            WBinit3:
            begin
                // Read I2C Receive data register - 8 bits       
                wbAddr    <= I2C1_RXDR;
                // read and discard RXDR, #2                
                wbDat_i   <= 8'h00;
                rwReturn  <= WBinit4;
            end

            WBinit4: 
            begin
                // Write I2C Command
                // STA | STD | RD | WR | ACK | CKSDIS | rsvd | rsvd
                wbAddr    <= I2C1_CMDR;
                // clock stretch enable                
                wbDat_i   <= 8'h00;
                rwReturn  <= WBidle;
            end

            //-----------------------------------
            // wait for I2C activity - "busy" is signalled

            WBidle :
            begin
                // Read I2C Status registers   
                // TIP | BUSY | RARC | SRW | ARBL | TRRDY | TROE HGC
                wbAddr   <= I2C1_SR;
                wbDat_i  <= 8'h00;

                // wait for I2C activity - "busy" is signalled                    
                if (busy) 
                    rwReturn <= WBwaitTR;
                else
                    rwReturn <= WBidle;
            end

            //-----------------------------------
            // wait for TRRDY

            WBwaitTR:
            begin
                if (txReady) begin
                    // Write Transmit data register - 8 bits
                    wbAddr    <= I2C1_TXDR;
                    wbDat_i   <= XO;
                    rwReturn  <= WBout0;
                end
                else if (rxReady) begin
                    // Read I2C Receive data register - 8 bits                
                    wbAddr    <= I2C1_RXDR;
                    wbDat_i   <= 8'h00;
                    rwReturn  <= WBin0;
                end
            end

            //-----------------------------------
            // incoming data

            //WBin0: nextState <= WBidle;              // incoming data

            //-----------------------------------
            // outgoing data

            //WBout0:  nextState <= WBout1;            // outgoing data

            //WBout1:  nextState <= WBidle;            // outgoing data

            //-----------------------------------
            // read cycle

            WBrd:
            begin
                if (wbAck) begin
                    wbStb <= 1'b0;
                    wbCyc <= 1'b0;

                    // Targeted READ cases
                    if (hitI2CSR) begin
                        // Read I2C Status registers        
                        txReady   <= vBusy & (vTxRxRdy &  vSlaveTransmitting & !vTIP );
                        rxReady   <= vBusy & (vTxRxRdy & !vSlaveTransmitting         );
                        lastTxNak <= vBusy & (vRARC    &  vSlaveTransmitting &  vTROE);
                        busy      <= vBusy;
                    end 
                    else if (hitI2CRXDR) begin
                        // Read I2C Data registers   
                        isAddr  <= (wbDat_o[7:`I2C_DATA_BITS] == `A_ADDR);
                        isData  <= (wbDat_o[7:`I2C_DATA_BITS] == `D_ADDR);
                        inData  <=  wbDat_o[`I2C_DATA_BITS-1:0];
                    end
                    else if (hitCFGRXDR) begin
                        cfgBusy <= (wbDat_o[7] == 1'b1);
                    end     

                    wbOutBuff <= wbDat_o;
                end
                else begin
                    wbStb <= 1'b1;
                    wbCyc <= 1'b1;
                end

                write_active = 1'b0;
                read_active = 1'b1;
            end

            //-----------------------------------
            // write cycle

            WBwr:
            begin
                if (wbAck) begin
                    wbStb <= 1'b0;
                    wbCyc <= 1'b0;
                    wbWe  <= 1'b0;
                end
                else begin
                    wbStb <= 1'b1;
                    wbCyc <= 1'b1;
                    wbWe  <= 1'b1;
                end

                write_active = 1'b1;
                read_active = 1'b0;
            end

            // others
            default:   rwReturn <= WBstart;
        endcase
    end
end

always @(*) begin: wb_fsm_next_state_blk

    if (rst) begin
        nextState = WBstart;
        vTIP      = 1'b0; 
        vBusy     = 1'b0;        
        vRARC     = 1'b0;        
        vSlaveTransmitting = 1'b0;
        vTxRxRdy  = 1'b0;        
        vTROE     = 1'b0;    
    end
    else begin

        case (WBstate)

            //-----------------------------------
            // initialise
            
            WBstart: nextState = WBwr;

            WBinit1: nextState = WBrd;

            WBinit2: nextState = WBrd;

            WBinit3: nextState = WBrd;

            WBinit4: nextState = WBwr;

            //-----------------------------------
            // wait for I2C activity - "busy" is signalled
            WBidle : nextState = WBrd;

            //-----------------------------------
            // wait for TRRDY
            WBwaitTR:
            begin
                if (lastTxNak)                      // last read?
                    nextState = WBstart;
                else if (txReady) 
                    // Write Transmit data register - 8 bits
                    nextState = WBwr;
                else if (rxReady) 
                    // Read I2C Receive data register - 8 bits                
                    nextState = WBrd;
                else if (!busy)
                    nextState = WBstart;
                else
                    nextState = WBrd;
            end

            //-----------------------------------
            // incoming data
            WBin0: nextState = WBidle;              // incoming data

            //-----------------------------------
            // outgoing data

            WBout0:  nextState = WBout1;            // outgoing data

            WBout1:  nextState = WBidle;            // outgoing data

            //-----------------------------------
            // read cycle
            WBrd:
            begin
                if (wbAck) begin
                    if (hitI2CSR) begin
                        // Read I2C Status registers   
                        // TIP | BUSY | RARC | SRW | ARBL | TRRDY | TROE HGC
                        vTIP               = (wbDat_o[7] == 1'b1);
                        vBusy              = (wbDat_o[6] == 1'b1);
                        vRARC              = (wbDat_o[5] == 1'b1);
                        vSlaveTransmitting = (wbDat_o[4] == 1'b1);
                        vTxRxRdy           = (wbDat_o[2] == 1'b1);
                        vTROE              = (wbDat_o[1] == 1'b1);
                    end

                    nextState = rwReturn;
                end
            end

            //-----------------------------------
            // write cycle
            WBwr:
            begin 
                if (wbAck) begin 
                    nextState = rwReturn;
                end
            end

            // others
            default: nextState = WBstart;

        endcase
    end
end


always @(posedge xclk or negedge sys_rst) begin: wb_fsm_curr_state_blk

    if (~sys_rst)
        WBstate <= WBstart;
    else
        WBstate <= nextState;
end


always @(posedge xclk or negedge sys_rst) begin: wb_fsm_i2c_addr_rd_blk

    if (~sys_rst) begin
        rwAddr            <= `TXA_W'd0;
        RdSubAddr         <= `TXSubA_W'd0;
        WrSubAddr         <= `TXSubA_W'd0;
    end 
    else begin 

        // Address
        if ((WBstate == WBin0) & isAddr) begin
            // In this case, data is address (i.e. MAX width - 3:0, 4 bit 
            // reg addressing )
            rwAddr <= inData[`TXARange];
            // 2^7, 127:0, 128 bit sub addressing 
            RdSubAddr <= `TXSubA_W'd0;
            WrSubAddr <= `TXSubA_W'd0;
        end

        else if (XIloc_PRdFinished)
            RdSubAddr <= (RdSubAddr +1) % (`TXSubA_W);

        else if (XIloc_PWr)
            WrSubAddr <= (WrSubAddr +1) % (`TXSubA_W); // Unused signal
    end
end


always @(posedge xclk or negedge sys_rst) begin: wb_fsm_i2c_data_rd_blk

    if (~sys_rst) begin
        XIloc_PD          <= `I2C_DATA_BITS'd0;
        XIloc_PWr         <= 1'b0;
    end 
    else begin 

        // Data
        if ((WBstate == WBin0) & isData) begin
            XIloc_PD  <= inData;
            XIloc_PWr <= 1'b1;
        end
        else
            XIloc_PWr <= 1'b0;
    end
end


always @(posedge xclk or negedge sys_rst) begin: wb_fsm_prdfin_blk

    if (~sys_rst)
        XIloc_PRdFinished <= 1'b0;
    else
        XIloc_PRdFinished <= (WBstate == WBout0);
end


always @(posedge xclk or negedge sys_rst) begin: wb_fsm_pifctl_blk_2

    if (~sys_rst) begin
        XIloc_PRWA    <= `TXA_W'd0;
        XIloc_PRdSubA <= `TXSubA_W'd0;        
    end
    else begin
        XIloc_PRWA    <= rwAddr;
        XIloc_PRdSubA <= RdSubAddr;
    end
end


// Assign XI Nets
//assign XI <= XIloc;
always @(posedge xclk or negedge sys_rst) begin
    if (~sys_rst) begin
        XI_PWr         <= 1'b0;
        XI_PRWA        <= `TXA_W'b0;
        XI_PRdFinished <= 1'b0;
        XI_PRdSubA     <= `TXSubA_W'b0;
        XI_PD          <= `I2C_DATA_BITS'b0;
    end
    else begin
        XI_PWr         <= XIloc_PWr;
        XI_PRWA        <= XIloc_PRWA;
        XI_PRdFinished <= XIloc_PRdFinished;
        XI_PRdSubA     <= XIloc_PRdSubA;
        XI_PD          <= XIloc_PD;
    end
end

   
endmodule
