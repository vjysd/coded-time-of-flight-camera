module ADCSample
  (
   input         clk,
   input         reset,

   input         sample_en,
   output        sample_rdy,
   output reg    sample_done,
   output [15:0] red,
   output [15:0] green,
   output [15:0] blue,

   ////////////////////
   // EXTERNAL PORTS //
   ////////////////////
   
   output        CDSCLK1,
   output        CDSCLK2,
   output        ADCCLK,

   input [7:0]   DATA
   );
   
   // clock divider to slow down sample and ADC clock
   reg [31:0]         clock_div;

   localparam SAMPLE_PERIOD = 8 / 2; // 80ns
   localparam ADCCLK_PERIOD = 8 / 2; // 80ns
   
   // Triggers an ADC sample
   reg               sample_clk;
   // Byte readout clock
   reg               adc_clk;

   // The current byte to read
   reg [2:0]         current_byte;
   reg [47:0]        adc_data;

   reg [2:0]         state;
   localparam [2:0] STATE_IDLE = 3'd0;
   localparam [2:0] STATE_SAMPLE = 3'd1;
   localparam [2:0] STATE_READOUT = 3'd2;
   
   assign CDSCLK1 = 0;
   assign CDSCLK2 = sample_clk;
   assign ADCCLK = adc_clk;

   assign sample_rdy = state == STATE_IDLE;
   assign red = adc_data[47:32];
   assign green = adc_data[31:16];
   assign blue = adc_data[15:0];

   always @(posedge clk) begin
      if (reset) begin
         sample_done <= 0;
         clock_div <= 0;
         sample_clk <= 0;
         adc_clk <= 0;
         current_byte <= 0;
         
         state <= STATE_IDLE;
      end // if (reset)
      else begin
         sample_done <= 0;
         case (state)
           // Wait for sample_en
           STATE_IDLE: begin
              if (sample_en) begin
                 clock_div <= SAMPLE_PERIOD;
                 adc_clk <= 0;
                 sample_clk <= 1;
                 state <= STATE_SAMPLE;
              end
           end
           
           // Wait for sample period to finish
           STATE_SAMPLE: begin
              if (clock_div == 0) begin
                 clock_div <= ADCCLK_PERIOD;
                 sample_clk <= 0;
                 
                 state <= STATE_READOUT;
                 adc_clk <= ~adc_clk;
              end
              else begin
                 clock_div <= clock_div - 1;
              end
           end // case: STATE_SAMPLE

           // Wait for data to settle
           STATE_READOUT: begin
              clock_div <= clock_div - 1;
              // Wait a half period after toggling adc_clk, in order to let the output settle
              if (clock_div == ADCCLK_PERIOD / 2) begin
                 // Sample the bus and move on
                 adc_data <= {adc_data[41:0], DATA};
                 current_byte <= current_byte + 1;
              end
              if (clock_div == 0) begin
                 if (current_byte == 6) begin
                    current_byte <= 0;
                    state <= STATE_IDLE;
		    sample_done <= 1;
                 end
                 else begin
                    // Toggle the ADCCLK signal
                    clock_div <= ADCCLK_PERIOD;
                    adc_clk <= ~adc_clk;
                 end
              end
           end
         endcase // case (state)
      end // else: !if(reset)
   end // else: !if(reset)
   
endmodule
