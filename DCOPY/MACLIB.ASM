; "MACLIB.ASM" PC-9801UV11 make by R.H 1989/11/04
;              PC-9801UV11 make by R.H 1990/04/01
;		486/50 subset version. 1993/06/28
;
;
;	E X E L O A D    l i b r a l y .
;
;
;
; public subroutine.

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	PRINT	; print string.
PUBLIC	DECSTR	; val DX to dec string.
PUBLIC	INPUT	; string input.
PUBLIC	STRDEC	; dec string to DX reg.
PUBLIC	HEXSTR	; val DX to hex string.
PUBLIC	STRHEX	; hex string to DX reg.
PUBLIC	BINSTR	; val DX to bin string.
PUBLIC	STRBIN	; bin string to DX reg.
PUBLIC	CHPUT	; print of ascii character.
PUBLIC	KESCAP	; ESC key & break check & pause.
PUBLIC	KEYLOD	; key buffer read.
PUBLIC	PRNAB	; print of a register(BIN).
PUBLIC	LFPRN	; line feed.
PUBLIC	STRZTS	; zero to space. "00123" - > "  123"
PUBLIC	STRSPL	; space pless. "  123" - > "123  "

STRING_LEN 	EQU	32	; string length.

STRING_INPUT	MACRO		; string input
	MOV	AH,0AH		; 
	INT	21H		; DOS call.
	ENDM

PUTCHAR		MACRO		; character put.
	MOV	AH,06H		; 
	INT	21H		; DOS call.
	ENDM

KEY_BUFFER_READ	MACRO		; read key buffer.
	PUSH	AX		;
	MOV	DL,0FFH		;
	MOV	AH,06H		; direct console input.
	INT	21H		; DOS call.
	MOV	DL,AL		;
	XOR	DH,DH		; DH=0
	POP	AX		;
	ENDM


; print of string.
; -i- SI : string address.
;        NULL=end of string.

PRINT	PROC	NEAR

	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
PRINT1:
	MOV	AL,[SI]
	CMP	AL,0	;end of string
	JE	PRINT2

	CALL	CHPUT

	INC	SI
	JMP	PRINT1
PRINT2:
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX

	RET
PRINT	ENDP


; i*2 value -> decimal string.
; -i- DX   : i*2 value
; -o- SI   : string address.
;            NULL=end of string.

DECSTR	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX

	MOV	BX,0
	MOV	SI,OFFSET BUFFER
DECST0:	MOV	CX,WORD PTR DECST3[BX]

	XOR	AL,AL		;
DECST1:	SUB	DX,CX		;AL = DX / CX
	JB	DECST2		;
	INC	AL		;
	JMP	DECST1		;
DECST2:	ADD	DX,CX		;DX = DX mod CX

	OR	AL,30H		;char = AL+30H
	MOV	BYTE PTR[SI],AL	;

	INC	BX
	INC	BX
	INC	SI
	CMP	BX,4*2
	JB	DECST0		;next

	OR	DL,30H		;char = DL+30H
	MOV	[SI+0],DL	;

	MOV	BYTE PTR [SI+1],0	;null.
	MOV	SI,OFFSET BUFFER  	;sting adrs.

	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
DECSTR	ENDP


; sting input.
; -o- SI : string address.
;           NULL=end of string.

INPUT	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX

	MOV	BYTE PTR STRING,STRING_LEN
	MOV	DX,OFFSET STRING

	STRING_INPUT		; string input

	MOV	SI,OFFSET STRING
	INC	SI
	MOV	BL,[SI]
	MOV	BH,0
	INC	SI
	MOV	BYTE PTR [SI][BX],0	;end of string.

	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
INPUT	ENDP


; string(decimal format) -> i*2 value.
; -i- SI :string address.
;         NULL=end of string.
; -o- DX :i*2 value.

STRDEC	PROC	NEAR
STRDEC0:
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	SI

	MOV	DX,0

	MOV	AL,[SI]
	INC	SI

	CMP	AL,'+'	;if AL='+' then
	JZ	STRDEC1

	CMP	AL,'-'	;if AL<>'-'then
	JNZ	STRDEC2

	CALL	STRDEC0
	NEG	DX	; DX=-DX
	JMP	STRDEC3

STRDEC1:
	MOV	AL,[SI]	;next char.
	INC	SI	;
