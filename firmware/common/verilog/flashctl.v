
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
wire xclk;
wire red_flash;
wire green_flash;
wire slv8;
wire XI;
wire XO;
wire GSRnX;
wire MiscReg;

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

    /*output*/ .XI      (XI  ),
    /*input */ .XO      (XO  )
);

// Control logic
pifctl i_pifctl(

    /*input */ .xclk    (xclk   ),

    /*input */ .XI      (XI     ),
    /*output*/ .XO      (XO     ),
      
    /*output*/ .MiscReg (MiscReg)
);

reg r, g;

always (*) begin : led_pattern_select_blk

    case(1):

        (MiscReg==LED_ALTERNATING): 
        begin
            r = red_flash;
            g = green_flash;
        end

        (MiscReg==LED_SYNC):
        begin
            r = red_flash;
            g = green_flash;
        end

        default:
        begin
            r = 0;
            g = 0;
        end

    endcase

// Global set/reset
IB IBgsr     (.I(GSRn), .O(GSRnX));
GSR GSR_GSR  (.GSR(GSRnX));

// Outputs
OB   REG_BUF (.I(r   ), .O(LEDR ));
OB GREEN_BUF (.I(g   ), .O(LEDG ));

endmodule
