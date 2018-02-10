;------------------------------------------------------;
; 8088ROM.2                                            ;
;------------------------------------------------------;
; DISPLAY ROUTINES                                     ;
;------------------------------------------------------;
Level0Mess
DebugM          DB DLo,   E,     BLo,   Dot0      ;0  Debug
VelM            DB V,     E,     L,     Dot1      ;1  Velocity
WheelsM         DB C,     OLo,   NLo,   Dot2      ;2  Controllers
XposeOctM       DB O,     CLo,   TLo,   Dot3      ;3  Transpose, Octave
Split1M         DB S,     P,     One,   Dot4      ;4  Splits 1
SysM            DB S,     YLo,   S,     Dot5      ;5  System
ResM            DB RLo,   E,     S,     Dot6      ;6  Resets
Split2M         DB S,     P,     Two,   Dot7      ;7  Splits 2
Patch1M         DB PLo,   CLo,   One,   Dot8      ;8  Program Change 1        
Patch2M         DB PLo,   CLo,   Two,   Dot9      ;9  Program Change 2        
Lev0Key10       DB Space, Space, Space, Dot0      ;10             
Lev0Key11       DB Space, Space, Space, Dot0      ;11             
Lev0Key12       DB Space, Space, Space, Dot0      ;12             
Lev0Key13       DB Space, Space, Space, Dot0      ;13             
Lev0Key14       DB Space, Space, Space, Dot0      ;14 ESCAPE      
Lev0Key15       DB Space, Space, Space, Bar8      ;15 ENTER       
;------------------------------------------------------;
DispMenu        proc    near                           ; Level 1 Display
;------------------------------------------------------;
                cmpb    [MenuTimer], 90                ; Waited 2 s ?
                je      WriteMenu                      ; Time to write
                ret                                    ;
                ;--------------------------------------;
WriteMenu       push    ax                             ; 
                push    bx                             ; 4 byte offsets
                movb    [MenuTimer], 255               ; Deactivate
                mov     bx, [Level0Task]               ; Lev0=0,2,4,6,8,...
                shl     bx                             ; Lev0=0,4,8,12,..
                ;--------------------------------------;
                mov     ax, offset(Level0Mess)[bx]     ;
                mov     bx, offset(Level0Mess)+2[bx]   ;
                mov     +12[bp], al                    ; Disp 1
                mov     +0[bp], ah                     ; Disp 2
                mov     +4[bp], bl                     ; Disp 3
                mov     +8[bp], bh                     ; BAR Disp
                pop     bx                             ;
                pop     ax                             ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
;----------------------------------------------;
ClearAllDisp    proc   near                    ;
;----------------------------------------------;
                push   ax                      ;
                push   cx                      ;
                push   di                      ;
                xor    ax, ax                  ; al=0
                movb    [MenuTimer], 255       ; Deactivate
                mov    [TempDisp], al          ; Flag Temp Disp nonactive
                mov    di, bp                  ; [bp]->Disp Level 0,1
                mov    cx, 16                  ; Clear primary display
                rep                            ;
                stosw                          ; store ax=0 32 times in +x[di]
                pop    di                      ;
                pop    cx                      ;
                pop    ax                      ;
                ret                            ;
                endp                           ;
;----------------------------------------------;
;------------------------------------------------------;
SetUpTempDisp   proc    near                           ;
;------------------------------------------------------;
                cmpb    [TempDisp], 00H                ; No active Temp Disp ?
                ja      SetUpTExit                     ; Yes, don't save
                cmpb    [MenuTimer], 90                ; Disp Menu
                jb      SetUpTExit                     ; Busy timing out
                call    SaveDisp                       ; Save CurrDisp
SetUpTExit      ret                                    ;
                endp                                   ;
;------------------------------------------------------;
SetUpExitDisp   proc    near                           ;
;------------------------------------------------------;
                cmpb    [MenuTimer], 90                ; Disp Menu
                jb      ExitSetUpDisp                  ; Busy timing out
                call    SetDispTS                      ; Set Temp Steady Attrib
ExitSetUpDisp   ret                                    ;
                endp                                   ;
;------------------------------------------------------;
; Set display to Temp, Steady state                    ;
;------------------------------------------------------;
SetDispTS       proc   near                    ;
                push   ax                      ;
                mov    ax, 0002H               ; al=Temp, Steady Attrib
                movb   [TempDisp], 01H         ; Flag Temp Disp active
                mov    +1[bp], al              ; Disp2 Attrib
                mov    +3[bp], ah              ; Disp2 Timer B=0
                mov    +5[bp], al              ; Disp3 Attrib
                mov    +7[bp], ah              ; Disp3 Timer B=0
                mov    +9[bp], al              ; BarLed Attrib
                mov    +11[bp], ah             ; BarLed Timer B=0
                mov    +13[bp], al             ; Disp1 Attrib
                mov    +15[bp], ah             ; Disp1 Timer B=0
                pop    ax                      ;
                ret                            ;
                endp                           ;
