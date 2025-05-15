; "TEXTVIEW.ASM" PC98series make by R.H 1993/06/29
;
;
;	text view handle.
;
;
; public subroutine.

STRING_LEN	EQU	32	; string length.

TC_WHITE	EQU	11100001B
TC_FRM_LIN	EQU	10100001B
TC_FRM_D_LIN	EQU	11000001B

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	TXVW_INPUT		; sting input.
PUBLIC	TXVW_PRINT		; print.
PUBLIC	TXVW_PRNXT		; print next.
PUBLIC	TXVW_REPEAT		; repert string.
PUBLIC	TXVW_CLEAR		; line clear.
PUBLIC	TXVW_CLS		; clear screen.
PUBLIC	TXVW_UWAIT		; user wait.
PUBLIC	TXVW_UWAIT2		; user wait2.(anther key)
PUBLIC	TXVW_INKEY		; user inkey.
PUBLIC	TXVW_1TO4N		; select number 1-4.
PUBLIC	TXVW_FRAME		; frame.
PUBLIC	TXVW_FRAME_S		; star frame.
PUBLIC	TXVW_FRMCLS		; frame inside clear screen.
PUBLIC	TXVW_FRMCLS_S		; star frame inside clear screen.
PUBLIC	TXVW_TXVIEWMODE		; set view text mode.
PUBLIC	TXVW_RETDOSMODE		; return to DOS text mode.

EXTRN	CCCIN:NEAR		; console in.
EXTRN	CCCOUT:NEAR		; print character.
EXTRN	CCCRD:NEAR		; read key buffer.
EXTRN	CCCLOC:NEAR		; locate.
EXTRN	CCCCOL:NEAR		; text color.
EXTRN	CCCCLA:NEAR		; text color&attribute.
EXTRN	CCCCGT:NEAR		; text color&attribute get.
EXTRN	CCCINB:NEAR		; console in + break on.
EXTRN	CCCFKY:NEAR		; function key.
EXTRN	CCCKCR:NEAR		; key buffer clear.
EXTRN	CCCKIN:NEAR		; key in.


; ****************************************************
;	sting input.
;	-I- AX : locate x.
;	    BX : locate y.
;	    DX : text color&attribute.
;	-O- SI : string address.
;	    AX : 0=normal,3=F3,11=ESC
; ****************************************************

TXVW_INPUT	PROC	NEAR
	CALL	CCCLOC		; locate.
	MOV	AX,DX		; text color&attribute.
	CALL	CCCCLA		; text color&attribute.

	MOV	STRING,STRING_LEN
	MOV	DX,OFFSET STRING
	CALL	CCCINB		; console in + break on.

	MOV	SI,OFFSET STRING
	INC	SI
	MOV	BL,[SI]
	MOV	BH,0
	INC	SI
	MOV	BYTE PTR [SI][BX],0	;end of string.

	RET
TXVW_INPUT	ENDP


; ****************************************************
;	print.
;	-I- SI : string address.
;	    AX : locate x.
;	    BX : locate y.
;	    DX : text color&attribute.
; ****************************************************

TXVW_PRINT	PROC	NEAR
	CALL	CCCLOC		; locate.
	MOV	AX,DX		; text color&attribute.
	CALL	CCCCLA		; text color&attribute.
TXVW_PRINT_LOOP:
	MOV	DL,DS:[SI]
	CMP	DL,0	;end of string
	JE	TXVW_PRINT_EXIT

	CALL	CCCOUT		; print character.

	INC	SI
	JMP	TXVW_PRINT_LOOP
TXVW_PRINT_EXIT:
	RET
TXVW_PRINT	ENDP


; ****************************************************
;	print next.
;	-I- SI : string address.
; ****************************************************

TXVW_PRNXT	PROC	NEAR
TXVW_PRNXT_LOOP:
	MOV	DL,[SI]
	CMP	DL,0	;end of string
	JE	TXVW_PRNXT_EXIT

	CALL	CCCOUT		; print character.

	INC	SI
	JMP	TXVW_PRNXT_LOOP
