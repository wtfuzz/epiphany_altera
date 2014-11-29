## Epiphany eLink Interface

This currenly only implements a basic receiver interface using ALTLVDS_RX
to receive the 300MHz DDR from the 8 data lines from the Epiphany chip.

ALTLVDS_RX uses dedicated hard IP in the FPGA rather than LEs to implement the fast clock side
and supports sampling at phase angles to sample both edges of the clock for DDR.

### Test Hardware

* Terasic C5G (Cyclone V GX)
* Custom HSMC PCB carrier for Parallella which routes PEC_NORTH to HSMC LVDS pairs

### Verilog

* elink_serdes.v contains the ALTLVDS_RX IP and 'pivots' the data back to parallell (eLink isn't 8x serial lines, but rather 8 bit parallell. We can take advantage of the serdes hard IP, but the data appears odd without reorganizing it). This also provides an 8 bit frame byte corresponding to the FRAME signal over the last 8 clock edges.
* elink_aligner.v contains a basic alignment module to shift the received chunks to the frame boundaries, and signal when output frame data is valid
* Parallella_HSMC.v is the top level entity which instantiates the basic receiver, and provides a simple latch of received frame payload data. The latched payload data is wired to 8 LEDs on the C5G board, so the last value received over the eLink is displayed in binary



