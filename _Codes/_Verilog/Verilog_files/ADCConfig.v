module ADCConfig
  (
   input            clk,
   input            reset,

   input [2:0]      read_address,
   output reg [8:0] read_data,
   input            read_en,
   output           read_rdy,
   output reg       read_done, 
   
   input [2:0]      write_address,
   input [8:0]      write_data,
   input            write_en,
   output           write_rdy,
   output reg       write_done,
   
   //////////////////////////
   // EXTERNAL CONNECTIONS //
   //////////////////////////
   output reg       SCLK,
   inout            SDATA,
   output reg       SLOAD
   );
   
   wire        sdata_in;  // ADC to FPGA SDATA
   reg         sdata_out; // FPGA to ADC SDATA
   reg         sdata_oe;  // Output enable for bidirectional SDATA

   reg [2:0]   address;
   reg         read;
   
   // State machine for writing to the ADC
   reg [7:0]   delay_counter;
   reg [3:0]   bit_counter;
   reg [2:0]   state;
   reg [8:0]   data;
   localparam [2:0] STATE_IDLE    = 3'd0;
   localparam [2:0] STATE_ADDRESS = 3'd1;
   localparam [2:0] STATE_DELAY   = 3'd2;
   localparam [2:0] STATE_DATA    = 3'd3;

   assign write_rdy = state == STATE_IDLE;
   assign read_rdy = write_rdy;
   
   assign sdata_in = SDATA;
   assign SDATA = sdata_oe ? sdata_out : 1'bz; // Tri-state bus

   always@(posedge clk) begin
      if (reset) begin
         SCLK <= 0;
         SLOAD <= 1;
         sdata_out <= 0;
         sdata_oe <= 0;
         delay_counter <= 0;
         bit_counter <= 0;

			read_data <= 0;
         read_done <= 0;
         write_done <= 0;
         state  <= STATE_IDLE;

      end
      else begin
         read_done <= 0;
         write_done <= 0;
         if (state == STATE_IDLE) begin
            sdata_oe <= 1;
            if (write_en) begin
               address <= write_address;
               data <= write_data;
               delay_counter <= 0;
               bit_counter <= 0;
               read <= 0;
               SLOAD <= 0;
               state <= STATE_ADDRESS;
            end // if (write_en)

            if (read_en) begin
               address <= read_address;
               delay_counter <= 0;
               bit_counter <= 0;
               read <= 1;
               SLOAD <= 0;
               state <= STATE_ADDRESS;
               
            end
            
         end
         else begin
            // Slow down SCLK
            delay_counter <= delay_counter + 1;
            
            if (delay_counter == 128) begin
               SCLK <= 1;
               if (read && state == STATE_DATA) begin
                  if (bit_counter == 0) begin
                     sdata_oe <= 0;
                  end
                  else
                    data <= {data[7:0], sdata_in};
               end
            end
            else if (delay_counter == 0) begin
               SCLK <= 0;
               
               case (state)
                 STATE_ADDRESS:
                   // Send the R/W bit, and the three address bits
                   begin
                      bit_counter <= bit_counter + 1;
                      case (bit_counter)
                        0: sdata_out <= read;
                        1: sdata_out <= address[2];
                        2: sdata_out <= address[1];
                        3: begin
                           sdata_out <= address[0];
                           
                           bit_counter <= 0;
                           state <= STATE_DELAY;
                        end
                      endcase
                   end // case: STATE_ADDRESS
                 
                 STATE_DELAY:
                   // Pause for three cycles 
                   begin
                      sdata_out <= 0;
                      if (bit_counter == 2) begin
                         bit_counter <= 0;
                         state <= STATE_DATA;
                         if (read) sdata_oe <= 0;
                      end
                      else begin
                         bit_counter <= bit_counter + 1;
                      end
                   end // case: STATE_DELAY
                 
                 STATE_DATA:
                   // Send out 9-bit word
                   begin
                      bit_counter <= bit_counter + 1;
                      if (bit_counter == 9) begin
                         state <= STATE_IDLE;
                         SLOAD <= 1;
                         if (read) begin
									read_done <= 1;
									read_data <= data;
								 end
                         else      write_done <= 1;
                         
                      end
                      if (!read) begin
                         // send out MSB
                         sdata_out <= data[8];
                         // shift data one bit
                         data <= {data[7:0], 1'b0};
                      end
                   end // case: STATE_DATA
               endcase // case (state)
            end // if (delay_counter == 0)
         end // else: !if(state == STATE_IDLE)
      end // else: !if(reset)
   end // always@ (posedge clk)
   
endmodule
   
  
             
