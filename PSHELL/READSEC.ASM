; "READSEC.ASM" PC-9801UV11 make by R.H 1990/09/25
;
;
;	E X E L O A D    D I S K    s e c t o r    r e a d e r .
;
;
;	"(READSEC.ASM) fatal error : DMA boundary."
;	が表示されたらば CHASH_BUFFER1 の絶対アドレスを
;	変更する必要があります。
;
; public subroutine.( sector read optimizer )

INCLUDE	TSTSET.INC

DEBUG		EQU	0		; debug flag.

RECBUFFMAX	EQU	16		; 論理レコードバッファ数

MIN_CLAST	EQU	2		; 最小クラスタ番号
MAX_CLAST	EQU	8*2*77-10	; 最大クラスタ番号

LEN_CLAST	EQU	1024		; クラスタバイト数
LEN_SECTOR	EQU	1024		; セクタバイト数

READ_RETCOUNT 	EQU	10		; ＲＥＡＤ・リトライ回数
WRITE_RETCOUNT 	EQU	10		; ＷＲＩＴＥ・リトライ回数

CLAST_OFFSET	EQU	9		; クラスタ開始位置のセクタオフセット

FAT_EOF_CLAST	EQU	0FFFH		; ファイルの最後のクラスタ(FAT)
NONE_CLAST	EQU	0		; クラスタ無し

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:DATA

PUBLIC	SSRCSR		; クラスタ順次読み出し開始
PUBLIC	SSRPLN		; クラスタ順次読み出し数設定
PUBLIC	SSRRDS		; クラスタ順次読み出し

PUBLIC	SSRRRD		; 連続レコード順次読み出し

PUBLIC	SSWCSR		; クラスタ順次書き込み開始
PUBLIC	SSWPLN		; クラスタ順次書き込み数設定
PUBLIC	SSWWTS		; クラスタ順次書き込み
PUBLIC	SSWCED		; クラスタ順次書き込み終了

PUBLIC	SSWRWT		; 連続レコード順次書き込み

EXTRN	NXTNUM:NEAR	; 次のクラスタ番号を取り出す
EXTRN	NXTFRE:NEAR	; 次の空きクラスタを捜す
EXTRN	FATSET:NEAR	; ＦＡＴへクラスタ番号を書き込む


;	クラスタ順次読み出し開始
;	-I- DX : 読み出し開始クラスタ番号

SSRCSR	PROC	NEAR
	PUSH	AX

	MOV	AX,1			; ハンドルＩＤ 1=読み込みハンドル
	CALL	SSRHDL			; ハンドル設定

	MOV	RDNEXTPNT,DX		; 読み出し待ちクラスタ番号

	POP	AX
	RET
SSRCSR	ENDP


;	クラスタ順次読み出し数設定
;	-I- CX : 読み出し開始クラスタ数

SSRPLN	PROC	NEAR
	MOV	AX,1			; ハンドルＩＤ 1=読み込みハンドル
	CALL	SSRHDL			; ハンドル設定

	MOV	RDNEXTCNT,CX		; 読み出し待ちクラスタ数

	MOV	TRACKBUFFMAX,0		; トラックバッファ・レコード最大数
	MOV	TRACKBUFFPNT,0		; トラックバッファ・レコードポインタ

	RET
SSRPLN	ENDP


;	クラスタ順次読み出し
;	-I- ES:DI : クラスタバッファアドレス
;	-O- AX    : 0=正常, 1=E.O.F, 2=ディスクエラー, 3=読み出し計画終了

SSRRDS	PROC	NEAR
	MOV	AX,1			; ハンドルＩＤ 1=読み込みハンドル
	CALL	SSRHDL			; ハンドル設定

	MOV	CLSTBUFSEG,ES		; クラスタバッファ・セグメント
	MOV	CLSTBUFOFS,DI		; クラスタバッファ・オフセット

	MOV	AX,TRACKBUFFPNT		; トラックバッファ・レコードポインタ
	CMP	AX,TRACKBUFFMAX		; トラックバッファ・レコード最大数
	JB	SSRRDS_GET		;

	CMP	RDNEXTCNT,0		; 読み出し待ちクラスタ数
	JMPEQ	SSRRDS_PLAN_END		;

	CALL	RECORDPLN		; 読み出し論理レコードテーブル設定
	CMP	RECNCNT,0		; 論理レコード数
	JE	SSRRDS_EOF		;

	MOV	FLAG_RWMODE,1		; フラグ・1=読み込み
	CALL	TRACKPLN		; 読み書きトラック設定
	CALL	TRACKBUFFPLN		; 読み書きトラックテーブル設定
	CALL	BUFFERREAD		; バッファ読み込み
	CMP	AX,0			; 0=正常,1=エラー
	JNE	SSRRDS_ERROR		;

	MOV	AX,RECNCNT		; 論理レコード数
	MOV	TRACKBUFFMAX,AX		; トラックバッファ・レコード最大数
	MOV	TRACKBUFFPNT,0		; トラックバッファ・レコードポインタ

SSRRDS_GET:
	MOV	AX,LEN_CLAST		; クラスタバイト数
	MOV	BX,TRACKBUFFPNT		; ×トラックバッファ・ポインタ
	MUL	BX			;
	ADD	AX,TRACKBUFFOFS		; ＋トラックバッファ・オフセット
	MOV	SI,AX			;

	MOV	ES,CLSTBUFSEG		; クラスタバッファ・セグメント
	MOV	DI,CLSTBUFOFS		; クラスタバッファ・オフセット
	MOV	DX,TRACKBUFFSEG		; トラックバッファ・セグメント
	MOV	CX,LEN_CLAST/2		; クラスタバイト数
	PUSH	DS			;
	MOV	DS,DX			;
	REP	MOVSW			;
	POP	DS			;

	INC	TRACKBUFFPNT		; トラックバッファ・レコードポインタ

SSRRDS_EXIT:
	MOV	AX,0			; 0=正常
	RET
SSRRDS_EOF:
	MOV	AX,1			; 1=E.O.F
	RET
SSRRDS_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	RET
SSRRDS_PLAN_END:
	MOV	AX,3			; 3=読み出し計画終了
	RET
SSRRDS	ENDP


;	連続レコード順次読み出し
;	-I- ES:DI : レコード読み出しバッファアドレス
;	    DX    : 読み出し開始論理レコード番号
;	    CX    : 読み出しレコード数
;	-O- AX    : 0=正常, 2=ディスクエラー

SSRRRD	PROC	NEAR
	MOV	AX,1			; ハンドルＩＤ 1=読み込みハンドル
	CALL	SSRHDL			; ハンドル設定

	MOV	RECDBUFSEG,ES		; レコードバッファセグメント
	MOV	RECDBUFOFS,DI		; レコードバッファオフセット

	MOV	RECSTARTNUM,DX		; 論理レコード番号
	MOV	RECCOUNT,CX		; 連続レコード数
