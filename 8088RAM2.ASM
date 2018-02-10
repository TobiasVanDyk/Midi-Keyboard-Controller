;--------------------------------------------------------;
; 8088 CPU keyboard                                      ;
; 8088RAM.2                                              ;
;----------------------------------------------------------------------;
; Create file 8088.ASM by:                                             ;
; COPY 8088RAM.1 + 8088RAM.2 + 8088ROM.1 + 8088ROM.2  8088.ASM         ;
;======================================================================;
startcode       jmp     main              ; proc main                  ;
;----------------------------------------------------------------------;
;======================================================;
; Permanent NMI INT Procedure: INT02                   ;
;======================================================;
INTProc         proc    near                   ;
                push    ax                     ;
                push    bx                     ;
                push    cx                     ;
                push    dx                     ;
                push    di                     ;
                push    si                     ;
                ;------------------------------;
                ; Send 1st Midi byte           ;
                ;------------------------------;
                call    SendMidi               ; Send 1 Midi byte if TXEnable>0
                ;------------------------------; 
                ; Read Keyboard Keys           ;
                ;------------------------------;
                cmpb    [KeyScanEnable], 00H   ; Scan Disabled
                je      NoKeyScan              ; Yes
                call    ReadKeys               ; Scan Keyboard
                ;------------------------------;
                ; Send 2nd Midi byte           ;
                ;------------------------------;
                call    SendMidi               ; Send 1 Midi byte
                ;------------------------------;
NoKeyScan                                                         
;----------;----;-------------------------------------------;
;Measured  ;    ; Do Tasks 0-1E in word increment           ; *=can be disabled
;IdleLoops:;    ; i.e. 16 tasks:                            ;
;          ;    ;                                           ;
; 39h      ;  * ; Task 0:  Do Buttons                       ;
; 34h      ;  * ; Task 2:  Read Buttons                     ; Start with Task 02
; 31h      ;    ; Task 4:  Do Display Timers                ;
; 2ch      ;    ; Task 6:  Update Displays                  ; 
; 36h      ;  * ; Task 8:  Read KeyBrd Buttons              ;
; 38h      ;  * ; Task A:  Do KeyBrd Buttons                ;
; 37h      ;  * ; Task C:  Read Wheel 0                     ;
; 37h      ;  * ; Task E:  Read Wheel 1                     ;
; 35h      ;  * ; Task 10: Read and Do Wheel Buttons        ; 
; 36h      ;    ; Task 12: (a) Display Menu Indicators      ; very short
;          ;    ;          (b) Display Curr Wheel Value     ;
;          ;    ;          (c) Patch Update                 ; very short
; 28h      ;  * ; Task 14: Read Wheel 2                     ;
; 1eh (2)  ;  * ; Task 16: Read Wheel 3                     ;
; 34h      ;  * ; Task 18: Check Wheels Changed             ;
; 39h      ;  * ; Task 1A: Special Tasks                    ;
; 34h      ;  * ; Task 1C: Do Wheels 0 and 1                ;
; 34h      ;  * ; Task 1E: Do Wheels 2 and 3                ;
;          ;    ;                                           ;
; (1)      ;    ; Special Tasks: Not always active          ;
;          ;  * ; (a) Process Received Commands             ;
;          ;    ; (b)                                       ;
;          ;    ;                                           ;
; (1) Measured with no keys pressed. If all 6 splits enabled;
;     and 8 keys pressed, drops by about 1eh.               ;
; (2) Open circuit wheel, the larger wheel R the longer the ;
;     task time, i.e. 1e improves to about 30h.             ;
;-----------------------------------------------------------;
                ;------------------------------;
                ; Calculate Next TASK          ; Will start with task 02
                ;------------------------------;
                mov     bx, [TaskNumber]       ; bl=TaskNumber: Table Offset
                                               ; bh=TaskBusy 0,1
                add     bl, 02H                ; TaskNumber +2 increase
                and     bl, 00011111B          ; Only Tasks 0,2,4-1E
                mov     [TaskNumber], bl       ; Store current task no
                shr     bh                     ; Task busy-disabled if = 01 
                jc      BusyTask               ; Yes, else bh = 0
                calln   TaskAddress[bx]        ; Task Adress+offset
BusyTask
                ;------------------------------; increment every 2 ms 
                incw    [Timer0]               ; reset to 0: 64k*2ms=2 minutes
                mov     bx, [IdleTimer]        ; bl=IdleTimer, bh=TaskTime
                mov     ax, [TaskTest]         ; al=TaskTest,  ah=TaskNumber
                xor     al, ah                 ; Test# = Task# ? 
                jnz     NotTest                ; if al<>ah
                cmp     bl, bh                 ; cmp shortest idle time
                jae     NotShorter             ; current>=prev shortest
                mov     [TaskTime], bl         ; new shortest
NotShorter      mov     [IdleTimer], al        ; al=0, reset to 0
NotTest         
                ;------------------------------;
                ; Send 3rd Midi byte           ;
                ;------------------------------;
                call    SendMidi               ; Send 1 Midi byte
                ;------------------------------;
EXITINT1        pop     si                     ;
                pop     di                     ;
                pop     dx                     ;
                pop     cx                     ;
                pop     bx                     ;
                pop     ax                     ;
                iret                           ;
                endp                           ; proc INTProc
;==============================================;
main            proc    near                 ;
                ;----------------------------;
                cmpb    [ResetDefault], 00H  ; Reset to defaults ?
                je      NoDefReset           ; No
                call    ResetDef             ;
                ;----------------------------;
                ; Enable Perm INT vector     ;
                ;----------------------------;
NoDefReset      movb    [PermINT], 01H       ; Next Temp INT will set to INTProc
                movb    [TaskTime], 0FFH     ; Debug: Max Time
                movb    [WheelsEnable], 01H  ; Enable Wheels
                ;----------------------------;
loop1           ;================================;
                ; IDLE LOOP                      ;
                ;================================;
                ; Check Command Mode             ; 
                ; Check for Midi Receive Codes   ;
                ;--------------------------------;
                call    ReceiveMidi              ; 
                ;--------------------------------;
                ; Check Idle Times               ; Count Idle Loops
                ;--------------------------------;
                mov     ax, [TaskTest]           ; al=TaskTest ah=TaskNumber
                cmp     ah, al                   ; TaskTest=TaskNumber
                jne     NotTask                  ;
                incb    [IdleTimer]              ;   
                ;--------------------------------;
NotTask         jmp     loop1                    ;
                endp                             ; proc main
;================================================;
;--------------------------------------------------;
; Task 12:       (a) Do Wheels Display             ;
;                (b) Do Menu Display               ;
;                (c) UpDatePatches                 ;
;--------------------------------------------------;
DoVarious       proc    near                       ;
                call    DoWheelsDisp               ; Wheels Display Routine
                call    DispMenu                   ; Do Level0 Menu Update
                call    UpdatePatch                ; Update Patch to Curr Split
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Task 1A: Special Tasks: not always active        ;
;                (a) Process Commands              ;
;                (b)                               ;
;--------------------------------------------------;
DoSpecial       proc    near                       ;
                call    ProcessCom                 ; Process Commands
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Enable or Disable Functions                      ; al=0=disable, al=1=enable
;--------------------------------------------------; 
DisEnableFunc   proc    near                       ;
                mov     [KeyScanEnable], al        ; Dis-Enable KeyScan
                mov     [WheelsEnable], al         ; Dis-Enable Wheels
                mov     [WButtonEnable], al        ; Dis-Enable WhButtons
                mov     [KButtonEnable], al        ; Dis-Enable KBrd Buttons
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Activate Receiver for Commands                   ;
;--------------------------------------------------;
ActivateRx      proc    near                       ;
                push    ax                         ;
                xor     ax, ax                     ; ax=0
                mov     [CommandMode], al          ; Enable New Command
                mov     [RxIn], ax                 ; Rec End Ptr = 0
                mov     [RxOut], ax                ; Rec Start Ptr = 0
                movw    [RxBufferMax], RxEnd       ; Receiver Max Buff Size
                movw    [RxBuffer], offset(RxBuff) ; Addr of Receiver Buff
                movb    [RxEnable], 01H            ; Enable Receiver
                pop     ax                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
CFG1234Tab      DW      offset(CFG1), offset(CFG2) ; CFG Blocks 1,2,3,4
                DW      offset(CFG3), offset(CFG4) ;
;--------------------------------------------------;
SelectCFG1234   proc    near                       ; Returns si=CFG1,2,3,4
;--------------------------------------------------;         di=si+240
                push    bx                         ;
                xor     bx, bx                     ; bx=0
                mov     bl, +7[di]                 ; +0[di]=XBuff, bl=0,1,2,3
                shl     bx                         ; bx=0,2,4,6
                mov     si, offset(CFG1234Tab)[bx] ; si=CFG1-CFG4
                mov     di, si                     ; di=si
                add     di, 40*6                   ; di=END, si=START
                pop     bx                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
SetupCFGBlock   proc    near                       ; bx=CFG1,2,3,4 on entry
;--------------------------------------------------; 
                push    ax                         ;
                mov     ax, 40                     ; ax=40=Split A-F Size
                mov     [SplitCFG:A], bx           ;
                add     bx, ax                     ;
                mov     [SplitCFG:B], bx           ;
                add     bx, ax                     ;
                mov     [SplitCFG:C], bx           ;
                add     bx, ax                     ;
                mov     [SplitCFG:D], bx           ;
                add     bx, ax                     ;
                mov     [SplitCFG:E], bx           ;
                add     bx, ax                     ;
                mov     [SplitCFG:F], bx           ;
                pop     ax                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Command 00: Send ACK back                        ;
;--------------------------------------------------; 
CommandACK      DB  0F0H, 0,0,0, 01H, 0F7H         ; SysEx Format
;--------------------------------------------------;
Comm00          proc    near                       ;
                push    ax                         ;
                push    dx                         ;
                ;----------------------------------; Do not use XBuff, will
                ; Send Command Knock Received ACK  ; interfere with ProcessComm
                ;----------------------------------; 
                mov     dl, 0F0H                   ; [F0]: SysExStart
                xor     ax, ax                     ; [0][0]: Id1, Id2
                call    XmitMidi3                  ; Sends dl,ah,al
                mov     dl, al                     ; [0]: Id3
                mov     ax, 01F7H                  ; [0][F7]: DataLen, SysExEnd 
                call    XmitMidi3                  ; Sends dl,ah,al
                ;----------------------------------;
                pop     dx                         ;
                pop     ax                         ;
                ret                                ;
                endp                               ;
;-----------------------------------------------------------------------------;
; Command 01: Enable-Disable Single Split   TESTED OK                         ;
;-----------------------------------------------------------------------------; 
; To enable Split B:                                                          ;
; Send 240   0 0 0  4 0  1        1 1       247                               ; 
;      SysEx ID     Len  Comm Split En-Dis  SysExEnd                          ;
; To disable Split C:                                                         ;
; Send 240  0 0 0  4 0  1  2 0  247                                           ;
; Note: Should wait 2mS after sending 240 before sending rest of bytes.       ;
;       Could else send about 6-8 F0 bytes at start.                          ;
;-----------------------------------------------------------------------------;
Comm01          proc    near                       ; [di]->[RxBuffer]
                push    ax                         ;
                push    bx                         ;
                xor     ax, ax                     ; ax=0
                ;----------------------------------;
                mov     bx, +7[di]                 ; bl=Data1:Split A-F Enable
                mov     al, bh                     ; bh=Data2:0:Enable,1:Disable
                mov     bh, ah                     ; bh=0
                shl     bx                         ; Split No *2
                mov     bx, offset(SplitCFG:A)[bx] ; bx <- [SplitCFG:X]
                ;----------------------------------;