STRDEC2:
	SUB	AL,'0'	;if AL<'0' or
	JB	STRDEC3	;   AL>'9' then
	CMP	AL,10	;      return
	JNB	STRDEC3	;A=0...9

	MOV	CX,DX	;
	SHL	DX,1	;
	SHL	DX,1	; DX=DX*10
	ADD	DX,CX	;
	SHL	DX,1	;

	MOV	AH,0	; DX=DX+AL
	ADD	DX,AX	;
	JMP	STRDEC1

STRDEC3:
	POP	SI
	POP	CX
	POP	BX
	POP	AX
	RET
STRDEC	ENDP


; i*2 value -> hexdecimal string.
; -i- DX : i*2 value
; -o- SI : string address.
;         NULL=end of string.

HEXSTR	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX

	MOV	SI,OFFSET BUFFER

	MOV	AL,DH
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	CALL	HEXSTR3
	MOV	AL,DH
	CALL	HEXSTR3

	MOV	AL,DL
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	CALL	HEXSTR3
	MOV	AL,DL
	CALL	HEXSTR3

	MOV	BYTE PTR [SI],0	;null.
	MOV	SI,OFFSET BUFFER		;string adrs.

	POP	CX
	POP	BX
	POP	AX
	RET

HEXSTR3:AND	AL,0FH
	CMP	AL,0AH	;if AL<0ah then
	JB	HEXSTR4
	ADD	AL,07H  ; ascii 'A'-'F'
HEXSTR4:ADD	AL,30H  ; ascii '0'-'9'
	MOV	BYTE PTR [SI],AL
	INC	SI
	RET
HEXSTR	ENDP


; string(hex format) -> i*2 value.
; -i- SI :string address.
;         NULL=end of string.
; -o- DX :i*2 value.

STRHEX	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	SI

	MOV	DX,0000H

STRHE1:	MOV	AL,BYTE PTR[SI]
	INC	SI

	SUB	AL,'0'		;
	JB	STRHE3		; if char < '0' then exit

	CMP	AL,10		;
	JB	STRHE2		; if char < '9' then STRHE2

	SUB	AL,'A'-'0'	;
	JB	STRHE3		; if char < 'A' then exit
	CMP	AL,6		;
	JNB	STRHE3		; if char > 'F' then exit

	ADD	AL,10

STRHE2:	SHL	DX,1		;
	SHL	DX,1		;
	SHL	DX,1		; DX = DX * 10h
	SHL	DX,1		;
	OR	DL,AL		; DX = DX + AL
	JMP	STRHE1		; loop end

STRHE3:	POP	SI
	POP	CX
	POP	BX
	POP	AX
	RET
STRHEX	ENDP


; i*2 value -> string(bin format).
; -i- DX :i*2 value.
; -o- SI :string address.
;         NULL=end of string.

BINSTR	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX

	MOV	SI,OFFSET BUFFER
	MOV	BX,8000H
	MOV	CX,16
BINSTR1:
	MOV	AX,DX
	AND	AX,BX			; if bitX = 1 then
	JZ	BINSTR2			;   [si] = '1'
	MOV	BYTE PTR[SI],'1'	;
	JMP	BINSTR3			; else
BINSTR2:				;   [si] = '0'
	MOV	BYTE PTR[SI],'0'	;
BINSTR3:				; endif
	SHR	BX,1
	INC	SI
	LOOP	BINSTR1

	MOV	BYTE PTR [SI],0	;end of string.
	MOV	SI,OFFSET BUFFER	;string adrs.

	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
BINSTR	ENDP


; string(bin format) -> i*2 value.
; -i- SI :string address.
; -o- DX :i*2 value.

STRBIN	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	SI

	MOV	DX,0
STRBIN1:
	MOV	AL,[SI]
	INC	SI
	SUB	AL,'0'		; if [si]<'0' then exit.
	JB	STRBIN2		;
	CMP	AL,2		; if [si]>'1' then exit.
	JNB	STRBIN2		;

	SHL	DX,1		;
	OR	DL,AL		;

	JMP	STRBIN1
STRBIN2:
	POP	SI
	POP	CX
	POP	BX
	POP	AX
	RET
STRBIN	ENDP


; print of ascii character.
;  -i- AL : ascii code
;

CHPUT	PROC	NEAR
	MOV	DL,AL			; put char=DL
	PUTCHAR				; character put.
	RET
CHPUT	ENDP


CHR_ESC		EQU	1BH	; ESC code.
CHR_CTRL_S	EQU	13H	; ctrl-S
CHR_CTRL_Q	EQU	11H	; ctrl-Q
CHR_CTRL_C	EQU	03H	; ctrl-C
CHR_CTRL_CR	EQU	0DH	; CR

