;----------------------------------------------------------------;
; 8088 CPU keyboard                                              ;
; 8088RAM.1                                                      ;
;----------------------------------------------------------------;
; Create file 8088.ASM by:                                       ;
; COPY 8088RAM.1 + 8088RAM.2 + 8088ROM1 + 8088ROM2  8088.ASM     ;
;----------------------------------------------------------------;
BlockSize       equ    8192      ;
                ORG    0000H     ; SET PROGRAM COUNTER = 0000H
;----------------------------------------------;
; Blocks selected (74138) on A13,A14,A15(+DEN) ;
;----------------------------------------------;
Block0          equ    0000H                   ; 0000H     0 RAM+OS (8k)
Block1          equ    Block0+BlockSize        ; 2000H  8192 BUTTONS
Block2          equ    Block1+BlockSize        ; 4000H 16384 UNUSED
Block3          equ    Block2+BlockSize        ; 6000H 24576 WHEELS       
Block4          equ    Block3+BlockSize        ; 8000H 32768 DISPLAY+KEYS
Block5          equ    Block4+BlockSize        ; A000H 40960 KEYBOARD
Block6          equ    Block5+BlockSize        ; C000H 49152 UART
Block7          equ    Block6+BlockSize        ; E000H 57344 ROM+BIOS (8k)
;----------------------------------------------;
ResetAddres     equ    0FFF0H           ; reset start in ROM
ResetSegment    equ    0F000H           ;
ResetOffset     equ    0FH              ; reset starts 16 bytes below RomTop

RomSize         equ    BlockSize        ;
RomStart        equ    0FFFFH-RomSize   ; start  of rom
RomSegment      equ    0F000H           ;

NMIVectorLo     equ    0008H              ; NMI INT2
NMIVectorHi     equ    000AH              ;
OVVectorLo      equ    0010H              ; OVERFLOW INT4
OVVectorHi      equ    0012H              ;
DIV0VectorLo    equ    0000H              ; DIV0 INT0
DIV0VectorHi    equ    0002H              ;
;-----------------------------------------;
RamSize         equ    BlockSize/1        ; 8k 6264: 6116=2k would be /4
RamStart        equ    00000H             ; start  of rom
RamTop          equ    RamStart+RamSize-1 ; Top of Ram, Top of stack = 8191
RamSegment      equ    00000H             ;
;-----------------------------------------;
UARTData        equ    Block6+0   ; A0=0 UART Data register Read/Write
UARTControl     equ    Block6+1   ; A0=1 UART Comm register Write Only
UARTStatus      equ    Block6+1   ; A0=1 UART Stat register Read Only
UARTMode        equ    01001110B  ; 1 stop, no parity, 8 data, x16
UARTReset       equ    01000000B  ; Internal reset before MODE set
UARTCommand1    equ    00000001B  ; Xmitter Enable
UARTCommand2    equ    00000101B  ; Xmit + Receive + DTR output lo
UARTCommand3    equ    00000111B  ; Xmit + Receive + DTR output hi
UARTCommand4    equ    00110111B  ; Xmit + Receive enable, reset error
                                  ; Turn on(lo) RTS, DTR outputs
