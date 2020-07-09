; Initialize X and IMM for Collatz program
  IMM 1
  LDX IMM ; X = 1
  IMM 3

@main:

  TXA     ; Let A = X.
  XOR X   ; Make sure A contains 0
  ST R0   ; R0 (count) = 0

  IN      ; Read a flit from din

@collatz: 
  ST R1    ; Save current A
  
  LD R0    ; Load count into A
  ADD X    ; Increment A
  ST R0    ; Store back into count
  
  LD R1    ; Restore A

  JEQ X @return   ; If A is 1, we're done
  
  JSET X +  ; If A is not a multiple of two, we multiply and add
  
  RSH X     ; (Else divide by two)
  JA @collatz; Go to top of Collatz loop

* MUL IMM    ; Multiply by 3
  ADD X      ; Add 1
  JA @collatz; Go to top of Collatz loop

@return:
  LD R0    ; A = count
  OUT 1    ; Output A with TLAST = 1
  JA @main   ;       Go to top of main loop        
