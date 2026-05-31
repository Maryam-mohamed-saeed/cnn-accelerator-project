`timescale 1ns / 1ps

module Psum_Router_tb();

    // ---------------------------------------------------------
    // 1. Signal Declarations
    // ---------------------------------------------------------
    // Inputs to UUT (reg)
    reg                     PE_in_valid;
    reg  signed [20:0]      PE_in;
    reg                     GLB_in_valid;
    reg  signed [20:0]      GLB_in;
    reg                     north_in_valid;
    reg  signed [20:0]      north_in;
    reg                     PE_out_ready;
    reg                     GLB_out_ready;
    reg                     south_out_ready;
    reg                     data_in_sel;
    reg                     data_out_sel;

    // Outputs from UUT (wire)
    wire                    PE_in_ready;
    wire                    GLB_in_ready;
    wire                    north_in_ready;
    wire                    PE_out_valid;
    wire signed [20:0]      PE_out;
    wire                    GLB_out_valid;
    wire signed [20:0]      GLB_out;
    wire                    south_out_valid;
    wire signed [20:0]      south_out;

    // ---------------------------------------------------------
    // 2. Unit Under Test (UUT) Instance
    // ---------------------------------------------------------
    Psum_Router uut (
        .PE_in_ready(PE_in_ready),
        .PE_in_valid(PE_in_valid),
        .PE_in(PE_in),
        .GLB_in_ready(GLB_in_ready),
        .GLB_in_valid(GLB_in_valid),
        .GLB_in(GLB_in),
        .north_in_ready(north_in_ready),
        .north_in_valid(north_in_valid),
        .north_in(north_in),
        .PE_out_ready(PE_out_ready),
        .PE_out_valid(PE_out_valid),
        .PE_out(PE_out),
        .GLB_out_ready(GLB_out_ready),
        .GLB_out_valid(GLB_out_valid),
        .GLB_out(GLB_out),
        .south_out_ready(south_out_ready),
        .south_out_valid(south_out_valid),
        .south_out(south_out),
        .data_in_sel(data_in_sel),
        .data_out_sel(data_out_sel)
    );

    // ---------------------------------------------------------
    // 3. Stimulus Logic
    // ---------------------------------------------------------
    initial begin
        // --- Initialize Inputs ---
        PE_in = 21'd0; PE_in_valid = 0;
        GLB_in = 21'd0; GLB_in_valid = 0;
        north_in = 21'd0; north_in_valid = 0;
        PE_out_ready = 0; GLB_out_ready = 0; south_out_ready = 0;
        data_in_sel = 0; data_out_sel = 0;

        $display("--- Starting Mariam's Psum_Router Test ---");
        #10;

     // SCENARIO 1: Fixed Path (PE -> GLB)
        // Change 21'sd1024 to 21'd1024
        PE_in = 21'd1024; PE_in_valid = 1; GLB_out_ready = 1;
        #5;
        if (GLB_out == 21'd1024 && GLB_out_valid == 1)
            $display("[SUCCESS] PE to GLB results path verified.");
        else
            $display("[ERROR] PE to GLB path failure!");

        // SCENARIO 2: GLB to PE
        data_in_sel  = 1'b1; 
        data_out_sel = 1'b1; 
        PE_out_ready = 1;
        GLB_in = 21'd500; GLB_in_valid = 1; // Changed from 21'sd500
        #5;
        if (PE_out == 21'd500 && GLB_in_ready == 1)
            $display("[SUCCESS] GLB to PE startup path verified.");
        else
            $display("[ERROR] GLB to PE path failure!");

        // SCENARIO 3: North to South (Negative Number Handling)
        data_in_sel  = 1'b0; 
        data_out_sel = 1'b0; 
        south_out_ready = 1;
        // To represent -128 in 21-bit Two's Complement without using 'sd:
        // -128 is 21'h1FFFF80
        north_in = 21'hFFFF80; north_in_valid = 1; 
        #5;
        if (south_out == 21'hFFFF80 && north_in_ready == 1)
            $display("[SUCCESS] North to South accumulation path verified.");
        else
            $display("[ERROR] North to South path failure!");

        // SCENARIO 4: Backpressure Stall
        // If the downstream PE is busy, the North input must stall
        south_out_ready = 0; // Simulate downstream stall
        #5;
        if (north_in_ready == 0)
            $display("[SUCCESS] Handshake stall (Backpressure) works correctly.");
        else
            $display("[ERROR] Backpressure failed to propagate!");
// --- STALL TEST: Verifying Backpressure ---
        #10;
        $display("Starting Stall Test: Setting south_out_ready to 0");
        
        // Setup a valid path from North to South
        data_in_sel  = 1'b0; // FROM_NORTH
        data_out_sel = 1'b0; // TO_SOUTH
        north_in      = 21'h12345; 
        north_in_valid = 1'b1;
        
        // Initially, the destination is READY
        south_out_ready = 1'b1;
        #5; // Wait for combinational logic to settle
        
        // NOW: Simulate a stall by setting south_out_ready to 0
        south_out_ready = 1'b0;
        #5;
        
        if (north_in_ready == 1'b0)
            $display("[SUCCESS] Backpressure detected: north_in_ready dropped to 0.");
        else
            $display("[FAILURE] Logic Error: north_in_ready is still 1 despite south stall!");

        #20;
        $display("--- Testbench Finished ---");
       
    end

    // ---------------------------------------------------------
    // 4. Waveform Generation (Optional)
    // ---------------------------------------------------------
    initial begin
        $dumpfile("psum_router_waves.vcd");
        $dumpvars(0, Psum_Router_tb);
    end

endmodule