SSRRRD_LOOP_ALL:
	CALL	RENRECSET		; 連続レコードテーブル設定

	CMP	RECNCNT,0		; 論理レコード数
	JE	SSRRRD_EXIT		;

	MOV	FLAG_RWMODE,1		; フラグ・1=読み込み
	CALL	TRACKPLN		; 読み書きトラック設定
	CALL	TRACKBUFFPLN		; 読み書きトラックテーブル設定
	CALL	BUFFERREAD		; バッファ読み込み
	CMP	AX,0			; 0=正常,1=エラー
	JNE	SSRRRD_ERROR		;

	MOV	AX,RECNCNT		; 論理レコード数
	MOV	BX,LEN_SECTOR		; ×セクタバイト数
	MUL	BX			;
	MOV	CX,AX			;
	SHR	CX,1			; word counter.

	MOV	ES,RECDBUFSEG		; レコードバッファセグメント
	MOV	DI,RECDBUFOFS		; レコードバッファオフセット
	ADD	RECDBUFOFS,AX		; レコードバッファオフセット

	MOV	DX,TRACKBUFFSEG		; トラックバッファ・セグメント
	MOV	SI,TRACKBUFFOFS		; トラックバッファ・オフセット

	PUSH	DS			;
	MOV	DS,DX			;
	REP	MOVSW			; copy.
	POP	DS			;

	JMP	SSRRRD_LOOP_ALL		;

SSRRRD_EXIT:
	MOV	AX,0			; 0=正常
	RET
SSRRRD_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	RET
SSRRRD	ENDP


;	クラスタ順次書き込み開始

SSWCSR	PROC	NEAR
	PUSH	AX
	MOV	AX,2			; ハンドルＩＤ 2=書き込みハンドル
	CALL	SSRHDL			; ハンドル設定

	MOV	WTNEXTPNT,NONE_CLAST	; 書き込み前回の空きクラスタ番号
	MOV	WTENDFATPNT,NONE_CLAST	; 書き込み前回のファイル終クラスタ番号
	POP	AX
	RET
SSWCSR	ENDP


;	クラスタ順次書き込み数設定
;	-I- CX : 書き込み待ちクラスタ数
;	-O- AX : 0=正常,4=空きが無い,5=指定クラスタ数が０
;	    DX : 開始クラスタ番号

SSWPLN	PROC	NEAR
	MOV	AX,2			; ハンドルＩＤ 2=書き込みハンドル
	CALL	SSRHDL			; ハンドル設定

	MOV	WTNEXTCNT,CX		; 書き込み待ちクラスタ数

	CALL	FRECLSTGET		; 空きクラスタ確保

	MOV	DX,RECNTBL[0]		; 論理レコード表
	SUB	DX,CLAST_OFFSET		; －クラスタ開始位置のセクタオフセット
	RET
SSWPLN	ENDP

	
;	クラスタ順次書き込み
;	-I- ES:DI : クラスタバッファアドレス
;	-O- AX    : 0=正常, 2=ディスクエラー, 3=書き込み計画終了
;		    4=空きエリアが無い

SSWWTS	PROC	NEAR
	MOV	AX,2			; ハンドルＩＤ 2=書き込みハンドル
	CALL	SSRHDL			; ハンドル設定

	MOV	CLSTBUFSEG,ES		; クラスタバッファ・セグメント
	MOV	CLSTBUFOFS,DI		; クラスタバッファ・オフセット

	CMP	TRACKBUFFMAX,0		; トラックバッファ・レコード最大数
	JNE	SSWWTS_PUT		;

	CALL	FRECLSTGET		; 空きクラスタ確保
	CMP	AX,5			; 5=指定クラスタ数が０
	JE	SSWWTS_PLAN_END		;
	CMP	AX,4			; 4=空きが無い
	JE	SSWWTS_NONE		;

SSWWTS_PUT:				;
	MOV	AX,LEN_CLAST		; クラスタバイト数
	MOV	BX,TRACKBUFFPNT		; ×トラックバッファ・ポインタ
	MUL	BX			;
	ADD	AX,TRACKBUFFOFS		; ＋トラックバッファ・オフセット
	MOV	DI,AX			;
	MOV	ES,TRACKBUFFSEG		; トラックバッファ・セグメント

	MOV	DX,CLSTBUFSEG		; クラスタバッファ・セグメント
	MOV	SI,CLSTBUFOFS		; クラスタバッファ・オフセット
	MOV	CX,LEN_CLAST/2		; クラスタバイト数
	PUSH	DS			;
	MOV	DS,DX			;
	REP	MOVSW			;
	POP	DS			;

	INC	TRACKBUFFPNT		; トラックバッファ・レコードポインタ

	MOV	AX,TRACKBUFFPNT		; トラックバッファ・レコードポインタ
	CMP	AX,TRACKBUFFMAX		; トラックバッファ・レコード最大数
	JB	SSWWTS_EXIT		;

SSWWTS_WRITE:				;
	CALL	BUFFERWRITE		; バッファ書き込み
	CMP	AX,0			; 0=正常,1=エラー
	JNE	SSWWTS_ERROR		;

	CALL	ALLFATSET	; 論理レコード表の内容をＦＡＴへ書き込む

	MOV	TRACKBUFFMAX,0		; トラックバッファ・レコード最大数
	MOV	TRACKBUFFPNT,0		; トラックバッファ・レコードポインタ

SSWWTS_EXIT:
	MOV	AX,0			; 0=正常
	RET
SSWWTS_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	RET
SSWWTS_PLAN_END:
	MOV	AX,3			; 3=書き込み計画終了
	RET
SSWWTS_NONE:
	MOV	AX,4			; 4=空きエリアが無い
	RET
SSWWTS	ENDP


;	クラスタ順次書き込み終了

SSWCED	PROC	NEAR
	MOV	AX,2			; ハンドルＩＤ 2=書き込みハンドル
	CALL	SSRHDL			; ハンドル設定

	CMP	WTNEXTPNT,NONE_CLAST	; 書き込み前回の空きクラスタ番号
	JE	SSWCED_EXIT		;
	MOV	AX,WTNEXTPNT		; 書き込み前回の空きクラスタ番号
	MOV	PNTNOW,AX		; 書き込むＦＡＴのクラスタ位置
	MOV	DX,FAT_EOF_CLAST	; ファイルの最後のクラスタ(FAT)
	CALL	FATSET			; ＦＡＴへクラスタ番号を書き込む
SSWCED_EXIT:
	RET
SSWCED	ENDP


