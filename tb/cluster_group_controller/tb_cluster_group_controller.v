
// =============================================================================
// Testbench: tb_cluster_group_controller.v
//
// Architecture (mirrors glb_router_tb.v):
//   - GLB_CLUSTER is instantiated alongside the controller DUT.
//   - The TB acts as the external data source (DRAM/BRAM):
//       * It watches iact_GLB_write_en from the controller.
//       * When asserted, the TB streams iact data into the GLB exactly as
//         glb_router_tb.v does (set write_addr -> assert write_en + data_in_valid
//         -> stream words -> deassert write_en -> wait for write_done).
//       * write_done from the GLB is fed back to the controller as
//         iact_GLB_write_done.
//   - Weight GLB write is handled the same way (TB streams weight data).
//
// Test Cases:
//   TC1 - GLB Iact Loaded Correctly:
//         After turn_on the controller asserts iact_GLB_write_en.
//         The TB streams NUM_IACT_WORDS into the GLB and verifies
//         write_done is received, then verifies the controller de-asserts
//         iact_GLB_write_en.
//
//   TC2 - Iact Done Assertion Correct:
//         After the GLB is loaded, the FSM routes weights and then iacts.
//         Verify load_PEs_iact is asserted at GLB_IACT_READ_ADDRESS,
//         iact_GLB_read_en is asserted during routing, and after
//         load_PEs_iact_done the controller re-asserts iact_GLB_write_en
//         (background load) and mac_start in PE_START_IACT_GLB_LOAD.
//
// Protocol (from glb_router_tb.v comments):
//   WRITE:
//     Cycle 0 : set write_addr
//     Cycle 1 : assert write_en + data_in_valid
//     Cycle 2+: stream data words
//     Deassert write_en -> write_done pulses next cycle
// =============================================================================