;----------------------------------------------;
; Reset to display to previous state           ;
;----------------------------------------------;
LoadDisp        proc   near                    ;
                push   cx                      ;
                push   di                      ;
                push   si                      ;
                mov    di, bp                  ; Curr Disp [bp]->CurrDispL0,1
                mov    si, di                  ; Start of Display Buffer
                sub    si, 64                  ; 64 bytes down
                jmp    SDL1                    ;
;----------------------------------------------;
; Save current display in DispLxBuff           ;
;----------------------------------------------;
SaveDisp        push   cx                      ;
                push   di                      ;
                push   si                      ;
                mov    si, bp                  ; Curr Disp [bp]->CurrDispL0,1
                mov    di, si                  ; Start of Display Buffer
                sub    di, 64                  ; 64 bytes down
                ;------------------------------;
SDL1            cld                            ; INC si, di
                mov    cx, 16                  ; Display Lev 0,1 Size=32 bytes
                rep                            ; [si]->[di]
                movsw                          ;
                ;------------------------------;
                pop    si                      ;
                pop    di                      ;
                pop    cx                      ;
                ret                            ;
                endp                           ;
;----------------------------------------------;
;---------------------------------------------------;
; Update Display Timers every 16*2mS = 32mS         ;
; Reset Timers to 0 every 32 counts: 32*32 = 1024mS ;
; 512mS is ON, 512mS is OFF                         ;
;---------------------------------------------------;
DoDispTimer     proc    near
                push    ax
                push    cx
                push    dx
                push    di
                ;------------------------------;
                mov     dx, 0002H              ;
                mov     di, bp                 ; [bp]->CurrDispL0,1
                ;------------------------------;
                ; Display Menu Timer: Exit Lev1;
                ;------------------------------;
                cmpb    [MenuTimer], 90        ; 2 seconds delay
                jae     DoDNoMenuTimer         ; Only inc up to 90
                cmp     [ButtonEnable], dh     ; dh=0, busy with Level 1 Keys ?
                je      DoDNoMenuTimer         ; Yes, dont count up
                incb    [MenuTimer]            ; Menu indicator
                ;------------------------------;
                ; Message Timer: Scroll Write  ;
                ;------------------------------;
DoDNoMenuTimer  decb    [MessTimer]            ; messages timer
                ;------------------------------;
                ; KBrd LED: 2nd Timer          ; If KLED>4=> Add Temp attrib
                ;------------------------------; to others of off,on,norm,slow
                mov     ax, [KBrdConnect]      ; i.e:         4   5  6    7
                cmp     al, 04H                ; 04=Temp On
                jb      DoDKCExit              ; KBrdConnect=0,1,2,3
                inc     ah                     ; ah=[KBrdConnect+1] 2nd timer
                and     ah, [KBrdLEDOnTime]    ; Temp Ontime = 32*16mS = 0.5 Sec
                jnz     DoDKC                  ; Not time to switch off perm
                xor     ax, ax                 ; KBrdConnect=KBrdConnect+1=0
DoDKC           mov     [KBrdConnect], ax      ; New values
DoDKCExit   
                ;------------------------------;
DoDTimers       ; Update Timers                ;
                ;------------------------------;
                mov     cx, 04                 ; 4 Displays: 3 7SEG+BAR
DoDTL2          add     di, dx                 ; [di]->2+CurrDispL0,1=Timers D2
                                               ; 4 bytes between blocks
                mov     ax, [di]               ; TimerA and TimerB
                inc     al                     ; TimerA: Blink
                cmp     -1[di], dl             ; dl=02, TimerB Activated ?
                jb      DoDTNotTimB            ;
                inc     ah                     ; TimerB: Stay on for 4sec only
DoDTNotTimB     and     al, [Seg7Cnt]          ; 00011111B 32 count max
                stosw                          ; mov [di], ax, di=di+2
                loop    DoDTL2                 ; Next Timer
                ;------------------------------; di=bp+16 on exit
                mov     cl, 08                 ; Eight LED's, ch=0
                inc     dl                     ; dx=0003H
DoDTL3
                mov     ax, [di]               ; Display+Timer=+16[bp]
                inc     ah                     ; Timer
                cmp     al, dl                 ; dl=3, BlinkRate: 2=Norm, 3=Slow
                je      DoDTSlow               ; Slow Speed
                and     ah, [ILEDCnt1]         ; 00001111B 16 count max 0F
DoDTSlow        and     ah, [ILEDCnt2]         ; 00111111B 64 count max 3F
DoDTL4          stosw                          ; mov [di], ax, di=di+2
                loop    DoDTL3                 ; Next Timer
                ;------------------------------;
ExitDoDT        pop     di
                pop     dx
                pop     cx
                pop     ax
                ret
                endp
;---------------------------------------------------;
DoDLED          proc    near                        ;
;---------------------------------------------------;
                add     si, dx                      ; si=+02
                mov     al, +11[di]                 ; al=0,1=Enable:A
                cmp     [Split], ah                 ; 0,1,2,3,4,5
                jne     DoDNotCurr                  ;
                add     al, dl                      ; dl=02, al=2,3
