; "TSTSET.INC" PC-9801UV11 make by R.H 1989/10/24
;
;	E X E L O A D    p r i n t   m a c r o .
;
;
;
; public subroutine.


;	‚o‚q	h•\Ž¦•¶Žš—ñh
;	i‰üs–³‚µƒvƒŠƒ“ƒgj

PR	MACRO	STRING
	LOCAL	L1,L2
	PUSH	SI
	JMP	L2
DATA	SEGMENT WORD	PUBLIC	'DATA'
	EVEN
L1	DB	STRING,0
	EVEN
DATA	ENDS
L2:	MOV	SI,OFFSET L1
	CALL	PRINT
	POP	SI
	ENDM


;	‚o‚q‚e	h•\Ž¦•¶Žš—ñh
;	i‰üs—L‚èƒvƒŠƒ“ƒgj

PRF	MACRO	STRING
	LOCAL	L1,L2
	PUSH	SI
	JMP	L2
DATA	SEGMENT WORD	PUBLIC	'DATA'
	EVEN
L1	DB	STRING,0
	EVEN
DATA	ENDS
L2:	MOV	SI,OFFSET L1
	CALL	PRINT
	POP	SI
	CALL	LFPRN	; line feed.
	ENDM


;	‚h‚m‚o	h•\Ž¦•¶Žš—ñh
;	i•¶Žš—ñ‚Ì“ü—Íj@o—Í@‚c‚rF‚r‚h“ü—Í•¶Žš—ñ—p
;		“à•”ƒoƒbƒtƒ@‚Ìæ“ªƒAƒhƒŒƒXiNULL=end of stringj

INP	MACRO	STRING
	LOCAL	L1,L2,L3,L4,L5
	PUSH	SI
	JMP	L2
DATA	SEGMENT WORD	PUBLIC	'DATA'
	EVEN
L1	DB	STRING,0
	EVEN
DATA	ENDS
L2:	MOV	SI,OFFSET L1
	CALL	PRINT
	POP	SI
	CALL	INPUT
	CALL	LFPRN	; line feed.
	CMP	WORD PTR [SI],'Q'	;exit.
	JNZ	L3
	RET
L3:
	ENDM


;	‚k‚e
;	i‰üsj

LF	MACRO
	CALL	LFPRN	; line feed.
	ENDM


;	‚o‚q‚r	h•\Ž¦•¶Žš—ñhC‚r‚s‚q‚h‚m‚f
;	i‰üs—L‚è•¶Žš—ñƒvƒŠƒ“ƒgj

PRS	MACRO	STRING,PARAM
	LOCAL	L1,L2
	PUSH	SI
	PUSH	DX
	PUSH	SI
	JMP	L2
DATA	SEGMENT WORD	PUBLIC	'DATA'
	EVEN
L1	DB	STRING,0
	EVEN
DATA	ENDS
L2:	MOV	SI,OFFSET L1
	CALL	PRINT
	POP	SI
	MOV	SI,OFFSET PARAM
	CALL	PRINT
	POP	DX
	POP	SI
	CALL	LFPRN	; line feed.
	ENDM


