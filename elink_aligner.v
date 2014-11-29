`timescale 1ns/1ps

module elink_aligner(
    input clk,
    input [63:0] in,
    input [7:0] mask,
    output reg [111:0] out,
    output reg out_valid,

    output [7:0] b0,
    output [3:0] ctrlmode,
    output [31:0] dest_addr,
    output write,
    output access,
    output [1:0] datamode,
    output [31:0] data,
    output [31:0] src_addr
);

reg [7:0] pos;
wire [7:0] shift;
wire [7:0] count;
wire [7:0] count_tail;

reg [7:0] last_mask = 8'd0;
reg [111:0] last_out = 112'd0;
reg [7:0] last_pos = 8'd0;

assign b0 = out_valid ? out[111:104] : 0;
assign ctrlmode = out_valid ? out[103:100] : 0;
assign dest_addr = out_valid ? out[99:68] : 0;
assign datamode = out_valid ? out[67:66] : 0;
assign write = out_valid ? out[65] : 0;
assign access = out_valid ? out[64] : 0;
assign data = out_valid ? out[63:32] : 0;
assign src_addr = out_valid ? out[31:0] : 0;

// Number of bytes in the first chunk of data, including 'full' chunks of 8 bytes
// This will default to 0 for trailing data chunks
assign count = mask == 8'b11111111 ? 8'd8 :
               mask == 8'b01111111 ? 8'd7 :
               mask == 8'b00111111 ? 8'd6 :
               mask == 8'b00011111 ? 8'd5 :
               mask == 8'b00001111 ? 8'd4 :
               mask == 8'b00000111 ? 8'd3 :
               mask == 8'b00000011 ? 8'd2 : 
               mask == 8'b00000001 ? 8'd1 : 8'd0;

// Number of bytes in the chunk containing the tail end of a frame
assign count_tail = mask == 8'b11111110 ? 8'd7 :
                    mask == 8'b11111100 ? 8'd6 :
                    mask == 8'b11111000 ? 8'd5 :
                    mask == 8'b11110000 ? 8'd4 :
                    mask == 8'b11100000 ? 8'd3 :
                    mask == 8'b11000000 ? 8'd2 :
                    mask == 8'b10000000 ? 8'd1 : 8'd0;

// Number of bytes to shift out in the chunk containing the tail end of the frame
assign shift = mask == 8'b11111111 ? 8'd0 :
               mask == 8'b11111110 ? 8'd1 :
               mask == 8'b11111100 ? 8'd2 :
               mask == 8'b11111000 ? 8'd3 :
               mask == 8'b11110000 ? 8'd4 :
               mask == 8'b11100000 ? 8'd5 : 
               mask == 8'b11000000 ? 8'd6 : 
               mask == 8'b10000000 ? 8'd7 : 8'd0;

initial
begin
    pos <= 8'b0;
    out <= 111'b0;
end

always @(posedge clk) begin
        last_out = out;
        last_pos = pos;
                last_mask = mask;

        out_valid = 0;
 
        // Increment the number of bits in the output register
        pos = last_pos + count*8 + count_tail*8;

        // (in >> (shift*8)) right aligns the data according to the mask
        // for example if we have 3 bytes in the input net, the mask from
        // the deserializer would contain 8'b11100000
        // The input is shifted right by 40 bits in this case
                
        // Shift the output register left, and OR the right aligned input
        // This acts as a shift register, sliding the parallell data
        // through the frame until it is aligned
        out = (last_out << 112-last_pos) | (in >> (shift*8));

        if(pos >= 14*8)
        begin
            pos = 0;
            last_pos = 0;
            out_valid = 1;
        end

end

endmodule
