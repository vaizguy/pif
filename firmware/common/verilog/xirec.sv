
// XI interface
interface XIrec (
    
    logic                                 PWr         /*: boolean;      -- registered single-clock write strobe*/ 
    logic  [2**`XA_BITS-1:0             ] PRWA        /*: TXA;          -- registered incoming addr bus        */
    logic                                 PRdFinished /*: boolean;      -- registered in clock PRDn goes off   */ 
    logic  [XSUBA_MAX    :0             ] PRdSubA     /*: TXSubA;       -- read sub-address                    */
    logic  [7            :`I2C_TYPE_BITS] PD          /*: TwrData;      -- registered incoming data bus        */
);

endinterface
