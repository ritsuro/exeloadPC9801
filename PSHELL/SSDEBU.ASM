; "SSDEBU.ASM" PC-9801UV11 make by R.H 1989/11/10
;
;	E X E L O A D     D E B U G   c o m m a n d .
;
;
;
; command.

INCLUDE	TSTSET.INC

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:DATA

PUBLIC	CMIOCK		; Ｉ／Ｏ変化チェック
PUBLIC	CMCKEY		; キー入力ＢＩＯＳチェック
PUBLIC	CMCTMP		; 秘密変数の表示等
PUBLIC	CMCEXE		; 標準ＤＯＳのロードモジュールチェック
PUBLIC	CMCMEM		; メモリーダンプ
PUBLIC	CMCSNS		; センスコマンドテスト
PUBLIC	CMCSN2		; 旧センスコマンドテスト
PUBLIC	CMCSN3		; センスコマンドテストＷＡＩＴ付き

EXTRN	KESCAP:NEAR	; ESC key & break check & pause.
EXTRN	SSFDDV:NEAR	; ＦＤドライブドア開閉チェック
EXTRN	FFOPEN:NEAR	; ファイルオープン
EXTRN	FFCLOS:NEAR	; ファイルクローズ
EXTRN	FFREAD:NEAR	; ファイルの読み出し
EXTRN	KESCAP:NEAR	; ESC key & break check & pause.

CHECK_LEN	EQU	16	; チェック長さ
BUFF_LEN	EQU	64	; buffer length.


;	Ｉ／Ｏ変化チェック
;	-I- DX : Ｉ／Ｏアドレスオフセット
;	（ＥＳＣキーを押すまで抜けないよ）

CMIOCK	PROC	NEAR
	MOV	AX,SEG DATA
	MOV	ES,AX

	MOV	IO_ADRS,DX		; Ｉ／Ｏアドレス
CMIOCK1:
	MOV	DI,OFFSET IO_BUFFER
	MOV	DX,IO_ADRS		; Ｉ／Ｏアドレス
	MOV	CX,CHECK_LEN		; チェック長さ
CMIOCK2:
	JMP	CMIOCK2_WAIT1		; ３８６ＳＸ以降
CMIOCK2_WAIT1:
	JMP	CMIOCK2_WAIT2
CMIOCK2_WAIT2:
	JMP	CMIOCK2_WAIT3
CMIOCK2_WAIT3:
	JMP	CMIOCK2_WAIT4
CMIOCK2_WAIT4:
	IN	AX,DX
	STOSW
	INC	DX
	LOOP	CMIOCK2

	MOV	SI,OFFSET IO_BUFFER
	MOV	DI,OFFSET IO_BUFFER2

	MOV	CHK_COUNT,0		; チェック個数
	MOV	DX,IO_ADRS		; Ｉ／Ｏアドレス
	MOV	CX,CHECK_LEN		; チェック長さ
CMIOCK3:
	MOV	AX,WORD PTR DS:[SI]
	CMP	AX,WORD PTR DS:[DI]
	JE	CMIOCK4
	PUSH	DI
	PUSH	SI
	PUSH	DX

	INC	CHK_COUNT		; チェック個数

	PR	" i"
	CALL	HEXSTR
	CALL	PRINT
	
	PR	"/"
	MOV	DX,AX
	CALL	HEXSTR
	CALL	PRINT

	POP	DX
	POP	SI
	POP	DI
CMIOCK4:
	INC	SI
	INC	SI
	INC	DI
	INC	DI
	INC	DX
	LOOP	CMIOCK3


	CMP	CHK_COUNT,0		; チェック個数
	JE	CMIOCK5
	LF
	PRF	"-------------------------------"
CMIOCK5:
	MOV	SI,OFFSET IO_BUFFER
	MOV	DI,OFFSET IO_BUFFER2
	MOV	CX,CHECK_LEN		; チェック長さ
	REP	MOVSW

	CALL	KESCAP		; ESC key & break check & pause.
	CMP	AX,1
	JE	CMIOCK_ESC
	CMP	AX,2
	JE	CMIOCK_BREAK

	JMP	CMIOCK1		; next

CMIOCK_ESC:
	PRF	"[ESC]"
	RET
CMIOCK_BREAK:
	PRF	"[break]"
	RET
CMIOCK	ENDP


;	キー入力ＢＩＯＳチェック
;	（キーを押すまで抜けない）

CMCKEY	PROC	NEAR
	MOV	AH,0	; key data read.
	INT	18H

	PR	"スキャンコード＝"
	CALL	PRNAH

	PR	" 内部コード＝"
	MOV	AH,AL
	CALL	PRNAH

	LF

	RET