;	連続レコード順次書き込み
;	-I- ES:DI : レコード書き込みバッファアドレス
;	    DX    : 書き込み開始論理レコード番号
;	    CX    : 書き込みレコード数
;	-O- AX    : 0=正常, 2=ディスクエラー

SSWRWT	PROC	NEAR
	MOV	AX,2			; ハンドルＩＤ 2=書き込みハンドル
	CALL	SSRHDL			; ハンドル設定

	MOV	RECDBUFSEG,ES		; レコードバッファセグメント
	MOV	RECDBUFOFS,DI		; レコードバッファオフセット

	MOV	RECSTARTNUM,DX		; 論理レコード番号
	MOV	RECCOUNT,CX		; 連続レコード数
SSWRWT_LOOP_ALL:
	CALL	RENRECSET		; 連続レコードテーブル設定

	CMP	RECNCNT,0		; 論理レコード数
	JE	SSWRWT_EXIT		;

	MOV	FLAG_RWMODE,2		; フラグ・2=書き込み
	CALL	TRACKPLN		; 読み書きトラック設定
	CALL	TRACKBUFFPLN		; 読み書きトラックテーブル設定

	MOV	AX,RECNCNT		; 論理レコード数
	MOV	BX,LEN_SECTOR		; ×セクタバイト数
	MUL	BX			;
	MOV	CX,AX			;
	SHR	CX,1			; word counter.

	MOV	DX,RECDBUFSEG		; レコードバッファセグメント
	MOV	SI,RECDBUFOFS		; レコードバッファオフセット
	ADD	RECDBUFOFS,AX		; レコードバッファオフセット

	MOV	ES,TRACKBUFFSEG		; トラックバッファ・セグメント
	MOV	DI,TRACKBUFFOFS		; トラックバッファ・オフセット

	PUSH	DS			;
	MOV	DS,DX			;
	REP	MOVSW			; copy.
	POP	DS			;

	CALL	BUFFERWRITE		; バッファ書き込み
	CMP	AX,0			; 0=正常,1=エラー
	JNE	SSWRWT_ERROR		;

	JMP	SSWRWT_LOOP_ALL		;

SSWRWT_EXIT:
	MOV	AX,0			; 0=正常
	RET
SSWRWT_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	RET
SSWRWT	ENDP


;	空きクラスタ確保
;	-I/O- WTNEXTPNT : 書き込み前回の空きクラスタ番号
;	      WTNEXTCNT : 書き込み待ちクラスタ数
;	-O-   RECNTBL[] : 論理レコード表
;	      RECNCNT   : 論理レコード数
;	      TRKCNT    : 読み書きトラック数
;	      TRKDCYL[] : 読み書きシリンダ番号表
;	      TRKHEAD[] : 読み書きヘッド番号表
;	      TRKDSECR[]: 読み書きセクタ番号表
;	      TRKDLEN[] : 読み書きデータ長表
;	      TRKBUFFSEG[] : 読み書きバッファセグメント
;	      TRKBUFFOFS[] : 読み書きバッファオフセット
;	      TRACKBUFFMAX : トラックバッファ・レコード最大数
;	      TRACKBUFFPNT : トラックバッファ・レコードポインタ
;	      AX        : 0=正常,4=空きが無い,5=指定クラスタ数が０

FRECLSTGET	PROC	NEAR
	CMP	WTNEXTCNT,0		; 書き込み待ちクラスタ数
	JE	FRECLSTGET_EXIT2	;

	CALL	RECWRTPLN		; 書き込み論理レコードテーブル設定
	CMP	AX,0			; 0=通常,1=空きエリアが無い
	JNE	FRECLSTGET_NONE		;

	CMP	RECNCNT,0		; 論理レコード数
	JE	FRECLSTGET_EXIT2	;

	MOV	FLAG_RWMODE,2		; フラグ・2=書き込み
	CALL	TRACKPLN		; 読み書きトラック設定
	CALL	TRACKBUFFPLN		; 読み書きトラックテーブル設定

	MOV	AX,RECNCNT		; 論理レコード数
	MOV	TRACKBUFFMAX,AX		; トラックバッファ・レコード最大数
	MOV	TRACKBUFFPNT,0		; トラックバッファ・レコードポインタ

	MOV	AX,0			; 0=正常
	RET
FRECLSTGET_EXIT2:
	MOV	DX,0
	MOV	AX,5			; 5=指定クラスタ数が０
	RET
FRECLSTGET_NONE:
	MOV	DX,0
	MOV	AX,4			; 4=空きエリアが無い
	RET
FRECLSTGET	ENDP



;	論理レコード表の内容をＦＡＴへ書き込む
;	-I-   RECNTBL[] : 論理レコード表
;	      RECNCNT   : 論理レコード数
;	-I/O- WTENDFATPNT : 書き込み前回のファイル終クラスタ番号

ALLFATSET	PROC	NEAR
	MOV	SI,0			; word pointer.
	MOV	CX,RECNCNT		; 論理レコード数
	JCXZ	ALLFATSET_LOOP_E	;
ALLFATSET_LOOP:				;
	MOV	AX,WTENDFATPNT		; 書き込み前回のファイル終クラスタ番号
	MOV	PNTNOW,AX		; 書き込むＦＡＴのクラスタ位置
	MOV	DX,RECNTBL[SI]		; 論理レコード表
	SUB	DX,CLAST_OFFSET		; －クラスタ開始位置のセクタオフセット
	MOV	WTENDFATPNT,DX		; 書き込み前回のファイル終クラスタ番号

	CMP	PNTNOW,MIN_CLAST	; 最小クラスタ番号
	JB	ALLFATSET_NEXT		;
	PUSH	SI			;
	PUSH	CX			;
	CALL	FATSET			; ＦＡＴへクラスタ番号を書き込む
	POP	CX			;
	POP	SI			;
ALLFATSET_NEXT:
	INC	SI
	INC	SI
	LOOP	ALLFATSET_LOOP
ALLFATSET_LOOP_E:

ALLFATSET_SKIP:
	RET
ALLFATSET	ENDP



;	連続レコードテーブル設定
;	-I/O- RECSTARTNUM : 論理レコード番号
;	      RECCOUNT    : 連続レコード数
;	-O-   RECNTBL[]   : 論理レコード表
;	      RECNCNT     : 論理レコード数

RENRECSET	PROC	NEAR
	MOV	RECNCNT,0		; 論理レコード数