C01Enable       mov     +11[bx], al                ; al=0,1:SplitX Un,Active
                ror     ax                         ; al=1->ah=128, al=0->ah=0
                or      [bx],  ah                  ; or 80H,0H: SplitStrt D7=1
                ;----------------------------------; 
                pop     bx                         ;
                pop     ax                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------------------;
; Command 02: Enable-Disable Multiple Splits  TESTED OK        ;
;--------------------------------------------------------------; 
; To enable Split B,D, disable A,C E,F:                        ;
; Send 240  0 0 0  14 0  2  0 0  2 1  3 0  4 1  5 0  6 0   247 ;            
;                           A    B    C    D    E    F         ;
;--------------------------------------------------------------; 
Comm02          proc    near                       ;
                push    ax                         ; [di]->[RxBuffer]
                push    bx                         ;
                push    cx                         ;
                push    di                         ;
                xor     cx, cx                     ; cx=0
                mov     cl, 06H                    ; 6 Splits
                ;----------------------------------;
C02Loop         xor     ax, ax                     ; ax=0
                mov     bx, +7[di]                 ; bl=Data1:Split A-F Enable
                mov     al, bh                     ; bh=Data2:0:Enable,1:Disable
                mov     bh, ah                     ; bh=0
                shl     bx                         ; Split No *2
                mov     bx, offset(SplitCFG:A)[bx] ; bx <- [SplitCFG:X]
                ;----------------------------------;
                mov     +11[bx], al                ; al=0,1:SplitX Un,Active
                ror     ax                         ; al=1->ah=128, al=0->ah=0
                or      [bx],  ah                  ; or 80H,0H: SplitStrt D7=1
                add     di, 02H                    ; [di]->+7,+9,+11,+13,+15,+17
                loop    C02Loop                    ;
                ;----------------------------------; 
                pop     di                         ;
                pop     cx                         ;
                pop     bx                         ;
                pop     ax                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Command 03:   New CFG Data                       ; TESTED OK
;--------------------------------------------------;
; Send 240  0 0 0  99 3  3  x  n0..n479  247       ; x = 0-3 = SplitBlock 1-4 
;--------------------------------------------------; n1-n479 CFG Data as 7bit
Comm03          proc    near                       ; Datalength=3+240*2-1=483
                push    cx                         ; 483-256-128=99=63H
                push    di                         ;=>d1=63h=99, d2=03=128+256
                push    si                         ;
                ;----------------------------------; [di]->[RxBuffer]
                call    SelectCFG1234              ; Returns si=CFG1,2,3,4, di
                mov     di, si                     ; di=si+240 not used
                ;----------------------------------;
                mov     cx, 240                    ; cx=240 words(si), bytes(di)
                mov     si, [RxBuffer]             ; Data starts at byte 8
                add     si, 0008H                  ;
                ;----------------------------------;
C03Loop         lodsw                              ; [si]->ax, si+2
                xchg    ax                         ; exchange al, ah
                ror     ah                         ; ah=1->ah=128, ah=0->ah=0
                or      al, ah                     ; ah=128->al=al+128
                stosb                              ; al->[di], di=di+1
                loop    C03Loop                    ;
                ;----------------------------------;
                pop     si                         ;
                pop     di                         ;
                pop     cx                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Command 04:   Send Selected block CFG Data       ; 
;--------------------------------------------------;
; Send 240  0 0 0  3 0  4  x  247                  ; x = CFGBlock 0-3
;--------------------------------------------------; 
Comm04          proc   near                        ;
                push    di                         ;
                push    si                         ;
                ;----------------------------------; [di]->[RxBuffer]
                movb    [Bit7Enable], 01H          ; Send as 0-127 double bytes
                call    SelectCFG1234              ; Returns si=CFG1,2,3,4, di
                call    SendData                   ; Send from [si] up to [di]
                movb    [Bit7Enable], 00H          ; Send as 0-255 single byte
                ;----------------------------------; Send ah=0,1 al=0-127
                pop     si                         ; 
                pop     di                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Command 05:   Send Current block CFG Data        ; TESTED OK
;--------------------------------------------------;
; Send 240  0 0 0  2 0  5  247                     ; 
;--------------------------------------------------; 
Comm05          proc   near                        ;
                push    di                         ;
                push    si                         ;
                ;----------------------------------;
                movb    [Bit7Enable], 01H          ; Send as 0-127 double bytes
                mov     si, [SplitCFG:A]           ; CFG Block 1-4:A Start
                mov     di, si                     ; 
                add     di, 40*6                   ; END Ptr=240 bytes,Split A-F
                call    SendData                   ; Send from [si] up to [di]
                movb    [Bit7Enable], 00H          ; Send as 0-255 single byte
                ;----------------------------------; Send ah=0,1 al=0-127
                pop     si                         ; 
                pop     di                         ;
                ret                                ;
                endp                               ;
;------------------------------------------------------;
; Command 06: Make new Split Current                   ;
;------------------------------------------------------; 
; To make Split B Current:                             ;
; Send 240   0 0 0  3 0  6        1   247              ; 
;      SysEx ID     Len  Comm Split   SysExEnd         ;
;------------------------------------------------------;
Comm06          proc    near                       ; [di]->[RxBuffer]
                push    bx                         ;
                ;----------------------------------;
                mov     bl, +7[di]                 ; bl=Data1:Split A-F Current
                mov     [Split], bl                ; Store Split 0-5
                call    SetPatch                   ; SplitPatch->CurrPatch
                ;----------------------------------; 
                pop     bx                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Command 07: Select new Split Block 1,2,3,4       ;
;--------------------------------------------------;
; To select Split Block 2:                         ;
; Send 240   0 0 0  3 0  7    1           247      ; 
;      SysEx ID     Len  Comm SplitBlock  SysExEnd ;
;--------------------------------------------------;
Comm07          proc    near                       ; [di]->[RxBuffer]
                push    bx                         ;
                push    di                         ;
                push    si                         ;
                ;----------------------------------;
                call    SelectCFG1234              ; Returns si=CFG1,2,3,4, di
                mov     bx, si                     ;
                call    SetupCFGBlock              ; bx=CFG1,2,3,4 on entry
                call    SetPatch                   ; SplitPatch->CurrPatch
                call    DoAutoLoad                 ; Send CFGStr if active
                ;----------------------------------; 
                pop     si                         ;
                pop     di                         ;
                pop     bx                         ;
                ret                                ;
                endp                               ;
;---------------------------------------------------------------------------;
; Command 08:   Increase-decrease-zero selected Split Octave or Transpose   ;
;---------------------------------------------------------------------------; 
CommOctTpTab    DW  offset(OctaveZero), offset(OctaveDown), offset(OctaveUp) 
                DW  offset(XPoseZero),  offset(XPoseDwn),   offset(XPoseUp) 
;---------------------------------------------------------------------------; 
Comm08          proc   near                                                 ;
;---------------------------------------------------------------------------; 
; To increase octave Split B:                        Oct:0=Zero Xpose:3=Zero;
; Send 240   0 0 0  4 0  8    1      2      247          1=Down       4=Down; 
;      SysEx ID     Len  Comm Split  OctTp  SysExEnd     2=Up         5=Up  ;
;---------------------------------------------------------------------------; 
                push   bx                          ;
                push   di                          ;
                push   [Split]                     ; current Split modified
                ;----------------------------------;
                mov    bx, +7[di]                  ; bl=Split A-F=0-5, bh=OctTp
                mov    [Split], bl                 ; Temporary current Split
                mov    bl, bh                      ; bl=0,1,2 = Octave Type
                xor    bh, bh                      ; bh=0
                shl    bl                          ; word offset
                mov    di, offset(CommOctTpTab)[bx]; Routine to do
                call   DoXposeOct                  ; Do Routine
                ;----------------------------------;
                pop    [Split]                     ; current Split back
                pop    di                          ;
                pop    bx                          ;
                ret                                ;
                endp                               ;
;------------------------------------------------------;
; Command 09:   Increase-decrease all Splits Octave    ;
;------------------------------------------------------; 
Comm09          proc   near                        ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Command 10:                                      ;
;--------------------------------------------------; 
Comm10          proc   near                        ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Command 11:                                      ;
;--------------------------------------------------; 
Comm11          proc   near                        ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
; Write Command number 00-11                       ;
;--------------------------------------------------;
WriteCommTab    DB CLo,   Zero, Zero               ; "c00"  Comm00
                DB E,     S,   One                 ; "ES1"  Comm01
                DB E,     S,   Two                 ; "ES2"  Comm02
                DB C,     F,   One                 ; "CF1"  Comm03
                DB C,     F,   Two                 ; "CF2"  Comm04
                DB C,     F,   Three               ; "CF3"  Comm05
                DB S,     C,   Space               ; "SC "  Comm06
                DB S,     BLo, Space               ; "SB "  Comm07
                DB Space, Space, Space             ;        Comm08
                DB Space, Space, Space             ;        Comm09
                DB CLo, One, Zero                  ; "c10"  Comm10
                DB CLo, One, One                   ; "c11"  Comm11
;--------------------------------------------------;
WriteComm       proc   near                        ;
;--------------------------------------------------;
                push   ax                          ;
                push   bx                          ;
                mov    ax, [CommandNo]             ; CommandNo 0-99
                mov    bx, offset(WriteCommTab)    ; Command Messages
                add    bx, ax                      ;
                add    bx, ax                      ;
                add    bx, ax                      ;
                cmpb   [bx], Space                 ; 1st Space=don't write
                je     WriteCommExit               ; Yes
                mov    [Message], bx               ;
                call   WriteStaticTB               ; Write Message
WriteCommExit   pop    bx                          ;
                pop    ax                          ;
                ret                                ;
                endp                               ;
;---------------------------------------------------------------; 
; Process received Commands                                     ;
;---------------------------------------------------------------; 
; SysEXStart ID1 ID2 ID3 LenLo LenHi CommNo D1..Dn SysEXEnd     ;
;  B0        B1  B2  B3  B4    B5    B6     B7..   Bx           ;
;---------------------------------------------------------------; 
; DataLength: B4=0-127 B5=0-127. Construct DataLength by        ;
;             replacing B4(D7) with B5(D0), and shifting        ;
;             all the other B5 digits one position right.       ;
;             Length includes CommandNo and SysExEnd bytes.     ;
;---------------------------------------------------------------; 
; CommandMode: 0=Unactive                                       ;
;              1=F0 received, busy receiving until F7           ;
;              2=F7 received, but not command not yet processed ;
;---------------------------------------------------------------; 
CommandAddr     
                DW  offset(Comm00), offset(Comm01) ; Command routines
                DW  offset(Comm02), offset(Comm03) ;
                DW  offset(Comm04), offset(Comm05) ;
                DW  offset(Comm06), offset(Comm07) ;
                DW  offset(Comm08), offset(Comm09) ;
                DW  offset(Comm10), offset(Comm11) ;
;--------------------------------------------------;
ProcessCom      proc   near                        ;
                cmpb   [CommandMode], 02H          ; Comm requires Processing ?
                jne    PCExit                      ; No
                movb   [CommandMode], 00H          ; Reset to processed done
                ;----------------------------------;
                push    ax                         ; Byte 0 = F0 already been
                push    bx                         ; 
                push    di                         ; 
                mov     di, [RxBuffer]             ; Addr of Receiver Buff
                cmpb    [di], 0F0H                 ; Byte 0: F0=SysEx Start ?
                jne     PCExit1                    ; No
                ;----------------------------------;
                mov     ax, +1[di]                 ; SysEx 3 byte ManufID:all 0
                add     al, +3[di]                 ;
                jnz     PCExit1                    ; Wrong Manufacturer ID
                ;----------------------------------;
                mov     bx, +4[di]                 ; Data length bytes
                shr     bh                         ; bh:D0->bl:D7
                jnc     NotD0                      ; and shift other bh 1 right
                or      bl, 10000000B              ; Set bl:D7