DoDNotCurr      xlat                                ; al=0,1,2,3->al=0,3,2,1
                mov     [si], al                    ;
                add     di, 40                      ;
                inc     ah                          ; ah=00-05
                add     si, dx                      ; si=+04
                ret                                 ;
                endp                                ;
;--------------------------------------------------------------;
; Update Display                                               ;
;--------------------------------------------------------------;
; A,B,C,D,E,F: Split States:                                   ;
; Number   Current  Enabled  Result (0=No 1=Yes)               ;
;      0         0        0       0  LED off                   ;
;      1         0        1       3  LED on slow blink         ;
;      2         1        0       2  LED on fast blink         ;
;      3         1        1       1  LED on steady             ;
;--------------------------------------------------------------;
DoDSplitTab     DB 00, 03, 02, 01                              ; Table:Split X
;--------------------------------------------------------------;
DoDisp          proc    near                                   ;
;--------------------------------------------------------------;
                push    ax
                push    bx
                push    cx
                push    dx
                push    di
                push    si
                ;------------------------------;
                mov     bx, Disp2              ; 1st Display HW Port
                mov     di, bp                 ; [bp]=[di]->CurrDispL0,1
                ;------------------------------;
DoDL3           ; Update Displays              ;
                ;------------------------------;
                mov     cx, 0004H              ; 4 Displays: 3 7SEG + 1 BAR
                mov     si, cx                 ; si=0004
                mov     dx, [Seg7Times]        ; dl=TimerA dh= TimerB times
DoDL4
                mov     ax, +1[di]             ; Display Timer Flag + TimerA
                cmp     al, 01H                ; TimerA active ?
                jb      DoDNotTimer1           ; No
                je      DoDTimer               ; TimerA: Blink
                ;------------------------------;
                cmp     +3[di], dh             ; TimerB: Time to switch off?
                jbe     DoDNotOff3             ; No, check if blink + temp
                mov     al, -62[di]            ; Display Save Buffer + 2
                xor     ah, ah                 ; Ensure Timer B = 0 cleared
                mov     [TempDisp], ah         ; Flag Temp Done = 0
                mov     +2[di], ax             ; TimerA, TimerB 
                mov     ax, -64[di]            ; Display Save Buffer
                mov     [di], ax               ; al=Prev Value ah=Prev Attrib
                jmp     DoDNext1               ; Switch off
                ;------------------------------;
DoDNotOff3      cmp     al, 03H                ; Temp and blink ?
                jb      DoDNotOff1             ; No

DoDTimer        cmp     ah, dl                 ; TimerA off cycle ?
                jbe     DoDNotOff1             ; No
DoDOff1
                xor     ax, ax                 ; ax=0, display off 
                jmp     DoDNext1               ;
DoDNotTimer1
DoDNotOff1      mov     al, [di]               ; Value
DoDNext1        mov     [bx], al               ; Display HW Port
                inc     bx                     ;
                add     di, si                 ; si=04, 4byte display blocks
                loop    DoDL4                  ; Next Display
                ;------------------------------;
                ; UpDate State of ILED's       ;
                ;------------------------------;
                mov     si, bp                 ;                     
                add     si, 16                 ; [si]->L0I0:D,L1I0:D
                push    si                     ; save
                ;------------------------------;
                ; Update KBrd LED              ; 
                ;------------------------------;
                mov     al,  [KBrdConnect]     ; Kbrd connected LED
                and     al,  00000011B         ; Values (4-7=Temp) -> 0-3
                mov     [si], al               ; KBrd LED +0[si]
                ;------------------------------;
                ; Update Power LED             ; 
                ;------------------------------;
                mov     al,  [PowerLED]        ; POWER LED
                mov     +4[si], al             ; Main Power LED
                ;------------------------------;
                ; Update Split A - F Green LEDs;  
                ;------------------------------;
                mov     bx, offset(DoDSplitTab); Xlation Table
                mov     di, [SplitCFG:A]       ;
                xor     ax, ax                 ; ah=0
                mov     dx, 0002H              ; dh=00, dl=02
                ;------------------------------;
                call    DoDLED                 ; Split A +2[si]  ah=00
                call    DoDLED                 ; Split B +6[si]  ah=01
                add     si, 04                 ; si=+14
                call    DoDLED                 ; Split C +14[si] ah=02
                sub     si, 10                 ; si=+08
                call    DoDLED                 ; Split D +8[si]  ah=03
                call    DoDLED                 ; Split E +12[si] ah=04
                sub     si, 06                 ; si=+10
                call    DoDLED                 ; Split F +10[si] ah=05
                ;------------------------------;
                ; Write Display Lists to LED's ; dx=0002H
                ;------------------------------;
                pop     si                     ; si back = bp+16
                mov     cl, 08H                ; 8 Indiv LED's, ch=0
                mov     bx, 0FF01H             ; State of ILED's in bh