UARTCommand5    equ    00010101B  ; Xmit + Receive enable, reset error
;-----------------------------------------;
KeyBrd          equ    Block5             ; Keyboard Read Port A000H
K0              equ    Block5+0           ; KeyBoard Key0 A000H
K1              equ    Block5+1           ; KeyBoard Key1 A001H
K2              equ    Block5+2           ; KeyBoard Key2 A002H
;-----------------------------------------;
Disp2           equ    Block4+0           ; Display 1: 7SEG+DOT middle 8000H
Disp3           equ    Block4+1           ; Display 3: 7SEG+DOT right  8001H
BARLED          equ    Block4+2           ; Display 2: 8 LED BAR       8002H
Disp1           equ    Block4+3           ; Display 4: 7SEG+DOT left   8003H
ILED            equ    Block4+4           ; Display 5: INDIV LED's     8004H
;-----------------------------------------;
Buttons         equ    Block1             ; Program Keys               2000H
;-----------------------------------------;
Wheels          equ    Block3             ; Pots                       6000H
;------------------------------------------------------------------;
; MEMORY MAP                                                       ;
;------------------------------------------------------------------;
; 1F00-1FFF: RAMTOP = STACKTOP (6264 8Kb)                          ;
; 1000-1F00: RAM BIOS = 4096-64 bytes                              ;
;-------------------------------------4th 1024---------------------;
; 0C00-0FFF: RECEIVE BUFFER = 1024 bytes                           ;
;          : Extra Midi Buffer: Special Transmit (1024 bytes)      ;3072
;-------------------------------------3rd 1024---------------------------;
; 0BC0-0BFF: 64 Available                                                ;3008
; 0AD0-0BBF: CFG Block 4: Splits A4 - F4 240 bytes                       ;2768
; 09E0-0ACF: CFG Block 3: Splits A3 - F3 240 bytes                       ;2528
; 08F0-09DF: CFG Block 2: Splits A2 - F2 240 bytes                       ;2288
; 0800-08EF: CFG Block 1: Splits A1 - F1 240 bytes                       ;2048
;-------------------------------------2nd 1024---------------------------;
; 07F4-07FF: Keyboard Buttons State (12 bytes:only 7 keys:0-6 used)      ;2036 
; 07E0-07F3: Addresses of each block below (20 bytes)                    ;2016
; 07C0-07DF: Level 1 Check Key 09 (Patch Xmit) Key xx Address (32 bytes) ;1984
; 07A0-07BF: Level 1 Check Key 08                                        ;1952
; 0780-079F: Level 1 Check Key 07                                        ;1920
; 0760-077F: Level 1 Check Key 06                                        ;1888 
; 0740-075F: Level 1 Check Key 05                                        ;1856
; 0720-073F: Level 1 Check Key 04                                        ;1824
; 0700-071F: Level 1 Check Key 03                                        ;1792
; 06E0-06FF: Level 1 Check Key 02                                        ;1760
; 06C0-06DF: Level 1 Check Key 01 (Patch Xmit) Key xx Address (32 bytes) ;1728
; 06A0-06BF: Level 1 Check Key 00 (Debug) Key xx Address (32 bytes)      ;1696
; 0560-059F: Patch Xmit define: Key 0-9 -> patch 0-127 (320 bytes)       ;1376
; 0540-055F: Level 0 Check Key xx Address (32 bytes)                     ;1344
; 0520-053F: Task Addresses (32 bytes)                                   ;1312
; 0500-051F: Buttons State (32 bytes)                                    ;1280
; 0480-04FF: Key Velocities (128 bytes)                                  ;1152
; 0400-047F: Key States (128 bytes)                                      ;0
;-------------------------------------1st 1024---------------------------;
; 0380-03FF: Custom Velocity Table (128 bytes)                     ;896 *
; 0340-037F: Wheels Configuration (64 bytes:16 bytes per wheel)    ;832
; 0300-033F: Display Area (768-831: 64 bytes)                      ;768
; 02C0-02FF: Display Area Image Save (During Temp) (64 bytes)      ;704
; 0200-02BF: Variables 192 bytes allocated: 512-703                ;512
; 0100-01FF: Midi Codes Buffer (256 bytes)                         ;256
; 00F8-00FF: 8 Available                                           ;248
; 00F0-00F7: Wheels Buttons State (8 bytes, only 4 used)           ;240 *
; 00E0-00EF: KeyBoard Buttons Addresses (16 bytes,14 used=7 Addr)  ;224 *
; 00C0-00DF: 32 Available                                          ;191-223
; 0060-00BF: SplitCFG Pre-initialise Strings:16*6=96 bytes         ;96-191
; 0014-005F: 76 bytes for special BIOS Load variables              ;20-95
;------------------------------------------------------------------;
; 0010-0013: INTOVFL                                               ;16-19
; 000C-000F: 4 bytes available                                     ;12
; 0008-000B: INTNMI (used)                                         ;8-11
; 0004-0007: 4 bytes available                                     ;4
; 0000-0003: INTDIV0                                               ;0-3
;------------------------------------------------------------------;
; Variables Block 1                                                ;
;------------------------------------------------------------------;
; 0014-005F: 76 bytes for special and BIOS load affected variables ;20-95
; BIOS Load will only start loading from after these variables     ;
; .x shows coupling i.e. keep in same sequence                     ;
;------------------------------------------------------------------;0 val vars
PermINT        equ   20 ; 01 = Enable Permanent INT    ;Byte       *
TaskTest       equ   21 ; Debug:Idle Time              ;Byte.1 
TaskNumber     equ   22 ; Task 0,2,4,6,..,8,A,C,..,1E  ;Byte.2
TaskBusy       equ   23 ; 1=Task busy 0=Next Task      ;Byte.3
GoRAMBIOS      equ   24 ; 1=Enable JMP to RAM Bios     ;Byte       *
ResetDefault   equ   25 ; Reset to default values if=1 ;Byte       *
FilterEnable   equ   26 ; Receiver Timing Filter Enable;    
WheelsEnable   equ   28 ; 1=Enable Wheels              ;
U4             equ   30 ;                              ;UNUSED
U5             equ   32 ;                              ;UNUSED
XBuffIn        equ   34 ; Extra Xmission Buffer Input  ;    
XBuffOut       equ   36 ; Extra Xmission Buffer OutPut ;
Timer0         equ   38 ; General Timer: 2 ms INT inc  ;    
Timer1         equ   40 ; General Timer: 2 ms INT inc  ;
KeyStore       equ   42 ; Last Note Stored             ;     
Split          equ   44 ; Current Split 0=A B=1 C=2    ;
TempDisp       equ   46 ; Flag Temp Disp Active=0,1,2  ;    
Level01        equ   48 ; Buttons Level 0 (Top) or 1   ;
Level0Task     equ   50 ; Level0 Current Task          ;    
Level0Addr     equ   52 ; Addr of Curr Lev 0 Task Table;
U2             equ   54 ;                              ;UNUSED
RxIn           equ   56 ; Receive input Ptr            ;
RxOut          equ   58 ; Receive output Ptr           ;    
RxEnable       equ   60 ; Receive: 1=Enable 0=Disable  ;
ILEDState      equ   62 ; Current state of Indiv LEDs  ;    
;------------------------------------------------------;mixed val vars
KeyScanEnable  equ   64 ; Keyboard Scan: 1=Enable      ;
ButtonEnable   equ   66 ; Buttons Enable = 01          ;     
WButtonEnable  equ   68 ; Wheels Buttons Enable=01     ;
KButtonEnable  equ   70 ; Keyboard Buttons Enable=01   ;    
TxEnable       equ   72 ; Xmitter: 1,2=Enable 0=Disable;    
ButtonPressed  equ   74 ; Number 0-31 of pressed PKey  ;     
KButtonPressed equ   76 ; No 0-4 of pressed KbrdKey    ;    
WButtonPressed equ   78 ; No 1,2,4: pressed WheelsKey  ;
RxBufferMax    equ   80 ; Receiver Max BuffSize=RxEnd  ;    
RxBuffer       equ   82 ; Addr Receive BuffStart=RxBuff;
SplitCFG:A     equ   84 ; Ptr to curr Split A          ;Word.1
SplitCFG:B     equ   86 ; Ptr to curr Split B          ;Word.2
SplitCFG:C     equ   88 ; Ptr to curr Split C          ;Word.3     
SplitCFG:D     equ   90 ; Ptr to curr Split D          ;Word.4
SplitCFG:E     equ   92 ; Ptr to curr Split E          ;Word.5
SplitCFG:F     equ   94 ; Ptr to curr Split F          ;Word.6
;--------------------------------------------------------------------;
VarBlock       equ    Block0+512      ; Start of Variables storage   ;
;--------------------------------------------------------------------;
; Variables Block 2                                                  ;
;--------------------------------------------------------------------;
; 0200-02BF: Variables 192 bytes allocated: 512-703                  ;512
;--------------------------------------------------------------------;
U1                equ VarBlock+00 ; Unused                       ;Byte
Escape            equ VarBlock+01 ; 1=Escape Key pressed         ;Byte
CurrPatch         equ VarBlock+02 ; Current patch No 0-127       ;Byte
PredefPatch       equ VarBlock+03 ; Predef patch No 0-9          ;Byte
Wheel0            equ VarBlock+04 ; Value of Wheel 0             ;Byte
Wheel1            equ VarBlock+05 ; Value of Wheel 1             ;Byte
Wheel2            equ VarBlock+06 ; Value of Wheel 2             ;Byte
Wheel3            equ VarBlock+07 ; Value of Wheel 3             ;Byte
WButtons          equ VarBlock+08 ; Buttons on Wheels            ;Byte
PPatch            equ VarBlock+09 ; Patch No 0-127               ;Byte
Bit7Enable        equ VarBlock+10 ; 01=Enable 7Bit Xmitter       ;Byte
HeaderEnable      equ VarBlock+11 ; 01=Add SysEx Header          ;Byte
Error             equ VarBlock+12 ; GP Error Flag                ;
Message           equ VarBlock+14 ; Message Start Address        ;    
MessageEnd        equ VarBlock+16 ; Message End Address          ;
MessTimer         equ VarBlock+18 ; Message Timer                ;
IdleTimer         equ VarBlock+20 ; Debug:how long not NMI       ;Byte.1
TaskTime          equ VarBlock+21 ; Debug: Lowest Idle Count     ;Byte.2    
BinCount          equ VarBlock+22 ; Debug:Counter if Key 02 press;    
DelayTimer        equ VarBlock+24 ; proc Delay1 Timer            ;
CounterDec        equ VarBlock+26 ;                              ;    
CounterHex        equ VarBlock+28 ;                              ;
Number1s          equ VarBlock+30 ; Get3Digit variables          ;    
Number10s         equ VarBlock+32 ;                              ;     
Number100s        equ VarBlock+34 ;                              ;
Number            equ VarBlock+36 ;                              ;    
PKey              equ VarBlock+38 ; PatchXmit: Key 0-9           ;
PChannel          equ VarBlock+40 ;            Channel 0-15      ;     
Response          equ VarBlock+42 ; 0=NoResponse 1=Press Button  ;
WheelsNum         equ VarBlock+44 ; Wheels Number 0-3            ;    
WheelsMax         equ VarBlock+46 ; Wheels Max Position          ;
WheelsMin         equ VarBlock+48 ; Wheels Min Position          ;    
WheelsRst         equ VarBlock+50 ; Wheels Rest Position         ;
WheelsType        equ VarBlock+52 ; Wheels Type 0,1              ;    
KBrdConnect       equ VarBlock+54 ; 1=Flash 0=Steady Kbrd LED    ;
DisplayWheels     equ VarBlock+56 ; Enable Wheels Display if 1   ;    
Patch2ndTime      equ VarBlock+58 ; KbrdButton Patches 2x press  ;
KBrdOption        equ VarBlock+60 ; KeyButton 0-6                ;    
TempSplit         equ VarBlock+62 ; Enable-Disable split         ;
TempCFG           equ VarBlock+64 ; Enable CFG1,2,3              ;    
FootSWNum         equ VarBlock+66 ; Footswitch No 0, 1           ;
WheelsVar1        equ VarBlock+68 ; Temp storage for DoWheels    ;     
WheelsVar2        equ VarBlock+70 ; Temp storage for DoWheels    ;
GlobalOctXp       equ VarBlock+72 ; 1=Global,0=Single OctaveXpose;    
CommandMode       equ VarBlock+74 ; Commands Receive Mode:=01    ;    
CommandNo         equ VarBlock+76 ; Received Command Number      ;    
DataLength        equ VarBlock+78 ; Length of Data in Command    ;    
;----------------------------------------------------------------;
ScanToKey         equ VarBlock+100; Basic Correction 0 - 127     ;Byte
MessEnable        equ VarBlock+101; Message Enable = 1           ;Byte
U3                equ VarBlock+102;                              ;UNUSED
KBrdScanNum       equ VarBlock+104; Number of KBrdButtons        ;    
PowerLED          equ VarBlock+106; 1=Flash 0=Steady Power LED   ;
INTDone           equ VarBlock+108; Check INT finished complete  ;    
Seg7Times         equ VarBlock+110; Timer A,B constants:offtime  ;    
OctXpose          equ VarBlock+112; 0=Oct 1=Xpose                ;
ErrLEDOnTime      equ VarBlock+114; Error LED Temp time on       ;    
KBrdLEDOnTime     equ VarBlock+116; KeyBrd LED Temp time on      ;
Seg7Cnt           equ VarBlock+118; 7Seg Blink Time              ;    
ILEDCnt1          equ VarBlock+120; ILED Norm Blink Time         ;    
ILEDCnt2          equ VarBlock+122; ILED Slow Blink Time         ;    
ILEDOffTime       equ VarBlock+124; ILED Blink Off Cycle Start   ;    
MenuTimer         equ VarBlock+126; Menu Disp Timer:255 Disable  ;    
DTRStatus         equ VarBlock+128; DTR State 0=off 1=on         ;    
                                  ; UART:D1=DTR 0=on 1=off       ;    
MidiIn            equ VarBlock+130; Buffer Input Ptr             ;    
MidiOut           equ VarBlock+132; Buffer Output Ptr            ;
ScrollTime        equ VarBlock+134; Time between scrolls         ;    
MidiNoteOff       equ VarBlock+136; NoteOff=80/90+VelFilt=0/7F   ;
U6                equ VarBlock+138;                              ;UNUSED
;------------------------------------------------------------------;
; Split CFG Blocks: Each 40 bytes                                  ;
;------------------------------------------------------------------;
SplitPosS:X     equ      0    ; SplitPoint Start 0-127 Notes       ;+0
                              ; D7=0,1 if Split=Dis,Enabled        ;