TXVW_PRNXT_EXIT:
	RET
TXVW_PRNXT	ENDP


; ****************************************************
;	repert string.
;	-I- SI : string address.
;	    CX : repart count.
;	    AX : locate x.
;	    BX : locate y.
;	    DX : text color&attribute.
; ****************************************************

TXVW_REPEAT	PROC	NEAR
	CALL	CCCLOC		; locate.
	MOV	AX,DX		; text color&attribute.
	CALL	CCCCLA		; text color&attribute.

	JCXZ	TXVW_REPEAT_EXIT
TXVW_REPEAT_LOOP:
	PUSH	CX
	PUSH	SI
TXVW_REPEAT_LOOP2:
	MOV	DL,[SI]
	CMP	DL,0	;end of string
	JE	TXVW_REPEAT_NEXT
	CALL	CCCOUT		; print character.
	INC	SI
	JMP	TXVW_REPEAT_LOOP2
TXVW_REPEAT_NEXT:
	POP	SI
	POP	CX
	LOOP	TXVW_REPEAT_LOOP
TXVW_REPEAT_EXIT:
	RET
TXVW_REPEAT	ENDP


; ****************************************************
;	line clear.
;	-I- AX : locate x.
;	    BX : locate y.
;	    CX : length.
; ****************************************************

TXVW_CLEAR	PROC	NEAR
	CALL	CCCLOC		; locate.
	MOV	AX,0
	CALL	CCCCLA		; text color&attribute.

	JCXZ	TXVW_CLEAR_EXIT
TXVW_CLEAR_LOOP:
	PUSH	CX
	MOV	DL,' '
	CALL	CCCOUT		; print character.
	POP	CX
	LOOP	TXVW_CLEAR_LOOP
TXVW_CLEAR_EXIT:
	RET
TXVW_CLEAR	ENDP


; ****************************************************
;	clear screen.
; ****************************************************

TXVW_CLS	PROC	NEAR
	MOV	ES,ATTR_VRAM_SEG	; attribute vram address.
	MOV	DI,0			;
	MOV	CX,80*25		;
	MOV	AX,11100001B		; attribute.
	REP	STOSW			; char=2byte.

	MOV	ES,TEXT_VRAM_SEG	; text vram address.
	MOV	DI,0			;
	MOV	CX,80*25		;
	MOV	AX,20H			; text.
	REP	STOSW			; char=2byte.
	RET
TXVW_CLS	ENDP


; ****************************************************
;	user wait.
;	-O- AX : 3=F3,11=ESC,12=ENTER
; ****************************************************

TXVW_UWAIT	PROC	NEAR
	CALL	CCCKCR		; key buffer clear.
TXVW_UWAIT_LOOP:
	CALL	CCCFKY		; function key.
	CMP	AL,3
	JE	TXVW_UWAIT_EXIT
	CMP	AL,11
	JE	TXVW_UWAIT_EXIT
	CMP	AL,12
	JE	TXVW_UWAIT_EXIT
	JMP	TXVW_UWAIT_LOOP
TXVW_UWAIT_EXIT:
	RET
TXVW_UWAIT	ENDP


; ****************************************************
;	user wait2.(anther key)
; ****************************************************

TXVW_UWAIT2	PROC	NEAR
	PUSH	AX
	PUSH	BX
	CALL	CCCKCR		; key buffer clear.
TXVW_UWAIT2_LOOP:
	CALL	CCCKIN		; key in.
	CMP	AX,0		; character code. (NULL=none)
	JNE	TXVW_UWAIT2_EXIT
	CMP	BL,0		; 0=none
	JNE	TXVW_UWAIT2_EXIT
	JMP	TXVW_UWAIT2_LOOP
TXVW_UWAIT2_EXIT:
	POP	BX
	POP	AX
	RET
TXVW_UWAIT2	ENDP