NotD0           mov     [DataLength], bx           ; bh=Len(Hi), bl=Len(Lo)
                cmpb    +5[bx+di], 0F7H            ; SysEx End ?
                jne     PCExit1                    ; No
                ;----------------------------------;
                xor     bh, bh                     ; bh=0
                mov     [di], bh                   ; Reset block: remove F0
                mov     bl, +6[di]                 ; bl=Command No
                mov     [CommandNo], bl            ;                     
                shl     bl                         ; 2* -> Addr word offset
                and     bl, 00011111B              ; Only Command (0-11)*2
                calln   offset(CommandAddr)[bx]    ; Call Command Routine  
                call    WriteComm                  ; Display Comm00-99 messages
                ;----------------------------------;
PCExit1         pop     di                         ;
                pop     bx                         ;
                pop     ax                         ;
PCExit          ret                                ;
                endp                               ;
;--------------------------------------------------; 
;----------------------------------------------------------------;
; BIOS Data:non standard: Are Xmitted as 8bit values, no header  ;
;----------------------------------------------------------------;
; System Exclusive: (* = Compulsary Standard Format)             ; Size is after
; * Byte 0: SysEx = F0 : SysEx Command Byte                      ; decoding i.e
; * Byte 1,2,3: Manuf ID (Previously only Byte 1 used:=>0-127)   ; 7bit->8bit
;             : If 1st byte=0 then next two bytes gives 14bit ID ; 7bit->8bit
;             : Use provisionally 0, 0, 0 here.                  ; 7bit->8bit
;   Byte 4: Dump ID: 0                                           ; Size varies
;                  : 1 Split CFG Data: Single CFG Block=4 Splits ; Size=240
;                  : 2 Split CFG Data: 4 Split CFG's=24 Splits   ; Size=960
;                  : 4 Split String Data for 4 Splits            ; Size=64
;                  : 5 RAM Velocity Table Data                   ; Size=128
;                  : 6 Programmed Patch Data                     ; Size=320
;   Bytes 5 - x : Data Bytes (all 0-128): Send as 2 bytes :      ;
;                 MSB (=0,1) LSB (=0-7F) to form 8 bit byte.     ;
;   Byte x+1: Checksum (Simple 7 bit sum of Data Bytes)          ;
;           : Calculate as 8bit Sum and then set D7=0.           ;
; * Byte x+2: SysExEnd = F7: End of SysEx                        ;
;----------------------------------------------------------------;
;------------------------------------------------------;
; Make System Exclusive Header                         ;
;------------------------------------------------------;
MakeSysExHead   proc    near                           ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
; Read System Exclusive Header                         ;
;------------------------------------------------------;
ReadSysExHead   proc    near                           ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
;--------------------------------------------------;
UpDatePatch     proc    near                       ; Update Patches
;--------------------------------------------------;
                push    bx                         ;
                call    SetUpSplit                 ; Get Curr Split
                mov     al, [CurrPatch]            ; Current PatchNumber
                andb    +38[bx], 10000000B         ; Keep if >127:Autoload
                or      +38[bx], al                ; Store in Split Patch
                pop     bx                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
SetPatch        proc    near                       ; Update Patches
;--------------------------------------------------;
                push    bx                         ;
                call    SetUpSplit                 ; Get Curr Split
                mov     al, +38[bx]                ; Get Split Patch
                and     al, 07FH                   ; SUB 128 if >127=AutoLoad
                mov     [CurrPatch], al            ; Make Current PatchNumber
                pop     bx                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
;------------------------------------------------------;
; Level 1 Routines                                     ;
;------------------------------------------------------;
Lev1:0          
                ;======================================;
                ; Level 1: Key 0 = Debug               ;
                ;======================================;
L0:0:K00
                mov     al, [UARTStatus]               ;
                call    XlateBinaryTab                 ;
                jmp     ExitKeyRoutine                 ;
L0:0:K01        ;--------------------------------------;
                mov     al, [TaskTime]                 ;
                call    XlateBinaryTab                 ;
                call    WriteHex                       ;
                jmp     ExitKeyRoutine                 ;
L0:0:K02        ;--------------------------------------;
                mov     al, [BinCount]                 ;
                call    XlateBinaryTab                 ;
                incb    [BinCount]                     ;
                jmp     ExitKeyRoutine                 ;
L0:0:K03        ;--------------------------------------;
L0:0:K04        ;--------------------------------------;
                jmp     ExitKeyRoutine                 ;
L0:0:K05        ;--------------------------------------;
                mov     bx, [CounterHex] 
                mov     al, [bx]
                call    XlateBinaryTab                 ;
                call    WriteHex
                incw    [CounterHex]
                jmp     ExitKeyRoutine                 ;
L0:0:K06        ;--------------------------------------;
                mov     bx, [CounterDec] 
                mov     al, [bx]
                call    XlateBinaryTab                 ;
                call    WriteDec
                incw    [CounterDec]
                jmp     ExitKeyRoutine                 ;
L0:0:K07        ;--------------------------------------;
                call    Get3Dec                        ;
                mov     [CounterDec], al               ;
                mov     [CounterHex], al               ;
                call    Delay00                        ;
                call    Get3Dec                        ;
                mov     [CounterDec+1], al             ;
                mov     [CounterHex+1], al             ;
                call    Delay00                        ;
                jmp     ExitKeyRoutine                 ;
L0:0:K08        ;--------------------------------------;
                mov     al, [Wheel0]                   ; Raw Value
                call    WriteHex                       ;
                call    Delay0                         ;
                mov     al, [Wheel0Value]              ; Scaled Value
                call    WriteHex                       ;
                jmp     ExitKeyRoutine                 ;
L0:0:K09        ;--------------------------------------;
                call    Get3Dec                        ;
                mov     [TaskTest], al                 ;
                call    WriteHex                       ;
                movb    [TaskTime], 0FFH               ; set=longest
                movb    [IdleTimer], 07FH              ; set to 127
                jmp     ExitKeyRoutine                 ;
L0:0:K15
                movw    [Disp1:1], (2*256)+RLo         ; Test Temp Displays
                movb    [Error], 00H                   ; reset error
                jmp     ExitKeyRoutine                 ;
L0:0:K10
L0:0:K11
L0:0:K12
L0:0:K13
ExitLev1:0
                jmp     ExitKeyRoutine                 ;
;------------------------------------------------------;
Lev1:5          
;------------------------------------------------------;
;========================================;
; Level 1: Key 5 = System                ;
;========================================;
;  [7]             [8]             [9]   ; Select Noteoff format.
;Select NoteOff:                UART-DTR ; 
;90-x-00 80-x-VEL                on-off  ; 
;----------------------------------------;
;  [4]             [5]             [6]   ;
;Disable Keybrd  Send                    ; Xmit contents of Data Area-Buffer
;  Scan          Buffer                  ; 0=Cancel, 1=Receiver, 2=SplitCFG
;----------------------------------------; 3=SplitStr 4=0-4095 of RAM
;  [1]             [2]             [3]   ; Num+10=>Add SysExclusive Header
;Select Basic   Receiver       Send CFG  ; 
;Note Offset     ON-OFF      as 7bit data;                          
;----------------------------------------;
;  [0]           [ENTER]        [ESCAPE] ; 
;                              Return to ;                                
;                               Level 0  ;              
;========================================;
                ;--------------------------------------;
                ; Key 01: Select Basic Note Offset     ;
                ;--------------------------------------;
L0:5:K01        call    Get1Dec                        ;
                cmp     al, 040H                       ;
                ja      L0:5:K01                       ; Only 0-64 allowed
                mov     [ScanToKey], al                ; 0=No effect
                call    CalcKeyOffSet                  ; Set for all 4 Splits
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; En-Dis-able Receiver                 ;
L0:5:K02        ;--------------------------------------;
                xorb    [RxEnable], 01H                ; En-Disable Receiver
                jz      L05RxDis                       ; 
                ;--------------------------------------;
L05RxEn         call    ActivateRx                     ; Enable, init receiver
                movw    [Message], offset(ReceiverOn)  ;
                jmp     L05K02Exit                     ;
                ;--------------------------------------;
L05RxDis        movw    [Message], offset(ReceiverOff) ; al=0=Disable
                ;--------------------------------------;
L05K02Exit      call    WriteStaticPS                  ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 04: Disable Keyboard Scans       ;
                ;--------------------------------------;
L0:5:K04        call    Get1Dec                        ;
                cmp     al, 01H                        ;
                ja      L0:5:K04                       ; Only 0,1 allowed
                mov     [KeyScanEnable], al            ; 0=OFF, 1=ON
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 05: Send Data Area-Buffer        ;
L0:5:K05        ;--------------------------------------;
L05K05          call    Get2Dec                        ; Get 2 digit constant
                cmp     al, 15                         ; 0-7,8-15 accepted
                ja      L05K05                         ; Try again
                ;--------------------------------------;
                cmp     al, 01H                        ; Receiver Headerless ?
                jb      RecNoHead                      ; Yes
                je      SplitCFGNoHead                 ; 
                cmp     al, 03H                        ; RAM Headerless ?
                je      RAMNoHead                      ; Yes
                jb      StrNoHead                      ;  
                ja      L05SendExit                    ;
                ;--------------------------------------;
RAMNoHead       push    di                             ;
                push    si                             ;
                mov     di, 4095                       ; End of RAM DATA
                xor     si, si                         ; si=0, start of RAM
                jmp     L05SendData                    ;
                ;--------------------------------------;
RecNoHead       push    di                             ;
                push    si                             ;
                mov     di, offset(RxBuff)             ; Receiver Buffer
                mov     si, di                         ; 
                add     di, [RxIn]                     ; END Ptr
                add     si, [RxOut]                    ; START Ptr
                dec     di                             ; Last inc di in RecLoop
                cmp     di, si                         ; END>START ?
                jbe     L05NoData                      ; Nothing in buffer
                jmp     L05SendData                    ;
                ;--------------------------------------;
StrNoHead       push    di                             ;
                push    si                             ;
                mov     si, offset(SplitCFGStr)        ; SplitCFGStr Start
                mov     di, offset(SplitCFGStr)+16*4   ; Size=64 bytes
                jmp     L05SendData                    ;
                ;--------------------------------------;
SplitCFGNoHead  push    di                             ;
                push    si                             ;
                mov     si, [SplitCFG:A]               ; SplitCFG Start
                mov     di, si                         ; 
                add     di, 40*6                       ; END Ptr = 240 bytes
                ;--------------------------------------;
L05SendData     call    SendData                       ;
                call    WriteDone                      ;
L05NoData       pop     si                             ;
                pop     di                             ;
L05SendExit     jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Select NoteOn Format:                ;
                ; [90-Note-00] or [80-Note-VEL]        ;
                ; Valid for all 4 Splits               ;
                ;--------------------------------------;
L0:5:K07        movw    [Message], offset(NOffMess)    ; Note Off: Key 0,1
                call    WriteScroll                    ;
                call    Get1Dec                        ;
                call    Delay00                        ;
                cmp     al, 01H                        ;
                ja      L0:5:K07                       ; Only 0,1 allowed
                cmp     al, 00H                        ;
                je      L05NOff80                      ; 80 Format:default
                movw    [MidiNoteOff], 0090H           ;
                jmp     ExitKeyRoutine                 ;
L05NOff80       movw    [MidiNoteOff], 7F80H           ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:5:K03        call    Comm06                         ;
L0:5:K06 
L0:5:K08
L0:5:K00        jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 09: Set-Reset UART DTR ouput     ; DTR connected to RED
                ;--------------------------------------; LED on front panel
L0:5:K09        push    ax                             ;
                mov     ax, [DTRStatus]                ; al=DTR var: 0,1
                                                       ; ah=00000101 Tx=Rx=On
                xor     al, 01H                        ; 1=Set, 0=reset DTR var
                jnz     L05K09On                       ; DTR on
