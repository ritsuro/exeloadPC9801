; "DOSIO.ASM" PC-9801UV11 make by R.H 1989/11/04
;
;	E X E L O A D    D i s k   l i b r a l y .
;
;
;	カレントドライブはここで管理される
;
;		FFDRV(カレントドライブ設定)
;		public FLCURT: カレントドライブ
;
; public subroutine.


INCLUDE	TSTSET.INC

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:DATA


PUBLIC	FFOPEN			; ファイルオープン
PUBLIC	FFCLOS			; ファイルクローズ
PUBLIC	FFREAD			; ファイルの読み出し
PUBLIC	FFSEEK			; ファイルポインタシーク

PUBLIC	FFDRV			; カレントドライブ設定

EXTRN	SSRDRV:NEAR		; ドライブ番号の設定（０ー３）
EXTRN	SSRDNO:NEAR		; ドライブ番号の取得（０ー３）

EXTRN	SSRSRT:NEAR		; ファイルの先頭クラスタ番号の取り出し

EXTRN	SSSEEK:NEAR		; クラスタのシーク

EXTRN	SSRCSR:NEAR		; クラスタ順次読み出し開始
EXTRN	SSRPLN:NEAR		; クラスタ順次読み出し数設定
EXTRN	SSRRDS:NEAR		; クラスタ順次読み出し


FLALLLEN	EQU	32	; 指定ファイル名最大長さ

CLST_LENGTH	EQU	1024	; クラスタのバイト数

;
;	ファイルオープン
;	-I- DS:SI : ファイル名
;	-O- AX    : 0=正常, 1=該当ファイルがない, 2=ディスクエラー

FFOPEN	PROC	NEAR
	CALL	PATH_GET		; パス名／ファイル名ＧＥＴ

	MOV	AX,FLDRIVE		; ドライブ番号
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	CMP	AX,0			; 0=正常,1=番号エラ,2=ディスクエラ
	JNE	FFOPEN_EXIT		;

	MOV	SI,OFFSET FLNAME	; 指定ファイル名
	CALL	SSRSRT			; ファイルの先頭クラスタ番号の取り出し
	MOV	STARTCLST,DX		; 先頭のクラスタ番号
	CALL	SSRCSR			; クラスタ順次読み出し開始

	MOV	FILE_LEN_LOW,CX		; ファイルの長さ
	MOV	FILE_LEN_HI,BX		; (long integer)

	MOV	FILE_PNT_LOW,CX		; 読み出しファイルの残りバイト数
	MOV	FILE_PNT_HI,BX		; (long integer)

	MOV	NOWCOUNT,0		; クラスタバッファ内の残りバイト数
	MOV	CLBYTE_OFFSET,0		; クラスタ内先頭からのバイト数

FFOPEN_EXIT:				;
	RET				;
FFOPEN	ENDP


;
;	ファイルクローズ
;

FFCLOS	PROC	NEAR
	RET
FFCLOS	ENDP


;	ファイルの読み出し
;	-I- ES:DI    : データバッファのアドレス
;	    CX       : 読み込みデータのバイト数
;	-O- ES:[DI]  : データ
;	    DX       : 読み込み出来たバイト数
;	    AX       : 1=Ｅ．Ｏ．Ｆ（もう続きのデータは無い）
;		     : 2=ディスクエラー