DoDL5
                mov     ax, [si]               ; Display + Timer 
                cmp     al, dh                 ; dh=00, LED Off ?
                je      DoDOff2                ; Yes
                cmp     al, dl                 ; dl=02, Timer active ?
                jb      DoDNotTimer2           ; No
                cmp     ah, [ILEDOffTime]      ; 08H Timer off cycle ?
                jb      DoDNotOff2             ; No
DoDOff2
                xor     bh, bl                 ; Bitx: 0 = OFF
                jmp     DoDNext2               ;
DoDNotTimer2
DoDNotOff2      or      bh, bl                 ; Bitx: 1 = ON
DoDNext2        
                shl     bl                     ; Next ILED
                add     si, dx                 ; dx=02, 2byte blocks
                loop    DoDL5                  ; Next Display
                ;------------------------------;
                mov     [ILED], bh             ; Indiv LED Display HW Port
                mov     [ILEDState], bh        ; Current state of Indiv LEDs
                ;------------------------------;
ExitDoD         pop     si
                pop     di
                pop     dx
                pop     cx
                pop     bx
                pop     ax
                ret
                endp
;-----------------------------------------------------------;
; RomKey Addresses                                          ;
;-----------------------------------------------------------;
RomKeyAddr DW offset(RomKey00), offset(RomKey01)            ;
           DW offset(RomKey02), offset(RomKey03)            ;
;-----------------------------------------------------------;
;------------------------------------------------------------------;
; 0040-005F: 76 bytes for special and BIOS load affected variables ;64-95
; BIOS Load will only start loading from after these variables     ;
; .x shows coupling i.e. keep in same sequence                     ;
;------------------------------------------------------------------;
RomVarAddr                                                         ;
 DW 0001H     ; KeyScanEnable     64: Keyboard Scan: 1=Enable      ;
 DW 0001H     ; ButtonEnable      66: Buttons Enable = 01          ;     
 DW 0001H     ; WButtonEnable     68; Wheels Buttons Enable=01     ;
 DW 0001H     ; KButtonEnable     70; Keyboard Buttons Enable=01   ;    
 DW 0001H     ; TxEnable          72: Xmitter: 1,2=Enable 0=Disable;    
 DW 00FFH     ; ButtonPressed     74: Number 0-31 of pressed PKey  ;     
 DW 00FFH     ; KButtonPressed    76; No 0-4 of pressed KbrdKey    ;    
 DW 00FFH     ; WButtonPressed    78; No 1,2,4: pressed WheelsKey  ;
 DW RxEnd     ; RxBufferMax       80; Receiver Max BuffSize=RxEnd  ;    
 DW RxBuff    ; RxBuffer          82; Addr Receive BuffStart=RxBuff;
 DW offset(CFG1)    ;   SplitCFG  84; Ptr to curr Split A          ;    
 DW offset(CFG1+40) ;   SplitCFG  86; Ptr to curr Split B          ;
 DW offset(CFG1+80) ;   SplitCFG  88; Ptr to curr Split C          ;     
 DW offset(CFG1+120);   SplitCFG  90; Ptr to curr Split D          ;
 DW offset(CFG1+160);   SplitCFG  92; Ptr to curr Split E          ;
 DW offset(CFG1+200);   SplitCFG  94; Ptr to curr Split F          ;
;--------------------------------------------------------------------;
PatchVal                                                             ;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key00   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
;--------------------------------------------------------------------;
; Scroll Messages:                                                   ;
; Message Storage Area: 1st 2 bytes=stringlength (excl last 2 spaces);
; Add two spaces at end                                              ;
;--------------------------------------------------------------------;
                DB 9,0
PatchDefMess1   DB P,A,TLo,CLo,HLo,Space,DLo,E,F,Space,Space
                DB 4,0
DoneMess        DB DLo,OLo,NLo,E,Space,Space
                DB 30,0
Hallo-User      DB H,A,L,L,O,Space,Space,Dot,Space,Space,Dot,Space,Space
                DB P,rlo,E,S,S,Space,Space,Space,LBracket,Zero,RBracket,Space,
                DB S,tlo,A,rlo,tlo,Space,Space
                DB 18,0
Bios-Start      DB S,tlo,A,rlo,tlo,Space,blo,I,O,S,Space,
                DB L,O,A,dlo,Space,Space,Dot,Space,Space
                DB 6,0
Dots            DB Space,Space,Dot,Space,Space,Dot,Space,Space
                DB 5,0
Lines           DB Space,Space,Minus,Minus,Minus,Space,Space
                DB 15,0
NOffMess        DB NLo,OLo,TLo,E,Space,OLo,FLo,FLo,Space
                DB Zero,Space,OLo,RLo,Space,One,Space,Space
                DB 16,0
YesNoMess       DB PLo,RLo,E,S,S,Space
                DB LBracket,YLo,RBracket,Space,OLo,RLo
                DB Space,LBracket,N,RBracket,Space,Space
