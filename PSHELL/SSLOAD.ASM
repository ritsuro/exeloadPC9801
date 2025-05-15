; "SSLOAD.ASM" PC-9801UV11 make by R.H 1989/11/10
;
;	E X E L O A D     L O A D    c o m m a n d .
;
;
;
; command.

INCLUDE	TSTSET.INC

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:DATA

PUBLIC	CMLOAD			; ＬＯＡＤ
PUBLIC	CMLCOM			; ＬＯＡＤ／ＣＯＭファイル
PUBLIC	CMLEXE			; ＬＯＡＤ／ＥＸＥファイル

EXTRN	FFOPEN:NEAR		; ファイルオープン
EXTRN	FFCLOS:NEAR		; ファイルクローズ
EXTRN	FFREAD:NEAR		; ファイルの読み出し
EXTRN	PRINT:NEAR		; 文字列の表示
EXTRN	KESCAP:NEAR		; ESC key & break check & pause.

EXTRN	HEXSTR:NEAR		; DX -> hex string.

READ_PARAGRAPH	EQU	1024	; read paragraph length.
READ_LEN	EQU	16*1024;16*64; read length.
CHR_CR		EQU	0DH	; calig return.
CHR_LF		EQU	0AH	; line feed.


;
;	ＬＯＡＤ
;	-I- DS:SI : ファイル名
;	    ES    : フリーエリアの開始位置（パラグラフ値）
;	-O- AX    : 0=正常, 1=該当ファイル無し, 2=ディスクエラー

CMLOAD	PROC	NEAR
	CALL	FFOPEN			; ファイルオープン
	CMP	AX,1			; file not found.
	JE	CMLOAD99		;
	CMP	AX,2			; ディスクエラー
	JE	CMLOAD_ERR_OPEN		;

	MOV	DI,0			; load memory area offset = 0 + ES*16
CMLOAD2:
	MOV	CX,READ_LEN		; read length.

	CALL	FFREAD			; ファイルの読み出し
	CMP	AX,2			; ディスクエラー
	JE	CMLOAD_ERROR		;
	CMP	AX,1			; E.O.F
	JE	CMLOAD8			;

	CALL	KESCAP			; ESC key & break check & pause.
	CMP	AX,0
	JNE	CMLOAD_BREAK

	MOV	DX,ES	
	CALL	HEXSTR
	CALL	PRINT

	MOV	AX,ES			;
	ADD	AX,READ_PARAGRAPH	; read paragraph length.
	MOV	ES,AX			;

	JMP	CMLOAD2
CMLOAD8:	
	CALL	FFCLOS			; ファイルクローズ

	MOV	AX,0		; normal.
	RET

CMLOAD99:
	MOV	SI,OFFSET MSG_NOT_FOUND
	CALL	PRINT		;
	MOV	AX,1		; file not found.
	RET
CMLOAD_ERROR:
	MOV	SI,OFFSET MSG_DISK_ERROR
	CALL	PRINT		;
	MOV	AX,2		; ディスクエラー
	RET
CMLOAD_ERR_OPEN:
	MOV	SI,OFFSET MSG_OPEN_ERROR
	CALL	PRINT		;
	MOV	AX,2		; ディスクエラー
	RET
CMLOAD_BREAK:
	MOV	SI,OFFSET MSG_BREAK
	CALL	PRINT		; 処理中断
	MOV	AX,0		; normal.
	RET
CMLOAD	ENDP


;	ＬＯＡＤ／ＣＯＭファイル
;	-I- DS:SI : コマンドライン
;	    ES    : フリーエリアの開始位置（パラグラフ値）
;	-O- BX    : 標準ＤＯＳプロセスのヘッダアドレス先頭
;	    DX    : 標準ＤＯＳ実行ファイルのロードアドレス先頭
;	    ES    : 標準ＤＯＳ実行ファイルのロード後フリーエリア
;	    AX    : 0=正常, 1=該当ファイル無し, 2=ディスクエラー

CMLCOM	PROC	NEAR
	PUSH	SI

	MOV	FRE_ADRS,ES		; フリーエリアの開始位置

	MOV	CMND_LINE_ADRS,SI	; コマンドラインアドレス

	CALL	FLSET_COM		; ＣＯＭファイル名セット

	MOV	SI,OFFSET FL_COM	; ＣＯＭファイル名
	CALL	FFOPEN			; ファイルオープン
	CMP	AX,1			; file not found.
	JE	CMLCOM99		;
	CMP	AX,2			; ディスクエラー
	JE	CMLCOM_ERR_OPEN		;

	MOV	ES,FRE_ADRS		; フリーエリアの開始位置
	CALL	SETHEADER		; ヘッダ領域セット

	MOV	ES,FRE_ADRS		; フリーエリアの開始位置
	MOV	DI,100H			; コードセグメント開始の１００Ｈ
