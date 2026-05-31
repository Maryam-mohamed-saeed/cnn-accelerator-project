/* counter hayetsafar */
/* el heta bta3et el iact start addres*/

/*
    switch case for diff filter sizes and input fmap sizes
*/
/*
shelna el  //unique_values_per_cluster_per_cycle = 'd8;
la2naha el mafrood input mn el top
            FILTER_SIZE_5: begin
                //unique_values_per_cluster_per_cycle = 'd8;
                
            FILTER_SIZE_3: begin
                //unique_values_per_cluster_per_cycle = 'd4;




*/
module cluster_group_controller #(
    parameter IACT_SRAM_ADDRESS_SIZE = 8,
    parameter WEIGHT_SRAM_ADDRESS_SIZE = 7,
    parameter WRITE_COUNT_SIZE = 5,
    parameter WEIGHT_SIZE = 8
) (
    input clock,
    input reset,

    input [2:0] top_filter_mode, 
    input [2:0] top_input_mode,
    input turn_on, // turn on entire operation 
    // Convolution cofigurations
    input [4:0] cycles_per_iact_col,  // number of needed cycles to process 1 input fmap column with 1 filter column
    input [4:0] unique_values_per_cluster_per_cycle,   // number of unique values per cluster per cycle to process 1 input fmap column with 1 filter column
    input [7:0] unique_values_per_cluster,    // number of unique values per cluster for cycles to process 1 input fmap column with 1 filter column
    input [6:0] weight_values_per_filter,  // number of weight values per filter 
    input [3:0] weight_columns, // number of weight columns per filter

    // iact GLB controls 
    output reg                                  iact_GLB_write_en,
    output reg [IACT_SRAM_ADDRESS_SIZE-1 : 0]	iact_GLB_start_write_address,
    input      [IACT_SRAM_ADDRESS_SIZE-1 : 0]	iact_GLB_write_address,	
    input                                       iact_GLB_write_done,

    output reg                                  iact_GLB_read_en,
    output reg [IACT_SRAM_ADDRESS_SIZE-1 : 0]   iact_GLB_start_read_address_port0,
    output reg [IACT_SRAM_ADDRESS_SIZE-1 : 0]   iact_GLB_start_read_address_port1,
    output reg [IACT_SRAM_ADDRESS_SIZE-1 : 0]   iact_GLB_start_read_address_port2,
    // to request for loading next input fmap columns from bram to glb
    output reg iact_column_done_flag,

    // weight GLB controls 
	output									weight_GLB_data_in_ready,
	input	 								weight_GLB_data_in_valid,
	input		[WEIGHT_SIZE-1 : 0]			weight_GLB_data_in,

	input									weight_GLB_data_out_ready_0,
	output	 								weight_GLB_data_out_valid_0,
	output	 	[WEIGHT_SIZE-1 : 0]			weight_GLB_data_out_0,

	input									weight_GLB_data_out_ready_1,
	output	 								weight_GLB_data_out_valid_1,
	output	 	[WEIGHT_SIZE-1 : 0]			weight_GLB_data_out_1,

	input									weight_GLB_data_out_ready_2,
	output	 								weight_GLB_data_out_valid_2,
	output	 	[WEIGHT_SIZE-1 : 0]			weight_GLB_data_out_2,
	
	output reg									weight_GLB_write_en, // enables write
	output reg	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_write_addr, // initial write address
	input	 									weight_GLB_write_done, // flags the end of write operation

	output reg									weight_GLB_read_en_0, // enables read from port 0
	output reg	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_read_addr_0, // initial read address
	input	 									weight_GLB_read_done_0, // flags the end of read operation

	output reg									weight_GLB_read_en_1, // enables read from port 1
	output reg	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_read_addr_1, // initial read address
	input	 									weight_GLB_read_done_1, // flags the end of read operation

	output reg									weight_GLB_read_en_2, // enables read from port 2
	output reg	[WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	weight_GLB_read_addr_2, // initial read address
	input	 									weight_GLB_read_done_2, // flags the end of read operation


    // psum GLB controls 
    output reg                                  psum_GLB_write_en,
    output reg [WEIGHT_SRAM_ADDRESS_SIZE-1 : 0]	psum_GLB_start_address,
    input                                       psum_GLB_write_done,
    input      [WEIGHT_SRAM_ADDRESS_SIZE-1 : 0] psum_GLB_write_address,
    output reg [WRITE_COUNT_SIZE-1 : 0]         psum_GLB_depth,

    // iact router 0 controls 
    output  reg    [1:0]           iact_router0_data_in_sel,
	output  reg    [2:0]           iact_router0_data_out_sel,
	// UNICAST
	output  reg    [3:0]           iact_router0_PE_sel,
	// MULTICAST
	output  reg    [11:0]          iact_router0_PE_choice,
	output  reg    [2:0]           iact_router0_Multicast_mode,

    // iact router 1 controls 
    output  reg    [1:0]           iact_router1_data_in_sel,
	output  reg    [2:0]           iact_router1_data_out_sel,
	// UNICAST
	output  reg    [3:0]           iact_router1_PE_sel,
	// MULTICAST
	output  reg    [11:0]          iact_router1_PE_choice,
	output  reg    [2:0]           iact_router1_Multicast_mode,

    // iact router 2 controls 
    output  reg    [1:0]           iact_router2_data_in_sel,
	output  reg    [2:0]           iact_router2_data_out_sel,
	// UNICAST
	output  reg    [3:0]           iact_router2_PE_sel,
	// MULTICAST
	output  reg    [11:0]          iact_router2_PE_choice,
	output  reg    [2:0]           iact_router2_Multicast_mode,

// weight router 0  
    output  reg    weight_router0_data_in_sel, 
	output  reg    [1:0] weight_router0_data_out_sel,

    // ----------Source Ports -----------
	// GLB Source
	input         weight_0_GLB_data_in_valid,   // GLB has valid encoded weight data
	input  [WEIGHT_SIZE-1:0] weight_0_GLB_data_in,       // input encoded weight data sent from GLB 
	output        weight_0_GLB_data_in_ready,     // Router tells GLB it's ready to accept the encoded weight data (If data_in_sel != GLB → ready = 0)

	// Horizontal Source (From Left PE)
	input         weight_0_horiz_data_in_valid,     // Left PE has valid encoded weight data
	input  [WEIGHT_SIZE-1:0] weight_0_horiz_data_in,      // input encoded weight data sent from left PE 
	output        weight_0_horiz_data_in_ready,   // Router tells left PE it's ready to accept the encoded weight data (If data_in_sel != HORIZ → ready = 0)

	// ----------Destination Ports -----------
	// PE0 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_0_PE_0_data_out_valid,      // output encoded weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] weight_0_PE_0_data_out,       // output encoded weight data received by the PE 

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_0_PE_1_data_out_valid,      // output encoded weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] weight_0_PE_1_data_out,       // output encoded weight data received by the PE 

	// PE2 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_0_PE_2_data_out_valid,      // output encoded weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] weight_0_PE_2_data_out,       // output encoded weight data received by the PE 
	
	// Horizantal Destination (HOR_CAST) (To Right PE)
	input         weight_0_horiz_data_out_ready,      // Right PE is ready to receive encoded weight data (always set to 1 during horizontal cast)
	output        weight_0_horiz_data_out_valid,      // output encoded weight data received by the right PE is valid (If data_out_sel != HOR_CAST → valid = 0)
	output [WEIGHT_SIZE-1:0] weight_0_horiz_data_out,    // output encoded weight data received by the right PE 


// weight router 1  
    output  reg    weight_router1_data_in_sel, 
	output  reg    [1:0] weight_router1_data_out_sel,

// ----------Source Ports -----------
	// GLB Source
	input         weight_1_GLB_data_in_valid,   // GLB has valid encoded weight data
	input  [WEIGHT_SIZE-1:0] weight_1_GLB_data_in,       // input encoded weight data sent from GLB 
	output        weight_1_GLB_data_in_ready,     // Router tells GLB it's ready to accept the encoded weight data (If data_in_sel != GLB → ready = 0)

	// Horizontal Source (From Left PE)
	input         weight_1_horiz_data_in_valid,     // Left PE has valid encoded weight data
	input  [WEIGHT_SIZE-1:0] weight_1_horiz_data_in,      // input encoded weight data sent from left PE 
	output        weight_1_horiz_data_in_ready,   // Router tells left PE it's ready to accept the encoded weight data (If data_in_sel != HORIZ → ready = 0)

	// ----------Destination Ports -----------
	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_1_PE_0_data_out_valid,      // output encoded weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] weight_1_PE_0_data_out,       // output encoded weight data received by the PE 

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_1_PE_1_data_out_valid,      // output encoded weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] weight_1_PE_1_data_out,       // output encoded weight data received by the PE 

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_1_PE_2_data_out_valid,      // output encoded weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] weight_1_PE_2_data_out,       // output encoded weight data received by the PE 
	
	// Horizantal Destination (HOR_CAST) (To Right PE)
	input         weight_1_horiz_data_out_ready,      // Right PE is ready to receive encoded weight data (always set to 1 during horizontal cast)
	output        weight_1_horiz_data_out_valid,      // output encoded weight data received by the right PE is valid (If data_out_sel != HOR_CAST → valid = 0)
	output [WEIGHT_SIZE-1:0] weight_1_horiz_data_out,    // output encoded weight data received by the right PE 


// weight router 2 
    output  reg    weight_router2_data_in_sel, 
	output  reg    [1:0] weight_router2_data_out_sel,

    // ----------Source Ports -----------
	// GLB Source
	input         weight_2_GLB_data_in_valid,   // GLB has valid encoded weight data
	input  [WEIGHT_SIZE-1:0] weight_2_GLB_data_in,       // input encoded weight data sent from GLB 
	output        weight_2_GLB_data_in_ready,     // Router tells GLB it's ready to accept the encoded weight data (If data_in_sel != GLB → ready = 0)

	// Horizontal Source (From Left PE)
	input         weight_2_horiz_data_in_valid,     // Left PE has valid encoded weight data
	input  [WEIGHT_SIZE-1:0] weight_2_horiz_data_in,      // input encoded weight data sent from left PE 
	output        weight_2_horiz_data_in_ready,   // Router tells left PE it's ready to accept the encoded weight data (If data_in_sel != HORIZ → ready = 0)

	// ----------Destination Ports -----------
	// PE0 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_2_PE_0_data_out_valid,      // output encoded weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] weight_2_PE_0_data_out,       // output encoded weight data received by the PE 

	// PE1 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_2_PE_1_data_out_valid,      // output encoded weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] weight_2_PE_1_data_out,       // output encoded weight data received by the PE 

	// PE2 (There are no ready signals as the pe ALWAYS receives the weight no matter what so it's always assumed to be ready)
	output        weight_2_PE_2_data_out_valid,      // output encoded weight data received by the PE is valid
	output [WEIGHT_SIZE-1:0] weight_2_PE_2_data_out,       // output encoded weight data received by the PE 

	// Horizantal Destination (HOR_CAST) (To Right PE)
	input         weight_2_horiz_data_out_ready,      // Right PE is ready to receive encoded weight data (always set to 1 during horizontal cast)
	output        weight_2_horiz_data_out_valid,      // output encoded weight data received by the right PE is valid (If data_out_sel != HOR_CAST → valid = 0)
	output [WEIGHT_SIZE-1:0] weight_2_horiz_data_out,    // output encoded weight data received by the right PE 


    // psum router 0 controls
    output reg      psum_router0_data_in_sel, 
	output reg      psum_router0_data_out_sel,

    // psum router 1 controls
    output reg      psum_router1_data_in_sel, 
	output reg      psum_router1_data_out_sel,

    // psum router 2 controls  
    output reg      psum_router2_data_in_sel, 
	output reg      psum_router2_data_out_sel,

    // psum router 3 controls  
    output reg      psum_router3_data_in_sel, 
	output reg      psum_router3_data_out_sel,
    
    // PE cluster controls
    output  reg    load_PEs_weight,
    input          load_PEs_weight_done,
    output  reg    load_PEs_iact,
    input          load_PEs_iact_done,
    output  reg    mac_start,
    input          mac_done,
    output  reg    psum_stream_start,
    input          psum_stream_done,
    output  reg    read_PEs_psum,

    output reg [3:0] mac_done_counter,  // counts cycles_per_iact_col, index to spad
    output reg [3:0] weight_column_counter, // counts weight_columns

    input          iact_next_ofmap_col, // from top

    //from cluster group controller to pe cluster to determine pe mod is it mac or stream
    output reg PE_mode
);

// ====================================================================	//
// 			    	Top filter modes (top_filter_mode) 			        //
// ====================================================================	//
    localparam FILTER_SIZE_9 = 3'b000;
    localparam FILTER_SIZE_7 = 3'b001;
    localparam FILTER_SIZE_5 = 3'b010;
    localparam FILTER_SIZE_3 = 3'b011;

// ====================================================================	//
// 			    	Top input modes (top_input_mode)                    //
// ====================================================================	//
    localparam INPUT_SIZE_1024 = 3'b000;
    localparam INPUT_SIZE_512  = 3'b001;
    localparam INPUT_SIZE_256  = 3'b010;  
    localparam INPUT_SIZE_128  = 3'b011;
    localparam INPUT_SIZE_64   = 3'b100;
    localparam INPUT_SIZE_32   = 3'b101;

// ====================================================================	//
// 			    	Iact router parameters                              //
// ====================================================================	//
    // data out direction
        localparam IACT_ROUTER_DATA_OUT_UNICAST     = 3'b000;
        localparam IACT_ROUTER_DATA_OUT_MULT_CAST 	= 3'b001;
        localparam IACT_ROUTER_DATA_OUT_HOR_CAST    = 3'b010;
        localparam IACT_ROUTER_DATA_OUT_VER_CAST    = 3'b011;
        localparam IACT_ROUTER_DATA_OUT_BROADCAST 	= 3'b100;

    // Multicast modes
        localparam MULTICAST_1 = 3'd1;
        localparam MULTICAST_2 = 3'd2;
        localparam MULTICAST_3 = 3'd3;
        localparam MULTICAST_4 = 3'd4;
        localparam MULTICAST_5 = 3'd5;
        localparam MULTICAST_6 = 3'd6;

    // PE indices 
        localparam PE0  = 4'd0;
        localparam PE1  = 4'd1;
        localparam PE2  = 4'd2;
        localparam PE3  = 4'd3;
        localparam PE4  = 4'd4;
        localparam PE5  = 4'd5;
        localparam PE6  = 4'd6;
        localparam PE7  = 4'd7;
        localparam PE8  = 4'd8;
        localparam PE9  = 4'd9;
        localparam PE10 = 4'd10;
        localparam PE11 = 4'd11;

    // data in direction
        localparam IACT_ROUTER_DATA_IN_GLB = 2'b00;
        localparam IACT_ROUTER_DATA_IN_NORTH = 2'b01;
        localparam IACT_ROUTER_DATA_IN__SOUTH = 2'b10;
        localparam IACT_ROUTER_DATA_IN__HORIZ = 2'b11;

// ====================================================================	//
// 			    	Weight router parameters  					    	//
// ====================================================================	//
    // data out direction
        localparam [1:0] WEIGHT_ROUTER_DATA_OUT_PE0  = 'd0;
        localparam [1:0] WEIGHT_ROUTER_DATA_OUT_PE1  = 'd1;
        localparam [1:0] WEIGHT_ROUTER_DATA_OUT_PE2  = 'd2;
        localparam [1:0] WEIGHT_ROUTER_DATA_OUT_HOR_CAST  = 'd3;

    // data in direction
        localparam WEIGHT_ROUTER_DATA_IN_GLB   	= 1'b0;
        localparam WEIGHT_ROUTER_DATA_IN_HORIZ	= 1'b1;


// ====================================================================	//
// 			    		Internal signals and buses  					//
// ====================================================================	//
    


// counters



//reg [3:0] weight_column_counter; // counts weight_columns
reg weight_column_done_flag;

reg psum_stream_done_reg;

reg PE_mac_start;

reg [3:0] iact_load_counter;

reg route_inc_flag;
// ====================================================================	//
// 			    		FSM states                   					//
// ====================================================================	//
    localparam IDLE = 'd0;
    localparam GLB_LOAD_ADDRESS = 'd1; // initially send start write address to weight and iact GLB 
    localparam GLB_LOAD = 'd2; // initially load iact and weight GLB

    localparam GLB_WEIGHT_READ_ADDRESS = 'd3; // send start read address to weight GLB 
    localparam ROUTE_WEIGHT_1 = 'd4; // read weights from GLB, route them to PEs
    localparam ROUTE_WEIGHT_2 = 'd5; // read weights from GLB, route them to PEs
    localparam ROUTE_WEIGHT_3 = 'd6; // read weights from GLB, route them to PEs


    localparam GLB_IACT_READ_ADDRESS = 'd7; // send start read address to iact GLB 
    localparam ROUTE_IACT_1 = 'd8; // read iacts from GLB, route them to PEs (mode 1)
    localparam ROUTE_IACT_2 = 'd9; // read iacts from GLB, route them to PEs (mode 2)
    localparam ROUTE_IACT_3 = 'd10; // read iacts from GLB, route them to PEs (mode 3)
    localparam ROUTE_IACT_4 = 'd11; // read iacts from GLB, route them to PEs (mode 4)
    localparam ROUTE_IACT_5 = 'd12; // read iacts from GLB, route them to PEs (mode 5)
    localparam ROUTE_IACT_6 = 'd13; // read iacts from GLB, route them to PEs (mode 6)

    localparam IACT_GLB_LOAD_ADDRESS = 'd14; // send start write address to iact GLB 
    localparam PE_START_IACT_GLB_LOAD = 'd15; // PE starts operation for 1 input fmap col & load iact GLB (new iacts) while PE is working

    localparam PSUM_STREAM = 'd16;  // PEs stream psums to the PE beneath every filter window
    localparam PSUM_GLB_LOAD_ADDRESS = 'd17; // send start write address to psum GLB 
    localparam PSUM_GLB_LOAD = 'd18; // load psum GLB (with output fmap col)

    localparam IACT_GLB_LOAD_ADDRESS_NEXT_OFMAP_COL = 'd19; // send start write address to iact GLB 
    localparam IACT_GLB_LOAD_NEXT_OFMAP_COL = 'd20; // load iact GLB (with new input fmap col that serves new output fmap col

reg [4:0] current_state, next_state;


// Register for weight_GLB_write_done
reg weight_GLB_write_done_reg;

always @ (posedge weight_GLB_write_done) begin
if (reset) begin
    weight_GLB_write_done_reg <= 'd0;
end

else begin
    weight_GLB_write_done_reg <= weight_GLB_write_done;
end
end



always @(posedge clock) begin
    if(reset) begin
        current_state <= IDLE;
    end
    else begin
        current_state <= next_state;
    end
end

// next state logic 
always @(*) begin
    case(current_state)
        IDLE: begin
            $display("in IDLE");
            if (turn_on) begin
                next_state = GLB_LOAD_ADDRESS; 
            end
            else if (iact_next_ofmap_col) begin
                next_state = IACT_GLB_LOAD_ADDRESS_NEXT_OFMAP_COL;
            end
            else begin
                next_state = IDLE;
            end
        end
        GLB_LOAD_ADDRESS: begin
            next_state = GLB_LOAD;
        end

        //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ///////// nghayar el condition yb2a kda -> if(iact_GLB_write_done && weight_GLB_write_done)
        ///////// iact_GB_write_done and weight_GLB_write_done are high for only 1 cycle
        ///////// momkn mn gher ma ne check el weight_GLB_write_done 3shan 3o2bal ma el iact_GLB_write_done ttrefe3 hykon el weight_GLB_write_done nezlet
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        //////// write_done is high 1 CYCLE AFTER write_en is lowered/////////////////////////////
        ////////////////////////////////////////////////////////////////////////////////////////////
        GLB_LOAD: begin
            $display("in GLB_LOAD");
            if ((iact_GLB_write_done) & (weight_GLB_write_done_reg)) begin
                weight_GLB_write_done_reg = 'd0;
                next_state = GLB_WEIGHT_READ_ADDRESS;
            end
            else begin
                next_state = GLB_LOAD;
            end
        end


        ////////////////////////////////////////////////// what the fuck /////////////////////////////////////////////////
        GLB_WEIGHT_READ_ADDRESS: begin
            $display("in GLB_WEIGHT_READ_ADDRESS");
            next_state = ROUTE_WEIGHT_1;
        end
        ROUTE_WEIGHT_1: begin
            $display("in ROUTE_WEIGHT_1");
            next_state = ROUTE_WEIGHT_2;    
        end
        ROUTE_WEIGHT_2: begin
            $display("in ROUTE_WEIGHT_2");
            next_state = ROUTE_WEIGHT_3;    
        end
        ROUTE_WEIGHT_3: begin
            $display("in ROUTE_WEIGHT_3");
            if (load_PEs_weight_done) begin
                next_state = GLB_IACT_READ_ADDRESS;
            end
            else begin
                next_state = ROUTE_WEIGHT_1;/////// or GLB_WEIGHT_READ_ADDRESS
            end   
        end     
        ////////////////////////////////////////////////////////////////////////////////////////////////////////



        GLB_IACT_READ_ADDRESS: begin
            $display("in GLB_IACT_READ_ADDRESS");
            next_state = ROUTE_IACT_1;
        end
        ROUTE_IACT_1: begin
            $display("in ROUTE_IACT_1");
            next_state = ROUTE_IACT_2;
        end
        ROUTE_IACT_2: begin
            $display("in ROUTE_IACT_2");
            next_state = ROUTE_IACT_3;
        end
        ROUTE_IACT_3: begin
            $display("in ROUTE_IACT_3");
            next_state = ROUTE_IACT_4;
        end
        ROUTE_IACT_4: begin
            $display("in ROUTE_IACT_4");
            next_state = ROUTE_IACT_5;
        end
        ROUTE_IACT_5: begin
            $display("in ROUTE_IACT_5");
            next_state = ROUTE_IACT_6;
        end
        ROUTE_IACT_6: begin
            $display("in ROUTE_IACT_6");
            if (load_PEs_iact_done) begin
                next_state = IACT_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = GLB_IACT_READ_ADDRESS;
            end
        end
        IACT_GLB_LOAD_ADDRESS: begin
            $display("in IACT_GLB_LOAD_ADDRESS");
            next_state = PE_START_IACT_GLB_LOAD;
        end
        PE_START_IACT_GLB_LOAD: begin
            $display("in PE_START_IACT_GLB_LOAD");
            if (iact_column_done_flag && (iact_GLB_write_address == unique_values_per_cluster)) begin // check the address cond ( == iact_GLB_start_write_address ??)
                // we need to make the pe wait till glb loads
                // new col weight and iacts
                if (weight_column_done_flag) begin
                    next_state = PSUM_STREAM;
                end
                else begin
                    next_state = GLB_IACT_READ_ADDRESS;
                end 
            end
            else begin
                next_state = PE_START_IACT_GLB_LOAD;
            end
        end
        PSUM_STREAM: begin
            $display("in PSUM_STREAM");
            if (psum_stream_done) begin
                next_state = PSUM_GLB_LOAD_ADDRESS;
            end
            else begin
                next_state = PSUM_STREAM;
            end 
        end
        PSUM_GLB_LOAD_ADDRESS: begin
            $display("in PSUM_GLB_LOAD_ADDRESS");
            next_state = PSUM_GLB_LOAD;
        end
        PSUM_GLB_LOAD: begin
            $display("in PSUM_GLB_LOAD");
            if(psum_stream_done_reg && psum_GLB_write_done) begin
                next_state = IDLE;
            end
            else begin
                next_state = PSUM_GLB_LOAD;
            end 
        end
        IACT_GLB_LOAD_ADDRESS_NEXT_OFMAP_COL: begin
            $display("in IACT_GLB_LOAD_ADDRESS_NEXT_OFMAP_COL");
            next_state = IACT_GLB_LOAD_NEXT_OFMAP_COL;
        end
        IACT_GLB_LOAD_NEXT_OFMAP_COL: begin
            $display("in IACT_GLB_LOAD_NEXT_OFMAP_COL");
            if (iact_GLB_write_address == unique_values_per_cluster) begin
                next_state = GLB_IACT_READ_ADDRESS;
            end
            else begin
                next_state = IACT_GLB_LOAD_NEXT_OFMAP_COL;
            end
        end

    endcase
end

always @(*) begin
    // Initiallized
        iact_GLB_write_en =0;
        iact_GLB_start_write_address=0;
        weight_GLB_write_en = 0;
        weight_GLB_write_addr = 0;
        weight_GLB_read_en_0 = 0;
        weight_GLB_read_en_1 = 0;
        weight_GLB_read_en_2 = 0;
        weight_GLB_read_addr_0 = 0;
        weight_GLB_read_addr_1 = 0;
        weight_GLB_read_addr_2 = 0;
        psum_GLB_write_en = 0;
        psum_GLB_start_address=0;
        iact_router0_data_in_sel=0;
        iact_router0_data_out_sel=0;
        iact_router0_PE_sel=0;
        iact_router0_PE_choice=0;
        iact_router0_Multicast_mode=0;
        iact_router1_data_in_sel=0;
        iact_router1_data_out_sel=0;
        iact_router1_PE_sel=0;
        iact_router1_PE_choice=0;
        iact_router1_Multicast_mode=0;
        iact_router2_data_in_sel=0;
        iact_router2_data_out_sel=0;
        iact_router2_PE_sel=0;
        iact_router2_PE_choice=0;
        iact_router2_Multicast_mode=0;
        load_PEs_weight = 0;
        load_PEs_iact = 0;
        mac_start = 0;
        PE_mode = 0;
        psum_GLB_depth = 0;
        read_PEs_psum = 0;
        weight_router0_data_in_sel = 0;
        weight_router1_data_in_sel = 0;
        weight_router2_data_in_sel = 0;
        //weight_router3_data_in_sel = 0;
        weight_router0_data_out_sel = 0;
        weight_router1_data_out_sel = 0;
        weight_router2_data_out_sel = 0;
        //weight_router3_data_out_sel = 0;
        route_inc_flag = 0;
    case(current_state)
        IDLE: begin

        end
        GLB_LOAD_ADDRESS: begin
            iact_GLB_start_write_address = 'd0;
            weight_GLB_write_addr = 'd0;       
            end
        GLB_LOAD: begin
            iact_GLB_write_en = 1'b1;
            weight_GLB_write_en = 1'b1;
        end
        GLB_WEIGHT_READ_ADDRESS: begin
           weight_GLB_read_addr_0 = 'd0;
           weight_GLB_read_addr_1 = 'd0;
           weight_GLB_read_addr_2 = 'd0;
           load_PEs_weight = 'd1;
        end

        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        /////////////////////////// each weight router (0, 1, 2) is connected to its respective weight glb port (0, 1, 2) ONLYYYYYY////////////////////////
        //////////////////////////////////////////////( FEL INSTATNTIATIONS) //////////////////////////////////////////////////////////////////////////
        ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        ROUTE_WEIGHT_1: begin
            weight_GLB_read_en_0 = 'd1;  
            weight_GLB_read_en_1 = 'd1;            
            weight_GLB_read_en_2 = 'd1;  
          
            weight_router0_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;
            weight_router0_data_out_sel = WEIGHT_ROUTER_DATA_OUT_PE0;

            weight_router1_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;
            weight_router1_data_out_sel = WEIGHT_ROUTER_DATA_OUT_PE0;

            weight_router2_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;
            weight_router2_data_out_sel = WEIGHT_ROUTER_DATA_OUT_PE0;

        end
        ROUTE_WEIGHT_2: begin
            weight_GLB_read_en_0 = 'd1;  
            weight_GLB_read_en_1 = 'd1;            
            weight_GLB_read_en_2 = 'd1; 

            weight_router0_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;
            weight_router0_data_out_sel = WEIGHT_ROUTER_DATA_OUT_PE1;

            weight_router1_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;
            weight_router1_data_out_sel = WEIGHT_ROUTER_DATA_OUT_PE1;

            weight_router2_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;
            weight_router2_data_out_sel = WEIGHT_ROUTER_DATA_OUT_PE1;
        end
        ROUTE_WEIGHT_3: begin
            weight_GLB_read_en_0 = 'd1;  
            weight_GLB_read_en_1 = 'd1;            
            weight_GLB_read_en_2 = 'd1;  

            weight_router0_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;
            weight_router0_data_out_sel = WEIGHT_ROUTER_DATA_OUT_PE2;

            weight_router1_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;
            weight_router1_data_out_sel = WEIGHT_ROUTER_DATA_OUT_PE2;

            weight_router2_data_in_sel = WEIGHT_ROUTER_DATA_IN_GLB;
            weight_router2_data_out_sel = WEIGHT_ROUTER_DATA_OUT_PE2;
        end
        
        GLB_IACT_READ_ADDRESS: begin
            case (top_filter_mode)
            FILTER_SIZE_9: begin
                iact_GLB_start_read_address_port0 = iact_load_counter*unique_values_per_cluster_per_cycle; // port0 starts from 0 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port1 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd3; // port1 starts from 3 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port2 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd6; // port1 starts from 6 and increments by unique_values_per_cluster_per_cycle
            end
            FILTER_SIZE_7: begin
                iact_GLB_start_read_address_port0 = iact_load_counter*unique_values_per_cluster_per_cycle; // port0 starts from 0 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port1 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd3; // port1 starts from 3 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port2 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd6; // port1 starts from 6 and increments by unique_values_per_cluster_per_cycle
            end
            FILTER_SIZE_5: begin
                //unique_values_per_cluster_per_cycle = 'd8;
                iact_GLB_start_read_address_port0 = iact_load_counter*unique_values_per_cluster_per_cycle; // port0 starts from 0 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port1 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd3; // port1 starts from 3 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port2 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd6; // port1 starts from 6 and increments by unique_values_per_cluster_per_cycle
            end
            FILTER_SIZE_3: begin
                //unique_values_per_cluster_per_cycle = 'd4;
                iact_GLB_start_read_address_port0 = iact_load_counter*unique_values_per_cluster_per_cycle; // port0 starts from 0 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port1 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd4; // port1 starts from 4 and increments by unique_values_per_cluster_per_cycle
                iact_GLB_start_read_address_port2 = iact_load_counter*unique_values_per_cluster_per_cycle + 'd8; // port1 starts from 8 and increments by unique_values_per_cluster_per_cycle
            end
            endcase

            load_PEs_iact = 'd1;
        end

        ROUTE_IACT_1: begin
            iact_GLB_read_en = 'd1;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0000_0000_0001;
            iact_router0_Multicast_mode = MULTICAST_1;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0000_0000_0001;
            iact_router1_Multicast_mode = MULTICAST_1;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0000_0000_0001;
            iact_router2_Multicast_mode = MULTICAST_1;
        end
        ROUTE_IACT_2: begin
            iact_GLB_read_en = 'd1;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0000_0001_0010;
            iact_router0_Multicast_mode = MULTICAST_2;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0000_0001_0010;
            iact_router1_Multicast_mode = MULTICAST_2;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0000_0001_0010;
            iact_router2_Multicast_mode = MULTICAST_2;
        end
        ROUTE_IACT_3: begin
            iact_GLB_read_en = 'd1;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0001_0010_0100;
            iact_router0_Multicast_mode = MULTICAST_3;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0001_0010_0100;
            iact_router1_Multicast_mode = MULTICAST_3;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0001_0010_0100;
            iact_router2_Multicast_mode = MULTICAST_3;
        end
        ROUTE_IACT_4: begin
            iact_GLB_read_en = 'd1;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0010_0100_1000;
            iact_router0_Multicast_mode = MULTICAST_4;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0010_0100_1000;
            iact_router1_Multicast_mode = MULTICAST_4;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0010_0100_1000;
            iact_router2_Multicast_mode = MULTICAST_4;
        end
        ROUTE_IACT_5: begin
            iact_GLB_read_en = 'd1;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b0100_1000_0000;
            iact_router0_Multicast_mode = MULTICAST_5;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b0100_1000_0000;
            iact_router1_Multicast_mode = MULTICAST_5;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b0100_1000_0000;
            iact_router2_Multicast_mode = MULTICAST_5;
        end
        ROUTE_IACT_6: begin
            iact_GLB_read_en = 'd1;
            iact_router0_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router0_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router0_PE_sel = 0;
            iact_router0_PE_choice = 12'b1000_0000_0000;
            iact_router0_Multicast_mode = MULTICAST_6;

            iact_router1_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router1_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router1_PE_sel = 0;
            iact_router1_PE_choice = 12'b1000_0000_0000;
            iact_router1_Multicast_mode = MULTICAST_6;

            iact_router2_data_in_sel = IACT_ROUTER_DATA_IN_GLB;
            iact_router2_data_out_sel = IACT_ROUTER_DATA_OUT_MULT_CAST;
            iact_router2_PE_sel = 0;
            iact_router2_PE_choice = 12'b1000_0000_0000;
            iact_router2_Multicast_mode = MULTICAST_6;

            route_inc_flag = 1;
        end
        IACT_GLB_LOAD_ADDRESS: begin
            iact_GLB_start_write_address = 'd0; 
        end
        PE_START_IACT_GLB_LOAD: begin
            iact_GLB_start_write_address = 'd0;
            iact_GLB_write_en = 'd1;
            mac_start = 'd1;
            PE_mode = 'd0;
        end
        PSUM_STREAM: begin
            psum_stream_start = 'd1;
            PE_mode = 'd1;
        end
        PSUM_GLB_LOAD_ADDRESS: begin
            psum_GLB_start_address = (weight_column_counter-1) * cycles_per_iact_col; // same for all psum GLBs
            psum_GLB_depth = cycles_per_iact_col;
            read_PEs_psum = 'd1;
        end
        PSUM_GLB_LOAD: begin
            psum_GLB_write_en = 'd1;
            weight_router0_data_in_sel = 'd0;
            weight_router1_data_in_sel = 'd0;
            weight_router2_data_in_sel = 'd0;
           // weight_router3_data_in_sel = 'd0;
            weight_router0_data_out_sel = 'd0;
            weight_router1_data_out_sel = 'd0;
            weight_router2_data_out_sel = 'd0;
            //weight_router3_data_out_sel = 'd0;
        end
        IACT_GLB_LOAD_ADDRESS_NEXT_OFMAP_COL: begin
            iact_GLB_start_write_address = 'd0; 
        end
        IACT_GLB_LOAD_NEXT_OFMAP_COL: begin
            iact_GLB_write_en = 'd1;
        end

    endcase
end


// ====================================================================	//
// 			        	Counters                       					//
// ====================================================================	//
// Counter for the iact address offset
always @(posedge clock) begin
    if (reset) begin
        iact_load_counter <= 1'b0;
    end
    else if (route_inc_flag) begin
        iact_load_counter <= iact_load_counter + 1'b1;
    end
    else if(iact_load_counter == unique_values_per_cluster) begin
        iact_load_counter <= 1'b0;
    end
end

// Counter for iact column (mac cycles)
always @(posedge clock) begin
    if (reset) begin
        mac_done_counter <= 4'b0;
    end
    else if (mac_done == 1'b1 && !iact_column_done_flag) begin
        mac_done_counter <= mac_done_counter + 4'b1;
    end
    else if (iact_column_done_flag) begin
        mac_done_counter <= 4'b0;
    end
end

always @(posedge clock) begin
    if (reset) begin
        iact_column_done_flag <= 1'b0;
    end
    else if (mac_done_counter == cycles_per_iact_col) begin
        iact_column_done_flag <= 1'b1;
    end
    else if(next_state == GLB_IACT_READ_ADDRESS || next_state == PSUM_STREAM) begin
        iact_column_done_flag <= 1'b0;
    end
end

// Counter for weight column
always @(posedge clock) begin
    if (reset) begin
        weight_column_counter <= 4'b0;
    end
    else if (iact_column_done_flag && !weight_column_done_flag) begin
        weight_column_counter <= weight_column_counter + 4'b1;
    end
    else if (weight_column_done_flag) begin
        weight_column_counter <= 4'b0;
    end
end

always @(posedge clock) begin
    if (reset) begin
        weight_column_done_flag <= 1'b0;
    end
    else if (weight_column_counter == weight_columns) begin
        weight_column_done_flag <= 1'b1;
    end
    else if (next_state == PSUM_STREAM) begin
        weight_column_done_flag <= 1'b0;
    end
end
    
endmodule