End-Strings
;---------------------------------------------------------------------------;
; Static Messages: Always start with Disp1, put spaces in if otherwise      ;
;---------------------------------------------------------------------------;
OnMess          DB O,NLo,Space           ; "On"
OffMess         DB O,FLo,FLo             ; "Off"
EnableMess      DB E,N,A                 ; "ENA"
DisableMess     DB DLo,I,S               ; "DIS"
ReceiverOn      DB RLo,OLo,NLo           ; "Ron"
ReceiverOff     DB RLo,OLo,F             ; "Rof"
PatchMess1      DB P,DLo,Space           ; "Pd"=Predef Patch
PatchMess2      DB P,Equal,Space         ; "P=x"= Patch No
SplitMess1      DB S,Equal,Space         ; "S=A,b,C,d,E,F"
AllOffMess1     DB A,NLo,FLo             ; "Anf" All Notes off
AllOffMess2     DB N,OLo,FLo             ; "Nof" Notes off
CFG1Mess        DB C,Equal,One           ; "C=1"
CFG2Mess        DB C,Equal,Two           ; "C=2"
CFG3Mess        DB C,Equal,Three         ; "C=3"
CFG4Mess        DB C,Equal,Four          ; "C=4"
SplitSMess      DB L,O,Space             ; Low Split position
SplitEMess      DB H,I,Space             ; High Split Position
TempSCMess      DB E,Equal,Space         ; ah=Max Value Tempx
KBOctMess       DB O,CLo,Space           ; Keyboard Octave
KBTposeMess     DB TLo,PLo,Space         ; Keyboard Transpose
KBPMess1        DB P,OLo,NLo             ; "Pon" Keyboard Patch
KBPMess2        DB P,S,DLo               ; "Psd" Keyboard Patch Send
XpGM            DB A,L,L                 ; Global
XpSM            DB I,NLo,DLo             ; Individual
;----------------------------------------------------;
; Translation Table for Buttons: 12 button keypad    ;
;---------------------------------------------------------------------------;
;      NUMBER PAD FRONT VIEW                                                ;
;      [ 7 ]=06  [ 8 ]=03  [ 9 ]=0E         [ XLAT ]=Scan                   ;
;      [ 4 ]=04  [ 5 ]=02  [ 6 ]=0C                                         ;
;      [ 1 ]=07  [ 2 ]=01  [ 3 ]=0F                                         ;
;      [ 0 ]=05  [ E ]=00  [ C ]=0D         C=CLEAR/ESCAPE=14  E=ENTER=15   ;
;      Four buttons unused: 10,11,12,13                                     ;
;---------------------------------------------------------------------------;
;              0  1  2  3  4  5  6  7  8   9   A   B   C  D   E  F ; Scan Val
ButtonTab DB  15, 2, 5, 8, 4, 0, 7, 1, 10, 11, 12, 13, 6, 14, 9, 3 ; Xlated Val
;---------------------------------------------------------------------------;
;---------------------------------------------------------------------------;
; Translation Table for BAR DISPLAYS: Codes 0 to 7                          ;
;---------------------------------------------------------------------------;
;--------------------;
; LED Bar Display    ;
; Digit   76543210   ;
; Segment 50673421   ;
;--------------------;
;         00000000B  ; "0"
;         01000000B  ; "1"
;         00000001B  ; "2"
;         00000010B  ; "3"
;         00001000B  ; "4"
;         00000100B  ; "5"
;         10000000B  ; "6"
;         00100000B  ; "7"
;         00010000B  ; "8"
;--------------------;
BarTab DB Bar0, Bar1, Bar2, Bar3, Bar4, Bar5, Bar6, Bar7
DotTab DB Dot0, Dot1, Dot2, Dot3, Dot4, Dot5, Dot6, Dot7
BinTab DB 00000000B, 01000000B, 00000001B, 01000001B   ; 0-3
       DB 00000010B, 01000010B, 00000011B, 01000011B   ; 4-7
       DB 00001000B, 01001000B, 00001001B, 01001001B   ; 8-11
       DB 00001010B, 01001010B, 00001011B, 01001011B   ; 12-15
       DB 00000100B, 01000100B, 00000101B, 01000101B   ; 16-19
       DB 00000110B, 01000110B, 00000111B, 01000111B   ; 20-23
       DB 00001100B, 01001100B, 00001101B, 01001101B   ; 24-27
       DB 00001110B, 01001110B, 00001111B, 01001111B   ; 28-31

       DB 10000000B, 11000000B, 10000001B, 11000001B   ; 32-35
       DB 10000010B, 11000010B, 10000011B, 11000011B   ; 36-39
       DB 10001000B, 11001000B, 10001001B, 11001001B   ; 40-43
       DB 10001010B, 11001010B, 10001011B, 11001011B   ; 44     
       DB 10000100B, 11000100B, 10000101B, 11000101B   ; 48     
       DB 10000110B, 11000110B, 10000111B, 11000111B   ; 52     
       DB 10001100B, 11001100B, 10001101B, 11001101B   ; 56    
       DB 10001110B, 11001110B, 10001111B, 11001111B   ; 60-63

       DB 00100000B, 01100000B, 00100001B, 01100001B   ; 64-67
       DB 00100010B, 01100010B, 00100011B, 01100011B   ; 68 
       DB 00101000B, 01101000B, 00101001B, 01101001B   ; 72  
       DB 00101010B, 01101010B, 00101011B, 01101011B   ; 76   
       DB 00100100B, 01100100B, 00100101B, 01100101B   ; 80   
       DB 00100110B, 01100110B, 00100111B, 01100111B   ; 84   
       DB 00101100B, 01101100B, 00101101B, 01101101B   ; 88   
       DB 00101110B, 01101110B, 00101111B, 01101111B   ; 92-95  

       DB 10100000B, 11100000B, 10100001B, 11100001B   ; 96-99  
       DB 10100010B, 11100010B, 10100011B, 11100011B   ; 100   
       DB 10101000B, 11101000B, 10101001B, 11101001B   ; 104  
       DB 10101010B, 11101010B, 10101011B, 11101011B   ; 108    
       DB 10100100B, 11100100B, 10100101B, 11100101B   ; 112    
       DB 10100110B, 11100110B, 10100111B, 11100111B   ; 116    
       DB 10101100B, 11101100B, 10101101B, 11101101B   ; 120   
       DB 10101110B, 11101110B, 10101111B, 11101111B   ; 124-127
