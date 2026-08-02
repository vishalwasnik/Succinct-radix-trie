NAME    TRIE_ASM_MODULE

; Global variables from MAIN.C
EXTRN   DATA (current_node_idx)
EXTRN   DATA (node_match_char_cnt)

EXTRN DATA (current_identity)

EXTRN DATA (next_addr)


PUBLIC  _Process_Incoming_Byte_Trie
PUBLIC  INIT_RAM_TABLE	

?PR?_Process_Incoming_Byte_Trie?TRIE_ASM SEGMENT CODE
RSEG    ?PR?_Process_Incoming_Byte_Trie?TRIE_ASM
	
	; ----- INIT_RAM_TABLE ?? ???? ??? ??????? -----


INIT_RAM_TABLE:
    MOV R0, #40H           ; R0 ??? RAM ?? ?????????? ?????? (40H)
    MOV R1, #08H           ; 8 ???? ???? ???? ???
    MOV DPTR, #MASK_DATA   ; ROM ??? ???? ???? ??
    
LOAD_LOOP:
    CLR A
    MOVC A, @A+DPTR        ; ROM ?? ???? ????
    MOV @R0, A             ; RAM ??? ???? (Indirect Addressing)
    INC R0                 ; ???? RAM ??????
    INC DPTR               ; ???? ROM ??????
    DJNZ R1, LOAD_LOOP     ; ?? ?? 8 ???? ???? ? ???, ??? ????
RET

_Process_Incoming_Byte_Trie:
      
     ; Input: R7 = rx_byte
      MOV A, R7
     ;check current_identity zero hai ya nai 
     MOV A, current_identity
     ;IDENTITY_NOT_ZERO
	 JZ _NORMAL_TRIE
     AJMP _IDENTITY_NOT_ZERO
    
    
_NORMAL_TRIE: 
     MOV A, R7
    ; 1. Calculate High Index (Bits 3-5)
    ANL A, #38H
    SWAP A
    RR  A           ; A = High_Idx (0-7)
	
    MOV R2, A       ; Save high_idx in R2
    INC A
    ; 2. Fetch Config High
    MOV DPL, current_node_idx+1
    MOV DPH, current_node_idx
    ADD A, DPL      ; Offset High_Idx
    MOV DPL, A
    JNC H_NO_CARRY   ; 3 cycle 
    INC DPH
H_NO_CARRY:
    CLR A
    MOVC A, @A+DPTR ; 4 cycle Fetch config_high from Flash
    MOV R3, A       ; R3 = config_high
    
    
    ; 4. Calculate Low Index (Bits 0-2)
    MOV A, R7
    ANL A, #07H
    MOV R4, A       ; R4 = low_idx
    
   
    
        ; 6. Mask Check Low (Final Optimized Logic)
    MOV A, R4           ; R4 = low_idx (0-7)
    ADD A, #40H         ; ??? ?? ??? (40H-47H)
    MOV R1, A
    
    MOV A, @R1          ; [Step 1] ??? ?? ???? ????? (??? ??? ???? ??? 'RAM_BYTE')
    MOV R1, A
    
    ; [Step 2] ????? ???? R3 ?? AND ??? (???? ???????? ????? ?????? ?? ????)
    ANL A, R3           ; ?? A ??? ???? ??? ????? ??? ?? RAM ?? FLASH ????? ??? ???? ???
    
    XRL A, R1           ; [Step 3] ?? ??? ??? ?? ???? ?? ?????? ??? ?? ?? ???? ?????
         
    ; ????? ???? '??? ??? ???? ???? ?? ???' ???? ??, ?? ?? 'A' ?? ????? ???? ????? ?? 'R3' ?? ?? ???? ???
    ; ????? ??? ?? ????? ?? ??? ??? ??? ?? ?????? 0 ???? ??, ?? ???? 'JZ' ??????? ??? ??
    JZ  _MATCH
    AJMP _NOT_FOUND 

    

_MATCH:

    
    ; DPL/DPH abhi us node par hain jahan match mila
    ; Agar tumhe node ke 7th byte par jana hai:
    MOV  A, #7
    MOVC A, @A+DPTR ; Ab ye sahi hai: DPT+7 wala byte uthayega
    MOV  R5, A      ; R5 mein save ho gaya
    
    
       
   ;-------------------------------------------------------
; FUNCTION: COUNT_BITS
; INPUT:    R0 (Contains the 8-bit number 'n')
; OUTPUT:   R6 (Contains the total count of 1s)
; CYCLES:   19 Cycles (Execution time)
;-------------------------------------------------------

COUNT_BITS:
    
    MOV  A, R3          ; Copy n to Accumulator
    MOV  R6, #0         ; Initialize result counter to 0

    ; --- 8-Bit Unrolled Processing using JNC ---
    RRC  A              ; Bit 0 shift into Carry
    JNC  _BIT1          ; Skip if Carry is 0
    INC  R6             ; Increment count if 1
_BIT1:
    RRC  A              ; Bit 1 shift into Carry
    JNC  _BIT2
    INC  R6
_BIT2:
    RRC  A              ; Bit 2 shift into Carry
    JNC  _BIT3
    INC  R6
