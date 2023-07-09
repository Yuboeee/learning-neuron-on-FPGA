`timescale 1ns/1ps
`include "include.v"

module neuron #(parameter layerNo=0,neuronNo=0,numWeight=784,dataWidth=16,sigmoidSize=5,weightIntWidth=1,actType="relu",biasFile="",weightFile="")(
    input           clk,
    input           rst,
    input [dataWidth-1:0]    myinput,
    input           myinputValid,
    input           weightValid,    //signals called weightValid: the input weight is a valid weight, and we have a weight value.
    input           biasValid,
    input [31:0]    weightValue,
    input [31:0]    biasValue,
    input [31:0]    config_layer_num,
    input [31:0]    config_neuron_num,
    output[dataWidth-1:0]    out,
    output reg      outvalid   
    );
    
    parameter addressWidth = $clog2(numWeight); //the 'addressWidth' is log of number of weights 向上取整
    
    reg         wen;
    wire        ren;
    reg [addressWidth-1:0] w_addr;
    reg [addressWidth:0]   r_addr;//read address has to reach until numWeight hence width is 1 bit more
    reg [dataWidth-1:0]  w_in;
    wire [dataWidth-1:0] w_out;
    reg [2*dataWidth-1:0]  mul; 
    reg [2*dataWidth-1:0]  sum;
    reg [2*dataWidth-1:0]  bias;
    reg [31:0]    biasReg[0:0];
    reg         weight_valid;
    reg         mult_valid;
    wire        mux_valid;
    reg         sigValid; 
    wire [2*dataWidth:0] comboAdd;
    wire [2*dataWidth:0] BiasAdd;
    reg  [dataWidth-1:0] myinputd;
    reg muxValid_d;
    reg muxValid_f;
    reg addr=0;
   //Loading weight values into the memory
    always @(posedge clk)
    begin
        if(rst)
        begin
            w_addr <= {addressWidth{1'b1}}; //replicate(重复) one bit one 'addressWidth' times. (which means all the bits of right address will be initialized to 1 for ti)
                                            //weight address is initialized with all ones.
            wen <=0;
        end

        //we have hundreds of neuron, each neuron is uniquely identified by few parameters, 
        //one is the layer in which neuron is present (layer number); -> layerNo
        //and what is the particular number of this neuron in that particular layer. -> neuronNo
        else if(weightValid & (config_layer_num==layerNo) & (config_neuron_num==neuronNo))
        begin
            w_in <= weightValue;
            w_addr <= w_addr + 1;   //whenever we're writing, the weight address going to the neuron is current value plus one.
                                    //so the initial weight I need to store it in zero, for that logic to work, the initial value of weight address should be all ones.
                                    //(only all ones plus one will become zero)
            wen <= 1;
        end
        else
            wen <= 0;
    end

    assign mux_valid = mult_valid;
    assign comboAdd = mul + sum;
    assign BiasAdd = bias + sum;
    assign ren = myinputValid;
    
    `ifdef pretrained
        initial
        begin
            $readmemb(biasFile,biasReg);
        end
        always @(posedge clk)
        begin
            bias <= {biasReg[addr][dataWidth-1:0],{dataWidth{1'b0}}};
        end
    `else
        always @(posedge clk)
        begin
            if(biasValid & (config_layer_num==layerNo) & (config_neuron_num==neuronNo))
            begin
                bias <= {biasValue[dataWidth-1:0],{dataWidth{1'b0}}};
            end
        end
    `endif
    
    
    always @(posedge clk)
    begin
        if(rst|outvalid)
            r_addr <= 0;
        else if(myinputValid)
            r_addr <= r_addr + 1;
    end
    
    always @(posedge clk)
    begin
        mul  <= $signed(myinputd) * $signed(w_out); //myInput(after delay) * weight
                                                    //"$signed(c)"是一个function，将无符号数转化为有符号数返回，不改变c的类型和内容
    end
    
    
    always @(posedge clk)
    begin
        if(rst|outvalid)    //whenever a rst comes, or whenever this neuron get final output after activation,
            sum <= 0;       //this sum will be reset to zero.
        else if((r_addr == numWeight) & muxValid_f)
        begin

            //case for overflow
            if(!bias[2*dataWidth-1] &!sum[2*dataWidth-1] & BiasAdd[2*dataWidth-1]) //If bias and sum are positive and after adding bias to sum, if sign bit becomes 1, saturate
            begin
                sum[2*dataWidth-1] <= 1'b0;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};
            end

            //case for underflow
            else if(bias[2*dataWidth-1] & sum[2*dataWidth-1] &  !BiasAdd[2*dataWidth-1]) //If bias and sum are negative and after addition if sign bit is 0, saturate
            begin
                sum[2*dataWidth-1] <= 1'b1;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};
            end

            //common cases
            else
                sum <= BiasAdd; 
        end
        else if(mux_valid)  //this is a normal case in during normal multiplication
        begin

            //case 1: when you do the multiplication and addition, overflow may happen; or sometimes underflow may also happen.
            // "mul[2*dataWidth-1]" represent the leftmost bit of 'mul' -> if that value is zero, means in sign representation this is a positive number
            // "sum[2*dataWidth-1]" -> if that value is zero, means the previous sum is positive.
            // "comboAdd" represents the sum of (mul and previous sum).
            if(!mul[2*dataWidth-1] & !sum[2*dataWidth-1] & comboAdd[2*dataWidth-1]) //this means: when you add 2 positive numbers, but the result(comboAdd) is negative, that means something goes wrong.
                                                                                    //the overflow has happened, the output number is greater than what can be represented using these bits.
                                                                                    //in this case you need to saturate the output.
            begin
                sum[2*dataWidth-1] <= 1'b0;                     
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b1}};  //最高位设为0，其余位设为1，代表the largest positive number.
                                                                //因为overflow发生了，所以我们把sum设为最大值maximum positive value
            end

            //case 2: 
            //mul是negative，sum是negative，comboAdd是positive
            //这意味着underflow发生了 -> the number of output is so small that it cannot be represented using these many bits
            else if(mul[2*dataWidth-1] & sum[2*dataWidth-1] & !comboAdd[2*dataWidth-1])
            begin
                sum[2*dataWidth-1] <= 1'b1;
                sum[2*dataWidth-2:0] <= {2*dataWidth-1{1'b0}};  //sum设为最小值：符号位是1，其余位是0（represents the smallest number in two's complement representation）
            end

            //case 3:
            //如果上述两种情况都没发生（overflow和underflow）
            //this sum will just represent comboAdd (comboAdd = mul + sum)
            else
                sum <= comboAdd; 
        end
    end
    
    always @(posedge clk)
    begin
        myinputd <= myinput;    //the weight memory, we wrote it sequentially, that means it has one clock delay.
                                //Because of that delay (one clock latency), this input is also delayed by one clock.
        weight_valid <= myinputValid;
        mult_valid <= weight_valid;
        sigValid <= ((r_addr == numWeight) & muxValid_f) ? 1'b1 : 1'b0;
        outvalid <= sigValid;
        muxValid_d <= mux_valid;
        muxValid_f <= !mux_valid & muxValid_d;
    end
    
    
    //Instantiation of Memory for Weights 实例化
    Weight_Memory #(.numWeight(numWeight),.neuronNo(neuronNo),.layerNo(layerNo),.addressWidth(addressWidth),.dataWidth(dataWidth),.weightFile(weightFile)) WM(
        .clk(clk),
        .wen(wen),
        .ren(ren),
        .wadd(w_addr),
        .radd(r_addr),
        .win(w_in),
        .wout(w_out)
    );
    
    generate
        if(actType == "sigmoid")    //a non-linear function
        begin:siginst
        //Instantiation of ROM for sigmoid
            Sig_ROM #(.inWidth(sigmoidSize),.dataWidth(dataWidth)) s1(
            .clk(clk),
            .x(sum[2*dataWidth-1-:sigmoidSize]),
            .out(out)
        );
        end
        else    //a linear function
        begin:ReLUinst
            ReLU #(.dataWidth(dataWidth),.weightIntWidth(weightIntWidth)) s1 (
            .clk(clk),
            .x(sum),
            .out(out)
        );
        end
    endgenerate

    `ifdef DEBUG
    always @(posedge clk)
    begin
        if(outvalid)
            $display(neuronNo,,,,"%b",out);
    end
    `endif
endmodule