;---------------------------------------------------------------------------;
; Translation Table for 7SEG+DOT DISPLAYS 256 bytes: Codes 0 to 255         ;
;---------------------------------------------------------------------------;
;                                a                                          ;
; D0 - SEG f                   -----                                        ;
; D1 - SEG g                 f|  g  |b                                      ;
; D2 - SEG e                   -----                                        ;
; D3 - SEG d                 e|  d  |c                                      ;
; D4 - SEG a                   -----   o Dp                                 ;
; D5 - SEG b                                                                ;
; D6 - SEG c                                                                ;
; D7 - SEG Dp                                                               ;
;---------------------------------------------------------------------------;
; NUMBERS
; "0"=0 "1"=1 "2"=2 "3"=3 "4"=4 "5"=5 "6"=6 "7"=7 "8"=8 "9"=9 
;---------------------------------------------------------------------------;
SEG7Tab DB Zero, One, Two, Three, Four, Five, Six, Seven, Eight, Nine
;---------------------------------------------------------------------------;
; LETTERS
; "A"=10 "b"=11 "c"=12 "d"=13 "E"=14 "F"=15 "g"=16 "H"=17 "i"=18 "J"=19 
; "k"=20 "L"=21 "M"=22 "n"=23 "o"=24 "P"=25 "Q"=26 "r"=27 "S"=28 "t"=29 
; "u"=30 "V"=31 "W"=32 "x"=33 "y"=34 "z"=35 
;---------------------------------------------------------------------------;
  DB A, B, C, D, E, F, G, H, I, J, K, L, M
  DB N, O, P, Q, R, S, T, U, V, W, X, Y, Z
;------------------------------------------------------------ Wheels Xlation Tab
Wheel0Tab
 DB   0,  0,  0,  0,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11
 DB  12, 13, 14, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25, 26, 27, 29
 DB  30, 31, 32, 33, 34, 35, 36, 38, 39, 40, 41, 42, 43, 44, 45, 47
 DB  47, 48, 49, 50, 51, 52, 53, 55, 56, 57, 58, 59, 60, 61, 62, 64
 DB  65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80
 DB  81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96
 DB  97, 98, 99,100,101,102,103,104,105,106,107,108,109,110,111,112
 DB 113,114,115,116,117,118,119,120,122,124,126,127,127,127,127,127
;----------------------------------------------------------------------;
Wheel1Tab
 DB   0,  0,  0,  0,  1,  2,  3,  4,  5,  7,  9, 11, 13, 17, 21, 25
 DB  29, 33, 37, 41, 45, 49, 53, 57, 59, 61, 63, 64, 65, 69, 73, 77
 DB  81, 85, 89, 93, 97,101,105,109,113,117,121,123,124,125,126,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
;----------------------------------------------------------------------;
Wheel2Tab ; Midpoint Raw = 49h - 53h (73-83) which should = 63d xlated ;
 DB   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0    ;000-015
 DB   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0    ;016-031
 DB   1,  2,  3,  4,  5,  7,  9, 11, 13, 15, 17, 19, 21, 23, 25, 27    ;032-047
 DB  30, 32, 34, 36, 38, 45, 48, 50, 52, 54, 56, 58, 58, 59, 59, 60    ;048-063
 DB  60, 60, 62, 62, 63, 63, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64    ;064-079
 DB  64, 64, 64, 64, 64, 64, 64, 64, 65, 65, 70, 75, 80, 85, 90, 95    ;080-095
 DB 100,105,110,115,120,125,127,127,127,127,127,127,127,127,127,127    ;096-111
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127    ;112-127
;----------------------------------------------------------------------;
Wheel3Tab
 DB   0,  0,  0,  0,  1,  2,  3,  4,  5,  7,  9, 11, 13, 17, 21, 25
 DB  29, 33, 37, 41, 45, 49, 53, 57, 59, 61, 63, 64, 65, 69, 73, 77
 DB  81, 85, 89, 93, 97,101,105,109,113,117,121,123,125,127,127,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
 DB 127,127,127,127,127,127,127,127,127,127,127,127,127,127,127,127
