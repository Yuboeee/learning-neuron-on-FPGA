`timescale 1ns / 1ps
`include "include.v"
module Weight_Memory #(parameter numWeight = 3, neuronNo=5,layerNo=1,addressWidth=10,dataWidth=16,weightFile="w_1_15.mif") 
    ( 
    input clk,
    input wen,
    input ren,
    input [addressWidth-1:0] wadd,
    input [addressWidth-1:0] radd,
    input [dataWidth-1:0] win,
    output reg [dataWidth-1:0] wout);
    
    reg [dataWidth-1:0] mem [numWeight-1:0];    //parameterize the width of the memory and the depth of the memory 参数化内存宽度和深度
                                                //the depth of the memory depends upon how many weights you have, also the number of weights depends on the number of inputs to your neuron.
                                                //reg[dataWidth-1:0] mem [numWeight-1:0] -> numWeight个位宽为dataWidth的一维数组

    `ifdef pretrained   //This "ifdef ~ endif" is deciding whether this will act like a RAM or a ROM
        initial         //"pretrained" is a defined value which is defined in this "include.v" file.
                        //If it's defined -> more like ROM; if it's defined -> more like RAM.
		begin
	        $readmemb(weightFile, mem); //"readmemb" means the content of the file should be in binary format.
                                        //"readmemh" means the content of the file should be in hexadecimal format.
	    end
	`else
		always @(posedge clk)
		begin
			if (wen)    //If it's not defined as "pretrained" that means the values to the memory will be stored by some external circuitry that is what is written here (which is like our normal RAM).
                        //address and addressWeight should be written (parameter: wadd).
			begin
				mem[wadd] <= win;   //whatever input is coming, we'll store it in the memory.
			end
		end 
    `endif
    
    always @(posedge clk)
    begin
        if (ren)        //if a readable signal coming, there's a read address coming as well.
        begin
            wout <= mem[radd];
        end
    end 
endmodule