; "IPLSYS.ASM" PC-9801UV11 make by R.H 1989/12/01
;
;	E X E L O A D    I P L   k i t .
;
;	I P L   &   s y s t e m    w r i t e .
;
;	ＩＰＬとシステムの書き込み

INCLUDE	TSTSET.INC

SEC_BYTE	EQU	1024	; セクタバイト数

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,SS:STACK,ES:DATA

EXTRN	SYSSET:NEAR		; システムの２ＨＤＦＤへの転送

START:	PUSH	DS

	MOV	AX,SEG DATA
	MOV	DS,AX

	MOV	AX,SS			; stack segment.
	MOV	SAVE_SS,AX		;
	MOV	SAVE_SP,SP		; stack pointer.

	MOV	AX,SEG STACK		; stack segment.
	MOV	SS,AX			;
	MOV	SP,OFFSET TOP_OF_STACK	; stack pointer.

	CALL	MAIN

	MOV	AX,SAVE_SS		;
	MOV	SS,AX			; stack segment.
	MOV	SP,SAVE_SP		; stack pointer.

	POP	DS
FINALE:	MOV	AH,4CH
	MOV	AL,0
	INT	21H

MAIN	PROC	NEAR
	CALL	CLS

PRF "IPLSYS/EXELOAD ver0.28 (C) R.Hashimoto 1989-1993 in shimorenjaku."

	PRF	"システムの書き込み"
	INP	"１ＭＦＤドライブ番号は？（１、２、３、４）"
	CALL	STRDEC
	MOV	AX,DX			; １ＭＦＤドライブ番号
	DEC	AX			;
	MOV	DRIVE_NUMBER,AX

INP "１ＭＦＤドライブにシステムを書き込みますか？（Ｑ＝やっやだ！やめてぇ）"

	CALL	SYSTEM_WRITE		; システム書き込み

	RET
MAIN	ENDP


;	システムの書き込み

SYSTEM_WRITE	PROC	NEAR
	CALL	DISKRESET		; ディスクのリセット

	MOV	DX,DRIVE_NUMBER		; ドライブ番号
	CALL	SYSSET			; システムの２ＨＤＦＤへの転送
	RET
SYSTEM_WRITE	ENDP


;	ディスクのリセット

DISKRESET	PROC	NEAR
	MOV	AH,0DH		; disk reset.
	INT	21H		; dos function.
	RET
DISKRESET	ENDP


CODE	ENDS

DATA	SEGMENT	PUBLIC	'DATA'

DRIVE_NUMBER	DW	0	; ドライブ番号

NUM	DW	0	; counter.

SAVE_SS	DW	0	; stack segment.
SAVE_SP	DW	0	; stack pointer.

BUFFSET	DB	1024 DUP (0)	; バッファ


DATA	ENDS


STACK	SEGMENT	STACK
	DB	10000 DUP (?)
TOP_OF_STACK	LABEL	WORD
STACK	ENDS

	END	START
;
;	end of "IPLSYS.ASM"
;
