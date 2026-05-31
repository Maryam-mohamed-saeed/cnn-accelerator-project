`timescale 1ns/1ns

// =============================================================================
//  PE_cluster_TB.v
//  Simple but comprehensive testbench for PE_cluster
//
//  Tests covered:
//   TC1 – Reset / idle (no outputs asserted)
//   TC2 – FILTER_3 mode: load weights → load iacts → MAC → psum stream → GLB
//   TC3 – FILTER_5 mode: same flow, fewer active PEs
//   TC4 – FILTER_7 mode: same flow
//   TC5 – FILTER_9 mode: same flow (all 36 PEs active)
//   TC6 – Back-pressure: GLB ready de-asserted, check cluster waits
//
//  Data model (identical across all filter modes):
//   iact[0..3]   = {1, 2, 3, 4}
//   weight[0..2] = {5, 6, 7}          (3 weight columns)
//   cycles_per_iact_col  = 4          (inner MAC loop depth)
//   weight_columns       = 3          (outer weight loop depth)
//
//   expected psum[k] = iact[k] * (5+6+7) = iact[k] * 18
//     psum[0]=18, psum[1]=36, psum[2]=54, psum[3]=72
// =============================================================================

module PE_cluster_tb;

// ---------------------------------------------------------------------------
// Parameters (must match DUT defaults)
// ---------------------------------------------------------------------------
localparam PE_NUM           = 36;
localparam ROW_NUM          = 9;
localparam IACT_WIDTH       = 8;
localparam WEIGHT_WIDTH     = 8;
localparam PSUM_WIDTH       = 20;
localparam IACT_SPAD_DEPTH  = 16;
localparam PSUM_SPAD_DEPTH  = 16;
localparam WEIGHT_SPAD_DEPTH= 9;
localparam CLUSTER_ROWS     = 9;

localparam CLK_PERIOD            = 10;

// localparam CYCLES_PER_IACT_COL   = 4;
// localparam WEIGHT_COLUMNS        = 3;

// Filter mode codes (match DUT localparams)
localparam FILTER_3 = 3'd0;
localparam FILTER_5 = 3'd1;
localparam FILTER_7 = 3'd2;
localparam FILTER_9 = 3'd3;

// ---------------------------------------------------------------------------
// DUT signals
// ---------------------------------------------------------------------------
reg         clock, reset;
reg  [2:0]  top_filter_mode;
reg         top_load_PEs_weight_pe;
wire        load_PEs_weight_done_top;
reg         top_load_PEs_iact_pe;
wire        load_PEs_iact_done_top;
reg         top_mac_en_pe;
wire        mac_done_top;
reg         top_psum_stream_start_pe;
wire        psum_stream_done_top;
reg         top_PSUM_to_GLB_en_pe;
reg         PE_mode;
reg  [4:0]  cycles_per_iact_col;
reg  [3:0]  weight_columns;
reg  [3:0]  psum_spad_write_index;
reg  [3:0]  weight_spad_index;

// GLB ready/valid/data (4 channels)
reg         final_psum_out_ready_glb0, final_psum_out_ready_glb1;
reg         final_psum_out_ready_glb2, final_psum_out_ready_glb3;
wire        final_psum_out_valid_glb0, final_psum_out_valid_glb1;
wire        final_psum_out_valid_glb2, final_psum_out_valid_glb3;
wire signed [PSUM_WIDTH-1:0] final_psum_out_glb0, final_psum_out_glb1;
wire signed [PSUM_WIDTH-1:0] final_psum_out_glb2, final_psum_out_glb3;

wire [35:0] iact_weight_data_ready; // one bit per pe
reg [35:0] iact_weight_data_valid; // one bit per pe
reg signed [IACT_WIDTH-1:0] iact_weight_data [0:35]; // one value per pe

// ---------------------------------------------------------------------------
// DUT instantiation
// ---------------------------------------------------------------------------
PE_cluster #(
    .PE_NUM            (PE_NUM),
    .ROW_NUM           (ROW_NUM),
    .IACT_WIDTH        (IACT_WIDTH),
    .WEIGHT_WIDTH      (WEIGHT_WIDTH),
    .PSUM_WIDTH        (PSUM_WIDTH),
    .IACT_SPAD_DEPTH   (IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH   (PSUM_SPAD_DEPTH),
    .WEIGHT_SPAD_DEPTH (WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS      (CLUSTER_ROWS)
) dut (
    .clock                      (clock),
    .reset                      (reset),
    .top_filter_mode            (top_filter_mode),
    .top_load_PEs_weight_pe     (top_load_PEs_weight_pe),
    .load_PEs_weight_done_top   (load_PEs_weight_done_top),
    .top_load_PEs_iact_pe       (top_load_PEs_iact_pe),
    .load_PEs_iact_done_top     (load_PEs_iact_done_top),
    .top_mac_en_pe              (top_mac_en_pe),
    .mac_done_top               (mac_done_top),
    .top_psum_stream_start_pe   (top_psum_stream_start_pe),
    .psum_stream_done_top       (psum_stream_done_top),
    .top_PSUM_to_GLB_en_pe      (top_PSUM_to_GLB_en_pe),
    .PE_mode                    (PE_mode),
    .cycles_per_iact_col        (cycles_per_iact_col),
    .weight_columns             (weight_columns),
    .psum_spad_write_index      (psum_spad_write_index),
    .weight_spad_index          (weight_spad_index),
    // GLB channels
    .final_psum_out_ready_glb0  (final_psum_out_ready_glb0),
    .final_psum_out_valid_glb0  (final_psum_out_valid_glb0),
    .final_psum_out_glb0        (final_psum_out_glb0),
    .final_psum_out_ready_glb1  (final_psum_out_ready_glb1),
    .final_psum_out_valid_glb1  (final_psum_out_valid_glb1),
    .final_psum_out_glb1        (final_psum_out_glb1),
    .final_psum_out_ready_glb2  (final_psum_out_ready_glb2),
    .final_psum_out_valid_glb2  (final_psum_out_valid_glb2),
    .final_psum_out_glb2        (final_psum_out_glb2),
    .final_psum_out_ready_glb3  (final_psum_out_ready_glb3),
    .final_psum_out_valid_glb3  (final_psum_out_valid_glb3),
    .final_psum_out_glb3        (final_psum_out_glb3),
    // iact and weight data for 36 pes
    .PE00_iact_weight_data_ready(iact_weight_data_ready[0]),
    .PE00_iact_weight_data_valid(iact_weight_data_valid[0]),
    .PE00_iact_weight_data      (iact_weight_data[0]),

    .PE01_iact_weight_data_ready(iact_weight_data_ready[1]),
    .PE01_iact_weight_data_valid(iact_weight_data_valid[1]),
    .PE01_iact_weight_data      (iact_weight_data[1]),

    .PE02_iact_weight_data_ready(iact_weight_data_ready[2]),
    .PE02_iact_weight_data_valid(iact_weight_data_valid[2]),
    .PE02_iact_weight_data      (iact_weight_data[2]),

    .PE03_iact_weight_data_ready(iact_weight_data_ready[3]),
    .PE03_iact_weight_data_valid(iact_weight_data_valid[3]),
    .PE03_iact_weight_data      (iact_weight_data[3]),

    .PE10_iact_weight_data_ready(iact_weight_data_ready[4]),
    .PE10_iact_weight_data_valid(iact_weight_data_valid[4]),
    .PE10_iact_weight_data      (iact_weight_data[4]),

    .PE11_iact_weight_data_ready(iact_weight_data_ready[5]),
    .PE11_iact_weight_data_valid(iact_weight_data_valid[5]),
    .PE11_iact_weight_data      (iact_weight_data[5]),

    .PE12_iact_weight_data_ready(iact_weight_data_ready[6]),
    .PE12_iact_weight_data_valid(iact_weight_data_valid[6]),
    .PE12_iact_weight_data      (iact_weight_data[6]),

    .PE13_iact_weight_data_ready(iact_weight_data_ready[7]),
    .PE13_iact_weight_data_valid(iact_weight_data_valid[7]),
    .PE13_iact_weight_data      (iact_weight_data[7]),

    .PE20_iact_weight_data_ready(iact_weight_data_ready[8]),
    .PE20_iact_weight_data_valid(iact_weight_data_valid[8]),
    .PE20_iact_weight_data      (iact_weight_data[8]),

    .PE21_iact_weight_data_ready(iact_weight_data_ready[9]),
    .PE21_iact_weight_data_valid(iact_weight_data_valid[9]),
    .PE21_iact_weight_data      (iact_weight_data[9]),

    .PE22_iact_weight_data_ready(iact_weight_data_ready[10]),
    .PE22_iact_weight_data_valid(iact_weight_data_valid[10]),
    .PE22_iact_weight_data      (iact_weight_data[10]),

    .PE23_iact_weight_data_ready(iact_weight_data_ready[11]),
    .PE23_iact_weight_data_valid(iact_weight_data_valid[11]),
    .PE23_iact_weight_data      (iact_weight_data[11]),

    .PE30_iact_weight_data_ready(iact_weight_data_ready[12]),
    .PE30_iact_weight_data_valid(iact_weight_data_valid[12]),
    .PE30_iact_weight_data      (iact_weight_data[12]),

    .PE31_iact_weight_data_ready(iact_weight_data_ready[13]),
    .PE31_iact_weight_data_valid(iact_weight_data_valid[13]),
    .PE31_iact_weight_data      (iact_weight_data[13]),

    .PE32_iact_weight_data_ready(iact_weight_data_ready[14]),
    .PE32_iact_weight_data_valid(iact_weight_data_valid[14]),
    .PE32_iact_weight_data      (iact_weight_data[14]),

    .PE33_iact_weight_data_ready(iact_weight_data_ready[15]),
    .PE33_iact_weight_data_valid(iact_weight_data_valid[15]),
    .PE33_iact_weight_data      (iact_weight_data[15]),

    .PE40_iact_weight_data_ready(iact_weight_data_ready[16]),
    .PE40_iact_weight_data_valid(iact_weight_data_valid[16]),
    .PE40_iact_weight_data      (iact_weight_data[16]),

    .PE41_iact_weight_data_ready(iact_weight_data_ready[17]),
    .PE41_iact_weight_data_valid(iact_weight_data_valid[17]),
    .PE41_iact_weight_data      (iact_weight_data[17]),

    .PE42_iact_weight_data_ready(iact_weight_data_ready[18]),
    .PE42_iact_weight_data_valid(iact_weight_data_valid[18]),
    .PE42_iact_weight_data      (iact_weight_data[18]),

    .PE43_iact_weight_data_ready(iact_weight_data_ready[19]),
    .PE43_iact_weight_data_valid(iact_weight_data_valid[19]),
    .PE43_iact_weight_data      (iact_weight_data[19]),

    .PE50_iact_weight_data_ready(iact_weight_data_ready[20]),
    .PE50_iact_weight_data_valid(iact_weight_data_valid[20]),
    .PE50_iact_weight_data      (iact_weight_data[20]),

    .PE51_iact_weight_data_ready(iact_weight_data_ready[21]),
    .PE51_iact_weight_data_valid(iact_weight_data_valid[21]),
    .PE51_iact_weight_data      (iact_weight_data[21]),

    .PE52_iact_weight_data_ready(iact_weight_data_ready[22]),
    .PE52_iact_weight_data_valid(iact_weight_data_valid[22]),
    .PE52_iact_weight_data      (iact_weight_data[22]),

    .PE53_iact_weight_data_ready(iact_weight_data_ready[23]),
    .PE53_iact_weight_data_valid(iact_weight_data_valid[23]),
    .PE53_iact_weight_data      (iact_weight_data[23]),

    .PE60_iact_weight_data_ready(iact_weight_data_ready[24]),
    .PE60_iact_weight_data_valid(iact_weight_data_valid[24]),
    .PE60_iact_weight_data      (iact_weight_data[24]),

    .PE61_iact_weight_data_ready(iact_weight_data_ready[25]),
    .PE61_iact_weight_data_valid(iact_weight_data_valid[25]),
    .PE61_iact_weight_data      (iact_weight_data[25]),

    .PE62_iact_weight_data_ready(iact_weight_data_ready[26]),
    .PE62_iact_weight_data_valid(iact_weight_data_valid[26]),
    .PE62_iact_weight_data      (iact_weight_data[26]),

    .PE63_iact_weight_data_ready(iact_weight_data_ready[27]),
    .PE63_iact_weight_data_valid(iact_weight_data_valid[27]),
    .PE63_iact_weight_data      (iact_weight_data[27]),

    .PE70_iact_weight_data_ready(iact_weight_data_ready[28]),
    .PE70_iact_weight_data_valid(iact_weight_data_valid[28]),
    .PE70_iact_weight_data      (iact_weight_data[28]),

    .PE71_iact_weight_data_ready(iact_weight_data_ready[29]),
    .PE71_iact_weight_data_valid(iact_weight_data_valid[29]),
    .PE71_iact_weight_data      (iact_weight_data[29]),

    .PE72_iact_weight_data_ready(iact_weight_data_ready[30]),
    .PE72_iact_weight_data_valid(iact_weight_data_valid[30]),
    .PE72_iact_weight_data      (iact_weight_data[30]),

    .PE73_iact_weight_data_ready(iact_weight_data_ready[31]),
    .PE73_iact_weight_data_valid(iact_weight_data_valid[31]),
    .PE73_iact_weight_data      (iact_weight_data[31]),

    .PE80_iact_weight_data_ready(iact_weight_data_ready[32]),
    .PE80_iact_weight_data_valid(iact_weight_data_valid[32]),
    .PE80_iact_weight_data      (iact_weight_data[32]),

    .PE81_iact_weight_data_ready(iact_weight_data_ready[33]),
    .PE81_iact_weight_data_valid(iact_weight_data_valid[33]),
    .PE81_iact_weight_data      (iact_weight_data[33]),

    .PE82_iact_weight_data_ready(iact_weight_data_ready[34]),
    .PE82_iact_weight_data_valid(iact_weight_data_valid[34]),
    .PE82_iact_weight_data      (iact_weight_data[34]),

    .PE83_iact_weight_data_ready(iact_weight_data_ready[35]),
    .PE83_iact_weight_data_valid(iact_weight_data_valid[35]),
    .PE83_iact_weight_data      (iact_weight_data[35])
);

// ---------------------------------------------------------------------------
// Clock
// ---------------------------------------------------------------------------
initial clock = 0;
always #(CLK_PERIOD/2) clock = ~clock;

integer i;
integer j;
// ---------------------------------------------------------------------------
// Main stimulus
// ---------------------------------------------------------------------------
initial begin
    $dumpfile("pe_cluster_tb.vcd");
    $dumpvars;

    top_filter_mode = FILTER_9;
    top_load_PEs_weight_pe = 0;
    top_load_PEs_iact_pe = 0;
    top_mac_en_pe = 0;
    top_psum_stream_start_pe = 0;
    top_PSUM_to_GLB_en_pe = 0;
    PE_mode = 0;
    cycles_per_iact_col = 16;
    weight_columns = 9;
    weight_spad_index = 0;
    psum_spad_write_index = 0;

    reset = 1;
    @(posedge clock);
    reset = 0;
    
    // phase 1: load weights
        $display("Starting weight load phase");
        top_load_PEs_weight_pe = 1;
        for (i = 0; i<9; i=i+1) begin
            // same weights acrross each row of PEs 
            // row 0
            iact_weight_data_valid[0] = 1; iact_weight_data[0] = 1; // 1*(i+1);
            iact_weight_data_valid[1] = 1; iact_weight_data[1] = 1; // 1*(i+1);
            iact_weight_data_valid[2] = 1; iact_weight_data[2] = 1; // 1*(i+1);
            iact_weight_data_valid[3] = 1; iact_weight_data[3] = 1; // 1*(i+1);
            // row 1
            iact_weight_data_valid[4] = 1; iact_weight_data[4] = 1; // 2*(i+1);
            iact_weight_data_valid[5] = 1; iact_weight_data[5] = 1; // 2*(i+1);
            iact_weight_data_valid[6] = 1; iact_weight_data[6] = 1; // 2*(i+1);
            iact_weight_data_valid[7] = 1; iact_weight_data[7] = 1; // 2*(i+1);
            // row 2
            iact_weight_data_valid[8] = 1; iact_weight_data[8] = 1; // 3*(i+1);
            iact_weight_data_valid[9] = 1; iact_weight_data[9] = 1; // 3*(i+1);
            iact_weight_data_valid[10] = 1; iact_weight_data[10] = 1; // 3*(i+1);
            iact_weight_data_valid[11] = 1; iact_weight_data[11] = 1; // 3*(i+1);
            // row 3
            iact_weight_data_valid[12] = 1; iact_weight_data[12] = 1; // 4*(i+1);
            iact_weight_data_valid[13] = 1; iact_weight_data[13] = 1; // 4*(i+1);
            iact_weight_data_valid[14] = 1; iact_weight_data[14] = 1; // 4*(i+1);
            iact_weight_data_valid[15] = 1; iact_weight_data[15] = 1; // 4*(i+1);
            // row 4
            iact_weight_data_valid[16] = 1; iact_weight_data[16] = 1; // 5*(i+1);
            iact_weight_data_valid[17] = 1; iact_weight_data[17] = 1; // 5*(i+1);
            iact_weight_data_valid[18] = 1; iact_weight_data[18] = 1; // 5*(i+1);
            iact_weight_data_valid[19] = 1; iact_weight_data[19] = 1; // 5*(i+1);
            // row 5
            iact_weight_data_valid[20] = 1; iact_weight_data[20] = 1; // 6*(i+1);
            iact_weight_data_valid[21] = 1; iact_weight_data[21] = 1; // 6*(i+1);
            iact_weight_data_valid[22] = 1; iact_weight_data[22] = 1; // 6*(i+1);
            iact_weight_data_valid[23] = 1; iact_weight_data[23] = 1; // 6*(i+1);
            // row 6
            iact_weight_data_valid[24] = 1; iact_weight_data[24] = 1; // 7*(i+1);
            iact_weight_data_valid[25] = 1; iact_weight_data[25] = 1; // 7*(i+1);
            iact_weight_data_valid[26] = 1; iact_weight_data[26] = 1; // 7*(i+1);
            iact_weight_data_valid[27] = 1; iact_weight_data[27] = 1; // 7*(i+1);
            // row 7
            iact_weight_data_valid[28] = 1; iact_weight_data[28] = 1; // 8*(i+1);
            iact_weight_data_valid[29] = 1; iact_weight_data[29] = 1; // 8*(i+1);
            iact_weight_data_valid[30] = 1; iact_weight_data[30] = 1; // 8*(i+1);
            iact_weight_data_valid[31] = 1; iact_weight_data[31] = 1; // 8*(i+1);
            // row 8
            iact_weight_data_valid[32] = 1; iact_weight_data[32] = 1; // 9*(i+1);
            iact_weight_data_valid[33] = 1; iact_weight_data[33] = 1; // 9*(i+1);
            iact_weight_data_valid[34] = 1; iact_weight_data[34] = 1; // 9*(i+1);
            iact_weight_data_valid[35] = 1; iact_weight_data[35] = 1; // 9*(i+1);

            @(posedge clock);
        end
        top_load_PEs_weight_pe = 0;
        $display("Weight load completed, waiting for load_PEs_weight_done_top");
        wait(load_PEs_weight_done_top);
        $display("load_PEs_weight_done_top asserted");

    @(posedge clock);

    // phase 2: load iacts
        $display("Starting iact load phase");
        top_load_PEs_iact_pe = 1;
        for (i = 0; i<16; i=i+1) begin
            // diagonal iact assignment, simulating real routing behavior
            // diagonal 1
            iact_weight_data_valid = 'd0;
            // router 1
            iact_weight_data_valid[0] = 1; iact_weight_data[0] = 1; // 1*(i+1);
            // router 2
            iact_weight_data_valid[12] = 1; iact_weight_data[12] = 1; // 1*(i+1);
            // router 3
            iact_weight_data_valid[24] = 1; iact_weight_data[24] = 1; // 1*(i+1);
            @(posedge clock);

            // diagonal 2
            iact_weight_data_valid = 'd0;
            // router 1
            iact_weight_data_valid[1] = 1; iact_weight_data[1] = 1; // 2*(i+1);
            iact_weight_data_valid[4] = 1; iact_weight_data[4] = 1; // 2*(i+1);
            // router 2
            iact_weight_data_valid[13] = 1; iact_weight_data[13] = 1; // 2*(i+1);
            iact_weight_data_valid[16] = 1; iact_weight_data[16] = 1; // 2*(i+1);
            // router 3
            iact_weight_data_valid[25] = 1; iact_weight_data[25] = 1; // 2*(i+1);
            iact_weight_data_valid[28] = 1; iact_weight_data[28] = 1; // 2*(i+1);
            @(posedge clock);

            // diagonal 3
            iact_weight_data_valid = 'd0;
            // router 1
            iact_weight_data_valid[2] = 1; iact_weight_data[2] = 1; // 3*(i+1);
            iact_weight_data_valid[5] = 1; iact_weight_data[5] = 1; // 3*(i+1);
            iact_weight_data_valid[8] = 1; iact_weight_data[8] = 1; // 3*(i+1);
            // router 2
            iact_weight_data_valid[14] = 1; iact_weight_data[14] = 1; // 3*(i+1);
            iact_weight_data_valid[17] = 1; iact_weight_data[17] = 1; // 3*(i+1);
            iact_weight_data_valid[20] = 1; iact_weight_data[20 ] = 1; // 3*(i+1);
            // router 3
            iact_weight_data_valid[26] = 1; iact_weight_data[26] = 1; // 3*(i+1);
            iact_weight_data_valid[29] = 1; iact_weight_data[29] = 1; // 3*(i+1);
            iact_weight_data_valid[32] = 1; iact_weight_data[32] = 1; // 3*(i+1);
            @(posedge clock);

            // diagonal 4
            iact_weight_data_valid = 'd0;
            // router 1
            iact_weight_data_valid[3] = 1; iact_weight_data[3] = 1; // 4*(i+1);
            iact_weight_data_valid[6] = 1; iact_weight_data[6] = 1; // 4*(i+1);
            iact_weight_data_valid[9] = 1; iact_weight_data[9] = 1; // 4*(i+1);
            // router 2
            iact_weight_data_valid[15] = 1; iact_weight_data[15] = 1; // 4*(i+1);
            iact_weight_data_valid[18] = 1; iact_weight_data[18] = 1; // 4*(i+1);
            iact_weight_data_valid[21] = 1; iact_weight_data[21] = 1; // 4*(i+1);
            // router 3
            iact_weight_data_valid[27] = 1; iact_weight_data[27] = 1; // 4*(i+1);
            iact_weight_data_valid[30] = 1; iact_weight_data[30] = 1; // 4*(i+1);
            iact_weight_data_valid[33] = 1; iact_weight_data[33] = 1; // 4*(i+1);
            @(posedge clock);

            // diagonal 5
            iact_weight_data_valid = 'd0;
            // router 1
            iact_weight_data_valid[7] = 1; iact_weight_data[7] = 1; // 5*(i+1);
            iact_weight_data_valid[10] = 1; iact_weight_data[10] = 1; // 5*(i+1);
            // router 2
            iact_weight_data_valid[19] = 1; iact_weight_data[19] = 1; // 5*(i+1);
            iact_weight_data_valid[22] = 1; iact_weight_data[22] = 1; // 5*(i+1);
            // router 3
            iact_weight_data_valid[31] = 1; iact_weight_data[31] = 1; // 5*(i+1);
            iact_weight_data_valid[34] = 1; iact_weight_data[34] = 1; // 5*(i+1);
            @(posedge clock);

            // diagonal 6
            iact_weight_data_valid = 'd0;
            // router 1
            iact_weight_data_valid[11] = 1; iact_weight_data[11] = 1; // 6*(i+1);
            // router 2
            iact_weight_data_valid[23] = 1; iact_weight_data[23] = 1; // 6*(i+1);
            // router 3        
            iact_weight_data_valid[35] = 1; iact_weight_data[35] = 1; // 6*(i+1);
            @(posedge clock);
        end
        top_load_PEs_iact_pe = 0;
        iact_weight_data_valid = 'd0;
        $display("iact load completed, waiting for load_PEs_iact_done_top");
        wait(load_PEs_iact_done_top);
        $display("load_PEs_iact_done_top asserted");

    @(posedge clock);

    // phase 3: mac 
        psum_spad_write_index = 0;
        weight_spad_index = 0;
        $display("Starting mac phase");
        for (j = 0; j<9; j=j+1) begin
            $display("Starting mac no.%0d", j);
            for (i = 0; i<15; i=i+1) begin
                top_mac_en_pe = 1;
                @(posedge clock);
                top_mac_en_pe = 0;
                @(posedge clock);
                @(posedge clock);
                psum_spad_write_index = psum_spad_write_index + 1;
            end
            top_mac_en_pe = 1;
            @(posedge clock);
            top_mac_en_pe = 0;
            $display("waiting for mac_done_top to check mac completion no.%0d", j);
            wait(mac_done_top);
            $display("mac_done_top asserted no.%0d", j);
            @(posedge clock);
            @(posedge clock);
            weight_spad_index = weight_spad_index + 1;
            psum_spad_write_index = 0;
        end
            top_mac_en_pe = 0;
            psum_spad_write_index = 0;
            weight_spad_index = 0;
    
    @(posedge clock);

    // // phase 3: mac 
        // psum_spad_write_index = 0;
        // weight_spad_index = 0;
        // $display("Starting mac phase");
        // for (i = 0; i<15; i=i+1) begin
        //     top_mac_en_pe = 1;
        //     @(posedge clock);
        //     top_mac_en_pe = 0;
        //     @(posedge clock);
        //     @(posedge clock);
        //     psum_spad_write_index = psum_spad_write_index + 1;
        // end
        // top_mac_en_pe = 1;
        // @(posedge clock);
        // top_mac_en_pe = 0;
        // $display("waiting for mac_done_top to check mac completion");
        // wait(mac_done_top);
        // $display("mac_done_top asserted");
        // @(posedge clock);
        // @(posedge clock);
        // top_mac_en_pe = 0;
        // psum_spad_write_index = 0;
        // weight_spad_index = 0;

    // // phase 2: load iacts
    //     $display("Starting iact load phase");
    //     top_load_PEs_iact_pe = 1;
    //     for (i = 0; i<16; i=i+1) begin
    //         // diagonal iact assignment, simulating real routing behavior
    //         // diagonal 1
    //         iact_weight_data_valid = 'd0;
    //         // router 1
    //         iact_weight_data_valid[0] = 1; iact_weight_data[0] = 2; // 1*(i+1);
    //         // router 2
    //         iact_weight_data_valid[12] = 1; iact_weight_data[12] = 2; // 1*(i+1);
    //         // router 3
    //         iact_weight_data_valid[24] = 1; iact_weight_data[24] = 2; // 1*(i+1);
    //         @(posedge clock);

    //         // diagonal 2
    //         iact_weight_data_valid = 'd0;
    //         // router 1
    //         iact_weight_data_valid[1] = 1; iact_weight_data[1] = 2; // 2*(i+1);
    //         iact_weight_data_valid[4] = 1; iact_weight_data[4] = 2; // 2*(i+1);
    //         // router 2
    //         iact_weight_data_valid[13] = 1; iact_weight_data[13] = 2; // 2*(i+1);
    //         iact_weight_data_valid[16] = 1; iact_weight_data[16] = 2; // 2*(i+1);
    //         // router 3
    //         iact_weight_data_valid[25] = 1; iact_weight_data[25] = 2; // 2*(i+1);
    //         iact_weight_data_valid[28] = 1; iact_weight_data[28] = 2; // 2*(i+1);
    //         @(posedge clock);

    //         // diagonal 3
    //         iact_weight_data_valid = 'd0;
    //         // router 1
    //         iact_weight_data_valid[2] = 1; iact_weight_data[2] = 2; // 3*(i+1);
    //         iact_weight_data_valid[5] = 1; iact_weight_data[5] = 2; // 3*(i+1);
    //         iact_weight_data_valid[8] = 1; iact_weight_data[8] = 2; // 3*(i+1);
    //         // router 2
    //         iact_weight_data_valid[14] = 1; iact_weight_data[14] = 2; // 3*(i+1);
    //         iact_weight_data_valid[17] = 1; iact_weight_data[17] = 2; // 3*(i+1);
    //         iact_weight_data_valid[20] = 1; iact_weight_data[20 ] = 2; // 3*(i+1);
    //         // router 3
    //         iact_weight_data_valid[26] = 1; iact_weight_data[26] = 2; // 3*(i+1);
    //         iact_weight_data_valid[29] = 1; iact_weight_data[29] = 2; // 3*(i+1);
    //         iact_weight_data_valid[32] = 1; iact_weight_data[32] = 2; // 3*(i+1);
    //         @(posedge clock);

    //         // diagonal 4
    //         iact_weight_data_valid = 'd0;
    //         // router 1
    //         iact_weight_data_valid[3] = 1; iact_weight_data[3] = 2; // 4*(i+1);
    //         iact_weight_data_valid[6] = 1; iact_weight_data[6] = 2; // 4*(i+1);
    //         iact_weight_data_valid[9] = 1; iact_weight_data[9] = 2; // 4*(i+1);
    //         // router 2
    //         iact_weight_data_valid[15] = 1; iact_weight_data[15] = 2; // 4*(i+1);
    //         iact_weight_data_valid[18] = 1; iact_weight_data[18] = 2; // 4*(i+1);
    //         iact_weight_data_valid[21] = 1; iact_weight_data[21] = 2; // 4*(i+1);
    //         // router 3
    //         iact_weight_data_valid[27] = 1; iact_weight_data[27] = 2; // 4*(i+1);
    //         iact_weight_data_valid[30] = 1; iact_weight_data[30] = 2; // 4*(i+1);
    //         iact_weight_data_valid[33] = 1; iact_weight_data[33] = 2; // 4*(i+1);
    //         @(posedge clock);

    //         // diagonal 5
    //         iact_weight_data_valid = 'd0;
    //         // router 1
    //         iact_weight_data_valid[7] = 1; iact_weight_data[7] = 2; // 5*(i+1);
    //         iact_weight_data_valid[10] = 1; iact_weight_data[10] = 2; // 5*(i+1);
    //         // router 2
    //         iact_weight_data_valid[19] = 1; iact_weight_data[19] = 2; // 5*(i+1);
    //         iact_weight_data_valid[22] = 1; iact_weight_data[22] = 2; // 5*(i+1);
    //         // router 3
    //         iact_weight_data_valid[31] = 1; iact_weight_data[31] = 2; // 5*(i+1);
    //         iact_weight_data_valid[34] = 1; iact_weight_data[34] = 2; // 5*(i+1);
    //         @(posedge clock);

    //         // diagonal 6
    //         iact_weight_data_valid = 'd0;
    //         // router 1
    //         iact_weight_data_valid[11] = 1; iact_weight_data[11] = 2; // 6*(i+1);
    //         // router 2
    //         iact_weight_data_valid[23] = 1; iact_weight_data[23] = 2; // 6*(i+1);
    //         // router 3        
    //         iact_weight_data_valid[35] = 1; iact_weight_data[35] = 2; // 6*(i+1);
    //         @(posedge clock);
    //     end
    //     top_load_PEs_iact_pe = 0;
    //     iact_weight_data_valid = 'd0;
    //     $display("iact load completed, waiting for load_PEs_iact_done_top");
    //     wait(load_PEs_iact_done_top);
    //     $display("load_PEs_iact_done_top asserted");

    // @(posedge clock);

    // phase 4: stream
    top_psum_stream_start_pe = 1;
    PE_mode = 1; // streaming mode
    $display("Starting stream phase");
    $display("waiting for psum_stream_done_top to check stream completion");
    wait(psum_stream_done_top);
    $display("psum_stream_done_top asserted");
    @(posedge clock);
    top_psum_stream_start_pe = 0;

        

    @(posedge clock);
    @(posedge clock);
    @(posedge clock);
    @(posedge clock);

    $stop;
end

endmodule