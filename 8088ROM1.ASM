;---------------------------------------------------------------------------;
; CHANGES (1) 
;         (2) 
;---------------------------------------------------------------------------;
;--------------------------------------------------------;
; 8088 CPU keyboard                                      ;
; 8088ROM.1                                              ;
;----------------------------------------------------------------------;
; Create file 8088.ASM by:                                             ;
; COPY 8088RAM.1+8088RAM.2+8088RAM.3+8088ROM.1+8088ROM.2 8088.ASM      ;
;======================================================================;
; Unused section of ASM                                                ;
;----------------------------------------------------------------------;
B0              ds      (BlockSize/2)-(EndCode-StartCode),00H ;
B1              ds      BlockSize,01H    ;
B2              ds      BlockSize,02H    ;
B3              ds      BlockSize,03H    ;
B4              ds      BlockSize,04H    ;
B5              ds      BlockSize,05H    ;
B6              ds      BlockSize,06H    ;
;==================================================================;
; ROM START                                                        ;
;==================================================================;
romstartcode
rommain         proc    near  
                nop            ; 6264 gets a FF in here sometimes
                ;--------------------------------------------------;
                ; set segment registers and stack area in 2116 RAM ;   
                ;--------------------------------------------------;
                xor     ax, ax                         ; ax=0
                mov     ds, ax                         ; All SEG REG = 0
                mov     ss, ax
                mov     es, ax
                mov     sp, StackTop                   ; SP=RAMTOP=8191
                ;-----------------------------------------;
                ; Initialise Temp Reset Vector            ;
                ; Keep if BIOS dump in progress           ; ax=0000H
                ;-----------------------------------------;
                movw    [NMIVectorLo], offset(RomINTInit) ; int offset
                mov     [NMIVectorHi], ax                 ; int segment
                mov     [PermINT], al                     ; Disable Perm INT
                mov     [Timer0], ax                      ; Reset
                mov     [RxIn], ax                        ; Start of Dump
                mov     [GoRamBIOS], al                   ; Disable RAM Bios JMP
                mov     [ILEDState], al                   ; Indiv LED's
                mov     [ResetDefault], al                ; 0=No Reset Defaults
                mov     [RxEnable], al                    ; Disable Receiver
                movw    [ButtonEnable], 0001H             ; 01=Enable Buttons
                movw    [ButtonPressed], 00FFH            ; FF=NoKey
                ;-----------------------------------------;
                ; Initialise OVFLOW and DIV0 INT Vectors  ; ax=0000H
                ;-----------------------------------------;
                movw    [OVVectorLo], offset(RamOV)       ; int offset
                mov     [OVVectorHi], ax                  ; int segment
                movw    [DIV0VectorLo], offset(RamDIV0)   ; int offset
                mov     [DIV0VectorHi], ax                ; int segment
                ;-----------------------------------------;
                ;----------------------------;
                ; Initialise RAM Areas       ; 
                ;----------------------------;
                cld                          ; clear DF: i.e. INC DI
                mov     cx, ax               ; cx=ax=0
                mov     di, ButtonsState     ; Buttons State
                mov     cl, 10H              ; size=32/2=16 words
                rep                          ;
                stosw                        ; store 00H 32 times
                ;------------------------------;
                ; Initialise UART              ;
                ;------------------------------;
                call    InitUART               ;
                ;------------------------------;
                ; Initialise bp to display area;
                ;------------------------------;
                call    SetLevel0              ; [bp]->DispArea
                movb    [ScrollTime], 64       ; Scrolling Delay
                ;------------------------------;
                ;--------------------------------------------;
                ; Write Start Up Messages                    ;
                ;--------------------------------------------;
                movb    [ILED], 0FFH                         ;
                call    Delay1                               ;
                call    ClearDisp1to5                        ; Clear 5 displays
                mov     bx, offset(Hallo-User)               ;
                call    WriteScroll1                         ;
                ;--------------------------------------------;
Romloop1           
                ;--------------------------------------;
                ; Check if BIOS Load Key is pressed    ;
                ;          Normal Start key pressed    ;
                ;          Ram image copy key pressed  ;
                ;          Help key pressed            ;
                ;--------------------------------------;
                ; Calls to key routine addresses       ;
                ;--------------------------------------;
                mov     bx, [ButtonPressed]            ; Table Offset, bh=0
                shl     bl                             ; *2=Word offset
                jc      RomExitKey                     ; Unpressed Key=FF
                and     bl, 00000111B                  ; Only Keys 0,1,2,3
                calln   offset(RomKeyAddr)[bx]         ; Do Key xx
                ;--------------------------------------;
                movb    [ButtonPressed], 0FFH          ; clear key pressed
                call    WriteScroll1                   ;
RomExitKey  
                ;--------------------------------------;
                ; Receive Bios via Midi                ;
                ; Use AX, DI                           ;
                ;--------------------------------------;
                call    ReceiveBios                    ; 
                ;------------------------------;
                ; JMP to RAMBios               ;
                ;------------------------------;
                cmpb    [GoRAMBios], 01H       ; Enabled ?
                jne     RomLoop1               ; No
                movb    [GoRAMBios], 00H       ; Disable
                jmp     startcode              ; goto RAM
                ;------------------------------;
                endp                           ; 
;======================================================================;
; Temporary NMI INT Procedure: Change after initialisation completed   ;
;======================================================================;
RomINTInit      proc    near                        ;
                push    ax                          ;
                push    bx                          ;
                push    cx                          ;
                push    dx                          ;
                push    di                          ;
                push    si                          ;
                ;-----------------------------------;
                decb    [MessTimer]                 ; Used by WriteScroll
                incb    [Timer0]                    ;
                jnz     NotTime                     ; Every 2*256=512 mS
                xorb    [ILEDState], GreenLED1      ;
                mov     al, [ILEDState]             ;
                mov     [ILED], al                  ;
                ;-----------------------------------;
                ; Update Display                    ;
                ;-----------------------------------;
NotTime         mov     al, +0[bp]                  ; Display 2          
                mov     ah, +4[bp]                  ; Display 3
                mov     [Disp2], ax                 ; HW Disp2+Disp3
                mov     al, +8[bp]                  ; BARLed 
                mov     ah, +12[bp]                 ; Display 1 
                mov     [BARLED], ax                ; HW BarLed+Disp1
                ;-----------------------------------;
                ; Read Buttons (Program Keys)       ;
                ;-----------------------------------;
                cmpb    [ButtonEnable], 01H         ; Enabled ?
                jne     NotButton                   ; No
                call    ReadButton                  ;
NotButton
                ;--------------------------------------;
                ; Initialise Perm Reset Vector         ;
                ;--------------------------------------;
                cmpb    [PermINT], 01H                 ; Enabled ?
                jne     NotPermINT                     ; No
                movw    [NMIVectorLo], offset(INTProc) ; int offset
                ;--------------------------------------;
NotPermINT      pop     si                             ;
                pop     di                             ;
                pop     dx                             ;
                pop     cx                             ;
                pop     bx                             ;
                pop     ax                             ;
                iret                                   ;
                endp                                   ; INTInit
;------------------------------------------------------;
; Load new RAM Bios                                    ;
;------------------------------------------------------;
RomKey01        proc    near                           ; Load BIOS
                movb    [RxEnable], 01H                ; Enable Receiver
                movw    [RxIn], 0000H                  ; Reset Inp Ptr=0 start
                mov     bx, offset(Bios-Start)         ;
                ret                                    ;
;------------------------------------------------------;
; Copy Bios from ROM                                   ;
;------------------------------------------------------;
RomKey02        mov     bx, offset(Dots)               ;
                ret                                    ;
;------------------------------------------------------;
; Start with defaults loaded                           ;
;------------------------------------------------------;
RomKey03        movw    bx, offset(Lines)              ;
                movb    [ResetDefault], 01H            ; Reset Defaults
                jmp     RomKeyL1                       ;
;------------------------------------------------------;
; Enable Jump to RAM BIOS                              ;
;------------------------------------------------------;
RomKey00        mov     bx, offset(Dots)               ;
RomKeyL1        movb    [GoRAMBIOS], 01H               ; Enable
                movb    [RxEnable], 00H                ; Disable Receiver
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
;--------------------------------------------------;
; Initialise UART Mode and Command                 ;
; Need an internal reset if mode is to be changed  ;
;--------------------------------------------------;
; UARTData        equ    Block6+0   ; A0=0 UART registers
; UARTControl     equ    Block6+1   ; A0=1
; UARTStatus      equ    Block6+1   ; A0=1
; UARTMode        equ    01001110B  ; 1 stop, no parity, 8 data, x16
; UARTCommand1    equ    00000001B  ; Xmitter Enable
; UARTDTRLo       equ    00000111B  ; Xmit + Receive + DTR output lo
; UARTDTRHi       equ    00000101B  ; Xmit + Receive + DTR output hi
; UARTCommand3    equ    00010101B  ; Xmit + Receive enable, reset error
; UARTCommand4    equ    00110111B  ; Xmit + Receive enable, reset error
                                    ; Turn on(lo) RTS, DTR outputs
; UARTReset       equ    01000000B  ; Internal reset after MODE set
;---------------------------------------------------;
InitUART        proc    near                        ;
;---------------------------------------------------;
                movb    [UARTControl], UARTMode     ;
                jmp     InitUART0                   ; wait
InitUART0       movb    [UARTControl], UARTReset    ;
                jmp     InitUART1                   ; wait
InitUART1       movb    [UARTControl], UARTMode     ;
                jmp     InitUART2                   ; wait
InitUART2       movb    [UARTControl], UARTCommand4 ;
                ret                                 ; 
                endp                                ;