RENRECSET_LOOP:
	CMP	RECCOUNT,0		; 連続レコード数
	JE	RENRECSET_LOOP_E	;

	MOV	AX,RECNCNT		; 論理レコード数
	CMP	AX,RECNDIM		; 論理レコード最大数
	JNB	RENRECSET_LOOP_E	;

	MOV	AX,RECSTARTNUM		; 論理レコード番号
	MOV	SI,RECNCNT		; 論理レコード数
	SHL	SI,1			; word pointer.
	MOV	RECNTBL[SI],AX		; 論理レコード表 <- 読み出すレコード

	INC	RECNCNT			; 論理レコード数
	INC	RECSTARTNUM		; 論理レコード番号
	DEC	RECCOUNT		; 連続レコード数

	JMP	RENRECSET_LOOP		;
RENRECSET_LOOP_E:
IF DEBUG	; debug flag.
	CALL	DUMP_RECORD		; dump : 論理レコード表
ENDIF
	RET
RENRECSET	ENDP


;	読み出し論理レコードテーブル設定
;	-I/O- RDNEXTPNT : 読み出し待ちクラスタ番号
;	      RDNEXTCNT : 読み出し待ちクラスタ数
;	-O-   RECNTBL[] : 論理レコード表
;	      RECNCNT   : 論理レコード数

RECORDPLN	PROC	NEAR

IF DEBUG	; debug flag.
PRVH	"RDNEXTPNT=",RDNEXTPNT
PRV	"RDNEXTCNT=",RDNEXTCNT
ENDIF

	MOV	RECNCNT,0		; 論理レコード数
RECORDPLN_LOOP:
	CMP	RDNEXTCNT,0		; 読み出し待ちクラスタ数
	JE	RECORDPLN_EXIT		;

	MOV	BX,RECNCNT		; 論理レコード数
	CMP	BX,RECNDIM		; 論理レコード最大数
	JNB	RECORDPLN_EXIT		;

	MOV	AX,RDNEXTPNT		; 読み出し待ちクラスタ番号

	CMP	AX,MAX_CLAST		; 最大クラスタ番号
	JNBE	RECORDPLN_EXIT		;
	CMP	AX,MIN_CLAST		; 最小クラスタ番号
	JB	RECORDPLN_EXIT		;

	ADD	AX,CLAST_OFFSET		; クラスタ開始位置のセクタオフセット
	SHL	BX,1			; word pointer.
	MOV	RECNTBL[BX],AX		; 論理レコード表
	INC	RECNCNT			; 論理レコード数

	MOV	AX,RDNEXTPNT		; 読み出し待ちクラスタ番号
	MOV	PNTNOW,AX		; 現在のクラスタ番号

	CALL	NXTNUM			; 次のクラスタ番号を取り出す

	MOV	AX,PNTNXT		; 続きのクラスタ番号
	MOV	RDNEXTPNT,AX		; 読み出し待ちクラスタ番号

	DEC	RDNEXTCNT		; 読み出し待ちクラスタ数

	JMP	RECORDPLN_LOOP
RECORDPLN_EXIT:
IF DEBUG	; debug flag.
	CALL	DUMP_RECORD		; dump : 論理レコード表
ENDIF
	RET
RECORDPLN	ENDP


;	書き込み論理レコードテーブル設定
;	-I/O- WTNEXTPNT : 書き込み前回の空きクラスタ番号
;	      WTNEXTCNT : 書き込み待ちクラスタ数
;	-O-   RECNTBL[] : 論理レコード表
;	      RECNCNT   : 論理レコード数
;	      AX        : 0=通常,1=空きエリアが無い

RECWRTPLN	PROC	NEAR

IF DEBUG	; debug flag.
PRVH	"WTNEXTPNT=",WTNEXTPNT
PRV	"WTNEXTCNT=",WTNEXTCNT
ENDIF

	MOV	RECNCNT,0		; 論理レコード数
RECWRTPLN_LOOP:
	CMP	WTNEXTCNT,0		; 書き込み待ちクラスタ数
	JE	RECWRTPLN_EXIT		;

	MOV	BX,RECNCNT		; 論理レコード数
	CMP	BX,RECNDIM		; 論理レコード最大数
	JNB	RECWRTPLN_EXIT		;

	MOV	AX,WTNEXTPNT		; 書き込み前回の空きクラスタ番号
	MOV	PNTNOW,AX		; 現在のクラスタ番号
	CALL	NXTFRE			; 次の空きクラスタを捜す
	CMP	AX,0			; 0=通常,1=空きセクタ無し
	JNE	RECWRTPLN_NONE		;

	MOV	AX,PNTFRE		; 次の空きクラスタ番号
	MOV	WTNEXTPNT,AX		; 書き込み前回の空きクラスタ番号

	ADD	AX,CLAST_OFFSET		; クラスタ開始位置のセクタオフセット
	SHL	BX,1			; word pointer.
	MOV	RECNTBL[BX],AX		; 論理レコード表
	INC	RECNCNT			; 論理レコード数

	DEC	WTNEXTCNT		; 書き込み待ちクラスタ数

	JMP	RECWRTPLN_LOOP		;

RECWRTPLN_EXIT:
IF DEBUG	; debug flag.
	CALL	DUMP_RECORD		; dump : 論理レコード表
ENDIF
	MOV	AX,0			; 0=通常
	RET
RECWRTPLN_NONE:
	MOV	AX,1			; 1=空きエリアが無い
	RET
RECWRTPLN	ENDP


;	読み書きトラック設定
;	-I-   RECNTBL[] : 論理レコード表
;	      RECNCNT   : 論理レコード数
;	      FLAG_RWMODE: フラグ・1=読み込み,2=書き込み
;	-O-   TRKCNT    : 読み書きトラック数
;	      TRKDCYL[] : 読み書きシリンダ番号表
;	      TRKHEAD[] : 読み書きヘッド番号表
;	      TRKDSECR[]: 読み書きセクタ番号表
;	      TRKDLEN[] : 読み書きデータ長表
;	読み込み時のトラック連続は最大１６セクタ（両面）まで
;	書き込み時のトラック連続は最大８セクタ（片面）まで

TRACKPLN	PROC	NEAR
	MOV	DLEN,0			; データ長
	MOV	DCYL,0			; シリンダ番号（Ｃ）０ー７６
	MOV	DHEAD,0			; ヘッド番号（Ｈ）０ー１
	MOV	DSECR,0			; セクタ番号（Ｒ）１ー８（２６）

	MOV	RECPNT,0		; 論理レコード表ポインタ
	MOV	TRKCNT,0		; 読み書きトラック数