_BIT3:
    RRC  A              ; Bit 3 shift into Carry
    JNC  _BIT4
    INC  R6
_BIT4:
    RRC  A              ; Bit 4 shift into Carry
    JNC  _BIT5
    INC  R6
_BIT5:
    RRC  A              ; Bit 5 shift into Carry
    JNC  _BIT6
    INC  R6
_BIT6:
    RRC  A              ; Bit 6 shift into Carry
    JNC  _BIT7
    INC  R6
_BIT7:
    RRC  A              ; Bit 7 shift into Carry
    JNC  _BIT_END
    INC  R6
_BIT_END:
        ; --- Yahan R6 mein COUNT_BITS ka result hai ---
    ; --- Yahan R5 mein _MATCH ka data save hai ---
    
    MOV  A, R6      ; A mein pehla value lo
    ADD  A, R5      ; R5 ko usme jodo
    ;//a mul 8 
        ; --- Abhi A mein (R6 + R5) hai ---
    RL  A           ; x2 (A * 2)
    
    
    ; --- Ab A mein result * 8 hai ---
    ADD A, #8       ; Node offset add karo
    MOVC A, @A+DPTR ; Fetch karo
    MOV R1,A
  //  XRL A, R7       ; Compare with rx_byte
  //  JZ  _NODE_FOUND ; Agar match hua (Result 0)
  //  ANL  A, #0FCH       ; Mask: Last 2 bits clear (11111100)
   // MOV  R1, A          ; Temp store
    
  //  MOV  A, R7          ; rx_byte wapas lao
   // ANL  A, #0FCH       ; Iska bhi mask karo
    
  //  XRL  A, R1          ; Compare
  //  JZ   _NODE_FOUND    ; Agar ab match hua, toh FOUND par jao
    ; copy paste
     //  ADD A,#8
     ;first byte for flag 
     MOV  R6, #00H
     
    ; yha 1 byte me 4 possibility hogi flag ke liye yhi check krna hai  01 00 10 11 agr powwibili hai age bdho   nai toh not found 
    MOV  A, R7          ; rx_byte wapas lao Accumulator mein
    ANL  A, #0C0H       ; Akhiri ke 6 bits ko zero (clear) kar do
    RR A
    RR A
    INC A  ; yha binary no. ahe 
    //MOV R1,A
    //MOVC A,@A+DPTR
      
    
    JZ CHECK_0          ; Agar 0 hai
    DEC A
    JZ CHECK_1          ; Agar 1 hai
    DEC A
    JZ CHECK_2          ; Agar 2 hai
    DEC A
    JZ CHECK_3          ; Agar 3 hai
    LJMP _NOT_FOUND  ;eror 

       ;-------------------------------------------------------
; FUNCTION: FLAG CHECK 
; INPUT:    R1 (Contains the 2-bit number 'n')
; OUTPUT:   R6 (Contains the total count of 1s)
; CYCLES:   aprox Cycles (Execution time)
;-------------------------------------------------------

    
    
    
//AGAIN:
//    RRC A               ; Rotate Right through Carry
//    JNC SKIP_INC        ; Agar Carry = 0 hai (bit 0 tha), toh skip karo
//    INC R6              ; Agar Carry = 1 hai (bit 1 tha), toh count +1 karo r6 use kiya count krne ke liye  phle vala erase krke yeh fir se chalu krega   

//SKIP_INC:
//    DJNZ R1, AGAIN      ; Counter R1 decrement karo. Jab tak 0 na ho, loop chalao

    ; ----- Yahan R1 ka pehle wala kaam (loop count) poora ho gaya -----
    
    ; *** REUSE ***: Final '1's count r0 me hai.

//DONE:
                 ; Program samapt (ya aage ka code)

CHECK_3:
    ; (Agar 3 hai toh 3, 2, 1, 0 sab check honge)
    ; Yahan wo data use hoga jo upar MOVC se laya tha (usko kisi RAM ya register me rakh sakte hain, jaise R3 mein)
    ; Par image ke anusar agar seedha shift karna hai:
    MOV A, R1
    RR A 
    RR A
    RR A
    RRC A
    JNC _NOT_FOUND
    INC R6
    RL A 
    RRC A 
    JNC _SKIP_INC_3_1_
    INC R6
        _SKIP_INC_3_1_:
        RL A 
    RRC A 
    JNC _SKIP_INC_3_2_
    INC R6
    _SKIP_INC_3_2_:
    RL A 
    RRC A 
    JNC _SKIP_INC_3_3_
    INC R6
    _SKIP_INC_3_3_:
     SJMP DONE

CHECK_2:
    MOV A, R1
    RR A 
    RR A
    RRC A
    JNC _NOT_FOUND
    INC R6
    RL A 
    RRC A 
    JNC _SKIP_INC_2_1_
    INC R6
    _SKIP_INC_2_1_:
    RL A 
    RRC A 
    JNC _SKIP_INC_2_2_
    INC R6
    _SKIP_INC_2_2_:
     SJMP DONE
    
    