;---------------------------------------------------------------------------;
; Table of Velocity Table Addresses:                                        ;
; RamVelTab = custom, 0 = Raw Velocities, 1-9 = Xlate, 10 = Const Velocities;
;---------------------------------------------------------------------------;
VAddr  DW      offset(Vel1), offset(Vel2), offset(Vel3), offset(Vel4)
       DW      offset(Vel5), offset(Vel6), offset(Vel7), offset(Vel8)
       DW      RamVelTab
;---------------------------------------------------------------------------;
; Velocity Tables: 128 bytes long                                           ;
;---------------------------------------------------------------------------;
Vel0   ;Keep velocity values as detected                                    ;
;---------------------------------------------------------------------------;
       ;   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  
Vel1  DB   0,  2,  4,  6,  9, 12, 15, 17, 20, 22, 25, 27, 29, 31, 33, 36
      DB  38, 40, 42, 44, 46, 48, 50, 52, 54, 56, 58, 60, 62, 63, 64, 66
      DB  67, 68, 70, 72, 73, 74, 75, 77, 79, 80, 81, 82, 83, 85, 86, 87
      DB  88, 89, 91, 92, 93, 94, 95, 96, 97, 98, 99, 99,100,101,102,103
      DB 104,104,105,106,106,107,107,108,109,110,111,111,112,113,113,114
      DB 114,115,115,116,116,116,117,117,118,118,118,119,119,119,120,120
      DB 120,121,121,122,122,122,122,123,123,123,123,124,124,124,124,124
      DB 125,125,125,125,125,125,126,126,126,127,127,127,127,127,127,127
       ;   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  
Vel2  DB   0,  1,  1,  1,  1,  1,  2,  2,  2,  2,  2,  3,  3,  3,  3,  3
      DB   3,  3,  3,  3,  3,  4,  4,  4,  4,  4,  5,  5,  5,  6,  6,  6
      DB   7,  7,  7,  7,  7,  7,  8,  8,  8,  8,  9,  9,  9, 10, 10, 10
      DB  11, 11, 12, 12, 12, 13, 13, 13, 14, 14, 15, 15, 16, 16, 17, 17
      DB  18, 19, 19, 20, 20, 21, 22, 23, 23, 24, 25, 26, 27, 27, 28, 28
      DB  29, 30, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 44
      DB  45, 46, 47, 48, 50, 52, 53, 55, 56, 58, 60, 62, 64, 66, 67, 69
      DB  71, 73, 75, 78, 80, 83, 85, 88, 92, 96,100,104,108,114,120,127
       ;   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  
Vel3  DB   0,  1,  1,  2,  2,  2,  3,  3,  3,  4,  4,  5,  5,  6,  6,  7
      DB   7,  7,  8,  8,  8,  9,  9, 10, 10, 11, 11, 12, 12, 13, 13, 14
      DB  15, 16, 16, 17, 17, 18, 18, 19, 20, 21, 22, 22, 23, 23, 24, 25
      DB  26, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 35, 36, 37, 38, 39
      DB  40, 41, 42, 43, 44, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54
      DB  55, 56, 57, 59, 60, 62, 63, 64, 65, 67, 68, 69, 70, 71, 72, 73
      DB  74, 75, 76, 78, 80, 82, 83, 84, 86, 87, 89, 91, 92, 94, 95, 97
      DB  99,100,101,103,105,107,109,111,113,115,117,119,121,123,125,127
       ;   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  
Vel4  DB  25, 25, 25, 26, 26, 26, 26, 26, 27, 27, 27, 28, 28, 29, 29, 30
      DB  31, 31, 32, 32, 33, 33, 34, 34, 35, 35, 36, 36, 37, 37, 38, 38
      DB  39, 39, 40, 41, 41, 42, 42, 43, 44, 44, 45, 46, 46, 47, 47, 48
      DB  49, 49, 50, 50, 51, 52, 52, 53, 54, 55, 56, 56, 57, 58, 58, 59
      DB  60, 61, 62, 63, 64, 64, 65, 66, 67, 67, 68, 68, 69, 70, 71, 72
      DB  73, 74, 75, 76, 77, 78, 79, 80, 81, 81, 82, 83, 84, 85, 86, 87
      DB  88, 89, 90, 91, 93, 94, 95, 96, 97, 98, 99,100,101,102,103,104
      DB 106,108,111,113,115,117,119,121,123,123,124,125,125,126,127,127
       ;   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  
