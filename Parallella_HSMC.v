module Parallella_HSMC(

    //////////// CLOCK //////////
    input                       CLOCK_125_p,
    input                       CLOCK_50_B5B,
    input                       CLOCK_50_B6A,
    input                       CLOCK_50_B7A,
    input                       CLOCK_50_B8A,

    //////////// LED //////////
    output           [7:0]      LEDG,
    output           [9:0]      LEDR,

    //////////// KEY //////////
    input                       CPU_RESET_n,
    input            [3:0]      KEY,

    //////////// SW //////////
    input            [9:0]      SW,

    //////////// SEG7 //////////
    output           [6:0]      HEX0,
    output           [6:0]      HEX1,

    //////////// HDMI-TX //////////
    /*
    output                      HDMI_TX_CLK,
    output          [23:0]      HDMI_TX_D,
    output                      HDMI_TX_DE,
    output                      HDMI_TX_HS,
    input                       HDMI_TX_INT,
    output                      HDMI_TX_VS,
    */

    //////////// ADC SPI //////////
    /*
    output                      ADC_CONVST,
    output                      ADC_SCK,
    output                      ADC_SDI,
    input                       ADC_SDO,
    */

    //////////// Audio //////////
    /*
    input                       AUD_ADCDAT,
    inout                       AUD_ADCLRCK,
    inout                       AUD_BCLK,
    output                      AUD_DACDAT,
    inout                       AUD_DACLRCK,
    output                      AUD_XCK,
    */
    
    //////////// I2C for Audio/HDMI-TX/Si5338/HSMC //////////
    /*
    output                      I2C_SCL,
    inout                       I2C_SDA,
    */

    //////////// SDCARD //////////
    /*
    output                      SD_CLK,
    inout                       SD_CMD,
    inout            [3:0]      SD_DAT,
    */

    //////////// Uart to USB //////////
    input                       UART_RX,
    output                      UART_TX,

    //////////// SRAM //////////
    /*
    output          [17:0]      SRAM_A,
    output                      SRAM_CE_n,
    inout           [15:0]      SRAM_D,
    output                      SRAM_LB_n,
    output                      SRAM_OE_n,
    output                      SRAM_UB_n,
    output                      SRAM_WE_n,
    */

    //////////// LPDDR2 //////////
    /*
    output           [9:0]      DDR2LP_CA,
    output                      DDR2LP_CK_n,
    output                      DDR2LP_CK_p,
    output           [1:0]      DDR2LP_CKE,
    output           [1:0]      DDR2LP_CS_n,
    output           [3:0]      DDR2LP_DM,
    inout           [31:0]      DDR2LP_DQ,
    inout            [3:0]      DDR2LP_DQS_n,
    inout            [3:0]      DDR2LP_DQS_p,
    input                       DDR2LP_OCT_RZQ,
    */

    //////////// GPIO, GPIO connect to GPIO Default //////////
    inout           [35:0]      GPIO,

    //////////// HSMC, HSMC connect to HSMC Default With Transceiver //////////
    input            [2:1]      HSMC_CLKIN_p,
    output           [2:1]      HSMC_CLKOUT_p,
    //output                        HSMC_CLKOUT0,
    //inout              [3:0]      HSMC_D,
    /*
    input            [3:0]      HSMC_GXB_RX_p,
    output           [3:0]      HSMC_GXB_TX_p,
    */
    
    input           [16:0]      HSMC_RX_p,
    output          [16:0]      HSMC_TX_p
);


//=======================================================
//  REG/WIRE declarations
//=======================================================

// 5MHz PLL output
wire clk5;
// 100MHz PLL output
wire clk100;

wire elink_rx_pclk;
wire [63:0] elink_rx_data;
wire [7:0] elink_rx_mask;

wire [111:0] elink_rx_frame;
wire [31:0] elink_rx_payload;
wire elink_rx_valid;

//=======================================================
//  Structural coding
//=======================================================

pll mypll(
    .refclk(CLOCK_50_B5B),
    .outclk_0(clk5),
    .outclk_1(clk100),
    .locked(LEDG[0])
);

// Instantiate a receiver serdes, which will lock to LCLK, and generate a LCLK/8 parallell clock
// The out net is a 64 bit array of the last data received on the RXI_DATA lines
// The out_mask net is an 8 bit array containing the status of the FRAME line for the last 8 bytes
// LCLK = CCLK/2
// CCLK = 600MHz
// LCLK = 300MHz
// PCLK = 75MHz
elink_serdes_receiver receiver(
    .in(HSMC_RX_p[7:0]),
    .frame_in(HSMC_RX_p[15]),
    .lclk(HSMC_CLKIN_p[1]),
    .locked(LEDG[1]),
    .pclk(elink_rx_pclk),
    .out(elink_rx_data),
    .out_mask(elink_rx_mask)
);

// Instantiate an aligner which will register the incoming data blocks from the serdes
// and raise out_valid when the data is aligned. The output nets are assigned to the aligned
// fields of the frame and are valid on the rising edge of out_valid.
// There is a minimum 2 clock delay until data is valid. The only frame size currently supported
// is 14 bytes, so it takes 2*8 byte chunks for a full 14 byte frame to be buffered
elink_aligner aligner(
    .clk(elink_rx_pclk),
    .in(elink_rx_data),
    .mask(elink_rx_mask),
    .out(elink_rx_frame),
    .out_valid(elink_rx_valid),
    .data(elink_rx_payload)
);
assign GPIO[0] = elink_rx_pclk;
assign GPIO[1] = elink_rx_valid;
assign LEDG[2] = elink_rx_valid;

reg [31:0] last_data = 32'd0;
reg [31:0] current_data = 32'd0;

// As a test, we sample elink_rx_valid on each rising edge of the parallell clock.
// If data is valid, put the received data into the current_data register
// This acts as a latch, retaining the previous value for display on LEDs
always @(posedge elink_rx_pclk) begin
    if(elink_rx_valid)
    begin
        current_data = elink_rx_payload;
    end else begin
        current_data = last_data;
    end
	 last_data = current_data;
end

// Wire 8 red LEDs to the lower 8 bits of the latched data
assign LEDR[7:0] = current_data[7:0];

// TXI_RD_WAIT
assign HSMC_TX_p[15] = 0;
// TXI_WR_WAIT
assign HSMC_TX_p[16] = 0;

endmodule
