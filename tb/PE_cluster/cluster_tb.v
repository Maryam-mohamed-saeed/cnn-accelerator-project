`timescale 1ns/1ps

module PE_cluster_tb;

// ============================================================================
// Parameters
// ============================================================================
localparam PE_NUM            = 36;
localparam ROW_NUM           = 9;
localparam IACT_WIDTH        = 8;
localparam WEIGHT_WIDTH      = 8;
localparam PSUM_WIDTH        = 20;
localparam IACT_SPAD_DEPTH   = 16;
localparam PSUM_SPAD_DEPTH   = 16;
localparam WEIGHT_SPAD_DEPTH = 9;
localparam CLUSTER_ROWS      = 9;
localparam CLK_PERIOD        = 10;

// ── Test config ──────────────────────────────────────────────────────────────
// FILTER_3 mode: 3×3 kernel → 9 rows active, 3 weight cols, 4 output channels
// filter_mode encoding: 0=FILTER_3, 1=FILTER_5, 2=FILTER_7, 3=FILTER_9
localparam FILTER_MODE       = 3'd3; // FILTER_9
localparam CYCLES_PER_IACT   = 4;   // iact spad depth / psum slots per PE
localparam WEIGHT_COLS       = 9;   // outer MAC loop (filter size)
localparam NUM_PE_ROWS        = 9;   // active rows for FILTER_9 (rows 0-8)
localparam NUM_PE_COLS        = 4;   // always 4 columns

// ============================================================================
// DUT Ports
// ============================================================================
reg  clock, reset;
reg  [2:0] top_filter_mode;

// cluster-level control (to/from cluster group controller = TB here)
reg  top_load_PEs_weight_pe;
wire load_PEs_weight_done_top;
reg  top_load_PEs_iact_pe;
wire load_PEs_iact_done_top;

reg  top_mac_en_pe;
wire mac_done_top;

reg  top_psum_stream_start_pe;
wire psum_stream_done_top;

reg  top_PSUM_to_GLB_en_pe;
reg  PE_mode;

reg  [4:0] cycles_per_iact_col;
reg  [3:0] weight_columns;
reg  [3:0] psum_spad_write_index; // inner mac counter
reg  [3:0] weight_spad_index;     // outer weight col counter

// GLB psum outputs (4 columns → 4 GLB banks)
reg  final_psum_out_ready_glb0, final_psum_out_ready_glb1;
reg  final_psum_out_ready_glb2, final_psum_out_ready_glb3;
wire final_psum_out_valid_glb0; wire signed [PSUM_WIDTH-1:0] final_psum_out_glb0;
wire final_psum_out_valid_glb1; wire signed [PSUM_WIDTH-1:0] final_psum_out_glb1;
wire final_psum_out_valid_glb2; wire signed [PSUM_WIDTH-1:0] final_psum_out_glb2;
wire final_psum_out_valid_glb3; wire signed [PSUM_WIDTH-1:0] final_psum_out_glb3;

// Per-PE iact/weight data buses (9 rows × 4 cols)
// TB drives each column's bus independently (same data across rows for this test)
reg  [IACT_WIDTH-1:0] col_data   [0:3]; // data currently on each column bus
reg                   col_valid  [0:3]; // valid on each column bus

// Wire up all 36 PE data buses
// Row 0
reg  signed [IACT_WIDTH-1:0] PE00_d, PE01_d, PE02_d, PE03_d;
reg                           PE00_v, PE01_v, PE02_v, PE03_v;
wire                          PE00_ready, PE01_ready, PE02_ready, PE03_ready;
// Row 1
reg  signed [IACT_WIDTH-1:0] PE10_d, PE11_d, PE12_d, PE13_d;
reg                           PE10_v, PE11_v, PE12_v, PE13_v;
wire                          PE10_ready, PE11_ready, PE12_ready, PE13_ready;
// Row 2
reg  signed [IACT_WIDTH-1:0] PE20_d, PE21_d, PE22_d, PE23_d;
reg                           PE20_v, PE21_v, PE22_v, PE23_v;
wire                          PE20_ready, PE21_ready, PE22_ready, PE23_ready;
// Row 3-8 (inactive in FILTER_3 but still connected)
reg  signed [IACT_WIDTH-1:0] PE30_d, PE31_d, PE32_d, PE33_d;
reg                           PE30_v, PE31_v, PE32_v, PE33_v;
wire                          PE30_ready,PE31_ready,PE32_ready,PE33_ready;
reg  signed [IACT_WIDTH-1:0] PE40_d, PE41_d, PE42_d, PE43_d;
reg                           PE40_v, PE41_v, PE42_v, PE43_v;
wire                          PE40_ready,PE41_ready,PE42_ready,PE43_ready;
reg  signed [IACT_WIDTH-1:0] PE50_d, PE51_d, PE52_d, PE53_d;
reg                           PE50_v, PE51_v, PE52_v, PE53_v;
wire                          PE50_ready,PE51_ready,PE52_ready,PE53_ready;
reg  signed [IACT_WIDTH-1:0] PE60_d, PE61_d, PE62_d, PE63_d;
reg                           PE60_v, PE61_v, PE62_v, PE63_v;
wire                          PE60_ready,PE61_ready,PE62_ready,PE63_ready;
reg  signed [IACT_WIDTH-1:0] PE70_d, PE71_d, PE72_d, PE73_d;
reg                           PE70_v, PE71_v, PE72_v, PE73_v;
wire                          PE70_ready,PE71_ready,PE72_ready,PE73_ready;
reg  signed [IACT_WIDTH-1:0] PE80_d, PE81_d, PE82_d, PE83_d;
reg                           PE80_v, PE81_v, PE82_v, PE83_v;
wire                          PE80_ready,PE81_ready,PE82_ready,PE83_ready;

// ============================================================================
// DUT
// ============================================================================
PE_cluster #(
    .PE_NUM(PE_NUM), .ROW_NUM(ROW_NUM),
    .IACT_WIDTH(IACT_WIDTH), .WEIGHT_WIDTH(WEIGHT_WIDTH),
    .PSUM_WIDTH(PSUM_WIDTH), .IACT_SPAD_DEPTH(IACT_SPAD_DEPTH),
    .PSUM_SPAD_DEPTH(PSUM_SPAD_DEPTH), .WEIGHT_SPAD_DEPTH(WEIGHT_SPAD_DEPTH),
    .CLUSTER_ROWS(CLUSTER_ROWS)
) dut (
    .clock(clock), .reset(reset),
    .top_filter_mode(top_filter_mode),

    .top_load_PEs_weight_pe(top_load_PEs_weight_pe),
    .load_PEs_weight_done_top(load_PEs_weight_done_top),
    .top_load_PEs_iact_pe(top_load_PEs_iact_pe),
    .load_PEs_iact_done_top(load_PEs_iact_done_top),

    .top_mac_en_pe(top_mac_en_pe),
    .mac_done_top(mac_done_top),
    .top_psum_stream_start_pe(top_psum_stream_start_pe),
    .psum_stream_done_top(psum_stream_done_top),
    .top_PSUM_to_GLB_en_pe(top_PSUM_to_GLB_en_pe),
    .PE_mode(PE_mode),

    .cycles_per_iact_col(cycles_per_iact_col),
    .weight_columns(weight_columns),
    .psum_spad_write_index(psum_spad_write_index),
    .weight_spad_index(weight_spad_index),

    .final_psum_out_ready_glb0(final_psum_out_ready_glb0),
    .final_psum_out_valid_glb0(final_psum_out_valid_glb0),
    .final_psum_out_glb0(final_psum_out_glb0),
    .final_psum_out_ready_glb1(final_psum_out_ready_glb1),
    .final_psum_out_valid_glb1(final_psum_out_valid_glb1),
    .final_psum_out_glb1(final_psum_out_glb1),
    .final_psum_out_ready_glb2(final_psum_out_ready_glb2),
    .final_psum_out_valid_glb2(final_psum_out_valid_glb2),
    .final_psum_out_glb2(final_psum_out_glb2),
    .final_psum_out_ready_glb3(final_psum_out_ready_glb3),
    .final_psum_out_valid_glb3(final_psum_out_valid_glb3),
    .final_psum_out_glb3(final_psum_out_glb3),

    // Row 0
    .PE00_iact_weight_data_ready(PE00_ready), .PE00_iact_weight_data_valid(PE00_v), .PE00_iact_weight_data(PE00_d),
    .PE01_iact_weight_data_ready(PE01_ready), .PE01_iact_weight_data_valid(PE01_v), .PE01_iact_weight_data(PE01_d),
    .PE02_iact_weight_data_ready(PE02_ready), .PE02_iact_weight_data_valid(PE02_v), .PE02_iact_weight_data(PE02_d),
    .PE03_iact_weight_data_ready(PE03_ready), .PE03_iact_weight_data_valid(PE03_v), .PE03_iact_weight_data(PE03_d),
    // Row 1
    .PE10_iact_weight_data_ready(PE10_ready), .PE10_iact_weight_data_valid(PE10_v), .PE10_iact_weight_data(PE10_d),
    .PE11_iact_weight_data_ready(PE11_ready), .PE11_iact_weight_data_valid(PE11_v), .PE11_iact_weight_data(PE11_d),
    .PE12_iact_weight_data_ready(PE12_ready), .PE12_iact_weight_data_valid(PE12_v), .PE12_iact_weight_data(PE12_d),
    .PE13_iact_weight_data_ready(PE13_ready), .PE13_iact_weight_data_valid(PE13_v), .PE13_iact_weight_data(PE13_d),
    // Row 2
    .PE20_iact_weight_data_ready(PE20_ready), .PE20_iact_weight_data_valid(PE20_v), .PE20_iact_weight_data(PE20_d),
    .PE21_iact_weight_data_ready(PE21_ready), .PE21_iact_weight_data_valid(PE21_v), .PE21_iact_weight_data(PE21_d),
    .PE22_iact_weight_data_ready(PE22_ready), .PE22_iact_weight_data_valid(PE22_v), .PE22_iact_weight_data(PE22_d),
    .PE23_iact_weight_data_ready(PE23_ready), .PE23_iact_weight_data_valid(PE23_v), .PE23_iact_weight_data(PE23_d),
    // Row 3
    .PE30_iact_weight_data_ready(PE30_ready), .PE30_iact_weight_data_valid(PE30_v), .PE30_iact_weight_data(PE30_d),
    .PE31_iact_weight_data_ready(PE31_ready), .PE31_iact_weight_data_valid(PE31_v), .PE31_iact_weight_data(PE31_d),
    .PE32_iact_weight_data_ready(PE32_ready), .PE32_iact_weight_data_valid(PE32_v), .PE32_iact_weight_data(PE32_d),
    .PE33_iact_weight_data_ready(PE33_ready), .PE33_iact_weight_data_valid(PE33_v), .PE33_iact_weight_data(PE33_d),
    // Row 4
    .PE40_iact_weight_data_ready(PE40_ready), .PE40_iact_weight_data_valid(PE40_v), .PE40_iact_weight_data(PE40_d),
    .PE41_iact_weight_data_ready(PE41_ready), .PE41_iact_weight_data_valid(PE41_v), .PE41_iact_weight_data(PE41_d),
    .PE42_iact_weight_data_ready(PE42_ready), .PE42_iact_weight_data_valid(PE42_v), .PE42_iact_weight_data(PE42_d),
    .PE43_iact_weight_data_ready(PE43_ready), .PE43_iact_weight_data_valid(PE43_v), .PE43_iact_weight_data(PE43_d),
    // Row 5
    .PE50_iact_weight_data_ready(PE50_ready), .PE50_iact_weight_data_valid(PE50_v), .PE50_iact_weight_data(PE50_d),
    .PE51_iact_weight_data_ready(PE51_ready), .PE51_iact_weight_data_valid(PE51_v), .PE51_iact_weight_data(PE51_d),
    .PE52_iact_weight_data_ready(PE52_ready), .PE52_iact_weight_data_valid(PE52_v), .PE52_iact_weight_data(PE52_d),
    .PE53_iact_weight_data_ready(PE53_ready), .PE53_iact_weight_data_valid(PE53_v), .PE53_iact_weight_data(PE53_d),
    // Row 6
    .PE60_iact_weight_data_ready(PE60_ready), .PE60_iact_weight_data_valid(PE60_v), .PE60_iact_weight_data(PE60_d),
    .PE61_iact_weight_data_ready(PE61_ready), .PE61_iact_weight_data_valid(PE61_v), .PE61_iact_weight_data(PE61_d),
    .PE62_iact_weight_data_ready(PE62_ready), .PE62_iact_weight_data_valid(PE62_v), .PE62_iact_weight_data(PE62_d),
    .PE63_iact_weight_data_ready(PE63_ready), .PE63_iact_weight_data_valid(PE63_v), .PE63_iact_weight_data(PE63_d),
    // Row 7
    .PE70_iact_weight_data_ready(PE70_ready), .PE70_iact_weight_data_valid(PE70_v), .PE70_iact_weight_data(PE70_d),
    .PE71_iact_weight_data_ready(PE71_ready), .PE71_iact_weight_data_valid(PE71_v), .PE71_iact_weight_data(PE71_d),
    .PE72_iact_weight_data_ready(PE72_ready), .PE72_iact_weight_data_valid(PE72_v), .PE72_iact_weight_data(PE72_d),
    .PE73_iact_weight_data_ready(PE73_ready), .PE73_iact_weight_data_valid(PE73_v), .PE73_iact_weight_data(PE73_d),
    // Row 8
    .PE80_iact_weight_data_ready(PE80_ready), .PE80_iact_weight_data_valid(PE80_v), .PE80_iact_weight_data(PE80_d),
    .PE81_iact_weight_data_ready(PE81_ready), .PE81_iact_weight_data_valid(PE81_v), .PE81_iact_weight_data(PE81_d),
    .PE82_iact_weight_data_ready(PE82_ready), .PE82_iact_weight_data_valid(PE82_v), .PE82_iact_weight_data(PE82_d),
    .PE83_iact_weight_data_ready(PE83_ready), .PE83_iact_weight_data_valid(PE83_v), .PE83_iact_weight_data(PE83_d)
);

// ============================================================================
// Clock
// ============================================================================
initial clock = 0;
always #(CLK_PERIOD/2) clock = ~clock;

// ============================================================================
// Test vectors
// ============================================================================
// Architecture: each ROW gets a DIFFERENT weight (its filter row).
//   row r, col c: weight = weight_vals[r]
// Each PE in the same ROW shares the same weight (broadcast across cols).
// Each PE in the same COL shares the same iact values (broadcast across rows).
//
// FILTER_3 → 3 active rows (rows 0,1,2), 3 weight columns, 4 output channels
//
// iact[k] = {10, 20, 30, 40} for k in 0..3  (same per column)
// weight[r] for row r = {2, 3, 4}  (different per row, same weight_col value)
//   BUT weight_spad_index selects column of the filter, not the row.
//   In this arch each row PE stores ALL filter columns:
//     row 0 stores w[col0][row0], w[col1][row0], w[col2][row0] = 2,3,4
//     row 1 stores w[col0][row1], w[col1][row1], w[col2][row1] = 5,6,7
//     row 2 stores w[col0][row2], w[col1][row2], w[col2][row2] = 8,9,10
//
// Final psum accumulated at the bottom of each column (row 2 for FILTER_3):
//   glb_out[col][iact_slot] = sum over rows of (iact[iact_slot] * weight[row][weight_col])
//   For col 0 (weight_spad_index cycles 0,1,2):
//     psum_col0[k] = iact[k]*(2+3+4) + iact[k]*(5+6+7) + iact[k]*(8+9+10)
//                  = iact[k] * (9 + 18 + 27) = iact[k] * 54
//   psum_col0[0]=540, [1]=1080, [2]=1620, [3]=2160
//
// Note: in the stream phase, the bottom PE (row 2) accumulates psum_in=0
//       (from row0 which gets psum_in=0 from top_psum_stream_start_pe acting as valid signal)
//       then passes result down the chain. GLB receives the chain-accumulated value.

localparam NUM_ROWS_ACTIVE = 9; // FILTER_3

// Weight matrix: weight_mem[row][weight_col]
reg signed [WEIGHT_WIDTH-1:0] weight_mem [0:NUM_ROWS_ACTIVE-1][0:WEIGHT_COLS-1];

// iact values (same for all columns and rows)
reg signed [IACT_WIDTH-1:0] iact_vals [0:CYCLES_PER_IACT-1];

// Expected per-PE psum before streaming (each PE accumulates its own row's weights)
reg signed [PSUM_WIDTH-1:0] pe_expected_psum [0:NUM_ROWS_ACTIVE-1][0:CYCLES_PER_IACT-1];

// Expected final GLB output = sum across all rows of each column
reg signed [PSUM_WIDTH-1:0] expected_glb [0:NUM_PE_COLS-1][0:CYCLES_PER_IACT-1];

// Captured GLB outputs
reg signed [PSUM_WIDTH-1:0] glb_captured [0:NUM_PE_COLS-1][0:CYCLES_PER_IACT-1];
reg glb_valid_captured [0:NUM_PE_COLS-1][0:CYCLES_PER_IACT-1];

integer i, j, r, c;
integer pass_count, fail_count;
integer weight_col, mac_slot;

// ============================================================================
// Tasks
// ============================================================================
task tick;
begin @(posedge clock); #1; end
endtask

// Drive all active-row column buses with the same data/valid
task drive_all_cols;
    input signed [IACT_WIDTH-1:0] data;
    input valid;
begin
    // All rows in active range get the same data (broadcast from GLB)
    PE00_d=data; PE00_v=valid; PE10_d=data; PE10_v=valid; PE20_d=data; PE20_v=valid;
    PE01_d=data; PE01_v=valid; PE11_d=data; PE11_v=valid; PE21_d=data; PE21_v=valid;
    PE02_d=data; PE02_v=valid; PE12_d=data; PE12_v=valid; PE22_d=data; PE22_v=valid;
    PE03_d=data; PE03_v=valid; PE13_d=data; PE13_v=valid; PE23_d=data; PE23_v=valid;
    // Inactive rows tied off
    PE30_d=0; PE30_v=0; PE31_d=0; PE31_v=0; PE32_d=0; PE32_v=0; PE33_d=0; PE33_v=0;
    PE40_d=0; PE40_v=0; PE41_d=0; PE41_v=0; PE42_d=0; PE42_v=0; PE43_d=0; PE43_v=0;
    PE50_d=0; PE50_v=0; PE51_d=0; PE51_v=0; PE52_d=0; PE52_v=0; PE53_d=0; PE53_v=0;
    PE60_d=0; PE60_v=0; PE61_d=0; PE61_v=0; PE62_d=0; PE62_v=0; PE63_d=0; PE63_v=0;
    PE70_d=0; PE70_v=0; PE71_d=0; PE71_v=0; PE72_d=0; PE72_v=0; PE73_d=0; PE73_v=0;
    PE80_d=0; PE80_v=0; PE81_d=0; PE81_v=0; PE82_d=0; PE82_v=0; PE83_d=0; PE83_v=0;
end
endtask

task check;
    input signed [PSUM_WIDTH-1:0] got;
    input signed [PSUM_WIDTH-1:0] exp;
    input [255:0] tag;
begin
    if (got === exp) begin
        $display("  PASS [%0s]  got=%0d  exp=%0d", tag, got, exp);
        pass_count = pass_count + 1;
    end else begin
        $display("  FAIL [%0s]  got=%0d  exp=%0d  <<<<", tag, got, exp);
        fail_count = fail_count + 1;
    end
end
endtask

// ============================================================================
// MAIN TEST
// ============================================================================
initial begin
    $dumpfile("PE_cluster_tb.vcd");
    $dumpvars(0, PE_cluster_tb);

    // ── test vectors ─────────────────────────────────────────────────────────
    // iact values broadcast to all columns
    iact_vals[0] = 8'sd10; iact_vals[1] = 8'sd20;
    iact_vals[2] = 8'sd30; iact_vals[3] = 8'sd40;

    // weight_mem[row][weight_col]
    // For FILTER_9 we initialize a 9x9 weight kernel. Use a simple pattern
    // weight_mem[row][col] = (row*9 + col + 1) to keep values small and distinct.
    for (r = 0; r < NUM_ROWS_ACTIVE; r = r + 1) begin
        for (j = 0; j < WEIGHT_COLS; j = j + 1) begin
            weight_mem[r][j] = $signed((r*WEIGHT_COLS + j + 1));
        end
    end

    // Per-PE expected psum: pe_expected_psum[row][iact_slot]
    //   = iact[slot] * sum_over_weight_cols(weight_mem[row][wc])
    for (r = 0; r < NUM_ROWS_ACTIVE; r = r + 1) begin
        for (i = 0; i < CYCLES_PER_IACT; i = i + 1) begin
            pe_expected_psum[r][i] = 0;
            for (j = 0; j < WEIGHT_COLS; j = j + 1)
                pe_expected_psum[r][i] = pe_expected_psum[r][i]
                                       + iact_vals[i] * weight_mem[r][j];
        end
    end

    // Expected GLB output = psum chain sum across all active rows
    // (psum_in to row0 = 0, each row adds its own psum and passes down)
    for (c = 0; c < NUM_PE_COLS; c = c + 1) begin
        for (i = 0; i < CYCLES_PER_IACT; i = i + 1) begin
            expected_glb[c][i] = 0;
            for (r = 0; r < NUM_ROWS_ACTIVE; r = r + 1)
                expected_glb[c][i] = expected_glb[c][i] + pe_expected_psum[r][i];
        end
    end

    pass_count = 0; fail_count = 0;

    // ── defaults ──────────────────────────────────────────────────────────────
    reset                    = 1;
    top_filter_mode          = FILTER_MODE;
    top_load_PEs_weight_pe   = 0;
    top_load_PEs_iact_pe     = 0;
    top_mac_en_pe            = 0;
    top_psum_stream_start_pe = 0;
    top_PSUM_to_GLB_en_pe    = 0;
    PE_mode                  = 0;
    cycles_per_iact_col      = CYCLES_PER_IACT;
    weight_columns           = WEIGHT_COLS;
    psum_spad_write_index    = 0;
    weight_spad_index        = 0;
    final_psum_out_ready_glb0 = 1;
    final_psum_out_ready_glb1 = 1;
    final_psum_out_ready_glb2 = 1;
    final_psum_out_ready_glb3 = 1;
    drive_all_cols(0, 0);

    repeat(4) tick;
    reset = 0;
    tick;

    // =========================================================================
    // PHASE 1 — LOAD WEIGHTS
    // All active PEs in each row receive their row's weight set.
    // The cluster broadcasts top_load_PEs_weight_pe to all PEs.
    // Each row has its own weight values; the columns all get the same weight
    // per row (weight_mem[row][weight_col] written sequentially).
    // We write all WEIGHT_COLS weights for each row sequentially,
    // one row at a time. All rows are loaded in parallel per cycle
    // because all PEs in the same row share the same data bus column signals,
    // but different rows can have different data — we load them simultaneously
    // by driving each row's bus with its own weight value each tick.
    // =========================================================================
    $display("\n=== PHASE 1: Load Weights to all PEs ===");
    // Drive load signal
    top_load_PEs_weight_pe = 1;

    // Each weight column: send weight_mem[row][wc] to all PEs in that row simultaneously
    for (i = 0; i < WEIGHT_COLS; i = i + 1) begin
        // Row 0 buses
        PE00_d=weight_mem[0][i]; PE00_v=1; PE01_d=weight_mem[0][i]; PE01_v=1;
        PE02_d=weight_mem[0][i]; PE02_v=1; PE03_d=weight_mem[0][i]; PE03_v=1;
        // Row 1 buses
        PE10_d=weight_mem[1][i]; PE10_v=1; PE11_d=weight_mem[1][i]; PE11_v=1;
        PE12_d=weight_mem[1][i]; PE12_v=1; PE13_d=weight_mem[1][i]; PE13_v=1;
        // Row 2 buses
        PE20_d=weight_mem[2][i]; PE20_v=1; PE21_d=weight_mem[2][i]; PE21_v=1;
        PE22_d=weight_mem[2][i]; PE22_v=1; PE23_d=weight_mem[2][i]; PE23_v=1;
        // Inactive rows (disabled, still driven with 0)
        PE30_d=0; PE30_v=1; PE31_d=0; PE31_v=1; PE32_d=0; PE32_v=1; PE33_d=0; PE33_v=1;
        PE40_d=0; PE40_v=1; PE41_d=0; PE41_v=1; PE42_d=0; PE42_v=1; PE43_d=0; PE43_v=1;
        PE50_d=0; PE50_v=1; PE51_d=0; PE51_v=1; PE52_d=0; PE52_v=1; PE53_d=0; PE53_v=1;
        PE60_d=0; PE60_v=1; PE61_d=0; PE61_v=1; PE62_d=0; PE62_v=1; PE63_d=0; PE63_v=1;
        PE70_d=0; PE70_v=1; PE71_d=0; PE71_v=1; PE72_d=0; PE72_v=1; PE73_d=0; PE73_v=1;
        PE80_d=0; PE80_v=1; PE81_d=0; PE81_v=1; PE82_d=0; PE82_v=1; PE83_d=0; PE83_v=1;
        tick;
        $display("  weight_col[%0d]: row0=%0d row1=%0d row2=%0d",
                 i, $signed(weight_mem[0][i]),
                    $signed(weight_mem[1][i]),
                    $signed(weight_mem[2][i]));
    end

    drive_all_cols(0, 0); // de-assert all valid
    top_load_PEs_weight_pe = 0;

    // Wait for all PEs to pulse weight_done (cluster ANDs them → load_PEs_weight_done_top)
    tick; // weight_done pulses inside PEs
    $display("  load_PEs_weight_done_top = %b (expect 1)", load_PEs_weight_done_top);
    tick; // all FSMs → IDLE

    // =========================================================================
    // PHASE 2+3 — OUTER LOOP (weight columns) × INNER LOOP (mac slots)
    // For each weight_col:
    //   a) Reload iact SPAD (same iact values every pass)
    //   b) Inner: CYCLES_PER_IACT single-MAC steps
    //      mac_done comes from DO_MAC state combinatorially (mac_done=1 always in DO_MAC)
    //      cluster ANDs all PE mac_done → mac_done_top
    //      TB waits for mac_done_top then drives WRITE_BACK by deasserting mac_en
    // =========================================================================
    for (weight_col = 0; weight_col < WEIGHT_COLS; weight_col = weight_col + 1) begin

        // ── 2a: Reload iact SPAD ─────────────────────────────────────────────
        $display("\n=== Weight col %0d: Load IACTs ===", weight_col);
        top_load_PEs_iact_pe = 1;

        for (i = 0; i < CYCLES_PER_IACT; i = i + 1) begin
            // Broadcast same iact to all active rows × all cols
            PE00_d=iact_vals[i]; PE00_v=1; PE01_d=iact_vals[i]; PE01_v=1;
            PE02_d=iact_vals[i]; PE02_v=1; PE03_d=iact_vals[i]; PE03_v=1;
            PE10_d=iact_vals[i]; PE10_v=1; PE11_d=iact_vals[i]; PE11_v=1;
            PE12_d=iact_vals[i]; PE12_v=1; PE13_d=iact_vals[i]; PE13_v=1;
            PE20_d=iact_vals[i]; PE20_v=1; PE21_d=iact_vals[i]; PE21_v=1;
            PE22_d=iact_vals[i]; PE22_v=1; PE23_d=iact_vals[i]; PE23_v=1;
            PE30_d=0; PE30_v=1; PE31_d=0; PE31_v=1; PE32_d=0; PE32_v=1; PE33_d=0; PE33_v=1;
            PE40_d=0; PE40_v=1; PE41_d=0; PE41_v=1; PE42_d=0; PE42_v=1; PE43_d=0; PE43_v=1;
            PE50_d=0; PE50_v=1; PE51_d=0; PE51_v=1; PE52_d=0; PE52_v=1; PE53_d=0; PE53_v=1;
            PE60_d=0; PE60_v=1; PE61_d=0; PE61_v=1; PE62_d=0; PE62_v=1; PE63_d=0; PE63_v=1;
            PE70_d=0; PE70_v=1; PE71_d=0; PE71_v=1; PE72_d=0; PE72_v=1; PE73_d=0; PE73_v=1;
            PE80_d=0; PE80_v=1; PE81_d=0; PE81_v=1; PE82_d=0; PE82_v=1; PE83_d=0; PE83_v=1;
            tick;
            $display("  iact[%0d]=%0d written to all cols", i, $signed(iact_vals[i]));
        end

        drive_all_cols(0, 0);
        top_load_PEs_iact_pe = 0;
        tick; // iact_done pulses
        $display("  load_PEs_iact_done_top = %b (expect 1)", load_PEs_iact_done_top);
        tick; // FSMs → IDLE

        // ── 2b: Inner MAC loop ────────────────────────────────────────────────
        $display("=== Weight col %0d: MAC loop ===", weight_col);
        weight_spad_index = weight_col[3:0];

        for (mac_slot = 0; mac_slot < CYCLES_PER_IACT; mac_slot = mac_slot + 1) begin
            psum_spad_write_index = mac_slot[3:0];

            // Wait for all FSMs to be IDLE before firing mac_en
            wait (dut.PE00.current_state == 0); @(posedge clock); #1;

            // Assert mac_en → all PEs: IDLE → DO_MAC
            // DO_MAC sets mac_done=1 combinatorially (same cycle)
            // mac_done_top = AND of all active PE mac_done signals
            top_mac_en_pe = 1;
            tick;            // PEs: IDLE → DO_MAC, mac_done=1 comb, next=WRITE_BACK
            top_mac_en_pe = 0;
            // mac_done_top should be high now (all PEs in DO_MAC)
            $display("  mac_slot=%0d mac_done_top=%b (expect 1)", mac_slot, mac_done_top);

            tick;            // PEs: DO_MAC → WRITE_BACK
            tick;            // PEs: WRITE_BACK → IDLE
        end
    end

    $display("\n  All %0d MAC ops complete.", WEIGHT_COLS * CYCLES_PER_IACT);

    // =========================================================================
    // PHASE 4 — PSUM STREAM
    // psum_stream_start broadcast to all PEs → FSM: IDLE → STREAM_1
    // The top row (row 0) gets psum_in = 0 (driven by top_psum_stream_start_pe
    // in the cluster: PE0X_psum_in = 0, PE0X_psum_in_valid = top_psum_stream_start_pe)
    // Each row's STREAM_1 waits for psum_in_handshake from the row above.
    // The chain propagates: row0 output → row1 input → ... → row2 output → GLB.
    //
    // The TB only needs to assert psum_stream_start and switch PE_mode=1,
    // then wait for psum_stream_done_top (AND of all PE psum_stream_done).
    // We also capture the GLB outputs as they arrive.
    // =========================================================================
    $display("\n=== PHASE 4: PSUM Stream ===");

    PE_mode = 1;
    top_psum_stream_start_pe = 1;
    tick;                          // all PEs: IDLE → STREAM_1
    top_psum_stream_start_pe = 0;

    // Stream proceeds autonomously:
    // Row 0: psum_in=0 (valid=top_psum_stream_start_pe just fired → handshake ok)
    // Row 0 STREAM_1 → STREAM_2 (psum_out_valid=1 → row1 sees valid psum_in)
    // Row 1 STREAM_1 → STREAM_2 → row2 STREAM_1 → STREAM_2
    // Row 2 STREAM_2: psum_out_valid=1 → final_psum_out_glbX
    //
    // We sample the GLB outputs while psum_out_valid is high.
    // Each psum slot takes: NUM_ROWS_ACTIVE * 2 cycles (STREAM_1 + STREAM_2 per row)
    // Total stream: CYCLES_PER_IACT * (2 * NUM_ROWS_ACTIVE) cycles

    begin : stream_capture
        integer slot, row_cyc, glb_slot;
        glb_slot = 0;

        // Wait for stream to propagate through all rows and capture outputs
        // Total cycles = CYCLES_PER_IACT slots × 2 states/row × NUM_ROWS_ACTIVE rows
        repeat(CYCLES_PER_IACT * 2 * NUM_ROWS_ACTIVE + 4) begin
            tick;
            // Sample each GLB bank when valid
            if (final_psum_out_valid_glb0 && glb_slot < CYCLES_PER_IACT) begin
                glb_captured[0][glb_slot] = final_psum_out_glb0;
                glb_captured[1][glb_slot] = final_psum_out_glb1;
                glb_captured[2][glb_slot] = final_psum_out_glb2;
                glb_captured[3][glb_slot] = final_psum_out_glb3;
                glb_valid_captured[0][glb_slot] = 1;
                $display("  Stream slot %0d captured: glb0=%0d glb1=%0d glb2=%0d glb3=%0d",
                         glb_slot, $signed(final_psum_out_glb0), $signed(final_psum_out_glb1),
                                   $signed(final_psum_out_glb2), $signed(final_psum_out_glb3));
                glb_slot = glb_slot + 1;
            end
        end
    end

    // Wait for psum_stream_done_top
    if (!psum_stream_done_top)
        $display("  WARN: psum_stream_done_top not yet asserted, waiting...");
    wait(psum_stream_done_top);
    $display("  psum_stream_done_top asserted");
    tick;

    // Verify captured stream outputs
    $display("\n=== Stream Output Checks ===");
    for (i = 0; i < CYCLES_PER_IACT; i = i + 1) begin
        for (c = 0; c < NUM_PE_COLS; c = c + 1) begin
            check(glb_captured[c][i], expected_glb[c][i], "STREAM_GLB");
        end
    end

    // =========================================================================
    // PHASE 5 — PSUM TO GLB (final readout from psum spad of bottom PE)
    // Only the last active row outputs to the GLB in each filter mode.
    // The cluster routes psum_to_GLB_en to the correct row's PEs.
    // FSM: IDLE → PSUM_TO_GLB_1 → PSUM_TO_GLB_2 (cycles through all slots).
    // =========================================================================
    $display("\n=== PHASE 5: PSUM to GLB (direct spad readout) ===");

    PE_mode = 0;
    top_PSUM_to_GLB_en_pe = 1;
    tick;               // → PSUM_TO_GLB_1
    top_PSUM_to_GLB_en_pe = 0;
    tick;               // PSUM_TO_GLB_1 → PSUM_TO_GLB_2

    for (i = 0; i < CYCLES_PER_IACT; i = i + 1) begin
        tick;
        if (final_psum_out_valid_glb0) begin
            $display("  GLB slot %0d: glb0=%0d exp=%0d | glb1=%0d exp=%0d | glb2=%0d exp=%0d | glb3=%0d exp=%0d",
                     i,
                     $signed(final_psum_out_glb0), $signed(expected_glb[0][i]),
                     $signed(final_psum_out_glb1), $signed(expected_glb[1][i]),
                     $signed(final_psum_out_glb2), $signed(expected_glb[2][i]),
                     $signed(final_psum_out_glb3), $signed(expected_glb[3][i]));
            check(final_psum_out_glb0, expected_glb[0][i], "GLB_READ_col0");
            check(final_psum_out_glb1, expected_glb[1][i], "GLB_READ_col1");
            check(final_psum_out_glb2, expected_glb[2][i], "GLB_READ_col2");
            check(final_psum_out_glb3, expected_glb[3][i], "GLB_READ_col3");
        end else
            $display("  WARN: GLB valid=0 on slot %0d", i);
    end
    tick;

    // =========================================================================
    // REPORT
    // =========================================================================
    $display("\n======================================");
    $display("  TEST COMPLETE");
    $display("  PASS: %0d   FAIL: %0d", pass_count, fail_count);
    if (fail_count == 0)
        $display("  *** ALL TESTS PASSED ***");
    else
        $display("  *** %0d TEST(S) FAILED ***", fail_count);
    $display("======================================\n");

    #50; $finish;
end

// ============================================================================
// Timeout watchdog
// ============================================================================
initial begin
    #5000000;
    $display("TIMEOUT");
    $finish;
end

// ============================================================================
// Cluster-level monitor
// ============================================================================
initial begin
    $monitor("[%0t ns] wt_done=%b iact_done=%b mac_done_top=%b stream_done=%b | glb0_v=%b glb0=%0d",
             $time,
             load_PEs_weight_done_top, load_PEs_iact_done_top,
             mac_done_top, psum_stream_done_top,
             final_psum_out_valid_glb0, $signed(final_psum_out_glb0));
end

endmodule