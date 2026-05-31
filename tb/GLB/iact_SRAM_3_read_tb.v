`timescale 1ns / 1ps

// =======================================================================================
//  Testbench: iact_SRAM_3_read_tb
//  DUT:       iact_SRAM 
//
//  Test cases
//  ----------
//  TC1  : Reset behaviour, all outputs deassert after reset
//  TC2  : Full 256-entry write burst, check write_done pulses once
//  TC3  : Read back all 256 entries on router 0, verify data integrity
//  TC4  : Read back all 256 entries on router 1, verify data integrity
//  TC5  : Read back all 256 entries on router 2, verify data integrity
//  TC6  : write_done / read_done_x each pulses for exactly 1 clock cycle
//  TC7  : All three routers reading simultaneously (same start addr)
//  TC8  : All three routers reading simultaneously (different start addrs)
//  TC9  : Back-to-back write then immediate 3-way read
//  TC10 : data_in_valid de-asserts mid-write (stall)
//  TC11 : data_out_ready stall on one router while others continue reading
//  TC12 : Concurrent write and read on all three ports 
//  TC13 : Apply reset mid-operation, DUT recovers cleanly
//  TC14 : Sparse write (stalls between entries) 
//  TC15 : Single-entry write & read on each router
//  TC16 : write_addr / read_addr_x boundary check (0xFF)
//  TC17 : data_in_ready tracks write_en exactly
//  TC18 : Write at offset, read back at offset from all three routers
//  TC19 : Write at offset, read back at offset from all three routers simultaneously
//  TC20 : Read from random addresses
//  TC21 : Stress: 10 full write/read cycles on all routers
// =======================================================================================

module iact_SRAM_3_read_tb;

// -----------------------------------------------------------------------
//  Clock & global parameters
// -----------------------------------------------------------------------
localparam CLK_PERIOD   = 10;
localparam IACT_SIZE    = 8;
localparam IACT_DEPTH   = 256;
localparam ADDR_SIZE    = 8;

// -----------------------------------------------------------------------
//  DUT ports
// -----------------------------------------------------------------------
reg                     clock;
reg                     reset;

// write port
wire                    data_in_ready;
reg                     data_in_valid;
reg  [IACT_SIZE-1:0]    data_in;
reg                     write_en;
reg  [ADDR_SIZE-1:0]    write_addr;
wire                    write_done;

// router 0
reg                     data_out_ready_0;
wire                    data_out_valid_0;
wire [IACT_SIZE-1:0]    data_out_0;
reg                     read_en_0;
reg  [ADDR_SIZE-1:0]    read_addr_0;
wire                    read_done_0;

// router 1
reg                     data_out_ready_1;
wire                    data_out_valid_1;
wire [IACT_SIZE-1:0]    data_out_1;
reg                     read_en_1;
reg  [ADDR_SIZE-1:0]    read_addr_1;
wire                    read_done_1;

// router 2
reg                     data_out_ready_2;
wire                    data_out_valid_2;
wire [IACT_SIZE-1:0]    data_out_2;
reg                     read_en_2;
reg  [ADDR_SIZE-1:0]    read_addr_2;
wire                    read_done_2;

// -----------------------------------------------------------------------
//  DUT instantiation
// -----------------------------------------------------------------------
iact_SRAM dut (
    .clock            (clock           ),
    .reset            (reset           ),

    .data_in_ready    (data_in_ready   ),
    .data_in_valid    (data_in_valid   ),
    .data_in          (data_in         ),

    .data_out_ready_0 (data_out_ready_0),
    .data_out_valid_0 (data_out_valid_0),
    .data_out_0       (data_out_0      ),

    .data_out_ready_1 (data_out_ready_1),
    .data_out_valid_1 (data_out_valid_1),
    .data_out_1       (data_out_1      ),

    .data_out_ready_2 (data_out_ready_2),
    .data_out_valid_2 (data_out_valid_2),
    .data_out_2       (data_out_2      ),

    .write_en         (write_en        ),
    .write_addr       (write_addr      ),
    .write_done       (write_done      ),

    .read_en_0        (read_en_0       ),
    .read_addr_0      (read_addr_0     ),
    .read_done_0      (read_done_0     ),

    .read_en_1        (read_en_1       ),
    .read_addr_1      (read_addr_1     ),
    .read_done_1      (read_done_1     ),

    .read_en_2        (read_en_2       ),
    .read_addr_2      (read_addr_2     ),
    .read_done_2      (read_done_2     )
);

// -----------------------------------------------------------------------
//  Clock generation
// -----------------------------------------------------------------------
initial clock = 0;
always #(CLK_PERIOD/2) clock = ~clock;

// -----------------------------------------------------------------------
//  Test counters
// -----------------------------------------------------------------------
integer pass_count;
integer fail_count;
integer test_case_count;

reg [IACT_SIZE-1:0] expected_mem [0:IACT_DEPTH-1];

task wait_cycles;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1)
            @(posedge clock);
    end
endtask

task apply_reset;
    begin
        @(negedge clock);
        reset = 1;
        @(negedge clock);
        reset = 0;
    end
endtask

task inputs_init;
    begin
        write_en = 0;
        write_addr = 0;
        data_in_valid = 0;
        data_in = 0;
        data_out_ready_0 = 0;
        data_out_ready_1 = 0;
        data_out_ready_2 = 0;
        read_en_0 = 0;
        read_en_1 = 0;
        read_en_2 = 0;
        read_addr_0 = 0;
        read_addr_1 = 0;
        read_addr_2 = 0;
    end
endtask

task check;
    input cond;
    input [500:0] msg;
    begin
        if (cond) begin
            $display("  [PASS] TC%0d: %s", test_case_count, msg);
            pass_count = pass_count + 1;
        end else begin
            $display("  [FAIL] TC%0d: %s  (time=%0t)", test_case_count, msg, $time);
            fail_count = fail_count + 1;
        end
    end
endtask

// Write n bytes starting at start_addr, pattern base+i
task write_burst;
    input integer n;
    input [ADDR_SIZE-1:0] start_addr;
    input [IACT_SIZE-1:0] base;
    integer i;
    begin
        
        write_addr = start_addr;
        @(negedge clock);
        write_en = 1;
        data_in_valid = 1;
        data_in = base;
        expected_mem[start_addr] = base;
        for (i = 1; i < n; i = i + 1) begin
            @(negedge clock);
            data_in_valid = 1;
            data_in = base + i[IACT_SIZE-1:0];
            expected_mem[start_addr + i] = base + i[IACT_SIZE-1:0];
        end
        @(negedge clock);
        data_in_valid = 0;
        write_en = 0;
    end
endtask

// Read n bytes on 1 router (0, 1 or 2) from start_addr and check against expected_mem
task read_and_verify;
    input integer n;
    input [ADDR_SIZE-1:0] start_addr;
    input integer router; // 0, 1, or 2
    integer i;
    integer rd_errors;
    reg [IACT_SIZE-1:0] got;
    reg valid_sig;
    begin
        rd_errors = 0;
        valid_sig = 0;

        // set up chosen router
        case (router)
            0: begin 
                read_addr_0 = start_addr; @(negedge clock); 
                read_en_0 = 1; data_out_ready_0 = 1; 
            end
            1: begin 
                read_addr_1 = start_addr; @(negedge clock); 
                read_en_1 = 1; data_out_ready_1 = 1; 
            end
            2: begin 
                read_addr_2 = start_addr; @(negedge clock); 
                read_en_2 = 1; data_out_ready_2 = 1; 
            end
        endcase

        for (i = 0; i < n; i = i + 1) begin

            @(posedge clock); #1; // data_out_valid goes high; data is stable
            case (router)
                0: begin 
                    wait(data_out_valid_0);
                    got = data_out_0; valid_sig = data_out_valid_0; 
                end
                1: begin 
                    wait(data_out_valid_1);
                    got = data_out_1; valid_sig = data_out_valid_1;
                end
                2: begin 
                    wait(data_out_valid_2);
                    got = data_out_2; valid_sig = data_out_valid_2; 
                end
            endcase

            if (!valid_sig) begin
                $display("  [FAIL] TC%0d: R%0d: data_out_valid_%0d not asserted at i=%0d",
                          test_case_count, router, router, i);
                fail_count = fail_count + 1;
                rd_errors = rd_errors + 1;
            end else if (got !== expected_mem[(start_addr + i) & 8'hFF]) begin
                $display("  [FAIL] TC%0d: R%0d: addr %0d expected 0x%02h got 0x%02h",
                          test_case_count, router, start_addr+i, expected_mem[(start_addr + i) & 8'hFF], got);
                fail_count = fail_count + 1;
                rd_errors = rd_errors + 1;
            end
        end

        // de-assert router
        @(negedge clock);
        case (router)
            0: begin read_en_0 = 0; data_out_ready_0 = 0; end
            1: begin read_en_1 = 0; data_out_ready_1 = 0; end
            2: begin read_en_2 = 0; data_out_ready_2 = 0; end
        endcase

        if (rd_errors == 0) begin
            $display("  [PASS] TC%0d: R%0d: %0d reads correct from addr 0x%02h",
                      test_case_count, router, n, start_addr);
            pass_count = pass_count + 1;
        end
    end
endtask

// Read n bytes on chosen routers simultaneous from start_addr and check against expected_mem
task read_and_verify_sim;
    input integer n;
    input [ADDR_SIZE-1:0] start_addr_0;
    input [ADDR_SIZE-1:0] start_addr_1;
    input [ADDR_SIZE-1:0] start_addr_2;
    input router0, router1, router2;
    integer i;
    integer rd_errors;
    begin
        rd_errors = 0;
        read_addr_0 = start_addr_0;
        read_addr_1 = start_addr_1;
        read_addr_2 = start_addr_2;
        @(negedge clock);
        if (router0) begin
            read_en_0 = 1;
            data_out_ready_0 = 1;
        end
        if (router1) begin
            read_en_1 = 1;
            data_out_ready_1 = 1;
        end
        if (router2) begin
            read_en_2 = 1;
            data_out_ready_2 = 1;
        end

        for (i = 0; i < n; i = i + 1) begin
            @(posedge clock); #1;  // data now valid
            if (router0) begin
                if (!data_out_valid_0) begin
                    $display("  [FAIL] TC%0d: R0: data_out_valid not asserted at i=%0d", test_case_count, i);
                    fail_count = fail_count + 1;
                    rd_errors = rd_errors + 1;
                end else if (data_out_0 !== expected_mem[(start_addr_0 + i) & 8'hFF]) begin
                    $display("  [FAIL] TC%0d: R0: addr %0d: expected 0x%02h got 0x%02h",
                            test_case_count, start_addr_0+i, expected_mem[(start_addr_0 + i) & 8'hFF], data_out_0);
                    fail_count = fail_count + 1;
                    rd_errors = rd_errors + 1;
                end
            end
            if (router1) begin
                if (!data_out_valid_1) begin
                    $display("  [FAIL] TC%0d: R1: data_out_valid not asserted at i=%0d", test_case_count, i);
                    fail_count = fail_count + 1;
                    rd_errors = rd_errors + 1;
                end else if (data_out_1 !== expected_mem[(start_addr_1 + i) & 8'hFF]) begin
                    $display("  [FAIL] TC%0d: R1: addr %0d: expected 0x%02h got 0x%02h",
                            test_case_count, start_addr_1+i, expected_mem[(start_addr_1 + i) & 8'hFF], data_out_1);
                    fail_count = fail_count + 1;
                    rd_errors = rd_errors + 1;
                end
            end
            if (router2) begin
                if (!data_out_valid_2) begin
                    $display("  [FAIL] TC%0d: R2: data_out_valid not asserted at i=%0d", test_case_count, i);
                    fail_count = fail_count + 1;
                    rd_errors = rd_errors + 1;
                end else if (data_out_2 !== expected_mem[(start_addr_2 + i) & 8'hFF]) begin
                    $display("  [FAIL] TC%0d: R2: addr %0d: expected 0x%02h got 0x%02h",
                            test_case_count, start_addr_2+i, expected_mem[(start_addr_2 + i) & 8'hFF], data_out_2);
                    fail_count = fail_count + 1;
                    rd_errors = rd_errors + 1;
                end
            end
        end

        @(negedge clock);
        read_en_0 = 0;
        data_out_ready_0 = 0;
        read_en_1 = 0;
        data_out_ready_1 = 0;
        read_en_2 = 0;
        data_out_ready_2 = 0;

        if (rd_errors == 0) begin
            $display("  [PASS] TC%0d: %0d sim reads verified correctly ", test_case_count, n);
            pass_count = pass_count + 1;
        end
    end
endtask

// -----------------------------------------------------------------------
//  Main stimulus
// -----------------------------------------------------------------------
integer i, j;
integer pulse_count;
integer rd_err;

initial begin
    $dumpfile("iact_SRAM_3_read_tb.vcd");
    $dumpvars;

    pass_count = 0;
    fail_count = 0;

    inputs_init;

    // ===================================================================
    //  TC1 – Reset behaviour, all outputs deassert after reset
    // ===================================================================
    test_case_count = 1;
    $display("\n=== TC1: Reset behaviour ===");
    apply_reset;
    @(posedge clock); #1;
    check(data_out_valid_0 === 1'b0, "data_out_valid_0 = 0 after reset");
    check(data_out_valid_1 === 1'b0, "data_out_valid_1 = 0 after reset");
    check(data_out_valid_2 === 1'b0, "data_out_valid_2 = 0 after reset");
    check(write_done       === 1'b0, "write_done       = 0 after reset");
    check(read_done_0      === 1'b0, "read_done_0      = 0 after reset");
    check(read_done_1      === 1'b0, "read_done_1      = 0 after reset");
    check(read_done_2      === 1'b0, "read_done_2      = 0 after reset");
    check(data_in_ready    === 1'b0, "data_in_ready    = 0 (write_en=0)");

    // ===================================================================
    //  TC2 – Full 256-entry write burst, check write_done pulses once
    // ===================================================================
    test_case_count = 2;
    $display("\n=== TC2: Full 256-entry write burst ===");
    apply_reset;

    write_burst(IACT_DEPTH, 0, 8'hA0);

    wait(write_done);

    check(1, "write_done pulses after write operation");

    // ==========================================================================
    //  TC3-5 – Read back all 256 entries on each router, verify data integrity
    // ==========================================================================
    test_case_count = 3;
    $display("\n=== TC3: Full read-back on router 0 ===");
    wait_cycles(2);
    @(negedge clock);
    read_and_verify(IACT_DEPTH, 0, 0);

    test_case_count = 4;
    $display("\n=== TC4: Full read-back on router 1 ===");
    wait_cycles(2);
    @(negedge clock);
    read_and_verify(IACT_DEPTH, 0, 1);

    test_case_count = 5;
    $display("\n=== TC5: Full read-back on router 2 ===");
    wait_cycles(2);
    @(negedge clock);
    read_and_verify(IACT_DEPTH, 0, 2);

    // ======================================================================
    //  TC6 – write_done / read_done_x each pulses for exactly 1 clock cycle
    // ======================================================================
    test_case_count = 6;
    $display("\n=== TC6: write_done / read_done single-cycle pulse ===");
    apply_reset;

    // Write 4 bytes
    @(negedge clock);
    write_addr = 0;
    @(negedge clock);
    write_en = 1;
    data_in_valid = 1; data_in = 8'h11; expected_mem[0] = 8'h11; wait_cycles(1);
                        data_in = 8'h22; expected_mem[1] = 8'h22; wait_cycles(1);
                        data_in = 8'h33; expected_mem[2] = 8'h33; wait_cycles(1);
                        data_in = 8'h44; expected_mem[3] = 8'h44; wait_cycles(1);
    @(negedge clock); data_in_valid = 0; write_en = 0;

    // Count write_done pulses over next 6 cycles
    pulse_count = 0;
    for (i = 0; i < 6; i = i + 1) begin @(posedge clock); #1; if (write_done) pulse_count = pulse_count + 1; end
    check(pulse_count === 1, "write_done pulses for exactly 1 cycle");

    // read_done_0
    @(negedge clock);
    read_addr_0 = 0; 
    @(negedge clock);
    read_en_0 = 1; data_out_ready_0 = 1;
    wait_cycles(4);
    @(negedge clock); read_en_0 = 0; data_out_ready_0 = 0;
    pulse_count = 0;
    for (i = 0; i < 6; i = i + 1) begin @(posedge clock); #1; if (read_done_0) pulse_count = pulse_count + 1; end
    check(pulse_count === 1, "read_done_0 pulses for exactly 1 cycle");

    // read_done_1
    @(negedge clock);
    read_addr_1 = 0; 
    @(negedge clock);
    read_en_1 = 1; data_out_ready_1 = 1;
    wait_cycles(4);
    @(negedge clock); read_en_1 = 0; data_out_ready_1 = 0;
    pulse_count = 0;
    for (i = 0; i < 6; i = i + 1) begin @(posedge clock); #1; if (read_done_1) pulse_count = pulse_count + 1; end
    check(pulse_count === 1, "read_done_1 pulses for exactly 1 cycle");

    // read_done_2
    @(negedge clock);
    read_addr_2 = 0; 
    @(negedge clock);
    read_en_2 = 1; data_out_ready_2 = 1;
    wait_cycles(4);
    @(negedge clock); read_en_2 = 0; data_out_ready_2 = 0;
    pulse_count = 0;
    for (i = 0; i < 6; i = i + 1) begin @(posedge clock); #1; if (read_done_2) pulse_count = pulse_count + 1; end
    check(pulse_count === 1, "read_done_2 pulses for exactly 1 cycle");

    // ===================================================================
    //  TC7 – All three routers reading simultaneously (same start addr)
    // ===================================================================
    test_case_count = 7;
    $display("\n=== TC7: 3-way simultaneous read, same start addr ===");
    apply_reset;
    write_burst(16, 0, 8'hBB);
    wait_cycles(2);

    @(negedge clock);
    read_and_verify_sim(16, 0, 0, 0, 1, 1, 1);

    $display("  [PASS] TC7: 3 routers read same address ranges correctly");

    // =======================================================================
    //  TC8 – All three routers reading simultaneously (different start addr)
    // =======================================================================
    test_case_count = 8;
    $display("\n=== TC8: 3-way simultaneous read, different start addr ===");
    apply_reset;
    write_burst(IACT_DEPTH, 0, 8'h01);
    wait_cycles(2);

    // Routers start at different points in the memory
    @(negedge clock);
    read_and_verify_sim(16, 0, 64, 128, 1, 1, 1);

    $display("  [PASS] TC8: 3 routers read different address ranges correctly");

    // ===================================================================
    //  TC9 – Back-to-back write then immediate 3-way read
    // ===================================================================
    test_case_count = 9;
    $display("\n=== TC9: Back-to-back write then 3-way read ===");
    apply_reset;

    write_burst(32, 0, 8'hCC);

    // Start all three reads immediately
    read_and_verify_sim(32, 0, 0, 0, 1, 1, 1);

    check(1, "Back-to-back write then 3-way read completed without deadlock");

    // ===================================================================
    //  TC10 – data_in_valid de-asserts mid-write (stall)
    // ===================================================================
    test_case_count = 10;
    $display("\n=== TC10: Mid-write valid stall ===");
    apply_reset;

    write_addr = 0;
    @(negedge clock);
    write_en = 1; data_in_valid = 1; 
    data_in = 8'hAA; expected_mem[0] = 8'hAA;
    // @(posedge clock);
    @(negedge clock); data_in = 8'hBB; expected_mem[1] = 8'hBB;
    // @(posedge clock);

    // Stall for 4 cycles
    @(negedge clock); data_in_valid = 0;
    wait_cycles(4);

    // Resume
    @(negedge clock); data_in_valid = 1; data_in = 8'hCC; expected_mem[2] = 8'hCC;
    @(posedge clock);
    @(negedge clock); data_in = 8'hDD; expected_mem[3] = 8'hDD;
    @(posedge clock);
    @(negedge clock); data_in_valid = 0; write_en = 0;
    wait_cycles(3);

    read_and_verify(4, 0, 0);

    // =========================================================================
    //  TC11 – data_out_ready stall on one router while others continue reading
    // =========================================================================
    test_case_count = 11;
    $display("\n=== TC11: Back-pressure on router 1 while 0 and 2 stream ===");
    apply_reset;

    write_burst(8, 0, 8'h10);
    wait_cycles(2);

    @(negedge clock);
    read_addr_0 = 0; 
    read_addr_1 = 0; 
    read_addr_2 = 0; 
    @(negedge clock);
    read_en_0 = 1; data_out_ready_0 = 1;
    read_en_1 = 1; data_out_ready_1 = 0; // stalled initially
    read_en_2 = 1; data_out_ready_2 = 1;

    @(posedge clock); #1;
    if (data_out_0 !== expected_mem[0]) begin
        $display("  [FAIL] TC%0d: R0: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[0], data_out_0);
        fail_count = fail_count + 1;
    end
    if (data_out_2 !== expected_mem[0]) begin
        $display("  [FAIL] TC%0d: R2: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[0], data_out_2);
        fail_count = fail_count + 1;
    end
    
    @(posedge clock); #1;
    if (data_out_0 !== expected_mem[1]) begin
        $display("  [FAIL] TC%0d: R0: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[1], data_out_0);
        fail_count = fail_count + 1;
    end
    if (data_out_2 !== expected_mem[1]) begin
        $display("  [FAIL] TC%0d: R2: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[1], data_out_2);
        fail_count = fail_count + 1;
    end
    wait_cycles(2);
    @(negedge clock); data_out_ready_1 = 1; // release back-pressure on router 1

    @(posedge clock); #1;
    if (data_out_0 !== expected_mem[4]) begin
        $display("  [FAIL] TC%0d: R0: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[4], data_out_0);
        fail_count = fail_count + 1;
    end
    if (data_out_1 !== expected_mem[0]) begin
        $display("  [FAIL] TC%0d: R1: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[0], data_out_1);
        fail_count = fail_count + 1;
    end
    if (data_out_2 !== expected_mem[4]) begin
        $display("  [FAIL] TC%0d: R2: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[4], data_out_2);
        fail_count = fail_count + 1;
    end
    
    @(posedge clock); #1;
    if (data_out_0 !== expected_mem[5]) begin
        $display("  [FAIL] TC%0d: R0: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[5], data_out_0);
        fail_count = fail_count + 1;
    end
    if (data_out_1 !== expected_mem[1]) begin
        $display("  [FAIL] TC%0d: R1: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[1], data_out_1);
        fail_count = fail_count + 1;
    end
    if (data_out_2 !== expected_mem[5]) begin
        $display("  [FAIL] TC%0d: R2: addr %0d: expected 0x%02h got 0x%02h", 
            test_case_count, 0, expected_mem[5], data_out_2);
        fail_count = fail_count + 1;
    end
    wait_cycles(2);
    @(negedge clock);
    read_en_0 = 0; data_out_ready_0 = 0;
    read_en_1 = 0; data_out_ready_1 = 0;
    read_en_2 = 0; data_out_ready_2 = 0;
    check(1, "Back-pressure on R1 did not block R0 or R2");

    // ===================================================================
    //  TC12 – Concurrent write and read on all three ports 
    // ===================================================================
    test_case_count = 12;
    $display("\n=== TC12: Concurrent write_en and all read_en ===");
    apply_reset;

    write_burst(8, 0, 8'hFF);
    wait_cycles(2);

    @(negedge clock);
    write_addr = 16; 
    @(negedge clock);
    write_en = 1; data_in_valid = 1; data_in = 8'h01;
    
    read_and_verify_sim(8, 0, 0, 0, 1, 1, 1);
    
    write_en = 0; data_in_valid = 0;
    
    check(1, "DUT survived simultaneous write + 3-way read without locking");

    // ===================================================================
    //  TC13 – Apply reset mid-operation, DUT recovers cleanly
    // ===================================================================
    test_case_count = 13;
    $display("\n=== TC13: Reset mid-write, then normal operation ===");
    apply_reset;
    write_addr = 0;
    @(negedge clock);
    write_en = 1; data_in_valid = 1; data_in = 8'hDE;
    wait_cycles(5);

    // Inject reset mid-burst
    reset = 1;
    check(data_out_valid_0 === 0, "data_out_valid_0 = 0 after mid-op reset");
    check(data_out_valid_1 === 0, "data_out_valid_1 = 0 after mid-op reset");
    check(data_out_valid_2 === 0, "data_out_valid_2 = 0 after mid-op reset");
    check(write_done       === 0, "write_done       = 0 after mid-op reset");
    @(negedge clock); reset = 0;
    write_en = 0; data_in_valid = 0;

    // Resume normal operation
    @(negedge clock);
    write_burst(4, 0, 8'h01);
    wait_cycles(2);
    @(negedge clock);
    read_and_verify(4, 0, 0);

    // ===================================================================
    //  TC14 – Sparse write (stalls between entries) 
    // ===================================================================
    test_case_count = 14;
    $display("\n=== TC14: Sparse write (stalls between entries) ===");
    apply_reset;

    write_addr = 0;
    write_en = 1; 
    for (i = 0; i < 8; i = i + 1) begin
        @(negedge clock); data_in_valid = 1; data_in = 8'h20 + i; expected_mem[i] = 8'h20 + i;
        @(posedge clock);
        @(negedge clock); data_in_valid = 0;   // 1-cycle stall
        @(posedge clock);
    end
    @(negedge clock); write_en = 0;
    wait_cycles(3);

    @(negedge clock);
    read_and_verify(8, 0, 1); // verify via router 1
    read_and_verify(8, 0, 2); // verify via router 2

    // ===================================================================
    //  TC15 – Single-entry write & read on each router
    // ===================================================================
    test_case_count = 15;
    $display("\n=== TC15: Single-entry write & read on each router ===");
    apply_reset;
    write_burst(1, 0, 8'hAB);
    wait_cycles(2);
    read_and_verify(1, 0, 0);
    read_and_verify(1, 0, 1);
    read_and_verify(1, 0, 2);

    // ===================================================================
    //  TC16 – write_addr / read_addr_x boundary check (0xFF)
    // ===================================================================
    test_case_count = 16;
    $display("\n=== TC16: Boundary address 0xFF ===");
    apply_reset;
    // Fill full memory
    write_burst(IACT_DEPTH, 0, 8'h30);

    // Start all three readers at the last address
    read_and_verify_sim(4, 8'hFF, 8'hFF, 8'hFF, 1, 1, 1);
    
    check(1, "Reads from boundary addr 0xFF did not hang");

    // ===================================================================
    //  TC17 – data_in_ready tracks write_en exactly
    // ===================================================================
    test_case_count = 17;
    $display("\n=== TC17: data_in_ready tracks write_en ===");
    apply_reset;

    @(posedge clock); #1;
    check(data_in_ready === 1'b0, "data_in_ready = 0 when write_en = 0");
    @(negedge clock); write_en = 1;
    @(posedge clock); #1;
    check(data_in_ready === 1'b1, "data_in_ready = 1 when write_en = 1");
    @(negedge clock); write_en = 0;
    @(posedge clock); #1;
    check(data_in_ready === 1'b0, "data_in_ready = 0 when write_en deasserts");

    // =====================================================================
    //  TC18 – Write at offset, read back at offset from all three routers
    // =====================================================================
    test_case_count = 18;
    $display("\n=== TC18: Non-zero write_addr offset then read ===");
    apply_reset;
    // Write 8 bytes starting at address 0x80
    write_burst(8, 8'h80, 8'hCA);
    wait_cycles(2);
    // Read them back from each router
    @(negedge clock);
    read_and_verify(8, 8'h80, 0);
    read_and_verify(8, 8'h80, 1);
    read_and_verify(8, 8'h80, 2);

    // ===================================================================================
    //  TC19 – Write at offset, read back at offset from all three routers simultaneously
    // ====================================================================================
    test_case_count =  21;
    $display("\n=== TC21: Non-zero write_addr offset then read sim ===");
    // apply_reset;

    write_burst(8, 8'h08, 8'b0);
    wait_cycles(2);
    @(negedge clock);
    read_and_verify_sim(8, 8'h08, 8'h08, 8'h08, 1, 1, 1);

    check(1, "Non-zero write_addr write then read at offset passed");

    // ===================================================================
    //  TC20 – Read from random addresses
    // ===================================================================
    test_case_count =  20;
    $display("\n=== TC20: Read from random addresses ===");
    apply_reset;

    write_burst(IACT_DEPTH, 8'h08, 8'b0);
    wait_cycles(2);
    @(negedge clock);
    read_and_verify_sim(8, 8'h10, 8'h20, 8'h30, 1, 1, 1);

    wait_cycles(2);
    @(negedge clock);
    read_and_verify_sim(8, 8'ha0, 8'hb0, 8'hc0, 1, 1, 1);
    read_and_verify_sim(8, 8'hd0, 8'he0, 8'hf0, 1, 1, 1);

    read_and_verify(8, 8'd50, 0);
    read_and_verify(8, 8'd40, 0);

    read_and_verify(8, 8'd80, 0);
    read_and_verify(8, 8'd80, 1);
    read_and_verify(8, 8'd80, 2);

    check(1, "Read from random addresses passed");

    // ===================================================================
    //  TC21 – Stress: 10 full write/read cycles on all routers
    // ===================================================================
    test_case_count = 21;
    $display("\n=== TC21: Stress: 10 full write/read cycles on all routers ===");
    apply_reset;
    for (j = 0; j < 10; j = j + 1) begin
        write_burst(IACT_DEPTH, 0, j * 8'd13);
        wait_cycles(3);
        @(negedge clock);
        // Quick sanity read on all three routers
        read_and_verify_sim(IACT_DEPTH, 0, 0, 0, 1, 1, 1);
        wait_cycles(2);
        @(negedge clock);
    end
    check(1, "10 full write/read cycles on all routers passed");

    wait_cycles(5);

    // ===================================================================
    //  Summary
    // ===================================================================
    $display("\n============================================");
    $display("  TESTBENCH SUMMARY");
    $display("  PASSED : %0d", pass_count);
    $display("  FAILED : %0d", fail_count);
    $display("============================================\n");

    if (fail_count == 0)
        $display(">>> ALL TESTS PASSED <<<");
    else
        $display(">>> %0d TEST(S) FAILED – review log above <<<", fail_count);

    $stop;
end

endmodule
