; "SSTYPE.ASM" PC-9801UV11 make by R.H 1989/11/10
;
;	E X E L O A D     T Y P E   c o m m a n d .
;
;
;
; command.

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:DATA

PUBLIC	CMTYPE			; テキストファイルの表示

EXTRN	FFOPEN:NEAR		; ファイルオープン
EXTRN	FFCLOS:NEAR		; ファイルクローズ
EXTRN	FFREAD:NEAR		; ファイルの読み出し
EXTRN	PRINT:NEAR		; 文字列の表示
EXTRN	KESCAP:NEAR		; ESC key & break check & pause.


BUFF_LEN	EQU	4	; string buffer length.
CHR_CR		EQU	0DH	; calig return.
CHR_LF		EQU	0AH	; line feed.


;
;	ＴＹＰＥ
;	-I- DS:SI : ファイル名
;	-O- AX    : 0=正常, 1=該当ファイル無し, 2=ディスクエラー

CMTYPE	PROC	NEAR
	CALL	FFOPEN		; ファイルオープン
	CMP	AX,1		; file not found.
	JE	CMTYPE99	;
	CMP	AX,2		; ディスクエラー
	JE	CMTYPE_ERR_OPEN	;

	MOV	AX,SEG DATA
	MOV	ES,AX
CMTYPE2:
	MOV	DI,OFFSET STRING_BUFF	; string buffer.
	MOV	CX,BUFF_LEN		; string buffer length.
	CALL	FFREAD			; ファイルの読み出し
	CMP	AX,2			; ディスクエラー
	JE	CMTYPE_ERROR		;
	CMP	AX,1			; E.O.F
	JE	CMTYPE8			;

	MOV	SI,OFFSET STRING_BUFF	; string buffer.
	CALL	PRINT			; 表示

	CALL	KESCAP		; ESC key & break check & pause.
	CMP	AX,0
	JNE	CMTYPE_BREAK

	JMP	CMTYPE2
CMTYPE8:	
	CALL	FFCLOS			; ファイルクローズ

	MOV	SI,OFFSET MSG_MARK	; Ｅ．Ｏ．Ｆマーク
	CALL	PRINT		;
	MOV	AX,0		; normal.
	RET
CMTYPE99:
	MOV	SI,OFFSET MSG_NOT_FOUND
	CALL	PRINT		;
	MOV	AX,1		; file not found.
	RET
CMTYPE_ERROR:
	MOV	SI,OFFSET MSG_DISK_ERROR
	CALL	PRINT		;
	MOV	AX,2		; ディスクエラー
	RET
CMTYPE_ERR_OPEN:
	MOV	SI,OFFSET MSG_OPEN_ERROR
	CALL	PRINT		;
	MOV	AX,2		; ディスクエラー
	RET
CMTYPE_BREAK:
	MOV	SI,OFFSET MSG_BREAK
	CALL	PRINT		; 処理中断
	MOV	AX,0		; normal.
	RET
CMTYPE	ENDP

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

STRING_BUFF	DB	BUFF_LEN DUP (0)	; string buffer.
STRING_END	DB	0			;
MSG_MARK	DB	"[EOF]",CHR_CR,CHR_LF,0	; Ｅ．Ｏ．Ｆマーク
MSG_BREAK	DB	"[break]",CHR_CR,CHR_LF,0 ; 処理中断
MSG_NOT_FOUND	DB	"ファイルが見つかりません",CHR_CR,CHR_LF,0
MSG_DISK_ERROR	DB	"ディスクエラー",CHR_CR,CHR_LF,0
MSG_OPEN_ERROR	DB	"オープンエラー",CHR_CR,CHR_LF,0

DATA	ENDS
	END
;
;	end of "SSTYPE.ASM"
;
