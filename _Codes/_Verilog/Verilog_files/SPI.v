module SPI
  (
   input        clk,
   input        reset,

   // 0 for analog, 1 for digital
   input        channel,
   
   output       read_rdy,
   input        read_en,
   input [6:0]  read_address,
   output reg [7:0] read_data,
   output reg   read_done,

   output       write_rdy,
   input        write_en,
   input [6:0]  write_address,
   input [7:0]  write_data,
   output reg   write_done,

   //////////////////////////
   // EXTERNAL CONNECTIONS //
   //////////////////////////
   
   output reg   SCK,
   output reg   MOSI,
   input        MISO,
   output reg   CS_A,
   output reg   CS_D
   );

   reg          read;
   reg [6:0]    address;
   reg [7:0]    data;

   reg [31:0]   delay_counter;
   localparam CLOCK_DIV = 32'd2000;
   
   reg [3:0]    bit_counter;

   reg [1:0]    state;
   localparam [2:0] STATE_IDLE    = 2'd0;
   localparam [2:0] STATE_ADDRESS = 2'd1;
   localparam [2:0] STATE_DATA    = 2'd2;
   localparam [2:0] STATE_DELAY   = 2'd3;

   assign read_rdy = state == STATE_IDLE;
   assign write_rdy = state == STATE_IDLE;
   
   always @ (posedge clk) begin
      if (reset) begin
         SCK <= 0;
         MOSI <= 0;
         CS_A <= 0;
         CS_D <= 0;
         
         read_done <= 0;
         write_done <= 0;
         
         bit_counter <= 0;
         state <= STATE_IDLE;
      end
      else begin
         read_done <= 0;
         write_done <= 0;
         case (state)
           STATE_IDLE: begin
              if (write_en) begin
                 address <= write_address;
                 data <= write_data;
                 bit_counter <= 0;
                 read <= 0;
                 delay_counter <= CLOCK_DIV;
                 
                 if (channel == 0) CS_A <= 1;
                 else              CS_D <= 1;
                 
                 state <= STATE_ADDRESS;
              end // if (write_en)
              else if (read_en) begin
                 address <= read_address;
                 bit_counter <= 0;
                 read <= 1;
                 delay_counter <= CLOCK_DIV;
                 if (channel == 0) CS_A <= 1;
                 else              CS_D <= 1;
                 state <= STATE_ADDRESS;
              end
            end // case: STATE_IDLE
           STATE_ADDRESS: begin
              delay_counter <= delay_counter - 1;
              if (delay_counter == 0) begin
                 delay_counter <= CLOCK_DIV;
                 SCK <= 0;
              end
              if (delay_counter == CLOCK_DIV/2) begin
                 // Set SCK high and send bit
                 bit_counter <= bit_counter + 1;
                 if (bit_counter == 8) begin
                    bit_counter <= 0;
                    delay_counter <= CLOCK_DIV / 2;
                    state <= STATE_DATA;
                 end
                 else if (bit_counter == 0) begin
                    SCK <= 1;
                    MOSI <= ~read;
                 end
                 else begin
                    SCK <= 1;
                    MOSI <= address[6];
                    address <= {address[5:0], 1'b0};
                 end
              end
           end // case: STATE_ADDRESS
           STATE_DATA: begin
              delay_counter <= delay_counter - 1;
              if (delay_counter == 0) begin
                 delay_counter <= CLOCK_DIV;
                 // Set SCK low, sample bit if we're reading
                 SCK <= 0;
                 if (read) begin
                    data <= {data[6:0], MISO};
                 end
              end // if (delay_counter == 0)
              if (delay_counter == CLOCK_DIV / 2) begin
                 bit_counter <= bit_counter + 1;
                 SCK <= 1;
                 if (bit_counter == 8) begin
                    if (read) begin read_done  <= 1'b1; read_data <= data; end
                    else      write_done <= 1'b1;
                    CS_A <= 0;
                    CS_D <= 0;
                    SCK <= 0;
                    MOSI <= 0;
                    state <= STATE_DELAY;
                 end
                 else if (!read) begin
                    MOSI <= data[7];
                    data <= {data[6:0], 1'b0};
                 end
              end
           end // case: STATE_DATA
           STATE_DELAY: begin
              delay_counter <= delay_counter - 1;
              if (delay_counter == 0) begin
                 state <= STATE_IDLE;
					  data <= 0;
              end
           end
         endcase
      end
   end

endmodule