;---------------------------------------------------;
;-----------------------------------------------;
; Check if Xmitter is ready                     ;
; TxReady Bit means Data Buffer is empty        ;
; TxReady is NOT conditional on TxEnable=1 or   ;
; on CTS=0 (Output Pin TxRdy IS dependent on    ;
; these two                                     ;
;-----------------------------------------------;
CheckXmitReady  proc    near                    ;
                testb   [UARTStatus], 00000100B ; AND TxEmpty Bit D2
                jz      CheckXmitReady          ; Xmitter busy D2=0
                ret                             ; Xmitter empty D2=1
;-----------------------------------------------;
; Check if Receiver is ready                    ;
; RxReady Bit means Data Buffer is full         ;
;-----------------------------------------------;
CheckRxReady    testb   [UARTStatus], 00000010B ; AND RxReady Bit D1
                jz      CheckRxReady            ; Receiver not ready D1=0
                ret                             ; 
                endp                            ;
;----------------------------------------------;
; Send 1 Midi byte                             ;
; No Check for Overflow                        ;
;----------------------------------------------;
SendMidi        proc near                      ;
                ;------------------------------;
                testb   [UARTStatus], 00000100B; AND TxEmpty Bit D2
                jz      EXSendMidi1            ; Xmitter busy D2=0
                ;------------------------------;
                push    bx                     ;
                cmpb    [TxEnable], 01H        ; 1,2=Enabled
                jb      EXSendMidi             ; No: TxEnable=0
                ja      DoXSend                ; 2: Extra Xmit Buffer
                ;------------------------------;
                ; Use 256 byte buffer: MidiBuff; Used for short Midi codes
                ;------------------------------;
                mov     bx, [MidiOut]          ;
                cmp     [MidiIn], bl           ;
                je      EXSendMidi             ; nothing new
                mov     bl, [bx]               ;
                incb    [MidiOut]              ; wrap around FF-->00
                mov     [UARTData], bl         ; Xfer data to UART Xmitter
                pop     bx                     ;
                ret                            ;
                ;------------------------------;
                ; Use 1024 byte buffer: XBuff  ; Used for single codes block
                ;------------------------------;
DoXSend         cmpw    [XBuffIn], 0000H       ; Anything in Buffer ?
                je      EXSendMidi0            ; No, exit
                ;------------------------------;
                mov     bx, [XBuffOut]         ;
                mov     bl, XBuff[bx]          ;
                incw    [XBuffOut]             ;
                decw    [XBuffIn]              ; Done sending 1 byte
                mov     [UARTData], bl         ; Xfer data to UART Xmitter
                pop     bx                     ;
                ret                            ;
                ;------------------------------;
EXSendMidi0     movb    [TxEnable], 01H        ; Reset to normal Tx
EXSendMidi      pop     bx                     ;
EXSendMidi1     ret                            ;
                endp                           ;
;------------------------------------------------------; 
ReceiveBios     proc    near                           ; 
;------------------------------------------------------;
                cmpb    [RxEnable], 00H                ; Receiver enabled ?
                je      RBiosNotRx                     ; 0=Disabled
                ;--------------------------------------;
                ; Check Data Ready in UART register    ;
                ;--------------------------------------;
                testb   [UARTStatus], 00000010B        ; AND RxReady Bit D1
                jz      RBiosNotRx                     ; Receiver not yet 
                ;--------------------------------------; Ready if D1=0
                push    ax                             ;
                push    di                             ;
                ;--------------------------------------; Ready if D1=0
                ; Read and Store Byte                  ;
                ;--------------------------------------;
                mov     al, [UARTData]                 ; Read Midi Byte
                mov     di, [RxIn]                     ; Receiver In Ptr
                mov     +96[di], al                    ; Store Byte in Buff
                inc     di                             ; Next Position
                mov     [RxIn], di                     ; Receiver In Ptr
                call    XlateBinaryTab                 ; Xlate and display
                ;--------------------------------------; points to next pos.
                pop     di                             ;
                pop     ax                             ;
RBiosNotRx      ret                                    ;
                endp                                   ;
;------------------------------------------------------;

;------------------------------------------------------;
WriteDone       proc    near                           ; Write "Done" Message
;------------------------------------------------------;
                movw    [Message], offset(DoneMess)    ;
                call    WriteScroll                    ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
;----------------------------------------------;
; Calculate Current Split Block                ;
;----------------------------------------------;
CSTab           DB      0,40,80,120,160,200    ;
;----------------------------------------------;
CurrSplitCFG    proc    near                   ;
                mov     bx, [Split]            ; Current A-F = 0-5, bh=0
                mov     bl, offset(CSTab)[bx]  ; 0-5 = 0,40,80,120,160,200
                ret                            ;
;----------------------------------------------;
SetUpSplit      mov     bx, [Split]            ; Current A-F = 0-5, bh=0
                mov     bl, offset(CSTab)[bx]  ; 0-5 = 0,40,80,120,160,200
                add     bx, [SplitCFG:A]       ; bx=Split*40+SplitCFGA
                ret                            ;
                endp                           ;
;----------------------------------------------;
GSSTab          DB      0,16,32,48,64,80,96    ;
;----------------------------------------------;
GetSplitStr     proc    near                   ;
;----------------------------------------------;
                mov     bx, [Split]            ; 0-5 = Split A-F
                mov     bl, offset(GSSTab)[bx] ;
                add     bx, offset(SplitCFGStr); [bx]->SplitCFGStr
                ret                            ;
                endp                           ;
;----------------------------------------------;
;------------------------------------------------------------------;
; Put single Key Offset value in KeyOffset                         ;
;------------------------------------------------------------------;
; Single key transpose in Xpose             : +0 to +12            ;
; Octave offset in Octave                   : +0 to +2, -0 to -2   ;
; Scan correction (Scan to Key) in ScanToKey: 0 to 127             ;
; KeyOffset = TOTAL of Xpose+Octave+ScanToKey                      ;
; This when added to Scan Number (0-127) will give final Key Number;
; Use VAL for + values, 256-VAL for - values, when added to byte   ;
; will then automatically adjust to addition or subtraction        ;
; For example:                                                     ;
;   Octave = +2: [Octave]=2                                        ;
;   Octave = -2: [Octave]=256-2=254                                ;
;   Key Scan = 50 => Add +2 => KeyNumber = 52                      ;
;                    Sub -2 => KeyNumber = 50+254=304=(304-256)=48 ;
;------------------------------------------------------------------;
CalcKOS         proc   near                ;
                push   ax                  ;
                mov    al, +6[bx]          ; Octave:X Octave +2 stored as 24
                                           ; Octave -1 stored as 256-12=244
                add    al, +8[bx]          ; XPose:X Stored as 0 to 12(+), 
                                           ; 256 to 244(-)
                add    al, [ScanToKey]     ; Basic correction: same for A,B,C
                mov    +9[bx], al          ; KeyOffSet:X Final Total Value
                pop    ax                  ;
                ret                        ;
                endp                       ;
;------------------------------------------;
CalcKeyOffSet   proc   near                ;
                push   bx                  ;
                push   cx                  ;
                mov    bx, [SplitCFG:A]    ;
                mov    cx, 0006H           ; Splits A-F
                ;--------------------------;
CalcKOSL1       call   CalcKOS             ; Split A-F
                add    bx, 40              ;
                loop   CalcKOSL1           ;
                ;--------------------------;
                pop    cx                  ;
                pop    bx                  ;
                ret                        ;
                endp                       ;
;-----------------------------------------------;
; Setup Velocity Table                          ;
;-----------------------------------------------;
SetVT           proc    near                    ;
                xor     bx, bx                  ; bx=0
                mov     bl, +15[di]             ; VelMode:X, byte
                dec     bl                      ; Table1=0, Table9=8
                js      ExitSetVT               ; vel0=255, no table
                shl     bl                      ; *2 word ptr
                mov     bx, offset(VAddr)[bx]   ; Address: Table 1-9
                mov     +4[di], bx              ; VelTab:X Store Address
ExitSetVT       ret                             ;
;-----------------------------------------------;
SetVelTable     push    bx                      ;
                push    cx                      ;
                push    di                      ;
                mov     di, [SplitCFG:A]        ;
                mov     cx, 0006H               ; Splits A-F
                ;-------------------------------;
SetVTL1         call    SetVT                   ; Set Splits A-F
                add     di, 40                  ;
                loop    SetVTL1                 ;
                ;-------------------------------;
                pop     di                      ; 
                pop     cx                      ; 
                pop     bx                      ; 
                ret                             ;
                endp                            ;
;-----------------------------------------------;
                ;-------------------------------;
                ; General Exit for all ESC Keys ;
                ;-------------------------------;
L0:X:K14        call    SetLevel0               ; Reset to Level 0
                call    ClearAllDisp            ;
                jmp     ExitLev1Esc             ;
;-----------------------------------------------;
;------------------------------------------------------;
; Execute Button Pressed commands                      ;
;------------------------------------------------------;
DoButtonExit    proc    near    
ExitDoButton    ret
DoButton        ;--------------------------------------;
                ; Do Button Pressed                    ;
                ;--------------------------------------;
                mov     bx, [ButtonPressed]            ; bl=Offset into Table
                shl     bl                             ; bl=Word offset, bh=0
                jc      ExitDoButton                   ; bl=FF, buttons in use
                ;--------------------------------------;
                cmp     [ButtonEnable], bh             ; bh=0, 0 => Disabled ?
                je      ExitDoButton                   ; Yes
                ;--------------------------------------;
                mov     [Escape],   bh                 ; Clear Escape
                mov     [ButtonEnable], bh             ; Disable Buttons
                movb    [MenuTimer], 255               ; Disable Menu Timer
                ;--------------------------------------;
                ; Check Level 0 (Top) or 1 (Bottom)    ;
                ;--------------------------------------;
                cmp     [Level01], bh                  ; bh=0, Level 0 or 1 ?
                ja      DoLevel1                       ; is 1
                ;======================================;
DoLevel0        ; Do Level0                            ;
                ;======================================;
                mov     [Level0Task], bl               ; Lev0 Task No 0,1,2,3,.
                jmpn    (+KeyAddrLev0)[bx]             ; Do Key xx Level 0
                ;--------------------------------------;
L0Key00         jmp     ExitKeyLev0                    ; Debug Buttons 
                ;--------------------------------------;
L0Key01         jmp     ExitKeyLev0                    ; Velocity Contour Select
                ;--------------------------------------;
L0Key02         jmp     ExitKeyLev0                    ; Calibrate Wheels
                ;--------------------------------------;
L0Key03         jmp     ExitKeyLev0                    ; Transpose and Octave 
                ;--------------------------------------;
L0Key04         jmp     ExitKeyLev0                    ; Splits 1
                ;--------------------------------------;
L0Key05         jmp     ExitKeyLev0                    ; System
                ;--------------------------------------;
L0Key06         jmp     ExitKeyLev0                    ; Resets
                ;--------------------------------------;
L0Key07         jmp     ExitKeyLev0                    ; Splits 2
                ;--------------------------------------;
L0Key08         jmp     ExitKeyLev0                    ; Patches 1
                ;--------------------------------------;
L0Key09         jmp     ExitKeyLev0                    ; Patches 2
                ;--------------------------------------;
                ; These keys have no addresses for Lev1;
                ; Clear Screen and keep at Level 0     ;
                ;--------------------------------------;
L0Key10         
L0Key11         
L0Key12         
L0Key13         
L0Key14                                                ; [ESCAPE]
L0Key15         jmp     ExitLev0Esc                    ; [RETURN]
                ;======================================; END LEVEL 0
DoLevel1        ; Do Level1                            ;
                ;======================================;
                ;--------------------------------------;
                ; Jmp to addresses                     ;
                ;--------------------------------------;
                mov     si, [Level0Task]               ; Lev0 Number (0-9)*2 
                mov     si, KeyAddrLev1:X[si]          ; Lev 1 Table start
                jmpn    [bx+si]                        ; Do Key xx
                ;======================================;
                ; Lev1: Key 0 = Debug                  ;
                ; Lev1: Key 1 = Velocity Contours      ;
                ; Lev1: Key 2 = Wheels Configuration   ;
                ; Lev1: Key 3 = Transpose, Octave      ;
                ; Lev1: Key 4 = Splits 1               ;
                ; Lev1: Key 5 = System                 ;
                ; Lev1: Key 6 = Resets                 ;
                ; Lev1: Key 7 = Splits 2               ;
                ; Lev1: Key 8 = Patches 1              ;
                ; Lev1: Key 9 = Patches 2              ;
                ;======================================;
;------------------------------------------------------;
ExitKeyLev0     call    SetLevel1                      ; Shifted now to Level 1
ExitLev0Esc     call    ClearAllDisp                   ;
                call    WriteMenu                      ; Level 0 Indicator
ExitLev1Esc     movb    [MenuTimer], 255               ; Disable Menu Timer
                jmp     ExitAllKey                     ;
ExitKeyRoutine  movb    [MenuTimer], 00H               ; Start count: MenuDisp
ExitAllKey      movb    [ButtonPressed], 0FFH          ; Clear prev entry
                movb    [ButtonEnable], 01H            ; Enable Buttons
                ret                                    ; 
                endp                                   ;
;------------------------------------------------------;
;----------------------------------------------------;
; Send Data Area or Buffer                           ; si=Start of Area (addr)
;----------------------------------------------------; di=End of Area (addr)
SendData        proc    near                         ;
                push    si                           ;
                movb    [TxEnable], 00H              ; Disable other Xmits
                movb    [KeyScanEnable], 00H         ; Scan Disabled
                ;------------------------------------;
SDCheckXmit     call    CheckXmitReady               ; Xmitter ready ?
                ;------------------------------------;
                xor     ax, ax                       ; ah=0
                lodsb                                ; mov al,[si]: Get Byte
                ;------------------------------------;
                cmpb    [Bit7Enable], 00H            ; 7 Bits Disabled ?
                je      SD8Bit                       ; Yes, send byte as 8 bits
                ;------------------------------------;
                shl     ax                           ; ah = 0 or 1 from al D7
                shr     al                           ; al now = al-128
                mov     [UARTData], ah               ; Send ah=al D7=0,1
                call    CheckXmitReady               ;
                ;------------------------------------;
SD8Bit          mov     [UARTData], al               ; Send Byte: 8 or 7 Bits
                call    XlateBinaryTab               ; Xlate and display
                cmp     si, di                       ; Done ?
                jb      SDCheckXmit                  ;
                ;------------------------------------;
                movb    [KeyScanEnable], 01H         ; Scan Enabled
                movb    [TxEnable], 01H              ; Enable other Xmits
                pop     si                           ;
                ret                                  ;
                endp                                 ;
                ;------------------------------------;
;------------------------------------------------------;
; Read Wheels Values                                   ;
;------------------------------------------------------;
ReadWheels      proc    near                           ;
                ;--------------------------------------;
                cmpb    [WheelsEnable], 00H            ; Disabled ?
                je      RWExit1                        ; Yes
                ;--------------------------------------;
                push    ax                             ;
                push    cx                             ;
                push    di                             ;
                ;--------------------------------------;
                cld                                    ;
                mov     di, Wheels                     ; Wheels HW Port
                mov     cx, WheelsMaxCount             ; Max Count
                ;--------------------------------------;
                in      al, 00H                        ; Start Pulses on 74221's
                ;--------------------------------------;
RWWait          mov     al, [Wheels]                   ; ah=al=[Wheels]
                and     al, bl                         ;
                loopnz  RWWait                         ; No
                ;--------------------------------------;
RWDone          sub     cl, WheelsMaxCount-1           ;
                neg     cl                             ; Count Down->Up
                mov     [si], cl                       ;
                ;--------------------------------------;
RWExit          pop     di                             ;
                pop     cx                             ;
                pop     ax                             ;
RWExit1         ret                                    ;
                endp                                   ;
;------------------------------------------------------;
; Read Wheels Values                                   ;
;------------------------------------------------------;
ReadWheelsX     proc    near                           ;
;------------------------------------------------------;
ReadWheels0     push    bx                             ;
                push    si                             ;
                mov     bl, 00000001B                  ; Wheel0 = D0
                mov     si, Wheel0                     ; State storage
                jmp     DoRW                           ;
                ;--------------------------------------;
ReadWheels1     push    bx                             ;
                push    si                             ;
                mov     bl, 00000010B                  ; Wheel1 = D1
                mov     si, Wheel1                     ;
                jmp     DoRW                           ;
                ;--------------------------------------;
ReadWheels2     push    bx                             ;
                push    si                             ;
                mov     bl, 00000100B                  ; Wheel2 = D2
                mov     si, Wheel2                     ;
                jmp     DoRW                           ;
                ;--------------------------------------;
ReadWheels3     push    bx                             ;
                push    si                             ;
                mov     bl, 00001000B                  ; Wheel0 = D3
                mov     si, Wheel3                     ;
                ;--------------------------------------;
DoRW            call    ReadWheels                     ; Fire MonoStables
                pop     si                             ;
                pop     bx                             ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
GetWheelsCFG    proc    near                    ;
;-----------------------------------------------;
                mov     bx, [WheelsNum]         ; 0,1,2,3
                shl     bx                      ; *16=WheelsCFG Block
                shl     bx                      ;
                shl     bx                      ;
                shl     bx                      ;
                add     bx, WheelsCFG           ; Wheel0 CFG Block
                ret                             ;
                endp                            ;
;-----------------------------------------------;
; Display Wheels                                ;
;-----------------------------------------------;
DoWheelsDisp    proc    near                    ;
                push    ax                      ;
                push    bx                      ;
                cmpb    [WheelsNum], 0FFH       ;
                je      DWDExit                 ;
                ;-------------------------------;
                cmpb    [DisplayWheels], 01H    ;
                je      DWDRaw                  ;
                ja      DWDXlated               ;
                jmp     DWDExit                 ;
                ;-------------------------------;
DWDRaw          mov     bx, [WheelsNum]         ; 0,1,2,3
                mov     al, Wheel0[bx]          ; Raw Value
                jmp     DWDDisp                 ;
                ;-------------------------------;
DWDXlated       call    GetWheelsCFG            ; [bx]->WheelXCFG Block
                mov     al, +4[bx]              ; Wheel0Value=+4[bx]
                ;-------------------------------;
DWDDisp         call    WriteHex                ;
                call    XlateBinaryTab          ;
                movb    [TempDisp], 10H         ; Active Temp Disp 
DWDExit         pop     bx                      ; 
                pop     ax                      ;
                ret                             ;
                endp                            ;
;------------------------------------------------------;
; Check if ReadWheels means Wheels values has changed  ;
;------------------------------------------------------;
WheelsChange    proc    near                           ;
                push    ax                             ;
                push    bx                             ;
                push    cx                             ;
                push    dx                             ;
                push    di                             ;
                push    si                             ;
                ;--------------------------------------;
                xor     cx, cx                         ; cx=0
                mov     dx, cx                         ; dx=0
                mov     cl, 04H                        ; 4 Wheels
                mov     dl, 01H                        ; dh=0, dl=01
                ;--------------------------------------;
                cmp     [WheelsEnable], dh             ; dh=0, disabled ?
                je      WCExit                         ;
                ;--------------------------------------;
                mov     si, WheelsCFG                  ; Start of Wheels CFG
                mov     bx, offset(Wheel0Tab)          ; [bx]->Wheel0Tab
                mov     di, Wheel0                     ; Raw value storage
                ;--------------------------------------;
WCLoop          mov     [si], dh                       ; dh=0, no Change: Start
                mov     al, [di]                       ; New Raw Value
                mov     +3[si], al                     ; Raw Value
                xlat                                   ; al = new xlated value
                ;--------------------------------------;
                cmp    +2[si], dl                      ; dl=01, Range = 0-127 ?
                je     WCRangeDone                     ; Yes
                jb     WCRange0To64                    ;
WCRange0To255   shl    al                              ; This will decr sens
                and    al, 01111111B                   ; Keep values<127
                jmp    WCRangeDone                     ;
WCRange0To64    inc    al                              ; so that 64 can also
                shr    al                              ; be reached:128/2=64
WCRangeDone     ;--------------------------------------;
                cmp     al, +4[si]                     ; New = Old ?
                je      WCNext                         ; Yes
                ;--------------------------------------;
WCIsChange      mov     [si], dl                       ; dl=01, changed
                ;--------------------------------------;
WCNext          mov     +4[si], al                     ; XLated Value
                inc    di                              ; Wheel0: 1byte
                add    si, 010H                        ; WheelCFG Block Size 16
                add    bx, 080H                        ; Xlation Table 128
                loop   WCLoop                          ; Next Wheel   
                ;--------------------------------------;
WCExit          pop    si                              ;
                pop    di                              ;
                pop    dx                              ;
                pop    cx                              ;
                pop    bx                              ;
                pop    ax                              ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
WWTab           DB Dot0, Dot1, Dot2, Dot3, Dot4, Dot5, Dot6, Dot7
                DB Dot8, Dot9, Dot10,Dot11,Dot12,Dot13,Dot14,Dot15
                DB Dot16,Dot17,Dot18,Dot19,Dot20,Dot21,Dot22,Dot23
                DB Dot24,Dot25,Dot26,Dot27,Dot28,Dot29,Dot30,Dot33,Dot36
;------------------------------------------------------;
WriteWheel      proc   near                            ;
;------------------------------------------------------;
                push   ax                              ; Wheel value
                push   bx                              ; 
                ;--------------------------------------;
WWDispNoSave    shr    al                              ; DIV 4
                shr    al                              ; al=0-127->0-31
                inc    al                              ; al=1-32
                mov    bx, offset(WWTab)               ;
                xlat                                   ; al=Dot1-Dot32
                mov    +8[bp], al                      ; BarDisp
                ;--------------------------------------;
                pop    bx                              ; 
                pop    ax                              ; Wheel value back
WheelNoDisp     ret                                    ; Used: disable WheelDisp
                endp                                   ;
;------------------------------------------------------;
XmitMidi2       proc   near                      ;
;------------------------------------------------;
                push    bx                       ;
                mov     bx, [MidiIn]             ; MidiBuff Input Ptr
                jmp    Xmit2                     ;
;------------------------------------------------;
XmitMidi3       push    bx                       ;
                mov     bx, [MidiIn]             ; MidiBuff Input Ptr
                mov     [bx], dl                 ; 
                inc     bl                       ; wrap around if FF-->00
Xmit2           mov     [bx], ah                 ; 
                inc     bl                       ; wrap around if FF-->00
                mov     [bx], al                 ; 
                inc     bl                       ;
                mov     [MidiIn], bl             ; End with MidiIn-->Current
                pop     bx                       ;
                ret                              ;
                endp                             ;
;------------------------------------------------------------;
; Do Custom Volume control via Vert Offs in SplitCFG's       ;
; Wheel Values: 0-63   = Neg offset: 0-63 -> (256-63)-(256-1);
; Wheel Values: 65-127 = Pos offset: 65-127 -> 0-63          ;
;------------------------------------------------------------;
DoWVolume       proc    near                     ; 
                ;--------------------------------;
                cmp     al, 040H                 ; + or - ?
                jb      DWVolNeg                 ; Neg
                ;--------------------------------;
                and     al, 00111111B            ; Same as sub 40H
                jmp     DWVolL1                  ; 64->0, 127->63
                ;--------------------------------;
DWVolNeg        neg     al                       ; neg=not+1=256-val
                ;--------------------------------;
DWVolL1         mov     +13[di], al              ; Split Vert offs
                ;--------------------------------;
                ret                              ;
                endp                             ;
;------------------------------------------------;
; Xmit ChannelPressure Change Values: D0-DF,01-7F; [si]->WheelsCFG
;------------------------------------------------; [(bx+)di]->Split
DoWChPressure   proc    near                     ; 
                push    dx                       ;
                mov     ah, 0D0H                 ; Channel Pressure Code
                jmp     DoXmit2                  ;
;------------------------------------------------;
; Xmit Program Change Values: C0-CF, 01-7F       ; [si]->WheelsCFG
;------------------------------------------------; [(bx+)di]->Split
DoWProgChange   push    dx                       ;
                mov     ah, 0C0H                 ; Patch Change Code
                ;--------------------------------;
DoXmit2         or      ah, +10[di]              ; Active Split Channel Number
                ;--------------------------------;
                call    XmitMidi2                ;
                ;--------------------------------;
                pop     dx                       ;
                ret                              ;
                endp                             ;
;------------------------------------------------;
; Xmit Pitch Bend: E0-EF, LSB 0-127, MSB=0-127   ;
; al=MSB Value 0-127                             ;
;------------------------------------------------;
DoWPitchBend    proc    near                     ; 
                push    dx                       ;
                mov     ah, 00H                  ; PitchBend LSB=0
                mov     dl, 0E0H                 ; PitchBend Code
                jmp     DoXmit3                  ;
;------------------------------------------------;
; Xmit Controller: B0-BF, 01-3F, MSB=0-127       ; [si]->WheelsCFG
; al=MSB Value 0-127, ah=Controller Number 01-7F ; [(bx+)di]->Split
;------------------------------------------------;
DoWController   push    dx                       ;
                mov     ah, +2[bx+di]            ; Wheel Controller Number 0-127
                mov     dl, 0B0H                 ; Controllers Code
                jmp     DoXmit3                  ;
;------------------------------------------------;
; Xmit Note Off Values: 90-9F/80-8F,00/01-7F     ; [si]->WheelsCFG
;------------------------------------------------; [(bx+)di]->Split
DoWNoteOff      push    dx                       ;
                mov     ah, al                   ;
                mov     dx, [MidiNoteOff]        ; dl=80,90 dh=7F,00
                shr     dh                       ; 7F->3F
                mov     al, dh                   ;
                jmp     DoXmit3                  ;
;------------------------------------------------;
; Xmit Note On Values: 90-9F,01-7F               ; [si]->WheelsCFG
;------------------------------------------------; [(bx+)di]->Split
DoWNoteOn       push    dx                       ;
                mov     ah, al                   ;
                mov     al, 040H                 ; Velocity constant = 64
                mov     dl, 090H                 ; Note On Code
                ;--------------------------------;
DoXmit3         or      dl, +10[di]              ; Active Split Channel Number
                call    XmitMidi3                ;
                ;--------------------------------;
                pop     dx                       ;
DoWNothing      ret                              ;
                endp                             ;
;------------------------------------------------;
; Xmit Note On+Off Values: 90-9F/80-8F,00/01-7F  ; [si]->WheelsCFG
;------------------------------------------------; [(bx+)di]->Split
DoWNoteOnOff    proc    near                     ; 
                call    DoWNoteOn                ;
                call    DoWNoteOff               ;
                ret                              ;
                endp                             ;
;------------------------------------------------;
;------------------------------------------------------;
; Do Wheels: Execute assigned wheels routines          ;
;------------------------------------------------------;
DoWheels01      proc    near                           ;
;------------------------------------------------------;
                movb    [WheelsVar1], 10H              ; [bx]->WheelAddr=+16
                movw    [WheelsVar2], WheelsCFG        ; [si]->Wheels0CFG
                call    DoWheels                       ;
                ret                                    ;
;------------------------------------------------------;
DoWheels23      movb    [WheelsVar1], 16H              ; [bx]->WheelAddr=+22
                movw    [WheelsVar2], WheelsCFG+32     ; [si]->Wheels2CFG
                call    DoWheels                       ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
; Do Wheels: Execute assigned wheels routines          ;
;------------------------------------------------------;
DoWheels        proc    near                           ;
                push    ax                             ;
                push    bx                             ;
                push    cx                             ;
                push    dx                             ;
                push    di                             ;
                push    si                             ;
                ;--------------------------------------;
                shrb    [WheelsEnable]                 ; 00->FF (0=Disabled) ?
                jnc     DWExit                         ; Yes, is = 0, keep = 0
                ;--------------------------------------; Else if = 1 now = 0
                mov     di, [SplitCFG:A]               ; Ptr to Split A
                xor     cx, cx                         ; cx=0
                mov     bx, cx                         ; bx=0
                mov     dx, cx                         ; dx=0
                mov     dl, 10H                        ; dl=16
                ;--------------------------------------;
                ; Split Loop                           ;
                ;--------------------------------------;
DWSplitLoop     cmpb    [di], 80H                      ; Split enabled ?
                jb      DWNextSplit                    ; No
                ;--------------------------------------;
                ; Wheels Loop                          ;
                ;--------------------------------------;
                mov     cl, 02H                        ; 2 Wheels, ch=bh=dh=0
                mov     bl, [WheelsVar1]               ; [bx]->WheelAddr=+16,+22
                mov     si, [WheelsVar2]               ; [si]->WheelsCFG
                ;======================================;
DWWheelLoop     cmp     [si], bh                       ; bh=0, Any Change ?
                je      DWNextWheel                    ; No
                ;--------------------------------------;
                ; Check Curr Disp Save                 ;
                ;--------------------------------------;
                cmp     [TempDisp], bh                 ; bh=0, No act Temp Disp?
                ja      DWNoSetUp                      ; Yes, don't save
                cmpb    [MenuTimer], 90                ; Disp Menu Timeout
                jb      DWNoSetUp                      ; Busy timing out
                call    SaveDisp                       ; Save CurrDisp
                ;--------------------------------------;
DWNoSetUp       mov     al, +4[si]                     ; Current Wheel Value
                ;--------------------------------------; in WheelsCFG
                calln   +8[si]                         ; Call display routine
                calln   [bx+di]                        ; call assigned routine
                ;--------------------------------------; in SplitCFG
                ; Set Temp Steady Attrib               ;
                ;--------------------------------------;
                cmpb    [MenuTimer], 90                ; Disp Menu Timeout
                jb      DWNextWheel                    ; Busy timing out
                call    SetDispTS                      ; Set Temp Steady Attrib
                ;--------------------------------------;
DWNextWheel     add     si, dx                         ; dx=0010H NextWheelsCFG
                add     bl, 03H                        ; Next Wh.Addr in Split
                loop    DWWheelLoop                    ; Check Next Wheel
                ;======================================;
DWNextSplit     add     di, 40                         ; Size of Splitblocks
                cmp     di, [SplitCFG:F]               ; Done Split A-F ?
                jbe     DWSplitLoop                    ; No
                ;--------------------------------------;
                movb    [WheelsEnable], 01H            ; Enable 
                ;--------------------------------------;
DWExit          pop     si                             ;
                pop     di                             ;
                pop     dx                             ;
                pop     cx                             ;
                pop     bx                             ;
                pop     ax                             ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
;  Send All Notes off on 16 Ch                         ;
;------------------------------------------------------;
AllNotesOff1    proc    near                       ;
                push    ax                         ;
                push    bx                         ;
                push    cx                         ;
                push    dx                         ;
                ;-------------------------------------; 
                movw    [Message], offset(AllOffMess1); "Anf" = All Notes Off
                call    WriteStaticPS                 ;
                xor     bx, bx                        ; Buff Input Ptr = 0
                mov     [XBuffOut], bx                ; Start output from 0
                mov     al, 0B0H                      ; al=All Notes Off
                mov     dx, 007BH                     ; Allnotesoff:D1=123 D2=00
                ;-------------------------------------;
                mov     cx, 16                     ; 16 Midi Channels
ANO1L1            
                mov     XBuff[bx], al              ; CH MODE = Bx
                mov     (XBuff+1)[bx], dx          ; D1=123: ALL NOTES OFF D2=00
                add     bl, 03H                    ; Next three bytes
                inc     al                         ; Next Channel: B0-BF
                loop    ANO1L1                     ;
                ;----------------------------------;
                mov     [XBuffIn], bx              ; End with In-->Current
                movb    [TxEnable], 02H            ; Enable XtraSend in MidiSend
                ;----------------------------------;
ANO1Exit        pop     dx                         ;
                pop     cx                         ;
                pop     bx                         ;
                pop     ax                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Send 128 Notes off on Curr Ch                    ;
;--------------------------------------------------;
AllNotesOff2    proc    near                       ;
                push    ax                         ;
                push    bx                         ;
                push    dx                         ;
                ;-------------------------------------; 
                movw    [Message], offset(AllOffMess2); "Nof" = Notes Off"
                call    WriteStaticPS                 ;
                call    SetUpSplit                    ; Get curr Active Split
                mov     al, [MidiNoteOff]             ; al=80/90 
                or      al, +10[bx]                   ; Split Channel Number
                xor     dx, dx                        ; dl=0 1st Note Number 
                                                      ; dh=0 Velocity
                mov     [XBuffOut], dx                ; Start output from 0
                mov     bx, offset(XBuff)             ; Buffer Ptr
                ;-------------------------------------;
ANO2L1          mov     [bx], al                      ; Note off = 8x,9x
                inc     bx                            ; Next Position
                mov     [bx], dx                      ; NOTES NUMBER + VEL
                inc     bx                            ; Next 
                inc     bx                            ; Next: Total 3 bytes
                inc     dl                            ; Next Note: 0-127
                jns     ANO2L1                        ; cx (128) notes
                ;-------------------------------------;
                movw    [XBuffIn], 128*3              ; End with In-->Current
                movb    [TxEnable], 02H               ; Enable XtraSend:MidiSend
                ;-------------------------------------;
ANO2Exit        pop     dx                         ;
                pop     bx                         ;
                pop     ax                         ;
                ret                                ;
                endp                               ;
;-----------------------------------------------------------;
; Define new Patch Xmit definitions                         ;
;-----------------------------------------------------------;
; Enter as: K CC PPP:  K = Keynumber 0-9,                   ;
;                     CC = Channelnumber 01-16              ;
;                    PPP = Patchnumber 000-127              ;
;-----------------------------------------------------------;
DefPatchXmit    proc    near                                ;
                push    ax                                  ;
                push    bx                                  ;
                push    cx                                  ;
                movw    [Message], offset(PatchDefMess1)    ;
                call    WriteScroll                         ;
                ;-------------------------------------------;
                ; Get KeyNumber and Channel Number          ;
                ;-------------------------------------------;
                call    Get1Dec                             ; PatchKey 0-9
                mov     [PKey], ax                          ;
                call    Delay00                             ;
                ;-------------------------------------------;
PLGetCh         call    Get2Dec                             ; Channel 1-16
                dec     ax                                  ; Ch 1-16 now 0-15
                mov     [PChannel], ax                      ;
                call    Delay00                             ;
                cmp     al, 0FH                             ; Channel>15 ?
                ja      PLGetCh                             ; Yes: Try again
                ;-------------------------------------------;
PLGetPatch      call    Get3Dec                             ;
                call    Delay00                             ;
                mov     [PPatch], al                        ;
                cmp     al, 080H                            ; Patch No 0-127
                jb      PLPatchOK                           ;
                cmp     al, 0FFH                            ; Patch No = FF
                je      PLPatchOK                           ; -> NonActive
                jmp     PLGetPatch                          ;
                ;-------------------------------------------;
PLPatchOK       mov     bx, [PKey]                          ;
                mov     cx, 0005H                           ; Keyxx MUL 32
                shl     bx, cl                              ;
                add     bx, [PChannel]                      ; word increase
                add     bx, [PChannel]                      ; 0-30 added
                ;-------------------------------------------;
                mov     ax, 00C0H                           ;
                or      al, [PChannel]                      ;
                mov     ah, [PPatch]                        ;
                mov     PatchXmit[bx], ax                   ;
                ;-------------------------------------------;
ExitPatchXmit   call    WriteDone                           ;
                pop     cx                                  ;
                pop     bx                                  ;
                pop     ax                                  ;
                ret                                         ;
                endp                                        ;
;-----------------------------------------------------------;
;------------------------------------------------;
; Xmit Patch Change Numbers: 0-99 or 0-127       ;
;------------------------------------------------;
DoPatchXmit2    proc    near                     ; al = Patch Number 0-127
                push    ax                       ;
                push    bx                       ;
                call    SetUpSplit               ; Get curr Active Split
                mov     ah, 0C0H                 ; Patch Change
                add     ah, +10[bx]              ; Split Channel Number
                mov     bx, [MidiIn]             ; MidiBuff Input Ptr
                ;--------------------------------;
                mov     [bx], ah                 ; PATCH CHANGE = Cx
                inc     bl                       ; wrap around if FF-->00
                mov     [bx], al                 ; PATCH NUMBER 0-7F
                inc     bl                       ;
                ;--------------------------------;
                mov     [MidiIn], bl             ; End with MidiIn-->Current
                pop     bx                       ;
                pop     ax                       ;
                ret                              ;
                endp                             ;
;--------------------------------------------------;
; Xmit Patch Xmit definitions                      ;
;--------------------------------------------------;
DoPatchXmit1    proc    near                       ;
                push    ax                         ;
                push    cx                         ;
                push    di                         ;
                push    si                         ;
                ;----------------------------------;
                xor     ax, ax                     ; ax=0
                mov     [XBuffOut], ax             ; Start output from 0
                mov     al, [PredefPatch]          ; No 0-9
                mov     cx, 0005H                  ; Keyxx MUL 32
                shl     ax, cl                     ;
                mov     si, PatchXmit              ; add 0-288 offset
                add     si, ax                     ; into table
                mov     di, XBuff                  ; Xmit Buff Start
                ;----------------------------------;
                mov     cx, 16                     ; 16 Patch Changes
DPL2            lodsw                              ; mov ax,[si], si=si+2
                cmp     ah, 0FFH                   ; al=Patch Change+Ch
                loope   DPL2                       ; ah=Patch Number 0-127
                stosw                              ; mov,[di],ax, di=di+2
                loop    DPL2                       ; ah=FF:NonActive
                ;----------------------------------;
                sub     di, XBuff                  ; Xmit Buff Start
                mov     [XBuffIn], di              ; End with In-->Current
                movb    [TxEnable], 02H            ; Enable XtraSend in MidiSend
                pop     si                         ;
                pop     di                         ;
                pop     cx                         ;
                pop     ax                         ;
                ret                                ;
                endp                               ;
;==================================================;
Lev1:9                                             ;
;======================================;
; Level 1: Key 9 = Patches 2           ;
;======================================;
;  [7]           [8]           [9]     ; 
;                                      ; 
;                                      ; 
;--------------------------------------;
;  [4]           [5]           [6]     ; 
;                                      ; 
;                                      ; 
;--------------------------------------;
;  [1]           [2]           [3]     ;                        
;Get Predef   Config Predef SEND Predef; 
;Patch 0-9    Patch 0-9     Patch 0-9  ;              
;--------------------------------------;
;  [0]         [ENTER]       [ESCAPE]  ; 
;Send Auto                   Return to ; Send 128 Patch Changes and NoteOn-Offs
;Patch Check                  Level 0  ;              
;======================================;
;----------------------------------------------------;
DispPredefPatch proc    near                         ; Write Predefined Patch No
                mov     al, [PredefPatch]            ;
                call    WriteDecPS                   ; "Pdx"
                movb    +12[bp], P                   ; Disp 1
                movb    +0[bp], DLo                  ; Disp 2
                ret                                  ;
                endp                                 ;
;----------------------------------------------------;
                ;--------------------------------------;
                ; Keys [1],[2],[3] operate on          ;
                ; predefined patches                   ;
                ;--------------------------------------;
L0:9:K01        call    DefPatchXmit                   ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:9:K02        call    Get1Dec                        ; Get Patch Key 0-9
                cmp     al, 09H                        ;
                ja      L0:9:K02                       ; Only 0-9 allowed
                mov     [PredefPatch], al              ;
                call    DispPredefPatch                ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:9:K03        call    DispPredefPatch                ;
                call    DoPatchXmit1                   ; send predef patches
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Send Patch Change + Note On-Off Mess ;
                ;--------------------------------------;
L0:9:K00        push    bx                             ;
                push    cx                             ;
                push    dx                             ;
                ;--------------------------------------;
                call    SetUpSplit                     ; [bx]->SplitX
                mov     dl, 90H                        ; NoteOn-Off
                or      dl, +10[bx]                    ; Channel in Split
                mov     cx, 0080H                      ; 128=Num of Prog Changes
                ;--------------------------------------;
PCSendLoop      mov     ax, 4080H                      ; al=ProgChNo, ah=Note=64
                sub     al, cl                         ; al=PC No
                call    WriteDec                       ; Write al
                call    DoPatchXmit2                   ; al=Patch No
                ;--------------------------------------;
                mov     al, ah                         ; al=Key Vel=64=ON
                call    XmitMidi3                      ; Send 3 bytes:dl,ah,al
                call    Delay00                        ;
                ;--------------------------------------;
                mov     al, ch                         ; ch=0, Key Vel=0=OFF
                call    XmitMidi3                      ; Send 3 bytes:dl,ah,al
                call    Delay00                        ;
                ;--------------------------------------;
                loop    PCSendLoop                     ; 
                ;--------------------------------------;
                pop     dx                             ;
                pop     cx                             ;
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:9:K04 
L0:9:K05 
L0:9:K06 
L0:9:K07 
L0:9:K08 
L0:9:K09 
L0:9:K10
L0:9:K11
L0:9:K12
L0:9:K13
L0:9:K15
ExitLev1:9      jmp     ExitKeyRoutine             ;
;--------------------------------------------------;
Lev1:8                                             ;
;==================================================;
;======================================;
; Level 1: Key 8 = Patches 1           ;
;======================================;
;  [7]           [8]           [9]     ; Increase, decrease, Send current patch.
; Increase      SEND:      Decrease    ; Send current split only.
;Patch 0-127  Curr Split   Patch 0-127 ; 
;--------------------------------------;
;  [4]           [5]           [6]     ; Send curr patch as split A-F
; SEND as      SEND as      Get 3digit ; regardless of which is active or
; Split A      Split B      Patch 0-127; enabled.
;--------------------------------------;
;  [1]           [2]           [3]     ; [1],[2],[4],[5]: Send Curr Split
;SEND as       SEND as      Get 2digit ; only, or if enabled also A-F. 
;Split C       Split D     Patch 0-127 ; 
;--------------------------------------;
;  [0]         [ENTER]       [ESCAPE]  ; 
;SEND as       SEND as       Return to ;                                
;Split E       Split F        Level 0  ;              
;======================================;
;----------------------------------------------;
DispCurrPatch   proc    near                   ; Write Current Patch No
                and     al, 01111111B          ; Only 0-127 allowed
                mov     [CurrPatch], al        ;
                call    WriteDecPS             ;
                ret                            ;
                endp                           ;
;----------------------------------------------;
                ;--------------------------------------;
                ; Send Patch Splits                    ;
                ;--------------------------------------;
L0:8:K04        mov     ax, (256*A)+00H                ; 00 = Split A
                jmp     SendPSplit                     ;
                ;--------------------------------------;
L0:8:K05        mov     ax, (256*BLo)+01H              ; 01 = Split B
                jmp     SendPSplit                     ;
                ;--------------------------------------;
L0:8:K01        mov     ax, (256*C)+02H                ; 02 = Split C
                jmp     SendPSplit                     ;
                ;--------------------------------------;
L0:8:K02        mov     ax, (256*DLo)+03H              ; 03 = Split D
                jmp     SendPSplit                     ;
                ;--------------------------------------;
L0:8:K00        mov     ax, (256*E)+04H                ; 04 = Split E
                jmp     SendPSplit                     ;
                ;--------------------------------------;
L0:8:K15        mov     ax, (256*F)+05H                ; 05 = Split F
                ;--------------------------------------;
SendPSplit                                             ; Send Patch Splits
                movw    [Message], offset(PatchMess2)  ; "P=A,B,C,d,E,F"
                call    WriteStaticPS                  ;
                mov     +4[bp], ah                     ; [Disp3:X],ah="A-F"
                push    [Split]                        ; save
                mov     [Split], al                    ; Set A-F temp Active
                mov     al, [CurrPatch]                ;
                call    DoPatchXmit2                   ;
                pop     [Split]                        ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Keys [2],[3],[4],[5],[6] [7],[8],[9] ;
                ; operate on current patch             ;
                ;--------------------------------------;
L0:8:K03        call    Get2Dec                        ; Get Patch No 0-99
                cmp     al, 063H                       ; > 99 ?
                ja      L0:8:K03                       ; Only 0-99 allowed
                call    DispCurrPatch                  ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:8:K06        call    Get3Dec                        ; Get Patch No 0-127
                cmp     al, 07FH                       ; > 127 ?
                ja      L0:8:K06                       ; Only 0-127 allowed
                call    DispCurrPatch                  ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:8:K08        mov     al, [CurrPatch]                ;
                call    DispCurrPatch                  ;
                call    DoPatchXmit2                   ; Send single patch
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:8:K07        mov     al, [CurrPatch]                ;
                inc     al                             ;
                call    DispCurrPatch                  ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:8:K09        mov     al, [CurrPatch]                ;
                dec     al                             ;
                call    DispCurrPatch                  ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:8:K10
L0:8:K11
L0:8:K12
L0:8:K13
ExitLev1:8      jmp     ExitKeyRoutine                 ;
;------------------------------------------------------;
;===============================================;
; Level 1: Key 3 = Transpose + Octave + Channel ;
;===============================================;
;    [7]              [8]               [9]     ; [7],[8],[9],[4],[5],[6] has
;Xpose Down        Xpose Zero        Xpose Up   ; effect only on current Split.
;-----------------------------------------------; To set on all 4 Splits select
;    [4]              [5]               [6]     ; Key [0] first: GLOBAL.
;Octave Down      Octave Zero       Octave Up   ;
;-----------------------------------------------;
;    [1]              [2]               [3]     ; 
;                                               ;
;                                               ;    
;-----------------------------------------------;
;    [0]            [ENTER]          [ESCAPE]   ; 
; Set Scope:                        Return to   ; 
; Global-Single Split               Level 0     ;              
;===============================================;
;------------------------------------------------------------------;
; Put single Key Offset value in KeyOffset                         ;
;------------------------------------------------------------------;
; Single key transpose in Xpose             : +0 to +12            ;
; Octave offset in Octave                   : +0 to +2, -0 to -2   ;
; Scan correction (Scan to Key) in ScanToKey: 0 to 127             ;
; KeyOffset = TOTAL of Xpose+Octave+ScanToKey                      ;
; This when added to Scan Number (0-127) will give final Key Number;
; Use VAL for + values, 256-VAL for - values, when added to byte   ;
; will then automatically adjust to addition or subtraction        ;
; For example:                                                     ;
;   Octave = +2: [Octave]=2                                        ;
;   Octave = -2: [Octave]=256-2=254                                ;
;   Key Scan = 50 => Add +2 => KeyNumber = 52                      ;
;                    Sub -2 => KeyNumber = 50+254=304=(304-256)=48 ;
;------------------------------------------------------------------;
Lev1:3                                                             ;
;------------------------------------------------------------------;
Lev13Xpose      proc    near                           ;
;------------------------------------------------------;
                mov     al, +8[bx]                     ; XPose:X
                mov     ah, Space                      ;
                cmp     al, 07FH                       ; + or - Xpose ?
                jb      L13UpXpose                     ; Up Xpose
                neg     al                             ; Convert to - Number
                mov     ah, Minus                      ;
L13UpXpose      call    WriteDec                       ;
                mov     +12[bp], ah                    ; [Disp1:0,1]
                call    CalcKOS                        ; Calc Key Offset
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
Lev13Octave     proc    near                           ;
;------------------------------------------------------;
                mov     al, +7[bx]                     ; Oct:X
                mov     ah, Space                      ;
                cmp     al, 07FH                       ; + or - Octave ?
                jb      L13UpOctave                    ; Up Octave
                neg     al                             ; Convert to - Number
                mov     ah, Minus                      ;
L13UpOctave     call    WriteDec                       ;
                movb    +12[bp], Space                 ; [Disp1:0,1]
                mov     +0[bp], ah                     ; [Disp2:0,1]
                call    CalcKOS                        ; Calc KeyOffSet
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
OctaveZero      proc    near                           ;
;------------------------------------------------------;
                push    bx                             ;
                call    SetUpSplit                     ;
                movw    +6[bx], 0000H                  ; Octave:X + Oct:X
                jmp     OctaveL1                       ;
;------------------------------------------------------;
OctaveUp        push    bx                             ;
                call    SetUpSplit                     ;
                addb    +6[bx], 12                     ; Octave:X
                incb    +7[bx]                         ; Oct:X
                jmp     OctaveL1                       ;
;------------------------------------------------------;
OctaveDown      push    bx                             ;
                call    SetUpSplit                     ;
                subb    +6[bx], 12                     ; Octave:X
                decb    +7[bx]                         ; Oct:X
OctaveL1        call    Lev13Octave                    ;
                pop     bx                             ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
DoXposeOct      proc    near                           ;
;------------------------------------------------------;
                push    bx                             ;
                cmpb    [GlobalOctXp], 01H             ; Global-single split ?
                je      DoXpOctGlobal                  ;
                ;--------------------------------------;
                calln   di                             ;
                pop     bx                             ;
                ret                                    ;
                ;--------------------------------------;
DoXpOctGlobal   push    [Split]                        ;
                movb    [Split], 05H                   ; 6 Splits: F->A
XpOctLoop       calln   di                             ;
                decb    [Split]                        ;
                jns     XpOctLoop                      ; Next Split
                pop     [Split]                        ;
                pop     bx                             ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
XposeDwn        proc    near                           ;
;------------------------------------------------------;
                call    SetUpSplit                     ;
                decb    +8[bx]                         ; Xpose:X
                call    Lev13XPose                     ;
                ret                                    ;
;------------------------------------------------------;
XposeUp         call    SetUpSplit                     ;
                incb    +8[bx]                         ; Xpose:X
                call    Lev13XPose                     ;
                ret                                    ;
;------------------------------------------------------;
XposeZero       call    SetUpSplit                     ;
                movb    +8[bx], 00H                    ; Xpose:X
                call    Lev13XPose                     ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
                ;--------------------------------------;
                ; Xpose Up, Down or set to Zero        ;
                ;--------------------------------------;
L0:3:K07        push    di                             ; XPOSE DOWN
                mov     di, offset(XposeDwn)           ;
                call    DoXposeOct                     ;
                pop     di                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:3:K08        push    di                             ; XPOSE ZERO
                mov     di, offset(XposeZero)          ;
                call    DoXposeOct                     ;
                pop     di                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:3:K09        push    di                             ; XPOSE UP
                mov     di, offset(XposeUp)            ;
                call    DoXposeOct                     ;
                pop     di                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Adjust Octave                        ;
                ;--------------------------------------;
L0:3:K04        push    di                             ; OCTAVE DOWN
                mov     di, offset(OctaveDown)         ;
                call    DoXposeOct                     ;
                pop     di                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:3:K05        push    di                             ; OCTAVE ZERO
                mov     di, offset(OctaveZero)         ;
                call    DoXposeOct                     ;
                pop     di                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:3:K06        push    di                             ; OCTAVE UP
                mov     di, offset(OctaveUp)           ;
                call    DoXposeOct                     ;
                pop     di                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Select Global or Single Split Effect ;
                ;--------------------------------------;
L0:3:K00        xorb    [GlobalOctXp], 01H             ;
                jnz     L03K00Global                   ;
                movw    [Message], offset(XpSM)        ; Disp1="SgL"=Single
                jmp     ExitL03K00                     ;
L03K00Global    movw    [Message], offset(XpGM)        ; Disp1="ALL"=Global
ExitL03K00      call    WriteStaticPS                  ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ;                                      ;
                ;--------------------------------------;
L0:3:K02        
L0:3:K01
L0:3:K03
L0:3:K10
L0:3:K11
L0:3:K12
L0:3:K13
L0:3:K15
ExitLev1:3      jmp     ExitKeyRoutine                 ;
;------------------------------------------------------;
;----------------------------------------------;
; Write Decimal Number 000 - 999               ;
; Number in AL                                 ;
;----------------------------------------------;
WriteDecTS     proc    near                    ;
               push    ax                      ;
               push    bx                      ;
               push    dx                      ;
               call    SaveDisp                ; Save Curr Disp
               mov     ah, 02H                 ; ah=2: Temp Steady
               jmp     WDL1                    ;
               ;-------------------------------;
WriteDecPB     push    ax                      ;
               push    bx                      ;
               push    dx                      ;
               mov     ah, 01H                 ; ah=1: Perm Blink
               jmp     WDL1                    ;
               ;-------------------------------;
WriteDec       
WriteDecPS     push    ax                      ;
               push    bx                      ;
               push    dx                      ;
               xor     ah, ah                  ; ah=0: Perm Steady
               ;-------------------------------;
WDL1           cmp     al, 100                 ; Split into 3 groups:
               jb      L0to99                  ; (1) 0-99
               cmp     al, 200                 ; (2) 100-199
               jb      L100to199               ; (3) 200-255
               ;-------------------------------;
L200to255      mov     dx, (200*256)+Two       ; "2xx"
               jmp     Do10s1s                 ;
L100to199      mov     dx, (100*256)+One       ; "1xx"
               jmp     Do10s1s                 ;
L0to99         mov     dx, (0*256)+Zero        ; "0xx"
Do10s1s        ;-------------------------------;
               sub     al, dh                  ; al=al-200,100,0
               mov     dh, ah                  ; ah=attrib
               mov     +12[bp], dx             ; Display dl="0,1,2" + dh=Attrib
               ;-------------------------------;
               aam                             ; al/10, set ah=10s, al=1s
               mov     dl, ah                  ; ah=dl=10s number saved
               mov     bx, offset(OnesTab)     ;
               xlat                            ; xlat for al=1s
               mov     ah, dh                  ; attribute
               mov     +4[bp], ax              ;
               mov     al, dl                  ; 10s number
               xlat                            ; xlat for al=10s
               mov     +0[bp], ax              ;
               ;-------------------------------;
               pop     dx                      ;
               pop     bx                      ;
               pop     ax                      ;
               ret                             ;
               endp                            ;
;-----------------------------------------------;
; Write Hex Number 00 - FF                      ;
; Number in AL                                  ;
;-----------------------------------------------;
WriteHexTS     proc    near                     ;
               push    ax                       ;
               push    bx                       ;
               call    SaveDisp                 ; Save Current Disp
               mov     ah, 02H                  ; ah=2 Temp Steady
               jmp     WHL1                     ;
               ;--------------------------------;
WriteHex       
WriteHexPS     push    ax                       ;
               push    bx                       ;
               xor     ah, ah                   ; ah=0 Perm Steady
               ;--------------------------------;    
WHL1           push    ax                       ; save number
               mov     bx, offset(Seg7Tab)      ; 0-F Xlation table
               and     al, 0FH                  ; mask out top nibble
               xlat                             ;
               mov     +0[bp], ax               ; LSD + ah=Attrib
               pop     ax                       ; Number back
               shr     al                       ; shift right one nibble
               shr     al                       ;
               shr     al                       ;
               shr     al                       ;
               xlat                             ;
               mov     +12[bp], ax              ; MSD + ah=Attrib
               mov     al, HLo                  ; "h"
               mov     +4[bp], ax               ; "h" + ah=Attrib
               ;--------------------------------;
               pop     bx                       ;
               pop     ax                       ;
               ret                              ;
               endp                             ;
;-----------------------------------------------;
; Write static message                          ;
; Enter with message start in [Message]         ;
;-----------------------------------------------;
WriteStaticTB   proc    near                    ; Temp Message: Blink
                push    ax                      ;
                push    si                      ;
                call    SaveDisp                ; Save Current Disp
                mov     ah, 03H                 ; Attrib=3=Temp Blink
                jmp     WSL1                    ;
;-----------------------------------------------;
WriteStaticTS   push    ax                      ; Temp Message: Steady
                push    si                      ;
                call    SaveDisp                ; Save Current Disp
                mov     ah, 02H                 ; Attrib=2=Temp Steady
                jmp     WSL1                    ;
;-----------------------------------------------;
WriteStaticPB   push    ax                      ; Perm Message: Blink
                push    si                      ;
                mov     ah, 01H                 ; Attrib=1=Perm Blink
                jmp     WSL1                    ;
;-----------------------------------------------;
WriteStatic     
WriteStaticPS   push    ax                      ;
                push    si                      ;
                xor     ah, ah                  ; Attrib=0=Perm Steady
                ;-------------------------------;
WSL1            cld                             ; decrement mode
                mov     si, [Message]           ; Address of message start
                lodsb                           ; mov al, [si] + inc si
                mov     +12[bp], ax             ; Display 1 
                lodsb                           ; mov al, [si] + inc si
                mov     +0[bp], ax              ; Display 2          
                lodsb                           ; mov al, [si] + inc si
                mov     +4[bp], ax              ; Display 3
                ;-------------------------------;
                pop     si                      ;
                pop     ax                      ;
                ret                             ;
                endp                            ;
;-----------------------------------------------;
; Clear all 3-5 Displays                        ;
;-----------------------------------------------;
ClearDispX      proc    near                    ;
ClearDisp1to5   push    ax                      ;
                xor     ax, ax                  ;
                mov     +16[bp], ax             ;
                mov     +18[bp], ax             ;
                mov     +20[bp], ax             ;
                mov     +22[bp], ax             ;
                mov     +24[bp], ax             ; 
                mov     +26[bp], ax             ; 
                mov     +28[bp], ax             ;
                mov     +30[bp], ax             ;
                pop     ax                      ;
ClearDisp1to4   movw    +8[bp],  0000H          ; 
ClearDisp1to3   movw    +12[bp], 0000H          ;
                movw    +0[bp],  0000H          ;
                movw    +4[bp],  0000H          ;
                ret                             ;
                endp                            ;
;-----------------------------------------------;
; Set Dots in Displays 1, 2, 3                  ;
;-----------------------------------------------;
DotsDispX       proc    near                    ;
DotsDisp1to3    push    ax                      ;
                mov     ax, (Dot*256)+Dot       ;
                jmp     DoDots                  ;
                ;-------------------------------;
DotsDisp2to3    push    ax                      ;
                mov     ax, (Space*256)+Dot     ;
                jmp     DoDots                  ;
                ;-------------------------------;
DotsDisp3       push    ax                      ;
                mov     ax, (Space*256)+Space   ; ax=0000
                ;-------------------------------;
DoDots          mov     +12[bp], ah             ;
                mov     +0[bp], al              ;
                movb    +4[bp], Dot             ;
                pop     ax                      ;
                ret                             ;
                endp                            ;
;-----------------------------------------------;
; Xlate Binary value to Bardisplay Binary Value ;
; Display on Bardisplay                         ;
; Enter with binary value in AL                 ;
;-----------------------------------------------;
XlateBinaryTab  proc    near                    ;
                push    ax                      ;
                push    bx                      ;
                ;-------------------------------;
                cbw                             ; al>127->ah=ff else ah=0
                and     ax, 107FH               ; al=0-127, ah D4=0,1
                mov     bx, offset(BinTab)      ; Address of Xlat Table
                xlat                            ; AL Ptr into table, AL=result
                or      al, ah                  ; Set-reset D4
                mov     +8[bp], al              ;
                ;-------------------------------;
                pop     bx                      ;
                pop     ax                      ;
                ret                             ;
                endp
;=========================================================;
; Error Routines                                          ;
;=========================================================;
RamErrorINT     proc    near                              ;
;---------------------------------------------------------;
                iret
;---------------------------------------------------------;
Errorproc       
RamOV           movb    [Disp1], O                        ;
                movb    [Disp2], V                        ;
                movb    [Disp3], F                        ;
                jmp     RamNext                           ;
;---------------------------------------------------------;
RamDIV0         movb    [Disp1], DLo                      ;
                movb    [Disp2], I                        ;
                movb    [Disp3], V                        ;
RamNext         movw    [NMIVectorLo], offset(RamErrorINT); int offset
                call    Delay0                            ;
                call    Delay0                            ;
                jmp     RomINTInit                        ; Start from Scratch
                endp                                      ;
;---------------------------------------------------------;
;-----------------------------------------------;
; Set Level to 0: Button Pad                    ;
;-----------------------------------------------;
SetLevel0       proc   near                     ;
                movb   [Level01], 00H           ; Level = 0 Top Level
                mov     bp, CurrDispL0          ; Pos 0 in display area
                ret                             ;
                endp                            ;
;-----------------------------------------------;
; Set Level to 1: Button Pad                    ;
;-----------------------------------------------;
SetLevel1       proc   near                     ;
                movb   [Level01], 01H           ; Level = 1 Top Level
                mov     bp, CurrDispL1          ; Pos 0 in display area
                ret                             ;
                endp                            ;
;-----------------------------------------------;
; Get 1 digit decimal number from keypad 0-9    ;
; Leave with number in AH                       ;
; Display number in AL                          ;
;-----------------------------------------------;
Get1Num       proc    near             
              push    bx                        ;
              movb    [MenuTimer], 255          ; Disable Menu Timer
              movb    [Response], 01H           ; Response wanted LED
              ;---------------------------------;
GetNumber     movb    [ButtonPressed], 0FFH     ; Clear Number
              call    ReadButton1               ;
              cmpb    [ButtonPressed], 0AH      ; Biggest Number = 9
              jb      NumberOK                  ;
              cmpb    [ButtonPressed], 0EH      ; Escape-Clear pressed = 14
              jne     GetNumber                 ;
              ;---------------------------------;
              ; Escape pressed: return immediate;
              ;---------------------------------;
              movb    [Escape], 01H             ; Escape pressed
              xor     ax, ax                    ; ax=0, clear number and display
              call    ClearDisp1to3             ; clear all three displays
              jmp     ExitGetNum                ;
NumberOK
              mov     bx, offset(Seg7Tab)       ;
              mov     al, [ButtonPressed]       ;
              mov     ah, al                    ; Entered Number 0-9 in ah
              xlat                              ; Display Number in al
ExitGetNum    movb    [Response], 00H           ; Response LED cancelled
              pop     bx
              ret
              endp
;-----------------------------------------------;
; Xlate GetxDec Numbers to single number        ;
;-----------------------------------------------;
XlatGetDec    proc    near
              push    bx                        ;
              push    cx                        ;
              ;---------------------------------; Get 100s Number
              mov     bx, [Number100s]          ;
              shl     bx                        ;
              mov     cx, offset(Xlat100s)[bx]  ; 100s Number in cx
              ;---------------------------------; Get 10s Number
              mov     bx, offset(Xlat10s)       ;
              mov     ax, [Number10s]           ; ah=Hi[Number10s]=0
              xlat                              ;
              add     ax, cx                    ; 100s+10s Number in ax
              ;---------------------------------; Get 1s Number
              add     ax, [Number1s]            ; Hi[Number1s]=0
              mov     [Number], ax              ; Store final number
              ;---------------------------------;
              pop     cx                        ;
              pop     bx                        ;
              ret                               ;
              endp                              ;
;-------------------------------------------------;
; Get 1-3 digit decimal number from keypad 000-999;
; Leave with number in AX (ah=0 if number = 0-255);
;-------------------------------------------------;
GetXDec       proc    near             
;-----------------------------------------------;
Get1Dec       call    DotsDisp3                 ;
              movw    [Number100s], 0000H       ;
              movw    [Number10s], 000H         ;
              jmp     Get1s                     ;
              ;---------------------------------;
Get2Dec       call    DotsDisp2to3              ;
              movw    [Number100s], 0000H       ;
              jmp     Get10s                    ;
              ;---------------------------------;
Get3Dec       call    DotsDisp1to3              ;
              ;---------------------------------;
Get100s       call    Get1Num                   ;
              mov     +12[bp], al               ;
              mov     [Number100s], ah          ;
              ;---------------------------------;
Get10s        call    Get1Num                   ;
              mov     +0[bp], al                ;
              mov     [Number10s], ah           ;
              ;---------------------------------;
Get1s         call    Get1Num                   ;
              mov     +4[bp], al                ;
              mov     [Number1s], ah            ;
              ;---------------------------------; Calculate Number
              call    XlatGetDec                ;
              ;---------------------------------;
ExitXDec      ret
              endp
;-----------------------------------------------;
; Get ENTER from keypad                         ;
;-----------------------------------------------;
GetEnter      proc    near                      ;
              call    DotsDisp3                 ;
              movb    [MenuTimer], 255          ; Disable Menu Timer
              movb    [Response], 01H           ; Response wanted LED
              ;---------------------------------;
GetE          movb    [ButtonPressed], 0FFH     ; Clear Number
              call    ReadButton1               ;
              cmpb    [ButtonPressed], 0FH      ; Enter = 15
              je      IsEnter                   ;
              jmp     GetE                      ;
IsEnter       ;---------------------------------;
              movb    [Response], 00H           ; Response LED cancelled
              ret                               ;
              endp                              ;
;------------------------------------------------------;
GetYesNo        proc    near                           ; Return AL=1=Yes
;------------------------------------------------------;        AL=0=No
                movw    [Message], offset(YesNoMess)   ;
                call    WriteScroll                    ;
                call    Get1Dec                        ;
                movb    +4[bp], Space                  ;
                cmp     al, 01H                        ; Yes ?
                je      GYNIsYes                       ;
                cmp     al, 03H                        ; No ?
                jne     GetYesNo                       ; No
                xor     al, al                         ; al=0=no
                movb    +4[bp], N                      ;
GYNIsYes        ret                                    ;
                endp                                   ;
;------------------------------------------------------;
; Write scrolling message                       ;
; Enter with message start in [Message]         ;
;-----------------------------------------------;
WriteScroll1    proc    near                    ;
;-----------------------------------------------;
                mov     [Message], bx           ; Message Addr
;-----------------------------------------------;
WriteScroll     push    ax                      ;
                push    bx                      ;
                push    cx                      ;
                push    si                      ;
                cld                             ; decrement mode
                mov     si, [Message]           ; Address of message start
                mov     cx, -2[si]              ; Length of message, ch=0
                mov     bx, [ScrollTime]        ; Time between scrolls bh=00
                ;-------------------------------;
MessLoop        lodsb                           ; mov al, [si] + inc si
                mov     +12[bp], al             ; Display 1 
                mov     ax, [si]                ; al=lo, ah=hi
                mov     +0[bp], al              ; Display 2          
                mov     +4[bp], ah              ; Display 3
                cmp     ah, RBracket            ; Pause extra if Right bracket
                jne     NoRBracket              ; such as: "[0] or [1]" as a
                call    Delay0                  ; prompt for Keypress.
NoRBracket      
                mov     [MessTimer], bl         ; Set timer
MessTimerLoop   cmp     [MessTimer], bh         ; bh=00H
                jnz     MessTimerLoop           ;
                loop    MessLoop                ; dec cx, loop if not 0
                ;-------------------------------;
MessExit        call    ClearDisp1to3           ; Clear all 3 displays
                pop     si                      ;
                pop     cx                      ;
                pop     bx                      ;
                pop     ax                      ;
                ret                             ;
                endp                            ;
;-----------------------------------------------;
RomGoRAM        proc    near                    ;
;-----------------------------------------------;
                movb    [GoRAMBios], 00H        ; Disable
                movb    [RxEnable], 00H         ; Disable Receiver
                movb    [ScrollTime], 10H       ; RAM Scrolling Delay
                ret                             ;
                endp                            ;
;-----------------------------------------------;
DoOneValReset   proc    near                    ;
;-----------------------------------------------;
                push    cx                      ; 
                xor     cx, cx                  ; cx=0
                mov     di, [bx]                ; destination
                mov     cl, +2[bx]              ; number of words
                mov     al, +3[bx]              ; words value
                mov     ah, al                  ; ah=al
                rep                             ;
                stosw                           ; store words=0000
                add     bx, 0004H               ; next di,cx,ax values
                pop     cx                      ;
                ret                             ;
                endp                            ;
;-----------------------------------------------;
DoMixValReset   proc    near                    ;               
;-----------------------------------------------;
                push    cx                      ;
                xor     cx, cx                  ; cx=0
                mov     di, [bx]                ; destination
                mov     cl, +3[bx]              ; number of blocks
                ;-------------------------------;
DoMixValLoop    mov     si, +4[bx]              ; source
                push    cx                      ; save number of blocks
                mov     cl, +2[bx]              ; number of words=x
                rep                             ;
                movsw                           ; move words=x [si]->[di]
                pop     cx                      ; number of blocks
                loop    DoMixValLoop            ;
                ;-------------------------------;
                add     bx, 0006H               ; next di,cx,si values
                pop     cx                      ;
                ret                             ;
                endp                            ;
;-----------------------------------------------;
; Delay                                         ;
;-----------------------------------------------;
Delay00         proc    near                    ;
                movw    [DelayTimer], 07FFFH    ; Set timer
                jmp     Delay0Loop              ;
Delay0          proc    near                    ;
                movw    [DelayTimer], 0FFFFH    ; Set timer
Delay0Loop                                        
                decw    [DelayTimer]            ;
                jnz     Delay0Loop              ;
                ret                             ;
                endp                            ;
                endp                            ;
;-----------------------------------------------;
; Delay                                         ;
;-----------------------------------------------;
Delay1          proc    near
                call    Delay0                  ;
                call    Delay0                  ;
                ret                             ;
                endp                            ;
;---------------------------------------------------;
; Read Buttons (Program Keys)                       ;
;---------------------------------------------------;
ReadButton      proc    near                        ;
                cmpb    [ButtonEnable], 01H         ; Enabled ?
                jne     BNoButton                   ; No
                ;-----------------------------------;
ReadButton1     push    bx                          ;
                push    cx                          ;
                push    dx                          ;
                push    di                          ;
                push    si                          ;
                ;-------------------------------------------------------;
                ;           0000000L L:Lower Contact: End               ;
                ; Key unpressed    : L=1: State=1: Value=00B = 1        ;
                ; Key pressed      : L=0: State=0: Value=01B = 0        ;
                ; VALUE CHANGE     : [ 1 --> 0 --> 1 ]                  ;
                ; STATE CHANGE     : [ 1 --> 0 --> 2 --> 1 ]            ;
                ;-------------------------------------------------------;
                mov     si, Buttons            ; HW Port 2000-2001H
                mov     cx, ButtonsNumber      ; number of Keys to scan, ch=0
                mov     di, ButtonsState       ; 
                mov     bx, offset(ButtonTab)  ; Address of Xlat Table
                mov     dx, 0102H              ; dh=01, dl=02
                ;------------------------------;
BLoop           
                lodsb                          ; mov al, [si] + inc si
                and     al, dh                 ; dh=01, mask out D7 to D1
                jz      BPressed               ; AL=0
                ;------------------------------;
BNotPressed     stosb                          ; mov [di], al=01, inc di
                                               ; Clear previous key state
                loop    BLoop                  ;
                jmp     BExit                  ;
                ;------------------------------;
BPressed        cmp     [di], dh               ; dh=01, Previously state 1 ?
                ja      BReleaseKey            ; 2 previous first release
                je      BPressed01             ; 1: Debounce period
                                               ; Store al=00H in Buttonstate
                mov     ax, di                 ; Raw Button Number 0-15 in al
                xlat                           ; ButtonTab in bx      
                mov     [ButtonPressed], al    ; Xlated ButtonPressed No 0-15
BReleaseKey     mov     al, dl                 ; dl=02, prev pressed key state
BPressed01      stosb                          ; Store al=00 or 01 in [di]
                loop    BLoop                  ;
BExit           ;------------------------------;
                pop     si                     ;
                pop     di                     ;
                pop     dx                     ;
                pop     cx                     ;
                pop     bx                     ;
BNoButton       ret                            ;
                endp                           ;
;------------------------------------------------------;
; Read Wheels Buttons                                  ;
;------------------------------------------------------;
ReadWButtons    proc    near                           ;
                push    ax                             ;
                push    bx                             ;
                push    cx                             ;
                push    di                             ;
                ;--------------------------------------;
                cmpb    [WButtonEnable], 01H           ; Enabled ?
                jne     WExit                          ; No
                ;--------------------------------------;
                ;-------------------------------------------------------;
                ;           0CCC0000 C:Contact: End                     ;
                ; Key unpressed     : C=1: State=1: Value=01110000      ;
                ; Key pressed       : C=0: State=0: Value=00000000      ;
                ; VALUE+STATE CHANGE: [ 1 --> 0 --> 1 ]                 ;
                ;-------------------------------------------------------;
                mov     di, WButtonState       ; no need for lo di !
                mov     bx, 1001H              ; bh=D4=Key01, bl=key01
                mov     cx, 03H                ; Three Keys
                ;==============================;
WLoop           mov     al, [Wheels]           ; Get Changed State
                and     al, bh                 ; Buttons in D6,D5,D4
                jz      WPressed               ; AL=0
                ;------------------------------;
WNotPressed     mov     al, 01H                ; mov [di], al=01, inc di
                stosb                          ; Clear previous key state
                shl     bx                     ; Next Digit, Next Key=01,02,04
                loop    WLoop                  ;
                jmp     WExit                  ; Done
                ;------------------------------; 
WPressed        cmpb    [di], 01H              ; Previously state 1 ?
                ja      WReleaseKey            ; 2 previous first release
                je      WPressed01             ; 1: Debounce period
                                               ; Store al=00H in WButtonstate
                mov     [WButtonPressed], bl   ; ButtonPressed No 1,2,4
WReleaseKey     mov     al, 02H                ; previous pressed key state
WPressed01      stosb                          ; Store al=00 or 01 in [di]
                loop    WLoop                  ;
                ;------------------------------;
WExit           pop     di                     ;
                pop     cx                     ;
                pop     bx                     ;
                pop     ax                     ;
                endp                           ;
;----------------------------------------------;
; Read KbrdButtons (Program Keys)               ;
;-----------------------------------------------;
KReadButton     proc    near
                cmpb    [KButtonEnable], 01H        ; Enabled ?
                jne     KNoButton                   ; No
KReadButton1    proc    near                        ;
                push    ax                          ;
                push    cx                          ;
                push    di                          ;
                push    si                          ;
                ;-------------------------------------------------------;
                ;           L0000000 L:Lower Contact: End               ;
                ; Key unpressed    : L=1: State=1: Value=10000000 = 128 ;
                ; Key pressed      : L=0: State=0: Value=00000000 = 0   ;
                ; VALUE CHANGE     : [ 128 --> 0 --> 128 ]              ;
                ; STATE CHANGE     : [   1 --> 0 --> 2 --> 1 ]          ;
                ;-------------------------------------------------------;
                mov     si, KeyBrd+031H             ; start at +49
                mov     cx, [KBrdScanNum]           ; number of Keys to scan
                mov     di, KButtonsState           ; no need for lo di !
                ;-----------------------------------; use lo si as key number
KLoop           
                lodsb                          ; mov al, [si] + inc si
                and     al, 00000001B          ; mask out D7 to D1
                jz      KPressed               ; AL=0
                ;------------------------------;
KNotPressed     
                stosb                          ; mov [di], al=01, inc di
                                               ; Clear previous key state
                loop    KLoop                  ;
                jmp     KExit                  ; Exit
                ;------------------------------;
KPressed        cmpb    [di], 01H              ; Previously state 1 ?
                ja      KReleaseKey            ; 2 previous first release
                je      KPressed01             ; 1: Debounce period
                                               ; Store al=00H in KButtonstate
                mov     ax, si                 ;
                sub     ax, 032H               ; Sub 31H+1H (si already inc)    
                mov     [KButtonPressed], al   ; ButtonPressed No 0-6
KReleaseKey     mov     al, 02H                ; previous pressed key state
KPressed01      stosb                          ; Store al=00 or 01 in [di]
                loop    KLoop                  ;
                ;------------------------------;
KExit           pop     si                     ;
                pop     di                     ;
                pop     cx                     ;
                pop     ax                     ;
KNoButton       ret                            ;
                endp                           ;
                endp                           ;
;----------------------------------------------;
;-----------------------------------------------------------------------------;
; Read Keyboard Keys                                                          ;
;-----------------------------------------------------------------------------;
ReadKeys        proc    near                                                  ;
;-----------------------------------------------------------------------------;
; LO byte of SI = KEY (NOTE) NUMBER 0-255                                     ;
;-----------------------------------------------------------------------------;
;           00000KLU K:Program Keys                                           ;
;                    L:Lower Bar: End                        AFTER SHR AL     ;
;                    U:Upper Bar: Top         D7    D0          AL  CARRY     ;
; Key unpressed    : U=0, L=1: State=0: Value=1.....0B = 128    64  clear     ;
; Key inbetween    : U=1, L=1: State=1: Value=1.....1B = 129    64  set       ;
;                              State=3: Value=1.....1B = 129                  ;
; Key pressed      : U=1, L=0: State=2: Value=0.....1B = 001    00  set       ;
; Key shorted      : U=0, L=0: State=4: Value=0.....0B = 000    00  clear     ;
; If Key goes down : State = 1                                                ;
; If Key goes up   : State = 3                                                ;
; VALUE CHANGE     :                                                          ;
;                    [ 128 --> 129 --> 1 --> 129 -->128 ]                     ;
; STATE CHANGE     :                                                          ;
;                    [   0 -->   1 --> 2 -->   3 --> 0 ]                      ;
;-----------------------------------------------------------------------------;
                mov     si, KeyBrd             ; KeyBrd HW Port,    si=A000H
                mov     bx, KeyState           ; Vel=[bx+128], bx=0400H, bh=04
                mov     di, 0080H              ; di(lo)=128, di(hi)=00 
                mov     cx, KeyScanNumber      ; cl=No of Keys, ch=0
                mov     dx, 0102H              ; dh=01, dl=02
                mov     ah, 7FH                ; ah=7F
                ;------------------------------; 
RKLoop           
                lodsb                          ; mov al, [si] + inc si
                shr     al                     ; D0 into carry
                jc      NotTop                 ; AL=01,129: Transition or Bottom
                ;------------------------------;
                ; State 0: Key Unpressed       ; AL=128-->0  1000000-->00
                ;------------------------------; 55 clocks for unpressed Key
State0          
                cmp     [bx], dh               ; dh=01, Prev down trans: [bx]-1?
                jnb     Next0                  ; NOT 0: Further Attention
                inc     bx                     ; Previous also at Top = State 0
                loop    RKLoop                 ;
                ret                            ; Done
Next0                                          ; Could be [di] = 1 or = 3
                jne     Midi0                  ; NOT 1 but 3: Save Midi 
                                               ; 1: Debounce required
                mov     [bx], ch               ; ch=0, Reset to Top State
                mov     [bx+di], ah            ; ah=7F, Reset velocity to max
                inc     bx                     ;
                loop    RKLoop                 ;
                ret                            ;
Midi0                                          ; Previous State = 3
                mov     dx, [MidiNoteOff]      ; 80H/90H = Midi Note Off Ch 1
                call    MidiOnOffStore         ; Previous State=3 => NOTE OFF
                mov     [bx], ch               ; ch=0, Reset to Top State
                mov     [bx+di], ah            ; ah=7F, Reset velocity to max
                inc     bx                     ;
                loop    RKLoop                 ;
                ret                            ;
                ;------------------------------; After shr al: Value  64,0,64
NotTop                                         ; States 1,2,3: Value 129,1,129
                shl     al                     ;
                jns     State2                 ; Value 01->00: Key end reached
                ;------------------------------;
                ; States 1, 3: Transition      ; AL=129, now=128
                ;------------------------------;
State13          
                test    [bx], dh               ; dh=01, Previous State=1 or 3 ?
                jnz     Exit13                 ; In Transition: State 1 or 3
                incb    [bx]                   ; Previous 2 or 0: now 3 or 1
Exit13     
                decb    [bx+di]                ; decrement velocity byte
                jz      VelError               ; too long transition
                inc     bx                     ;
                loop    RKLoop                 ;
                ret                            ;
VelError        movb    [bx+di], MinVel        ; Minimum Velocity possible
                inc     bx                     ;
                loop    RKLoop                 ;
                ret                            ;
                ;------------------------------;
                ; State 2: Bottom              ; AL=1-->128: 
                ;------------------------------;
State2         
                cmp     [bx], dl               ; dl=02, Prev also at bottom ?
                jne     Next2                  ; No, further attention
                inc     bx                     ;
                loop    RKLoop                 ;
                ret                            ;
Next2                                          ; Prev = Transition: 3 or 1
                ja      ResetKey2              ; 3 previous: Debounce required
                                               ; previous 1 (or 0 ?)
                mov     dx, NoteOn             ; 7F90H: NoteOnCh1+VelocityFilter
                call    MidiOnOffStore         ; Previous State=1 => NOTE ON
ResetKey2       mov     [bx], dl               ; dl=02, Reset to Bottom State
                mov     [bx+di], ah            ; ah=7F, Reset vel for going up
                inc     bx                     ;
                loop    RKLoop                 ;
                ret                            ;
                endp                           ;
;----------------------------------------------;
;-----------------------------; SPLIT X: 40 bytes
;SplitPosS:A         ; SplitPoint Start 0-127 Notes       ;+0
;SplitPosE:A         ; SplitPoint End   0-127 Notes       ;+1
;                    ; Unused                             ;+2  Word
;VelTab:A            ; Current Vel Table Address          ;+4  Word
;Octave:A            ; Octave: -36,24,..,0,+12,+24,+36    ;+6
;Oct:A               ; Octave: 0=0, +-12=1 +-24=2 +-36=3  ;+7
;XPose:A             ; Transpose +-0,+-1,+-2 to +-12      ;+8
;KeyOffSet:A         ; Total of Octave, Xpose, Basic Offs ;+9
;Channel:A           ; SplitA Midi Channel 0-15           ;+10
;Enable:A            ; 1=Enable Split A: 0=Disable        ;+11
;VelInv:A            ; 0=Normal Vel Tabel 11=Inverse Value;+12  
;VelOffsV:A          ; Vel Offset Vertical: 0-127         ;+13
;VelConst:A          ; Const Vel Value: 64 default FF=off ;+14
;VelMode:A           ; Velocity Contour 0-7               ;+15 
;Wheel0Addr:A        ; Wheel0 Routine Addr: 0000=Off      ;+16 Word
;Wheel0Num:A         ; Wheel0 Controller Number: 0-127    ;+18
;Wheel1Addr:A        ; Wheel1 Routine Addr: 0000=Off      ;+19 Word
;Wheel1Num:A         ; Wheel1 Controller Number: 0-127    ;+21
;Wheel2Addr:A        ; Wheel2 Routine Addr: 0000=Off      ;+22 Word
;Wheel2Num:A         ; Wheel2 Controller Number: 0-127    ;+24
;Wheel3Addr:A        ; Wheel3 Routine Addr: 0000=Off      ;+25 Word
;Wheel3Num:A         ; Wheel3 Controller Number: 0-127    ;+27
;WFoot0Addr:A        ; Wheel0 Footsw Addr: 0000=Off       ;+28 Word
;WFoot0Num:A         ; Wheel0 Footsw Con Number: 0-127    ;+30
;WFoot1Addr:A        ; Wheel1 Footsw Addr: 0000=Off       ;+31 Word
;WFoot1Num:A         ; Wheel1 Footsw Con Number: 0-127    ;+33
;WFoot2Addr:A        ; Wheel2 Footsw Addr: 0000=Off       ;+34 Word
;WFoot2Num:A         ; Wheel2 Footsw Con Number: 0-127    ;+36
;SplitStr1:X         ; 32byte pre-init string:Value=len   ;+37
;SplitPatch          ;                                    ;+38
;Unused              ;                                    ;+39  
;----------------------------------------------;
; Store On Off NOTES                           ;
;----------------------------------------------;
MidiOnOffStore  proc    near                   ; ah=7F on entry
                ;------------------------------;
                push    cx                     ; ch=00, cl=xx
                push    si                     ; si=A0xx
                ;------------------------------;
                ; Store Last Key               ; 
                ;------------------------------; (could also use si-1, or 49-cl)
                mov     bh, [bx+di]            ; bh=128[bx]=KeyVelocity
                mov     [KeyStore], bx         ; bl=Key#, bh=KeyVel
                mov     al, bl                 ; al=bl=NOTE NUMBER, ah=7F, bh=01
                mov     di, ax                 ; di(hi)=7F, di(lo)=xx
                mov     bx, [MidiIn]           ; MidiBuffer Input Ptr, bh=01
                ;==============================; bx=MidiBuff[MidiIn]
                ; SPLIT A                      ;
                ;==============================;  
MNSplitA        mov     si, [SplitCFG:A]       ; Start of CFG block: A
                mov     cx, [si]               ; SplitPos Start (cl), End (ch)
                shl     cl                     ; cl:D7=1,0 = Split En-Dis-abled
                jnc     MNSplitB               ; Split is Disabled
                ;------------------------------;
                shr     cl                     ; cl now with D7=0
                cmp     al, cl                 ; SplitPosS:X Start: raw Scan Pos
                jb      MNSplitB               ; Below Split X Range
                cmp     al, ch                 ; SplitPosE:X End
                ja      MNSplitB               ; Above Split X Range
                call    MidiNotes              ; Do Split A
                ;==============================;
                ; SPLIT B                      ;
                ;==============================;
MNSplitB        add     si, 40                 ; Start of CFG block: B
                mov     cx, [si]               ; SplitPos Start (cl), End (ch)
                shl     cl                     ; cl:D7=1,0 = Split En-Dis-abled
                jnc     MNSplitC               ; Split is Disabled
                ;------------------------------;
                shr     cl                     ; cl now with D7=0
                cmp     al, cl                 ; SplitPosS:X Start: raw Scan Pos
                jb      MNSplitC               ; Below Split X Range
                cmp     al, ch                 ; SplitPosE:X End
                ja      MNSplitC               ; Above Split X Range
                call    MidiNotes              ; Do Split B
                ;==============================;
                ; SPLIT C                      ;
                ;==============================;
MNSplitC        add     si, 40                 ; Start of CFG block: C
                mov     cx, [si]               ; SplitPos Start (cl), End (ch)
                shl     cl                     ; cl:D7=1,0 = Split En-Dis-abled
                jnc     MNSplitD               ; Split is Disabled
                ;------------------------------;
                shr     cl                     ; cl now with D7=0
                cmp     al, cl                 ; SplitPosS:X Start: raw Scan Pos
                jb      MNSplitD               ; Below Split X Range
                cmp     al, ch                 ; SplitPosE:X End
                ja      MNSplitD               ; Above Split X Range
                call    MidiNotes              ; Do Split C
                ;==============================;
                ; SPLIT D                      ;
                ;==============================;
MNSplitD        add     si, 40                 ; Start of CFG block: D
                mov     cx, [si]               ; SplitPos Start (cl), End (ch)
                shl     cl                     ; cl:D7=1,0 = Split En-Dis-abled
                jnc     MNSplitE               ; Split is Disabled
                ;------------------------------;
                shr     cl                     ; cl now with D7=0
                cmp     al, cl                 ; SplitPosS:X Start: raw Scan Pos
                jb      MNSplitE               ; Below Split X Range
                cmp     al, ch                 ; SplitPosE:X End
                ja      MNSplitE               ; Above Split X Range
                call    MidiNotes              ; Do Split C
                ;==============================;
                ; SPLIT E                      ;
                ;==============================;
MNSplitE        add     si, 40                 ; Start of CFG block: E
                mov     cx, [si]               ; SplitPos Start (cl), End (ch)
                shl     cl                     ; cl:D7=1,0 = Split En-Dis-abled
                jnc     MNSplitF               ; Split is Disabled
                ;------------------------------;
                shr     cl                     ; cl now with D7=0
                cmp     al, cl                 ; SplitPosS:X Start: raw Scan Pos
                jb      MNSplitF               ; Below Split X Range
                cmp     al, ch                 ; SplitPosE:X End
                ja      MNSplitF               ; Above Split X Range
                call    MidiNotes              ; Do Split C
                ;==============================;
                ; SPLIT F                      ;
                ;==============================;
MNSplitF        add     si, 40                 ; Start of CFG block: F
                mov     cx, [si]               ; SplitPos Start (cl), End (ch)
                shl     cl                     ; cl:D7=1,0 = Split En-Dis-abled
                jnc     MNExit                 ; Split is Disabled
                ;------------------------------;
                shr     cl                     ; cl now with D7=0
                cmp     al, cl                 ; SplitPosS:X Start: raw Scan Pos
                jb      MNExit                 ; Below Split X Range
                cmp     al, ch                 ; SplitPosE:X End
                ja      MNExit                 ; Above Split X Range
                call    MidiNotes              ; Do Split C
                ;==============================;
MNExit          mov     [MidiIn], bl           ; End with MidiIn-->Current
                mov     bl, al                 ; al=Key#, ah=7F
                mov     bh, 04H                ; bx=04xx=KeyState
                mov     di, 0080H              ; di(lo)=128, di(hi)=00 
                mov     dx, 0102H              ; dh=01 dl=02
                ;------------------------------; 
                pop     si                     ;
                pop     cx                     ;
                ret                            ;
                endp                           ;
;----------------------------------------------;
; Store On Off NOTES for Split X               ;
;----------------------------------------------;
MidiNotes       proc    near                   ; changes AX, BX, CX, DX
                push    dx                     ; on entry ah=7F,   bh=00
                ;==============================;          al=note, bl=MidiIn+x
                ; STORE BYTES 0, 1             ;
                ;==============================;
                mov     cx, +9[si]             ; cl=KeyOffs, ch=Channel
                or      dl, ch                 ; Channel:X DL lo nybble=Ch X
                add     al, cl                 ; KeyOffSet:X Convert Scan to Key
                and     al, ah                 ; ah=7F, if >127 then incorrect
                mov     [bx], dl               ; NOTE-ON-OFF
                inc     bl                     ; wrap around if FF-->00
                mov     [bx], al               ; NOTE NUMBER
                inc     bl                     ; 
                ;------------------------------;
                ;VelTab:A     Current Vel Table Address          ;+4  Word
                ;VelInv:A     0=Normal Vel Tabel 11=Inverse Value;+12  
                ;VelOffsV:A   Vel Offset Vertical: 0-127         ;+13
                ;VelConst:A   Const Vel Value: 64 default FF=off ;+14
                ;VelMode:A    Vel Contour 0,1-9,10               ;+15
                ;==============================;
                ; Xlate Velocities Vel0-Vel7   ; Inverse: add 11 to values i.e
                ; Mode 0:Raw (not xlated)      ; inverse xlated custom = 20
                ;      1-9: Xlated, 9=custom   ;
                ;      10: Constant            ;
                ;------------------------------; 
                mov     al, [Keystore+1]       ; Velocity Count
                and     al, dh                 ; Noteoff: dh=00:90 or 7F:80
                jz      MNStore2               ;  Noteon: dh=7F:90
                ;------------------------------;
                mov     cx, +12[si]            ; cl=VelInv:0,11, ch=OffsVert
                mov     dx, +14[si]            ; dl=VelConst:A,  dh=VelMode:A
                ;------------------------------;
                ; Do Constant Velocity         ; ah=7F
                ;------------------------------;
                or      dh, dh                 ; VelMode:X Mode 0:Raw Velocities
                jz      MNCheckInv             ;
                or      dl, dl                 ; dl=FF=not constant velocity
                js      MNXlatVel              ; dl=FF, i.e. not const vel
                mov     al, dl                 ; al= constant vel value
                jmp     MNCheckInv             ; Check for Inverse
                ;------------------------------; dx now available
                ; Do Xlated Velocity           ;
                ;------------------------------;
MNXLatVel       mov     dx, bx                 ; Save bx
                mov     bx, +4[si]             ; VelTab:X Addr of curr Vel Table
                xlat                           ; AL Ptr into table, AL=result
                mov     bx, dx                 ; bx back
MNCheckInv      or      cl, cl                 ; Normal = 0, not inverse ?
                jz      MNDoVertOfs            ; Yes, done
                not     al                     ; inverse and sub 128 leaves inv
                and     al, ah                 ; ah=7F
                ;------------------------------;
                ; Add Vertical Vel Offset      ; Used in volume wheel: Can
                ;------------------------------; only add + offsets
MNDoVertOfs     add     al, ch                 ; Add + or - vertical offset
                js      MNMinMax               ; New Vel > 127
MNStore2        
                mov     [bx], al               ; VELOCITY VALUE
                inc     bl                     ; 
                mov     ax, di                 ; al=Key#, ah=7F
                pop     dx                     ;
                ret                            ;
                ;------------------------------;
MNMinMax        or      ch, ch                 ; Check if + or -
                jns     MNPos                  ; + Offs
                mov     ah, MinVel             ; ah=minimum velocity
MNPos           mov     [bx], ah               ; ah=(MIN,MAX) VELOCITY VALUE
                inc     bl                     ; 
                mov     ax, di                 ; al=Key#, ah=7F
                pop     dx                     ;
                ret                            ;
                endp                           ;
;----------------------------------------------;