FFREAD	PROC	NEAR
	PUSH	ES			;
	PUSH	DI			;
	PUSH	CX			;

	MOV	BUFFSEG,ES		; バッファ・セグメント
	MOV	BUFFOFS,DI		; バッファ・オフセット
	MOV	DATALEN,CX		; データ長さ
	MOV	NOWREAD_LEN,0		; 読み出しバイト数

	CALL	BUFFCLAER		; es:[di]cx buffer 0 clear.

	MOV	CX,DATALEN		; データ長さ
	CALL	FILE_LEN_CHECK		; ファイル長さチェック
	MOV	NOWBYTE_LEN,CX		; 指定バイト数
	CMP	AX,1			; 1=Ｅ．Ｏ．Ｆ
	JMPEQ	FFREAD_EOF		;

	CMP	NOWBYTE_LEN,0		; 指定バイト数が０ならば
	JMPEQ	FFREAD_NORMAL		; おわり

	CMP	FLAG_SEEKCLAST,1	; 1=シークしたので現在クラスタを読め
	JE	FFREAD_READSTART	;

	MOV	AX,NOWBYTE_LEN		; 指定バイト数が
	CMP	AX,NOWCOUNT		; ｸﾗｽﾀバッファ内の残りバイト数
	JMPBE	FFREAD_MOV_ONLY		; 以下ならばバッファ転送のみ

	CMP	NOWCOUNT,0		; ｸﾗｽﾀバッファ内の残りバイト数が
	JE	FFREAD_READSTART	; 残っているならば取り出す

	MOV	SI,OFFSET CLST_BUFF	; クラスタバッファ
	ADD	SI,CLBYTE_OFFSET	; クラスタ内先頭からのバイト数
	MOV	ES,BUFFSEG		; バッファ・セグメント
	MOV	DI,BUFFOFS		; バッファ・オフセット
	MOV	CX,NOWCOUNT		; ｸﾗｽﾀバッファ内の残りバイト数
	REP	MOVSB			; copy.

	MOV	AX,NOWCOUNT		; ｸﾗｽﾀバッファ内の残りバイト数
	ADD	BUFFOFS,AX		; バッファ・オフセット
	SUB	NOWBYTE_LEN,AX		; 指定バイト数
	ADD	NOWREAD_LEN,AX		; 読み出しバイト数

	MOV	CLBYTE_OFFSET,0		; クラスタ内先頭からのバイト数
	MOV	NOWCOUNT,0		; ｸﾗｽﾀバッファ内の残りバイト数

FFREAD_READSTART:			;
	MOV	AX,FLDRIVE		; ドライブ番号
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	CMP	AX,0			; 0=正常,1=番号エラ,2=ディスクエラ
	JMPNE	FFREAD_ERROR		;

	CALL	READPLAN		; 読み出し計画

FFREAD_LOOP:
	CALL	READCLST		; クラスタ読み込み
	CMP	AX,1			; 1=E.O.F
	JMPEQ	FFREAD_EOF		;
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	FFREAD_ERROR		;
	CMP	AX,3			; 3=読み出し計画終了
	JMPEQ	FFREAD_NORMAL		;

	MOV	AX,CLST_LENGTH		; クラスタのバイト数
	SUB	AX,CLBYTE_OFFSET	; －クラスタ内先頭からのバイト数
	MOV	NOWCOUNT,AX		; ＝バッファ内の残りバイト数

	MOV	AX,NOWBYTE_LEN		; 指定バイト数が
	CMP	AX,NOWCOUNT		; バッファ内の残りバイト数で
	JBE	FFREAD_LOOP_E		; 足りるならば、ループおわり

	MOV	SI,OFFSET CLST_BUFF	; クラスタバッファ
	ADD	SI,CLBYTE_OFFSET	; クラスタ内先頭からのバイト数
	MOV	ES,BUFFSEG		; バッファ・セグメント
	MOV	DI,BUFFOFS		; バッファ・オフセット
	MOV	CX,NOWCOUNT		; バッファ内の残りバイト数
	REP	MOVSB			; copy.

	MOV	AX,NOWCOUNT		; ｸﾗｽﾀバッファ内の残りバイト数
	ADD	BUFFOFS,AX		; バッファ・オフセット
	SUB	NOWBYTE_LEN,AX		; 指定バイト数
	ADD	NOWREAD_LEN,AX		; 読み出しバイト数

	MOV	CLBYTE_OFFSET,0		; クラスタ内先頭からのバイト数
	MOV	NOWCOUNT,0		; ｸﾗｽﾀバッファ内の残りバイト数

	CMP	NOWBYTE_LEN,0		; 指定バイト数が０ならば
	JE	FFREAD_NORMAL		; おわり

	JMP	FFREAD_LOOP		; 次のクラスタの読み込み

FFREAD_LOOP_E:

FFREAD_MOV_ONLY:			;
	MOV	SI,OFFSET CLST_BUFF	; クラスタバッファ
	ADD	SI,CLBYTE_OFFSET	; クラスタ内先頭からのバイト数
	MOV	ES,BUFFSEG		; バッファ・セグメント
	MOV	DI,BUFFOFS		; バッファ・オフセット
	MOV	CX,NOWBYTE_LEN		; 指定バイト数
	JCXZ	FFREAD_66		;
	REP	MOVSB			; copy.