; ****************************************************
;	user inkey.
;	-O- AX : character code. (NULL=none)
;	    BL : 0=none,1=F1,2=F2,3=F3,4=F4,5=F5,6=F6,7=F7,8=F8,9=F9,10=F10
;			11=ESC
; ****************************************************

TXVW_INKEY	PROC	NEAR
	CALL	CCCKIN			; key in.
	RET
TXVW_INKEY	ENDP


; ****************************************************
;	select number 1-4.
;	-O- AX : number 1-4.(0=none)
;	    BX : 0=normal,3=F3,11=ESC
; ****************************************************

TXVW_1TO4N	PROC	NEAR
	CALL	CCCKCR		; key buffer clear.

TXVW_1TO4N_LOOP:
	CALL	CCCKIN		; key in.
	CMP	BL,3		; F3
	JE	TXVW_1TO4N_ESC
	CMP	BL,11		; ESC
	JE	TXVW_1TO4N_ESC

	CMP	BL,0
	JNE	TXVW_1TO4N_NEXT

	CMP	AX,0			; character code. (NULL=none)
	JE	TXVW_1TO4N_NEXT

	CMP	AX,'1'
	JB	TXVW_1TO4N_NEXT
	CMP	AX,'4'
	JNBE	TXVW_1TO4N_NEXT

	SUB	AX,'0'
	JMP	TXVW_1TO4N_EXIT
TXVW_1TO4N_NEXT:
	JMP	TXVW_1TO4N_LOOP
TXVW_1TO4N_EXIT:
	RET
TXVW_1TO4N_ESC:
	MOV	AX,0
	RET
TXVW_1TO4N	ENDP


;	frame.

TXVW_FRAME	PROC	NEAR
	MOV	SI,OFFSET STR_TITLE	;"‚Q‚g‚cƒfƒBƒXƒNƒRƒs[",0
	MOV	AX,0			; locate x.
	MOV	BX,0			; locate y.
	MOV	DX,TC_WHITE		; text color&attribute.
	CALL	TXVW_PRINT		; print.

	MOV	SI,OFFSET STR_LN1	;
	MOV	AX,0			; locate x.
	MOV	BX,1			; locate y.
	MOV	DX,TC_FRM_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.

	MOV	SI,OFFSET STR_LN2	;
	MOV	AX,0			; locate x.
	MOV	BX,23			; locate y.
	MOV	DX,TC_FRM_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.

	RET
TXVW_FRAME	ENDP


;	star frame.

TXVW_FRAME_S	PROC	NEAR
	MOV	SI,OFFSET STR_TITLE	;"‚Q‚g‚cƒfƒBƒXƒNƒRƒs[",0
	MOV	AX,0			; locate x.
	MOV	BX,0			; locate y.
	MOV	DX,TC_WHITE		; text color&attribute.
	CALL	TXVW_PRINT		; print.

	MOV	SI,OFFSET STR_LN1D	;
	MOV	AX,0			; locate x.
	MOV	BX,1			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.

	MOV	SI,OFFSET STR_LN11D	;
	MOV	AX,0			; locate x.
	MOV	BX,2			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	MOV	SI,OFFSET STR_LN12D	;
	MOV	AX,0			; locate x.
	MOV	BX,3			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	MOV	SI,OFFSET STR_LN13D	;
	MOV	AX,0			; locate x.
	MOV	BX,4			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	MOV	SI,OFFSET STR_LN14D	;
	MOV	AX,0			; locate x.
	MOV	BX,5			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	MOV	SI,OFFSET STR_LN21D	;
	MOV	AX,0			; locate x.
	MOV	BX,21			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	MOV	SI,OFFSET STR_LN22D	;
	MOV	AX,0			; locate x.
	MOV	BX,22			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.

	MOV	SI,OFFSET STR_LN2D	;
	MOV	AX,0			; locate x.
	MOV	BX,23			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.

	RET
TXVW_FRAME_S	ENDP


;	frame inside clear screen.

