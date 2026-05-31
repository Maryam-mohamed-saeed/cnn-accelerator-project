`timescale 1ns/1ps

module Iact_Router_tb;

// ====================================================================
// Parameters
// ====================================================================
localparam UNICAST    = 3'b000;
localparam MULT_CAST  = 3'b001;
localparam HOR_CAST   = 3'b010;
localparam VER_CAST   = 3'b011;
localparam BROADCAST  = 3'b100;

localparam GLB   = 2'b00;
localparam NORTH = 2'b01;
localparam SOUTH = 2'b10;
localparam HORIZ = 2'b11;

localparam MULTICAST_1 = 3'd1;
localparam MULTICAST_2 = 3'd2;
localparam MULTICAST_3 = 3'd3;
localparam MULTICAST_4 = 3'd4;
localparam MULTICAST_5 = 3'd5;
localparam MULTICAST_6 = 3'd6;

// ====================================================================
// DUT Signals
// ====================================================================

// Source ports - GLB
wire        GLB_data_in_ready;
reg         GLB_data_in_valid;
reg  [11:0] GLB_data_in;

// Source ports - North
wire        north_data_in_ready;
reg         north_data_in_valid;
reg  [11:0] north_data_in;

// Source ports - South
wire        south_data_in_ready;
reg         south_data_in_valid;
reg  [11:0] south_data_in;

// Source ports - Horiz
wire        horiz_data_in_ready;
reg         horiz_data_in_valid;
reg  [11:0] horiz_data_in;

// Destination ports - PEs
reg  [11:0] PE_data_out_ready_arr;
wire [11:0] PE_data_out_valid_arr;

// Individual PE ready signals
reg         PE_0_data_out_ready;
reg         PE_1_data_out_ready;
reg         PE_2_data_out_ready;
reg         PE_3_data_out_ready;
reg         PE_4_data_out_ready;
reg         PE_5_data_out_ready;
reg         PE_6_data_out_ready;
reg         PE_7_data_out_ready;
reg         PE_8_data_out_ready;
reg         PE_9_data_out_ready;
reg         PE_10_data_out_ready;
reg         PE_11_data_out_ready;

// Individual PE valid/data outputs
wire        PE_0_data_out_valid;     wire [11:0] PE_0_data_out;
wire        PE_1_data_out_valid;     wire [11:0] PE_1_data_out;
wire        PE_2_data_out_valid;     wire [11:0] PE_2_data_out;
wire        PE_3_data_out_valid;     wire [11:0] PE_3_data_out;
wire        PE_4_data_out_valid;     wire [11:0] PE_4_data_out;
wire        PE_5_data_out_valid;     wire [11:0] PE_5_data_out;
wire        PE_6_data_out_valid;     wire [11:0] PE_6_data_out;
wire        PE_7_data_out_valid;     wire [11:0] PE_7_data_out;
wire        PE_8_data_out_valid;     wire [11:0] PE_8_data_out;
wire        PE_9_data_out_valid;     wire [11:0] PE_9_data_out;
wire        PE_10_data_out_valid;    wire [11:0] PE_10_data_out;
wire        PE_11_data_out_valid;    wire [11:0] PE_11_data_out;

// Directional outputs
reg         north_data_out_ready;
wire        north_data_out_valid;    wire [11:0] north_data_out;

reg         south_data_out_ready;
wire        south_data_out_valid;    wire [11:0] south_data_out;

reg         horiz_data_out_ready;
wire        horiz_data_out_valid;    wire [11:0] horiz_data_out;

// Control signals
reg  [1:0]  data_in_sel;
reg  [2:0]  data_out_sel;
reg  [3:0]  PE_sel;
reg  [11:0] PE_choice;
reg  [2:0]  Multicast_mode;

// ====================================================================
// DUT Instantiation
// ====================================================================
Iact_Router dut (
    .GLB_data_in_ready      (GLB_data_in_ready),
    .GLB_data_in_valid      (GLB_data_in_valid),
    .GLB_data_in            (GLB_data_in),

    .north_data_in_ready    (north_data_in_ready),
    .north_data_in_valid    (north_data_in_valid),
    .north_data_in          (north_data_in),

    .south_data_in_ready    (south_data_in_ready),
    .south_data_in_valid    (south_data_in_valid),
    .south_data_in          (south_data_in),

    .horiz_data_in_ready    (horiz_data_in_ready),
    .horiz_data_in_valid    (horiz_data_in_valid),
    .horiz_data_in          (horiz_data_in),

    .PE_0_data_out_ready     (PE_0_data_out_ready),     .PE_0_data_out_valid     (PE_0_data_out_valid),     .PE_0_data_out     (PE_0_data_out),
    .PE_1_data_out_ready     (PE_1_data_out_ready),     .PE_1_data_out_valid     (PE_1_data_out_valid),     .PE_1_data_out     (PE_1_data_out),
    .PE_2_data_out_ready     (PE_2_data_out_ready),     .PE_2_data_out_valid     (PE_2_data_out_valid),     .PE_2_data_out     (PE_2_data_out),
    .PE_3_data_out_ready     (PE_3_data_out_ready),     .PE_3_data_out_valid     (PE_3_data_out_valid),     .PE_3_data_out     (PE_3_data_out),
    .PE_4_data_out_ready     (PE_4_data_out_ready),     .PE_4_data_out_valid     (PE_4_data_out_valid),     .PE_4_data_out     (PE_4_data_out),
    .PE_5_data_out_ready     (PE_5_data_out_ready),     .PE_5_data_out_valid     (PE_5_data_out_valid),     .PE_5_data_out     (PE_5_data_out),
    .PE_6_data_out_ready     (PE_6_data_out_ready),     .PE_6_data_out_valid     (PE_6_data_out_valid),     .PE_6_data_out     (PE_6_data_out),
    .PE_7_data_out_ready     (PE_7_data_out_ready),     .PE_7_data_out_valid     (PE_7_data_out_valid),     .PE_7_data_out     (PE_7_data_out),
    .PE_8_data_out_ready     (PE_8_data_out_ready),     .PE_8_data_out_valid     (PE_8_data_out_valid),     .PE_8_data_out     (PE_8_data_out),
    .PE_9_data_out_ready     (PE_9_data_out_ready),     .PE_9_data_out_valid     (PE_9_data_out_valid),     .PE_9_data_out     (PE_9_data_out),
    .PE_10_data_out_ready    (PE_10_data_out_ready),    .PE_10_data_out_valid    (PE_10_data_out_valid),    .PE_10_data_out    (PE_10_data_out),
    .PE_11_data_out_ready    (PE_11_data_out_ready),    .PE_11_data_out_valid    (PE_11_data_out_valid),    .PE_11_data_out    (PE_11_data_out),

    .north_data_out_ready    (north_data_out_ready),    .north_data_out_valid    (north_data_out_valid),    .north_data_out    (north_data_out),

    .south_data_out_ready    (south_data_out_ready),    .south_data_out_valid    (south_data_out_valid),    .south_data_out    (south_data_out),

    .horiz_data_out_ready    (horiz_data_out_ready),    .horiz_data_out_valid    (horiz_data_out_valid),    .horiz_data_out    (horiz_data_out),

    .data_in_sel    (data_in_sel),
    .data_out_sel   (data_out_sel),
    .PE_sel         (PE_sel),
    .PE_choice      (PE_choice),
    .Multicast_mode (Multicast_mode)
);

// ====================================================================
// Helper Task: Set all PE ready signals at once
// ====================================================================
task set_all_pe_ready;
    input val;
    begin
        PE_0_data_out_ready  = val;
        PE_1_data_out_ready  = val;
        PE_2_data_out_ready  = val;
        PE_3_data_out_ready  = val;
        PE_4_data_out_ready  = val;
        PE_5_data_out_ready  = val;
        PE_6_data_out_ready  = val;
        PE_7_data_out_ready  = val;
        PE_8_data_out_ready  = val;
        PE_9_data_out_ready  = val;
        PE_10_data_out_ready = val;
        PE_11_data_out_ready = val;
    end
endtask

// ====================================================================
// Helper Task: Reset all inputs
// ====================================================================
task reset_inputs;
    begin
        GLB_data_in_valid      = 0; GLB_data_in      = 0;
        north_data_in_valid    = 0; north_data_in    = 0;
        south_data_in_valid    = 0; south_data_in    = 0;
        horiz_data_in_valid    = 0; horiz_data_in    = 0;

        north_data_out_ready = 1;
        south_data_out_ready = 1;
        horiz_data_out_ready = 1;

        set_all_pe_ready(1);

        data_in_sel    = GLB;
        data_out_sel   = UNICAST;
        PE_sel         = 0;
        PE_choice      = 0;
        Multicast_mode = 0;
    end
endtask

// ====================================================================
// Helper Task: Check with pass/fail message
// ====================================================================
integer pass_count;
integer fail_count;

task check;
    input        condition;
    input [400:0] test_name;
    begin
        if (condition) begin
            $display("  [PASS] %s", test_name);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] %s", test_name);
            fail_count = fail_count + 1;
        end
    end
endtask

// ====================================================================
// Test Variables
// ====================================================================
integer i;

// ====================================================================
// Main Test Body
// ====================================================================
initial begin
    pass_count = 0;
    fail_count = 0;

    reset_inputs();
    #10;

    // ----------------------------------------------------------------
    // TEST 1: Input Source Selection – GLB
    // ----------------------------------------------------------------
    $display("\n=== TEST 1: Input Source Selection (GLB) ===");
    data_in_sel          = GLB;
    data_out_sel         = UNICAST;
    PE_sel               = 4'd0;
    GLB_data_in_valid    = 1;
    GLB_data_in          = 12'hABC;
    #5;

    check(GLB_data_in_ready     == 1,    "GLB data ready when sel=GLB");
    check(north_data_in_ready   == 0,    "North data NOT ready when sel=GLB");
    check(PE_0_data_out         == 12'hABC, "GLB data routed to PE0");
    check(PE_0_data_out_valid   == 1,    "PE0 data valid asserted (UNICAST PE0)");
    check(PE_1_data_out_valid== 0,    "PE1 data valid NOT asserted (UNICAST PE0)");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 2: Input Source Selection – NORTH
    // ----------------------------------------------------------------
    $display("\n=== TEST 2: Input Source Selection (NORTH) ===");
    data_in_sel           = NORTH;
    data_out_sel          = UNICAST;
    PE_sel                = 4'd3;

    north_data_in_valid   = 1;
    north_data_in         = 12'hDEF;
    #5;

    check(north_data_in_ready == 1,    "NORTH data ready when sel=NORTH");
    check(GLB_data_in_ready   == 0,    "GLB data NOT ready when sel=NORTH");
    check(PE_3_data_out          == 12'hDEF, "NORTH data routed correctly");
    check(PE_3_data_out_valid    == 1,    "PE3 data valid (UNICAST PE3, src=NORTH)");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 3: Input Source Selection – SOUTH
    // ----------------------------------------------------------------
    $display("\n=== TEST 3: Input Source Selection (SOUTH) ===");
    data_in_sel           = SOUTH;
    data_out_sel          = UNICAST;
    PE_sel                = 4'd7;
    south_data_in_valid   = 1;
    south_data_in         = 12'h123;
    #5;

    check(south_data_in_ready == 1, "SOUTH data ready when sel=SOUTH");
    check(PE_7_data_out_valid    == 1, "PE7 data valid (UNICAST PE7, src=SOUTH)");
    check(PE_7_data_out          == 12'h123,"SOUTH data routed to PE7");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 4: Input Source Selection – HORIZ
    // ----------------------------------------------------------------
    $display("\n=== TEST 4: Input Source Selection (HORIZ) ===");
    data_in_sel           = HORIZ;
    data_out_sel          = UNICAST;
    PE_sel                = 4'd11;
    horiz_data_in_valid   = 1;
    horiz_data_in         = 12'hFFF;
    #5;

    check(horiz_data_in_ready == 1,    "HORIZ data ready when sel=HORIZ");
    check(PE_11_data_out_valid   == 1,    "PE11 data valid (UNICAST PE11, src=HORIZ)");
    check(PE_11_data_out         == 12'hFFF,"HORIZ data routed to PE11");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 5: UNICAST – all PEs individually
    // ----------------------------------------------------------------
    $display("\n=== TEST 5: UNICAST – Sweep all PE targets ===");
    data_in_sel         = GLB;
    data_out_sel        = UNICAST;
    GLB_data_in_valid   = 1;
    GLB_data_in         = 12'hA5A;

    for (i = 0; i < 12; i = i + 1) begin
        PE_sel = i[3:0];
        #5;
        // Only the selected PE should have data valid
        case(i)
            0:  check(PE_0_data_out_valid  == 1 && PE_1_data_out_valid  == 0, "UNICAST PE0 only");
            1:  check(PE_1_data_out_valid  == 1 && PE_0_data_out_valid  == 0, "UNICAST PE1 only");
            2:  check(PE_2_data_out_valid  == 1 && PE_3_data_out_valid  == 0, "UNICAST PE2 only");
            3:  check(PE_3_data_out_valid  == 1 && PE_2_data_out_valid  == 0, "UNICAST PE3 only");
            4:  check(PE_4_data_out_valid  == 1 && PE_5_data_out_valid  == 0, "UNICAST PE4 only");
            5:  check(PE_5_data_out_valid  == 1 && PE_4_data_out_valid  == 0, "UNICAST PE5 only");
            6:  check(PE_6_data_out_valid  == 1 && PE_7_data_out_valid  == 0, "UNICAST PE6 only");
            7:  check(PE_7_data_out_valid  == 1 && PE_6_data_out_valid  == 0, "UNICAST PE7 only");
            8:  check(PE_8_data_out_valid  == 1 && PE_9_data_out_valid  == 0, "UNICAST PE8 only");
            9:  check(PE_9_data_out_valid  == 1 && PE_8_data_out_valid  == 0, "UNICAST PE9 only");
            10: check(PE_10_data_out_valid == 1 && PE_11_data_out_valid == 0, "UNICAST PE10 only");
            11: check(PE_11_data_out_valid == 1 && PE_10_data_out_valid == 0, "UNICAST PE11 only");
        endcase
    end
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 6: MULTICAST – PE_choice bitmask
    // ----------------------------------------------------------------
    $display("\n=== TEST 6: MULTICAST – bitmask PE_choice ===");
    data_in_sel          = GLB;
    data_out_sel         = MULT_CAST;
    GLB_data_in_valid    = 1;
    GLB_data_in          = 12'hBEE;
    Multicast_mode       = MULTICAST_2;

    // Select PEs 1, 4
    PE_choice = 12'b0000_0001_0010;
    #5;
    check(PE_4_data_out_valid  == 1, "MULTICAST: PE4 valid (bit 4 set)");
    check(PE_2_data_out_valid  == 0, "MULTICAST: PE2 NOT valid (bit 2 clear)");
    check(PE_3_data_out_valid  == 0, "MULTICAST: PE3 NOT valid (bit 3 clear)");
    check(PE_5_data_out_valid  == 0, "MULTICAST: PE5 NOT valid (bit 5 clear)");
    check(PE_1_data_out_valid     == 1, "MULTICAST: PE1 data valid");
    check(PE_4_data_out           == 12'hBEE, "MULTICAST: data value correct on PE4");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 7: HOR_CAST
    // ----------------------------------------------------------------
    $display("\n=== TEST 7: HOR_CAST ===");
    data_in_sel          = GLB;
    data_out_sel         = HOR_CAST;
    GLB_data_in_valid    = 1;
    GLB_data_in          = 12'hCAF;
    #5;

    check(horiz_data_out_valid    == 1,    "HOR_CAST: horiz data valid");
    check(horiz_data_out          == 12'hCAF,"HOR_CAST: data value correct");
    check(north_data_out_valid == 0,    "HOR_CAST: north NOT valid");
    check(south_data_out_valid == 0,    "HOR_CAST: south NOT valid");
    check(PE_0_data_out_valid  == 0,    "HOR_CAST: PE0 NOT valid");
    // horiz ready drives internal_data_ready -> GLB_data_in_ready
    check(GLB_data_in_ready    == 1,    "HOR_CAST: GLB in_ready reflects horiz out_ready");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 8: VER_CAST
    // ----------------------------------------------------------------
    $display("\n=== TEST 8: VER_CAST ===");
    data_in_sel          = GLB;
    data_out_sel         = VER_CAST;
    GLB_data_in_valid    = 1;
    GLB_data_in          = 12'hBAD;
    #5;

    check(north_data_out_valid    == 1,    "VER_CAST: north data valid");
    check(south_data_out_valid    == 1,    "VER_CAST: south data valid");
    check(south_data_out          == 12'hBAD,"VER_CAST: south data value correct");
    check(horiz_data_out_valid == 0,    "VER_CAST: horiz NOT valid");
    check(PE_5_data_out_valid  == 0,    "VER_CAST: PE5 NOT valid");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 9: BROADCAST
    // ----------------------------------------------------------------
    $display("\n=== TEST 9: BROADCAST ===");
    data_in_sel          = GLB;
    data_out_sel         = BROADCAST;
    GLB_data_in_valid    = 1;
    GLB_data_in          = 12'hFED;
    #5;

    check(PE_5_data_out_valid  == 1, "BROADCAST: PE5 valid");
    check(PE_11_data_out_valid == 1, "BROADCAST: PE11 valid");
    check(north_data_out_valid == 1, "BROADCAST: north valid");
    check(south_data_out_valid == 1, "BROADCAST: south valid");
    check(horiz_data_out_valid == 1, "BROADCAST: horiz valid");
    check(PE_0_data_out_valid     == 1, "BROADCAST: PE0 data valid");
    check(north_data_out_valid    == 1, "BROADCAST: north data valid");
    check(south_data_out          == 12'hFED,"BROADCAST: data value correct on south");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 10: Back-pressure – UNICAST PE0 not ready
    // ----------------------------------------------------------------
    $display("\n=== TEST 10: Back-pressure (UNICAST PE0 not ready) ===");
    data_in_sel          = GLB;
    data_out_sel         = UNICAST;
    PE_sel               = 4'd0;
    PE_0_data_out_ready    = 0;
    GLB_data_in_valid    = 1;
    #5;

    check(GLB_data_in_ready    == 0, "Back-pressure: GLB data NOT ready when PE0 not ready");

    // Now assert PE0 ready
    PE_0_data_out_ready    = 1;
    #5;
    check(GLB_data_in_ready == 1, "Back-pressure: GLB addr ready restored");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 11: Back-pressure – BROADCAST (one PE not ready blocks all)
    // ----------------------------------------------------------------
    $display("\n=== TEST 11: Back-pressure (BROADCAST, PE6 not ready) ===");
    data_in_sel          = GLB;
    data_out_sel         = BROADCAST;
    GLB_data_in_valid    = 1;
    PE_6_data_out_ready    = 0;
    #5;

    check(GLB_data_in_ready    == 0, "Back-pressure BROADCAST: data blocked when PE6 not ready");

    PE_6_data_out_ready    = 1;
    #5;
    check(GLB_data_in_ready == 1, "Back-pressure BROADCAST: unblocked after PE6 ready");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 12: Back-pressure – HOR_CAST horiz_out not ready
    // ----------------------------------------------------------------
    $display("\n=== TEST 12: Back-pressure (HOR_CAST, horiz not ready) ===");
    data_in_sel             = GLB;
    data_out_sel            = HOR_CAST;
    GLB_data_in_valid       = 1;
    horiz_data_out_ready    = 0;
    #5;

    check(GLB_data_in_ready    == 0, "Back-pressure HOR_CAST: data blocked");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 13: Source mux isolation – only selected source drives valid
    // ----------------------------------------------------------------
    $display("\n=== TEST 13: Source isolation – invalid sources don't bleed through ===");
    data_in_sel           = SOUTH;
    data_out_sel          = UNICAST;
    PE_sel                = 4'd4;
    // Drive all sources valid
    GLB_data_in_valid  = 1; GLB_data_in  = 12'h001;
    north_data_in_valid= 1; north_data_in= 12'h002;
    south_data_in_valid= 1; south_data_in= 12'h003;
    horiz_data_in_valid= 1; horiz_data_in= 12'h004;
    #5;

    check(PE_4_data_out    == 12'h003, "Source isolation: SOUTH data selected");
    check(PE_4_data_out_valid == 1, "Source isolation: PE4 valid from SOUTH");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // TEST 14: MULTICAST ready logic (MULTICAST_3 mode)
    // ----------------------------------------------------------------
    $display("\n=== TEST 14: MULTICAST back-pressure (MULTICAST_3 mode) ===");
    data_in_sel          = GLB;
    data_out_sel         = MULT_CAST;
    Multicast_mode       = MULTICAST_3;  // checks PEs 2, 5, 8
    PE_choice            = 12'b0001_0010_0100;
    GLB_data_in_valid = 1;
    // PE5 not ready
    PE_5_data_out_ready = 0;
    #5;
    check(GLB_data_in_ready == 0, "MULTICAST_3: blocked when PE5 not ready");

    PE_5_data_out_ready = 1;
    #5;
    check(GLB_data_in_ready == 1, "MULTICAST_3: unblocked when all ready");
    reset_inputs(); #5;

    // ----------------------------------------------------------------
    // Summary
    // ----------------------------------------------------------------
    #20;
    $display("\n========================================");
    $display("  RESULTS: %0d passed, %0d failed", pass_count, fail_count);
    $display("========================================\n");

    if (fail_count == 0)
        $display("ALL TESTS PASSED");
    else
        $display("SOME TESTS FAILED – review output above");

    $stop;
end

// ====================================================================
// Timeout watchdog
// ====================================================================
initial begin
    #50000;
    $display("TIMEOUT: simulation exceeded limit");
    $stop;
end

// ====================================================================
// Waveform dump (comment out if not needed)
// ====================================================================
initial begin
    $dumpfile("iact_router_tb.vcd");
    $dumpvars(0, Iact_Router_tb);
end

endmodule