CMLCOM2:
	MOV	CX,READ_LEN		; read length.

	CALL	FFREAD			; ファイルの読み出し
	CMP	AX,2			; ディスクエラー
	JE	CMLCOM_ERROR		;
	CMP	AX,1			; E.O.F
	JE	CMLCOM8			;

	MOV	AX,ES			;
	ADD	AX,READ_PARAGRAPH	; read paragraph length.
	MOV	ES,AX			;

	JMP	CMLCOM2
CMLCOM8:	
	PUSH	ES			;
	CALL	FFCLOS			; ファイルクローズ
	POP	ES			; ES=ファイルのロード後フリーエリア

	MOV	BX,FRE_ADRS		; 標準ＤＯＳプロセスのヘッダアドレス
	MOV	DX,FRE_ADRS		; 標準ＤＯＳ実行ファイルのアドレス
	ADD	DX,10H			; コードセグメント開始の１００Ｈ

	MOV	AX,0			; normal.
	POP	SI
	RET
CMLCOM99:
	MOV	AX,1		; file not found.
	POP	SI
	RET
CMLCOM_ERROR:
	MOV	SI,OFFSET MSG_DISK_ERROR
	CALL	PRINT		;
	MOV	AX,2		; ディスクエラー
	POP	SI
	RET
CMLCOM_ERR_OPEN:
	MOV	SI,OFFSET MSG_OPEN_ERROR
	CALL	PRINT		;
	MOV	AX,2		; ディスクエラー
	POP	SI
	RET
CMLCOM	ENDP


;	ＬＯＡＤ／ＥＸＥファイル
;	-I- DS:SI : コマンドライン
;	    ES    : フリーエリアの開始位置（パラグラフ値）
;	-O- BX    : 標準ＤＯＳプロセスのヘッダアドレス先頭
;	    DX    : 標準ＤＯＳ実行ファイルのロードアドレス先頭
;	    ES    : 標準ＤＯＳ実行ファイルのロード後フリーエリア
;	    AX    : 0=正常, 1=該当ファイル無し, 2=ディスクエラー

CMLEXE	PROC	NEAR
;*DBG*;	PRVH	"PSHELL.EXE/SSLOAD.ASM/CMLEXE ES=",ES
	PUSH	SI

	MOV	FRE_ADRS,ES		; フリーエリアの開始位置

	MOV	CMND_LINE_ADRS,SI	; コマンドラインアドレス

	CALL	FLSET_EXE		; ＥＸＥファイル名セット

	MOV	SI,OFFSET FL_EXE	; ＥＸＥファイル名
	CALL	FFOPEN			; ファイルオープン
	CMP	AX,1			; file not found.
	JE	CMLEXE99		;
	CMP	AX,2			; ディスクエラー
	JE	CMLEXE_ERR_OPEN		;

	MOV	ES,FRE_ADRS		; フリーエリアの開始位置
	CALL	SETHEADER		; ヘッダ領域セット

	MOV	ES,FRE_ADRS		; フリーエリアの開始位置
	MOV	DI,100H			; コードセグメント開始の１００Ｈ
CMLEXE2:
	MOV	CX,READ_LEN		; read length.

	CALL	FFREAD			; ファイルの読み出し
	CMP	AX,2			; ディスクエラー
	JE	CMLEXE_ERROR		;
	CMP	AX,1			; E.O.F
	JE	CMLEXE8			;

	MOV	AX,ES			;
	ADD	AX,READ_PARAGRAPH	; read paragraph length.
	MOV	ES,AX			;

	JMP	CMLEXE2
CMLEXE8:
	PUSH	ES			;
	CALL	FFCLOS			; ファイルクローズ
	POP	ES			; ES=ファイルのロード後フリーエリア

	MOV	BX,FRE_ADRS		; 標準ＤＯＳプロセスのヘッダアドレス
	MOV	DX,FRE_ADRS		; 標準ＤＯＳ実行ファイルのアドレス
	ADD	DX,10H			; コードセグメント開始の１００Ｈ

	MOV	AX,0			; normal.
	POP	SI
	RET
CMLEXE99:
	MOV	AX,1		; file not found.
	POP	SI
	RET
