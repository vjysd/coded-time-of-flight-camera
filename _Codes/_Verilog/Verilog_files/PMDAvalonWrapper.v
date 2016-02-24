module PMDAvalonWrapper
  (
   input 	     clock,
   input 	     reset,
   
   input [15:0]      address,
   output reg [15:0] read_data,
   input [15:0]      write_data,
   
   input 	     read,
   input 	     write,

   // Two sets of modulation clocks of the same frequency. One drives the PMD, one drives the light source
   input 	     mod_clk,
   input 	     mod_clk_delay,

   ////////////////////
   // EXTERNAL PORTS //
   ////////////////////
   
   // To the PMD
   output 	     RESET_1,
   output 	     HOLD,
   output 	     MODSEL,
   output 	     START_ROI,
   output 	     CLK_ROI,
   input 	     ENABLE_ROI,
   
   // To the PMD SPI port
   output 	     SPI_CLK,
   output 	     MOSI,
   input 	     MISO,
   output 	     CS_A,
   output 	     CS_D,
   
   // To the ADC
   output 	     CDSCLK1,
   output 	     CDSCLK2,
   output 	     ADCCLK,
   input [7:0] 	     DATA,
   
   // To the ADC config port
   output 	     SCLK,
   output 	     SDATA,
   output 	     SLOAD,
   
   //To the PLL reconfig
   input 	     PHASE_DONE,
   output reg 	     PHASE_STEP,

   // To the light source
   output 	     LIGHT_MODSEL
   );
   
   reg 		     frame_start;
   wire 	     frame_rdy;
   wire 	     frame_done;
   reg [31:0] 	     delay_counter; 
   
   wire [14:0] 	     ram_read_address = address [14:0];
   wire [15:0] 	     ram_read_data;
   
   reg [15:0] 	     integration_time_lo;
   reg [15:0] 	     integration_time_hi;
   
   wire [31:0] 	     integration_time = {integration_time_hi, integration_time_lo};

   // 256 half periods (128 periods) of the modulation code
   reg [255:0] 	     modulation_code;
   
   // The length of the current modulation code
   reg [8:0] 	     modulation_code_length;
   
   FrameGrabber frame_grabber
     (
      .clk(clock),
      .reset(reset),

      .mod_enable(mod_enable),
      
      .timing_start(frame_start),
      .timing_rdy(frame_rdy),
      .timing_done(frame_done),
      
      .integration_time(integration_time),
      
      .ram_read_address(ram_read_address),
      .ram_read_data(ram_read_data),
      
      .RESET_1(RESET_1),
      .HOLD(HOLD),
      .START_ROI(START_ROI),
      .CLK_ROI(CLK_ROI),
      .ENABLE_ROI(ENABLE_ROI),
      .SPI_CLK(SPI_CLK),
      .MOSI(MOSI),
      .MISO(MISO),
      .CS_A(CS_A),
      .CS_D(CS_D),
      
      .CDSCLK1(CDSCLK1),
      .CDSCLK2(CDSCLK2),
      .ADCCLK(ADCCLK),
      .DATA(DATA),
      
      .SCLK(SCLK),
      .SDATA(SDATA),
      .SLOAD(SLOAD)
      );

   // Shift register which drives MODSEL for the PMD
   ShiftRegister
     #(
       .MAX_LENGTH(256),
       .COUNTER_WIDTH(9)
       )
   pmd_mod_register
     (
      .shift_clk(mod_clk),
      .reset(reset),
      .enable(1),
      
      .length(modulation_code_length),
      .data(modulation_code),
      .out(MODSEL)
      );
   
   // Shift register which drives the modulation signal for the light source
   // This has the same inputs as pmd_mod_register, except it uses a delayed clock signal
   ShiftRegister
     #(
       .MAX_LENGTH(256),
       .COUNTER_WIDTH(9)
       )
   light_mod_register
     (
      .shift_clk(mod_clk_delay),
      .reset(reset),
      .enable(1),
      
      .length(modulation_code_length),
      .data(modulation_code),
      .out(LIGHT_MODSEL)
      );

   always @(posedge clock or posedge reset) begin
      if (reset) begin
	 frame_start <= 0;
	 PHASE_STEP <= 0;
      end
      else begin
	 frame_start <= 0;
	 
	 if (PHASE_STEP == 1) begin
	    delay_counter <= delay_counter - 32'd1;
	    if (delay_counter == 0) begin
	       PHASE_STEP <= 0;
	    end
	 end
	 
	 if (write && address[15] == 0) begin
	    case (address[14:0])
	      15'h0000: frame_start <= write_data[0];
	      15'h0004: integration_time_lo <= write_data;
	      15'h0005: integration_time_hi <= write_data;
	      15'h0006:
		begin
		   PHASE_STEP <= 1;
		   delay_counter <= 2;
		end
	      15'h0007: modulation_code_length <= write_data;
	      15'h0008: modulation_code[15:0] <= write_data;
	      15'h0009: modulation_code[31:16] <= write_data;
	      15'h000A: modulation_code[47:32] <= write_data;
	      15'h000B: modulation_code[63:48] <= write_data;
	      15'h000C: modulation_code[79:64] <= write_data;
	      15'h000D: modulation_code[95:80] <= write_data;
	      15'h000E: modulation_code[111:96] <= write_data;
	      15'h000F: modulation_code[127:112] <= write_data;
	      15'h0010: modulation_code[143:128] <= write_data;
	      15'h0011: modulation_code[159:144] <= write_data;
	      15'h0012: modulation_code[175:160] <= write_data;
	      15'h0013: modulation_code[191:176] <= write_data;
	      15'h0014: modulation_code[207:192] <= write_data;
	      15'h0015: modulation_code[223:208] <= write_data;
	      15'h0016: modulation_code[239:224] <= write_data;
	      15'h0017: modulation_code[255:240] <= write_data;
	    endcase
	 end
      end
   end
   
   always @ (*) begin
      if (address[15] == 1'b0) begin
	 case (address[14:0])
	   15'h0000: read_data = 16'hBEEF; // frame_start is write-only
	   15'h0001: read_data = frame_rdy;
	   15'h0002: read_data = frame_done;
	   15'h0003: read_data = 16'hBEEF; // unused slot
	   15'h0004: read_data = integration_time_lo;
	   15'h0005: read_data = integration_time_hi;
	   15'h0006: read_data = 16'hBEEF; // phase step is write-only
	   15'h0007: read_data = modulation_code_length;
	   15'h0008: read_data = modulation_code[15:0];
	   15'h0009: read_data = modulation_code[31:16];
	   15'h000A: read_data = modulation_code[47:32];
	   15'h000B: read_data = modulation_code[63:48];
	   15'h000C: read_data = modulation_code[79:64];
	   15'h000D: read_data = modulation_code[95:80];
	   15'h000E: read_data = modulation_code[111:96];
	   15'h000F: read_data = modulation_code[127:112];
	   15'h0010: read_data = modulation_code[143:128];
	   15'h0011: read_data = modulation_code[159:144];
	   15'h0012: read_data = modulation_code[175:160];
	   15'h0013: read_data = modulation_code[191:176];
	   15'h0014: read_data = modulation_code[207:192];
	   15'h0015: read_data = modulation_code[223:208];
	   15'h0016: read_data = modulation_code[239:224];
	   15'h0017: read_data = modulation_code[255:240];
	   default:  read_data = 16'hBEEF;
	 endcase
      end
      else begin
	 read_data = ram_read_data;
      end
   end
   
   
   
endmodule