TRACKPLN_LOOP:
	MOV	AX,TRKCNT		; 読み書きトラック数
	CMP	AX,TRKDIM		; 読み書きトラック最大数
	JMPNB	TRACKPLN_EXIT		;

	MOV	BX,RECPNT		; 論理レコード表ポインタ
	CMP	BX,RECNCNT		; 論理レコード数
	JMPNB	TRACKPLN_EXIT		;

	SHL	BX,1			; word pointer.
	MOV	AX,RECNTBL[BX]		; 論理レコード表
	INC	RECPNT			; 論理レコード表ポインタ

	CALL	RECTOTRK		; 論理レコードからセクタ位置計算
	MOV	DCYL,AX			; シリンダ番号（Ｃ）
	MOV	DHEAD,CX		; ヘッド番号（Ｈ）
	MOV	NOWHED,CX		; 現在ヘッド番号
	MOV	DSECR,DX		; セクタ番号（Ｒ）
	MOV	NOWSEC,DX		; 現在セクタ番号
	MOV	DLEN,LEN_SECTOR		; データ長

TRACKPLN_LOOP2:
	INC	NOWSEC			; 現在セクタ番号

	MOV	AX,NOWHED		; 現在ヘッド番号
	CMP	AX,MAXHED		; 最大ヘッド番号
	JB	TRACKPLN_3		;

	MOV	AX,NOWSEC		; 現在セクタ番号
	CMP	AX,MAXSEC		; 最大セクタ番号
	JBE	TRACKPLN_5		;

	JMP	TRACKPLN_LOOP2_E	;
TRACKPLN_3:
	MOV	AX,NOWSEC		; 現在セクタ番号
	CMP	AX,MAXSEC		; 最大セクタ番号
	JBE	TRACKPLN_5		;

	CMP	FLAG_RWMODE,2		; フラグ・1=読み込み,2=書き込み
	JE	TRACKPLN_LOOP2_E	;

	INC	NOWHED			; 現在ヘッド番号
	MOV	NOWSEC,1		; 現在セクタ番号
TRACKPLN_5:

	MOV	BX,RECPNT		; 論理レコード表ポインタ
	CMP	BX,RECNCNT		; 論理レコード数
	JNB	TRACKPLN_LOOP2_E	;

	SHL	BX,1			; word pointer.
	MOV	AX,RECNTBL[BX]		; 論理レコード表

	CALL	RECTOTRK		; 論理レコードからセクタ位置計算

	CMP	AX,DCYL			; シリンダ番号（Ｃ）
	JNE	TRACKPLN_LOOP2_E	;
	CMP	CX,NOWHED		; 現在ヘッド番号
	JNE	TRACKPLN_LOOP2_E	;
	CMP	DX,NOWSEC		; 現在セクタ番号
	JNE	TRACKPLN_LOOP2_E	;

	ADD	DLEN,LEN_SECTOR		; データ長
	INC	RECPNT			; 論理レコード表ポインタ

	JMP	TRACKPLN_LOOP2		;

TRACKPLN_LOOP2_E:			;
	MOV	SI,TRKCNT		; 読み書きトラック数
	SHL	SI,1			; word pointer.
	MOV	AX,DCYL			; シリンダ番号（Ｃ）
	MOV	BX,DHEAD		; ヘッド番号（Ｈ）
	MOV	CX,DSECR		; セクタ番号（Ｒ）
	MOV	DX,DLEN			; データ長
	MOV	TRKDCYL[SI],AX		; 読み書きシリンダ番号表
	MOV	TRKHEAD[SI],BX		; 読み書きヘッド番号表
	MOV	TRKDSECR[SI],CX		; 読み書きセクタ番号表
	MOV	TRKDLEN[SI],DX		; 読み書きデータ長表
	INC	TRKCNT			; 読み書きトラック数

	JMP	TRACKPLN_LOOP

TRACKPLN_EXIT:
	RET
TRACKPLN	ENDP


;	読み書きトラックテーブル設定
;	-I- TRKCNT     : 読み書きトラック数
;	    TRKDLEN[]  : 読み書きデータ長表
;	-O- TRKBUFFSEG[] : 読み書きバッファセグメント
;	    TRKBUFFOFS[] : 読み書きバッファオフセット

TRACKBUFFPLN	PROC	NEAR
	MOV	DX,TRACKBUFFSEG			; トラックバッファ・セグメント
	MOV	BX,TRACKBUFFOFS			; トラックバッファ・オフセット

	MOV	SI,0				; word pointer.
	MOV	CX,TRKCNT			; 読み書きトラック数
	JCXZ	TRACKBUFFPLN_EXIT		;
TRACKBUFFPLN_LOOP:
	MOV	TRKBUFFSEG[SI],DX		; 読み書きバッファセグメント
	MOV	TRKBUFFOFS[SI],BX		; 読み書きバッファオフセット
	ADD	BX,TRKDLEN[SI]			; 読み書きデータ長表
	INC	SI				;
	INC	SI				; word pointer.
	LOOP	TRACKBUFFPLN_LOOP		;
TRACKBUFFPLN_EXIT:
IF DEBUG	; debug flag.
	CALL	DUMP_TRACK		; dump : トラック表
ENDIF
	RET
TRACKBUFFPLN	ENDP


;	バッファ読み込み
;	-I- TRKCNT       : 読み書きトラック数
;	    TRKDCYL[]    : 読み書きシリンダ番号表
;	    TRKHEAD[]    : 読み書きヘッド番号表
;	    TRKDSECR[]   : 読み書きセクタ番号表
;	    TRKDLEN[]    : 読み書きデータ長表
;	    TRKBUFFSEG[] : 読み書きバッファセグメント
;	    TRKBUFFOFS[] : 読み書きバッファオフセット
;	-O- AX           : 0=正常,1=エラー

BUFFERREAD	PROC	NEAR
	MOV	SI,0			; word pointer.
	MOV	CX,TRKCNT		; 読み書きトラック数
BUFFERREAD_LOOP:
	PUSH	CX			;
	PUSH	SI			;

	MOV	AX,TRKDCYL[SI]		; 読み書きシリンダ番号表
	MOV	BX,TRKHEAD[SI]		; 読み書きヘッド番号表
	MOV	CX,TRKDSECR[SI]		; 読み書きセクタ番号表
	MOV	DX,TRKDLEN[SI]		; 読み書きデータ長表
	MOV	DCYL,AX			; シリンダ番号（Ｃ）０ー７６
	MOV	DHEAD,BX		; ヘッド番号（Ｈ）０ー１
	MOV	DSECR,CX		; セクタ番号（Ｒ）１ー８（２６）
	MOV	DLEN,DX			; データ長（ＤＴＬ）（バイト単位）

	MOV	AX,TRKBUFFSEG[SI]	; 読み書きバッファセグメント
	MOV	BX,TRKBUFFOFS[SI]	; 読み書きバッファオフセット
	MOV	BUFFSEG,AX		; バッファ・セグメント
	MOV	BUFFOFS,BX		; バッファ・オフセット
	CALL	RDSECTOR		; セクタＲＥＡＤ

	POP	SI			;
	POP	CX			;

	CMP	DERROR,0		; 0=正常,1=エラー
	JNE	BUFFERREAD_ERROR	;

	INC	SI			;
	INC	SI			; word pointer.
	LOOP	BUFFERREAD_LOOP		;

