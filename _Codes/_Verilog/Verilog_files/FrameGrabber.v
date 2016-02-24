`timescale 10ns/1ns
module FrameGrabber
  (
   input 	 clk,
   input 	 reset,

   input 	 timing_start,
   output 	 timing_rdy,
   output 	 timing_done,

   input [31:0]  integration_time,
   
   input [14:0]  ram_read_address,
   output [15:0] ram_read_data,

   output 	 mod_enable,
   
   // To the PMD
   output 	 RESET_1,
   output 	 HOLD,
   output 	 START_ROI,
   output 	 CLK_ROI,
   input 	 ENABLE_ROI,

   // To the PMD SPI port
   output 	 SPI_CLK,
   output 	 MOSI,
   input 	 MISO,
   output 	 CS_A,
   output 	 CS_D,
   
   // To the ADC
   output 	 CDSCLK1,
   output 	 CDSCLK2,
   output 	 ADCCLK,
   input [7:0] 	 DATA,

   // To the ADC config port
   output 	 SCLK,
   output 	 SDATA,
   output 	 SLOAD
   );

   reg [4:0]   state;
   localparam STATE_SET_END_COL  = 4'd0;
   localparam STATE_SET_END_ROW  = 4'd1;
   localparam STATE_READ_END_COL = 4'd2;
   localparam STATE_READ_END_ROW = 4'd3;
   localparam STATE_IDLE         = 4'd4;
   localparam STATE_SAMPLE_WAIT  = 4'd5;
   localparam STATE_SAMPLE_ACQ   = 4'd6;
   localparam STATE_SAMPLE_G     = 4'd7;
   localparam STATE_SAMPLE_B     = 4'd8;
   localparam STATE_SAMPLE_END   = 4'd9;
   
   reg [15:0]  pixel_counter;
   
   // For SPI configuration
   reg         cycle;
  
   reg         channel;
   reg         write_en;
   wire        write_rdy;
   wire        write_done;
   reg [6:0]   write_address;
   reg [7:0]   write_data;
   
   reg         read_en;
   wire        read_rdy;
   wire        read_done;
   reg [6:0]   read_address;
   wire [7:0]  read_data;
   
   // ADC
   reg         sample_en;
   wire        sample_done;
   wire [15:0] red;
   wire [15:0] green;
   wire [15:0] blue;

   // timing
   wire [7:0]  current_row;
   wire [7:0]  current_column;
   wire        sample_pixel;

   // frame RAM
   reg [14:0]  ram_write_address;
   reg [15:0]  ram_write_data;
   reg         ram_write_enable;
   
   AD9826 adc (
	       .clk(clk),
	       .reset(reset),

               .sample_en(sample_en),
               .sample_rdy(),
               .sample_done(sample_done),
               
	       .red(red),
	       .green(green),
	       .blue(blue),
	       
	       .CDSCLK1(CDSCLK1),
	       .CDSCLK2(CDSCLK2),
	       .ADCCLK(ADCCLK),
	       .DATA(DATA),
	       .SCLK(SCLK),
	       .SDATA(SDATA),
	       .SLOAD(SLOAD)
	       );
   
   SPI spi (
	    .clk(clk),
	    .reset(reset),
	    
	    .write_en(write_en),
	    .write_rdy(write_rdy),
	    .write_done(write_done),
	    .write_address(write_address),
	    .write_data(write_data),
	    
	    .read_en(read_en),
	    .read_rdy(read_rdy),
	    .read_done(read_done),
	    .read_address(read_address),
	    .read_data(read_data),
	    
	    .channel(channel),
	    
	    .SCK(SPI_CLK),
	    .MOSI(MOSI),
	    .MISO(MISO),
	    .CS_A(CS_A),
	    .CS_D(CS_D)
	    );

   PMDTiming pmd_timing
     (
      .clk(clk),
      .reset(reset),
      .RESET_1(RESET_1),
      .HOLD(HOLD),
      .START_ROI(START_ROI),
      .CLK_ROI(CLK_ROI),
      .ENABLE_ROI(ENABLE_ROI),

      .mod_enable(mod_enable),
      
      .frame_start(timing_start),
      .frame_rdy(timing_rdy),
      .frame_done(timing_done),

      .integration_time(integration_time),
      
      .current_row(current_row),
      .current_column(current_column),
      .sample_pixel(sample_pixel)
      );

   // 162 x 120 x 16-bit block ram for storing the current frame
   BlockRam
     #(
       .ADDRESS_WIDTH(15),
       .DATA_WIDTH(16),
       .DEPTH(19440)
       )
   frame_ram
     (
      .clk(clk),
      
      .read_address(ram_read_address),
      .read_data(ram_read_data),
      
      .write_address(ram_write_address),
      .write_data(ram_write_data),
      .write_enable(ram_write_enable)
      );
   
   always @ (posedge clk) begin
      if (reset) begin
         state <= STATE_SET_END_COL;
         sample_en <= 0;
	 
         write_en <= 0;
	 read_en  <= 0;
	 
         ram_write_enable <= 0;
         cycle <= 0;
      end
      else begin
         case (state)
           STATE_SET_END_COL:
             begin
                write_en <= 0;
                if (write_rdy && cycle == 0) begin
                   channel       <= 1; // Configure digital interface
                   write_address <= 7'd2; // Address of end col register
                   write_data    <= 8'd53;
                   write_en      <= 1;
                   cycle         <= 1;
                end
                else if (write_done && cycle == 1) begin
                   cycle <= 0;
                   state <= STATE_SET_END_ROW;
                end
             end // case: STATE_SET_END_COL
           STATE_SET_END_ROW:
             begin
                write_en <= 0;
                if (write_rdy && cycle == 0) begin
                   write_address <= 7'd7; // Address of end row register
                   write_data    <= 8'd119;
                   write_en      <= 1;
                   cycle         <= 1;
                end
                else if (write_done && cycle == 1) begin
                   cycle <= 0;
                   state <= STATE_IDLE;
                end
             end // case: STATE_SET_END_ROW
           STATE_IDLE:
             begin
                if (timing_start) begin
                   state <= STATE_SAMPLE_WAIT;
                end
             end
           STATE_SAMPLE_WAIT:
             begin
                // Waiting for signal from timing module
					 if (timing_done) begin
					    state <= STATE_IDLE;
						 ram_write_enable <= 0;
					 end
                if (sample_pixel) begin
                   sample_en <= 1;
                   state <= STATE_SAMPLE_ACQ;
                end
             end
           STATE_SAMPLE_ACQ:
             begin
                // Wait for ADC to finish sampling
                sample_en <= 0;
                if (sample_done) begin
                   // Write the first pixel into memory
                   ram_write_address <= current_row * 162 + current_column*3;
                   ram_write_data    <= red;
                   ram_write_enable  <= 1'b1;
                   state <= STATE_SAMPLE_G;
                end
             end // case: STATE_SAMPLE_ACQ
           STATE_SAMPLE_G:
             begin
                ram_write_address <= ram_write_address + 1;
                ram_write_data    <= green;
                state <= STATE_SAMPLE_B;
             end
           STATE_SAMPLE_B:
             begin
                ram_write_address <= ram_write_address + 1;
                ram_write_data    <= blue;
                state <= STATE_SAMPLE_END;
             end
           STATE_SAMPLE_END:
             begin
                ram_write_enable <= 1'b0;
                if (timing_done) begin
                   state <= STATE_IDLE;
                end begin
                   state <= STATE_SAMPLE_WAIT;
                end 
             end
         endcase // case (state)
       
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule
