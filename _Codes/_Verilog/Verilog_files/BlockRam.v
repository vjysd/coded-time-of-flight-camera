module BlockRam
  #(
    parameter DATA_WIDTH = 8,
    parameter ADDRESS_WIDTH = 8,
    parameter DEPTH = 256
    )
  (
   input                       clk,

   input [ADDRESS_WIDTH-1:0]   read_address,
   output reg [DATA_WIDTH-1:0] read_data,

   input                       write_enable,
   input [ADDRESS_WIDTH-1:0]   write_address,
   input [DATA_WIDTH-1:0]      write_data
   );

   reg [DATA_WIDTH-1:0]        mem [DEPTH-1:0];

   always @ (posedge clk) begin
      if (write_enable) begin
         mem[write_address] <= write_data;
      end
      read_data <= mem[read_address];
   end
   
endmodule
