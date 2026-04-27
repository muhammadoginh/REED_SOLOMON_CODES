`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2026 12:36:14 PM
// Design Name: 
// Module Name: tb_reed_solomon_encode
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_reed_solomon_encode();
    parameter parameter_set = "hqc256";

    localparam CLK_PERIOD = 10;

    localparam N1_BYTES = (parameter_set == "hqc128") ? 46 :
                          (parameter_set == "hqc192") ? 56 :
                          (parameter_set == "hqc256") ? 90 : 46;
    localparam K_BYTES  = (parameter_set == "hqc128") ? 16 :
                          (parameter_set == "hqc192") ? 24 :
                          (parameter_set == "hqc256") ? 32 : 16;
    localparam N1 = 8 * N1_BYTES;
    localparam K  = 8 * K_BYTES;

    reg              clk;
    reg              rst_n;
    reg              start;
    reg  [K-1:0]     msg_in;
    wire [N1-1:0]    cdw_out;
    wire             done;

    reed_solomon_encode #(.parameter_set(parameter_set)) dut (
        .clk     (clk),
        .rst     (~rst_n),
        .start   (start),
        .msg_in  (msg_in),
        .cdw_out (cdw_out),
        .done    (done)
    );

    string  vec_dir;
    string  in_path;
    string  out_path;
    integer fi, fo;
    integer op_idx;
    integer pass_cnt;
    integer fail_cnt;
    integer scan_status;
    integer b;

    reg [K-1:0]      file_in;
    reg [N1-1:0]     file_out;
    reg [N1-1:0]     exp_cdw_swapped;
    reg [N1-1:0]     got_cdw;

    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        if (!$value$plusargs("VEC_DIR=%s", vec_dir)) begin
            vec_dir = "F:/Projects/REED_SOLOMON_CODES/REED_SOLOMON_CODES.srcs/sim_1/reed_solomon_encode/hqc-5";
        end
        in_path  = {vec_dir, "/inputs.mem"};
        out_path = {vec_dir, "/outputs.mem"};

        rst_n    = 1'b0;
        start    = 1'b0;
        msg_in   = '0;
        pass_cnt = 0;
        fail_cnt = 0;
        op_idx   = 0;

        #(CLK_PERIOD * 4);
        rst_n = 1'b1;
        #(CLK_PERIOD);

        fi = $fopen(in_path, "r");
        fo = $fopen(out_path, "r");
        if (fi == 0 || fo == 0) begin
            $display("FAIL: cannot open vector files in %s", vec_dir);
            $finish;
        end

        forever begin
            scan_status = $fscanf(fi, "%h\n", file_in);
            if (scan_status != 1) begin
                $fclose(fi);
                $fclose(fo);
                break;
            end
            scan_status = $fscanf(fo, "%h\n", file_out);
            if (scan_status != 1) begin
                $display("FAIL: outputs.mem shorter than inputs.mem at op %0d", op_idx);
                $fclose(fi);
                $fclose(fo);
                break;
            end

            // Byte-swap input msg: file MSB byte = C byte[0] ? HW LSB
            for (b = 0; b < K_BYTES; b++) begin
                msg_in[b*8 +: 8] = file_in[(K_BYTES - 1 - b)*8 +: 8];
            end

            // Byte-swap expected codeword (same rule)
            for (b = 0; b < N1_BYTES; b++) begin
                exp_cdw_swapped[b*8 +: 8] = file_out[(N1_BYTES - 1 - b)*8 +: 8];
            end

            // Drive start, wait for done
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            wait (done == 1'b1);
            @(posedge clk);

            got_cdw = cdw_out;
            if (got_cdw === exp_cdw_swapped) begin
                pass_cnt = pass_cnt + 1;
            end else begin
                fail_cnt = fail_cnt + 1;
                if (fail_cnt <= 5) begin
                    $display("FAIL: op=%0d exp=%0h got=%0h", op_idx, exp_cdw_swapped, got_cdw);
                end
            end

            op_idx = op_idx + 1;
        end

        $display("SUMMARY: submod=reed_solomon_encode set=%s dir=%s ops=%0d pass=%0d fail=%0d",
                 parameter_set, vec_dir, op_idx, pass_cnt, fail_cnt);
        if (fail_cnt == 0 && op_idx > 0) begin
            $display("PASS: tb_reed_solomon_encode");
        end else begin
            $display("FAIL: tb_reed_solomon_encode");
        end
        $finish;
    end
endmodule
