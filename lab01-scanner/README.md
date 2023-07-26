# Scanner
This is a scanner for the μRust language with lex.  
# Environment
Ubuntu 20.04  
Requirements: `sudo apt install flex bison git python3 python3-pip`  
# Get Started
* Compile source code and feed the input to your program
`make clean && make`  
`./myscanner < input/a01_arithmetic.rs >| tmp.out`
* Compare with the ground truth
`diff -y tmp.out answer/a01_arithmetic.out`
* Check the output file char-by-char
`od -c answer/a01_arithmetic.out`  

> 作者：成功大學資訊工程學系113級 鄭鈞智  
> 最後編輯： 2022/12/26 12:36