FFREAD_66:				;
	MOV	AX,NOWBYTE_LEN		; 指定バイト数
	SUB	NOWCOUNT,AX		; ｸﾗｽﾀバッファ内の残りバイト数
	ADD	CLBYTE_OFFSET,AX	; クラスタ内先頭からのバイト数
	ADD	NOWREAD_LEN,AX		; 読み出しバイト数
	CMP	NOWCOUNT,0		; クラスタバッファを使い切った？
	JNE	FFREAD_77		;
	MOV	CLBYTE_OFFSET,0		; クラスタ内先頭からのバイト数
	MOV	NOWCOUNT,0		; ｸﾗｽﾀバッファ内の残りバイト数
FFREAD_77:				;
	JMP	FFREAD_NORMAL		;

FFREAD_NORMAL:
	MOV	AX,0			; normal.
	JMP	FFREAD_EXIT		;
FFREAD_EOF:
	MOV	AX,1			; E.O.F
	JMP	FFREAD_EXIT		;
FFREAD_ERROR:
	MOV	AX,2			; ディスクエラー
	JMP	FFREAD_EXIT		;
FFREAD_EXIT:
	MOV	DX,NOWREAD_LEN		; 読み出しバイト数
	POP	CX			;
	POP	DI			;
	POP	ES			;
	RET				;
FFREAD	ENDP


;	ファイルポインタシーク
;	-I- AL    : 移動モード （0:先頭から,1:現在位置から,2:終端から）
;	    CX:DX : 移動するバイト数
;	-O- AX    : 0=正常,1=移動モードが無効,6=オープンされていない
;	    CX:DX : 移動後の位置（先頭からのバイト数）

FFSEEK	PROC	NEAR
;*;	PRVH	"移動モード:",AX
;*;	PRVH	"移動するバイト数(hi )CX=",CX
;*;	PRVH	"移動するバイト数(low)DX=",DX

	MOV	FLAG_SEEKCLAST,0	; 1=シークしたので現在クラスタを読め

	CMP	AL,0			; 移動モード 0:先頭から
	JE	FFSEEK_TOP_SEEK		;
	CMP	AL,1			; 移動モード 1:現在位置から
	JE	FFSEEK_NOW_PNT		;
	CMP	AL,2			; 移動モード 2:終端から
	JE	FFSEEK_END_PNT		;

	JMP	FFSEEK_ERRORMODE	;

FFSEEK_NOW_PNT:
	MOV	AX,FILE_LEN_LOW		; ファイルの長さ
	MOV	BX,FILE_LEN_HI		; (long integer)
	SUB	AX,FILE_PNT_LOW		; 読み出しファイルの残りバイト数
	SBB	BX,FILE_PNT_HI		; (long integer)
	ADD	AX,DX			; 移動するバイト数
	ADC	BX,CX			; 移動するバイト数
	MOV	DX,AX			; 先頭から移動するバイト数
	MOV	CX,BX			; 先頭から移動するバイト数
	JMP	FFSEEK_TOP_SEEK		;

FFSEEK_END_PNT:
	MOV	AX,FILE_LEN_LOW		; ファイルの長さ
	MOV	BX,FILE_LEN_HI		; (long integer)
	ADD	AX,DX			; 移動するバイト数
	ADC	BX,CX			; 移動するバイト数
	MOV	DX,AX			; 先頭から移動するバイト数
	MOV	CX,BX			; 先頭から移動するバイト数
	JMP	FFSEEK_TOP_SEEK		;

