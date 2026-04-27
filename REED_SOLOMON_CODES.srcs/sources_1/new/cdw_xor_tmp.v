`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/23/2026 12:40:09 PM
// Design Name: 
// Module Name: cdw_xor_tmp
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


module cdw_xor_tmp #(
        parameter parameter_set = "hqc128",
                                                   
        parameter N1_BYTES =    (parameter_set == "hqc128")? 46:
                                (parameter_set == "hqc192")? 56:
                                (parameter_set == "hqc256")? 90:
                                                             46,
        
        parameter K_BYTES = (parameter_set == "hqc128")? 16:
                            (parameter_set == "hqc192")? 24:
                            (parameter_set == "hqc256")? 32: 
                                                         16,
        
        parameter N1 = 8*N1_BYTES,
        parameter K = 8*K_BYTES
    )(
    
        //    input seed_valid,
        input [N1-K-1:0] cdw_in,
        input [N1-K-1:0] tmp_arr,
        output [N1-K-1:0] cdw_out
    );
    
    
    genvar i;
    generate
        for (i = N1_BYTES-K_BYTES; i>1; i=i-1) begin:cdw_xor_tmparr
            assign cdw_out[8*i-1:8*i-8] =  cdw_in[8*(i-1)-1:8*(i-1)-8] ^ tmp_arr[8*i-1:8*i-8];
        end
    endgenerate
    
    assign cdw_out[7:0] = tmp_arr[7:0];
    
endmodule