SplitPosE:X     equ      1    ; SplitPoint End   0-127 Notes       ;+1
U:X             equ      2    ; Unused                             ;+2  Word
VelTab:X        equ      4    ; Current Vel Table Address          ;+4  Word
Octave:X        equ      6    ; Octave: -36,24,..,0,+12,+24,+36    ;+6
Oct:X           equ      7    ; Octave: 0=0, +-12=1 +-24=2 +-36=3  ;+7
XPose:X         equ      8    ; Transpose +-0,+-1,+-2 to +-12      ;+8
KeyOffSet:X     equ      9    ; Total of Octave, Xpose, Basic Offs ;+9
Channel:X       equ     10    ; SplitA Midi Channel 0-15           ;+10
Enable:X        equ     11    ; 1=Enable Split A: 0=Disable        ;+11
VelInv:X        equ     12    ; 0=Normal Vel Tabel 11=Inverse Value;+12  
VelOffsV:X      equ     13    ; Vel Offset Vertical: 0-127         ;+13
VelConst:X      equ     14    ; Const Vel Value: 64 default FF=off ;+14
VelMode:X       equ     15    ; Vel Mode: 0,1-9,10                 ;+15
Wheel0Addr:X    equ     16    ; Wheel0 Routine Addr: 0000=Off      ;+16 Word
Wheel0Num:X     equ     18    ; Wheel0 Controller Number: 0-127    ;+18
Wheel1Addr:X    equ     19    ; Wheel1 Routine Addr: 0000=Off      ;+19 Word
Wheel1Num:X     equ     21    ; Wheel1 Controller Number: 0-127    ;+21
Wheel2Addr:X    equ     22    ; Wheel2 Routine Addr: 0000=Off      ;+22 Word
Wheel2Num:X     equ     24    ; Wheel2 Controller Number: 0-127    ;+24
Wheel3Addr:X    equ     25    ; Wheel3 Routine Addr: 0000=Off      ;+25 Word
Wheel3Num:X     equ     27    ; Wheel3 Controller Number: 0-127    ;+27
WFoot0Addr:X    equ     28    ; Wheel0 Footsw Addr: 0000=Off       ;+28 Word
WFoot0Num:X     equ     30    ; Wheel0 Footsw Con Number: 0-127    ;+30
WFoot1Addr:X    equ     31    ; Wheel1 Footsw Addr: 0000=Off       ;+31 Word
WFoot1Num:X     equ     33    ; Wheel1 Footsw Con Number: 0-127    ;+33
WFoot2Addr:X    equ     34    ; Wheel2 Footsw Addr: 0000=Off       ;+34 Word
WFoot2Num:X     equ     36    ; Wheel2 Footsw Con Number: 0-127    ;+36
SplitStr1:X     equ     37    ; 32byte pre-init string: 0=Disable  ;+37
                              ; 1-32=len, 129-160=len-128=autoload ;
SplitPatch:X    equ     38    ; Patch displayed from ProgChange    ;+38
SplitAvail3:X   equ     39    ; Unused                             ;+39
;---------------------------------------------------------------------;
; Constants                                                           ;
;---------------------------------------------------------------------;
NoteOff         equ    080H               ; MIDI NOTE OFF             ;
NoteOn          equ    7F90H              ; MIDI NOTE ON + Vel Filter ;
MinVel          equ    0AH                ; 10= reset minimum velocity;
KeyScanNumber   equ    031H               ; No of Keys to Scan = 49   ;
ButtonsNumber   equ    010H               ; Number of Buttons         ;
RxEnd           equ    1024               ; Max Size of Receive Buffer;
BIOSEnd         equ    (2*4096)-96        ; Max Size of BIOS Buffer   ;
WheelsMaxCount  equ    0080H              ; Max Count for Wheels=128  ;
XBuffMax        equ    1024               ; Extra Xmission Buff Size  ;    
;---------------------------------------------------------------------;
WheelsCFG       equ    832               ; 64 bytes WheelsCFG         ;
;---------------------------------------------------------------------;
Wheel0Change    equ    832               ; 0=No Change, 1=Change      ;+0
Wheel0Type      equ    833               ; Type 0=-Mid+, 1=0->Max     ;+1
Wheel0Range     equ    834               ; 1=0-127 or 0=0-255         ;+2
Wheel0Val       equ    835               ; Last Raw Value             ;+3
Wheel0Value     equ    836               ; Last Xlated Value 0-127,255;+4 
Wheel0Max       equ    837               ; Max Pos                    ;+5
Wheel0Min       equ    838               ; Min Pos                    ;+6
Wheel0Rst       equ    839               ; Rest Pos                   ;+7
Wheel0Disp      equ    840               ; Display Type Address       ;+8,+9
Wheel0Sens      equ    842               ; Sensitivity: 0,1,2         ;+10,+11
;---------------------------------------------------------------------;
Wheel1Change    equ    849               ; Wheel 1:                   ;
;---------------------------------------------------------------------;
Wheel2Change    equ    865               ; Wheel 2:                   ;
;---------------------------------------------------------------------;
Wheel3Change    equ    881               ; Wheel 3:                   ;
;---------------------------------------------------------------------;
; KeyState must be kept on a 256 boundary to derive NOTE NUMBER       ;
; from it: 1024 = 400H => lo byte = key number 0-127                  ;
;---------------------------------------------------------------------;
SplitCFGStr     equ    96                ; Pre-init Strings:128 bytes ;
KeyBrdKeyAddr   equ    224               ; KeyBrd Buttons Addresses   ;
WButtonState    equ    240               ; 4 bytes WheelsButtons State;
MidiBuff        equ    256               ; 256 bytes xmit Midi codes  ;
WheelsCFGStart  equ    832               ; 64 bytes WheelsCFG         ;
RamVelTab       equ    896               ; 128 bytes custom Vel Table ;
KeyState        equ    1024              ; 128 bytes=keys state       ;
KeyVel          equ    1024+128          ; 128 bytes=keys velocity    ;
ButtonsState    equ    1024+256          ; 32  bytes Prog Keys state  ;
TaskAddress     equ    1280+32           ; Adresses of Tasks 0-1E     ;
KeyAddrLev0     equ    1280+64           ; Table Level 0 Key xx Addr  ;
PatchXmit       equ    1280+96           ; Table of Patch definitions ;
KeyAddrLev1:0   equ    1280+96+320       ; Table Level 1 Key 00 Addr  ;
KeyAddrLev1:1   equ    1280+96+320+32    ; Table Level 1 Key 01 Addr  ;
KeyAddrLev1:2   equ    1280+96+320+64    ; Table Level 1 Key 02 Addr  ;
KeyAddrLev1:3   equ    1280+96+320+96    ; Table Level 1 Key 03 Addr  ;
KeyAddrLev1:4   equ    1280+96+320+128   ; Table Level 1 Key 04 Addr  ;
KeyAddrLev1:5   equ    1280+96+320+160   ; Table Level 1 Key 05 Addr  ;
KeyAddrLev1:6   equ    1280+96+320+192   ; Table Level 1 Key 06 Addr  ;
KeyAddrLev1:7   equ    1280+96+320+224   ; Table Level 1 Key 07 Addr  ;
KeyAddrLev1:8   equ    1280+96+320+256   ; Table Level 1 Key 08 Addr  ;
KeyAddrLev1:9   equ    1280+96+320+288   ; Table Level 1 Key 09 Addr  ;
KeyAddrLev1:X   equ    1280+96+320+320   ; Table of above addresses   ;
KButtonsState   equ    2036              ; KeyBrd Buttons 0-4: 2048-12;
CFG1            equ    2048              ; Splits A1 - F1 240 bytes   ;
CFG2            equ    2288              ; Splits A2 - F2 240 bytes   ;
CFG3            equ    2528              ; Splits A3 - F3 240 bytes   ;
CFG4            equ    2768              ; Splits A4 - F4 240 bytes   ;
XBuff           equ    3072              ; 1024 bytes xtra xmit Midi  ;
RxBuff          equ    3072              ; 3072 receive buffer:1k     ;
RAMBios         equ    4096              ; Bios Area                  ;
;---------------------------------------------------------------------;
StackTop        equ    RamTop                  ; Top of RAM
;------------------------------------------------------------------;
; Indiv LED Codes: (ILED)                                          ;
;------------------------------------------------------------------;
GreenLed1       equ    00000010B    ; LH Green LED (D1)=Split A
SplitALED       equ    GreenLed1    ; LH Green LED (D1)=Split A
SplitBLED       equ    00001000B    ; Green        (D3)=Split B
SplitCLED       equ    10000000B    ; Green        (D7)=Split C
SplitDLED       equ    00010000B    ; Green        (D4)=Split D
SplitFLED       equ    01000000B    ; Red          (D6)=Split E
SplitELED       equ    00100000B    ; Yellow       (D5)=Split F
PwrLED          equ    00000100B    ; Red          (D2)=Power
ErrorLed        equ    PwrLed       ; Red          (D2)=Error
KbrdLed         equ    00000001B    ; Green        (D0)=Keyboard
;--------------------------------------------------------------------------;
; CurrDisp      Current Display Definitions                                ;
;--------------------------------------------------------------------------;
;Disp1:BP  = +12[bp]
;Disp2:BP  =  +0[bp]
;Disp3:BP  =  +4[bp]
;BARLED:BP =  +8[bp]
;--------------------------------------------------------------------------;
CurrDispL0      equ    768             ; Level 0 Display                   ;
DispL0Buff      equ    704             ; Level 0 Display Image Save Buffer ;
;--------------------------------------------------------------------------;
;--------------------------------------------------;
; 7SEG: 0=ON STEADY 1=BLINK 2=ON TEMP 3=TEMP BLINK ; Clear by writing Space
;--------------------------------------------------;
L0D2:D          equ    768             ; 7SEG Display 2 (Middle)
L0D2:X          equ    769             ; Disp 2 2=TempOn 1=Blink 0=Steady
L0D2:T          equ    770             ; Disp 2 TimerA + TimerB(TempOn)
L0D3:D          equ    772             ; 7SEG Display 3 (RH Side)
L0D3:X          equ    773             ; Disp 3 2=TempOn 1=Blink 0=Steady
L0D3:T          equ    774             ; Disp 3 TimerA + TimerB
L0B:D           equ    776             ; BarLED Display
L0B:X           equ    777             ; BarLED Display Timer Flag 2,1,0
L0B:T           equ    778             ; BarLED Display Timer
L0D1:D          equ    780             ; 7SEG Display 1 (LH Side)
L0D1:X          equ    781             ; Disp 1 2=TempOn 1=Blink 0=Steady
L0D1:T          equ    782             ; Disp 1 TimerA + TimerB
;--------------------------------------; Alternative Names:
Disp1:0         equ    780             ; 7SEG Display 1 (LH Side)
Disp2:0         equ    768             ; 7SEG Display 2 (Middle)
Disp3:0         equ    772             ; 7SEG Display 3 (RH Side)
BARLED:0        equ    776             ; BarLED Display
;----------------------------------------------;
; ILED: 0=OFF 1=ON 2=BLINK NORMAL 3=BLINK SLOW ;
;----------------------------------------------;
L0I0:D          equ    784                     ; Indiv LED 7 (Green:KBRD)   
L0I0:T          equ    785                     ; Indiv LED 7 (Green)      Timer
L0I1:D          equ    786                     ; Indiv LED 1 (Green:SPLIT A) 
L0I1:T          equ    787                     ; Indiv LED 1 (Green)      Timer
L0I2:D          equ    788                     ; Indiv LED 8 (Red:POWER:ERROR)
L0I2:T          equ    789                     ; Indiv LED 8 (Red)        Timer
L0I3:D          equ    790                     ; Indiv LED 2 (Green:SPLIT B)
L0I3:T          equ    791                     ; Indiv LED 2 (Green)      Timer
L0I4:D          equ    792                     ; Indiv LED 4 (Green: SPLIT D)
L0I4:T          equ    793                     ; Indiv LED 4 (Green)      Timer
L0I5:D          equ    794                     ; Indiv LED 5 (Yellow:SPLIT E)
L0I5:T          equ    795                     ; Indiv LED 5 (Yellow)     Timer
L0I6:D          equ    796                     ; Indiv LED 6 (Red:   SPLIT F)
L0I6:T          equ    797                     ; Indiv LED 6 (Red)        Timer
L0I7:D          equ    798                     ; Indiv LED 3 (Green: SPLIT C)
L0I7:T          equ    799                     ; Indiv LED 3 (Green)      Timer
;--------------------------------------------------------------------------;
CurrDispL1      equ    800                     ; Level 1 Display
DispL1Buff      equ    736                     ; Level 0 Display Image Save Buff
;--------------------------------------------------------------------------;
L1D2:D          equ    800                     ; 7SEG Display 2 (Middle)
L1D2:X          equ    801                     ; Display 2: 2,1,0
L1D2:T          equ    802                     ; Display 2 TimerA + TimerB
L1D3:D          equ    804                     ; 7SEG Display 3 (RH Side)
L1D3:X          equ    805                     ; Display 3 2,1,0
L1D3:T          equ    806                     ; Display 3 TimerA + TimerB
L1B:D           equ    808                     ; BarLED Display
L1B:X           equ    809                     ; BarLED Display Timer Flag 1,0
L1B:T           equ    810                     ; BarLED Display Timer
L1D1:D          equ    812                     ; 7SEG Display 1 (LH Side)
L1D1:X          equ    813                     ; Display 1 2,1,0
L1D1:T          equ    814                     ; Display 1 TimerA + TimerB
;----------------------------------------------; Alternative Names:
Disp1:1         equ    812                     ; 7SEG Display 1 (LH Side)
Disp2:1         equ    800                     ; 7SEG Display 2 (Middle)
Disp3:1         equ    804                     ; 7SEG Display 3 (RH Side)
BARLED:1        equ    808                     ; BarLED Display
                                               ;-------------------------------;
                                               ; ILED: 0=OFF 1=ON 2=BLINK      ;
                                               ;-------------------------------;