L05K09Off       mov     ah, 00100111B                  ; Off D1=1         
L05K09On        mov     [UARTControl], ah              ; On  D1=0
                mov     [DTRStatus], al                ;
                call    WriteHex                       ; al=01,00
                mov     al, ah                         ;
                call    XlateBinaryTab                 ; Display ah
                pop     ax                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:5:K10
L0:5:K11
L0:5:K12
L0:5:K13
L0:5:K15 
ExitLev1:5
                jmp     ExitKeyRoutine                 ;
;------------------------------------------------------;
Lev1:6          
;======================================;
; Level 1: Key 6 = Reset               ;
;======================================;
;  [7]           [8]           [9]     ; 
;  All Notes    127 Notes Off          ;
;  Off, all Ch  Curr Split Ch          ; 
;--------------------------------------;
;  [4]           [5]           [6]     ;
;                                      ; 
;                                      ;
;--------------------------------------;
;  [1]           [2]           [3]     ;
;Load all       Do Warm                ;
;Default Values  Reboot                ;
;--------------------------------------;
;  [0]         [ENTER]       [ESCAPE]  ; 
;                            Return to ;                                
;                             Level 0  ;              
;======================================;
                ;--------------------------------------;
                ; Key 00:                              ;
                ;--------------------------------------;
L0:6:K00       
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 01: Reset to default values      ;
                ;--------------------------------------;
L0:6:K01        call    GetYesNo                       ;
                cmp     al, 00H                        ; No ?
                je      L06K01Exit                     ; Cancel Reset
                call    ResetDef                       ;
                call    InitUART                       ;
L06K01Exit      jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 02: Do Warm Boot                 ;
                ;--------------------------------------;
L0:6:K02        call    GetYesNo                       ;
                cmp     al, 00H                        ; No ?
                je      L06K02Exit                     ; Cancel Reset
                jmp     Rommain                        ;
L06K02Exit      jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 07: Send All Notes off on 16 Ch  ;
                ;--------------------------------------;
L0:6:K07        call    AllNotesOff1                   ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 08: Send 128 Notes off on Curr Ch;
                ;--------------------------------------;
L0:6:K08        call    AllNotesOff2                   ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:6:K03 
L0:6:K04 
L0:6:K05 
L0:6:K06 
L0:6:K09 
L0:6:K10
L0:6:K11
L0:6:K12
L0:6:K13
L0:6:K15 
ExitLev1:6
                jmp     ExitKeyRoutine                 ;
;------------------------------------------------------;
Lev1:1          
;========================================;
; Level 1: Key 1 = Velocity Params       ;
;========================================;
;  [7]             [8]             [9]   ;
;                                        ; 
;                                        ;
;----------------------------------------;
;  [4]             [5]             [6]   ;
;Vertical                                ;
;Offset                                  ;
;----------------------------------------;
;  [1]             [2]             [3]   ;
;Display Curr  Change Const  Configure   ;
;Vel Contour   Vel Value    Custom VelTab;
;----------------------------------------;
;  [0]           [ENTER]        [ESCAPE] ; 
;Select Vel                    Return to ;                                
;Contour                        Level 0  ;              
;========================================;
GetConstant     proc    near             ;
;----------------------------------------;
                push    bx               ;
                call    SetUpSplit       ; Calc SplitCFG Block
GCL1            call    Get3Dec          ; Get 3 digit constant
                call    Delay00          ;
                cmp     al, 127          ; Vel = 0-127
                ja      GCL1             ; Try again
                mov     +14[bx], al      ; VelConstant
                pop     bx               ;
                ret                      ;
                endp                     ;
;--------------------------------------------------;
DispCurrVel     proc    near                       ; Write Predefined Patch No
                push    ax                         ;
                push    bx                         ;
                ;----------------------------------;
                call    SetUpSplit                 ; Calc SplitCFG Block
                mov     al, +15[bx]                ; Velocity Contour 0-10 
                add     al, +12[bx]                ; 0:normal , 11:Inverse mode
                call    WriteDec                   ;
                movb    [Disp1:1], V               ; "Vxx"
                mov     al, +14[bx]                ;
                cmp     al, 0FFH                   ; Not Constant ?
                je      ExitDCV                    ; Yes, Exit
                call    Delay00                    ;
                call    WriteDec                   ; al=constant
                ;----------------------------------;
ExitDCV         pop     bx                         ;
                pop     ax                         ;
                ret                                ;
                endp                               ;
                ;======================================;
                ; Level 1: Key 1 = Velocity Contours   ;
                ;======================================;
                ;--------------------------------------;
                ; Key 00: Change Curr Split Vel contour;
                ;--------------------------------------;
L0:1:K00        push    bx                             ;
                call    DispCurrVel                    ; Show current Vel No
                call    Delay0                         ;
L01L0           call    Get2Dec                        ; Get Velocity Contour
                mov     ah, 0BH                        ; ah=11
                cmp     al, 21                         ; Only 0-21 allowed
                ja      L01L0                          ; Try again
                call    SetUpSplit                     ; Calc SplitCFG Block
                movb    +12[bx], 00H                   ; Norm=0 
                movb    +14[bx], 0FFH                  ; Constantoff=FFH
                cmp     al, ah                         ; VelMode<11 = Normal ?
                jb      L01NotInv                      ; Yes not inverse
                mov     +12[bx], ah                    ; Inverse mode = 11
                sub     al, ah                         ; VelMode 11-21 -> 0-10
L01NotInv       mov     +15[bx], al                    ; Velocity Contour 0-10 
                cmp     al, 0AH                        ; Constant Velocity ?
                jne     L01NotConst                    ;
                call    GetConstant                    ; Get 3 digit constant
                jmp     L01Exit                        ; No SetVT
L01NotConst     call    SetVT                          ; Contour Table Address
L01Exit         pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 01: Show current velocity setting;
                ;--------------------------------------;
L0:1:K01        
                call    DispCurrVel                    ; Display Vel Table No
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 02: Set Constant Vel Value       ;
                ;--------------------------------------;
L0:1:K02        call    GetConstant                    ; Get 3 digit constant
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 03: Configure Custom Vel Table   ;
                ;--------------------------------------;
L0:1:K03        
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 04: Set + Vertical Offset        ; Overwritten if Volume
                ;--------------------------------------; Controller used
L0:1:K04        push    bx                             ;
                call    SetUpSplit                     ; Calc SplitCFG Block
L01K04          call    Get2Dec                        ; Get 2 digit constant
                call    Delay00                        ;
                cmp     al, 64                         ; Vel offset max = 64
                ja      L01K04                         ; Try again
                mov     +13[bx], al                    ; Save al = Vert Offset
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 05:                              ;
                ;--------------------------------------;
L0:1:K05        
L0:1:K06   
L0:1:K07        
L0:1:K08        
L0:1:K09        
L0:1:K10
L0:1:K11
L0:1:K12
L0:1:K13
L0:1:K15
ExitLev1:1
                jmp     ExitKeyRoutine                 ;
;------------------------------------------------------;
Lev1:7          
;======================================;
; Level 1: Key 7 = Split 2             ;
;======================================;
;  [7]           [8]           [9]     ; 
;Load CFG4    Select CFG   Define Key  ; Load CFG blocks as set of splits A->E
;             1-4 to load  Splitpoints ; Define Lo and Hi keys on keyboard
;--------------------------------------;
;  [4]           [5]           [6]     ; 
;Load CFG3    AutoLoad    Define Split ; Switch Patch AutoLoad (Patch+128) OnOff
;            OnOff:Patch   Preinit Str ;
;--------------------------------------;
;  [1]           [2]           [3]     ;
;Load CFG2     Send Split   Send all 4 ;
;             Preinit Str  Preinit Strs;
;--------------------------------------;
;  [0]         [ENTER]       [ESCAPE]  ; Get Split Midichannel 1-16
;Load CFG1    Get Split      Return to ;                                
;            MidiChannel      Level 0  ;              
;=========================================;
CheckAutoLoad   proc    near              ;
;-----------------------------------------;
                push    si                ; save
                ;-------------------------;
                ; Check SplitStr Autoload ;
                ;-------------------------;
                mov     cl, +37[bx]       ; 0=OFF, >127=AUTO LOAD
                or      cl, cl            ;
                jns     NoSSLoad          ; No load if < 128, or if cx=0
                and     cx, 007FH         ;
                rep                       ; will inc di, si, dec cx
                movsb                     ; [di]->new destination
NoSSLoad        ;-------------------------;
                ; Check Patch Autoload    ;
                ;-------------------------;
                mov     ah, +38[bx]       ; 0=OFF, >127=AUTO LOAD
                or      ah, ah            ;
                jns     NoPLoad           ; No load if < 128, or if cx=0
                and     ah, 7FH           ;
                mov     al, 0C0H          ;
                or      al, +10[bx]       ; Channel
                stosw                     ; al->[di], di=di+2
                ;-------------------------;
NoPLoad         add     bx, 40            ; Next SplitCFG
                pop     si                ;
                add     si, 16            ; Next SplitCFG Str
                ret                       ;
                endp                      ;
;-----------------------------------------;
DoAutoLoad      proc    near              ;
;-----------------------------------------;
                push    cx                ;
                push    di                ;
                push    si                ;
                ;-------------------------;
                mov     bx, [SplitCFG:A]  ; [bx]->Split A
                mov     si, SplitCFGStr   ;
                movw    [XBuffOut], 0000H ; Start Xmit from XBuff+0
                mov     di, offset(XBuff) ;
                ;-------------------------;
                call    CheckAutoLoad     ; Split A
                call    CheckAutoLoad     ; Split B
                call    CheckAutoLoad     ; Split C
                call    CheckAutoLoad     ; Split D
                call    CheckAutoLoad     ; Split E
                call    CheckAutoLoad     ; Split F
                ;-------------------------;
                sub     di, offset(XBuff) ; Anything stored ?
                jz      DoALNoSend        ; No
                mov     [XBuffIn], di     ;
                movb    [TxEnable], 02H   ; Enable XtraSend in MidiSend
                ;-------------------------;
DoALNoSend      pop     si                ;
                pop     di                ;
                pop     cx                ;
                ret                       ;
                endp                      ;
;------------------------------------------------------;
GetCFG1234      proc    near                           ; 
;------------------------------------------------------;
GetCFGLoop      call    Get1Dec                        ; GFG Number: 1,2,3,4
                dec     al                             ; al = 0,1,2,3, ah=0
                cmp     al, 03H                        ;
                ja      GetCFGLoop                     ; Only 1-4 allowed
                ;--------------------------------------;
                mov     bx, offset(SplitCFGTab)        ; GetCFG1-GetCFG4
                shl     ax                             ; Word Ptr
                add     bx, ax                         ;
                jmpn    [bx]                           ; jmp GetCFG1->GetCFG4
                ;--------------------------------------;
GetCFG1         mov     bx, CFG1                       ; al=0
                movw    [Message], offset(CFG1Mess)    ; "C=1"
                jmp     GetCFGL1                       ;
                ;--------------------------------------;
GetCFG2         mov     bx, CFG2                       ; al=1
                movw    [Message], offset(CFG2Mess)    ; "C=2"
                jmp     GetCFGL1                       ;
                ;--------------------------------------;
GetCFG3         mov     bx, CFG3                       ; al=2
                movw    [Message], offset(CFG3Mess)    ; "C=3"
                jmp     GetCFGL1                       ;
                ;--------------------------------------;
GetCFG4         mov     bx, CFG4                       ; al=3
                movw    [Message], offset(CFG4Mess)    ; "C=4"
                ;--------------------------------------;
