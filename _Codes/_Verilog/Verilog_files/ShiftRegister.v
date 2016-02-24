/**
 * Asynchronous parallel input, serial out shift register
 */
module ShiftRegister
  #(
    parameter MAX_LENGTH = 32,
    parameter COUNTER_WIDTH = 5
    )
   (
   input                     shift_clk, 
   input                     reset,
   input                     enable,

   input [COUNTER_WIDTH-1:0] length, 
   input [MAX_LENGTH-1:0]    data,
   
   output reg                out
    );
   
   reg [MAX_LENGTH-1:0]      shift_data;
   reg [COUNTER_WIDTH-1:0]   shift_counter;
   reg                       is_shifting;
   
   always @ (posedge shift_clk) begin
      if (reset) begin
         out <= 1'b0;
         is_shifting <= 1'b0;
      end
      else begin
         if (!is_shifting && enable) begin
            shift_data <= data;
            shift_counter <= length - 1;
            is_shifting <= 1'b1;
         end
         else if (is_shifting) begin
            if (!enable) begin
               is_shifting <= 1'b0;
               out <= 1'b0;
            end
            else begin
               // Output the MSB
               out <= shift_data[MAX_LENGTH-1];
               // Shift left
               shift_data <= {shift_data[MAX_LENGTH-2:0], 1'b0};
               // Reset shift register to original input at the end
               if (shift_counter == 0) begin
                  shift_data <= data;
                  shift_counter <= length-1;
               end
               else begin
                  shift_counter <= shift_counter - 1;
               end
            end // else: !if(!enable)
         end // if (is_shifting)
      end // else: !if(reset)
   end // always @ (posedge shift_clk)
   
endmodule