L1I0:D          equ    816                     ; Indiv LED 7 (Green:KBRD)       
L1I0:T          equ    817                     ; Indiv LED 7 (Green)      Timer
L1I1:D          equ    818                     ; Indiv LED 1 (Green:SPLIT A) 
L1I1:T          equ    819                     ; Indiv LED 1 (Green)      Timer
L1I2:D          equ    820                     ; Indiv LED 8 (Red:POWER:ERROR)
L1I2:T          equ    821                     ; Indiv LED 8 (Red)        Timer
L1I3:D          equ    822                     ; Indiv LED 2 (Green: SPLIT B)
L1I3:T          equ    823                     ; Indiv LED 2 (Green)      Timer
L1I4:D          equ    824                     ; Indiv LED 4 (Green: SPLIT D)
L1I4:T          equ    825                     ; Indiv LED 4 (Green)      Timer
L1I5:D          equ    826                     ; Indiv LED 6 (Yellow:SPLIT E)
L1I5:T          equ    827                     ; Indiv LED 6 (Yellow)     Timer
L1I6:D          equ    828                     ; Indiv LED 5 (Red:   SPLIT F)
L1I6:T          equ    829                     ; Indiv LED 5 (Red)        Timer
L1I7:D          equ    830                     ; Indiv LED 3 (Green: SPLIT C)
L1I7:T          equ    831                     ; Indiv LED 3 (Green)      Timer
;--------------------------------------------------------------------------;
;------------------------------------------------------------------;
; Character Codes: Translated to 7 Segment Codes a,b,c,d,e,f,g, dp ;
;------------------------------------------------------------------;
;             Digit    76543210   NUMBERS
;           Segment    .cbadegf
;---------------------------------;
Zero            equ    01111101B  ; "0"
One             equ    01100000B  ; "1"
Two             equ    00111110B  ; "2"
Three           equ    01111010B  ; "3"
Four            equ    01100011B  ; "4"
Five            equ    01011011B  ; "5"
Six             equ    01011111B  ; "6"
Seven           equ    01110000B  ; "7"
Eight           equ    01111111B  ; "8"
Nine            equ    01111011B  ; "9"
;------------------------------------------------------------;
; Xlation Table for 7SEG+DOT DISPLAYS 256 bytes: Codes 0-255 ;
;------------------------------------------------------------;
;                                a                           ;
; D0 - SEG f                   -----                         ;
; D1 - SEG g                 f|  g  |b                       ;
; D2 - SEG e                   -----                         ;
; D3 - SEG d                 e|  d  |c                       ;
; D4 - SEG a                   -----   o Dp                  ;
; D5 - SEG b                                                 ;
; D6 - SEG c                                                 ;
; D7 - SEG Dp                                                ;
;------------------------------------------------------------;
;---------------------------------;
;             Digit    76543210   LETTERS
;           Segment    .cbadegf
;---------------------------------;
Blo             equ    01001111B  ; "b"
Clo             equ    00001110B  ; "c"
Dlo             equ    01101110B  ; "d"
FLo             equ    00010111B  ; "f"
GLo             equ    01111011B  ; "g"
HLo             equ    01000111B  ; "h"
ILo             equ    00000100B  ; "i"
KLo             equ    00001111B  ; "k" approx
LLo             equ    One        ; "l"
MLo             equ    01000110B  ; "m" approx
NLo             equ    01000110B  ; "n"
OLo             equ    01001110B  ; "o"
PLo             equ    00110111B  ; "P"
Rlo             equ    00000110B  ; "r"
Tlo             equ    00001111B  ; "t"
Ulo             equ    01001100B  ; "u"
Vlo             equ    ULo        ; "v"
Ylo             equ    01101011B  ; "y"
;---------------------------------;
;           Segment    .cbadegf
;---------------------------------;
A               equ    01110111B  ; "A"
B               equ    BLo        ; "b"
C               equ    00011101B  ; "C"
D               equ    DLo        ; "d"
E               equ    00011111B  ; "E"
F               equ    00010111B  ; "F"
G               equ    GLo        ; "g"
H               equ    01100111B  ; "H"
I               equ    00000101B  ; "I"
J               equ    01101000B  ; "J"
K               equ    KLo        ; "k" approx
L               equ    00001101B  ; "L"
M               equ    MLo        ; "m" approx
N               equ    01110101B  ; "N"
O               equ    01111101B  ; "O"
P               equ    PLo        ; "P"
;           Segment    .cbadegf
Q               equ    O          ; "Q"
R               equ    RLo        ; "r"
S               equ    01011011B  ; "S"
T               equ    TLo        ; "t"
U               equ    01101101B  ; "U"
V               equ    U          ; "V"
W               equ    U          ; "W" approx
X               equ    01100010B  ; "x" approx
Y               equ    YLo        ; "y"
Z               equ    Two        ; "Z"
;---------------------------------;
;             Digit    76543210   SPECIAL CHARACTERS
;           Segment    .cbadegf
;---------------------------------;
Minus           equ    00000010B  ; "-"
Blank           equ    00000000B  ; " "
Space           equ    Blank      ; " "
Dot             equ    128        ; "."
LBracket        equ    00011101B  ; "["
RBracket        equ    01111000B  ; "]"
Line1           equ    00010000B  ; 1 HORIZONTAL BAR
Line2T          equ    00010010B  ; 2 HORIZONTAL BARS
Line2B          equ    00001010B  ; 2 HORIZONTAL BARS
Equal           equ    Line2B     ; "=" 
Line3           equ    00011010B  ; 3 HORIZONTAL BARS
SegA            equ    00010000B  ; Segment a
SegB            equ    00100000B  ; Segment b
SegC            equ    01000000B  ; Segment c
SegD            equ    00001000B  ; Segment d
SegE            equ    00000100B  ; Segment e
SegF            equ    00000001B  ; Segment f
SegG            equ    00000010B  ; Segment g
SegDP           equ    10000000B  ; Segment .
;---------------------------------;
; LED Bar Display                 ;
;             Digit    76543210   ;
;           Segment    61784532   ;
;---------------------------------;
Bar0            equ    00000000B  ; "0"
Bar1            equ    01000000B  ; "1"
Bar2            equ    01000001B  ; "2"
Bar3            equ    01000011B  ; "3"
Bar4            equ    01001011B  ; "4"
Bar5            equ    01001111B  ; "5"
Bar6            equ    11001111B  ; "6"
Bar7            equ    11101111B  ; "7"
Bar8            equ    11111111B  ; "8"
;---------------------------------;
;             Digit    76543210   ;
;           Segment    61784532   ;
;---------------------------------;
Dot0            equ    00000000B  ; "0"
Dot1            equ    01000000B  ; "1"
Dot2            equ    00000001B  ; "2"
Dot3            equ    00000010B  ; "3"
Dot4            equ    00001000B  ; "4"
Dot5            equ    00000100B  ; "5"
Dot6            equ    10000000B  ; "6"
Dot7            equ    00100000B  ; "7"
Dot8            equ    00010000B  ; "8"
;---------------------------------;
Dot9            equ    01010000B  ; "1+8"
Dot10           equ    00010001B  ; "2+8"
Dot11           equ    00010010B  ; "3+8"
Dot12           equ    00011000B  ; "4+8"
Dot13           equ    00010100B  ; "5+8"
Dot14           equ    10010000B  ; "6+8"
Dot15           equ    00110000B  ; "7+8"
;---------------------------------;
Dot16           equ    01110000B  ; "0+8+7"
Dot17           equ    00110001B  ; "1+8+7"
Dot18           equ    00110010B  ; "2+8+7"
Dot19           equ    00111000B  ; "3+8+7"
Dot20           equ    00110100B  ; "4+8+7"
Dot21           equ    10110000B  ; "4+8+7"
;---------------------------------;
Dot22           equ    11110000B  ; "4+8+7+5"
Dot23           equ    10110001B  ; "4+8+7+5"
Dot24           equ    10110010B  ; "4+8+7+5"
Dot25           equ    10111000B  ; "4+8+7+5"
Dot26           equ    10110100B  ; "4+8+7+5"
;---------------------------------;
Dot27           equ    11110100B  ; "4+8+7+5+4"
Dot28           equ    10110101B  ; "4+8+7+5+4"
Dot29           equ    10110110B  ; "4+8+7+5+4"
Dot30           equ    10111100B  ; "4+8+7+5+4"
;---------------------------------;
Dot31           equ    11111100B  ; "4+8"
Dot32           equ    10111101B  ; "4+8"
Dot33           equ    10111110B  ; "4+8"
;---------------------------------;
Dot34           equ    11111110B  ; "4+8"
Dot35           equ    10111111B  ; "4+8"
;---------------------------------;
Dot36           equ    11111111B  ; "4+8"
;=================================;

