# Parser
This is a parser for the μRust language that supports print IO, arithmetic operations and some basic constructs for μRust.  
# Environment
Ubuntu 20.04  
Requirements: `sudo apt install flex bison git python3 python3-pip`  
Local Judge (Optional): `pip3 install local-judge`  
# Get Started
* Compile source code and feed the input to your program
`make clean && make`  
`./myscanner < input/a01_arithmetic.rs >| tmp.out`
* Compare with the ground truth
`diff -y tmp.out answer/a01_arithmetic.out`
* Check the output file char-by-char
`od -c answer/a01_arithmetic.out`  

> 作者：成功大學資訊工程學系113級 鄭鈞智  
> 最後編輯： 2023/07/26 15:01
