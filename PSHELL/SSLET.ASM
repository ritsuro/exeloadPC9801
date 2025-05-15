; "SSLET.ASM" PC-9801UV11 make by R.H 1989/11/18
;
;	E X E L O A D     L E T   c o m m a n d .
;
;
;
; command.

;	ŒvŽZ‹@”\

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	CMLET			; ŒvŽZ‹@”\

EXTRN	PRNAH:NEAR	;print ah reg.
EXTRN	PRINT:NEAR	;print string.
EXTRN	DECSTR:NEAR	;val DX to dec string.
EXTRN	INPUT:NEAR	;string input.
EXTRN	STRDEC:NEAR	;dec string to DX reg.
EXTRN	HEXSTR:NEAR	;val DX to hex string.
EXTRN	STRHEX:NEAR	;hex string to DX reg.
EXTRN	BINSTR:NEAR	;val DX to bin string.
EXTRN	STRBIN:NEAR	;bin string to DX reg.
EXTRN	PRINT:NEAR	; •¶Žš—ñ‚Ì•\Ž¦

;
;	‚k‚d‚s
;	-I- DS:SI : ŒvŽZŽ®

CMLET	PROC	NEAR
	CALL	STRDEC
	MOV	UVALUE,DX

	MOV	SI,OFFSET MSG_10
	CALL	PRINT
	MOV	DX,UVALUE
	CALL	DECSTR
	CALL	PRINT

	MOV	SI,OFFSET MSG_2
	CALL	PRINT
	MOV	DX,UVALUE
	CALL	BINSTR
	CALL	PRINT

	MOV	SI,OFFSET MSG_16
	CALL	PRINT
	MOV	DX,UVALUE
	CALL	HEXSTR
	CALL	PRINT

	MOV	SI,OFFSET MSG_CRLF	; CR+LF
	CALL	PRINT

	RET
CMLET	ENDP

CODE	ENDS

CHR_CR		EQU	0DH		; calig return.
CHR_LF		EQU	0AH		; line feed.

DATA	SEGMENT	PUBLIC	'DATA'

UVALUE		DW	0		; string address.

MSG_2		DB	" (2)",0
MSG_10		DB	" (10)",0
MSG_16		DB	" (16)",0
MSG_CRLF	DB	CHR_CR,CHR_LF,0

DATA	ENDS
	END
;
;	end of "SSLET.ASM"
;