CMCKEY	ENDP


;	秘密変数の表示等

CMCTMP	PROC	NEAR
	MOV	AX,0
	MOV	ES,AX

	PR	"立ち上げディスクのＤＡ／ＵＡ [584h]:"
	MOV	AH,BYTE PTR ES:[584H]
	CALL	PRINTAH
	LF

	PRF	"DISK_RESULT [564h~583h] 0           1           2           3"
	MOV	CX,8
	MOV	BX,564H
CMCTMP2:
	PR	"			"
	MOV	AH,BYTE PTR ES:[BX]
	CALL	PRINTAH
	MOV	AH,BYTE PTR ES:[BX][8]
	CALL	PRINTAH
	MOV	AH,BYTE PTR ES:[BX][16]
	CALL	PRINTAH
	MOV	AH,BYTE PTR ES:[BX][24]
	CALL	PRINTAH
	LF
	INC	BX
	LOOP	CMCTMP2


	PR	"DISK_RESET	[492h]:"
	MOV	AH,BYTE PTR ES:[492H]
	CALL	PRINTAH
	PRF	" 640KBFD->3210|3210<-1MBFD ｷｬﾘﾌﾞﾚｲﾄ実行"

	PR	"F2HD_MODE	[493h]:"
	MOV	AH,BYTE PTR ES:[493H]
	CALL	PRINTAH
	PRF	" 0:48tpi/1:96tpi(2DD)->3210|3210<-0:片1:両"

	PR	"DISK_EQUIP2	[494h]:"
	MOV	AH,BYTE PTR ES:[494H]
	CALL	PRINTAH
	PRF	"1:接続(640KBﾓｰﾄﾞ) 3210|...."

	PR	"DISK_EQUIP	[55Ch]:"
	MOV	AH,BYTE PTR ES:[55CH]
	CALL	PRINTAH
	PRF	"320KBFD->3210|3210<-1MBFD 1:接続"

	PR	"続きDISK_EQUIP	[55Dh]:"
	MOV	AH,BYTE PTR ES:[55DH]
	CALL	PRINTAH
	PRF	"640KBFD->3210|..10<-固定ディスク 1:接続"

	PR	"RDISK_EQUIP	[488h]:"
	MOV	AH,BYTE PTR ES:[488H]
	CALL	PRINTAH
	PRF	"640KBFD->3210|3210<-1MBFD RAMﾄﾞﾗｲﾌﾞ"

	PRF	"ＦＤドライブドア開閉チェック"
	MOV	DRIVE_NUM,0	; ドライブ番号
	MOV	CX,4
CMCTMP3:
	MOV	AH,BYTE PTR DRIVE_NUM
	CALL	PRNAH		; 数値を文字列に
	PR	":"
	MOV	AX,DRIVE_NUM

	PUSH	CX
	CALL	SSFDDV		; ＦＤドライブドア開閉チェック
	POP	CX

	CMP	AX,0
	JNE	CMCTMP31
	PR	"前と変わらず  "
	JMP	CMCTMP39
CMCTMP31:
	CMP	AX,1
	JNE	CMCTMP32
	PR	"ドアを開閉した  "
	JMP	CMCTMP39
CMCTMP32:
	PR	"ドアが開きっぱなし  "
CMCTMP39:
	INC	DRIVE_NUM
	LOOP	CMCTMP3
	LF

	PR	"このプログラムのセグメント SEG CODE="
	MOV	DX,SEG CODE
	CALL	HEXSTR
	CALL	PRINT
	PR	" SEG DATA="
	MOV	DX,SEG DATA
	CALL	HEXSTR
	CALL	PRINT

	LF

	RET
CMCTMP	ENDP


;	標準ＤＯＳのロードモジュールチェック
;	-I- DS:SI : ファイル名
;	-O- AX    : 0=正常, 1=該当ファイル無し

CMCEXE	PROC	NEAR
	CALL	FFOPEN		; ファイルオープン
	CMP	AX,0		; file not found.
	JNE	CMCEXE_DERROR	;

	MOV	AX,SEG DATA
	MOV	ES,AX
	MOV	DI,OFFSET HEADER_BUFFER	; 標準ＤＯＳのロードモジュール
					; ヘッダエリア
	MOV	CX,BUFF_LEN		; string buffer length.
	CALL	FFREAD			; ファイルの読み出し
	CMP	AX,0			; ディスクエラー
	JNE	CMCEXE_DERROR		;

	CALL	EXE_DUMP		; ヘッダダンプ

	CALL	FFCLOS			; ファイルクローズ
	MOV	AX,0			; normal.
	RET
