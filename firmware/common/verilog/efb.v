/* Verilog netlist generated by SCUBA Diamond (64-bit) 3.3.0.109 */
/* Module Version: 1.2 */
/* /usr/local/diamond/3.3_x64/ispfpga/bin/lin64/scuba -w -n efb -lang verilog -synth synplify -bus_exp 7 -bb -type efb -arch xo2c00 -freq 27.0 -i2c1 -i2c1_freq 400 -i2c1_sa 1000001 -i2c1_addr 7 -wb -dev 1200  */
/* Sat Dec 13 14:00:21 2014 */


`timescale 1 ns / 1 ps
module efb (wb_clk_i, wb_rst_i, wb_cyc_i, wb_stb_i, wb_we_i, wb_adr_i, 
    wb_dat_i, wb_dat_o, wb_ack_o, i2c1_scl, i2c1_sda, i2c1_irqo)/* synthesis NGD_DRC_MASK=1 */;
    input wire wb_clk_i;
    input wire wb_rst_i;
    input wire wb_cyc_i;
    input wire wb_stb_i;
    input wire wb_we_i;
    input wire [7:0] wb_adr_i;
    input wire [7:0] wb_dat_i;
    output wire [7:0] wb_dat_o;
    output wire wb_ack_o;
    output wire i2c1_irqo;
    inout wire i2c1_scl;
    inout wire i2c1_sda;

    wire scuba_vhi;
    wire scuba_vlo;
    wire i2c1_sdaoen;
    wire i2c1_sdao;
    wire i2c1_scloen;
    wire i2c1_sclo;
    wire i2c1_sdai;
    wire i2c1_scli;

    VHI scuba_vhi_inst (.Z(scuba_vhi));

    VLO scuba_vlo_inst (.Z(scuba_vlo));

    BB BB1_sda (.I(i2c1_sdao), .T(i2c1_sdaoen), .O(i2c1_sdai), .B(i2c1_sda));

    BB BB1_scl (.I(i2c1_sclo), .T(i2c1_scloen), .O(i2c1_scli), .B(i2c1_scl));

    defparam EFBInst_0.UFM_INIT_FILE_FORMAT = "HEX" ;
    defparam EFBInst_0.UFM_INIT_FILE_NAME = "NONE" ;
    defparam EFBInst_0.UFM_INIT_ALL_ZEROS = "ENABLED" ;
    defparam EFBInst_0.UFM_INIT_START_PAGE = 0 ;
    defparam EFBInst_0.UFM_INIT_PAGES = 0 ;
    defparam EFBInst_0.DEV_DENSITY = "1200L" ;
    defparam EFBInst_0.EFB_UFM = "DISABLED" ;
    defparam EFBInst_0.TC_ICAPTURE = "DISABLED" ;
    defparam EFBInst_0.TC_OVERFLOW = "DISABLED" ;
    defparam EFBInst_0.TC_ICR_INT = "OFF" ;
    defparam EFBInst_0.TC_OCR_INT = "OFF" ;
    defparam EFBInst_0.TC_OV_INT = "OFF" ;
    defparam EFBInst_0.TC_TOP_SEL = "OFF" ;
    defparam EFBInst_0.TC_RESETN = "ENABLED" ;
    defparam EFBInst_0.TC_OC_MODE = "TOGGLE" ;
    defparam EFBInst_0.TC_OCR_SET = 32767 ;
    defparam EFBInst_0.TC_TOP_SET = 65535 ;
    defparam EFBInst_0.GSR = "ENABLED" ;
    defparam EFBInst_0.TC_CCLK_SEL = 1 ;
    defparam EFBInst_0.TC_MODE = "CTCM" ;
    defparam EFBInst_0.TC_SCLK_SEL = "PCLOCK" ;
    defparam EFBInst_0.EFB_TC_PORTMODE = "WB" ;
    defparam EFBInst_0.EFB_TC = "DISABLED" ;
    defparam EFBInst_0.SPI_WAKEUP = "DISABLED" ;
    defparam EFBInst_0.SPI_INTR_RXOVR = "DISABLED" ;
    defparam EFBInst_0.SPI_INTR_TXOVR = "DISABLED" ;
    defparam EFBInst_0.SPI_INTR_RXRDY = "DISABLED" ;
    defparam EFBInst_0.SPI_INTR_TXRDY = "DISABLED" ;
    defparam EFBInst_0.SPI_SLAVE_HANDSHAKE = "DISABLED" ;
    defparam EFBInst_0.SPI_PHASE_ADJ = "DISABLED" ;
    defparam EFBInst_0.SPI_CLK_INV = "DISABLED" ;
    defparam EFBInst_0.SPI_LSB_FIRST = "DISABLED" ;
    defparam EFBInst_0.SPI_CLK_DIVIDER = 1 ;
    defparam EFBInst_0.SPI_MODE = "MASTER" ;
    defparam EFBInst_0.EFB_SPI = "DISABLED" ;
    defparam EFBInst_0.I2C2_WAKEUP = "DISABLED" ;
    defparam EFBInst_0.I2C2_GEN_CALL = "DISABLED" ;
    defparam EFBInst_0.I2C2_CLK_DIVIDER = 1 ;
    defparam EFBInst_0.I2C2_BUS_PERF = "100kHz" ;
    defparam EFBInst_0.I2C2_SLAVE_ADDR = "0b0011001" ;
    defparam EFBInst_0.I2C2_ADDRESSING = "7BIT" ;
    defparam EFBInst_0.EFB_I2C2 = "DISABLED" ;
    defparam EFBInst_0.I2C1_WAKEUP = "DISABLED" ;
    defparam EFBInst_0.I2C1_GEN_CALL = "DISABLED" ;
    defparam EFBInst_0.I2C1_CLK_DIVIDER = 17 ;
    defparam EFBInst_0.I2C1_BUS_PERF = "400kHz" ;
    defparam EFBInst_0.I2C1_SLAVE_ADDR = "0b1000001" ;
    defparam EFBInst_0.I2C1_ADDRESSING = "7BIT" ;
    defparam EFBInst_0.EFB_I2C1 = "ENABLED" ;
    defparam EFBInst_0.EFB_WB_CLK_FREQ = "27.0" ;
    EFB EFBInst_0 (.WBCLKI(wb_clk_i), .WBRSTI(wb_rst_i), .WBCYCI(wb_cyc_i), 
        .WBSTBI(wb_stb_i), .WBWEI(wb_we_i), .WBADRI7(wb_adr_i[7]), .WBADRI6(wb_adr_i[6]), 
        .WBADRI5(wb_adr_i[5]), .WBADRI4(wb_adr_i[4]), .WBADRI3(wb_adr_i[3]), 
        .WBADRI2(wb_adr_i[2]), .WBADRI1(wb_adr_i[1]), .WBADRI0(wb_adr_i[0]), 
        .WBDATI7(wb_dat_i[7]), .WBDATI6(wb_dat_i[6]), .WBDATI5(wb_dat_i[5]), 
        .WBDATI4(wb_dat_i[4]), .WBDATI3(wb_dat_i[3]), .WBDATI2(wb_dat_i[2]), 
        .WBDATI1(wb_dat_i[1]), .WBDATI0(wb_dat_i[0]), .PLL0DATI7(scuba_vlo), 
        .PLL0DATI6(scuba_vlo), .PLL0DATI5(scuba_vlo), .PLL0DATI4(scuba_vlo), 
        .PLL0DATI3(scuba_vlo), .PLL0DATI2(scuba_vlo), .PLL0DATI1(scuba_vlo), 
        .PLL0DATI0(scuba_vlo), .PLL0ACKI(scuba_vlo), .PLL1DATI7(scuba_vlo), 
        .PLL1DATI6(scuba_vlo), .PLL1DATI5(scuba_vlo), .PLL1DATI4(scuba_vlo), 
        .PLL1DATI3(scuba_vlo), .PLL1DATI2(scuba_vlo), .PLL1DATI1(scuba_vlo), 
        .PLL1DATI0(scuba_vlo), .PLL1ACKI(scuba_vlo), .I2C1SCLI(i2c1_scli), 
        .I2C1SDAI(i2c1_sdai), .I2C2SCLI(scuba_vlo), .I2C2SDAI(scuba_vlo), 
        .SPISCKI(scuba_vlo), .SPIMISOI(scuba_vlo), .SPIMOSII(scuba_vlo), 
        .SPISCSN(scuba_vlo), .TCCLKI(scuba_vlo), .TCRSTN(scuba_vlo), .TCIC(scuba_vlo), 
        .UFMSN(scuba_vhi), .WBDATO7(wb_dat_o[7]), .WBDATO6(wb_dat_o[6]), 
        .WBDATO5(wb_dat_o[5]), .WBDATO4(wb_dat_o[4]), .WBDATO3(wb_dat_o[3]), 
        .WBDATO2(wb_dat_o[2]), .WBDATO1(wb_dat_o[1]), .WBDATO0(wb_dat_o[0]), 
        .WBACKO(wb_ack_o), .PLLCLKO(), .PLLRSTO(), .PLL0STBO(), .PLL1STBO(), 
        .PLLWEO(), .PLLADRO4(), .PLLADRO3(), .PLLADRO2(), .PLLADRO1(), .PLLADRO0(), 
        .PLLDATO7(), .PLLDATO6(), .PLLDATO5(), .PLLDATO4(), .PLLDATO3(), 
        .PLLDATO2(), .PLLDATO1(), .PLLDATO0(), .I2C1SCLO(i2c1_sclo), .I2C1SCLOEN(i2c1_scloen), 
        .I2C1SDAO(i2c1_sdao), .I2C1SDAOEN(i2c1_sdaoen), .I2C2SCLO(), .I2C2SCLOEN(), 
        .I2C2SDAO(), .I2C2SDAOEN(), .I2C1IRQO(i2c1_irqo), .I2C2IRQO(), .SPISCKO(), 
        .SPISCKEN(), .SPIMISOO(), .SPIMISOEN(), .SPIMOSIO(), .SPIMOSIEN(), 
        .SPIMCSN7(), .SPIMCSN6(), .SPIMCSN5(), .SPIMCSN4(), .SPIMCSN3(), 
        .SPIMCSN2(), .SPIMCSN1(), .SPIMCSN0(), .SPICSNEN(), .SPIIRQO(), 
        .TCINT(), .TCOC(), .WBCUFMIRQ(), .CFGWAKE(), .CFGSTDBY());



    // exemplar begin
    // exemplar end

endmodule
