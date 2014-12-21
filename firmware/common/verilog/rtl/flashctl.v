`include "pifdefs.v"

module flasher (

    // I2C interface
    inout  SDA ,
    inout  SCL ,
    
    // Global set/resetn
    input  GSRn,

    // LED interface
    output LEDR,
    output LEDG
);

// Wires 
wire                                xclk;
wire                                red_flash;
wire                                green_flash;
wire [7            :0             ] XO;
wire                                GSRnX;
wire [3            :0             ] MiscReg;
wire                                XI_PWr;         /*: boolean;      -- registered single-clock write strobe*/ 
wire [2**`XA_BITS-1:0             ] XI_PRWA;        /*: TXA;          -- registered incoming addr bus        */
wire                                XI_PRdFinished; /*: boolean;      -- registered in clock PRDn goes off   */ 
wire [`XSUBA_MAX   :0             ] XI_PRdSubA;     /*: TXSubA;       -- read sub-address                    */
wire [7            :`I2C_TYPE_BITS] XI_PD;          /*: TwrData;      -- registered incoming data bus        */

// LED Flasher
pif_flasher i_pif_flasher (
    
    /*output*/ .red   (red_flash  ),
    /*output*/ .green (green_flash),
    /*output*/ .xclk  (xclk       )
);

// Wishbone interface
pifwb i_pifwb (

    /*inout */ .i2c_SCL (SCL ),
    /*inout */ .i2c_SDA (SDA ),

    /*input */ .xclk    (xclk),

    ///*output*/ .XI      (XI  ),
               .XI_PWr        (XI_PWr        ),        
               .XI_PRWA       (XI_PRWA       ),       
               .XI_PRdFinished(XI_PRdFinished),
               .XI_PRdSubA    (XI_PRdSubA    ),    
               .XI_PD         (XI_PD         ),         

    /*input */ .XO      (XO  )
);

// Control logic
pifctl i_pifctl(

    /*input */ .xclk    (xclk   ),

    ///*input */ .XI      (XI     ),
               .XI_PWr        (XI_PWr        ),        
               .XI_PRWA       (XI_PRWA       ),       
               .XI_PRdFinished(XI_PRdFinished),
               .XI_PRdSubA    (XI_PRdSubA    ),    
               .XI_PD         (XI_PD         ),         

    /*output*/ .XO      (XO     ),
      
    /*output*/ .MiscReg (MiscReg)
);

reg r, g;

always @(*) begin : led_pattern_select_blk

    case(1)

        (MiscReg==`LED_ALTERNATING): 
        begin
            r = red_flash;
            g = green_flash;
        end

        (MiscReg==`LED_SYNC):
        begin
            r = red_flash;
            g = green_flash;
        end

        default: // Includes LED_OFF as well.
        begin
            r = 0;
            g = 0;
        end

    endcase
end

// Global set/reset
IB IBgsr (.I(GSRn), .O(GSRnX));
GSR GSR_GSR (.GSR(GSRnX));

// Outputs
OB   REG_BUF (.I(r), .O(LEDR));
OB GREEN_BUF (.I(g), .O(LEDG));

endmodule