;===============================================================;
; RAM Image Area: 0000 - 1FFF (0-4096)                          ;
;===============================================================;
RAMBottom                                                       ;
;---------------------------------------------------------------;
; 0010-0013: INTOVFL                                            ;16-19
; 000C-000F: 4 bytes available                                  ;12
; 0008-000B: INTNMI (used)                                      ;8-11
; 0004-0007: 4 bytes available                                  ;4
; 0000-0003: INTDIV0                                            ;0-3
;---------------------------------------------------------------;
 DW offset(RamDIV0),    0000H                                   ;INT0=DIV0  
 DW 0000H,              0000H                                   ;INT1
 DW offset(ROMINTInit), 0000H                                   ;INT2=NMI
 DW 0000H,              0000H                                   ;INT3        
 DW offset(RamOV),      0000H                                   ;INT4=OverFl 
;------------------------------------------------------------------;
; 0014-005F: 76 bytes for special and BIOS load affected variables ;20-95
; BIOS Load will only start loading from after these variables     ;
; .x shows coupling i.e. keep in same sequence                     ;
;------------------------------------------------------------------;
 DB 00H       ; PermINT           20: 01 = Enable Permanent INT    ;Byte
 DB 00H       ; TaskTest          21: Debug:Idle Time              ;Byte.1 
 DB 00H       ; TaskNumber        22: Task 0,2,4,6,8,A,C,E         ;Byte.2
 DB 00H       ; TaskBusy          23: 1=Task busy 0=Next Task      ;Byte.3
 DB 00H       ; GoRAMBIOS         24: 1=Enable JMP to RAM Bios     ;Byte
 DB 00H       ; ResetDefault      25: Reset to default values if=1 ;Byte
 DW 0000H     ; FilterEnable      26; Receiver Timing Filter Ena   ;    
 DW 0000H     ; WheelsEnable      28; 1=Enable Wheels              ;
 DW 0000H     ;                   30:                              ;Unused
 DW 0000H     ;                   32:                              ;Unused
 DW 0000H     ; XBuffIn           34; Extra Xmission Buffer Input  ;    
 DW 0000H     ; XBuffOut          36; Extra Xmission Buffer OutPut ;
 DW 0000H     ; Timer0            38: General Timer: 2 ms INT inc  ;    
 DW 0000H     ; Timer1            40: General Timer: 2 ms INT inc  ;
 DW 0000H     ; KeyStore          42; Last Note Stored             ;     
 DW 0000H     ; Split             44; Current Split 0=A B=1 C=2    ;
 DW 0000H     ; TempDisp          46; Flag Temp Disp Active=0,1,2  ;    
 DW 0000H     ; Level01           48: Buttons Level 0 (Top) or 1   ;
 DW 0000H     ; Level0Task        50: Level0 Current Task          ;    
 DW 0000H     ; Level0Addr        52: Addr of Curr Lev 0 Task Table;
 DW 0000H     ;                   54:                              ;Unused
 DW 0000H     ; RxIn              56: Receive input Ptr            ;
 DW 0000H     ; RxOut             58: Receive output Ptr           ;    
 DW 0000H     ; RxEnable          60: Receive: 1=Enable 0=Disable  ;
 DW 0000H     ; ILEDState         62: Current state of Indiv LEDs  ;    
              ;----------------------------------------------------;
 DW 0001H     ; KeyScanEnable     64: Keyboard Scan: 1=Enable      ;
 DW 0001H     ; ButtonEnable      66: Buttons Enable = 01          ;     
 DW 0001H     ; WButtonEnable     68; Wheels Buttons Enable=01     ;
 DW 0001H     ; KButtonEnable     70; Keyboard Buttons Enable=01   ;    
 DW 0001H     ; TxEnable          72: Xmitter: 1,2=Enable 0=Disable;    
 DW 00FFH     ; ButtonPressed     74: Number 0-31 of pressed PKey  ;     
 DW 00FFH     ; KButtonPressed    76; No 0-4 of pressed KbrdKey    ;    
 DW 00FFH     ; WButtonPressed    78; No 1,2,4: pressed WheelsKey  ;
 DW BIOSEnd   ; RxBufferMax       80; Receiver Max BuffSize=RxEnd  ;    
 DW 0060H     ; RxBuffer          82; Addr Receive BuffStart=RxBuff;
 DW offset(CFG1)    ;   SplitCFG  84; Ptr to curr Split A          ;    
 DW offset(CFG1+40) ;   SplitCFG  86; Ptr to curr Split B          ;
 DW offset(CFG1+80) ;   SplitCFG  88; Ptr to curr Split C          ;     
 DW offset(CFG1+120);   SplitCFG  90; Ptr to curr Split D          ;
 DW offset(CFG1+160);   SplitCFG  92; Ptr to curr Split E          ;
 DW offset(CFG1+200);   SplitCFG  94; Ptr to curr Split F          ;
;--------------------------------------------------------------------;
; 0060-00DF: SplitCFG Pre-initialise Strings:16*6=96 bytes           ;96-191
;--------------------------------------------------------------------;
 DB 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;16  A
 DB 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;32  B 
 DB 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;48  C
 DB 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;64  D 
 DB 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;80  E
 DB 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;96  F 
;--------------------------------------------------------------------;
; Unused 32 bytes                                                    ;192-223
;--------------------------------------------------------------------;
 DB 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;  
 DB 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;32   
;--------------------------------------------------------------------;
; 00E0-00EF: KeyBoard Buttons Addresses (16 bytes,14 used=7 Addr)    ;224 *
;--------------------------------------------------------------------;
 DW offset(KB00), offset(KB01), offset(KB02), offset(KB03)           ;
 DW offset(KB04), offset(KB05), offset(KB06), 0000H                  ;16
;--------------------------------------------------------------------;
; 00F0-00F7: Wheels Buttons State (8 bytes, only 6 used)             ;240 *
;--------------------------------------------------------------------;
 DW 0101H, 0101H, 0101H, 0000H                                       ;  
;--------------------------------------------------------------------;
; 00F8-00FF: 8 Available                                             ;248
;--------------------------------------------------------------------;
 DB 00H,00H,00H,00H,00H,00H,00H,00H                                  ;8 Unused
