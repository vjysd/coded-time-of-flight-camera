module AD9826
  (
   input         clk,
   input         reset,

   //////////////
   // SAMPLING //
   //////////////
   output        sample_rdy,
   input         sample_en,
   output [15:0] red,
   output [15:0] green,
   output [15:0] blue,
   output        sample_done,
   
   //////////////////////////
   // EXTERNAL CONNECTIONS //
   //////////////////////////
   
   // Acquisition
   output        CDSCLK1,
   output        CDSCLK2,
   output        ADCCLK,
   input [7:0]   DATA,
   
   // Configuration interface
   output        SCLK,
   inout         SDATA,
   output        SLOAD
   );

   wire          sample_rdy_1;
   
   wire [2:0]    read_address;
   wire [8:0]    read_data;
   reg           read_en;
   wire          read_rdy;
   wire          read_done;
   
   
   wire [2:0]    write_address;
   reg [8:0]     write_data;
   reg           write_en;
   wire          write_rdy;
   wire          write_done;
   
   reg [1:0]     cycle;
   reg [2:0]     state;
   localparam [2:0] STATE_IDLE   = 3'd0;
   localparam [2:0] STATE_INIT   = 3'd1;
   localparam [2:0] STATE_READY  = 3'd2;
   
   /* Bits:
    Unused
    4V range
    internal vref
    3ch mode
    cds mode
    input camp bias = 4V
    powered-up
    unused
    2-byte mode
    */
   //data <= 9'b0_111011_0_0;
   
   assign read_address = 3'b000;
   
   assign write_address = 3'b000;

   assign sample_rdy = sample_rdy_1 && (state == STATE_READY);
   
   ADCConfig adc_config
     (
      .clk(clk),
      .reset(reset),
      
      .read_address(read_address),
      .read_data(read_data),
      .read_en(read_en),
      .read_rdy(read_rdy),
      .read_done(read_done),
      
      .write_address(write_address),
      .write_data(write_data),
      .write_en(write_en),
      .write_rdy(write_rdy),
      .write_done(write_done),
      
      .SCLK(SCLK),
      .SDATA(SDATA),
      .SLOAD(SLOAD)
      );
   
   
   ADCSample adc_sample
     (
      .clk(clk),
      .reset(reset),
      
      .sample_en(sample_en),
      .sample_rdy(sample_rdy_1),
      .sample_done(sample_done),
      .red(red),
      .green(green),
      .blue(blue),
      .CDSCLK1(CDSCLK1),
      .CDSCLK2(CDSCLK2),
      .ADCCLK(ADCCLK),
      .DATA(DATA)
      );
   
   
   always @(posedge clk) begin
      if (reset) begin
         read_en <= 0;
         write_en <= 0;
         
         cycle <= 0;
         state <= STATE_IDLE;
      end
      
      else begin
         case (state)
           STATE_IDLE: begin
              state <= STATE_INIT;
           end
           STATE_INIT: begin
              case (cycle)
                0: begin
                   if (write_rdy) begin
                      write_en <= 1;
                      write_data <= 9'b0_111010_0_0;
                      cycle <= cycle + 1;
                   end
                end
                1: begin
                   write_en <= 0;
                   if (write_done) begin
                      cycle <= 0;
                      state <= STATE_READY;
                   end
                end
              endcase // case (cycle)
           end // case: STATE_INIT
           // STATE_VERIFY: begin
           //    case (cycle)
           //      0: begin
           //         if (read_rdy) begin
           //            read_en <= 1;
           //            cycle <= cycle + 1;
           //         end
           //      end
           //      1: begin
           //         read_en <= 0;
           //         if (read_done) begin
           //            cycle <= 0;
           //         end
           //      end
  //              endcase // case (cycle)
  //           end // case: STATE_VERIFY
   endcase // case (state)
      end // else: !if(reset)
   end // always @ (posedge clk)
   
endmodule