GetCFGL1        call    SetupCFGBlock                  ; bx=CFG1,2,3,4 on entry
                call    SetPatch                       ; SplitPatch->CurrPatch
                call    DoAutoLoad                     ; Send CFGStr
                call    WriteStaticPS                  ; "C=1,2,3,4"
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
SendSplitStr    proc    near                       ;
;--------------------------------------------------;
                push    bx                         ;
                push    cx                         ;
                push    di                         ;
                push    si                         ;
                ;----------------------------------;
                call    GetSplitStr                ; [bx]->SplitCFGStr
                mov     si, bx                     ; source
                mov     di, offset(XBuff)          ; destination
                movw    [XBuffOut], 0000H          ; Start Xmit from XBuff+0
                ;----------------------------------;
                call    SetUpSplit                 ; [bx]->Split A,B,C,D,E,F
                mov     cl, +37[bx]                ; 0=OFF, 1-16=LENGTH=ON
                and     cx, 007FH                  ; If>127 then sub 128
                mov     [XBuffIn], cx              ; New In Ptr, could be=0
                jcxz    SSExit                     ; Nothing to send
                rep                                ;
                movsb                              ;
                ;----------------------------------;
                movb    [TxEnable], 02H            ; Enable XtraSend in MidiSend
                ;----------------------------------;
SSExit          pop     si                         ;
                pop     di                         ;
                pop     cx                         ;
                pop     bx                         ;
                ret                                ;
                endp                               ;
;--------------------------------------------------;
                ;--------------------------------------;
                ; Key 06: Store String values          ; For Current Split
                ;--------------------------------------;
L0:7:K06        push    bx                             ;
                push    cx                             ;
                ;--------------------------------------;
L07K06Loop1     call    Get2Dec                        ; Get Str Size 0-16
                cmp     al, 16                         ;
                ja      L07K06Loop1                    ; 
                call    SetUpSplit                     ; [bx]->Split A-F
                mov     +37[bx], al                    ; 0=OFF, 1-16=LENGTH=ON
                ;--------------------------------------;
                mov     cl, al                         ; Number of entries
                xor     ch, ch                         ;
                jcxz    L07K06Exit                     ; 0=Off
                ;--------------------------------------;
                call    GetYesNo                       ; Auto Load ?
                cmp     al, 00H                        ; 0=No ?
                je      L07K06Entries                  ; No autoload
                orb     +37[bx], 10000000B             ; Add 128 to LEN value
                ;--------------------------------------;
L07K06Entries   call    GetSplitStr                    ; [bx]->SplitCFGStr
L07K06Loop2     call    Get3Dec                        ;
                mov     [bx], al                       ; Store entry
                inc     bx                             ;
                call    Delay00                        ;
                loop    L07K06Loop2                    ;
                ;--------------------------------------;
L07K06Exit      pop     cx                             ;
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 02: Send SplitStrings            ; Current Split only
                ;--------------------------------------;
L0:7:K02        call    SendSplitStr                   ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 08: Get CFG 1,2,3,4: into A -F   ;
                ;--------------------------------------;
L0:7:K08        push    bx                             ;
                call    GetCFG1234                     ; Get GFGNumber: 1,2,3,4
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 07: Load CFG4                    ;
                ;--------------------------------------;
L0:7:K07        push    bx                             ;          
                call    GetCFG4                        ; Load CFG4
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 04: Load CFG3                    ;
                ;--------------------------------------;
L0:7:K04        push    bx                             ;         
                call    GetCFG3                        ; Load CFG3
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 01: Load CFG2                    ;
                ;--------------------------------------;
L0:7:K01        push    bx                             ; 
                call    GetCFG2                        ; Load CFG2
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 00: Load CFG1                    ;
                ;--------------------------------------;
L0:7:K00        push    bx                             ; 
                call    GetCFG1                        ; Load CFG1
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 05: Toggle Patch AutoLoad        ;
                ;--------------------------------------;
L0:7:K05        push    bx                             ;
                call    SetUpSplit                     ; Get Curr Split
                xorb    +38[bx], 10000000B             ; Current PatchNumber
                jns     L07NotAuto                     ; If<128 then Num+128
                movw    [Message], offset(EnableMess)  ;
                jmp     L07K05Exit                     ; 
L07NotAuto      movw    [Message], offset(DisableMess) ;
L07K05Exit      call    WriteStaticPS                  ;
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Key 09: Define SplitPoints           ;
                ;--------------------------------------;
L0:7:K09        push    bx                             ;
                movw    [Message], offset(SplitSMess)  ;
                call    WriteStatic                    ;
                movb    [KeyStore], 0FFH               ; Signal to store next
L07K09Loop1     cmpb    [KeyStore], 0FFH               ; Wait until Code stored
                nop
                je      L07K09Loop1                    ; 
                call    SetUpSplit                     ; Get curr Active Split
                mov     al, [KeyStore]                 ;
                cmpb    +11[bx], 00H                   ; Is split disabled ?
                je      L07K09NoEn                     ; Yes
                or      al, 80H                        ; Set D7=1 if Enabled
L07K09NoEn      mov     [bx], al                       ; SplitStart Start
                and     al, 7FH                        ; Clear D7=0
                ;--------------------------------------;
                movw    [Message], offset(SplitEMess)  ;
                call    WriteStatic                    ;
L07K09Loop2     cmp     [KeyStore], al                 ; Wait until Code stored
                nop
                je      L07K09Loop2                    ; 
                mov     al, [KeyStore]                 ;
                mov     +1[bx], al                     ; SplitStart End
                call    ClearDisp1To3                  ;
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:7:K15        ; Key 15: Get new Midi Channel         ;KEY ENTER
                ;--------------------------------------;
                push    bx                             ;
L07L1           call    Delay00                        ;
                call    Get2Dec                        ; Get Midi Channel 1-16
                dec     al                             ; Midi Channel 0-15
                cmp     al, 0FH                        ; > Channel 15 ?
                ja      L07L1                          ; Try again
                call    SetUpSplit                     ; Get curr Active Split
                mov     +10[bx], al                    ; Channel Number
                pop     bx                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:7:K03
L0:7:K10
L0:7:K11
L0:7:K12
L0:7:K13
ExitLev1:7      jmp     ExitKeyRoutine                 ;
;------------------------------------------------------;
Lev1:4          
;------------------------------------------------------;
;======================================;
; Level 1: Key 4 = Split Selections    ;
;======================================;
;  [7]           [8]           [9]     ; Enable: Toggle action => none,
; Split A      Split B       Split C   ; or any comb of A,B,C,D,E.  
; Current      Current       Current   ; 
;--------------------------------------;
;  [4]           [5]           [6]     ; Current: Exclusive action =>   
; Split D      Split E       Split F   ; Only one of A,B,C,D,E,F.
; Current      Current       Current   ; 
;--------------------------------------;
;  [1]           [2]           [3]     ;                         
; Enable       Enable        Enable    ;                                    
; Split A      Split B       Split C   ;                                     
;--------------------------------------;                                       
;  [0]         [ENTER]       [ESCAPE]  ; 
; Enable       Enable        Return to ; 
; Split D      Split E       Level 0   ; 
;======================================; 
;------------------------------------------------------;
Lev14ActSplit   proc    near                           ;
                push    ax                             ;
                push    bx                             ;
                mov     al, [Split]                    ; CurrS 0-5 = A-F
                mov     bx, offset(Seg7Tab)+10         ; +10 = A,B,C,D,E,F,...
                xlat                                   ; 0-5 = 'A'..'F'
                movw    [Message], offset(SplitMess1)  ; "S=A,b,C,d,E,F"
                call    WriteStatic                    ;
                mov     +4[bp], al                     ; [Disp3:0,1]="A-F"
                pop     bx                             ;
                pop     ax                             ;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
                ;--------------------------------------;
                ; Enable Splits A,B,C,D,E,F            ;KEYS 01,02,03,15,00
                ;--------------------------------------;
L0:4:K01        mov     bx, [SplitCFG:A]               ;
                jmp     L04Enable                      ;
                ;--------------------------------------;
L0:4:K02        mov     bx, [SplitCFG:B]               ;
                jmp     L04Enable                      ;
                ;--------------------------------------;
L0:4:K03        mov     bx, [SplitCFG:C]               ;
                jmp     L04Enable                      ;
                ;--------------------------------------;
L0:4:K00        mov     bx, [SplitCFG:D]               ;
                jmp     L04Enable                      ;
                ;--------------------------------------;
L0:4:K15        mov     bx, [SplitCFG:E]               ;
                jmp     L04Enable                      ;
                ;--------------------------------------;
L04Enable       xorb    +11[bx], 01H                   ; Split x (Un)Active
                xorb    [bx],  10000000B               ; SplitStrt D7=1,0
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Splits A,B,C,D,E,F Current           ;KEYS 04-09
                ;--------------------------------------;
L0:4:K07        movb    [Split], 00H                   ; Split A Current
                jmp     L04Current                     ;
                ;--------------------------------------;
L0:4:K08        movb    [Split], 01H                   ; Split B Current
                jmp     L04Current                     ;
                ;--------------------------------------;
L0:4:K09        movb    [Split], 02H                   ; Split C Current
                jmp     L04Current                     ;
                ;--------------------------------------;
L0:4:K04        movb    [Split], 03H                   ; Split D Current
                jmp     L04Current                     ;
                ;--------------------------------------;
L0:4:K05        movb    [Split], 04H                   ; Split E Current
                jmp     L04Current                     ;
                ;--------------------------------------;
L0:4:K06        movb    [Split], 05H                   ; Split F Current
                jmp     L04Current                     ;
                ;--------------------------------------;
L04Current      call    Lev14ActSplit                  ;                  
                call    SetPatch                       ; SplitPatch->CurrPatch
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:4:K10
L0:4:K11
L0:4:K12
L0:4:K13  
ExitLev1:4      jmp     ExitKeyRoutine                 ;
;------------------------------------------------------;
Lev1:2          
;------------------------------------------------------;
ExitLev1:2      jmp     ExitKeyRoutine                 ;
;========================================;
; Level 1: Key 2 = Wheels Configuration  ;
;========================================;
;  [7]             [8]             [9]   ; 
;                                        ;
;                                        ; 
;----------------------------------------;
;  [4]             [5]             [6]   ; Choose wheels 0-127 or 0-64 values.
; Select          Assign                 ; Range:0=0-64
;Wheels Range  Footswitches              ;       1=0-127
;----------------------------------------;       2=0-127 but half sensitivity
;  [1]             [2]             [3]   ;
;Assign Wheel Choose Wheel Disp Xlated or;
;to Routine    Disp Type   Raw Wheel val ;
;----------------------------------------;
;  [0]           [ENTER]        [ESCAPE] ; Wheels Number used in Options
;Get Wheels                    Return to ; [1],[2],[3],[4]. Option [1] also
;Number 1-4                     Level 0  ; use current active Split
;========================================;
                ;--------------------------------------;
                ; Get Wheels Number 1-4: (used as 0-3) ;
                ;--------------------------------------;
L0:2:K00        call    Get1Dec                        ; Get Wheels Number: 0-3
                dec     al                             ; 1-4 -> 0-3
                cmp     al, 03H                        ;
                ja      L0:2:K00                       ; Only 1-4 allowed
                mov     [WheelsNum], al                ; Wheels Number: 0-3 
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Get Wheels Assignment                ;
                ;--------------------------------------;
                ; 0: Deactivate Wheel in Split         ;
                ; 1: Controllers (2nd Number= Con No)  ; Bx
                ; 2: PitchBend                         ; Ex
                ; 3: Prog Change                       ; Cx
                ; 4: Channel Aftertouch                ; Dx
                ; 5: Note On                           ; 90
                ; 6: Note Off                          ; 80/90
                ; 7: Poly Aftertouch                   ; Ax
                ; Special (non std):                   ;
                ; 8: Volume control                    ; Via midi vert offset
                ; 9: Note On+Off                       ;
                ;10:                                   ;
                ;--------------------------------------;