;--------------------------------------------------------------------;
; 0100-01FF: Midi Codes Buffer (256 bytes)                           ;256
;--------------------------------------------------------------------;
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;  
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;64   
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;  
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;128   
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;  
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;192   
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;  
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;256   
;--------------------------------------------------------------------;
; 0200-02BF: Variables 192 bytes allocated: 512-703                  ;512
;--------------------------------------------------------------------;
 DB 00H       ;                    0:                              ;Byte Unused
 DB 00H       ; Escape             1: 1=Escape Key pressed         ;Byte
 DB 00H       ; CurrPatch          2: Current patch No 0-127       ;Byte
 DB 00H       ; PredefPatch        3: Predef patch No 0-9          ;Byte
 DB 00H       ; Wheel0             4; Value of Wheel 0             ;Byte
 DB 00H       ; Wheel1             5; Value of Wheel 1             ;Byte
 DB 00H       ; Wheel2             6; Value of Wheel 2             ;Byte
 DB 00H       ; Wheel3             7; Value of Wheel 3             ;Byte
 DB 00H       ; WButtons           8; Buttons on Wheels            ;Byte
 DB 00H       ; PPatch             9: Patch No 0-127               ;Byte
 DB 00H       ; Bit7Enable        10; 01=Enable 7Bit Xmitter       ;Byte
 DB 00H       ; HeaderEnable      11; 01=Add SysEx Header          ;Byte
 DW 0000H     ; Error             12: GP Error Flag                ;
 DW 0000H     ; Message           14: Message Start Address        ;    
 DW 0000H     ; MessageEnd        16: Message End Address          ;
 DW 0000H     ; MessTimer         18: Message Timer                ;    
 DB 00H       ; IdleTimer         20: Debug:how long not NMI       ;Byte.1
 DB 0FFH      ; TaskTime          21: Debug:Timer                  ;Byte.2
 DW 0000H     ; BinCount          22: Debug:Counter if Key 02 press;    
 DW 0000H     ; DelayTimer        24: proc Delay1 Timer            ;
 DW 0000H     ; CounterDec        26:                              ;    
 DW 0000H     ; CounterHex        28:                              ;
 DW 0000H     ; Number1s          30: Get3Digit variables          ;    
 DW 0000H     ; Number10s         32:                              ;     
 DW 0000H     ; Number100s        34:                              ;
 DW 0000H     ; Number            36:                              ;    
 DW 0000H     ; PKey              38: PatchXmit: Key 0-9           ;
 DW 0000H     ; PChannel          40:            Channel 0-15      ;     
 DW 0000H     ; Response          42: 0=NoResponse 1=Press Button  ;
 DW 0000H     ; WheelsNum         44; Wheels Number 0-3            ;    
 DW 0000H     ; WheelsMax         46; Wheels Max Position          ;
 DW 0000H     ; WheelsMin         48; Wheels Min Position          ;    
 DW 0000H     ; WheelsRst         50; Wheels Rest Position         ;
 DW 0000H     ; WheelsType        52; Wheels Type 0,1              ;    
 DW 0000H     ; KBrdConnect       54; 1=Flash 0=Steady Kbrd LED    ;
 DW 0000H     ; DisplayWheels     56; Enable Wheels Display if 1   ;    
 DW 0000H     ; Patch2ndTime      58; KbrdButton Patches 2x press  ;
 DW 0000H     ; KBrdOption        60; KeyButton 0-6                ;    
 DW 0000H     ; TempSplit         62; Enable-Disable split         ;
 DW 0000H     ; TempCFG           64; Enable CFG1,2,3              ;    
 DW 0000H     ; FootSWNum         66; Footswitch No 0, 1           ;
 DW 0000H     ; WheelsVar1        68; Temp storage for DoWheels    ;     
 DW 0000H     ; WheelsVar2        70; Temp storage for DoWheels    ;
 DW 0000H     ; GlobalOctXp       72; 1=Global,0=Single OctaveXpose;    
 DW 0000H     ; CommandMode       74; Commands Receive Mode:=01    ;    
 DW 0000H     ; CommandNo         76; Received Command Number      ;    
 DW 0000H     ; DataLength        78; Length of Data in Command    ;    
 DB 0H,0H,0H,0H,0H,0H,0H,0H,0H,0H   ; 10 Unused                    ;
 DB 0H,0H,0H,0H,0H,0H,0H,0H,0H,0H   ; 10 Unused                    ;
              ;----------------------------------------------------;
 DB 36        ; ScanToKey        100: Basic Correction 0 - 127     ;Byte
 DB 01H       ; MessEnable       101: Message Enable = 1           ;Byte
 DW 0000H     ;                  102:                              ;Unused
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
 DW 000AH     ; ScrollTime       134; ScrollTime:ROM=0040,RAM=0010 ;    
 DB 90H,00H   ; MidiNoteOff      136; NoteOff=80/90+VelFilt=0/7F   ;
 DW 0000H     ;                  138; Unused                       ;
 DB 0H,0H                           ; 2  Unused                    ;
 DB 0H,0H,0H,0H,0H,0H,0H,0H,0H,0H   ; 10 Unused                    ;
 DB 0H,0H,0H,0H,0H,0H,0H,0H,0H,0H   ; 10 Unused                    ;
 DB 0H,0H,0H,0H,0H,0H,0H,0H,0H,0H   ; 10 Unused                    ;
 DB 0H,0H,0H,0H,0H,0H,0H,0H,0H,0H   ; 10 Unused                    ;
 DB 0H,0H,0H,0H,0H,0H,0H,0H,0H,0H   ; 10 Unused                    ;
;--------------------------------------------------------------------;
; 02C0-02FF: Display Area Image Save (During Temp) (64 bytes)        ;704
;--------------------------------------------------------------------;
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;  
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;64   
;--------------------------------------------------------------------;
; 0300-033F: Display Area (768-831: 64 bytes)                        ;768
;--------------------------------------------------------------------;
 DB 00H    ; L0D2:D   768             ; 7SEG Display 2 (Middle)
 DB 00H    ; L0D2:X   769             ; Disp 2 2=Temp 1=Blink 0=Steady
 DW 0000H  ; L0D2:T   770             ; Disp 2 TimerA+B
 DB 00H    ; L0D3:D   772             ; 7SEG Display 3 (RH Side)
 DB 00H    ; L0D3:X   773             ; Disp 3 2=Temp 1=Blink 0=Steady
 DW 0000H  ; L0D3:T   774             ; Disp 3 TimerA+B
 DB 00H    ; L0B:D    776             ; BarLED Disp
 DB 00H    ; L0B:X    777             ; BarLED Disp Attrib
 DW 0000H  ; L0B:T    778             ; BarLED Disp TimerA+B
 DB 00H    ; L0D1:D   780             ; 7SEG Display 1 (LH Side)
 DB 00H    ; L0D1:X   781             ; Disp 1 2=Temp 1=Blink 0=Steady
 DW 0000H  ; L0D1:T   782             ; Disp 1 TimerA+B
 DB 0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0   ; 784-799 L0I0-L0I7 Indiv LED's
;-------------------------------------;
 DB 00H    ; L0D2:D   768             ; 7SEG Display 2 (Middle)
 DB 00H    ; L0D2:X   769             ; Disp 2 2=Temp 1=Blink 0=Steady
 DW 0000H  ; L0D2:T   770             ; Disp 2 TimerA+B
 DB 00H    ; L0D3:D   772             ; 7SEG Display 3 (RH Side)
 DB 00H    ; L0D3:X   773             ; Disp 3 2=Temp 1=Blink 0=Steady
 DW 0000H  ; L0D3:T   774             ; Disp 3 TimerA+B
 DB 00H    ; L0B:D    776             ; BarLED Disp
 DB 00H    ; L0B:X    777             ; BarLED Disp Attrib
 DW 0000H  ; L0B:T    778             ; BarLED Disp TimerA+B
 DB 00H    ; L0D1:D   780             ; 7SEG Display 1 (LH Side)
 DB 00H    ; L0D1:X   781             ; Disp 1 2=Temp 1=Blink 0=Steady
 DW 0000H  ; L0D1:T   782             ; Disp 1 TimerA+B
 DB 0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0   ; 784-799 L0I0-L0I7 Indiv LED's
;--------------------------------------------------------------------;
; 0340-037F: Wheels Configuration (64 bytes:16 bytes per wheel)      ;832
;--------------------------------------------------------------------;
; Wheel 0                                                            ;
;--------------------------------------------------------------------;
 DB 00H   ; Wheel0Change  832       ; 0=No Change, 1=Change          ;+0
 DB 01H   ; Wheel0Type    833       ; Type 0=-Mid+, 1=0->Max         ;+1
 DB 01H   ; Wheel0R       834       ; 1=0-127 or 0=0-255             ;+2
 DB 03H   ; Wheel0Val     835       ; Last Raw Value                 ;+3
 DB 00H   ; Wheel0Value   836       ; Last Xlated Value 0-127,255    ;+4 
 DB 7EH   ; Wheel0Max     837       ; Max Pos                        ;+5
 DB 03H   ; Wheel0Min     838       ; Min Pos                        ;+6
 DB 03H   ; Wheel0Rst     839       ; Rest Pos                       ;+7
 DW offset(WriteDec)      ; Wheel0Disp 840 ; Display Address         ;+8 +9
 DB 00H   ;               842       ;                                ;+10
 DB 00H   ;               843       ;                                ;+11
 DW 0000H ;               844       ;                                ;+12
 DB 00H   ;               846       ;                                ;+14
 DB 00H   ;               847       ;                                ;+15
