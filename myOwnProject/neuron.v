`timescale 1ns/1ps
`include "include.v"

module neuron #(
    //sigmoidSize, weightIntWidth, actType, biasFile
    parameter layerNo = 0, neuronNo = 0, numWeight = 10, dataWidth = 16, sigmoidSize = 5, weightIntWidth = 1, actType = "relu", biasFile = "", weightFile = ""
) (
    input clk,
    input rst,
    input [dataWidth-1 : 0] myinput,
    input myinputValid,
    input weightValid,
    input biasValid,    //
    input [31:0] weightValue,
    input [31:0] biasValue, //
    input [31:0] config_layer_num,  //
    input [31:0] config_neuron_num, //
    output [dataWidth-1 : 0] out,
    output reg outvalid
);

    parameter addressWidth = $clog2(numWeight);

    reg wen;
    wire ren;

    reg [addressWidth-1 : 0] w_addr;
    reg [addressWidth : 0] r_addr;  //为什么r_addr比w_addr多一位？

    reg [dataWidth-1 : 0] w_in;
    wire [dataWidth-1 : 0] w_out;   //为什么in是reg，out是wire？

    reg [2*dataWidth-1 : 0] mul;
    reg [2*dataWidth-1 : 0] sum;
    reg [2*dataWidth-1 : 0] bias;   //
    reg [31:0] biasReg[0:0];    //干嘛的？
    reg weight_valid;
    reg mult_valid;
    wire mux_valid;
    reg sigValid;   //
    wire [2*dataWidth : 0] comboAdd;    //为啥比mul, sum多一位？
    wire [2*dataWidth : 0] biasAdd; //
    reg [dataWidth-1 : 0] myinputd;
    reg muxValid_d;
    reg muxValid_f;
    reg addr = 0;

    //权重值加载到memory里
    always @(posedge clk) begin
        if(rst)
        begin
            w_addr <= {addressWidth{1'b1}};
            wen <= 0;
        end
        else if(weightValid & (config_layer_num == layerNo) & (config_neuron_num == neuronNo))
        begin
            w_in <= weightValue;
            w_addr <= w_addr + 1;
            wen <= 1;
        end
        else
            wen <= 0;
    end

    assign mux_valid = mult_valid;
    assign comboAdd = mul + sum;
    //assign biasAdd = bias + sum;
    assign ren = myinputValid;

    //省略对bias部分的处理

    always @(posedge clk) begin
        if (rst | outvalid) 
            r_addr <= 0;
        else if(myinputValid)
            r_addr <= r_addr + 1;
    end

    always @(posedge clk) begin
        mul <= $signed(myinputd) * $signed(w_out);
    end

    always @(posedge clk) begin
        if (rst|outvalid) 
            sum <= 0;
        else if((r_addr == numWeight) & muxValid_f)
        begin
            if (!bias[2*dataWidth-1]) begin
                
            end
        end
    end

endmodule
