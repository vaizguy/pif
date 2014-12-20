
module pifctl (

    input        xclk   ,

    XIrec        XI     ,
    output [7:0] XO     ,
    
    output [2:0] MiscReg
);

wire [7:`I2C_TYPE_BITS] ScratchReg   = `I2C_DATA_BITS'h15;
wire [1:0             ] MiscRegLocal = `LED_SYNC;

always @(posedge xclk) begin: reg_write_blk

    if (XI.PWr) begin

        case(XI.PRWA)
            W_SCRATCH_REG: ScratchReg <= XI.PD;
            W_MISC_REG   : MiscRegLocal <= XI.PD;
            default:;
        endcase
    end
end

reg [R_ID_NUM_SUBS-1:0] subAddr;
reg [7              :0] IDscratch;
reg [7              :0] IDletter;
reg [7              :0] subOut;
reg [7              :0] regOut;

always @(posedge xclk) begin: wishbone_reg_readback_blk_1

    IDscratch <= {2'b01. ScratchReg};
    IDletter <= {4'd6, XI.PRdSubA}; // 61h='a'
    subAddr <= XI.PRdSubA % R_ID_NUM_SUBS;

always @(posedge xclk) begin: wishbone_reg_readback_blk_2

    case (1)
        (subAddr == R_ID_ID     ): subOut <= ID;
        (subAddr == R_ID_SCRATCH): subOut <= IDscratch;
        (subAddr == R_ID_MISC   ): subOut <= {4'd5, MiscRegLocal}; // 50h='P'
        default: subOut <= IDletter;
    endcase

always @(posedge xclk) begin: wishbone_reg_readback_blk_3

    if (XI.PRWA == R_ID)
        regOut <= subOut;
    else
        regOut <= 8'd0;

always @(posedge xclk) begin: wishbone_reg_readback_blk_4  
    
    IdReadback <= regOut;
    XO <= IdReadback;
    MiscReg <= MiscRegLocal;

endmodule