WAssignAddr     DW offset(DoWNothing),    offset(DoWController)
                DW offset(DoWPitchBend),  offset(DoWProgChange)
                DW offset(DoWChPressure), offset(DoWNoteOn)
                DW offset(DoWNoteOff),    offset(DoWNothing)
                DW offset(DoWVolume),     offset(DoWNoteOnOff)
                DW offset(DoWNothing)
                ;--------------------------------------;
L0:2:K01        push    ax                             ;
                push    bx                             ;
                ;--------------------------------------;
L02K01L1        call    Get2Dec                        ; Wheels Assign No 1-10
                cmp     al, 0AH                        ;
                ja      L02K01L1                       ; Only 1-10 allowed
                push    ax                             ;
                ;--------------------------------------;
                mov     bx, ax                         ;
                xor     bh, bh                         ; bh=0
                shl     bl                             ; word offsets
                mov     ax, offset(WAssignAddr)[bx]    ; Routine addr
                call    SetUpSplit                     ; Get curr Active Split
                add     bx, [WheelsNum]                ; 3 byte offset
                add     bx, [WheelsNum]                ;
                add     bx, [WheelsNum]                ;
                mov     +16[bx], ax                    ; Wheels Addresses
                ;--------------------------------------;
                pop     ax                             ;
                cmp     al, 01H                        ; Controllers
                jne     L02K01Exit                     ; No, Done
L02K01Loop      call    Delay00                        ;
                call    Get3Dec                        ; Controller Number 0-127
                cmp     al, 7FH                        ;
                ja      L02K01Loop                     ;
                mov     +18[bx], al                    ; Controller Num
                ;--------------------------------------;
L02K01Exit      pop     bx                             ;
                pop     ax                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Get Wheels Display Type              ; 
                ; 0=No Display 1=Dec Num 2=Bar Display ;
                ;--------------------------------------;
WDispAddr       DW offset(WheelNoDisp),offset(WriteDec),offset(WriteWheel)
                ;--------------------------------------;
L0:2:K02        push    ax                             ;
                push    bx                             ;
L02K02L1        call    Get1Dec                        ; 
                cmp     al, 02H                        ;
                ja      L02K02L1                       ; Only 0,1,2 allowed
                ;--------------------------------------;
                mov     bx, offset(WDispAddr)          ; Disp Routines Addr
                xor     ah, ah                         ; ah=0    
                add     bx, ax                         ; word offsets
                add     bx, ax                         ;
                mov     ax, [bx]                       ; Routine addr
                call    GetWheelsCFG                   ; [bx]->WheelXCFG Block
                mov     +8[bx], ax                     ; Disp Addr->WheelsCFG
                pop     bx                             ;
                pop     ax                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
                ; Display Wheels Values                ;
                ;--------------------------------------;
L0:2:K03        incb    [DisplayWheels]                ; 0=Disable
                movb    [TempDisp], 10H                ; Active Temp Disp 
                cmpb    [DisplayWheels], 03H           ; 1=Raw Value
                jb      L02K03OK                       ; 2=Xlated Value
                movb    [DisplayWheels], 00H           ;
                movb    [TempDisp], 00H                ; No Temp Disp 
L02K03OK        call    ClearDisp1to4                  ; Clear Displays
                jmp     ExitKeyRoutine                 ;
                ;----------------------------------------;
                ; Key 04: Get Wheels Range: 0,1,2        ;
                ;----------------------------------------;
L0:2:K04        call    Get1Dec                          ; Get Range 0,1,2
                cmp     al, 02H                          ;
                ja      L0:2:K04                         ; Only 0,1,2 allowed
                call    GetWheelsCFG                     ; [bx]->WheelxCFG
                mov     +2[bx], al                       ; Range Value
                jmp     ExitKeyRoutine                   ;
                ;----------------------------------------;
                ; Get Footswitches Assignment            ;
                ;----------------------------------------;
                ; 0: Deactivate Footswitch               ;
                ; 1: Footswitches (2nd No=FootSW No)     ; Bx, 64-127, 0 or127
                ; 2: Predef PitchBend (2nd No=Bend Val)  ; Ex, 00, VAL
                ; 3: Predef Channel Pressure (2nd No=Val); Dx
                ; 4: Send Single Prog Change Value       ; Cx
                ; Special (non std):                     ;
                ; 5: Prog Change INCREMENT               ; Cx
                ; 6: Prog Change DECREMENT               ; Cx
                ; 7: Volume control INCREMENT            ; Via midi vert offset
                ; 8: Volume control DECREMENT            ; Via midi vert offset
                ; 9: Active split switch A->B->C->A      ;
                ;10: Octave Up                           ;
                ;10: Octave Down                         ;
                ;11: Transpose Up                        ;
                ;12: Transpose Down                      ;
                ;13: Switch to next SplitCFG             ;
                ;14: Switch KBrd Buttond to 2nd DEFINES  ;
                ;15:                                     ;
                ;16:                                     ;
                ;17:                                     ;
                ;18:                                     ;
                ;19:                                     ;
                ;----------------------------------------;
FSAssignAddr    DW offset(DoWNothing),    offset(DoFSController) ; 0,1
                DW offset(DoWPitchBend),  offset(DoWChPressure)  ; 2,3
                DW offset(DoWProgChange), offset(DoFSProgInc)    ; 4,5
                DW offset(DoFSProgDec),   offset(DoFSVolumeInc)  ; 6,7
                DW offset(DoFSVolumeDec), offset(OctaveUp)       ; 8,9
                DW offset(OctaveDown),    offset(XposeUp)        ; 10,11
                DW offset(XPoseDwn),      offset(DoWNothing)     ; 12,13
                DW offset(DoWNothing),    offset(DoWNothing)     ; 14,15
                DW offset(DoWNothing),    offset(DoWNothing)     ; 16,17
                DW offset(DoWNothing),    offset(DoWNothing)     ; 18,19
                ;------------------------------------------------;
L0:2:K05        push    ax                             ;
                push    bx                             ;
                push    si                             ;
                ;--------------------------------------;
                ; Get Footswitch Number 1,2,3          ;
                ;--------------------------------------;
L02K05Loop1     call    Get1Dec                        ; Get Footswitch No: 1,2
                dec     al                             ; 1-4 -> 0-3
                cmp     al, 01H                        ;
                ja      L02K05Loop1                    ; Only 1,2 allowed
                mov     [FootSwNum], al                ; FSwitch Number: 1-2 
                call    Delay00                        ;
                ;--------------------------------------;
                ; Get Assignment Number 0-19           ;
                ;--------------------------------------;
L02K05Loop2     call    Get2Dec                        ; FS Assign No 1-19
                cmp     al, 19                         ;
                ja      L02K05Loop2                    ; Only 1-19 allowed
                ;--------------------------------------;
                mov     si, offset(FSAssignAddr)       ; Routines Addresses
                xor     ah, ah                         ; ah=0    
                add     si, ax                         ; word offsets
                add     si, ax                         ;
                mov     si, [si]                       ; Routine addr
                call    SetUpSplit                     ; Get curr Active Split
                add     bx, [FootSwNum]                ; 3 byte offset
                add     bx, [FootSwNum]                ;
                add     bx, [FootSwNum]                ;
                mov     +28[bx], si                    ; FootSw Addresses
                ;--------------------------------------; Options 1-4 need 2nd No
                movb    +30[bx], 00H                   ; Prepare for +128 or 0
                dec     al                             ; Now Check 0-3
                jnz     L02K05NotCon                   ; Not Option 1
                movb    +30[bx], 80H                   ; Prepare for +128
L02K05NotCon    cmp     al, 03H                        ; Controllers etc ?
                ja      L02K05Exit                     ; No, Done
                ;--------------------------------------;
L02K05Loop3     call    Delay00                        ;
                call    Get3Dec                        ; Controller Number 0-127
                cmp     al, 7FH                        ;
                ja      L02K05Loop3                    ;
                add     +30[bx], al                    ; Contr Num = +0, +128
                ;--------------------------------------;
L02K05Exit      pop     si                             ;
                pop     bx                             ;
                pop     ax                             ;
                jmp     ExitKeyRoutine                 ;
                ;--------------------------------------;
L0:2:K06
L0:2:K07
L0:2:K08
L0:2:K09
L0:2:K10
L0:2:K11
L0:2:K12
L0:2:K13
L0:2:K15        jmp     ExitKeyRoutine                 ;
;------------------------------------------------------;
;------------------------------------------------------------;
; Do Custom Volume control via Vert Offs in SplitCFG's       ;
; Values: 0-63   = Neg offset: 0-63 -> (256-63)-(256-1)      ;
; Values: 65-127 = Pos offset: 65-127 -> 0-63                ;
;------------------------------------------------------------;
DoFSVolumeInc   proc    near                     ; 
                ;--------------------------------;
                incb   +13[bx]                   ; Split Vel Offset
                ret                              ;
                endp                             ;
                ;--------------------------------;
DoFSVolumeDec   proc    near                     ; 
                ;--------------------------------;
                decb   +13[bx]                   ; Split Vel Offset
                ret                              ;
                endp                             ;
;------------------------------------------------;
; Xmit FootSwitch Controller Values: B0-BF, 0,7F ; (B0-BF),(64-127),(0 or 127)
;------------------------------------------------; Operate on ACTIVE Split, not
DoFSController  proc    near                     ; all Enabled Splits.
                push    dx                       ;
                mov     dh, al                   ; al=Controller Number
                add     dh, 080H                 ; al>127=>al<128
                ;--------------------------------; 0-7F=0=Off, 80-FF=127=On
                cbw                              ; al<128=>ah=0, al>127=>ah=FF
                and     ax, 07F7FH               ; ah=0,127  al>127=>al=al-128 
                xchg    al, ah                   ; ah=Contr Num, al=0,127
                ;--------------------------------;
                mov     dl, 0B0H                 ; Controllers Code
                or      dl, +10[bx]              ; Active Split Channel Number
                ;--------------------------------;
                call    XmitMidi3                ; dl->ah->al
                ;--------------------------------;
                mov     al, dh                   ; Contr Num (+128) back
                pop     dx                       ;
                ret                              ;
                endp                             ;
;------------------------------------------------;
; INC-DEC KBrd Program Change Values: 01-7F      ; 
;------------------------------------------------; 
DoFSProgInc     proc    near                     ; 
                push    ax                       ;
                mov     al, [CurrPatch]          ;
                inc     al                       ;
                jmp     DoFSPID                  ;
                ;--------------------------------;
DoFSProgDec     proc    near                     ; 
                push    ax                       ;
                mov     al, [CurrPatch]          ;
                dec     al                       ;
                ;--------------------------------;
DoFSPID         and     al, 01111111B            ; Only 0-127 allowed
                mov     [CurrPatch], al          ;
                call    WriteDec                 ; Display Patch No
                ;--------------------------------;
                pop    ax                        ;
                ret                              ;
                endp                             ;
                endp                             ;
;------------------------------------------------;
;------------------------------------------------------;
Othertasks      proc    near                           ;
;------------------------------------------------------;
                ret                                    ;
                endp                                   ;
;------------------------------------------------------;
; Execute KeyBrd Button Pressed commands               ;
;------------------------------------------------------; [bx]->Seg7Tab+1,10
; Jmp here if Split Enable or SplitCFG pressed         ; [di]->TempCFG,TempSplit
;------------------------------------------------------; al=KbrdOption
DoEnableOrCFG   mov     [KbrdOption], al               ; 
                incb    [di]                           ;  
                cmp     [di], ah                       ; Max Value = ah=2,3 ?
                jbe     DoECL1                         ; No
                movb    [di], 00H                      ; 
DoECL1
                movw    [Message], offset(TempSCMess)  ; "E= "
                call    WriteStatic                    ; "E= A-F or 1-4"
                mov     al, [di]                       ; Tempx
                xlat                                   ; [bx]->Seg7Tab+x
                mov     +4[bp], al                     ; [Disp3:0,1]
                jmp     ExitKKeyRoutine                ; 