Vel5  DB   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0
      DB   0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  1,  1,  2,  2,  3,  3
      DB   4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18
      DB  18, 19, 20, 21, 22, 23, 23, 24, 25, 25, 26, 27, 28, 29, 30, 31
      DB  32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 46, 48, 49
      DB  50, 51, 52, 53, 55, 56, 57, 59, 60, 62, 63, 65, 66, 67, 68, 69
      DB  70, 72, 74, 76, 77, 79, 81, 82, 84, 85, 87, 89, 91, 93, 94, 96
      DB  98,100,102,104,106,108,110,111,112,116,118,120,122,124,126,127
       ;   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  
Vel6  DB   0,  1,  2,  3,  5,  7,  9, 11, 13, 15, 17, 19, 21, 22, 23, 25
      DB  26, 28, 30, 31, 33, 34, 35, 36, 37, 38, 39, 40, 42, 43, 45, 46
      DB  47, 48, 49, 51, 52, 53, 54, 55, 57, 58, 59, 60, 61, 63, 64, 65
      DB  66, 67, 68, 69, 70, 71, 72, 74, 75, 76, 77, 79, 80, 81, 83, 84
      DB  86, 88, 89, 90, 91, 92, 93, 94, 95, 96, 96, 97, 98, 98, 99,100
      DB 101,102,103,103,104,105,105,106,106,107,107,108,109,110,111,112
      DB 112,113,114,114,115,115,116,117,117,118,118,119,119,120,121,121
      DB 122,122,123,123,124,124,125,125,126,126,126,126,127,127,127,127
       ;   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  
Vel7  DB   0,  1,  2,  3,  5,  7,  9, 11, 13, 15, 17, 19, 21, 22, 23, 25
      DB  26, 27, 29, 30, 31, 34, 35, 35, 36, 37, 39, 40, 41, 42, 43, 44
      DB  45, 46, 47, 48, 49, 49, 50, 50, 51, 51, 52, 53, 53, 54, 55, 56
      DB  56, 57, 57, 58, 59, 59, 60, 60, 60, 61, 61, 62, 62, 62, 62, 63
      DB  63, 63, 63, 64, 64, 64, 64, 65, 65, 65, 66, 66, 66, 67, 67, 67
      DB  68, 68, 69, 69, 70, 70, 70, 71, 72, 73, 73, 74, 75, 75, 76, 77
      DB  78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 87, 88, 90, 92, 94, 96
      DB  98,100,101,102,103,105,107,109,111,113,115,117,120,123,126,127
       ;   0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  
Vel8  DB   0,  1,  2,  3,  5,  7,  9, 11, 13, 15, 17, 19, 21, 22, 23, 25
      DB  26, 27, 29, 30, 31, 34, 35, 35, 36, 37, 39, 40, 41, 42, 43, 44
      DB  45, 46, 47, 48, 49, 49, 50, 51, 52, 54, 55, 57, 58, 60, 61, 62
      DB  62, 63, 64, 65, 66, 67, 67, 68, 68, 69, 70, 71, 72, 72, 73, 73
      DB  74, 74, 75, 76, 76, 77, 77, 77, 77, 78, 78, 78, 78, 78, 79, 79
      DB  79, 80, 80, 81, 81, 82, 82, 82, 82, 83, 83, 83, 83, 84, 84, 84
      DB  84, 85, 86, 87, 87, 88, 89, 90, 90, 91, 92, 92, 93, 93, 94, 96
      DB  98,100,101,102,103,105,107,109,111,113,115,117,120,123,126,127
;---------------------------------------------------------------------------;
;----------------;
; Get3Dec Tables ;
;----------------;
Xlat100s      DW      0, 100, 200, 300, 400, 500, 600, 700, 800, 900
Xlat10s       DB      0,  10,  20,  30,  40,  50,  60,  70,  80,  90
;----------------------------------------------------------------------;
OnesTab   
 DB  Zero, One, Two, Three, Four, Five, Six, Seven, Eight, Nine ;0-9
;----------------------------------------------------------------------;

RomEndCode

;----------------------------------------------------------------------;
; Unused section of ROM                                                ;
;----------------------------------------------------------------------;
                ds      RomSize-(RomEndCode-RomStartCode)-ResetOffset-1, 00H ;
;------------------------------------------------;
; Reset vector                                   ;
;------------------------------------------------;
reset           
                jmp     offset(RomMain)+1, 0000H ; 5 bytes = EA 01 E0 00 00
                                                 ; i.e offset:segment=0000:E000
                                                 ; if no problem with first FF
                                                 ; remove the +1
;                nop
;                nop
;                ;------------------------------;
;                ; Equivalent jumps to above    ;
;                ;------------------------------;
;                jmp     main                   ; 3 bytes
;
;                jmp     RomStart+1, RomSegment ; compiled as JMP F000:E000
;                                               ; 5 bytes

;--------------------------------------------;
; Top part of ROM                            ;
;--------------------------------------------;
;               ds      ResetOffset-14, 00H  ;
;============================================; END 8088