BUFFERREAD_EXIT:
	MOV	AX,0			; 0=正常
	RET
BUFFERREAD_ERROR:
	MOV	AX,1			; 1=エラー
	RET
BUFFERREAD	ENDP


;	バッファ書き込み
;	-I- TRKCNT       : 読み書きトラック数
;	    TRKDCYL[]    : 読み書きシリンダ番号表
;	    TRKHEAD[]    : 読み書きヘッド番号表
;	    TRKDSECR[]   : 読み書きセクタ番号表
;	    TRKDLEN[]    : 読み書きデータ長表
;	    TRKBUFFSEG[] : 読み書きバッファセグメント
;	    TRKBUFFOFS[] : 読み書きバッファオフセット
;	-O- AX           : 0=正常,1=エラー

BUFFERWRITE	PROC	NEAR
	MOV	SI,0			; word pointer.
	MOV	CX,TRKCNT		; 読み書きトラック数
BUFFERWRITE_LOOP:
	PUSH	CX			;
	PUSH	SI			;

	MOV	AX,TRKDCYL[SI]		; 読み書きシリンダ番号表
	MOV	BX,TRKHEAD[SI]		; 読み書きヘッド番号表
	MOV	CX,TRKDSECR[SI]		; 読み書きセクタ番号表
	MOV	DX,TRKDLEN[SI]		; 読み書きデータ長表
	MOV	DCYL,AX			; シリンダ番号（Ｃ）０ー７６
	MOV	DHEAD,BX		; ヘッド番号（Ｈ）０ー１
	MOV	DSECR,CX		; セクタ番号（Ｒ）１ー８（２６）
	MOV	DLEN,DX			; データ長（ＤＴＬ）（バイト単位）

	MOV	AX,TRKBUFFSEG[SI]	; 読み書きバッファセグメント
	MOV	BX,TRKBUFFOFS[SI]	; 読み書きバッファオフセット
	MOV	BUFFSEG,AX		; バッファ・セグメント
	MOV	BUFFOFS,BX		; バッファ・オフセット
	CALL	WTSECTOR		; セクタＷＲＩＴＥ

	POP	SI			;
	POP	CX			;

	CMP	DERROR,0		; 0=正常,1=エラー
	JNE	BUFFERWRITE_ERROR	;

	INC	SI			;
	INC	SI			; word pointer.
	LOOP	BUFFERWRITE_LOOP	;

BUFFERWRITE_EXIT:
	MOV	AX,0			; 0=正常
	RET
BUFFERWRITE_ERROR:
	MOV	AX,1			; 1=エラー
	RET
BUFFERWRITE	ENDP


;	論理レコードからセクタ位置計算
;	-I- AX    : 論理レコード番号
;	-O- DX    : セクタ番号
;	    CX    : ヘッド番号
;	    AX    : シリンダ番号（Ｃ）０ー７６

RECTOTRK	PROC	NEAR
	MOV	DX,AX			;
	SHR	AX,1			;
	SHR	AX,1			;
	SHR	AX,1			;
	AND	DX,07H			; ８で割る（ＡＸ答え、ＤＸ余り）

	INC	DX			; セクタ番号（Ｒ）１ー８（２６）

	MOV	CX,AX			; ヘッド番号（Ｈ）０ー１
	AND	CX,0001H		; 偶数と奇数

	SHR	AX,1			; シリンダ番号（Ｃ）０ー７６
	RET
RECTOTRK	ENDP


;	セクタＲＥＡＤ
;	-I- DCYL    : シリンダ番号（Ｃ）０ー７６
;	    DHEAD   : ヘッド番号（Ｈ）０ー１
;	    DSECR   : セクタ番号（Ｒ）１ー８（２６）
;	    DLEN    : データ長（ＤＴＬ）（バイト単位）
;	    BUFFSEG : バッファ・セグメント
;	    BUFFOFS : バッファ・オフセット
;	-O- DERROR : 0=正常,1=エラー

RDSECTOR	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	MOV	READ_RETRY,READ_RETCOUNT ; ＲＥＡＤ・リトライ回数
RDSECTOR_RETRY:
	MOV	ES,BUFFSEG		; バッファ・セグメント
	MOV	BP,BUFFOFS		; バッファ・オフセット
	MOV	AL,BYTE PTR DUNIT	; デバイス識別・ユニット番号(DA/UA)
	MOV	BX,WORD PTR DLEN 	; データ長（ＤＴＬ）（バイト単位）
	MOV	CL,BYTE PTR DCYL 	; シリンダ番号（Ｃ）０ー７６
	MOV	DH,BYTE PTR DHEAD	; ヘッド番号（Ｈ）０ー１
	MOV	DL,BYTE PTR DSECR	; セクタ番号（Ｒ）１ー８（２６）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）
	MOV	AH,BYTE PTR DREAD	; ＲＥＡＤ　ＤＡＴＡ

	INT	1BH			; ディスクＢＩＯＳ
	JC	RDSECTOR_ERROR		;
RDSECTOR9:
	MOV	DERROR,0		; 0=正常
	RET				;

RDSECTOR_ERROR:				;
	CMP	AH,20H			; ＤＭＡ　Ｂｏｕｎｄａｒｙ
	JE	RDSECTOR_ERROR2		;

	CMP	AH,60H			; Not Ready. ユニットがノットレディ状態
	JE	RDSECTOR_ER_END		;

	DEC	READ_RETRY		; ＲＥＡＤ・リトライカウンタ
	JZ	RDSECTOR_ER_END		;

	MOV	AH,BYTE PTR DRECAL	; ＲＥＣＡＬＩＢＲＡＴＥ
	INT	1BH			; ディスクＢＩＯＳ
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	JMP	RDSECTOR_RETRY		;

RDSECTOR_ERROR2:
	PRF	"(READSEC.ASM) fatal error : DMA boundary."
RDSECTOR_ER_END:				;
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	MOV	DERROR,1		; 1=エラー
	RET				;
RDSECTOR	ENDP


;	セクタＷＲＩＴＥ
;	-I- DCYL    : シリンダ番号（Ｃ）０ー７６
;	    DHEAD   : ヘッド番号（Ｈ）０ー１
;	    DSECR   : セクタ番号（Ｒ）１ー８（２６）
;	    DLEN    : データ長（ＤＴＬ）（バイト単位）
;	    BUFFSEG : バッファ・セグメント
;	    BUFFOFS : バッファ・オフセット
;	-O- DERROR : 0=正常,1=エラー

