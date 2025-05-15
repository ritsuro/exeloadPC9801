; "TEXTVIEW.INC" PC98series make by R.H 1993/06/29
;
;
;	text view handle.
;
;
; define.

; ƒeƒLƒXƒg‘®«E‚o‚b|‚X‚W‚O‚P‚Ìê‡
;
;	ƒAƒgƒŠƒrƒ…[ƒg•\Œ»
;	7   6   5   4     3     2     1    0____
;	‚f@‚q@‚a@‚a‚f@‚t‚k@‚q‚u@‚a‚k@‚r‚s
;	@@@@@@‚u‚k

TC_WHITE	EQU	11100001B
TC_WHITE_RV	EQU	11100101B
TC_YELLOW_UL	EQU	11001001B
TC_YELLOW_RV	EQU	11000101B
TC_CYAN		EQU	10100001B
TC_CYAN_RV	EQU	10100101B
TC_BLUE		EQU	00100001B
TC_BLUE_RV	EQU	00100101B
TC_RED_RV	EQU	01000101B
TC_FRM_LIN	EQU	10100001B


;TX_INPUT	XX,YY,COLORS			; sting input.
;		;-O- SI : string address. AX : 0=normal,3=F3,11=ESC
;TX_PRINT	XX,YY,COLORS,STRING		; print.
;TX_PRINTA	XX,YY,COLORS,ADRS		; print(offset).
;TX_PRINTV	XX,YY,COLORS,STRING,VALUE,STRING2 ; print value.
;TX_PRINTVH	XX,YY,COLORS,STRING,VALUE,STRING2 ; print value.(HEX)
;TX_REPEAT	XX,YY,COLORS,STRING,COUNT	; repert string.
;TX_CLEAR	XX,YY,COUNT			; line clear.
;TX_CLS		; clear screen.
;TX_UWAIT	; user wait.
;		;-O- AX : 0=normal,3=F3,11=ESC,12=ENTER
;TX_1TO4N	; select number 1-4.
;		;-O- AX : number 1-4.(0=none) BX : 0=normal,3=F3,11=ESC
;TX_FRAME	; frame.
;TX_FRMCLS	; frame inside clear screen.

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE

EXTRN	TXVW_INPUT:NEAR		; sting input.
EXTRN	TXVW_PRINT:NEAR		; print.
EXTRN	TXVW_PRNXT:NEAR		; print next.
EXTRN	TXVW_REPEAT:NEAR	; repert string.
EXTRN	TXVW_CLEAR:NEAR		; line clear.
EXTRN	TXVW_CLS:NEAR		; clear screen.
EXTRN	TXVW_UWAIT:NEAR		; user wait.
EXTRN	TXVW_UWAIT2:NEAR	; user wait2.(anther key)
EXTRN	TXVW_INKEY:NEAR		; user inkey.
EXTRN	TXVW_1TO4N:NEAR		; select number 1-4.
EXTRN	TXVW_FRAME:NEAR		; frame.
EXTRN	TXVW_FRAME_S:NEAR	; star frame.
EXTRN	TXVW_FRMCLS:NEAR	; frame inside clear screen.
EXTRN	TXVW_FRMCLS_S:NEAR	; star frame inside clear screen.
EXTRN	TXVW_TXVIEWMODE:NEAR	; set view text mode.
EXTRN	TXVW_RETDOSMODE:NEAR	; return to DOS text mode.

CODE	ENDS

DATA	SEGMENT	PUBLIC	'DATA'

EXTRN	STR_DRV_NUM:WORD		; drive name.

DATA	ENDS

;	sting input.
;	-O- SI : string address.
;	    AX : 0=normal,3=F3,11=ESC

TX_INPUT	MACRO	XX,YY,COLORS
	MOV	AX,XX
	MOV	BX,YY
	MOV	DX,COLORS
	CALL	TXVW_INPUT		; sting input.
	ENDM


;	print.

TX_PRINT	MACRO	XX,YY,COLORS,STRING
	LOCAL	L1
DATA	SEGMENT	PUBLIC	'DATA'
L1	DB	STRING,0
DATA	ENDS
	MOV	AX,XX
	MOV	BX,YY
	MOV	DX,COLORS
	MOV	SI,OFFSET L1
	CALL	TXVW_PRINT		; print.
	ENDM

;	print(offset).

TX_PRINTA	MACRO	XX,YY,COLORS,ADRS
	MOV	SI,ADRS
	MOV	AX,XX
	MOV	BX,YY
	MOV	DX,COLORS
	CALL	TXVW_PRINT		; print.
	ENDM


;	print value.

TX_PRINTV	MACRO	XX,YY,COLORS,STRING,VALUE,STRING2
	LOCAL	L1,L2
DATA	SEGMENT	PUBLIC	'DATA'
L1	DB	STRING,0
L2	DB	STRING2,0
DATA	ENDS
	MOV	AX,XX
	MOV	BX,YY
	MOV	DX,COLORS
	MOV	SI,OFFSET L1
	CALL	TXVW_PRINT		; print.
	MOV	DX,VALUE
	CALL	DECSTR
	CALL	STRZTS	; zero to space. "00123" - > "  123"
	CALL	STRSPL	; space pless. "  123" - > "123  "
	CALL	TXVW_PRNXT		; print next.
	MOV	SI,OFFSET L2
	CALL	TXVW_PRNXT		; print next.
	ENDM

;	print value.(HEX)

TX_PRINTVH	MACRO	XX,YY,COLORS,STRING,VALUE,STRING2
	LOCAL	L1,L2
DATA	SEGMENT	PUBLIC	'DATA'
L1	DB	STRING,0
L2	DB	STRING2,0
DATA	ENDS
	MOV	AX,XX
	MOV	BX,YY
	MOV	DX,COLORS
	MOV	SI,OFFSET L1
	CALL	TXVW_PRINT		; print.
	MOV	DX,VALUE
	CALL	HEXSTR
;;	CALL	STRZTS	; zero to space. "00123" - > "  123"
;;	CALL	STRSPL	; space pless. "  123" - > "123  "
	CALL	TXVW_PRNXT		; print next.
	MOV	SI,OFFSET L2
	CALL	TXVW_PRNXT		; print next.
	ENDM


;	repert string.

TX_REPEAT	MACRO	XX,YY,COLORS,STRING,COUNT
	LOCAL	L1
DATA	SEGMENT	PUBLIC	'DATA'
L1	DB	STRING,0
DATA	ENDS
	MOV	AX,XX
	MOV	BX,YY
	MOV	DX,COLORS
	MOV	CX,COUNT
	MOV	SI,OFFSET L1
	CALL	TXVW_REPEAT		; repert string.
	ENDM

;	line clear.

TX_CLEAR	MACRO	XX,YY,COUNT
	PUSH	AX
	MOV	AX,XX
	MOV	BX,YY
	MOV	CX,COUNT
	CALL	TXVW_CLEAR		; line clear.
	POP	AX
	ENDM


;	clear screen.

TX_CLS	MACRO
	CALL	TXVW_CLS		; clear screen.
	ENDM

;	user wait.
;	-O- AX : 3=F3,11=ESC,12=ENTER

TX_UWAIT	MACRO
	CALL	TXVW_UWAIT		; user wait.
	ENDM


;	select number 1-4.
;	-O- AX : number 1-4.(0=none)
;	    BX : 0=normal,3=F3,11=ESC

TX_1TO4N	MACRO
	CALL	TXVW_1TO4N		; select number 1-4.
	ENDM


;	frame.

TX_FRAME	MACRO
	CALL	TXVW_FRAME		; frame.
;;	CALL	TXVW_FRAME_S		; star frame.
	ENDM

;	frame inside clear screen.

TX_FRMCLS	MACRO
	CALL	TXVW_FRMCLS		; frame inside clear screen.
;;	CALL	TXVW_FRMCLS_S		; star frame inside clear screen.
	ENDM

;	frame.

TX_FRAME_D	MACRO
;;	CALL	TXVW_FRAME		; frame.
	CALL	TXVW_FRAME_S		; star frame.
	ENDM

;	frame inside clear screen.

TX_FRMCLS_D	MACRO
;;	CALL	TXVW_FRMCLS		; frame inside clear screen.
	CALL	TXVW_FRMCLS_S		; star frame inside clear screen.
	ENDM

;
;	end of "TEXTVIEW.INC"
;