TXVW_FRMCLS	PROC	NEAR
	MOV	ES,ATTR_VRAM_SEG	; attribute vram address.
	MOV	DI,80*2*2		;
	MOV	CX,80*21		;
	MOV	AX,11100001B		; attribute.
	REP	STOSW			; char=2byte.

	MOV	ES,TEXT_VRAM_SEG	; text vram address.
	MOV	DI,80*2*2		;
	MOV	CX,80*21		;
	MOV	AX,20H			; text.
	REP	STOSW			; char=2byte.
	RET
TXVW_FRMCLS	ENDP


;	star frame inside clear screen.

TXVW_FRMCLS_S	PROC	NEAR
	CALL	TXVW_FRMCLS		; frame inside clear screen.
	MOV	SI,OFFSET STR_LN11D	;
	MOV	AX,0			; locate x.
	MOV	BX,2			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	MOV	SI,OFFSET STR_LN12D	;
	MOV	AX,0			; locate x.
	MOV	BX,3			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	MOV	SI,OFFSET STR_LN13D	;
	MOV	AX,0			; locate x.
	MOV	BX,4			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	MOV	SI,OFFSET STR_LN14D	;
	MOV	AX,0			; locate x.
	MOV	BX,5			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.

	MOV	SI,OFFSET STR_LN21D	;
	MOV	AX,0			; locate x.
	MOV	BX,21			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	MOV	SI,OFFSET STR_LN22D	;
	MOV	AX,0			; locate x.
	MOV	BX,22			; locate y.
	MOV	DX,TC_FRM_D_LIN		; text color&attribute.
	CALL	TXVW_PRINT		; print.
	RET
TXVW_FRMCLS_S	ENDP


;	set view text mode.

TXVW_TXVIEWMODE	PROC	NEAR
	CALL	CSLOFF			; cursole off.
	CALL	TXVW_CLS		; clear screen.
	RET
TXVW_TXVIEWMODE	ENDP


;	return to DOS text mode.

TXVW_RETDOSMODE	PROC	NEAR
	CALL	CSLON			; cursole on.
	CALL	TXVW_CLS		; clear screen.
	RET
TXVW_RETDOSMODE	ENDP


;	cursole on.

CSLON	PROC	NEAR
	PUSH	AX
	MOV	AH,11H
	INT	18H
	POP	AX
	RET
CSLON	ENDP


;	cursole off.

CSLOFF	PROC	NEAR
	PUSH	AX
	MOV	AH,12H
	INT	18H
	POP	AX
	RET
CSLOFF	ENDP


CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

PUBLIC	STR_DRV_NUM				; drive name.

TEXT_VRAM_SEG	DW	0A000H			; text vram address.
ATTR_VRAM_SEG	DW	0A200H			; attribute vram address.

STR_LN1	DB	"†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢  GAINAX 1993 †¢",0
STR_LN2	DB	"†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢†¢  2HD disk copy program.†¢",0

STR_LN1D DB	"šššššššššššššššššššššššššššššššššššššššš",0
STR_LN11D DB	"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@E@D@@@",0
STR_LN12D DB	"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@š@@D@",0
STR_LN13D DB	"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@D@@E@@@",0
STR_LN14D DB	"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@D@@D@",0
STR_LN21D DB	"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@zzz..  ",0
STR_LN22D DB	"@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@£ £@@",0
STR_LN2D DB	"šššššššššššššššššššššššššššššššššššššššš",0

STR_TITLE	DB	"‚Q‚g‚cƒfƒBƒXƒNƒRƒs[ ver1.0",0

STR_DRV_NUM	DW	SDRV0,SDRV1,SDRV2,SDRV3		; drive name.
SDRV0		DB	"‚P",0
SDRV1		DB	"‚Q",0
SDRV2		DB	"‚R",0
SDRV3		DB	"‚S",0


STRING	DB	STRING_LEN		; buffer length.
	DB	0			; character length.
	DB	STRING_LEN DUP (0)	; string.
	DB	0,0

DATA	ENDS

	END
;
;	end of "TEXTVIEW.ASM"
;