CMLEXE_ERROR:
	MOV	SI,OFFSET MSG_DISK_ERROR
	CALL	PRINT		;
	MOV	AX,2		; ディスクエラー
	POP	SI
	RET
CMLEXE_ERR_OPEN:
	MOV	SI,OFFSET MSG_OPEN_ERROR
	CALL	PRINT		;
	MOV	AX,2		; ディスクエラー
	POP	SI
	RET
CMLEXE	ENDP


;	ヘッダ領域セット
;	-I- CMND_LINE_ADRS : コマンドラインアドレス
;	    ES             : フリーエリアの開始位置（パラグラフ値）

SETHEADER	PROC	NEAR
	PUSH	SI

	MOV	DI,0				; クリア
	MOV	AL,0				;
	MOV	CX,100H				;
	REP	STOSB				;

	MOV	SI,CMND_LINE_ADRS		; コマンドラインアドレス
	MOV	CX,78H				; 最大７８ｈバイト
SETHEADER_LOP:					; パラメータリストの頭だし
	LODSB					;
	CMP	AL,' '				;
	JBE	SETHEADER_MOV			;
	LOOP	SETHEADER_LOP			;
	JMP	SETHEADER_EXIT			;

SETHEADER_MOV:					;
	MOV	ES:[80H],CL			; ヘッダセット
	MOV	DI,81H				;
	DEC	SI				;
	REP	MOVSB				;
	MOV	AL,0DH				;
	STOSB					;
SETHEADER_EXIT:
	POP	SI
	RET
SETHEADER	ENDP


;	ＣＯＭファイル名セット
;	-I- CMND_LINE_ADRS : コマンドラインアドレス
;	-O- FL_COM         : ＣＯＭファイル名

FLSET_COM	PROC	NEAR
	PUSH	ES
	MOV	AX,DS
	MOV	ES,AX

	MOV	DI,OFFSET FL_COM	; ＣＯＭファイル名
	MOV	CX,8			;
	MOV	AL,' '			;
	REP	STOSB			;

	MOV	SI,CMND_LINE_ADRS	; コマンドラインアドレス
	MOV	DI,OFFSET FL_COM	; ＣＯＭファイル名
	MOV	CX,8
FLSET_COM_LOOP:
	LODSB				;
	CMP	AL,'.'			;
	JE	FLSET_COM_EXIT		;
	CMP	AL,' '			;
	JBE	FLSET_COM_EXIT		;
	STOSB				;
	LOOP	FLSET_COM_LOOP		;
FLSET_COM_EXIT:				;
	POP	ES
	RET
FLSET_COM	ENDP



;	ＥＸＥファイル名セット
;	-I- CMND_LINE_ADRS : コマンドラインアドレス
;	-O- FL_EXE         : ＥＸＥファイル名

FLSET_EXE	PROC	NEAR
	PUSH	ES
	MOV	AX,DS
	MOV	ES,AX

	MOV	DI,OFFSET FL_EXE	; ＥＸＥファイル名
	MOV	CX,8			;
	MOV	AL,' '			;
	REP	STOSB			;

	MOV	SI,CMND_LINE_ADRS	; コマンドラインアドレス
	MOV	DI,OFFSET FL_EXE	; ＥＸＥファイル名
	MOV	CX,8
FLSET_EXE_LOOP:
	LODSB				;
	CMP	AL,'.'			;
	JE	FLSET_EXE_EXIT		;
	CMP	AL,' '			;
	JBE	FLSET_EXE_EXIT		;
	STOSB				;
	LOOP	FLSET_EXE_LOOP		;
FLSET_EXE_EXIT:				;
	POP	ES
	RET
FLSET_EXE	ENDP


CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

CMND_LINE_ADRS	DW	0			; コマンドラインアドレス
PARA_LIST_ADRS	DW	0			; パラメータリストアドレス
FRE_ADRS	DW	0			; フリーエリアの開始位置

FL_COM		DB	"        ","COM",0	; ＣＯＭファイル名
FL_EXE		DB	"        ","EXE",0	; ＥＸＥファイル名

MSG_BREAK	DB	"[break]",CHR_CR,CHR_LF,0 ; 処理中断
MSG_NOT_FOUND	DB	"ファイルが見つかりません",CHR_CR,CHR_LF,0
MSG_DISK_ERROR	DB	"ディスクエラー",CHR_CR,CHR_LF,0
MSG_OPEN_ERROR	DB	"オープンエラー",CHR_CR,CHR_LF,0

DATA	ENDS
	END
;
;	end of "SSLOAD.ASM"
;
