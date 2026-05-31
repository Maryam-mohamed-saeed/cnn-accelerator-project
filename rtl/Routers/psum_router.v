module Psum_Router #(
	parameter PSUM_SIZE = 20
) (
	// source ports
	output        						PE_data_in_ready,
	input         						PE_data_in_valid,
	input	signed 	[PSUM_SIZE-1:0] 	PE_data_in,
	
	output        						GLB_data_in_ready,
	input         						GLB_data_in_valid,
	input 	signed	[PSUM_SIZE-1:0] 	GLB_data_in,
	
	output        						north_data_in_ready,
	input         						north_data_in_valid,
	input 	signed 	[PSUM_SIZE-1:0] 	north_data_in,
	
	// destination ports
	input          					GLB_out_ready,
	output   reg     					GLB_out_valid,
	output 	signed 	[PSUM_SIZE-1:0]	GLB_out,

	input         					PE_out_ready,
	output  reg      					PE_out_valid,
	output 	signed 	[PSUM_SIZE-1:0]	PE_out,
	
	input         					south_out_ready,
	output  reg      					south_out_valid,
	output 	signed	[PSUM_SIZE-1:0]	south_out,
	
	// control
	input         	[1:0]			data_in_sel,
	input         	[1:0]			data_out_sel
);
 
// ====================================================================	//
// 						 		Parameters  							//
// ====================================================================	//
// data in direction
localparam FROM_PE = 2'b00;
localparam FROM_NOR = 2'b01;
localparam FROM_GLB = 2'b10;

// data out direction
localparam TO_GLB = 2'b00;
localparam TO_SOU = 2'b01;
localparam TO_PE = 2'b10;

// ====================================================================	//
// 							Internal Signals  							//
// ====================================================================	//
// internal wire
reg internal_data_ready;
reg internal_data_valid;
reg signed [PSUM_SIZE-1:0] internal_data;

// output in_ready signals
assign PE_data_in_ready = (data_in_sel == FROM_PE) & internal_data_ready;
assign north_data_in_ready = (data_in_sel == FROM_NOR) & internal_data_ready;
assign GLB_data_in_ready = (data_in_sel == FROM_GLB) & internal_data_ready;

// output data signals
assign PE_out = internal_data;
assign GLB_out = internal_data;
assign south_out = internal_data;

// output valid signals
always @(*) begin
	GLB_out_valid = 1'b0;
	south_out_valid = 1'b0;
	PE_out_valid = 1'b0;
	case(data_out_sel)
		TO_GLB: begin
			GLB_out_valid = internal_data_valid;
		end
		TO_SOU: begin
			south_out_valid = internal_data_valid;
		end
		TO_PE: begin
			PE_out_valid = internal_data_valid;
		end
		default: begin
		end
	endcase
end

// internal signals logic
always @(*) begin
	internal_data_ready = 1'b0;
	case(data_out_sel)
		TO_GLB: begin
			internal_data_ready = GLB_out_ready;
		end
		TO_SOU: begin
			internal_data_ready = south_out_ready;
		end
		TO_PE: begin
			internal_data_ready = PE_out_ready;
		end
		default: begin
			internal_data_ready = 1'b0;
		end
	endcase
end

always@(*) begin
	internal_data_valid = 1'b0;
	case(data_in_sel)
		FROM_PE: internal_data_valid = PE_data_in_valid;
		FROM_GLB: internal_data_valid = GLB_data_in_valid;
		FROM_NOR: internal_data_valid = north_data_in_valid;
		default : internal_data_valid = 1'b0;
	endcase
end

always@(*) begin
	internal_data = 'd0;
	case(data_in_sel)
		FROM_PE: internal_data = PE_data_in;
		FROM_GLB: internal_data = GLB_data_in;
		FROM_NOR: internal_data = north_data_in;
		default : internal_data = 'd0;
	endcase
end

endmodule