WTSECTOR	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	MOV	WRITE_RETRY,WRITE_RETCOUNT ; ＷＲＩＴＥ・リトライ回数
WTSECTOR_RETRY:
	MOV	ES,BUFFSEG		; バッファ・セグメント
	MOV	BP,BUFFOFS		; バッファ・オフセット
	MOV	AL,BYTE PTR DUNIT	; デバイス識別・ユニット番号(DA/UA)
	MOV	BX,WORD PTR DLEN 	; データ長（ＤＴＬ）（バイト単位）
	MOV	CL,BYTE PTR DCYL 	; シリンダ番号（Ｃ）０ー７６
	MOV	DH,BYTE PTR DHEAD	; ヘッド番号（Ｈ）０ー１
	MOV	DL,BYTE PTR DSECR	; セクタ番号（Ｒ）１ー８（２６）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）
	MOV	AH,BYTE PTR DWRITE	; ＷＲＩＴＥ　ＤＡＴＡ

	INT	1BH			; ディスクＢＩＯＳ
	JC	WTSECTOR_ERROR		;
WTSECTOR9:
	MOV	DERROR,0		; 0=正常
	RET				;

WTSECTOR_ERROR:				;
	CMP	AH,20H			; ＤＭＡ　Ｂｏｕｎｄａｒｙ
	JE	WTSECTOR_ERROR2		;

	CMP	AH,60H			; Not Ready. ユニットがノットレディ状態
	JE	WTSECTOR_ER_END		;

	DEC	WRITE_RETRY		; ＷＲＩＴＥ・リトライカウンタ
	JZ	WTSECTOR_ER_END		;

	MOV	AH,BYTE PTR DRECAL	; ＲＥＣＡＬＩＢＲＡＴＥ
	INT	1BH			; ディスクＢＩＯＳ
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	JMP	WTSECTOR_RETRY		;

WTSECTOR_ERROR2:
	PRF	"(READSEC.ASM) fatal error : DMA boundary."
WTSECTOR_ER_END:				;
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	MOV	DERROR,1		; 1=エラー
	RET				;
WTSECTOR	ENDP


;	ハンドル設定
;	-I- AX : ハンドルＩＤ 1=読み込みハンドル,2=書き込みハンドル

SSRHDL	PROC	NEAR
	PUSH	ES
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	SI
	PUSH	DI
	PUSH	BP
	CALL	HANDLE_CHG		; ハンドルの切り替え
	POP	BP
	POP	DI
	POP	SI
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	POP	ES
	RET
SSRHDL	ENDP

;	ハンドルの切り替え
;	-I- AX : ハンドルＩＤ 1=読み込みハンドル,2=書き込みハンドル

HANDLE_CHG	PROC	NEAR
	CMP	AX,0			;
	JE	HANDLE_CHG_EXIT		;
	CMP	AX,HANDLE_MAX		; ハンドル数
	JNBE	HANDLE_CHG_EXIT		;
	
	CMP	AX,HANDLE_CURENT	; カレント・ハンドルＩＤ
	JE	HANDLE_CHG_EXIT		;

	MOV	SI,OFFSET HANDLE_START	; ハンドルスタート
	MOV	DI,OFFSET HANDLE_2_START ; ハンドル２スタート
	MOV	CX,HANDLE_LEN		; ハンドル長さ
HANDLE_CHG_LOOP:
	MOV	AL,DS:[SI]		;
	MOV	BL,DS:[DI]		;
	MOV	DS:[SI],BL		;
	MOV	DS:[DI],AL		;
	INC	SI
	INC	DI
	LOOP	HANDLE_CHG_LOOP

	MOV	AX,HANDLE_NUM		; ハンドルＩＤ＝１
	MOV	HANDLE_CURENT,AX	; カレント・ハンドルＩＤ

HANDLE_CHG_EXIT:
	RET
HANDLE_CHG	ENDP


IF DEBUG	; debug flag.

;	dump : 論理レコード表

DUMP_RECORD	PROC	NEAR
	PR	"rec["
	MOV	DX,RECNCNT		; 論理レコード数
	CALL	DECSTR			;
	INC	SI			;
	INC	SI			;
	CALL	PRINT			;
	MOV	AL,']'			;
	CALL	CHPUT			;

	MOV	BX,0			; word pointer.
	MOV	CX,RECNCNT		; 論理レコード数
	JCXZ	DUMP_RECORD_EXIT	;
DUMP_RECORD_LOOP:
	MOV	DX,RECNTBL[BX]		; 論理レコード表
	CALL	HEXSTR			;
	INC	SI			;
	CALL	PRINT			;
	MOV	AL,' '			;
	CALL	CHPUT			;
	INC	BX
	INC	BX
	LOOP	DUMP_RECORD_LOOP
DUMP_RECORD_EXIT:
	LF
	RET
DUMP_RECORD	ENDP


;	dump : トラック表

DUMP_TRACK	PROC	NEAR
	MOV	BX,0			; word pointer.
	MOV	BP,0			; number.
	MOV	CX,TRKCNT		; 読み書きトラック数
DUMP_TRACK_LOOP:
	PR	"trk<"
	MOV	DX,BP
	CALL	DUMP_1VAL		; １値表示
	MOV	AL,'>'			;
	CALL	CHPUT			;
	INC	BP			;
	MOV	DX,TRKDCYL[BX]		; 読み書きシリンダ番号表
	CALL	DUMP_1VAL		; １値表示
	MOV	DX,TRKHEAD[BX]		; 読み書きヘッド番号表
	CALL	DUMP_1VAL		; １値表示
	MOV	DX,TRKDSECR[BX]		; 読み書きセクタ番号表
	CALL	DUMP_1VAL		; １値表示
	MOV	DX,TRKDLEN[BX]		; 読み書きデータ長表
	CALL	DUMP_1VAL		; １値表示
	MOV	DX,TRKBUFFSEG[BX]	; 読み書きバッファセグメント
	CALL	DUMP_1VAL		; １値表示
	MOV	DX,TRKBUFFOFS[BX]	; 読み書きバッファオフセット
	CALL	DUMP_1VAL		; １値表示
	LF
	INC	BX
	INC	BX
	LOOP	DUMP_TRACK_LOOP
	RET
DUMP_TRACK	ENDP


;	１値表示
;	-I- DX : 数値

DUMP_1VAL	PROC	NEAR
	CALL	HEXSTR			;
	CALL	PRINT			;
	MOV	AL,' '			;
	CALL	CHPUT			;
	RET
DUMP_1VAL	ENDP

ENDIF		; debug flag.

CODE	ENDS


;	ディスクキャッシュバッファ
;	悩めるＤＭＡバッファの群たち・・・
;
;	SEC_ID_TBL1(セクタＩＤバッファ)と
;	SEC_ID_TBL2(セクタＩＤバッファ)の間は１０２４バイト以上あけること
;	SEC_ID_TBL2はバウンダリエラー用の予備です。（"DKFROM.ASM"で使用）