;--------------------------------------------------------------------;
; Wheel 1                                                            ;
;--------------------------------------------------------------------;
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
; Wheel 2                                                            ;
;--------------------------------------------------------------------;
 DB 00H   ; Wheel0Change  832       ; 0=No Change, 1=Change          ;+0
 DB 00H   ; Wheel0Type    833       ; Type 0=-Mid+, 1=0->Max         ;+1
 DB 01H   ; Wheel0R       834       ; 1=0-127 or 0=0-255             ;+2
 DB 4FH   ; Wheel0Val     835       ; Last Raw Value                 ;+3
 DB 40H   ; Wheel0Value   836       ; Last Xlated Value 0-127,255    ;+4 
 DB 7EH   ; Wheel0Max     837       ; Max Pos                        ;+5
 DB 03H   ; Wheel0Min     838       ; Min Pos                        ;+6
 DB 4FH   ; Wheel0Rst     839       ; Rest Pos                       ;+7
 DW offset(WriteWheel)    ; Wheel0Disp 840 ; Display Address         ;+8 +9
 DB 00H   ;               842       ;                                ;+10
 DB 00H   ;               843       ;                                ;+11
 DW 0000H ;               844       ;                                ;+12
 DB 00H   ;               846       ;                                ;+14
 DB 00H   ;               847       ;                                ;+15
;--------------------------------------------------------------------;
; Wheel 3                                                            ;
;--------------------------------------------------------------------;
 DB 00H   ; Wheel0Change  832       ; 0=No Change, 1=Change          ;+0
 DB 01H   ; Wheel0Type    833       ; Type 0=-Mid+, 1=0->Max         ;+1
 DB 01H   ; Wheel0R       834       ; 1=0-127 or 0=0-255             ;+2
 DB 03H   ; Wheel0Val     835       ; Last Raw Value                 ;+3
 DB 00H   ; Wheel0Value   836       ; Last Xlated Value 0-127,255    ;+4 
 DB 7CH   ; Wheel0Max     837       ; Max Pos                        ;+5
 DB 03H   ; Wheel0Min     838       ; Min Pos                        ;+6
 DB 03H   ; Wheel0Rst     839       ; Rest Pos                       ;+7
 DW offset(WriteWheel)    ; Wheel0Disp 840 ; Display Address         ;+8 +9
 DB 00H   ;               842       ;                                ;+10
 DB 00H   ;               843       ;                                ;+11
 DW 0000H ;               844       ;                                ;+12
 DB 00H   ;               846       ;                                ;+14
 DB 00H   ;               847       ;                                ;+15
;--------------------------------------------------------------------;
; 0380-03FF: Custom Velocity Table (128 bytes)                       ;896 *
;--------------------------------------------------------------------;
 DW 4040H,4040H,4040H,4040H,4040H,4040H,4040H,4040H                  ;
 DW 4040H,4040H,4040H,4040H,4040H,4040H,4040H,4040H                  ;32  
 DW 4040H,4040H,4040H,4040H,4040H,4040H,4040H,4040H                  ;
 DW 4040H,4040H,4040H,4040H,4040H,4040H,4040H,4040H                  ;64  
 DW 4040H,4040H,4040H,4040H,4040H,4040H,4040H,4040H                  ;
 DW 4040H,4040H,4040H,4040H,4040H,4040H,4040H,4040H                  ;96  
 DW 4040H,4040H,4040H,4040H,4040H,4040H,4040H,4040H                  ;
 DW 4040H,4040H,4040H,4040H,4040H,4040H,4040H,4040H                  ;128  
;--------------------------------------------------------------------;
; 0400-047F: Key States (128 bytes)                                  ;0
;--------------------------------------------------------------------;
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;  
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;64   
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;  
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;128   
;--------------------------------------------------------------------;
; 0480-04FF: Key Velocities (128 bytes)                              ;1152
;--------------------------------------------------------------------;
 DW 7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH                  ;  
 DW 7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH                  ;  
 DW 7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH                  ;  
 DW 7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH                  ;64  
 DW 7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH                  ;  
 DW 7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH                  ;  
 DW 7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH                  ;  
 DW 7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH,7F7FH                  ;128 
;--------------------------------------------------------------------;
; 0500-051F: Buttons State (32 bytes)                                ;1280
;--------------------------------------------------------------------;
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H  ;32
;--------------------------------------------------------------------;
; 0520-053F: Task Addresses (32 bytes)                               ;1312
;--------------------------------------------------------------------;
 DW offset(DoButton),       offset(ReadButton)        ; Tasks  0, 2
 DW offset(DoDispTimer),    offset(DoDisp)            ; Tasks  4, 6
 DW offset(KReadButton),    offset(DoKButton)         ; Tasks  8, 10
 DW offset(ReadWheels0),    offset(ReadWheels1)       ; Tasks 12, 14
 DW offset(ReadDoWButtons), offset(DoVarious)         ; Tasks 16, 18
 DW offset(ReadWheels2),    offset(ReadWheels3)       ; Tasks 20, 22
 DW offset(WheelsChange),   offset(DoSpecial)         ; Tasks 24, 26
 DW offset(DoWheels01),     offset(DoWheels23)        ; Tasks 28, 30
;--------------------------------------------------------------------;
; 0540-055F: Level 0 Check Key xx Address (32 bytes)                 ;1344
;--------------------------------------------------------------------;
 DW offset(L0Key00), offset(L0Key01), offset(L0Key02),  offset(L0Key03)
 DW offset(L0Key04), offset(L0Key05), offset(L0Key06),  offset(L0Key07)
 DW offset(L0Key08), offset(L0Key09), offset(L0Key10),  offset(L0Key11)
 DW offset(L0Key12), offset(L0Key13), offset(L0Key14),  offset(L0Key15)
;--------------------------------------------------------------------;
; 0560-059F: Patch Xmit define: Key 0-9 -> patch 0-127 (320 bytes)   ;1376
;--------------------------------------------------------------------;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key00   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key01   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key02   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key03   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key04   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key05   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key06   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key07   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key08   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
 DB 0C0H,0,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;Key09   ;
 DB 0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH,0,0FFH ;32 bytes;
;------------------------------------------------------------------------;
; 06A0-06BF: Level 1 Check Key 00 (Debug) Key xx Address (32 bytes)      ;1696
;------------------------------------------------------------------------;
 DW offset(L0:0:K00),offset(L0:0:K01),offset(L0:0:K02),offset(L0:0:K03)
 DW offset(L0:0:K04),offset(L0:0:K05),offset(L0:0:K06),offset(L0:0:K07)
 DW offset(L0:0:K08),offset(L0:0:K09),offset(L0:0:K10),offset(L0:0:K11)
 DW offset(L0:0:K12),offset(L0:0:K13),offset(L0:X:K14),offset(L0:0:K15)
;------------------------------------------------------------------------;
; 06C0-06DF: Level 1 Check Key 01 (Patch Xmit) Key xx Address (32 bytes) ;1728
;------------------------------------------------------------------------;
 DW offset(L0:1:K00),offset(L0:1:K01),offset(L0:1:K02),offset(L0:1:K03)
 DW offset(L0:1:K04),offset(L0:1:K05),offset(L0:1:K06),offset(L0:1:K07)
 DW offset(L0:1:K08),offset(L0:1:K09),offset(L0:1:K10),offset(L0:1:K11)
 DW offset(L0:1:K12),offset(L0:1:K13),offset(L0:X:K14),offset(L0:1:K15)
;------------------------------------------------------------------------;
; 06E0-06FF: Level 1 Check Key 02                                        ;1760
;------------------------------------------------------------------------;
 DW offset(L0:2:K00),offset(L0:2:K01),offset(L0:2:K02),offset(L0:2:K03)
 DW offset(L0:2:K04),offset(L0:2:K05),offset(L0:2:K06),offset(L0:2:K07)
 DW offset(L0:2:K08),offset(L0:2:K09),offset(L0:2:K10),offset(L0:2:K11)
 DW offset(L0:2:K12),offset(L0:2:K13),offset(L0:X:K14),offset(L0:2:K15)
;------------------------------------------------------------------------;
; 0700-071F: Level 1 Check Key 03                                        ;1792
;------------------------------------------------------------------------;
 DW offset(L0:3:K00),offset(L0:3:K01),offset(L0:3:K02),offset(L0:3:K03)
 DW offset(L0:3:K04),offset(L0:3:K05),offset(L0:3:K06),offset(L0:3:K07)
 DW offset(L0:3:K08),offset(L0:3:K09),offset(L0:3:K10),offset(L0:3:K11)
 DW offset(L0:3:K12),offset(L0:3:K13),offset(L0:X:K14),offset(L0:3:K15)
;------------------------------------------------------------------------;
; 0720-073F: Level 1 Check Key 04                                        ;1824
;------------------------------------------------------------------------;
 DW offset(L0:4:K00),offset(L0:4:K01),offset(L0:4:K02),offset(L0:4:K03)
 DW offset(L0:4:K04),offset(L0:4:K05),offset(L0:4:K06),offset(L0:4:K07)
 DW offset(L0:4:K08),offset(L0:4:K09),offset(L0:4:K10),offset(L0:4:K11)
 DW offset(L0:4:K12),offset(L0:4:K13),offset(L0:X:K14),offset(L0:4:K15)
