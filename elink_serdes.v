module elink_serdes_receiver(
    input wire [7:0] in,
    input wire frame_in,
    input wire lclk,
    
    output wire locked,
    output wire pclk,
    
    output wire [63:0] out,
    output wire [7:0] out_mask
);

wire [71:0] data;

// Instantiate an ALTLVDS_RX hard IP with 600Mbit per channel, 9 bit input
// and deserialization factor of 8.
// The LCLK from the Epiphany is CCLK/2 (600/2) = 300MHz
// Data is DDR and sampled on both edges of LCLK
// The output parallel clock is LCLK/8 (deserialization factor) = 75MHz
// This results in 72 bits vaild on each rising edge of the parallel clock.
// The 9 input channels are the FRAME signal, and the 8 DATA TXO lines from the Epiphany
elink_lvds rxlvds(
    .rx_inclock(lclk),
    .rx_in({frame_in, in}),
    .rx_locked(locked),
    .rx_outclock(pclk),
    .rx_out(data) //,
    //.rx_channel_data_align(bitslip)
);

// The FRAME signal from the Epiphany is passed through the SERDES.
// The upper byte of the data are samples of the FRAME line per LCLK edge (rise and fall)
// There are 8 edges (4 clock cyles) per parallell clock cycle, so out_mask contains 8 bits
// This will be used to align the frame boundaries since this tells us where the data lies in each block
assign out_mask = data[71:64];

// The elink interface is actually a parallell interface, but the SERDES
// is treating each of the 8 data lines as independent serial streams.
// Here, we pivot back to parallell data, by taking a bit from each of the deserialized bytes.
// The first byte is composed of the MSB of each byte from the SERDES output
// The second byte is composed of the second bit of each byte from the SERDES output
// etc..
assign out[63:56] = {data[63], data[55], data[47], data[39], data[31], data[23], data[15], data[7]};
assign out[55:48] = {data[62], data[54], data[46], data[38], data[30], data[22], data[14], data[6]};
assign out[47:40] = {data[61], data[53], data[45], data[37], data[29], data[21], data[13], data[5]};
assign out[39:32] = {data[60], data[52], data[44], data[36], data[28], data[20], data[12], data[4]};
assign out[31:24] = {data[59], data[51], data[43], data[35], data[27], data[19], data[11], data[3]};
assign out[23:16] = {data[58], data[50], data[42], data[34], data[26], data[18], data[10], data[2]};
assign out[15:8]  = {data[57], data[49], data[41], data[33], data[25], data[17], data[9],  data[1]};
assign out[7:0]   = {data[56], data[48], data[40], data[32], data[24], data[16], data[8],  data[0]};

endmodule