CHECK_1:

    
    MOV A, R1
    RR A 
    RRC A
    JNC _NOT_FOUND
    INC R6
    RL A 
    RRC A 
    JNC _SKIP_INC_1_1_
    INC R6
    _SKIP_INC_1_1_:
     SJMP DONE
    
    
    

CHECK_0:
    MOV A, R1
    RRC A
    JNC _NOT_FOUND
    INC R6
    SJMP DONE

DONE:
    ; Sabhi bits check ho gayi
    
    
    
     
    ; 2nd  address byte
    INC DPTR
    CLR A
    MOVC A,@A+DPTR
    MOV R0,A          ; low byte save

    INC DPTR
    CLR A
    MOVC A,@A+DPTR
    MOV DPH,A
    MOV DPL,R0        ; DPTR = next node address
        MOV A, R6           ; R6 ki value ko Accumulator mein laao
    ADD A, DPL          ; DPL (Low byte) ke sath R6 ko add karo
    MOV DPL, A          ; Wapas DPL mein save kar do
    JNC DPTR_NO_CARRY   ; Agar Carry nahi aaya toh aage bado
    INC DPH             ; Agar Carry aaya toh DPH (High byte) ko 1 se badha do
DPTR_NO_CARRY:
    ; Ab tumhara DPTR update ho chuka hai (DPTR = DPTR + R6)


    ; yha ek dptr aur judega   kyuki design me thoda change kiya hai  
    ;yha flag se hme pta chkega kitna 01 10 hai 
    ; usko add krne ke bad vha pr jump krna hai  
    ; fir yeh process start hoga 
    ; New node se 3 byte read
    ; successfully jod diya 

    CLR A
    MOVC A,@A+DPTR
    MOV current_identity,A
    ; yha identity check kr lo . bs attribute hai ya nai   if attribute than set flag 1   aur nai hai toh kuch nai  


    INC DPTR
    CLR A
    MOVC A,@A+DPTR
    MOV next_addr+1,A


    INC DPTR
    CLR A
    MOVC A,@A+DPTR
    MOV next_addr,A
    
    
    
    
; isko kya krna hai ? pkka iska kam nai h ab .  

      INC node_match_char_cnt
	  MOV R7, #1
      ;GPIO HIGH FLAG FOR NEXT 
      ;NEXT BYTE
      ; Signal Pulse (High for 1 cycle, then Low)
      ;SETB P1.0    ; Pin High (Trigger active)
      ;NOP          ; Small pulse width (Required for stable propagation)
      ;CLR P1.0     ; Pin Low (Reset for next event)
      


       
      


                  ; Return, Result is in R7
 
     
    
    RET

   
  
 _IDENTITY_NOT_ZERO:
     ; base addr plus 1 current identity minus 1 
      
      DEC  current_identity
      ; 
      MOV A, current_identity
      JZ  _NEXT_AT_AD
	 ;confused for aribue and logic)// use fir trie.
      ;next_addr
      INC DPTR
      CLR A
      MOVC A, @A+DPTR
      XRL A, R7
      JNZ _NOT_EQUAL_phoneme
      ;FOUND UNFIXED NODE PHONEME BYTE. SET FLAG
      ;vhi gpio high phoneme found 
      
     
    RET
	_NEXT_AT_AD  :
	MOV DPH, next_addr+1    ; High Byte
    MOV DPL, next_addr      ; Low Byte
	CLR A              ; Accumulator ko 0 kar do (Offset = 0)
    MOVC A, @A+DPTR    ; DPTR ke current address se 1 Byte padh kar 'A' mein store karo
    
	;JNZ                  ; CHECK ACC IS ZERO OR NOT 
	;ACC IS ZERO GO TRIE IF NOT GOES DOWN
	;JNB ACC.7, _TRIE_L ; ACC 1ST BIT BIT IS ZERO JUMP 00111001 BIT 1ST 0 JUMP 
	; JUMP TRIE (JNB ACC.7, _BIT_IS_ZERO)
	
	;WRITE A CODE OF ATTRIBUTE 
	INC DPTR
	CLR A              ; Accumulator ko 0 kar do (Offset = 0)
    MOVC A, @A+DPTR
	; LCALL _Send_Byte_To_IC3
	; YHA APNE MRJI REGISTER KA USE KRKE CODE WRIET KR SKTE HO . ALREADY HAI .
	; HO GYA YHI HAI SUCCINT RADIX TRIE . YHA RESET KR DENA BASE ADDR OR ROOT ADDR 
	 RET
    
   

_NOT_FOUND:
    MOV current_node_idx, #38H
    MOV current_node_idx+1, #00H
    MOV node_match_char_cnt, #0
    MOV next_addr, #00H
    MOV next_addr+1, #00H
	  MOV R7, #0
    ; shayd yha attribute flag dekhna pdega agr phle 1 tha toh ab swnd kr do.
  
    RET

_NOT_EQUAL_phoneme: 
   ; FLAG SET NOT FOUND IN UNFIXED NODE PHONEME 


 RET 


MASK_DATA: DB 01H, 02H, 04H, 08H, 10H, 20H, 40H, 80H
END
