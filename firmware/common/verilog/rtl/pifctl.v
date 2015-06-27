`include "pifdefs.v"

module pifctl (

    input                           xclk   ,

    //XIrec                           XI     ,

    input                           XI_PWr,         /*: boolean;      -- registered single-clock write strobe*/ 
    input      [`TXA            :0] XI_PRWA,        /*: TXA;          -- registered incoming addr bus        */
    input                           XI_PRdFinished, /*: boolean;      -- registered in clock PRDn goes off   */ 
    input      [`TXSubA         :0] XI_PRdSubA,     /*: TXSubA;       -- read sub-address                    */
    input      [`I2C_DATA_BITS-1:0] XI_PD,          /*: TwrData;      -- registered incoming data bus        */

    output reg [7               :0] XO,
    
    output reg [31              :0] MiscReg,

    input                           sys_rst
);

reg [`I2C_DATA_BITS-1:0] ScratchReg;
reg [31              :0] MiscRegLocal;

always @(posedge xclk or negedge sys_rst) begin: reg_write_blk

    if (~sys_rst) begin
        ScratchReg   <= `I2C_DATA_BITS'h15;
        MiscRegLocal <= `LED_ALTERNATING;  // Default is alternating LEDs
    end
    else if (XI_PWr) begin

        case(XI_PRWA)
            `W_SCRATCH_REG: ScratchReg   <= XI_PD[`I2C_DATA_BITS-1:0];  // 6'd
            `W_MISC_REG   : MiscRegLocal <= {26'd0, XI_PD};             // 32'd
            default: ;
        endcase
    end
end

reg [`R_ID_NUM_SUBS-1:0] subAddr;
reg [7               :0] IDscratch;
reg [7               :0] IDletter;
reg [7               :0] subOut;
reg [7               :0] regOut;
reg [7               :0] IdReadback;

always @(*) begin: wishbone_reg_readback_blk_1

    if (~sys_rst) begin
        IDscratch = 8'd0;
        IDletter  = 8'd0;
        subAddr   = `R_ID_NUM_SUBS'd0;
    end
    else begin
        IDscratch = {2'b01, ScratchReg                };
        IDletter  = {4'd6 , to_4bit_vector(XI_PRdSubA)}; // 61h='a'
        subAddr   = XI_PRdSubA % `R_ID_NUM_SUBS;
    end
end

always @(*) begin: wishbone_reg_readback_blk_2

    if (~sys_rst) begin
        subOut = 8'd0;
    end
    else begin
        case (subAddr)
            `R_ID_ID     : subOut = `ID;
            `R_ID_SCRATCH: subOut = IDscratch;
            `R_ID_MISC   : subOut = {4'd5, to_4bit_vector(MiscRegLocal)}; // 50h='P'
            default: subOut = IDletter;
        endcase
    end
end

always @(*) begin: wishbone_reg_readback_blk_3

    if (~sys_rst)
        regOut = 8'd0;
    else if (XI_PRWA == `R_ID)
        regOut = subOut;
    else
        regOut = 8'd0;
end

always @(posedge xclk or negedge sys_rst) begin: wishbone_reg_readback_blk_4  
    
    if (~sys_rst) begin
        IdReadback <=  8'd0;
        XO         <=  8'd0;
        MiscReg    <= 32'd0;
    end
    else begin
        IdReadback <= regOut      ;
        XO         <= IdReadback  ;
        MiscReg    <= MiscRegLocal;
    end
end

function [3:0] to_4bit_vector (input arg);
    begin
        to_4bit_vector = arg % (2**4);       
    end
endfunction

endmodule