;	‚o‚q‚r‚`	h•\Ž¦•¶Žš—ñhC•¶Žš—ñƒAƒhƒŒƒX
;	i‰üs—L‚è•¶Žš—ñƒvƒŠƒ“ƒgj

PRSA	MACRO	STRING,PARAM
	LOCAL	L1,L2
	PUSH	SI
	PUSH	DX
	PUSH	SI
	JMP	L2
DATA	SEGMENT WORD	PUBLIC	'DATA'
	EVEN
L1	DB	STRING,0
	EVEN
DATA	ENDS
L2:	MOV	SI,OFFSET L1
	CALL	PRINT
	POP	SI
	MOV	SI,PARAM
	CALL	PRINT
	POP	DX
	POP	SI
	CALL	LFPRN	; line feed.
	ENDM



;	‚o‚q‚u	h•\Ž¦•¶Žš—ñhC‚v‚n‚q‚cQ‚u‚`‚k
;	i‰üs—L‚èƒ[ƒh’lƒvƒŠƒ“ƒg‚P‚Oij

PRV	MACRO	STRING,PARAM
	LOCAL	L1,L2
	PUSH	SI
	PUSH	DX
	PUSH	SI
	JMP	L2
DATA	SEGMENT WORD	PUBLIC	'DATA'
	EVEN
L1	DB	STRING,0
	EVEN
DATA	ENDS
L2:	MOV	SI,OFFSET L1
	CALL	PRINT
	POP	SI
	MOV	DX,PARAM
	CALL	DECSTR
	CALL	PRINT
	POP	DX
	POP	SI
	CALL	LFPRN	; line feed.
	ENDM



;	‚o‚q‚u‚g	h•\Ž¦•¶Žš—ñhC‚v‚n‚q‚cQ‚u‚`‚k
;	i‰üs—L‚èƒ[ƒh’lƒvƒŠƒ“ƒg‚P‚Uij

PRVH	MACRO	STRING,PARAM
	LOCAL	L1,L2
	PUSH	SI
	PUSH	DX
	PUSH	SI
	JMP	L2
DATA	SEGMENT WORD	PUBLIC	'DATA'
	EVEN
L1	DB	STRING,0
	EVEN
DATA	ENDS
L2:	MOV	SI,OFFSET L1
	CALL	PRINT
	POP	SI
	MOV	DX,PARAM
	CALL	HEXSTR
	CALL	PRINT
	POP	DX
	POP	SI
	CALL	LFPRN	; line feed.
	ENDM


;	‚o‚q‚u‚a	h•\Ž¦•¶Žš—ñhC‚v‚n‚q‚cQ‚u‚`‚k
;	i‰üs—L‚èƒ[ƒh’lƒvƒŠƒ“ƒg‚Qij

PRVB	MACRO	STRING,PARAM
	LOCAL	L1,L2
	PUSH	SI
	PUSH	DX
	PUSH	SI
	JMP	L2
DATA	SEGMENT WORD	PUBLIC	'DATA'
	EVEN
L1	DB	STRING,0
	EVEN
DATA	ENDS
L2:	MOV	SI,OFFSET L1
	CALL	PRINT
	POP	SI
	MOV	DX,PARAM
	CALL	BINSTR
	CALL	PRINT
	POP	DX
	POP	SI
	CALL	LFPRN	; line feed.
	ENDM


;	‚o‚q‚b‚g
;	i‚PƒLƒƒƒ‰ƒNƒ^ƒvƒŠƒ“ƒgj@“ü—Í@‚`‚gƒLƒƒƒ‰ƒNƒ^ƒR[ƒh

PRCH	MACRO
	LOCAL	L1
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	CMP	AH,20H
	JNB	L1
	MOV	AH,'.'
L1:
	MOV	AL,AH
	CALL	CHPUT	;print of ascii character.
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	ENDM


MOVX	MACRO	DEST,SOU
	MOV	AX,SOU
	MOV	DEST,AX
	ENDM

ADDX	MACRO	DEST,SOUR
	MOV	AX,SOUR
	ADD	DEST,AX
	ENDM

SUBX	MACRO	DEST,SOUR
	MOV	AX,SOUR
	SUB	DEST,AX
	ENDM

CMPX	MACRO	DEST,SOUR
	MOV	AX,SOUR
	CMP	DEST,AX
	ENDM

SHLX	MACRO	DEST,SOUR
	MOV	CL,SOUR
	SHL	DEST,CL
	ENDM

SHRX	MACRO	DEST,SOUR
	MOV	CL,SOUR
	SHR	DEST,CL
	ENDM

CODE	SEGMENT WORD	PUBLIC	'CODE'

	ASSUME	CS:CODE

EXTRN	PRINT:NEAR	; print string.
EXTRN	DECSTR:NEAR	; val DX to dec string.
EXTRN	INPUT:NEAR	; string input.
EXTRN	STRDEC:NEAR	; dec string to DX reg.
EXTRN	HEXSTR:NEAR	; val DX to hex string.
EXTRN	STRHEX:NEAR	; hex string to DX reg.
EXTRN	BINSTR:NEAR	; val DX to bin string.
EXTRN	STRBIN:NEAR	; bin string to DX reg.
EXTRN	CHPUT:NEAR	; print of ascii character.
EXTRN	KESCAP:NEAR	; ESC key & break check & pause.
EXTRN	KEYLOD:NEAR	; key buffer read.
EXTRN	PRNAB:NEAR	; print of a register(BIN).
EXTRN	LFPRN:NEAR	; line feed.
EXTRN	STRZTS:NEAR	; zero to space. "00123" - > "  123"
EXTRN	STRSPL:NEAR	; space pless. "  123" - > "123  "

CODE	ENDS

;
;	end of "TSTSET.INC"
;