`timescale 1ns/1ps

module tb_cluster_group_controller;

// ============================================================
// Parameters
// ============================================================
parameter IACT_SIZE                = 8;
parameter IACT_SRAM_DEPTH          = 256;
parameter IACT_SRAM_ADDRESS_SIZE   = 8;
parameter WEIGHT_SIZE              = 8;
parameter WEIGHT_SRAM_DEPTH        = 256;
parameter WEIGHT_SRAM_ADDRESS_SIZE = 8;   // GLB_CLUSTER uses 8; controller uses 7
parameter CTRL_WEIGHT_ADDR_SIZE    = 7;   // controller parameter
parameter PSUM_SIZE                = 20;
parameter PSUM_ADDR_SIZE           = 5;
parameter PSUM_SRAM_DEPTH          = 32;
parameter PSUM_WRITE_CNT_SIZE      = 5;
parameter WRITE_COUNT_SIZE         = 5;

// Number of iact words to write per load (matches unique_values_per_cluster)
parameter NUM_IACT_WORDS  = 16;
parameter NUM_WEIGHT_WORDS = 9;

// Convolution config
parameter CYCLES_PER_IACT_COL                = 5'd2;
parameter UNIQUE_VALUES_PER_CLUSTER_PER_CYCLE= 5'd8;
parameter UNIQUE_VALUES_PER_CLUSTER          = 8'd16;  // must match NUM_IACT_WORDS
parameter WEIGHT_VALUES_PER_FILTER           = 7'd9;
parameter WEIGHT_COLUMNS                     = 4'd1;

// ============================================================
// Clock / Reset
// ============================================================
reg clk;
reg rst;

initial clk = 0;
always #5 clk = ~clk;   // 100 MHz

task wait_clk;
    begin @(posedge clk); #1; end
endtask

// ============================================================
// Scoreboard
// ============================================================
integer pass_count;
integer fail_count;

// ============================================================
// GLB_CLUSTER port signals
// ============================================================

// -- IACT write (TB drives these into GLB) --
wire                            IACT_data_in_ready;
reg                             IACT_data_in_valid;
reg  [IACT_SIZE-1:0]            IACT_data_in;
reg                             IACT_write_en;
reg  [IACT_SRAM_ADDRESS_SIZE-1:0] IACT_write_addr;
wire                            IACT_write_done;

// -- IACT read ports (controller drives these) --
wire                            IACT_data_out_ready_0;
wire                            IACT_data_out_valid_0;
wire [IACT_SIZE-1:0]            IACT_data_out_0;

wire                            IACT_data_out_ready_1;
wire                            IACT_data_out_valid_1;
wire [IACT_SIZE-1:0]            IACT_data_out_1;

wire                            IACT_data_out_ready_2;
wire                            IACT_data_out_valid_2;
wire [IACT_SIZE-1:0]            IACT_data_out_2;

wire                            IACT_read_en_0;
wire [IACT_SRAM_ADDRESS_SIZE-1:0] IACT_read_addr_0;
wire                            IACT_read_done_0;

wire                            IACT_read_en_1;
wire [IACT_SRAM_ADDRESS_SIZE-1:0] IACT_read_addr_1;
wire                            IACT_read_done_1;

wire                            IACT_read_en_2;
wire [IACT_SRAM_ADDRESS_SIZE-1:0] IACT_read_addr_2;
wire                            IACT_read_done_2;

// -- WEIGHT write (TB drives these into GLB) --
wire                                  WEIGHT_data_in_ready;
reg                                   WEIGHT_data_in_valid;
reg  [WEIGHT_SIZE-1:0]                WEIGHT_data_in;
reg                                   WEIGHT_write_en;
reg  [WEIGHT_SRAM_ADDRESS_SIZE-1:0]   WEIGHT_write_addr;
wire                                  WEIGHT_write_done;

// -- WEIGHT read ports (controller drives) --
wire                                  WEIGHT_data_out_ready_0;
wire                                  WEIGHT_data_out_valid_0;
wire [WEIGHT_SIZE-1:0]                WEIGHT_data_out_0;
wire                                  WEIGHT_data_out_ready_1;
wire                                  WEIGHT_data_out_valid_1;
wire [WEIGHT_SIZE-1:0]                WEIGHT_data_out_1;
wire                                  WEIGHT_data_out_ready_2;
wire                                  WEIGHT_data_out_valid_2;
wire [WEIGHT_SIZE-1:0]                WEIGHT_data_out_2;

wire                                  WEIGHT_read_en_0;
wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0]   WEIGHT_read_addr_0;
wire                                  WEIGHT_read_done_0;
wire                                  WEIGHT_read_en_1;
wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0]   WEIGHT_read_addr_1;
wire                                  WEIGHT_read_done_1;
wire                                  WEIGHT_read_en_2;
wire [WEIGHT_SRAM_ADDRESS_SIZE-1:0]   WEIGHT_read_addr_2;
wire                                  WEIGHT_read_done_2;

// -- PSUM ports (tie off) --
wire psum0_data_in_ready, psum1_data_in_ready,
     psum2_data_in_ready, psum3_data_in_ready;
wire psum0_data_out_valid, psum1_data_out_valid,
     psum2_data_out_valid, psum3_data_out_valid;
wire signed [PSUM_SIZE-1:0] psum0_data_out, psum1_data_out,
                             psum2_data_out, psum3_data_out;
wire psum0_write_done, psum1_write_done,
     psum2_write_done, psum3_write_done;
wire psum0_read_done, psum1_read_done,
     psum2_read_done, psum3_read_done;

// ============================================================
// GLB_CLUSTER instantiation
// ============================================================
GLB_CLUSTER #(
    .IACT_SIZE            (IACT_SIZE),
    .IACT_SRAM_DEPTH      (IACT_SRAM_DEPTH),
    .IACT_SRAM_ADDRESS_SIZE(IACT_SRAM_ADDRESS_SIZE),
    .WEIGHT_SIZE          (WEIGHT_SIZE),
    .WEIGHT_SRAM_DEPTH    (WEIGHT_SRAM_DEPTH),
    .WEIGHT_SRAM_ADDRESS_SIZE(WEIGHT_SRAM_ADDRESS_SIZE),
    .PSUM_SIZE            (PSUM_SIZE),
    .ADDRESS_SIZE         (PSUM_ADDR_SIZE),
    .PSUM_SRAM_DEPTH      (PSUM_SRAM_DEPTH),
    .PSUM_WRITE_COUNT_SIZE(PSUM_WRITE_CNT_SIZE)
) u_glb (
    .clk                  (clk),
    .rst                  (rst),
    // IACT write
    .IACT_data_in_ready   (IACT_data_in_ready),
    .IACT_data_in_valid   (IACT_data_in_valid),
    .IACT_data_in         (IACT_data_in),
    // IACT read port 0
    .IACT_data_out_ready_0(IACT_data_out_ready_0),
    .IACT_data_out_valid_0(IACT_data_out_valid_0),
    .IACT_data_out_0      (IACT_data_out_0),
    // IACT read port 1
    .IACT_data_out_ready_1(IACT_data_out_ready_1),
    .IACT_data_out_valid_1(IACT_data_out_valid_1),
    .IACT_data_out_1      (IACT_data_out_1),
    // IACT read port 2
    .IACT_data_out_ready_2(IACT_data_out_ready_2),
    .IACT_data_out_valid_2(IACT_data_out_valid_2),
    .IACT_data_out_2      (IACT_data_out_2),
    // IACT control
    .IACT_write_en        (IACT_write_en),
    .IACT_write_addr      (IACT_write_addr),
    .IACT_write_done      (IACT_write_done),
    .IACT_read_en_0       (IACT_read_en_0),
    .IACT_read_addr_0     (IACT_read_addr_0),
    .IACT_read_done_0     (IACT_read_done_0),
    .IACT_read_en_1       (IACT_read_en_1),
    .IACT_read_addr_1     (IACT_read_addr_1),
    .IACT_read_done_1     (IACT_read_done_1),
    .IACT_read_en_2       (IACT_read_en_2),
    .IACT_read_addr_2     (IACT_read_addr_2),
    .IACT_read_done_2     (IACT_read_done_2),
    // WEIGHT write
    .WEIGHT_data_in_ready (WEIGHT_data_in_ready),
    .WEIGHT_data_in_valid (WEIGHT_data_in_valid),
    .WEIGHT_data_in       (WEIGHT_data_in),
    // WEIGHT read port 0
    .WEIGHT_data_out_ready_0(WEIGHT_data_out_ready_0),
    .WEIGHT_data_out_valid_0(WEIGHT_data_out_valid_0),
    .WEIGHT_data_out_0      (WEIGHT_data_out_0),
    // WEIGHT read port 1
    .WEIGHT_data_out_ready_1(WEIGHT_data_out_ready_1),
    .WEIGHT_data_out_valid_1(WEIGHT_data_out_valid_1),
    .WEIGHT_data_out_1      (WEIGHT_data_out_1),
    // WEIGHT read port 2
    .WEIGHT_data_out_ready_2(WEIGHT_data_out_ready_2),
    .WEIGHT_data_out_valid_2(WEIGHT_data_out_valid_2),
    .WEIGHT_data_out_2      (WEIGHT_data_out_2),
    // WEIGHT control
    .WEIGHT_write_en        (WEIGHT_write_en),
    .WEIGHT_write_addr      (WEIGHT_write_addr),
    .WEIGHT_write_done      (WEIGHT_write_done),
    .WEIGHT_read_en_0       (WEIGHT_read_en_0),
    .WEIGHT_read_addr_0     (WEIGHT_read_addr_0),
    .WEIGHT_read_done_0     (WEIGHT_read_done_0),
    .WEIGHT_read_en_1       (WEIGHT_read_en_1),
    .WEIGHT_read_addr_1     (WEIGHT_read_addr_1),
    .WEIGHT_read_done_1     (WEIGHT_read_done_1),
    .WEIGHT_read_en_2       (WEIGHT_read_en_2),
    .WEIGHT_read_addr_2     (WEIGHT_read_addr_2),
    .WEIGHT_read_done_2     (WEIGHT_read_done_2),
    // PSUM banks (tie off)
    .psum0_data_in_ready  (psum0_data_in_ready),
    .psum0_data_in_valid  (1'b0),
    .psum0_data_in        ({PSUM_SIZE{1'b0}}),
    .psum0_data_out_ready (1'b0),
    .psum0_data_out_valid (psum0_data_out_valid),
    .psum0_data_out       (psum0_data_out),
    .psum0_write_en       (1'b0),
    .psum0_write_addr     ({PSUM_ADDR_SIZE{1'b0}}),
    .psum0_write_done     (psum0_write_done),
    .psum0_read_done      (psum0_read_done),
    .psum0_read_en        (1'b0),
    .psum0_read_addr      ({PSUM_ADDR_SIZE{1'b0}}),
    .psum0_PSUM_DEPTH     ({PSUM_WRITE_CNT_SIZE{1'b0}}),
    .psum1_data_in_ready  (psum1_data_in_ready),
    .psum1_data_in_valid  (1'b0),
    .psum1_data_in        ({PSUM_SIZE{1'b0}}),
    .psum1_data_out_ready (1'b0),
    .psum1_data_out_valid (psum1_data_out_valid),
    .psum1_data_out       (psum1_data_out),
    .psum1_write_en       (1'b0),
    .psum1_write_addr     ({PSUM_ADDR_SIZE{1'b0}}),
    .psum1_write_done     (psum1_write_done),
    .psum1_read_done      (psum1_read_done),
    .psum1_read_en        (1'b0),
    .psum1_read_addr      ({PSUM_ADDR_SIZE{1'b0}}),
    .psum1_PSUM_DEPTH     ({PSUM_WRITE_CNT_SIZE{1'b0}}),
    .psum2_data_in_ready  (psum2_data_in_ready),
    .psum2_data_in_valid  (1'b0),
    .psum2_data_in        ({PSUM_SIZE{1'b0}}),
    .psum2_data_out_ready (1'b0),
    .psum2_data_out_valid (psum2_data_out_valid),
    .psum2_data_out       (psum2_data_out),
    .psum2_write_en       (1'b0),
    .psum2_write_addr     ({PSUM_ADDR_SIZE{1'b0}}),
    .psum2_write_done     (psum2_write_done),
    .psum2_read_done      (psum2_read_done),
    .psum2_read_en        (1'b0),
    .psum2_read_addr      ({PSUM_ADDR_SIZE{1'b0}}),
    .psum2_PSUM_DEPTH     ({PSUM_WRITE_CNT_SIZE{1'b0}}),
    .psum3_data_in_ready  (psum3_data_in_ready),
    .psum3_data_in_valid  (1'b0),
    .psum3_data_in        ({PSUM_SIZE{1'b0}}),
    .psum3_data_out_ready (1'b0),
    .psum3_data_out_valid (psum3_data_out_valid),
    .psum3_data_out       (psum3_data_out),
    .psum3_write_en       (1'b0),
    .psum3_write_addr     ({PSUM_ADDR_SIZE{1'b0}}),
    .psum3_write_done     (psum3_write_done),
    .psum3_read_done      (psum3_read_done),
    .psum3_read_en        (1'b0),
    .psum3_read_addr      ({PSUM_ADDR_SIZE{1'b0}}),
    .psum3_PSUM_DEPTH     ({PSUM_WRITE_CNT_SIZE{1'b0}})
);

// ============================================================
// Controller DUT port signals
// ============================================================
reg [2:0]  top_filter_mode;
reg [2:0]  top_input_mode;
reg        turn_on;
reg [4:0]  cycles_per_iact_col;
reg [4:0]  unique_values_per_cluster_per_cycle;
reg [7:0]  unique_values_per_cluster;
reg [6:0]  weight_values_per_filter;
reg [3:0]  weight_columns;

// iact GLB control wires (controller -> used to drive TB logic)
wire                              ctrl_iact_write_en;
wire [IACT_SRAM_ADDRESS_SIZE-1:0] ctrl_iact_start_write_addr;
wire [IACT_SRAM_ADDRESS_SIZE-1:0] ctrl_iact_write_address_fb; // GLB current addr fed back
wire                              ctrl_iact_write_done_fb;    // GLB write_done fed back

wire                              ctrl_iact_read_en;
wire [IACT_SRAM_ADDRESS_SIZE-1:0] ctrl_iact_read_addr_p0;
wire [IACT_SRAM_ADDRESS_SIZE-1:0] ctrl_iact_read_addr_p1;
wire [IACT_SRAM_ADDRESS_SIZE-1:0] ctrl_iact_read_addr_p2;
wire                              ctrl_iact_column_done_flag;

// weight GLB control wires from controller
wire                              ctrl_weight_write_en;
wire [CTRL_WEIGHT_ADDR_SIZE-1:0]  ctrl_weight_write_addr;
wire                              ctrl_weight_write_done_fb;

wire                              ctrl_weight_read_en_0;
wire [CTRL_WEIGHT_ADDR_SIZE-1:0]  ctrl_weight_read_addr_0;
wire                              ctrl_weight_read_done_0_fb;
wire                              ctrl_weight_read_en_1;
wire [CTRL_WEIGHT_ADDR_SIZE-1:0]  ctrl_weight_read_addr_1;
wire                              ctrl_weight_read_done_1_fb;
wire                              ctrl_weight_read_en_2;
wire [CTRL_WEIGHT_ADDR_SIZE-1:0]  ctrl_weight_read_addr_2;
wire                              ctrl_weight_read_done_2_fb;

// weight GLB data (controller <-> GLB via weight SRAM AXI-stream)
wire        ctrl_weight_data_in_ready;
wire        ctrl_weight_data_out_ready_0;
wire        ctrl_weight_data_out_ready_1;
wire        ctrl_weight_data_out_ready_2;

// psum GLB
wire                              ctrl_psum_write_en;
wire [CTRL_WEIGHT_ADDR_SIZE-1:0]  ctrl_psum_start_addr;
reg                               ctrl_psum_write_done;
reg  [CTRL_WEIGHT_ADDR_SIZE-1:0]  ctrl_psum_write_address;
wire [WRITE_COUNT_SIZE-1:0]       ctrl_psum_depth;

// iact router signals (controller outputs, not checked in these tests)
wire [1:0]  iact_r0_data_in_sel;
wire [2:0]  iact_r0_data_out_sel;
wire [3:0]  iact_r0_PE_sel;
wire [11:0] iact_r0_PE_choice;
wire [2:0]  iact_r0_Multicast_mode;

wire [1:0]  iact_r1_data_in_sel;
wire [2:0]  iact_r1_data_out_sel;
wire [3:0]  iact_r1_PE_sel;
wire [11:0] iact_r1_PE_choice;
wire [2:0]  iact_r1_Multicast_mode;

wire [1:0]  iact_r2_data_in_sel;
wire [2:0]  iact_r2_data_out_sel;
wire [3:0]  iact_r2_PE_sel;
wire [11:0] iact_r2_PE_choice;
wire [2:0]  iact_r2_Multicast_mode;

// weight router signals (tie off data ports)
wire        weight_r0_data_in_sel;
wire [1:0]  weight_r0_data_out_sel;
wire        weight_r1_data_in_sel;
wire [1:0]  weight_r1_data_out_sel;
wire        weight_r2_data_in_sel;
wire [1:0]  weight_r2_data_out_sel;

wire psum_r0_in_sel, psum_r0_out_sel;
wire psum_r1_in_sel, psum_r1_out_sel;
wire psum_r2_in_sel, psum_r2_out_sel;
wire psum_r3_in_sel, psum_r3_out_sel;

// PE cluster
wire        load_PEs_weight;
reg         load_PEs_weight_done;
wire        load_PEs_iact;
reg         load_PEs_iact_done;
wire        mac_start;
reg         mac_done;
wire        psum_stream_start;
reg         psum_stream_done;
wire        read_PEs_psum;
wire [3:0]  mac_done_counter;
wire [3:0]  weight_column_counter;
reg         iact_next_ofmap_col;
wire        PE_mode;

// ============================================================
// Controller instantiation
// ============================================================
cluster_group_controller #(
    .IACT_SRAM_ADDRESS_SIZE  (IACT_SRAM_ADDRESS_SIZE),
    .WEIGHT_SRAM_ADDRESS_SIZE(CTRL_WEIGHT_ADDR_SIZE),
    .WRITE_COUNT_SIZE        (WRITE_COUNT_SIZE),
    .WEIGHT_SIZE             (WEIGHT_SIZE)
) dut (
    .clock                              (clk),
    .reset                              (rst),
    .top_filter_mode                    (top_filter_mode),
    .top_input_mode                     (top_input_mode),
    .turn_on                            (turn_on),
    .cycles_per_iact_col                (cycles_per_iact_col),
    .unique_values_per_cluster_per_cycle(unique_values_per_cluster_per_cycle),
    .unique_values_per_cluster          (unique_values_per_cluster),
    .weight_values_per_filter           (weight_values_per_filter),
    .weight_columns                     (weight_columns),
    // iact GLB
    .iact_GLB_write_en                  (ctrl_iact_write_en),
    .iact_GLB_start_write_address       (ctrl_iact_start_write_addr),
    .iact_GLB_write_address             (IACT_write_addr),     // GLB current write address fed back
    .iact_GLB_write_done                (IACT_write_done),     // GLB write_done fed back
    .iact_GLB_read_en                   (ctrl_iact_read_en),
    .iact_GLB_start_read_address_port0  (ctrl_iact_read_addr_p0),
    .iact_GLB_start_read_address_port1  (ctrl_iact_read_addr_p1),
    .iact_GLB_start_read_address_port2  (ctrl_iact_read_addr_p2),
    .iact_column_done_flag              (ctrl_iact_column_done_flag),
    // weight GLB data
    .weight_GLB_data_in_ready           (ctrl_weight_data_in_ready),
    .weight_GLB_data_in_valid           (WEIGHT_data_in_valid),
    .weight_GLB_data_in                 (WEIGHT_data_in),
    .weight_GLB_data_out_ready_0        (ctrl_weight_data_out_ready_0),
    .weight_GLB_data_out_valid_0        (WEIGHT_data_out_valid_0),
    .weight_GLB_data_out_0              (WEIGHT_data_out_0),
    .weight_GLB_data_out_ready_1        (ctrl_weight_data_out_ready_1),
    .weight_GLB_data_out_valid_1        (WEIGHT_data_out_valid_1),
    .weight_GLB_data_out_1              (WEIGHT_data_out_1),
    .weight_GLB_data_out_ready_2        (ctrl_weight_data_out_ready_2),
    .weight_GLB_data_out_valid_2        (WEIGHT_data_out_valid_2),
    .weight_GLB_data_out_2              (WEIGHT_data_out_2),
    // weight GLB control
    .weight_GLB_write_en                (ctrl_weight_write_en),
    .weight_GLB_write_addr              (ctrl_weight_write_addr),
    .weight_GLB_write_done              (WEIGHT_write_done),
    .weight_GLB_read_en_0               (ctrl_weight_read_en_0),
    .weight_GLB_read_addr_0             (ctrl_weight_read_addr_0),
    .weight_GLB_read_done_0             (WEIGHT_read_done_0),
    .weight_GLB_read_en_1               (ctrl_weight_read_en_1),
    .weight_GLB_read_addr_1             (ctrl_weight_read_addr_1),
    .weight_GLB_read_done_1             (WEIGHT_read_done_1),
    .weight_GLB_read_en_2               (ctrl_weight_read_en_2),
    .weight_GLB_read_addr_2             (ctrl_weight_read_addr_2),
    .weight_GLB_read_done_2             (WEIGHT_read_done_2),
    // psum GLB
    .psum_GLB_write_en                  (ctrl_psum_write_en),
    .psum_GLB_start_address             (ctrl_psum_start_addr),
    .psum_GLB_write_done                (ctrl_psum_write_done),
    .psum_GLB_write_address             (ctrl_psum_write_address),
    .psum_GLB_depth                     (ctrl_psum_depth),
    // iact routers
    .iact_router0_data_in_sel           (iact_r0_data_in_sel),
    .iact_router0_data_out_sel          (iact_r0_data_out_sel),
    .iact_router0_PE_sel                (iact_r0_PE_sel),
    .iact_router0_PE_choice             (iact_r0_PE_choice),
    .iact_router0_Multicast_mode        (iact_r0_Multicast_mode),
    .iact_router1_data_in_sel           (iact_r1_data_in_sel),
    .iact_router1_data_out_sel          (iact_r1_data_out_sel),
    .iact_router1_PE_sel                (iact_r1_PE_sel),
    .iact_router1_PE_choice             (iact_r1_PE_choice),
    .iact_router1_Multicast_mode        (iact_r1_Multicast_mode),
    .iact_router2_data_in_sel           (iact_r2_data_in_sel),
    .iact_router2_data_out_sel          (iact_r2_data_out_sel),
    .iact_router2_PE_sel                (iact_r2_PE_sel),
    .iact_router2_PE_choice             (iact_r2_PE_choice),
    .iact_router2_Multicast_mode        (iact_r2_Multicast_mode),
    // weight routers (data ports tied off)
    .weight_router0_data_in_sel         (weight_r0_data_in_sel),
    .weight_router0_data_out_sel        (weight_r0_data_out_sel),
    .weight_0_GLB_data_in_valid         (1'b0),
    .weight_0_GLB_data_in               ({WEIGHT_SIZE{1'b0}}),
    .weight_0_GLB_data_in_ready         (),
    .weight_0_horiz_data_in_valid       (1'b0),
    .weight_0_horiz_data_in             ({WEIGHT_SIZE{1'b0}}),
    .weight_0_horiz_data_in_ready       (),
    .weight_0_PE_0_data_out_valid       (),
    .weight_0_PE_0_data_out             (),
    .weight_0_PE_1_data_out_valid       (),
    .weight_0_PE_1_data_out             (),
    .weight_0_PE_2_data_out_valid       (),
    .weight_0_PE_2_data_out             (),
    .weight_0_horiz_data_out_ready      (1'b0),
    .weight_0_horiz_data_out_valid      (),
    .weight_0_horiz_data_out            (),
    .weight_router1_data_in_sel         (weight_r1_data_in_sel),
    .weight_router1_data_out_sel        (weight_r1_data_out_sel),
    .weight_1_GLB_data_in_valid         (1'b0),
    .weight_1_GLB_data_in               ({WEIGHT_SIZE{1'b0}}),
    .weight_1_GLB_data_in_ready         (),
    .weight_1_horiz_data_in_valid       (1'b0),
    .weight_1_horiz_data_in             ({WEIGHT_SIZE{1'b0}}),
    .weight_1_horiz_data_in_ready       (),
    .weight_1_PE_0_data_out_valid       (),
    .weight_1_PE_0_data_out             (),
    .weight_1_PE_1_data_out_valid       (),
    .weight_1_PE_1_data_out             (),
    .weight_1_PE_2_data_out_valid       (),
    .weight_1_PE_2_data_out             (),
    .weight_1_horiz_data_out_ready      (1'b0),
    .weight_1_horiz_data_out_valid      (),
    .weight_1_horiz_data_out            (),
    .weight_router2_data_in_sel         (weight_r2_data_in_sel),
    .weight_router2_data_out_sel        (weight_r2_data_out_sel),
    .weight_2_GLB_data_in_valid         (1'b0),
    .weight_2_GLB_data_in               ({WEIGHT_SIZE{1'b0}}),
    .weight_2_GLB_data_in_ready         (),
    .weight_2_horiz_data_in_valid       (1'b0),
    .weight_2_horiz_data_in             ({WEIGHT_SIZE{1'b0}}),
    .weight_2_horiz_data_in_ready       (),
    .weight_2_PE_0_data_out_valid       (),
    .weight_2_PE_0_data_out             (),
    .weight_2_PE_1_data_out_valid       (),
    .weight_2_PE_1_data_out             (),
    .weight_2_PE_2_data_out_valid       (),
    .weight_2_PE_2_data_out             (),
    .weight_2_horiz_data_out_ready      (1'b0),
    .weight_2_horiz_data_out_valid      (),
    .weight_2_horiz_data_out            (),
    // psum routers
    .psum_router0_data_in_sel           (psum_r0_in_sel),
    .psum_router0_data_out_sel          (psum_r0_out_sel),
    .psum_router1_data_in_sel           (psum_r1_in_sel),
    .psum_router1_data_out_sel          (psum_r1_out_sel),
    .psum_router2_data_in_sel           (psum_r2_in_sel),
    .psum_router2_data_out_sel          (psum_r2_out_sel),
    .psum_router3_data_in_sel           (psum_r3_in_sel),
    .psum_router3_data_out_sel          (psum_r3_out_sel),
    // PE cluster
    .load_PEs_weight                    (load_PEs_weight),
    .load_PEs_weight_done               (load_PEs_weight_done),
    .load_PEs_iact                      (load_PEs_iact),
    .load_PEs_iact_done                 (load_PEs_iact_done),
    .mac_start                          (mac_start),
    .mac_done                           (mac_done),
    .psum_stream_start                  (psum_stream_start),
    .psum_stream_done                   (psum_stream_done),
    .read_PEs_psum                      (read_PEs_psum),
    .mac_done_counter                   (mac_done_counter),
    .weight_column_counter              (weight_column_counter),
    .iact_next_ofmap_col                (iact_next_ofmap_col),
    .PE_mode                            (PE_mode)
);

// ============================================================
// Controller -> GLB write wiring
// The TB watches ctrl_iact_write_en / ctrl_weight_write_en.
// When the controller asserts them, the TB streams data into
// the GLB, mirroring the exact protocol in glb_router_tb.v.
// ============================================================

// iact GLB read address and read_en are driven directly by controller
assign IACT_read_en_0   = ctrl_iact_read_en;
assign IACT_read_addr_0 = ctrl_iact_read_addr_p0;
assign IACT_read_en_1   = ctrl_iact_read_en;
assign IACT_read_addr_1 = ctrl_iact_read_addr_p1;
assign IACT_read_en_2   = ctrl_iact_read_en;
assign IACT_read_addr_2 = ctrl_iact_read_addr_p2;

// weight GLB read address and read_en are driven directly by controller
assign WEIGHT_read_en_0   = ctrl_weight_read_en_0;
assign WEIGHT_read_addr_0 = {{(WEIGHT_SRAM_ADDRESS_SIZE-CTRL_WEIGHT_ADDR_SIZE){1'b0}},
                              ctrl_weight_read_addr_0};
assign WEIGHT_read_en_1   = ctrl_weight_read_en_1;
assign WEIGHT_read_addr_1 = {{(WEIGHT_SRAM_ADDRESS_SIZE-CTRL_WEIGHT_ADDR_SIZE){1'b0}},
                              ctrl_weight_read_addr_1};
assign WEIGHT_read_en_2   = ctrl_weight_read_en_2;
assign WEIGHT_read_addr_2 = {{(WEIGHT_SRAM_ADDRESS_SIZE-CTRL_WEIGHT_ADDR_SIZE){1'b0}},
                              ctrl_weight_read_addr_2};

// GLB read-port ready signals (always 1: PEs always accept)
assign IACT_data_out_ready_0   = 1'b1;
assign IACT_data_out_ready_1   = 1'b1;
assign IACT_data_out_ready_2   = 1'b1;
assign WEIGHT_data_out_ready_0 = 1'b1;
assign WEIGHT_data_out_ready_1 = 1'b1;
assign WEIGHT_data_out_ready_2 = 1'b1;

// ============================================================
// Reference data arrays
// ============================================================
reg [IACT_SIZE-1:0]   iact_ref   [0:NUM_IACT_WORDS-1];
reg [WEIGHT_SIZE-1:0] weight_ref [0:NUM_WEIGHT_WORDS-1];

// ============================================================
// Helpers
// ============================================================
integer i;
integer timeout_cnt;
integer k;

// ============================================================
// TB task: stream iact data into GLB (glb_router_tb.v protocol)
// Called when the controller asserts ctrl_iact_write_en.
// ============================================================
task stream_iact_to_glb;
    begin
        // Cycle 0: set write address (use start address from controller)
        IACT_write_addr    = ctrl_iact_start_write_addr;
        IACT_write_en      = 0;
        IACT_data_in_valid = 0;
        wait_clk;

        // Cycle 1: assert write_en + first data word
        IACT_write_en      = 1;
        IACT_data_in_valid = 1;
        IACT_data_in       = iact_ref[0];
        wait_clk;

        // Cycles 2..N: stream remaining words
        for (i = 1; i < NUM_IACT_WORDS; i = i + 1) begin
            IACT_data_in = iact_ref[i];
            wait_clk;
        end

        // Deassert write_en -> write_done will pulse next cycle from GLB
        IACT_write_en      = 0;
        IACT_data_in_valid = 0;
        wait_clk;

        // Wait for write_done from GLB
        wait(IACT_write_done == 1);
        $display("  TB: IACT GLB write_done received at time %0t", $time);
        wait_clk;
    end
endtask

// ============================================================
// TB task: stream weight data into GLB
// ============================================================
task stream_weight_to_glb;
    begin
        WEIGHT_write_addr    = {{(WEIGHT_SRAM_ADDRESS_SIZE-CTRL_WEIGHT_ADDR_SIZE){1'b0}},
                                 ctrl_weight_write_addr};
        WEIGHT_write_en      = 0;
        WEIGHT_data_in_valid = 0;
        wait_clk;

        WEIGHT_write_en      = 1;
        WEIGHT_data_in_valid = 1;
        WEIGHT_data_in       = weight_ref[0];
        wait_clk;

        for (i = 1; i < NUM_WEIGHT_WORDS; i = i + 1) begin
            WEIGHT_data_in = weight_ref[i];
            wait_clk;
        end

        WEIGHT_write_en      = 0;
        WEIGHT_data_in_valid = 0;
        wait_clk;

        wait(WEIGHT_write_done == 1);
        $display("  TB: WEIGHT GLB write_done received at time %0t", $time);
        wait_clk;
    end
endtask

// ============================================================
// Main test flow
// ============================================================
initial begin
    $monitor("current state = %d",dut.current_state, "t=%0t", $time);
    $display("***********************************");
    $dumpfile("tb_cluster_group_controller.vcd");
    $dumpvars(0, tb_cluster_group_controller);

    $monitor("t=%0t | state_dbg: iact_we=%b wt_we=%b iact_wd=%b wt_wd=%b load_iact=%b iact_rd_en=%b",
             $time,
             ctrl_iact_write_en, ctrl_weight_write_en,
             IACT_write_done, WEIGHT_write_done,
             load_PEs_iact, ctrl_iact_read_en);

    pass_count = 0;
    fail_count = 0;

    // Build reference data
    for (i = 0; i < NUM_IACT_WORDS; i = i + 1)
        iact_ref[i] = (8'hA0 + i) & 8'hFF;   // same pattern as glb_router_tb.v

    for (i = 0; i < NUM_WEIGHT_WORDS; i = i + 1)
        weight_ref[i] = (8'hB0 + i) & 8'hFF;

    // --------------------------------------------------------
    // Initialise all inputs
    // --------------------------------------------------------
    rst                              = 1;
    turn_on                          = 0;
    top_filter_mode                  = 3'b000;  // FILTER_SIZE_9
    top_input_mode                   = 3'b000;
    cycles_per_iact_col              = CYCLES_PER_IACT_COL;
    unique_values_per_cluster_per_cycle = UNIQUE_VALUES_PER_CLUSTER_PER_CYCLE;
    unique_values_per_cluster        = UNIQUE_VALUES_PER_CLUSTER;
    weight_values_per_filter         = WEIGHT_VALUES_PER_FILTER;
    weight_columns                   = WEIGHT_COLUMNS;

    // TB-driven GLB write signals (idle)
    IACT_write_en      = 0;
    IACT_write_addr    = 0;
    IACT_data_in_valid = 0;
    IACT_data_in       = 0;

    WEIGHT_write_en      = 0;
    WEIGHT_write_addr    = 0;
    WEIGHT_data_in_valid = 0;
    WEIGHT_data_in       = 0;

    // PE cluster responses
    load_PEs_weight_done = 0;
    load_PEs_iact_done   = 0;
    mac_done             = 0;
    psum_stream_done     = 0;
    iact_next_ofmap_col  = 0;
    ctrl_psum_write_done  = 0;
    ctrl_psum_write_address = 0;

    // --------------------------------------------------------
    // Reset sequence
    // --------------------------------------------------------
    repeat(4) wait_clk;
    rst = 0;
    repeat(2) wait_clk;

    // ========================================================
    // TC1: GLB Iact Loaded Correctly
    // ========================================================
    // Expected:
    //   IDLE -> GLB_LOAD_ADDRESS: controller sets iact_GLB_start_write_address=0
    //   -> GLB_LOAD: controller asserts iact_GLB_write_en AND weight_GLB_write_en
    //      TB responds by streaming data into both GLBs
    //   -> Both write_done received -> FSM exits to GLB_WEIGHT_READ_ADDRESS
    //   Verify: iact_GLB_write_en was asserted, real write_done came from GLB,
    //           and iact_GLB_write_en de-asserts after write_done.
    // ========================================================
    $display("\n===== TC1: GLB Iact Loaded Correctly =====");

    // Pulse turn_on: IDLE -> GLB_LOAD_ADDRESS
    turn_on = 1;
    wait_clk;
    turn_on = 0;

    // ----- TC1_A: start write address is 0 in GLB_LOAD_ADDRESS -----
    // (combinational: visible before next clock edge)
    wait_clk;
    if (ctrl_iact_start_write_addr === 8'd0) begin
        $display("  [PASS] TC1_A: iact_GLB_start_write_address = 0 in GLB_LOAD_ADDRESS");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC1_A: iact_GLB_start_write_address = %0d (expected 0)",
                 ctrl_iact_start_write_addr);
        fail_count = fail_count + 1;
    end

    // FSM now enters GLB_LOAD
    wait_clk;

    // ----- TC1_B: iact_GLB_write_en asserted in GLB_LOAD -----
    if (ctrl_iact_write_en === 1'b1) begin
        $display("  [PASS] TC1_B: iact_GLB_write_en = 1 in GLB_LOAD");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC1_B: iact_GLB_write_en = %0b (expected 1)", ctrl_iact_write_en);
        fail_count = fail_count + 1;
    end

    // ----- TC1_C: weight_GLB_write_en also asserted concurrently -----
    if (ctrl_weight_write_en === 1'b1) begin
        $display("  [PASS] TC1_C: weight_GLB_write_en = 1 in GLB_LOAD (concurrent)");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC1_C: weight_GLB_write_en = %0b (expected 1)", ctrl_weight_write_en);
        fail_count = fail_count + 1;
    end

    // TB now streams iact and weight data into the GLBs exactly as
    // glb_router_tb.v does (write_addr set, write_en asserted, data streamed,
    // write_en deasserted, wait for write_done from the real GLB SRAM).
    // Run both streams: iact first then weight (weight_done latches in controller).
    fork
        stream_iact_to_glb;
        stream_weight_to_glb;
    join

    // ----- TC1_D: write_done was received and iact_GLB_write_en now de-asserted -----
    // After both write_done signals the controller exits GLB_LOAD.
    // Give a few cycles for the FSM to react.
    timeout_cnt = 0;
    while (ctrl_iact_write_en === 1'b1 && timeout_cnt < 20) begin
        wait_clk;
        timeout_cnt = timeout_cnt + 1;
    end

    if (ctrl_iact_write_en === 1'b0) begin
        $display("  [PASS] TC1_D: iact_GLB_write_en de-asserted after IACT_write_done");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC1_D: iact_GLB_write_en still HIGH %0d cycles after write_done",
                 timeout_cnt);
        fail_count = fail_count + 1;
    end

    if (ctrl_weight_write_en === 1'b0) begin
        $display("  [PASS] TC1_E: weight_GLB_write_en de-asserted after WEIGHT_write_done");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC1_E: weight_GLB_write_en still HIGH after write_done");
        fail_count = fail_count + 1;
    end

    $display("  >> TC1 complete.");

    // ========================================================
    // TC2: Iact Done Assertion Correct
    // ========================================================
    // FSM is now at GLB_WEIGHT_READ_ADDRESS.
    // Drive through weight routing (3 cycles), assert load_PEs_weight_done
    // in ROUTE_WEIGHT_3, then verify:
    //   TC2_A: load_PEs_iact = 1 in GLB_IACT_READ_ADDRESS
    //   TC2_B: iact_GLB_read_en = 1 in GLB_IACT_READ_ADDRESS
    // Then advance ROUTE_IACT_1..5 and assert load_PEs_iact_done in
    // ROUTE_IACT_6, then verify:
    //   TC2_C: iact_GLB_write_en = 1 in PE_START_IACT_GLB_LOAD
    //   TC2_D: mac_start = 1 in PE_START_IACT_GLB_LOAD
    //   TC2_E: IACT_write_done is received (real GLB write_done)
    //   TC2_F: iact_GLB_write_en de-asserts after the background load completes
    // ========================================================
    $display("\n===== TC2: Iact Done Assertion Correct =====");

    // 3 clocks: GLB_WEIGHT_READ_ADDRESS -> RW1 -> RW2 -> now in RW3
    repeat(3) wait_clk;

    // Assert load_PEs_weight_done to exit ROUTE_WEIGHT_3
    load_PEs_weight_done = 1;
    wait_clk;
    load_PEs_weight_done = 0;

    // FSM transitions to GLB_IACT_READ_ADDRESS (one clock for state register)
    wait_clk;

    // ----- TC2_A: load_PEs_iact asserted in GLB_IACT_READ_ADDRESS -----
    if (load_PEs_iact === 1'b1) begin
        $display("  [PASS] TC2_A: load_PEs_iact = 1 in GLB_IACT_READ_ADDRESS");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC2_A: load_PEs_iact = %0b (expected 1)", load_PEs_iact);
        fail_count = fail_count + 1;
    end

    // ----- TC2_B: iact_GLB_read_en asserted in GLB_IACT_READ_ADDRESS -----
    if (ctrl_iact_read_en === 1'b1) begin
        $display("  [PASS] TC2_B: iact_GLB_read_en = 1 in GLB_IACT_READ_ADDRESS");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC2_B: iact_GLB_read_en = %0b (expected 1)", ctrl_iact_read_en);
        fail_count = fail_count + 1;
    end

    // Advance through ROUTE_IACT_1 to ROUTE_IACT_5 (5 clocks)
    repeat(5) wait_clk;

    // Now in ROUTE_IACT_6: assert load_PEs_iact_done -> FSM goes to IACT_GLB_LOAD_ADDRESS
    load_PEs_iact_done = 1;
    wait_clk;
    load_PEs_iact_done = 0;

    // IACT_GLB_LOAD_ADDRESS (1 cycle) -> PE_START_IACT_GLB_LOAD
    wait_clk;   // IACT_GLB_LOAD_ADDRESS
    wait_clk;   // PE_START_IACT_GLB_LOAD

    // ----- TC2_C: iact_GLB_write_en asserted in PE_START_IACT_GLB_LOAD -----
    if (ctrl_iact_write_en === 1'b1) begin
        $display("  [PASS] TC2_C: iact_GLB_write_en = 1 in PE_START_IACT_GLB_LOAD (background load)");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC2_C: iact_GLB_write_en = %0b (expected 1)", ctrl_iact_write_en);
        fail_count = fail_count + 1;
    end

    // ----- TC2_D: mac_start asserted in PE_START_IACT_GLB_LOAD -----
    if (mac_start === 1'b1) begin
        $display("  [PASS] TC2_D: mac_start = 1 in PE_START_IACT_GLB_LOAD");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC2_D: mac_start = %0b (expected 1)", mac_start);
        fail_count = fail_count + 1;
    end

    // TB streams the next iact column into the GLB while the PE is computing
    // (background load). This is exactly the PE_START_IACT_GLB_LOAD purpose.
    stream_iact_to_glb;

    // ----- TC2_E: IACT_write_done was received from the real GLB -----
    // (stream_iact_to_glb already waited for write_done; we just check it fired)
    if (IACT_write_done === 1'b0) begin
        // write_done is a 1-cycle pulse; it has already gone low after the wait
        $display("  [PASS] TC2_E: IACT_write_done pulsed from real GLB SRAM (background load)");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC2_E: IACT_write_done still HIGH (unexpected)");
        fail_count = fail_count + 1;
    end

    // ----- TC2_F: iact_GLB_write_en de-asserted after background load done -----
    // After IACT_write_done the controller's FSM sees the exit condition in
    // PE_START_IACT_GLB_LOAD. Also simulate mac_done pulses so
    // iact_column_done_flag rises to meet the other half of the exit condition.
    for (k = 0; k < CYCLES_PER_IACT_COL; k = k + 1) begin
        mac_done = 1;
        wait_clk;
        mac_done = 0;
        wait_clk;
    end

    timeout_cnt = 0;
    while (ctrl_iact_write_en === 1'b1 && timeout_cnt < 30) begin
        wait_clk;
        timeout_cnt = timeout_cnt + 1;
    end

    if (ctrl_iact_write_en === 1'b0) begin
        $display("  [PASS] TC2_F: iact_GLB_write_en de-asserted after background load + mac cycles");
        pass_count = pass_count + 1;
    end else begin
        $display("  [FAIL] TC2_F: iact_GLB_write_en still HIGH (%0d cycle timeout)", timeout_cnt);
        fail_count = fail_count + 1;
    end

    repeat(4) wait_clk;

    // ========================================================
    // Summary
    // ========================================================
    $display("\n========================================");
    $display("  SIMULATION COMPLETE");
    $display("  PASS: %0d   FAIL: %0d", pass_count, fail_count);
    $display("========================================\n");

    if (fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("SOME TESTS FAILED - review output above");

    $finish;
end

// ============================================================
// Timeout watchdog
// ============================================================
initial begin
    #500000;
    $display("[TIMEOUT] Simulation exceeded 500us - possible deadlock");
    $finish;
end

endmodule