;------------------------------------------------------------;
; Jmp here if UP-DWN Arrow Pressed                           ;
;------------------------------------------------------------;
OctXpTab        DW      offset(OctaveDown), offset(OctaveUp) ; OctXp=0,2
                DW      offset(XposeDwn),   offset(XposeUp)  ; Up-Dwn=cl=0,1
SplitXTab       DW      0, 40, 80, 120, 160, 200             ; Split=A,B,C,D,E,F
SplitCFGTab     DW      offset(GetCFG1), offset(GetCFG2)     ; OctXp=0,2
                DW      offset(GetCFG3), offset(GetCFG4)     ;
KBIncDecAddr    DW      offset(KB0), offset(KB1), offset(KB2);
                DW      offset(KB3), offset(KB4), offset(KB0);
;------------------------------------------------------------;
KBIncDec        mov     bx, [KBrdOption]               ; Offset into Table
                shl     bx                             ; Word offset
                jmpn    offset(KBIncDecAddr)[bx]       ; Do Key x = KBx
                ;--------------------------------------;
                ; Enable-Disable Splits                ;
                ;--------------------------------------;
KB1             mov     di, [TempSplit]                ; di=0,1,2,3
                shl     di                             ; di=0,2,4,6
                and     di, 00FFH                      ; Remove 03 in Hi Byte
                mov     di, offset(SplitXTab)[di]      ; offset to SplitTab:X
                mov     bx, [SplitCFG:A]               ;
                mov     +11[bx+di], cl                 ; cl=0=Dis, cl=1=Enable
                andb    [bx+di], 01111111B             ; clear D7 SplitStart
                or      [bx+di], ch                    ; ch=00=Dis, ch=80=Enable
                jmp     ExitKKeyRoutine                ;
                ;--------------------------------------;
                ; Inc-Dec Patches                      ;
                ;--------------------------------------;
KB2             mov     al, [CurrPatch]                ;
                or      cl, cl                         ; Inc-Dec ?
                jz      KBDec                          ;
                inc     al                             ;
                jmp     KBL2                           ;
KBDec           dec     al                             ;
KBL2            and     al, 01111111B                  ; Only 0-127 allowed
                mov     [CurrPatch], al                ;
                call    WriteDec                       ; Display al=Patch No
                jmp     ExitKKeyRoutine                ;
                ;--------------------------------------;
                ; Octave + Xpose                       ;
                ;--------------------------------------;
KB3             mov     bx, [OctXpose]                 ; bx = 0 or 2
                add     bl, cl                         ; cl=0,1, bx=0,1,2,3
                shl     bx                             ; bx = 0,2,4,6
                mov     di, offset(OctXpTab)[bx]       ; Routine Addr
                call    DoXposeOct                     ;
                jmp     ExitKKeyRoutine                ;
                ;--------------------------------------;
                ; Load Split CFG 1,2,3,4               ;
                ;--------------------------------------;
KB4             mov     di, [TempCFG]                  ; di=0,1,2,3
                shl     di                             ; di=0,2,4,6
                and     di, 00FFH                      ; Remove 03 in Hi Byte
                calln   offset(SplitCFGTab)[di]        ; GetCFG1->GetCFG4
                ;--------------------------------------;
KB0             jmp     ExitKKeyRoutine                ;
;------------------------------------------------------;
;------------------------------------------------------------------------------;
;  KEYS: [6]=[INC]:    Increase, Enable or On                                  ;
;        [5]=[DEC]:    Decrease, Disable or Off                                ;
;      S [0]=[SPLIT]:  Select current active split: A,B,C,D,E,F: Run in 4 cycle;
;                      seq. Display "S=A,b,C,d,E,F". Split shown=active split  ;
;      E [1]=[ENABLE]: Enable the current active split=A,B,C,D,E,F by pressing ;
;                      [INC]=Enable, or [DEC]=Disable.                         ;
;      P [2]=[PATCH]:  Send program change selected by pressing the [INC-DEC]  ;
;                      keys (cycles 0-127) on the channel as for the current   ;
;                      active split. Send patch codes by pressing [PATCH]      ;
;                      again after selection of patch number 0-127.            ;
;      O [3]=[OCT-XP]: Octave or Xpose. Will cycle through 2 cycle Oct or Xps  ;
;                      seequence. [INC-DEC] keys will de-increase Oct or Xpose ;
;                      for the current active split.                           ;
;      C [4]=[CFG]:    Get Split CFG1,2,3,4. Will Cycle through 3 options and  ;
;                      if either Up-Dwn Key is pressed, will load new CFG.     ;
;------------------------------------------------------------------------------;
DoKButtonExit   proc    near                           ;
ExitDoKButton2  movb    [KButtonEnable], 01H           ; Re-enable
ExitDoKButton1  pop     bx                             ;
ExitDoKButton   ret                                    ;
DoKButton       proc    near                           ;
                ;--------------------------------------;
                ; Do Button Pressed                    ;
                ;--------------------------------------;
                shrb    [KButtonEnable]                ; D0=0,1 -> Carry
                jnc     ExitDoKButton                  ; Disabled, also set D0=0
                ;--------------------------------------;
                push    bx                             ;
                mov     bx, [KButtonPressed]           ; Offset into Table
                shl     bl                             ; Word offset
                jc      ExitDoKButton2                 ; if = FF Buttons unused
                ;--------------------------------------;
                push    ax                             ;
                push    cx                             ;
                push    di                             ;
                ;--------------------------------------;
                call    SetUpTempDisp                  ;
                ;--------------------------------------;
                ; Jump to key routine addresses        ;
                ;--------------------------------------;
                movb    [KBrdConnect], 05H             ; Temp Steady On
                jmpn    offset(KeyBrdKeyAddr)[bx]      ; Do Key xx = KB00-KB06
                ;--------------------------------------;
                ; Key 06: INC, ENABLE                  ;
                ;--------------------------------------;
KB06            mov     cx, 8001H                      ; INC Flag
                jmp     KBIncDec                       ;
                ;--------------------------------------;
                ; Key 05: DEC, DISABLE                 ;
                ;--------------------------------------;
KB05            mov     cx, 0000H                      ; DEC Flag
                jmp     KBIncDec                       ;
                ;--------------------------------------;
                ; Key 04: Select SplitCFG's 1,2,3,4    ;
                ;--------------------------------------;
KB04            mov     bx, offset(Seg7Tab)+1          ; +1 = 1,2,3,4
                mov     di, offset(TempCFG)            ;
                mov     ax, 0304H                      ; al=KBrdOption
                jmp     DoEnableOrCFG                  ; ah=Max Value
                ;--------------------------------------;
                ; Key 03: Octave-Xpose                 ;
                ;--------------------------------------;
KB03            movb    [KbrdOption], 03H              ; Shows Oct-Xpose
                xorb    [OctXpose], 02H                ; 0=Octave, 2=Xpose
                jnz     KB03XP                         ; Xpose mode
                movw    [Message], offset(KbOctMess)   ; "Oc " Octave On
                jmp     KB03L1                         ;
KB03XP          movw    [Message], offset(KbTposeMess) ; "Tp " Xpose On
                ;--------------------------------------;
KB03L1          call    WriteStatic                    ;
                jmp     ExitKKeyRoutine                ;
                ;--------------------------------------;
                ; Key 02: Select Patch: 0-127          ;
                ;--------------------------------------;
KB02            movb    [KbrdOption], 02H              ; Shows Patches
                cmpb    [Patch2ndTime], 01H            ;
                je      KB02ndTime                     ; 2nd KeyPress
                movb    [Patch2ndTime], 01H            ;
                movw    [Message], offset(KBPMess1)    ; "Pon" Patch On
                call    WriteStatic                    ;
                jmp     ExitKKeyRoutine                ;
KB02ndTime      ;--------------------------------------; Send patch displayed
                movb    [Patch2ndTime], 00H            ;
                movw    [Message], offset(KBPMess2)    ; "PSd" Patch Send
                call    WriteStatic                    ;
                mov     al, [CurrPatch]                ;
                call    DoPatchXmit2                   ;
                jmp     ExitKKeyRoutine                ;
                ;--------------------------------------;
                ; Key01: Cycle through 6 splits A-F    ;
                ;         En-Disable Displayed Split   ;
                ;--------------------------------------;
KB01            mov     bx, offset(Seg7Tab)+10         ; +10 = A,B,C,D,E,F
                mov     di, offset(TempSplit)          ;
                mov     ax, 0501H                      ; al=KBrdOption
                jmp     DoEnableOrCFG                  ; ah=Max Value
                ;--------------------------------------;
                ; Key 00: Activate Split A,B,C,D,E,F   ;
                ;--------------------------------------;
KB00            movb    [KbrdOption], 00H              ; Shows En-Disable Splits
                incb    [Split]                        ; 0 - 5 = Split A - F
                cmpb    [Split], 05H                   ; Only 0-5 allowed
                jbe     KB00L1                         ; OK
                movb    [Split], 00H                   ; Reset to 0
KB00L1          
                call    Lev14ActSplit                  ; Display "S=A,b,C,d,E,F"
                call    SetPatch                       ; Xfer Split to CurrPatch
                jmp     ExitKKeyRoutine                ; Done
;------------------------------------------------------;
ExitKKeyRoutine
                movb    [KButtonPressed], 0FFH         ;
                movb    [KButtonEnable], 01H           ; Enable Buttons
                call    SetUpExitDisp                  ; Set Temp Steady Attrib
                pop     di                             ;
                pop     cx                             ;
                pop     ax                             ;
                pop     bx                             ;
                ret
                endp
                endp                 
;----------------------------------------------;
; Read and Do Wheels Buttons                   ;
;----------------------------------------------;
ReadDoWButtons  proc    near                   ;
                call    ReadWButtons           ;
                call    DoWButtons             ; Active Split, not all enabled
                ret                            ; splits.
                endp                           ;
;----------------------------------------------;
DoWButtons      proc    near                   ;
;----------------------------------------------;
                push    ax                             ;
                push    bx                             ;
                ;--------------------------------------;
                ; Do Button Pressed                    ;
                ;--------------------------------------;
                shrb    [WButtonEnable]                ; carry=0=Disabled 
                jnc     ExitWB                         ; D0=0, and also set=0
                cmpb    [WButtonPressed], 0FFH         ; Buttons unused ?
                je      ExitWB                         ; Yes
                ;--------------------------------------;
                call    SetUpTempDisp                  ;
                call    SetUpSplit                     ;[bx]->SplitX
                ;--------------------------------------;
                ; Jump to key routine addresses        ; KEYS 01,02,04
                ;--------------------------------------;
                cmpb    [WButtonPressed], 02H          ;
                je      WKey02                         ;
                jb      WKey01                         ;
                ;--------------------------------------;
                ; Key 04:                              ; FOOTSWITCH 2 (=1)
                ;--------------------------------------;
WKey04          movb    +8[bp], Bar8                   ;
                mov     al, +33[bx]                    ; Controller Number
                calln   +31[bx]                        ; Assigned routine FS1
                mov     +33[bx], al                    ; Controller Number
                jmp     ExitWButton                    ;
                ;--------------------------------------;
                ; Key 02:                              ; FOOTSWITCH 1 (=0)
                ;--------------------------------------;
WKey02          movb    +8[bp], Bar8                   ;
                mov     al, +30[bx]                    ; Controller Number
                calln   +28[bx]                        ; Assigned routine FS1
                mov     +30[bx], al                    ; Controller Number
                jmp     ExitWButton                    ;
                ;--------------------------------------;
                ; Key 01:                              ; NOT HW ENABLED
                ;--------------------------------------; (no switch connected)
WKey01          movb    +4[bp], Three                  ; FOOTSWITCH 3 (=2)
                ;--------------------------------------;