;	ESC key & break check & pause.
;	-o- AX : 0=normal, 1=ESC on, 2=ctrl-C,3=enter.

KESCAP	PROC	NEAR
	CALL	KEYLOD		; key buffer read.
	CMP	DX,CHR_CTRL_CR	; CR
	JNE	KESCAP1
	MOV	AX,3		; enter.
	JMP	KESCAP9
KESCAP1:
	CMP	DX,CHR_ESC	; ESC code.
	JNE	KESCAP2

	MOV	AX,1		; ESC on.
	JMP	KESCAP9
KESCAP2:
	CMP	DX,CHR_CTRL_C	; ctrl-C
	JNE	KESCAP3

	MOV	AX,2		; ctrl-C on.
	JMP	KESCAP9
KESCAP3:
	CMP	DX,CHR_CTRL_S	; ctrl-S
	JE	KESCAP4

	MOV	AX,0		; normal.
	JMP	KESCAP9
KESCAP4:
	CALL	KEYLOD		; key buffer read.

	MOV	AX,0		; normal.
	CMP	DX,CHR_CTRL_Q	; ctrl-Q
	JE	KESCAP9		;

	MOV	AX,2		; ctrl-C on.
	CMP	DX,CHR_CTRL_C	; ctrl-C
	JE	KESCAP9		;

	MOV	AX,1		; ESC on.
	CMP	DX,CHR_ESC	; ESC code.
	JE	KESCAP9		;

	JMP	KESCAP4
KESCAP9:
	RET
KESCAP	ENDP


;	key buffer read.
;	-o- DX : character code. (NULL=none)

KEYLOD	PROC	NEAR
	KEY_BUFFER_READ		; read key buffer.
	RET
KEYLOD	ENDP


; print of a register(BIN).
; -i- AH  print hexdecimal.

PRNAB	PROC	NEAR
	PUSH	SI
	PUSH	DX
	PUSH	AX
	MOV	DH,0
	MOV	DL,AH
	CALL	BINSTR	; i*2 value -> string(bin format).
	ADD	SI,8
	CALL	PRINT
	POP	AX
	POP	DX
	POP	SI
	RET
PRNAB	ENDP


; line feed.

LFPRN	PROC	NEAR
	PUSH	SI
	MOV	SI,OFFSET LFP1
	CALL	PRINT
	POP	SI
	RET
LFPRN	ENDP

; zero to space. "00123" - > "  123"
; -i- SI : string address.
;        NULL=end of string.

STRZTS	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
STRZTS1:
	CMP	BYTE PTR [SI][1],0
	JE	STRZTS2
	CMP	BYTE PTR [SI],'0'		; '0' ?
	JNE	STRZTS2

	MOV	BYTE PTR [SI],' '

	INC	SI
	JMP	STRZTS1
STRZTS2:
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
STRZTS	ENDP


; space pless. "  123" - > "123  "
; -i- SI : string address.
;        NULL=end of string.

STRSPL	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	ES

	MOV	AX,DS
	MOV	ES,AX

	MOV	DI,SI

	MOV	CX,256

	MOV	AL,' '		; space.
	REPE	SCASB		; while (es:[di++]==' ')
	JE	STRSPL9
	DEC	DI

	MOV	BX,DI		; string top.

	MOV	AL,0		; end of string.
	REPNE	SCASB		; while (es:[di++]<>0)
	JNE	STRSPL9
	DEC	DI

	MOV	CX,DI		;
	SUB	CX,BX		; string length.
	JCXZ	STRSPL9		; CX=0 ?

	MOV	DI,BX		; string top.

	XCHG	DI,SI		;

	REP	MOVSB

	MOV	AL,0
	STOSB
STRSPL9:
	POP	ES
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
STRSPL	ENDP


CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

PUBLIC DECST3
DECST3	DW	10000,1000,100,10

DBLINT	DW	0CA00H,03B9AH  ,  0E100H,005F5H  ,  09680H,00098H
	DW	04240H,0000FH  ,  086A0H,00001H  ,  10000,0
	DW	1000,0         ,  100,0          ,  10,0

;		0 1 2 3 4 5 6 7 8 9 A B C D E F . .
BUFFER	DB	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

STRING	DB	STRING_LEN		; buffer length.
	DB	0			; character length.
	DB	STRING_LEN DUP (0)	; string.
	DB	0,0
LFP1	DB	0DH,0AH,0

DATA	ENDS

	END
;
;	end of "MACLIB.ASM"
;
