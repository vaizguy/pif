`include "pifdefs.v"

module pifctl (

    input        xclk   ,

    //XIrec        XI     ,

    input                                XI_PWr,         /*: boolean;      -- registered single-clock write strobe*/ 
    input [2**`XA_BITS-1:0             ] XI_PRWA,        /*: TXA;          -- registered incoming addr bus        */
    input                                XI_PRdFinished, /*: boolean;      -- registered in clock PRDn goes off   */ 
    input [`XSUBA_MAX   :0             ] XI_PRdSubA,     /*: TXSubA;       -- read sub-address                    */
    input [7            :`I2C_TYPE_BITS] XI_PD,          /*: TwrData;      -- registered incoming data bus        */

    output reg [7:0] XO     ,
    
    output reg [3:0] MiscReg,

    input sys_rst
);

reg [7:`I2C_TYPE_BITS] ScratchReg   = `I2C_DATA_BITS'h15;
reg [3:0             ] MiscRegLocal = `LED_SYNC;

always @(posedge xclk or negedge sys_rst) begin: reg_write_blk

    if (!sys_rst) begin
        ScratchReg   <=  'd0;
        MiscRegLocal <= 4'd0;
    end
    else if (XI_PWr) begin

        case(XI_PRWA)
            `W_SCRATCH_REG: ScratchReg   <= XI_PD;
            `W_MISC_REG   : MiscRegLocal <= XI_PD;
            default:;
        endcase
    end
end

reg [`R_ID_NUM_SUBS-1:0] subAddr;
reg [7               :0] IDscratch;
reg [7               :0] IDletter;
reg [7               :0] subOut;
reg [7               :0] regOut;
reg [7               :0] IdReadback;

always @(posedge xclk or negedge sys_rst) begin: wishbone_reg_readback_blk_1

    if (!sys_rst) begin
        IDscratch <= 8'd0;
        IDletter  <= 8'd0;
        subAddr   <= `R_ID_NUM_SUBS'd0;
    end
    else begin
        IDscratch <= {2'b01, ScratchReg     };
        IDletter  <= {4'd6 , XI_PRdSubA[3:0]}; // 61h='a'
        subAddr   <= XI_PRdSubA % `R_ID_NUM_SUBS;
    end
end

always @(posedge xclk or negedge sys_rst) begin: wishbone_reg_readback_blk_2

    if (!sys_rst) begin
        subOut <= 8'd0;
    end
    else begin
        case (1)
            (subAddr == `R_ID_ID     ): subOut <= `ID;
            (subAddr == `R_ID_SCRATCH): subOut <= IDscratch;
            (subAddr == `R_ID_MISC   ): subOut <= {4'd5, MiscRegLocal}; // 50h='P'
            default: subOut <= IDletter;
        endcase
    end
end

always @(posedge xclk or negedge sys_rst) begin: wishbone_reg_readback_blk_3

    if (!sys_rst)
        regOut <= 8'd0;
    else if (XI_PRWA == `R_ID)
        regOut <= subOut;
    else
        regOut <= 8'd0;
end

always @(posedge xclk or negedge sys_rst) begin: wishbone_reg_readback_blk_4  
    
    if (!sys_rst) begin
        IdReadback <= 8'd0;
        XO         <= 8'd0;
        MiscReg    <= 4'd0;
    end
    else begin
        IdReadback <= regOut      ;
        XO         <= IdReadback  ;
        MiscReg    <= MiscRegLocal;
    end
end

endmodule
