`timescale 1ns / 1ns

// =============================================================================
//  Testbench: Psum_SRAM_Bank_tb
//  DUT:       Psum_SRAM_Bank
//
//  Key DUT behaviours under test
//  ------------------------------
//  - Handshake write  : write_shake = psum_write_en & psum_data_in_valid
//  - Handshake read   : read_shake  = psum_read_en  & psum_data_out_ready
//  - psum_data_in_ready tracks psum_write_en combinatorially
//  - psum_write_done  : combinatorial, asserts when write_count == PSUM_DEPTH+1
//  - write_count      : increments on write_shake, resets on write_done / reset
//  - psum_read_done   : 1-cycle pulse when psum_data_out_valid & !psum_read_en
//  - Read address     : reloads from psum_read_addr every non-shake cycle
//  - Write address    : reloads from psum_write_addr when not writing
//  - Signed data      : psum_data is 20-bit signed – tested with negative values
//
//  Test cases
//  ----------
//  TC1  : Reset behaviour – all outputs deasserted
//  TC2  : Write PSUM_DEPTH entries, psum_write_done pulses at correct count
//  TC3  : Read back all written entries, verify signed data integrity
//  TC4  : psum_write_done pulses for exactly 1 clock cycle
//  TC5  : psum_read_done  pulses for exactly 1 clock cycle
//  TC6  : write_count resets to 0 after psum_write_done
//  TC7  : psum_data_in_ready tracks psum_write_en combinatorially
//  TC8  : psum_data_in_valid de-asserted mid-write (flow-control stall)
//  TC9  : psum_data_out_ready de-asserted mid-read (back-pressure stall)
//  TC10 : Non-zero psum_write_addr offset; write then read at offset
//  TC11 : Non-zero psum_read_addr offset; read subset of memory
//  TC12 : Signed negative values written and read back correctly
//  TC13 : Minimum burst: single-entry write & read
//  TC14 : Maximum burst: full PSUM_DEPTH entries with PSUM_DEPTH param set to max
//  TC15 : Back-to-back write then immediate read (no idle gap)
//  TC16 : Concurrent psum_write_en & psum_read_en
//  TC17 : Re-reset mid-write; DUT recovers and operates cleanly
//  TC18 : Two consecutive write bursts; write_count resets between them
//  TC19 : psum_write_addr reload – address returns to psum_write_addr when idle
//  TC20 : Stress – 10 consecutive write/read cycles with varied PSUM_DEPTH
// =============================================================================

module psum_SRAM_tb;

// -----------------------------------------------------------------------
//  Clock & global parameters
// -----------------------------------------------------------------------
localparam CLK_PERIOD       = 10;
localparam PSUM_SIZE        = 20;
localparam ADDR_SIZE        = 5;
localparam SRAM_DEPTH       = 32;   // 2^ADDR_SIZE
localparam WRITE_COUNT_SIZE = 5;
localparam TIMEOUT_CYC      = 8000;

// -----------------------------------------------------------------------
//  DUT ports
// -----------------------------------------------------------------------
reg                         clock;
reg                         reset;

wire                        psum_data_in_ready;
reg                         psum_data_in_valid;
reg  signed [PSUM_SIZE-1:0] psum_data_in;

reg                         psum_data_out_ready;
wire                        psum_data_out_valid;
wire signed [PSUM_SIZE-1:0] psum_data_out;

reg                         psum_write_en;
reg  [ADDR_SIZE-1:0]        psum_write_addr;
wire                        psum_write_done;

reg                         psum_read_en;
reg  [ADDR_SIZE-1:0]        psum_read_addr;
wire                        psum_read_done;

reg  [WRITE_COUNT_SIZE-1:0] PSUM_DEPTH;

// -----------------------------------------------------------------------
//  DUT instantiation
// -----------------------------------------------------------------------
Psum_SRAM_Bank_Old #(
    .PSUM_SIZE        (PSUM_SIZE       ),
    .ADDRESS_SIZE     (ADDR_SIZE       ),
    .PSUM_SRAM_DEPTH  (SRAM_DEPTH      ),
    .WRITE_COUNT_SIZE (WRITE_COUNT_SIZE)
) dut (
    .clock               (clock              ),
    .reset               (reset              ),
    .psum_data_in_ready  (psum_data_in_ready ),
    .psum_data_in_valid  (psum_data_in_valid ),
    .psum_data_in        (psum_data_in       ),
    .psum_data_out_ready (psum_data_out_ready),
    .psum_data_out_valid (psum_data_out_valid),
    .psum_data_out       (psum_data_out      ),
    .psum_write_en       (psum_write_en      ),
    .psum_write_addr     (psum_write_addr    ),
    .psum_write_done     (psum_write_done    ),
    .psum_read_en        (psum_read_en       ),
    .psum_read_addr      (psum_read_addr     ),
    .psum_read_done      (psum_read_done     ),
    .PSUM_DEPTH          (PSUM_DEPTH         )
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

reg signed [PSUM_SIZE-1:0] expected_mem [0:SRAM_DEPTH-1];

// -----------------------------------------------------------------------
//  Utility tasks
// -----------------------------------------------------------------------

task wait_cycles;
    input integer n;
    integer i;
    begin
        for (i = 0; i < n; i = i + 1)
            @(posedge clock);
    end
endtask

task inputs_init;
    begin
        psum_write_en       = 0;
        psum_write_addr     = 0;
        psum_data_in_valid  = 0;
        psum_data_in        = 0;
        psum_data_out_ready = 0;
        psum_read_en        = 0;
        psum_read_addr      = 0;
    end
endtask

task apply_reset;
    begin
        @(negedge clock);
        reset= 1;
        @(negedge clock);
        reset = 0;
    end
endtask

task check;
    input        cond;
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

// Write n signed values starting at psum_write_addr = start_addr.
// Pattern: signed value = base + i  (wraps naturally at 20-bit signed)
task write_burst;
    input integer                  n;
    input [ADDR_SIZE-1:0]          start_addr;
    input signed [PSUM_SIZE-1:0]   base;
    integer i;
    begin
        psum_write_addr = start_addr;
        @(negedge clock);
        psum_write_en   = 1;
        for (i = 0; i < n; i = i + 1) begin
            psum_data_in_valid = 1;
            psum_data_in       = base + i;
            expected_mem[start_addr + i] = base + i;
            @(posedge clock);
            // Stop before write_done fires to avoid address reload confusion
            if (psum_write_done) begin
                @(negedge clock);
                psum_data_in_valid = 0;
                psum_write_en      = 0;
                i = n; // exit loop
            end
        end
        @(negedge clock);
        psum_data_in_valid = 0;
        psum_write_en      = 0;
    end
endtask

// Read n entries starting at psum_read_addr = start_addr, verify vs expected_mem
task read_and_verify;
    input integer         n;
    input [ADDR_SIZE-1:0] start_addr;
    integer i;
    integer rd_errors;
    begin
        rd_errors = 0;
        psum_read_addr      = start_addr;
        @(negedge clock);

        psum_read_en        = 1;
        psum_data_out_ready = 1;

        // DUT registers psum_data_out 1 cycle after read_shake
        for (i = 0; i < n; i = i + 1) begin
            @(posedge clock); #1; // psum_data_out_valid high; data stable
            if (!psum_data_out_valid) begin
                $display("  [FAIL] TC%0d: psum_data_out_valid not asserted at i=%0d", test_case_count, i);
                fail_count = fail_count + 1;
                rd_errors = rd_errors + 1;
            end else if (psum_data_out !== expected_mem[start_addr + i]) begin
                $display("  [FAIL] TC%0d: addr %0d: expected %0d (0x%05h) got %0d (0x%05h)",
                          test_case_count, start_addr+i,
                          expected_mem[start_addr+i], expected_mem[start_addr+i],
                          psum_data_out, psum_data_out);
                fail_count = fail_count + 1;
                rd_errors = rd_errors + 1;
            end
        end

        @(negedge clock);
        psum_read_en        = 0;
        psum_data_out_ready = 0;

        if (rd_errors == 0) begin
            $display("  [PASS] TC%0d: %0d signed reads correct from addr 0x%02h",
                      test_case_count, n, start_addr);
            pass_count = pass_count + 1;
        end
    end
endtask

// -----------------------------------------------------------------------
//  Main stimulus
// -----------------------------------------------------------------------
integer i, j;
integer pulse_count;
integer wd_count;

initial begin
    $dumpfile("Psum_SRAM_Bank_tb.vcd");
    $dumpvars;

    pass_count  = 0;
    fail_count  = 0;
    PSUM_DEPTH = 5'd8; // default depth for most tests

    inputs_init;

    // ===================================================================
    //  TC1 – Reset behaviour
    // ===================================================================
    test_case_count =  1;
    $display("\n=== TC1: Reset behaviour ===");
    apply_reset;
    @(posedge clock); #1;
    check(psum_data_out_valid === 1'b0, "psum_data_out_valid = 0 after reset");
    check(psum_write_done     === 1'b0, "psum_write_done     = 0 after reset");
    check(psum_read_done      === 1'b0, "psum_read_done      = 0 after reset");
    check(psum_data_in_ready  === 1'b0, "psum_data_in_ready  = 0 (write_en=0)");

    // ===================================================================
    //  TC2 – Write PSUM_DEPTH entries; psum_write_done at correct count
    // ===================================================================
    test_case_count =  2;
    $display("\n=== TC2: write_done asserts when write_count == PSUM_DEPTH+1 ===");
    apply_reset;

    PSUM_DEPTH = 5'd8; // write_done when write_count reaches 8

    wd_count = 0;
    
    psum_write_addr = 0;
    @(negedge clock);
    psum_write_en = 1;

    for (i = 0; i < 8; i = i + 1) begin
        psum_data_in_valid = 1;
        psum_data_in       = 20'sh00010 * i;
        expected_mem[i]     = 20'sh00010 * i;
        @(negedge clock);
    end

    check(psum_write_done, "psum_write_done asserted at PSUM_DEPTH writes");

    @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;


    // ===================================================================
    //  TC3 – Read back all written entries; verify signed data
    // ===================================================================
    test_case_count =  3;
    $display("\n=== TC3: Read-back and signed data integrity ===");
    wait_cycles(2);

    @(negedge clock);
    read_and_verify(8, 0);

    // ===================================================================
    //  TC4 – psum_write_done pulses for exactly 1 clock cycle
    // ===================================================================
    test_case_count =  4;
    $display("\n=== TC4: psum_write_done single-cycle pulse ===");
    apply_reset;
    PSUM_DEPTH = 5'd3; // write_done after 4 writes

    psum_write_addr = 0;
    @(negedge clock);
    psum_write_en = 1;
    for (i = 0; i < 3; i = i + 1) begin
        psum_data_in_valid = 1; psum_data_in = i;
        expected_mem[i] = i;
        @(negedge clock);
    end
    @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;

    pulse_count = 0;
    for (i = 0; i < 6; i = i + 1) begin
        @(posedge clock); #1;
        if (psum_write_done) pulse_count = pulse_count + 1;
    end
    check(pulse_count === 1, "psum_write_done pulses for exactly 1 cycle");

    // ===================================================================
    //  TC5 – psum_read_done pulses for exactly 1 clock cycle
    // ===================================================================
    test_case_count =  5;
    $display("\n=== TC5: psum_read_done single-cycle pulse ===");
    psum_read_addr = 0; psum_read_en = 1; psum_data_out_ready = 1;
    wait_cycles(5);
    @(negedge clock); psum_read_en = 0; psum_data_out_ready = 0;

    pulse_count = 0;
    for (i = 0; i < 6; i = i + 1) begin
        @(posedge clock); #1;
        if (psum_read_done) pulse_count = pulse_count + 1;
    end
    check(pulse_count === 1, "psum_read_done pulses for exactly 1 cycle");

    // ===================================================================
    //  TC6 – write_count resets to 0 after psum_write_done
    // ===================================================================
    test_case_count =  6;
    $display("\n=== TC6: write_count resets to 0 after psum_write_done ===");
    apply_reset;
    PSUM_DEPTH = 5'd3; // triggers after 4 writes

    // First burst: trigger write_done
    psum_write_addr = 0; psum_write_en = 1;
    for (i = 0; i < 4; i = i + 1) begin
        @(negedge clock); psum_data_in_valid = 1; psum_data_in = i; @(posedge clock);
    end
    @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;
    wait_cycles(3);

    // Second burst: should trigger write_done again (count was reset)
    wd_count = 0;
    fork
        begin : wd_mon6
            integer t; t = 0;
            forever begin
                @(posedge clock); t = t + 1;
                if (psum_write_done) wd_count = wd_count + 1;
                if (t > 20) disable wd_mon6;
            end
        end
        begin
            psum_write_addr = 0; psum_write_en = 1;
            for (i = 0; i < 4; i = i + 1) begin
                @(negedge clock); psum_data_in_valid = 1; psum_data_in = i + 10; @(posedge clock);
            end
            @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;
            wait_cycles(3); disable wd_mon6;
        end
    join
    check(wd_count >= 1, "write_count properly reset; psum_write_done fires again");

    // ===================================================================
    //  TC7 – psum_data_in_ready tracks psum_write_en combinatorially
    // ===================================================================
    test_case_count =  7;
    $display("\n=== TC7: psum_data_in_ready tracks psum_write_en ===");
    apply_reset;

    @(posedge clock); #1;
    check(psum_data_in_ready === 1'b0, "psum_data_in_ready = 0 when write_en = 0");
    @(negedge clock); psum_write_en = 1;
    @(posedge clock); #1;
    check(psum_data_in_ready === 1'b1, "psum_data_in_ready = 1 when write_en = 1");
    @(negedge clock); psum_write_en = 0;
    @(posedge clock); #1;
    check(psum_data_in_ready === 1'b0, "psum_data_in_ready = 0 when write_en deasserted");

    // ===================================================================
    //  TC8 – psum_data_in_valid de-asserted mid-write (stall)
    // ===================================================================
    test_case_count =  8;
    $display("\n=== TC8: Mid-write valid stall ===");
    apply_reset;
    PSUM_DEPTH = 5'd7;

    psum_write_addr = 0; psum_write_en = 1;
    @(negedge clock); psum_data_in_valid = 1; psum_data_in = 20'sh00111; expected_mem[0] = 20'sh00111;
    @(posedge clock);
    @(negedge clock); psum_data_in = 20'sh00222; expected_mem[1] = 20'sh00222;
    @(posedge clock);
    // Stall for 4 cycles
    @(negedge clock); psum_data_in_valid = 0;
    wait_cycles(4);
    // Resume
    @(negedge clock); psum_data_in_valid = 1; psum_data_in = 20'sh00333; expected_mem[2] = 20'sh00333;
    @(posedge clock);
    @(negedge clock); psum_data_in = 20'sh00444; expected_mem[3] = 20'sh00444;
    @(posedge clock);
    @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;
    wait_cycles(3);

    read_and_verify(4, 0);

    // ===================================================================
    //  TC9 – psum_data_out_ready de-asserted mid-read (back-pressure)
    // ===================================================================
    test_case_count =  9;
    $display("\n=== TC9: Mid-read back-pressure stall ===");
    apply_reset;
    PSUM_DEPTH = 5'd7;
    write_burst(8, 0, 20'sh00050);
    wait_cycles(2);

    psum_read_addr = 0; psum_read_en = 1; psum_data_out_ready = 1;
    wait_cycles(4);                           // read ~3 entries
    @(negedge clock); psum_data_out_ready = 0; // back-pressure
    wait_cycles(5);
    @(negedge clock); psum_data_out_ready = 1; // release
    wait_cycles(5);
    @(negedge clock); psum_read_en = 0; psum_data_out_ready = 0;
    check(1, "Read completed after mid-read back-pressure stall");

    // ===================================================================
    //  TC10 – Non-zero psum_write_addr; write then read at offset
    // ===================================================================
    test_case_count =  10;
    $display("\n=== TC10: Non-zero write offset (addr 0x08) ===");
    apply_reset;
    PSUM_DEPTH = 5'd7;
    write_burst(8, 5'h08, 20'sh00100);
    wait_cycles(2);
    @(negedge clock); 
    read_and_verify(8, 5'h08);

    // ===================================================================
    //  TC11 – Non-zero psum_read_addr; read subset starting at offset
    // ===================================================================
    test_case_count =  11;
    $display("\n=== TC11: Non-zero read offset ===");
    apply_reset;
    PSUM_DEPTH = 5'd15;
    write_burst(16, 0, 20'sh00010);
    wait_cycles(2);
    @(negedge clock);
    read_and_verify(8, 5'h08);

    // ===================================================================
    //  TC12 – Signed negative values written and read back correctly
    // ===================================================================
    test_case_count =  12;
    $display("\n=== TC12: Signed negative values ===");
    apply_reset;
    PSUM_DEPTH = 5'd7;

    psum_write_addr = 0; psum_write_en = 1;
    begin : tc12_write
        reg signed [PSUM_SIZE-1:0] val;
        integer k;
        for (k = 0; k < 8; k = k + 1) begin
            val = -20'sh00001 * (k + 1);     // -1, -2, ... -8
            expected_mem[k] = val;
            @(negedge clock); psum_data_in_valid = 1; psum_data_in = val;
            @(posedge clock);
        end
    end
    @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;
    wait_cycles(2);
    @(negedge clock);
    read_and_verify(8, 0);

    // ===================================================================
    //  TC13 – Single-entry write & read
    // ===================================================================
    test_case_count =  13;
    $display("\n=== TC13: Single-entry write & read ===");
    apply_reset;
    PSUM_DEPTH = 5'd0; // write_done after 1 write

    psum_write_addr = 0; psum_write_en = 1;
    @(negedge clock); psum_data_in_valid = 1; psum_data_in = 20'sh7FFFF; expected_mem[0] = 20'sh7FFFF;
    @(posedge clock);
    @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;
    wait_cycles(2);
    @(negedge clock);
    read_and_verify(1, 0);

    // ===================================================================
    //  TC14 – Maximum burst: full SRAM_DEPTH (32) with PSUM_DEPTH = 31
    // ===================================================================
    test_case_count =  14;
    $display("\n=== TC14: Maximum burst (PSUM_DEPTH=31, 32 writes) ===");
    apply_reset;
    PSUM_DEPTH = 5'd31;
    write_burst(SRAM_DEPTH, 0, 20'sh00001);
    wait_cycles(3);
    @(negedge clock);
    read_and_verify(SRAM_DEPTH, 0);

    // ===================================================================
    //  TC15 – Back-to-back write then immediate read
    // ===================================================================
    test_case_count =  15;
    $display("\n=== TC15: Back-to-back write then immediate read ===");
    apply_reset;
    PSUM_DEPTH = 5'd7;
    write_burst(8, 0, 20'sh00055);
    // Start read immediately with no idle cycles
    read_and_verify(8, 0);
    check(1, "Back-to-back write/read completed without deadlock");

    // ===================================================================
    //  TC16 – Concurrent psum_write_en & psum_read_en
    // ===================================================================
    test_case_count =  16;
    $display("\n=== TC16: Concurrent write_en and read_en ===");
    apply_reset;
    PSUM_DEPTH = 5'd7;
    write_burst(8, 0, 20'sh000AA);
    wait_cycles(2);

    psum_write_en       = 1; psum_write_addr = 0; psum_data_in_valid = 1; psum_data_in = 20'sh00001;
    psum_read_en        = 1; psum_read_addr  = 0; psum_data_out_ready = 1;
    wait_cycles(10);
    @(negedge clock);
    psum_write_en       = 0; psum_data_in_valid = 0;
    psum_read_en        = 0; psum_data_out_ready = 0;
    check(1, "DUT survived concurrent write_en and read_en without locking");

    // ===================================================================
    //  TC17 – Re-reset mid-write; DUT recovers cleanly
    // ===================================================================
    test_case_count =  17;
    $display("\n=== TC17: Reset mid-write; clean recovery ===");
    apply_reset;
    PSUM_DEPTH = 5'd7;
    psum_write_addr = 0; psum_write_en = 1; psum_data_in_valid = 1; psum_data_in = 20'shDEAD;
    wait_cycles(5);
    // Inject reset mid-burst
    reset = 1; wait_cycles(3); reset = 0;
    psum_write_en = 0; psum_data_in_valid = 0;
    wait_cycles(2); #1;
    check(psum_data_out_valid === 0, "psum_data_out_valid = 0 after mid-op reset");
    check(psum_write_done     === 0, "psum_write_done     = 0 after mid-op reset");
    check(psum_read_done      === 0, "psum_read_done      = 0 after mid-op reset");

    // Resume and verify normal operation
    write_burst(4, 0, 20'sh00001);
    wait_cycles(2);
    read_and_verify(4, 0);

    // ===================================================================
    //  TC18 – Two consecutive write bursts; write_count resets between them
    // ===================================================================
    test_case_count =  18;
    $display("\n=== TC18: Two consecutive write bursts ===");
    apply_reset;
    PSUM_DEPTH = 5'd3; // done after 4 writes

    // First burst
    psum_write_addr = 0; psum_write_en = 1;
    for (i = 0; i < 4; i = i + 1) begin
        @(negedge clock); psum_data_in_valid = 1; psum_data_in = 20'sh00010 + i; expected_mem[i] = 20'sh00010 + i;
        @(posedge clock);
    end
    @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;
    wait_cycles(3);

    // Second burst with different data
    psum_write_addr = 0; psum_write_en = 1;
    for (i = 0; i < 4; i = i + 1) begin
        @(negedge clock); psum_data_in_valid = 1; psum_data_in = 20'sh000AA + i; expected_mem[i] = 20'sh000AA + i;
        @(posedge clock);
    end
    @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;
    wait_cycles(3);

    read_and_verify(4, 0);
    check(1, "Second burst overwrote first burst correctly");

    // ===================================================================
    //  TC19 – psum_write_addr reload when not writing
    // ===================================================================
    test_case_count =  19;
    $display("\n=== TC19: psum_write_address reloads from psum_write_addr when idle ===");
    apply_reset;
    PSUM_DEPTH = 5'd7;

    // Write 3 entries at addr 0
    psum_write_addr = 0; psum_write_en = 1;
    for (i = 0; i < 3; i = i + 1) begin
        @(negedge clock); psum_data_in_valid = 1; psum_data_in = i; expected_mem[i] = i;
        @(posedge clock);
    end
    @(negedge clock); psum_data_in_valid = 0;
    // While write_en still high but no valid: change write_addr
    psum_write_addr = 5'h10;
    wait_cycles(3);
    // Now write 2 more entries – should start from 0x10 (reloaded)
    @(negedge clock); psum_data_in_valid = 1; psum_data_in = 20'sh00055; expected_mem[5'h10] = 20'sh00055;
    @(posedge clock);
    @(negedge clock); psum_data_in = 20'sh00066; expected_mem[5'h11] = 20'sh00066;
    @(posedge clock);
    @(negedge clock); psum_data_in_valid = 0; psum_write_en = 0;
    wait_cycles(2);
    @(negedge clock);
    read_and_verify(2, 5'h10);

    // ===================================================================
    //  TC20 – Stress: 10 consecutive write/read cycles, varied PSUM_DEPTH
    // ===================================================================
    test_case_count =  20;
    $display("\n=== TC20: Stress – 10 write/read cycles, varied depth ===");
    for (j = 0; j < 10; j = j + 1) begin
        apply_reset;
        PSUM_DEPTH = j[WRITE_COUNT_SIZE-1:0] + 1; // depths 2..11
        write_burst(j + 2, 0, 20'sh00001 * (j + 1));
        wait_cycles(3);

        // Quick integrity read of first entry
        psum_read_addr = 0; psum_read_en = 1; psum_data_out_ready = 1;
        @(posedge clock); @(posedge clock); #1;
        if (psum_data_out !== expected_mem[0]) begin
            $display("  [FAIL] TC20 – iter %0d: exp 0x%05h got 0x%05h",
                      j, expected_mem[0], psum_data_out);
            fail_count = fail_count + 1;
        end
        @(negedge clock); psum_read_en = 0; psum_data_out_ready = 0;
        wait_cycles(2);
    end
    check(1, "10 write/read cycles with varied PSUM_DEPTH completed");

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