;------------------------------------------------------------------------;
; 0740-075F: Level 1 Check Key 05                                        ;1856
;------------------------------------------------------------------------;
 DW offset(L0:5:K00),offset(L0:5:K01),offset(L0:5:K02),offset(L0:5:K03)
 DW offset(L0:5:K04),offset(L0:5:K05),offset(L0:5:K06),offset(L0:5:K07)
 DW offset(L0:5:K08),offset(L0:5:K09),offset(L0:5:K10),offset(L0:5:K11)
 DW offset(L0:5:K12),offset(L0:5:K13),offset(L0:X:K14),offset(L0:5:K15)
;------------------------------------------------------------------------;
; 0760-077F: Level 1 Check Key 06                                        ;1888 
;------------------------------------------------------------------------;
 DW offset(L0:6:K00),offset(L0:6:K01),offset(L0:6:K02),offset(L0:6:K03)
 DW offset(L0:6:K04),offset(L0:6:K05),offset(L0:6:K06),offset(L0:6:K07)
 DW offset(L0:6:K08),offset(L0:6:K09),offset(L0:6:K10),offset(L0:6:K11)
 DW offset(L0:6:K12),offset(L0:6:K13),offset(L0:X:K14),offset(L0:6:K15)
;------------------------------------------------------------------------;
; 0780-079F: Level 1 Check Key 07                                        ;1920
;------------------------------------------------------------------------;
 DW offset(L0:7:K00),offset(L0:7:K01),offset(L0:7:K02),offset(L0:7:K03)
 DW offset(L0:7:K04),offset(L0:7:K05),offset(L0:7:K06),offset(L0:7:K07)
 DW offset(L0:7:K08),offset(L0:7:K09),offset(L0:7:K10),offset(L0:7:K11)
 DW offset(L0:7:K12),offset(L0:7:K13),offset(L0:X:K14),offset(L0:7:K15)
;------------------------------------------------------------------------;
; 07A0-07BF: Level 1 Check Key 08                                        ;1952
;------------------------------------------------------------------------;
 DW offset(L0:8:K00),offset(L0:8:K01),offset(L0:8:K02),offset(L0:8:K03)
 DW offset(L0:8:K04),offset(L0:8:K05),offset(L0:8:K06),offset(L0:8:K07)
 DW offset(L0:8:K08),offset(L0:8:K09),offset(L0:8:K10),offset(L0:8:K11)
 DW offset(L0:8:K12),offset(L0:8:K13),offset(L0:X:K14),offset(L0:8:K15)
;------------------------------------------------------------------------;
; 07C0-07DF: Level 1 Check Key 09 (Patch Xmit) Key xx Address (32 bytes) ;1984
;------------------------------------------------------------------------;
 DW offset(L0:9:K00),offset(L0:9:K01),offset(L0:9:K02),offset(L0:9:K03)
 DW offset(L0:9:K04),offset(L0:9:K05),offset(L0:9:K06),offset(L0:9:K07)
 DW offset(L0:9:K08),offset(L0:9:K09),offset(L0:9:K10),offset(L0:9:K11)
 DW offset(L0:9:K12),offset(L0:9:K13),offset(L0:X:K14),offset(L0:9:K15)
;------------------------------------------------------------------------;
; 07E0-07F3: Addresses of each block above (20 bytes)                    ;2016
;------------------------------------------------------------------------;
 DW KeyAddrLev1:0, KeyAddrLev1:1, KeyAddrLev1:2, KeyAddrLev1:3
 DW KeyAddrLev1:4, KeyAddrLev1:5, KeyAddrLev1:6, KeyAddrLev1:7
 DW KeyAddrLev1:8, KeyAddrLev1:9
;------------------------------------------------------------------------;
; 07F4-07FF: Keyboard Buttons State (12 bytes:only 7 keys:0-6 used)      ;2036 
;------------------------------------------------------------------------;
 DW 0101H, 0101H, 0101H, 0101H, 0101H, 0101H                             ;  
;------------------------------------------------------------------------;
; 0800-08EF: CFG Block 1: Splits A1,B1,C1,D1,E1,F1 = 40*6=240 bytes      ;2048
;------------------------------------------------------------------------;
;--------------------------------------------------------------;
; Split A1 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 80H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;D7=1=EnableSplit
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 00H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 01H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split B1 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;*
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 01H   ; Channel:A     10 SplitA Midi Channel 0-15          ;*
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;*
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWNothing)    ; Wheel0Addr:A  16 Wheel0 Routine    ;*
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 00H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split C1 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 02H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
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
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split D1 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 03H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
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
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split E1 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 04H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
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
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split F1 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 05H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
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
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
;------------------------------------------------------------------------;
; 08F0-09DF: CFG Block 2: Splits A2,B2,C2,D2,E2,F2 = 240 bytes           ;2288
;------------------------------------------------------------------------;
;--------------------------------------------------------------;
; Split A2 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 80H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 00H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 01H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split B2 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 01H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split C2 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 02H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split D2 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 03H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split E2 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 04H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split F2 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 05H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
;------------------------------------------------------------------------;
; 09E0-0ACF: CFG Block 3: Splits A3,B3,C3,D3,E3,F3 = 240 bytes           ;2528
;------------------------------------------------------------------------;
;--------------------------------------------------------------;
; Split A3 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 80H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 00H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 01H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split B3 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 01H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split C3 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 02H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split D3 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 03H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split E3 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 04H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split F3 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 05H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
;------------------------------------------------------------------------;
; 0AD0-0BBF: CFG Block 4: Splits A4,B4,C4,D4,E4,F4 = 240 bytes           ;2768
;------------------------------------------------------------------------;3007
;--------------------------------------------------------------;
; Split A4 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 80H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 00H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 01H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split B4 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 01H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split C4 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 02H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split D4 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 03H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split E4 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 04H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;
; Split F4 CFG Block: 40 bytes                                 ;
;--------------------------------------------------------------;
 DB 00H   ; SplitPosS:A    0 SplitPoint Start 0-127(49) Notes  ;
 DB 031H  ; SplitPosE:A    1 SplitPoint End   0-127(49) Notes  ;
 DW 0000H ;                2 UNUSED                            ;
 DW 0000H ; VelTab:A       4 Current Vel Table Address         ;
 DB 00H   ; Octave:A       6 Octave: -36,24,..,0,+12,+24,+36   ;
 DB 00H   ; Oct:A          7 Octave: 0=0, +-12=1 +-24=2 +-36=3 ;
 DB 00H   ; XPose:A        8 Transpose +-0,+-1,+-2 to +-12     ;
 DB 00H   ; KeyOffSet:A    9 Total of Octave, Xpose, Basic Offs;
 DB 05H   ; Channel:A     10 SplitA Midi Channel 0-15          ;
 DB 00H   ; Enable:A      11 0=Disable 1=Enable                ;
 DB 00H   ; VelInv:A      12 0=Normal 11=Inverse               ;
 DB 00H   ; VelOffsV:A    13 Vel Offset Vertical: -64-0-64     ;
 DB 0FFH  ; VelConst:A    14 Constant Velocity Value FF=off    ;
 DB 02H   ; VelMode:A     15 Velocity Contour 0-10             ;
 DW offset(DoWVolume)     ; Wheel0Addr:A  16 Wheel0 Routine    ;
 DB 00H   ; Wheel0Num:A   18 Wheel0 Controller Number: 0-127   ;    
 DW offset(DoWController) ; Wheel1Addr:A  19 Wheel1 Routine    ;        
 DB 01H   ; Wheel1Num:A   21 Wheel1 Controller Number: 0-127   ;    
 DW offset(DoWPitchBend)  ; Wheel2Addr:A  22 Wheel2 Routine    ;        
 DB 00H   ; Wheel2Num:A   24 Wheel2 Controller Number: 0-127   ;    
 DW offset(DoWNothing)    ; Wheel3Addr:A  25 Wheel3 Routine    ;        
 DB 00H   ; Wheel3Num:A   27 Wheel3 Controller Number: 0-127   ;   
 DW offset(DoFSController); WFoot0Addr:A  28 Wheel3 Footsw Addr;
 DB 40H   ; WFoot0Num:A   30 Wheel3 Foot0sw Con Number: 0-127  ;
 DW offset(DoWPitchBend)  ; WFoot13ddr:A  31 Wheel3 Footsw Addr;
 DB 1FH   ; WFoot1Num:A   33 Wheel3 Foot1sw Con Number: 0-127  ;
 DW offset(DoFSController); WFoot2Addr:A  34 Wheel3 Footsw Addr;
 DB 40H   ; WFoot2Num:A   36 Wheel3 Foot2sw Con Number: 0-127  ;
 DB 00H   ; SplitStr1:X   37 32byte pre-init string:Value=len  ;
 DB 00H   ; SplitPatch    38
 DB 0     ; Unused        39                                   ;
;--------------------------------------------------------------;3007
;------------------------------------------------------------------------;
; 0BC0-0BFF: 64 Available                                                ;3008
;------------------------------------------------------------------------;
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H      ;32
 DW 00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H,00H      ;64
;------------------------------------------------------------------------;
; 0C00-0FFF: RECEIVE BUFFER = 1024 bytes                                 ;3072
;          : SPECIAL TRANSMIT BUFFER = 1024 bytes                        ;
;------------------------------------------------------------------------;
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;64
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;128
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;192
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;256
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;64
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;128
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;192
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;256
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;64
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;128
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;192
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;256
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;64
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;128
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0    ;192
 DW 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,  0,0,0,0,0,0,0,0,0,0,0,0,0,0        ;
 DB 1, 2, 3, 4                                                           ;256
;========================================================================;


