// ====================================================================================================== //
// This module is weight router.
// weight router module is pure circuit switching (MUX).
// 3 weight ports in GLB connect to 3 PE in PE clusteer (one-to-one row) through weight routers.
// There are 2 ports(horiz, PE & GLB) in this module.
// This module contains 3 types of internal signals, internal_data, internal_data_valid, internal_data_ready.
// There 2 control signals from upper module, data_in_sel, data_out_sel, which can control the switching mode.
// data_in_sel and data_out_sel with valid and ready protocol, would estabalish 3-way handshake.
// 
// For data signals,  one large MUX deals 2 ports input data  signals and use data_in_sel  to determine internal_data.
// For valid signals, one large MUX deals 2 ports input valid signals and use data_in_sel  to determine internal_valid.
// For ready signals, one large MUX deals 2 ports input ready signals and use data_out_sel to determine internal_ready.
//  
// data  out signals are connected directly to internal_data.
// valid out signals are determine by a MUX with data_out_sel control.
// ready out signals are determine by a MUX with data_in_sel control.
// 
// In weight router, input signals are always sent to PE.
// ====================================================================================================== //

// ====================================================================================================== //
// Inputs:
// Set the required source address_valid and data_valid to 1
// Set ALL DESTINATIONS address_ready and data_ready ALWAYS TO 1

// Outputs:
// Only the required destination(s) should have their address_valid and data_valid = 1
// Only the required source should have its address_ready and data_ready = 1
// ====================================================================================================== //

module Weight_Router #(
	parameter WEIGHT_SIZE = 8
) (
//******************** Control Signals ****************************
	input         data_in_sel,				// which input source is selected
	input         [1:0] data_out_sel,	// which output destination is selected

//******************** Source Ports ****************************
	// GLB Source
	input         GLB_data_in_valid,		// GLB has valid weight data
	input  [WEIGHT_SIZE-1:0] GLB_data_in,	// input weight data sent from GLB  
	output        GLB_data_in_ready,		// Router tells GLB it's ready to accept the weight data (If data_in_sel != GLB → ready = 0)

	// Horizontal Source (From Left PE)
	input         horiz_data_in_valid,		// Left PE has valid weight data
	input  [WEIGHT_SIZE-1:0] horiz_data_in,	// input weight data sent from left PE  
	output        horiz_data_in_ready,		// Router tells left PE it's ready to accept the weight data (If data_in_sel != HORIZ → ready = 0)

//********************* Destination Ports ***************************
	// PE0 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        PE_0_data_out_valid,		// output weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] PE_0_data_out,	// output weight data received by the PE  

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        PE_1_data_out_valid,		// output weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] PE_1_data_out,	// output weight data received by the PE  

	// PE2 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        PE_2_data_out_valid,		// output weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] PE_2_data_out,	// output weight data received by the PE  
	
	// Horizantal Destination (HOR_CAST) (To Right PE)
	input         horiz_data_out_ready,		// Right PE is ready to receive weight data (always set to 1 during horizontal cast)
	output        horiz_data_out_valid,		// output weight data received by the right PE is valid (If data_out_sel != HOR_CAST → valid = 0)
	output [WEIGHT_SIZE-1:0] horiz_data_out	// output encoded weight data received by the right PE  
);

// ====================================================================	//
// 						 		Parameters  							//
// ====================================================================	//
// data out direction
localparam [1:0] PE0 	= 'd0;
localparam [1:0] PE1 	= 'd1;
localparam [1:0] PE2 	= 'd2;
localparam [1:0] HOR_CAST = 'd3;

// data in direction
localparam GLB   	= 1'b0;
localparam HORIZ	= 1'b1;

// ====================================================================	//
// 						 		Wires  									//
// ====================================================================	//
// internal signals
// destinations
wire 					internal_data_ready = (data_out_sel == HOR_CAST)? horiz_data_out_ready : 1'b1;
// sources
wire 					internal_data_valid = (data_in_sel == HORIZ)? horiz_data_in_valid : GLB_data_in_valid;
wire [WEIGHT_SIZE-1:0]	internal_data = (data_in_sel == HORIZ)? horiz_data_in : GLB_data_in;

// ====================================================================	//
// 						 		Combination  							//
// ====================================================================	//
// in ready switching
assign GLB_data_in_ready 		= (data_in_sel == GLB)	 & internal_data_ready;
assign horiz_data_in_ready 		= (data_in_sel == HORIZ) & internal_data_ready;

// data out switching			
assign PE_0_data_out_valid 		= (data_out_sel == PE0) && internal_data_valid;
assign PE_0_data_out = internal_data;

assign PE_1_data_out_valid 		= (data_out_sel == PE1) && internal_data_valid;
assign PE_1_data_out = internal_data;

assign PE_2_data_out_valid 		= (data_out_sel == PE2) && internal_data_valid;
assign PE_2_data_out = internal_data;

assign horiz_data_out_valid 	= (data_out_sel == HOR_CAST) & internal_data_valid;
assign horiz_data_out = internal_data;

endmodule