CMCEXE_DERROR:
	PRF	"ファイルがない"
	CALL	FFCLOS			; ファイルクローズ
	MOV	AX,1			; ディスクエラー
	RET
CMCEXE	ENDP


;	メモリーダンプ
;	-I- ES:DI : アドレスオフセット

CMCMEM	PROC	NEAR
	PUSH	AX
CMCMEM2:
	CALL	PRINT16H	; １６バイトダンプ

	CMP	DI,0FFF0H	; if DI>=fff0h then
	JB	CMCMEM3		;
	MOV	DI,0		;   DI = 0
	MOV	AX,ES		;
	ADD	AX,1000H	;   ES += 1000h
	MOV	ES,AX		;
	JMP	CMCMEM4		;
CMCMEM3:			; else
	ADD	DI,16		;   DI += 16
CMCMEM4:			; endif
	CALL	KESCAP		; ESC key & break check & pause.
	CMP	AX,0
	JNE	CMCMEM_BREAK

	JMP	CMCMEM2
CMCMEM_BREAK:
	POP	AX
	RET
CMCMEM	ENDP


;	センスコマンドテスト

CMCSNS	PROC	NEAR
	PRF	"新センス（COMMAND/STATUS）84H"
	MOV	DBIOS_WAT,0		; ディスクＢＩＯＳＷＡＩＴ
	MOV	DBIOS_CMD,84H		; ディスクＢＩＯＳコマンド
	CALL	SENSE_CHECK		; ＤＩＳＫ　ＢＩＯＳ　チェック
	RET
CMCSNS	ENDP


;	旧センスコマンドテスト

CMCSN2	PROC	NEAR
	PRF	"旧センス（ＳＥＮＳＥ）    04H"
	MOV	DBIOS_WAT,0		; ディスクＢＩＯＳＷＡＩＴ
	MOV	DBIOS_CMD,04H		; ディスクＢＩＯＳコマンド
	CALL	SENSE_CHECK		; ＤＩＳＫ　ＢＩＯＳ　チェック
	RET
CMCSN2	ENDP


;	センスコマンドテストＷＡＩＴ付き

CMCSN3	PROC	NEAR
	PRF	"新センスWAIT付 84H"
	MOV	DBIOS_WAT,6000		; ディスクＢＩＯＳＷＡＩＴ
	MOV	DBIOS_CMD,84H		; ディスクＢＩＯＳコマンド
	CALL	SENSE_CHECK		; ＤＩＳＫ　ＢＩＯＳ　チェック
	RET
CMCSN3	ENDP


;	ＤＩＳＫ　ＢＩＯＳ　チェック
;	-I- DBIOS_CMD : ディスクＢＩＯＳコマンド
;	    DBIOS_WAT : ディスクＢＩＯＳＷＡＩＴ

SENSE_CHECK	PROC	NEAR
	MOV	DAUA,90H		; ＤＡ／ＵＡ
SENSE_CHECK_LOOP:			;
	PR	" "			;
	MOV	DX,DAUA			; ＤＡ／ＵＡ
	CALL	HEXSTR			;
	INC	SI			;
	INC	SI			;
	CALL	PRINT			; print.
	PR	":"			;

	MOV	CX,DBIOS_WAT		; ディスクＢＩＯＳＷＡＩＴ
	JCXZ	SENSE_CHECK_WAIT3	;
SENSE_CHECK_WAIT:			;
	NOP				;
	JMP	SENSE_CHECK_WAIT2	;
SENSE_CHECK_WAIT2:			;
	LOOP	SENSE_CHECK_WAIT	;
SENSE_CHECK_WAIT3:			;

	MOV	AH,BYTE PTR DBIOS_CMD	; ディスクＢＩＯＳコマンド
	MOV	AL,BYTE PTR DAUA	; ＤＡ／ＵＡ
	INT	1BH			; ＤＩＳＫ　ＢＩＯＳ
	JB	SENSE_CHECK_21		;
	PR	"正常"
	JMP	SENSE_CHECK_22		;
SENSE_CHECK_21:				;
	PR	"異常"
SENSE_CHECK_22:				;
	MOV	DX,AX			;
	CALL	HEXSTR			; hex->string.
	CALL	PRINT			; print.
	PR	"  "

	INC	DAUA			; ＤＡ／ＵＡ
	CMP	DAUA,93H		; UNIT#3
	JBE	SENSE_CHECK_3		;
	LF				; line feed.
	MOV	DAUA,90H		; UNIT#0
SENSE_CHECK_3:				;
	CALL	KESCAP			; ESC key & break check & pause.
	CMP	AX,0			;
	JNE	SENSE_CHECK_EXIT	;

	JMP	SENSE_CHECK_LOOP	;