ExitWButton     movb    [WButtonPressed], 0FFH         ;
                movb    [WButtonEnable], 01H           ; Enable Buttons
                call    SetUpExitDisp                  ; Set Temp Steady Attrib
ExitWB          pop     bx                             ;
                pop     ax                             ;
                ret
                endp
;------------------------------------------------------------------;
; Reset to default values                                          ;
;------------------------------------------------------------------;
VarVal                                                             ;
 DB 36        ; ScanToKey        100: Basic Correction 0 - 127     ;Byte
 DB 01H       ; MessEnable       101: Message Enable = 1           ;Byte
 DW offset(main) ; EscAddr       102: Address to jmp after Esc     ;
 DW 0007H     ; KBrdScanNum      104; Number of KBrdButtons        ;    
 DW 0003H     ; PowerLED         106; 1=Flash 0=Steady Power LED   ;
 DW 0001H     ; INTDone          108; Check INT finished complete  ;    
 DB 0FH,07FH  ; Seg7Times        110; Timer A,B constants:offtime  ;    
 DW 0002H     ; OctXpose         112; 0=Oct 1=Xpose                ;
 DW 007FH     ; ErrLEDOnTime     114; Error LED Temp time on       ;    
 DW 000FH     ; KBrdLEDOnTime    116; KeyBrd LED Temp time on      ;
 DW 001FH     ; Seg7Cnt          118; 7Seg Blink Time              ;    
 DW 000FH     ; ILEDCnt1         120; ILED Norm Blink Time         ;    
 DW 003FH     ; ILEDCnt2         122; ILED Slow Blink Time         ;    
 DW 0008H     ; ILEDOffTime      124; ILED Blink Off Cycle Start   ;    
 DW 00FFH     ; MenuTimer        126; Menu Disp Timer:255 Disable  ;    
 DB 00H       ; DTRStatus        128; DTR State 0=off 1=on         ;    
 DB 00000101B ;                  129; UART:D1=DTR 0=on 1=off       ;    
 DW offset(MidiBuff)  ; MidiIn   130: Buffer Input Ptr             ;    
 DW offset(MidiBuff)  ; MidiOut  132: Buffer Output Ptr            ;
 DW 000AH     ; ScrollTime       134; Time between scrolls         ;    
 DB 90H,00H   ; MidiNoteOff      136; NoteOff=80/90+VelFilt=0/7F   ;
 DW 0FFFFH    ;                  138; Unused                       ;
;------------------------------------------------------------------;
CFGVar
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ; UNUSED         2                                   ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 00H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWNothing)    ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 00H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoWNothing)    ; WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 00H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWNothing)    ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 00H   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoWNothing)    ; WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 00H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------------;
; 0340-037F: Wheels Configuration (64 bytes:16 bytes per wheel)      ;832
WheelsVar
 DB 00H   ; Wheel0Change  832       ; 0=No Change, 1=Change          ;+0
 DB 01H   ; Wheel0Type    833       ; Type 0=-Mid+, 1=0->Max         ;+1
 DB 01H   ; Wheel0R       834       ; 1=0-127 or 0=0-255             ;+2
 DB 03H   ; Wheel0Val     835       ; Last Raw Value                 ;+3
 DB 00H   ; Wheel0Value   836       ; Last Xlated Value 0-127,255    ;+4 
 DB 7FH   ; Wheel0Max     837       ; Max Pos                        ;+5
 DB 03H   ; Wheel0Min     838       ; Min Pos                        ;+6
 DB 03H   ; Wheel0Rst     839       ; Rest Pos                       ;+7
 DW offset(WriteWheel)    ; Wheel0Disp 840 ; Display Address         ;+8 +9
 DB 00H   ;               842       ;                                ;+10
 DB 00H   ;               843       ;                                ;+11
 DW 0000H ;               844       ;                                ;+12
 DB 00H   ;               846       ;                                ;+14
 DB 00H   ;               847       ;                                ;+15
;--------------------------------------------------------------------;
ResetVal                                                             ;
 DB   96,0,  96/2, 0            ; SplitCFG Str         96-192  ( 96) ;
 DB  192,2, 128/2, 0            ; Display Areas       704-831  (128) ;
 DB    0,2, 100/2, 0            ; 0 value variables   512-611  (100) ;
 DB    0,4, 128/2, 0            ; KeyStates=0 value  1024-1151 (128) ;
 DB    0,5,  32/2, 0            ; ButtonsStates=0    1280-1311 ( 32) ;
 DB   22,0,  42/2, 0            ; ROM 0 value Vars     20-63   ( 44) ;
 DB  128,4, 128/2, 7FH          ; KeyVelocity=7F     1152-1279 (128) ;
 DB  128,3, 128/2, 40H          ; Custom Vel=40       896-1023 (128) ;
 DB  240,0,   8/2, 01H          ; Wheels Buttons      240-247  (  8) ;
 ;------------------------------;
 DB  100,2,  40/2, 1 
 DW  offset(VarVal)             ; Other value vars    612-651  ( 40) ;
 DB   64,0,  32/2, 1 
 DW  offset(ROMVarAddr)         ; ROM othervalue Vars  64-95   ( 32) ;
 DB    0,8,  40/2, 24
 DW  offset(CFGVar)             ; Split CFG:A-F Addr 2048-3007 ( 40) ;
 DB   64,3,  16/2, 4
 DW  offset(WheelsVar)          ; Wheel0 Addr         832-847  ( 16) ;
 DB   96,5,  32/2, 10
 DW  offset(PatchVal)           ; Patch Blocks       1376-1695 (320) ;
;--------------------------------------------------------------------;
;----------------------------------------------;
DoCFGValReset   proc    near                   ;
;----------------------------------------------;
                mov     si, offset(CFG1)       ; destination=CFG A1
                mov     cx, 0004H              ; 4 CFG Areas 1,2,3,4
                ;------------------------------;
DoCFGValLoop    movb    [si],     80H          ; Enable A1
                movb    +11[si],  01H          ; Enable=01
                movb    +50[si],  01H          ; Channel=01 
                movb    +90[si],  02H          ; Channel=02
                movb    +130[si], 03H          ; Channel=03
                movb    +170[si], 04H          ; Channel=04
                movb    +210[si], 05H          ; Channel=05
                add     si, 240                ; next area
                loop    DoCFGValLoop           ; 
                ;------------------------------; si=source=CFG1
                ret                            ;
                endp                           ;
;------------------------------------------------;
DoWheelsReset   proc    near                     ;
;------------------------------------------------;
                mov     si, offset(WheelsCFG)    ; destination=Wheel0 CFG Area
                movw    +8[si], offset(WriteDec) ; Wheel0: Display Type
                movb    +33[si],  00H            ; Wheel2: Middle Type Wheel
                movw    +35[si],  404FH          ; Wheel2: +3=4FH, +4=40H
                movb    +39[si],  4FH            ; Wheel2:
                ret                              ;
                endp                             ;
;------------------------------------------------;
ResetDef        proc   near                      ;
;------------------------------------------------;
                push    ax                     ;
                push    bx                     ;
                push    cx                     ;
                push    di                     ;
                push    si                     ;
                cld                            ; clear DF: i.e. INC DI,SI
                mov     bx, offset(ResetVal)   ; di, cx, (ax,si) values
                ;------------------------------;
                ; Reset one value areas        ;
                ;------------------------------;
                mov     cx, 9                  ;
ResetLoop1      call    DoOneValReset          ;
                loop    ResetLoop1             ;
                ;------------------------------; 
                ; Reset mixed value areas      ;
                ;------------------------------;
                mov     cx, 5                  ;
ResetLoop2      call    DoMixValReset          ;
                loop    ResetLoop2             ;
                ;------------------------------;
                call    DoCFGValReset          ; SplitCFG1,2,3,4=A1-4-F1-4
                call    DoWheelsReset          ; Wheels 0,1,2,3 CFG
                call    RomGoRAM               ; Set Ram variables
                ;------------------------------;
                ; Initialise KeyOffSet         ;
                ; Initialise Velocity Tables   ;
                ;------------------------------;
                movb    [ResetDefault], 00H    ; Cancel
                call    CalcKeyOffSet          ; KeyOffSet=Xpose+Octave+ScToKey
                call    SetVelTable            ; Fill VelTab with current addr
                call    SetLevel0              ; [bp]->DispArea
                ;------------------------------;
                pop     si                     ;
                pop     di                     ;
                pop     cx                     ;
                pop     bx                     ;
                pop     ax                     ;
                ret                            ;
                endp                           ;
;----------------------------------------------;
;---------------------------------------------------------------; 
; CommandMode: 0=Unactive                                       ;
;              1=F0 received, busy receiving until F7           ;
;              2=F7 received, but not command not yet processed ;
;---------------------------------------------------------------; 
ReceiveMidi     proc    near                                    ; 
;---------------------------------------------------------------;
                push    ax                             ; 
                mov     ax, 0200H                      ; al=0, ah=2
                ;--------------------------------------;
                cmp     [RxEnable], al                 ; al=0, receive disabled?
                je      NoRx1                          ; Yes
                test    [UARTStatus], ah               ; ah=2, AND RxRdy Bit D1
                jz      NoRx1                          ; Receiver not ready D1=0
                cmp     [CommandMode], ah              ; Still to be processed ?
                je      NoRx1                          ; Yes
                ;--------------------------------------; 
                push    bx                             ; 
                push    di                             ; 
                ;--------------------------------------;
                xor     bx, bx                         ; bx=0
                dec     ah                             ; ah=1
                ;--------------------------------------; 
                ; Read  Byte                           ; 
                ;--------------------------------------;
                mov     al, [UARTData]                 ; Read Midi Byte
                cmp     al, 0F0H                       ; SysExStart ?
                je      SysExStart                     ; Yes
                cmp     [CommandMode], ah              ; ah=1, command1 mode ?
                jne     NotValid                       ; Not valid seq    
                cmp     al, 0F7H                       ; SysExEnd ?
                je      SysExEnd                       ; Yes
                cmp     al, 080H                       ; Data codes al=0-127 ?
                jb      StoreCode                      ; Yes
                jae     NotValid                       ; Else 80-EF,F1-F6,F8-FF
                ;--------------------------------------;
SysExStart      mov     [CommandMode], ah              ; ah=1, Command=1 active
                mov     [TaskBusy], ah                 ; No tasks while receive
                mov     [KeyScanEnable], bl            ; bl=0, disable KeyScan
                mov     [RxIn], bx                     ; Rec End Ptr = 0
                mov     [RxOut], bx                    ; Rec Start Ptr = 0
                jmp     StoreCode                      ; al=F0
                ;--------------------------------------;
SysExEnd        mov     [TaskBusy], bl                 ; bl=0, tasks active
                movb    [CommandMode], 02H             ; Command=2 mode 
                mov     [KeyScanEnable], ah            ; ah=1, enable KeyScan
                ;--------------------------------------;
                ; Store Byte                           ;
                ;--------------------------------------;
StoreCode       mov     di, [RxIn]                     ; Receiver In Ptr
                mov     bx, [RxBuffer]                 ; offset(Buffer Used)
                mov     [bx+di], al                    ; Store Byte in Buff
                inc     di                             ; Next Position
                cmp     di, [RxBufferMax]              ; Buffer Full ?
                ja      NotValid                       ; Yes, reset
                mov     [RxIn], di                     ; Receiver In Ptr
                ;--------------------------------------; points to next pos.
NoRx            pop     di                             ;
                pop     bx                             ;
NoRx1           pop     ax                             ;
                ret                                    ;
                ;--------------------------------------;
NotValid        movb    [CommandMode], 00H             ; Command unactive
                movb    [TaskBusy], 00H                ; Tasks active
                mov     [KeyScanEnable], ah            ; ah=1, enable KeyScan
                jmp     NoRx                           ; done
                endp                                   ;
;------------------------------------------------------;
EndCode                                        ;
;----------------------------------------------;