CHASHB	SEGMENT	PUBLIC	'CHASHB'

EXTRN	SEC_ID_TBL1:BYTE		; セクタＩＤバッファ
EXTRN	SEC_ID_TBL2:BYTE		; セクタＩＤバッファ

EXTRN	CHASH_BUFFER1:BYTE		; トラックバッファ
EXTRN	CHASH_BUFFER2:BYTE		; トラックバッファ

CHASHB	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

EXTRN	PNTNOW:WORD			; 現在のクラスタ番号
EXTRN	PNTNXT:WORD			; 続きのクラスタ番号
EXTRN	PNTFRE:WORD			; 次の空きクラスタ番号

EXTRN	DREAD:WORD			; ＲＥＡＤ　ＤＡＴＡ
EXTRN	DWRITE:WORD			; ＷＲＩＴＥ　ＤＡＴＡ
EXTRN	DRECAL:WORD			; ＲＥＣＡＬＩＢＲＡＴＥ
EXTRN	DUNIT:WORD			; デバイス識別・ユニット番号（DA/UA）

DLEN		DW	0		; データ長（ＤＴＬ）（バイト単位）
DCYL		DW	0		; シリンダ番号（Ｃ）０ー７６
DHEAD		DW	0		; ヘッド番号（Ｈ）０ー１
DSECR		DW	1		; セクタ番号（Ｒ）１ー８（２６）
DSECN		DW	03		; セクタ長（Ｎ）
DSTAT		DW	0		; ステータス情報
DERROR		DW	0		; 0=正常,1=エラー

READ_RETRY	DW	0		; ＲＥＡＤ・リトライカウンタ
WRITE_RETRY	DW	0		; ＷＲＩＴＥ・リトライカウンタ

MAXSEC		DW	8		; 最大セクタ番号
NOWSEC		DW	0		; 現在セクタ番号
MAXHED		DW	1		; 最大ヘッド番号
NOWHED		DW	0		; 現在ヘッド番号

HANDLE_CURENT	DW	1		; カレント・ハンドルＩＤ
HANDLE_MAX	DW	2		; ハンドル数
HANDLE_LEN	DW	HANDLE_END - HANDLE_START ; ハンドル長さ

HANDLE_START	LABEL	BYTE		; ハンドルスタート
HANDLE_NUM	DW	1		; ハンドルＩＤ＝１

TRACKBUFFSEG	DW	SEG CHASHB		; トラックバッファ・セグメント
TRACKBUFFOFS	DW	OFFSET CHASH_BUFFER1	; トラックバッファ・オフセット

TRACKBUFFMAX	DW	0		; トラックバッファ・レコード最大数
TRACKBUFFPNT	DW	0		; トラックバッファ・レコードポインタ

RDNEXTPNT	DW	0		; 読み出し待ちクラスタ番号
RDNEXTCNT	DW	0		; 読み出し待ちクラスタ数

WTENDFATPNT	DW	0		; 書き込み前回のファイル終クラスタ番号
WTNEXTPNT	DW	0		; 書き込み前回の空きクラスタ番号
WTNEXTCNT	DW	0		; 書き込み待ちクラスタ数

RECNDIM		DW	RECBUFFMAX		; 論理レコード最大数
RECNCNT		DW	0			; 論理レコード数
RECNTBL		DW	RECBUFFMAX DUP (0)	; 論理レコード表
RECPNT		DW	0			; 論理レコード表ポインタ

TRKDIM		DW	RECBUFFMAX		; 読み書きトラック最大数
TRKCNT		DW	0			; 読み書きトラック数
TRKDCYL		DW	RECBUFFMAX DUP (0)	; 読み書きシリンダ番号表
TRKHEAD		DW	RECBUFFMAX DUP (0)	; 読み書きヘッド番号表
TRKDSECR	DW	RECBUFFMAX DUP (0)	; 読み書きセクタ番号表
TRKDLEN		DW	RECBUFFMAX DUP (0)	; 読み書きデータ長表
TRKBUFFSEG	DW	RECBUFFMAX DUP (0)	; 読み書きバッファセグメント
TRKBUFFOFS	DW	RECBUFFMAX DUP (0)	; 読み書きバッファオフセット

CLSTBUFSEG	DW	0		; クラスタバッファ・セグメント
CLSTBUFOFS	DW	0		; クラスタバッファ・オフセット

HANDLE_END	LABEL	BYTE		; ハンドルエンド

HANDLE_2_START	LABEL	BYTE		; ハンドル２スタート
	DW	2			; ハンドルＩＤ＝２
	DW	SEG CHASHB		; トラックバッファ・セグメント
	DW	OFFSET CHASH_BUFFER1	; トラックバッファ・オフセット
	DW	0			; トラックバッファ・レコード最大数
	DW	0			; トラックバッファ・レコードポインタ
	DW	0			; 読み出し待ちクラスタ番号
	DW	0			; 読み出し待ちクラスタ数
	DW	0		; 書き込み前回のファイル終クラスタ番号
	DW	0			; 書き込み前回の空きクラスタ番号
	DW	0			; 書き込み待ちクラスタ数
	DW	RECBUFFMAX		; 論理レコード最大数
	DW	0			; 論理レコード数
	DW	RECBUFFMAX DUP (0)	; 論理レコード表
	DW	0			; 論理レコード表ポインタ
	DW	RECBUFFMAX		; 読み書きトラック最大数
	DW	0			; 読み書きトラック数
	DW	RECBUFFMAX DUP (0)	; 読み書きシリンダ番号表
	DW	RECBUFFMAX DUP (0)	; 読み書きヘッド番号表
	DW	RECBUFFMAX DUP (0)	; 読み書きセクタ番号表
	DW	RECBUFFMAX DUP (0)	; 読み書きデータ長表
	DW	RECBUFFMAX DUP (0)	; 読み書きバッファセグメント
	DW	RECBUFFMAX DUP (0)	; 読み書きバッファオフセット
	DW	0			; クラスタバッファ・セグメント
	DW	0			; クラスタバッファ・オフセット
HANDLE_2_END	LABEL	BYTE		; ハンドル２エンド

RECSTARTNUM	DW	0		; 論理レコード番号
RECCOUNT	DW	0		; 連続レコード数

RECDBUFSEG	DW	0		; レコードバッファセグメント
RECDBUFOFS	DW	0		; レコードバッファオフセット

FLAG_RWMODE	DW	0		; フラグ・1=読み込み,2=書き込み

BUFFSEG		DW	0		; バッファ・セグメント
BUFFOFS		DW	0		; バッファ・オフセット

DATA	ENDS

	END
;
;	end of "READSEC.ASM"
;