FFSEEK_TOP_SEEK:
	MOV	FILE_OFST_LOW,DX	; ファイル先頭からの位置
	MOV	FILE_OFST_HI,CX		; (long integer)

	;*;PRVH	"FILE_OFST_LOW=",FILE_OFST_LOW
	;*;PRVH	"FILE_OFST_HI=",FILE_OFST_HI

	MOV	AX,FILE_LEN_LOW		; ファイルの長さ
	MOV	BX,FILE_LEN_HI		; (long integer)
	SUB	AX,DX			;
	SBB	BX,CX			;
	MOV	FILE_PNT_LOW,AX		; 読み出しファイルの残りバイト数
	MOV	FILE_PNT_HI,BX		; (long integer)

	;*;PRVH	"FILE_PNT_LOW=",FILE_PNT_LOW
	;*;PRVH	"FILE_PNT_HI=",FILE_PNT_HI

	MOV	AX,DX			; 移動するバイト数(low)
	MOV	DX,CX			; 移動するバイト数(hi)
	MOV	BX,CLST_LENGTH		; クラスタのバイト数
	DIV	BX			;
	MOV	CLST_OFFSET,AX		; 先頭からのクラスタ数
	MOV	CLBYTE_OFFSET,DX	; クラスタ内先頭からのバイト数

	;*;PRVH "CLST_OFFSET=",CLST_OFFSET
	;*;PRVH "CLBYTE_OFFSET=",CLBYTE_OFFSET
	;*;PRVH "STARTCLST=",STARTCLST

	MOV	DX,STARTCLST		; 先頭のクラスタ番号
	MOV	CX,CLST_OFFSET		; 先頭からのクラスタ数
	CALL	SSSEEK			; クラスタのシーク
	CALL	SSRCSR			; クラスタ順次読み出し開始

	MOV	NOWCOUNT,0		; バッファ内の残りバイト数
	MOV	FLAG_SEEKCLAST,1	; 1=シークしたので現在クラスタを読め

FFSEEK_EXIT:
	MOV	DX,FILE_OFST_LOW	; ファイル先頭からの位置
	MOV	CX,FILE_OFST_HI		; (long integer)
	MOV	AX,0			; 0=正常
	RET
FFSEEK_ERRORMODE:
	MOV	AX,1			; 1=移動モードが無効
	RET
FFSEEK_ERRORNOTOPEN:
	MOV	AX,6			; 6=オープンされていない
	RET
FFSEEK	ENDP


;	読み出し計画
;	-I- NOWBYTE_LEN   : 指定バイト数
;	    CLBYTE_OFFSET :クラスタ内先頭からのバイト数

READPLAN	PROC	NEAR
	MOV	AX,NOWBYTE_LEN		; 指定バイト数
	ADD	AX,CLBYTE_OFFSET	; クラスタ内先頭からのバイト数
	XOR	DX,DX			; DX=0
	MOV	BX,CLST_LENGTH		; ÷クラスタのバイト数
	DIV	BX			;
	CMP	DX,0			; 余り
	JE	READPLAN_5		;
	INC	AX			;
READPLAN_5:				; AX=クラスタ数
	MOV	CX,AX			; 読み出し開始クラスタ数
	CALL	SSRPLN			; クラスタ順次読み出し数設定
	RET
READPLAN	ENDP


;	クラスタ読み込み
;	-O- CLST_BUFF: クラスタバッファ
;	    AX       : 0=正常, 1=E.O.F, 2=ディスクエラー, 3=読み出し計画終了

READCLST	PROC	NEAR
	PUSH	ES
	PUSH	DI
	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,OFFSET CLST_BUFF	; クラスタバッファ
	CALL	SSRRDS			; クラスタ順次読み出し
	POP	DI
	POP	ES
	RET
READCLST	ENDP



;	カレントドライブ設定
;	-I- AX     : １ＭＦＤドライブ番号
;	-O- FLCURT : カレントドライブ
;	-O- AX : 0=正常,1=ドライブ番号エラー,2=ディスクエラー

FFDRV	PROC	NEAR
;*DBG*;	PRV	"１ＭＦＤドライブ番号 AX=",AX
	MOV	FLCURT,AX		; カレントドライブ
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	RET
FFDRV	ENDP


;
;	ファイル長さチェック
;	-I/O-  CX  : 読み出しバイト数
;	-O-    AX  : 0=正常, 1=Ｅ．Ｏ．Ｆ

FILE_LEN_CHECK	PROC	NEAR
	CMP	FILE_PNT_HI,0	; 読み出しファイルの残りバイト数(HI)
	JNE	FILE_LEN_CHECK5	;

	CMP	FILE_PNT_LOW,0	; 読み出しファイルの残りバイト数(LOW)
	JNE	FILE_LEN_CHECK2	;

	MOV	AX,1		; E.O.F
	RET

FILE_LEN_CHECK2:
	CMP	CX,FILE_PNT_LOW	; 読み出しバイト数と残りバイト数(LOW)
	JBE	FILE_LEN_CHECK5	; 読み出すバイト数が小さい？

	MOV	CX,FILE_PNT_LOW	; 残りの読み出しバイト数はこれだけ