SENSE_CHECK_EXIT:
	RET
SENSE_CHECK	ENDP



;	標準ＤＯＳロードモジュールヘッダダンプ

EXE_DUMP	PROC	NEAR
  PRVH "４Ｄｈ，５Ａｈマーク（標準ＤＯＳ）	   [00h~01h] ",[HEADER_BUFFER]
  PRVH "最終ページ（512byte単位）の有効バイト数	   [02h~03h] ",[HEADER_BUFFER][2]
  PRVH "ページ数（512byte単位）			   [04h~05h] ",[HEADER_BUFFER][4]
  PRVH "リロケートの計算を必要とするアドﾚｽ値の個数 [06h~07h] ",[HEADER_BUFFER][6]
  PRVH "ヘッダの大きさ（パラグラフ数／16byte単位） [08h~09h] ",[HEADER_BUFFER][8]
  PRVH "ヒープエリアの最小数			   [0Ah~0Bh] ",[HEADER_BUFFER][0AH]
  PRVH "ヒープエリアの最大数			   [0Ch~0Dh] ",[HEADER_BUFFER][0CH]
  PRVH "スタックセグメント（ＳＳ）初期値	   [0Eh~0Fh] ",[HEADER_BUFFER][0EH]
  PRVH "スタックポインタ（ＳＰ）初期値		   [10h~11h] ",[HEADER_BUFFER][10H]
  PRVH "チェックサム				   [12h~13h] ",[HEADER_BUFFER][12H]
  PRVH "インストラクションポインタ（ＩＰ）の初期値 [14h~15h] ",[HEADER_BUFFER][14H]
  PRVH "コードセグメント（ＣＳ）の初期値	   [16h~17h] ",[HEADER_BUFFER][16H]
  PRVH "リロケーション情報のオフセット		   [18h~19h] ",[HEADER_BUFFER][18H]
  PRVH "標準ＤＯＳオーバレイ番号		   [1Ah~1Bh] ",[HEADER_BUFFER][1AH]
	RET
EXE_DUMP	ENDP


;	ＡＨレジスタのプリント
;	-I- AH : 表示値

PRINTAH	PROC	NEAR
	CALL	PRNAH
	PR	" "
	CALL	PRNAB
	PR	" "
	RET
PRINTAH	ENDP


;	１６バイトダンプ
;	-I- ES:DI: １６バイトダンプ

PRINT16H	PROC	NEAR
	PUSH	AX
	PUSH	CX
	PUSH	DX
	PUSH	DI

	MOV	DX,ES			; セグメントアドレス
	CALL	HEXSTR			;
	CALL	PRINT			;

	MOV	AL,':'
	CALL	CHPUT

	MOV	DX,DI			; セグメントアドレス
	CALL	HEXSTR			;
	CALL	PRINT			;

	MOV	PRADRS,DI
	MOV	CX,16
PRINT16H2:
	MOV	AL,' '
	CALL	CHPUT
	MOV	AH,BYTE PTR ES:[DI]
	CALL	PRNAH
	INC	DI
	CMP	DI,0
	JE	PRINT16H22
	LOOP	PRINT16H2
PRINT16H22:

	MOV	AL,' '
	CALL	CHPUT

	MOV	DI,PRADRS

	MOV	CX,16
PRINT16H3:
	MOV	AH,BYTE PTR ES:[DI]
	PRCH
	INC	DI
	CMP	DI,0
	JE	PRINT16H33
	LOOP	PRINT16H3
PRINT16H33:

	MOV	AL,' '
	CALL	CHPUT

	LF
	POP	DI
	POP	DX
	POP	CX
	POP	AX
	RET
PRINT16H	ENDP



CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

HEADER_BUFFER	LABEL	WORD			; 標準ＤＯＳの
	DB	BUFF_LEN DUP (0)		; ロードモジュール
						; ヘッダエリア

CHK_COUNT	DW	0			; チェック個数

IO_BUFFER	DW	CHECK_LEN DUP (0)	; Ｉ／Ｏバッファ
IO_BUFFER2	DW	CHECK_LEN DUP (0)	; Ｉ／Ｏバッファ
IO_ADRS		DW	0			; Ｉ／Ｏアドレス
DRIVE_NUM	DW	0			; ドライブ番号

PRADRS		DW	0			; アドレス

DBIOS_CMD	DW	0			; ディスクＢＩＯＳコマンド
DBIOS_WAT	DW	0			; ディスクＢＩＯＳＷＡＩＴ
DAUA		DW	0			; デバイスＤＡ／ＵＡ


DATA	ENDS
	END
;
;	end of "SSDEBU.ASM"
;
