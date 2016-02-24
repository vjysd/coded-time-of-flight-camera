module PMDTiming
  (
   input 	    clk,
   input 	    reset,

   output reg 	    mod_enable, // Output to enable modulation modules
   input 	    frame_start, // Input to start frame acquisition
   output reg 	    frame_rdy, // Are we ready to capture a new frame?
   output reg [7:0] current_column, // current column of the readout
   output reg [7:0] current_row, // current row of the readout
   output reg 	    sample_pixel, // Signals other circuitry to sample the current pixel
   output reg 	    frame_done, // current frame done
		    
   input [31:0]     integration_time,
   
   output reg 	    RESET_1,
   output reg 	    HOLD,
   output reg 	    START_ROI,
   output reg 	    CLK_ROI,
   input 	    ENABLE_ROI
   );

   reg [4:0]  state; // Internal FSM
   localparam STATE_IDLE        = 4'd0;
   localparam STATE_RESET_1     = 4'd1;
   localparam STATE_RESET_2     = 4'd2;
   localparam STATE_RESET_3     = 4'd3;
   localparam STATE_INTEGRATION_1 = 4'd4;
   localparam STATE_INTEGRATION_2 = 4'd5;
   localparam STATE_INTEGRATION_3 = 4'd6;
   localparam STATE_INTEGRATION_4 = 4'd7;
   localparam STATE_INTEGRATION_5 = 4'd8;
   localparam STATE_READOUT_1     = 4'd9;
   localparam STATE_READOUT_2     = 4'd10;
   localparam STATE_READOUT_3     = 4'd11;
   localparam STATE_COOLDOWN      = 4'd12;

   reg [31:0] counter; // delay counter for various timing parametes
   localparam T_CLK_ROI_PERIOD = 32'd100 / 2;
   localparam T_PIXEL_RESET    = 32'd160 / 2 ; //1.6us
   localparam T_HOLD_RESET    = 32'd21 / 2; //200ns, time between hold and reset changes
   localparam T_HOLD_MOD    =   32'd10 / 2; // 100ns, delay beteween hold and modulation
   localparam T_COOLDOWN    = 32'd1000 / 2; // 10us, delay between readout and next integration

   reg        cycle; // Used for the first column of every readout, which is asserted for two clock cycles

   localparam LAST_COLUMN = 8'd53;
   localparam LAST_ROW    = 8'd119;
	
   
   always @ (posedge clk) begin
      if (reset) begin
         state <= STATE_IDLE;
         sample_pixel <= 0;
         frame_rdy <= 1;   
         frame_done <= 0;
         mod_enable <= 0;
         HOLD <= 1;
         RESET_1 <= 1;
         START_ROI <= 0;
         CLK_ROI <= 0;
      end
      else begin
         case (state)
           STATE_IDLE:
             begin
                if (frame_start) begin
                   state <= STATE_RESET_1;
                   HOLD <= 0;
                   RESET_1 <= 1;
                   frame_rdy <= 0;
                   frame_done <= 0;
                   counter <= T_PIXEL_RESET;
                end
             end
           STATE_RESET_1:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   HOLD <= 1;
                   counter <= T_HOLD_RESET;
                   state <= STATE_RESET_2;
                end
             end
           STATE_RESET_2:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   RESET_1 <= 0;
                   counter <= T_HOLD_RESET;
                   state <= STATE_RESET_3;
                end
             end
           STATE_RESET_3:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   HOLD <= 0;
                   counter <= T_HOLD_MOD;
                   state <= STATE_INTEGRATION_1;
                end
             end
           STATE_INTEGRATION_1:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   mod_enable <= 1;
                   counter <= integration_time;
                   state <= STATE_INTEGRATION_2;
                end
             end
           STATE_INTEGRATION_2:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   mod_enable <= 0;
                   counter <= T_HOLD_MOD;
                   state <= STATE_INTEGRATION_3;
                end
             end
           STATE_INTEGRATION_3:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   HOLD <= 1;
                   counter <= T_HOLD_RESET;
                   state <= STATE_INTEGRATION_4;
                end
             end
           STATE_INTEGRATION_4:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   RESET_1 <= 1;
                   counter <= T_HOLD_RESET;
                   state <= STATE_INTEGRATION_5;
                end
             end
           STATE_INTEGRATION_5:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   START_ROI <= 1;
                   counter <= T_CLK_ROI_PERIOD;
                   state <= STATE_READOUT_1;
                end
             end
           STATE_READOUT_1:
             begin
                counter <= counter - 32'd1;
                if (counter == T_CLK_ROI_PERIOD / 2) begin
                   CLK_ROI <= 1;
                end
                else if (counter == 0) begin
                   CLK_ROI <= 0;
                   START_ROI <= 0;
                   counter <= T_CLK_ROI_PERIOD / 2;
                   state <= STATE_READOUT_2;
                end
             end // case: STATE_READOUT_1
           STATE_READOUT_2:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   CLK_ROI <= 1;
                   current_row <= 0;
                   current_column <= 0;
                   cycle <= 0;
                   state <= STATE_READOUT_3;
                   counter <= T_CLK_ROI_PERIOD;
                end
             end // case: STATE_READOUT_2
           STATE_READOUT_3:
             begin
                sample_pixel <= 0;
                counter <= counter - 32'd1;
                // Make sure to assert sample_pixel only once for each column
                // including the special case first column
                if (counter == T_CLK_ROI_PERIOD / 2) begin
                   CLK_ROI <= 0;
                   if (cycle == 0) begin
                      sample_pixel <= 1;
                   end
                end
                else if (counter == 0) begin
                   // Special case, the first column is asserted for two cycles!
                   if (current_column == 0 && cycle == 0) begin
                      cycle <= 1;
                      counter <= T_CLK_ROI_PERIOD;
                      CLK_ROI <= 1;
                   end
                   else begin
                      cycle <= 0;
                      counter <= T_CLK_ROI_PERIOD;
                      CLK_ROI <= 1;
                      if (current_column == LAST_COLUMN) begin
                         if (current_row == LAST_ROW) begin
                            CLK_ROI <= 0;
                            frame_done <= 1;
                            counter <= T_COOLDOWN;
                            state <= STATE_COOLDOWN;
                         end
                         else begin
                            current_row <= current_row + 8'd1;
                            current_column <= 8'd0;
                         end
                      end // if (current_column == LAST_COLUMN)
                      else begin
                         current_column <= current_column + 8'd1;
                      end
                   end // else: !if(current_column == 0 && cycle == 0)
                end // if (counter == 0)
             end // case: STATE_READOUT_3
           STATE_COOLDOWN:
             begin
                counter <= counter - 32'd1;
                if (counter == 0) begin
                   state <= STATE_IDLE;
                   frame_rdy <= 1;
                end
             end
         endcase
      end
   end

endmodule
  
   
                 