FILE_LEN_CHECK5:
	SUB	FILE_PNT_LOW,CX	; 読み出しファイルの残りバイト数計算
	SBB	FILE_PNT_HI,0	; 
	MOV	AX,0		; normal.
	RET
FILE_LEN_CHECK	ENDP



;	バッファ０クリア
;	-I- ES:DI    : データバッファのアドレス
;	    CX       : 読み込みデータのバイト数

BUFFCLAER	PROC	NEAR
	MOV	AL,0
	REP	STOSB
	RET
BUFFCLAER	ENDP


;	パス名／ファイル名ＧＥＴ
;	-I- DS:SI   : 指定ファイル名
;	-O- FLNAME  : 指定ファイル名
;	    FLPATH  : パス名
;	    FLDRIVE : ドライブ番号

PATH_GET	PROC	NEAR
	PUSH	ES			;
	PUSH	DI			;
	PUSH	SI			;
	PUSH	CX			;

	MOV	AX,DS			;
	MOV	ES,AX			;

	CMP	BYTE PTR DS:[SI][1],':'	; ドライブデリミタ
	JNE	PATH_GET_CUR		;

	MOV	AX,DS:[SI]		; ドライブ  "A:", "B:", "C:", "D:"
	MOV	WORD PTR FLPATH,AX	; パス名
	SUB	AL,'A'			; 0 <- 'A', 1 <- 'B', 2 <- 'C' 
	MOV	BYTE PTR FLDRIVE,AL	; ドライブ番号

	INC	SI			;
	INC	SI			;

	MOV	DI,OFFSET FLNAME	; 指定ファイル名
	MOV	CX,FLALLLEN		; 指定ファイル名最大長さ
	REP	MOVSB			;

PATH_GET_EXIT:				;
	POP	CX			;
	POP	SI			;
	POP	DI			;
	POP	ES			;
	RET
PATH_GET_CUR:				;
	MOV	AX,FLCURT		; カレントドライブ
	MOV	FLDRIVE,AX		; ドライブ番号
	MOV	FLPATH,' '		; パス名
	MOV	FLPATH[1],' '		;

	MOV	DI,OFFSET FLNAME	; 指定ファイル名
	MOV	CX,FLALLLEN		; 指定ファイル名最大長さ
	REP	MOVSB			;

	POP	CX			;
	POP	SI			;
	POP	DI			;
	POP	ES			;
	RET
PATH_GET	ENDP

CODE	ENDS



DATA	SEGMENT	PUBLIC	'DATA'

PUBLIC	FLCURT				; カレントドライブ

EXTRN	CLST_BUFF:BYTE			; クラスタバッファ
;*;CLST_BUFF	DB	CLST_LENGTH DUP (0)	; クラスタバッファ

		EVEN

STARTCLST	DW	0	; 先頭のクラスタ番号

NOWCOUNT	DW	0	; クラスタバッファ内の残りバイト数

NOWBYTE_LEN	DW	0	; 指定バイト数

NOWREAD_LEN	DW	0	; 読み出しバイト数

FILE_LEN_LOW	DW	0	; ファイルの長さ
FILE_LEN_HI	DW	0	; (long integer)

FILE_PNT_LOW	DW	0	; 読み出しファイルの残りバイト数
FILE_PNT_HI	DW	0	; (long integer)

FILE_OFST_LOW	DW	0	; ファイル先頭からの位置
FILE_OFST_HI	DW	0	; (long integer)

CLST_OFFSET	DW	0	; 先頭からのクラスタ数
CLBYTE_OFFSET	DW	0	; クラスタ内先頭からのバイト数

FLAG_SEEKCLAST	DW	0	; 1=シークしたので現在クラスタを読め

BUFFOFS		DW	0	; バッファ・オフセット
BUFFSEG		DW	0	; バッファ・セグメント
DATALEN		DW	0	; データ長さ

FLCURT		DW	0			; カレントドライブ
FLDRIVE		DW	0			; ドライブ番号
FLPATH		DB	"  ",0,0		; パス名

FLNAME		DB	FLALLLEN DUP (' ')	; 指定ファイル名
		DB	0,0			;

DATA	ENDS
	END
;
;	end of "DOSIO.ASM"
;
