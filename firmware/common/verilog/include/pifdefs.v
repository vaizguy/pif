// PIF configuration Defines

// I2C interface
//-----------------------------------------------------------
// these constants are defined in outer 'pifcfg' files
`define ID             8'h41       // PIF_ID
`define DEVICE_DENSITY "1200L"     // XO2_DENSITY

`define A_ADDR 2'b00
`define D_ADDR 2'b01

`define I2C_TYPE_BITS 2
`define I2C_DATA_BITS 6

`define XA_BITS    4               // 16 Address registers
`define XSUBA_BITS 7               // 128 sub addresses
`define XSUBA_MAX  2**`XSUBA_BITS-1

`define TXARange  `XA_BITS-1:0
`define TXA       2**`XA_BITS-1
`define TXA_W     2**`XA_BITS
`define TXSubA    `XSUBA_MAX

//-----------------------------------------------------------
// ID register, read-only
`define R_ID `TXA_W'd0

// ID subregisters
//  0     ID                        BX4/8/16 = G/L/A
//  1     Scratch
//  2     Misc                      plus 30h -> 0/1/2/3
//  3..31 ID letter                 abcdefghij...
//
`define R_ID_NUM_SUBS 32
`define R_ID_ID       `R_ID_NUM_SUBS'd0
`define R_ID_SCRATCH  `R_ID_NUM_SUBS'd1
`define R_ID_MISC     `R_ID_NUM_SUBS'd2

// Scratch register, write here, read via R_ID, subaddr 1
`define W_SCRATCH_REG `TXA_W'd1

// Misc register, write here, read via R_ID, subaddr 2
// one of the examples uses this register to control the LEDs
`define W_MISC_REG    `TXA_W'd2

// LED States
`define LED_ALTERNATING 32'd0
`define LED_SYNC        32'd1
`define LED_OFF         32'd2

