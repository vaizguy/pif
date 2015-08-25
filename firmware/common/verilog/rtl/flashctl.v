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
wire                      xclk;
wire                      red_flash;
wire                      green_flash;
wire [7               :0] XO;
wire                      GSRnX /* synthesis pullmode="UP" */;
wire [`I2C_DATA_BITS-1:0] MiscReg;
wire                      XI_PWr;         /*: boolean;      -- registered single-clock write strobe*/ 
wire [`TXA            :0] XI_PRWA;        /*: TXA;          -- registered incoming addr bus        */
wire                      XI_PRdFinished; /*: boolean;      -- registered in clock PRDn goes off   */ 
wire [`TXSubA         :0] XI_PRdSubA;     /*: TXSubA;       -- read sub-address                    */
wire [`I2C_DATA_BITS-1:0] XI_PD;          /*: TwrData;      -- registered incoming data bus        */

// Global set/reset
IB IBgsr (.I(GSRn), .O(GSRnX));
GSR GSR_GSR (.GSR(GSRnX));

// LED Flasher
pif_flasher i_pif_flasher (
    
    /*output*/ .red    (red_flash  ),
    /*output*/ .green  (green_flash),
    /*output*/ .xclk   (xclk       ),
    
    /*input */ .sys_rst(GSRnX      )
);

// Wishbone interface
pifwb i_pifwb (

    /*inout */ .i2c_SCL       (SCL           ),
    /*inout */ .i2c_SDA       (SDA           ),

    /*input */ .xclk          (xclk          ),

    ///*output*/ .XI            (XI            ),
               .XI_PWr        (XI_PWr        ),        
               .XI_PRWA       (XI_PRWA       ),       
               .XI_PRdFinished(XI_PRdFinished),
               .XI_PRdSubA    (XI_PRdSubA    ),    
               .XI_PD         (XI_PD         ),         

    /*input */ .XO            (XO            ),

    /*input */ .sys_rst       (GSRnX         )

);

// Control logic
pifctl i_pifctl(

    /*input */ .xclk          (xclk          ),

    ///*input */ .XI            (XI            ),
               .XI_PWr        (XI_PWr        ),        
               .XI_PRWA       (XI_PRWA       ),       
               .XI_PRdFinished(XI_PRdFinished),
               .XI_PRdSubA    (XI_PRdSubA    ),    
               .XI_PD         (XI_PD         ),         

    /*output*/ .XO            (XO            ),
      
    /*output*/ .MiscReg       (MiscReg       ),

    /*input */ .sys_rst       (GSRnX         )

);


`ifdef LED_BEH_MUX
reg r, g;

always @(*) begin : led_pattern_select_blk

    case(MiscReg)

        `LED_ALTERNATING: 
        begin
            r = red_flash;
            g = green_flash;
        end

        `LED_SYNC:
        begin
            r = red_flash;
            g = red_flash;
        end

        `LED_OFF:
        begin
            r = 1'b0;
            g = 1'b0;
        end

        default: 
        begin
            r = 1'b0;
            g = 1'b0;
        end

    endcase
end
`else
wire r, g;

MUX41 i_red_led_mux (
    .D0 (red_flash ),
    .D1 (red_flash ),
    .D2 (1'b0      ),
    .D3 (1'b0      ),
    .SD1(MiscReg[0]),
    .SD2(MiscReg[1]),
    .Z  (r         )
);

MUX41 i_green_led_mux (
    .D0 (green_flash),
    .D1 (red_flash  ),
    .D2 (1'b0       ),
    .D3 (1'b0       ),
    .SD1(MiscReg[0] ),
    .SD2(MiscReg[1] ),
    .Z  (g          )
);
`endif

// Outputs
OB   REG_BUF (.I(r), .O(LEDR));
OB GREEN_BUF (.I(g), .O(LEDG));

endmodule
