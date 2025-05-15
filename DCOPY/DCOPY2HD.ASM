; "DCOPY2HD.ASM" PC98series make by R.H 1993/06/28
;
;
;	2HD(1024byte,8sector)disk copy.
;
;
; (C) 1993 ritsurou hashimoto.

INCLUDE	TSTSET.INC
INCLUDE	DCOPYDEF.INC
INCLUDE	TEXTVIEW.INC

READ_RETCOUNT 	EQU	10		; ＲＥＡＤ・リトライ回数
WRITE_RETCOUNT 	EQU	10		; ＷＲＩＴＥ・リトライ回数
FORMAT_RETCNT	EQU	10		; ＦＯＲＭＡＴ・リトライ回数

DCYL_DIR	EQU	0		; ＲＯＯＴ　シリンダ番号（Ｃ）
DHEAD_DIR	EQU	0		; ＲＯＯＴ　ヘッド番号（Ｈ）
DSECR_DIR	EQU	6		; ＲＯＯＴ　セクタ番号（Ｒ）

SEC_BYTE	EQU	1024		; セクタバイト数

INT_FD_BIOS	MACRO			; PC9801 disk/FD bios.
		INT	1BH		; disk bios.
		ENDM

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	DCOPY2HD			; 2HD disk copy.
PUBLIC	DRVNOSET			; 2HD disk copy dirve number set.
PUBLIC	DRVNORED			; 2HD disk copy dirve number read.
PUBLIC	P_CPY_S_DISK			; １ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー元ディスク交換
PUBLIC	P_CPY_D_DISK			; １ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー先ディスク交換
PUBLIC	DCRD_ERR_CHK			; 読込み時エラーチェック
PUBLIC	DCWR_ERR_CHK			; 書込み時エラーチェック
PUBLIC	RDSECTOR			; セクタＲＥＡＤ
PUBLIC	WTSECTOR			; セクタＷＲＩＴＥ
PUBLIC	VRFYSECTOR			; セクタＶＥＲＩＦＹ
PUBLIC	WRT_DISK_CHK			; 書込みディスクのチェック
PUBLIC	WRT_DISK_CHK_D			; 書込みディスクのチェック(dup mode)
PUBLIC	DOSRESET			; DOS system reset.

EXTRN	MEMOPN:NEAR			; real memory open.
EXTRN	MEMCLS:NEAR			; real memory close.
EXTRN	MEMSEK:NEAR			; real memory seek.

; ****************************************************
;	2HD disk copy.
;	-O- AX : 0=通常,1=中止,2=メモリ不足
; ****************************************************

DCOPY2HD	PROC	NEAR
	CALL	MEMOPN			; real memory open.
	CMP	BX,0			; free page counter.
	JE	DCOPY2HD_ERROR_MEM	;

	MOV	BX,0			; page number.
	CALL	MEMSEK			; real memory seek.
	CMP	AX,0			; 0=normal,3=error
	JNE	DCOPY2HD_QUIT		;

	MOV	TRACK_BUFFSEG,ES	; バッファ・セグメント
	MOV	TRACK_BUFFOFS,0		; バッファ・オフセット

	TX_PRINT 62,0,TC_CYAN ,"単純コピーモード"

	CALL	DOSRESET		; DOS system reset.

DCOPY2HD_INP_DRV1:
	TX_FRMCLS			; frame inside clear screen.

	TX_PRINT 8,18,TC_WHITE,"戻るときは、ESC を押してください。"
	TX_PRINT 8,20,TC_WHITE,"ディスクコピーしないで終了するときは、f.3 を押してください。"

	TX_PRINT 8,5,TC_YELLOW_RV,"コピー元のドライブ番号を数字キーで指定して下さい。"
	TX_1TO4N			; select number 1-4.
	CMP	BX,11			; 0=normal,3=F3,11=ESC
	JE	DCOPY2HD_INP_DRV1	;
	CMP	BX,3			;
	JE	DCOPY2HD_QUIT		;
	MOV	DRVNUM1,AX		; コピー元ドライブ
	TX_CLEAR 8,5,70
	TX_PRINT 8,5,TC_WHITE, "コピー元のドライブ番号"
	MOV	SI,DRVNUM1		; コピー元ドライブ
	DEC	SI
	SHL	SI,1
	TX_PRINTA 40,5,TC_WHITE,STR_DRV_NUM[SI]

DCOPY2HD_INP_DRV2:
	TX_PRINT 8,7,TC_YELLOW_RV,"コピー先のドライブ番号を数字キーで指定して下さい。"
	TX_1TO4N			; select number 1-4.
	CMP	BX,11			; 0=normal,3=F3,11=ESC
	JE	DCOPY2HD_INP_DRV1	;
	CMP	BX,3			;
	JE	DCOPY2HD_QUIT		;
	MOV	DRVNUM2,AX		; コピー先ドライブ
	TX_CLEAR 8,7,70
	TX_PRINT 8,7,TC_WHITE, "コピー先のドライブ番号"
	MOV	SI,DRVNUM2		; コピー元ドライブ
	DEC	SI
	SHL	SI,1
	TX_PRINTA 40,7,TC_WHITE,STR_DRV_NUM[SI]

	MOV	AX,DRVNUM1		; コピー元ドライブ
	MOV	BX,DRVNUM2		; コピー先ドライブ
	DEC	AX
	DEC	BX
	CALL	DRVNOSET		; 2HD disk copy dirve number set.

DCOPY2HD_INP_RET:
	CMPX	DRVNUM1,DRVNUM2		; コピー元ドライブ : コピー先ドライブ
	JE	DCOPY2HD_41		;
	TX_PRINT 8,9,TC_YELLOW_RV,"ドライブにディスクをセットしてリターンキーを押してください。"
	JMP	DCOPY2HD_42
DCOPY2HD_41:
	TX_PRINT 8,9,TC_YELLOW_RV,"コピー元ディスクをセットしてリターンキーを押してください。"
DCOPY2HD_42:

	TX_UWAIT			; user wait.
	PUSH	AX
	TX_CLEAR 8,9,70
	POP	AX
	CMP	AX,3			; 3=F3,11=ESC,12=ENTER
	JE	DCOPY2HD_QUIT		;
	CMP	AX,11			;
	JE	DCOPY2HD_INP_DRV2	;

	TX_CLEAR 8,18,70
	TX_CLEAR 8,20,70

	TX_PRINT 8,18,TC_WHITE,"ディスクコピーを中断するときは、f.3 か ESC を押してください。"

	MOV	NOW_DCYL,MAXCILINDER-1	; max cilinder.

	JMP	DCOPY2HD_INTER

DCOPY2HD_LOOP:
	CALL	P_CPY_S_DISK		; １ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー元ディスク交換
	CMP	AX,1			; 0=正常,1=中止
	JE	DCOPY2HD_BREAK		;
DCOPY2HD_INTER:

	TX_PRINTV 8,14,TC_WHITE ,"残り ",NOW_DCYL," です  "	; print value.

	MOVX	BUFFSEG,TRACK_BUFFSEG	; バッファ・セグメント
	MOVX	BUFFOFS,TRACK_BUFFOFS	; バッファ・オフセット

DCOPY2HD_RETRY_R:
	MOVX	DCYL,NOW_DCYL		; 現在のシリンダ番号
	MOV	DHEAD,0			; ヘッド番号（Ｈ）
	MOV	DSECR,1			; セクタ番号（Ｒ）
	MOV	DLEN,1024*16		; データ長（ＤＴＬ）（バイト単位）
	CALL	RDSECTOR		; セクタＲＥＡＤ

	CALL	DCRD_ERR_CHK		; 読込み時エラーチェック
	CMP	AX,1			; 1=再度読込み実行
	JE	DCOPY2HD_RETRY_R	;
	CMP	AX,2			; 2=致命的なエラー
	JE	DCOPY2HD_ERROR_READ	;
	CMP	AX,3			; 3=中止
	JE	DCOPY2HD_BREAK		;

	CALL	P_CPY_D_DISK		; １ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー先ディスク交換
	CMP	AX,1			; 0=正常,1=中止
	JE	DCOPY2HD_BREAK		;

	CMP	NOW_DCYL,MAXCILINDER-1	; max cilinder.
	JB	DCOPY2HD_WRT

	CALL	WRT_DISK_CHK		; 書込みディスクのチェック
	CMP	AX,1			; 0=normal,1=error,2=user break.
	JE	DCOPY2HD_ERROR_WRITE	;
	CMP	AX,2			;
	JE	DCOPY2HD_BREAK		;

DCOPY2HD_WRT:
	MOVX	BUFFSEG,TRACK_BUFFSEG	; バッファ・セグメント
	MOVX	BUFFOFS,TRACK_BUFFOFS	; バッファ・オフセット

DCOPY2HD_RETRY1:
	MOVX	DCYL,NOW_DCYL		; 現在のシリンダ番号
	MOV	DHEAD,0			; ヘッド番号（Ｈ）
	MOV	DSECR,1			; セクタ番号（Ｒ）
	MOV	DLENWRT,1024*8		; データ長（ＤＴＬ）（バイト単位)WR
	CALL	WTSECTOR		; セクタＷＲＩＴＥ

	CALL	DCWR_ERR_CHK		; 書込み時エラーチェック
	CMP	AX,1			; 1=再度書込み実行
	JE	DCOPY2HD_RETRY1		;
	CMP	AX,2			; 2=致命的なエラー
	JE	DCOPY2HD_ERROR_WRITE	;
	CMP	AX,3			; 3=中止
	JE	DCOPY2HD_BREAK		;

	ADD	BUFFOFS,1024*8		; バッファ・オフセット

DCOPY2HD_RETRY2:
	MOVX	DCYL,NOW_DCYL		; 現在のシリンダ番号
	MOV	DHEAD,1			; ヘッド番号（Ｈ）
	MOV	DSECR,1			; セクタ番号（Ｒ）
	MOV	DLENWRT,1024*8		; データ長（ＤＴＬ）（バイト単位)WR
	CALL	WTSECTOR		; セクタＷＲＩＴＥ

	CALL	DCWR_ERR_CHK		; 書込み時エラーチェック
	CMP	AX,1			; 1=再度書込み実行
	JE	DCOPY2HD_RETRY2		;
	CMP	AX,2			; 2=致命的なエラー
	JE	DCOPY2HD_ERROR_WRITE	;
	CMP	AX,3			; 3=中止
	JE	DCOPY2HD_BREAK		;


	MOVX	BUFFSEG,TRACK_BUFFSEG	; バッファ・セグメント
	MOVX	BUFFOFS,TRACK_BUFFOFS	; バッファ・オフセット

DCOPY2HD_RETRY3:
	MOVX	DCYL,NOW_DCYL		; 現在のシリンダ番号
	MOV	DHEAD,0			; ヘッド番号（Ｈ）
	MOV	DSECR,1			; セクタ番号（Ｒ）
	MOV	DLENWRT,1024*16		; データ長（ＤＴＬ）（バイト単位)WR
	CALL	VRFYSECTOR		; セクタＶＥＲＩＦＹ
	MOV	FLAG_VERIFY,AX		; ベリファイ結果 0=同じ,1=異なる

	CALL	DCWR_ERR_CHK		; 書込み時エラーチェック
	CMP	AX,1			; 1=再度書込み実行
	JE	DCOPY2HD_RETRY3		;
	CMP	AX,2			; 2=致命的なエラー
	JE	DCOPY2HD_ERROR_WRITE	;
	CMP	AX,3			; 3=中止
	JE	DCOPY2HD_BREAK		;

	CMP	FLAG_VERIFY,0		; ベリファイ結果 0=同じ,1=異なる
	JNE	DCOPY2HD_ERROR_VERIFY	;

	DEC	NOW_DCYL		; 現在のシリンダ番号
	CMP	NOW_DCYL,0		;
	JL	DCOPY2HD_COMPLITE

	JMP	DCOPY2HD_LOOP

DCOPY2HD_COMPLITE:
	TX_PRINT 8,13,TC_WHITE_RV,"ディスクコピー出来ました。"
	JMP	DCOPY2HD_NEXTDISK
DCOPY2HD_BREAK:
	TX_PRINT 8,13,TC_WHITE_RV,"ディスクコピーを中止します。"
	JMP	DCOPY2HD_NEXTDISK

DCOPY2HD_ERROR_READ:
	TX_PRINT 8,13,TC_WHITE_RV,"コピー元ディスクが読めませんでした。"
	JMP	DCOPY2HD_NEXTDISK

DCOPY2HD_ERROR_WRITE:
	TX_PRINT 8,13,TC_WHITE_RV,"このディスクには書き込めませんでした。"
	JMP	DCOPY2HD_NEXTDISK

DCOPY2HD_ERROR_VERIFY:
	TX_PRINT 8,13,TC_WHITE_RV,"このディスクにはディスクコピー出来ません。"
	JMP	DCOPY2HD_NEXTDISK
DCOPY2HD_NEXTDISK:
	TX_CLEAR 8,14,70
	TX_CLEAR 8,18,70
 TX_PRINT 8,18,TC_WHITE,"次のディスクコピーを行うときはリターンキーを押してください。"
 TX_PRINT 8,20,TC_WHITE,"ディスクコピーしないで終了するときは、f.3 か ESC を押してください。"
	TX_UWAIT			; user wait.
	PUSH	AX
	TX_CLEAR 8,13,70
	POP	AX
	CMP	AX,3			; 3=F3,11=ESC,12=ENTER
	JE	DCOPY2HD_QUIT		;
	CMP	AX,11			;
	JE	DCOPY2HD_QUIT		;
	TX_CLEAR 8,18,70
	TX_CLEAR 8,20,70
	TX_PRINT 8,18,TC_WHITE,"戻るときは、ESC を押してください。"
	TX_PRINT 8,20,TC_WHITE,"ディスクコピーしないで終了するときは、f.3 を押してください。"
	JMP	DCOPY2HD_INP_RET
DCOPY2HD_EXIT:
	CALL	MEMCLS			; real memory close.
	MOV	AX,0			; 0=通常
	RET
DCOPY2HD_QUIT:
	CALL	MEMCLS			; real memory close.
	MOV	AX,1			; 1=中止
	RET
DCOPY2HD_ERROR_MEM:
	CALL	MEMCLS			; real memory close.
	MOV	AX,2			; 2=メモリ不足
	RET
DCOPY2HD	ENDP


; ****************************************************
;	１ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー元ディスク交換
;	-O- AX : 0=正常,1=中止
; ****************************************************

P_CPY_S_DISK	PROC	NEAR
	CMPX	DRVNUM1,DRVNUM2		; コピー元ドライブ : コピー先ドライブ
	JNE	P_CPY_S_DISK_EXIT

	TX_PRINT 8,9,TC_YELLOW_RV,"コピー元ディスクをセットしてリターンキーを押してください。"
	TX_UWAIT				; user wait.
	TX_CLEAR 8,9,70
	CMP	AX,3				; 3=F3,11=ESC,12=ENTER
	JE	P_CPY_S_DISK_BREAK		;
	CMP	AX,11				;
	JE	P_CPY_S_DISK_BREAK		;

P_CPY_S_DISK_EXIT:
	MOV	AX,0		; 0=正常
	RET
P_CPY_S_DISK_BREAK:
	MOV	AX,1		; 1=中止
	RET
P_CPY_S_DISK	ENDP


; ****************************************************
;	１ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー先ディスク交換
;	-O- AX : 0=正常,1=中止
; ****************************************************

P_CPY_D_DISK	PROC	NEAR
	CMPX	DRVNUM1,DRVNUM2		; コピー元ドライブ : コピー先ドライブ
	JNE	P_CPY_D_DISK_EXIT

	TX_PRINT 8,9,TC_YELLOW_RV,"コピー先ディスクをセットしてリターンキーを押してください。"
	TX_UWAIT				; user wait.
	TX_CLEAR 8,9,70
	CMP	AX,3				; 3=F3,11=ESC,12=ENTER
	JE	P_CPY_D_DISK_BREAK		;
	CMP	AX,11				;
	JE	P_CPY_D_DISK_BREAK		;

P_CPY_D_DISK_EXIT:
	MOV	AX,0		; 0=正常
	RET
P_CPY_D_DISK_BREAK:
	MOV	AX,1		; 1=中止
	RET
P_CPY_D_DISK	ENDP


; ****************************************************
;	読込み時エラーチェック
;	-O- AX : 0=正常,1=再度読込み実行,2=致命的なエラー,3=中止
; ****************************************************

DCRD_ERR_CHK	PROC	NEAR
	CMP	DERROR,0		; 0=正常,1=エラー
	JE	DCRD_ERR_CHK_NORMAL	;

	CMP	DSTAT,60H		; ＮＲ／デバイスがノットレディ
	JE	DCRD_ERR_CHK_ERROR_NOTRDY

	JMP	DCRD_ERR_CHK_ERROR

DCRD_ERR_CHK_ERROR_NOTRDY:
	TX_PRINT 8,9,TC_WHITE_RV,	"コピー元のディスクがセットされていません。"
	TX_PRINT 8,11,TC_YELLOW_RV,"コピー元ディスクをセットしてリターンキーを押してください。"
	TX_UWAIT			; user wait.
	TX_CLEAR 8,9,70
	TX_CLEAR 8,11,70
	CMP	AX,3			; 3=F3,11=ESC,12=ENTER
	JE	DCRD_ERR_CHK_BREAK	;
	CMP	AX,11			;
	JE	DCRD_ERR_CHK_BREAK	;
	JMP	DCRD_ERR_CHK_RETRY	;

DCRD_ERR_CHK_NORMAL:
	CALL	TXVW_INKEY		; user inkey.
	CMP	BL,3			; 3=F3
	JE	DCRD_ERR_CHK_BREAK	;
	CMP	BL,11			; 11=ESC
	JE	DCRD_ERR_CHK_BREAK	;

	MOV	AX,0			; 0=正常
	RET
DCRD_ERR_CHK_RETRY:
	MOV	AX,1			; 1=再度書込み実行
	RET
DCRD_ERR_CHK_ERROR:
	MOV	AX,2			; 2=致命的なエラー
	RET
DCRD_ERR_CHK_BREAK:
	MOV	AX,3			; 3=中止
	RET
DCRD_ERR_CHK	ENDP


; ****************************************************
;	書込み時エラーチェック
;	-O- AX : 0=正常,1=再度書込み実行,2=致命的なエラー,3=中止
; ****************************************************

DCWR_ERR_CHK	PROC	NEAR
	CMP	DERROR,0		; 0=正常,1=エラー
	JE	DCWR_ERR_CHK_NORMAL	;

	CMP	DSTAT,60H		; ＮＲ／デバイスがノットレディ
	JE	DCWR_ERR_CHK_ERROR_NOTRDY
	CMP	DSTAT,70H		; ＮＷ／ライトプロテクト
	JE	DCWR_ERR_CHK_ERROR_W_PROTECT

	JMP	DCWR_ERR_CHK_ERROR

DCWR_ERR_CHK_ERROR_NOTRDY:
	TX_PRINT 8,9,TC_WHITE_RV,"コピー先ディスクがセットされていません。"
	TX_PRINT 8,11,TC_YELLOW_RV,"コピー先ディスクをセットしてリターンキーを押してください。"
	TX_UWAIT			; user wait.
	TX_CLEAR 8,9,70
	TX_CLEAR 8,11,70
	CMP	AX,3			; 3=F3,11=ESC,12=ENTER
	JE	DCWR_ERR_CHK_BREAK	;
	CMP	AX,11			;
	JE	DCWR_ERR_CHK_BREAK	;
	JMP	DCWR_ERR_CHK_RETRY	;

DCWR_ERR_CHK_ERROR_W_PROTECT:
	TX_PRINT 8,9,TC_WHITE_RV,"コピー先ディスクが書込み禁止になっています。"
	TX_PRINT 8,11,TC_YELLOW_RV,"ライトプロテクトを外してからコピー先ディスクをセットして"
	TX_PRINT 8,12,TC_YELLOW_RV,"リターンキーを押してください。"
	TX_UWAIT			; user wait.
	TX_CLEAR 8,9,70
	TX_CLEAR 8,11,70
	TX_CLEAR 8,12,70
	CMP	AX,3			; 3=F3,11=ESC,12=ENTER
	JE	DCWR_ERR_CHK_BREAK	;
	CMP	AX,11			;
	JE	DCWR_ERR_CHK_BREAK	;
	JMP	DCWR_ERR_CHK_RETRY	;

DCWR_ERR_CHK_NORMAL:
	CALL	TXVW_INKEY		; user inkey.
	CMP	BL,3			; 3=F3
	JE	DCWR_ERR_CHK_BREAK	;
	CMP	BL,11			; 11=ESC
	JE	DCWR_ERR_CHK_BREAK	;

	MOV	AX,0			; 0=正常
	RET
DCWR_ERR_CHK_RETRY:
	MOV	AX,1			; 1=再度書込み実行
	RET
DCWR_ERR_CHK_ERROR:
	MOV	AX,2			; 2=致命的なエラー
	RET
DCWR_ERR_CHK_BREAK:
	MOV	AX,3			; 3=中止
	RET
DCWR_ERR_CHK	ENDP

; ****************************************************
;	書込みディスクのチェック
;	-O- AX : 0=normal,1=error,2=user break.
; ****************************************************

WRT_DISK_CHK	PROC	NEAR
	CALL	WRDISK_CHECK		; 書込みディスクのチェック
	CMP	AX,0			; 0=あたらしい
	JE	WRT_DISK_CHK_EXIT	;
	CMP	AX,1			; 1=データ有り
	JE	WRT_DISK_CHK_ANTHER_DISK
	CMP	AX,2			; 2=中止
	JE	WRT_DISK_CHK_BREAK	;
	CMP	AX,3			; 3=フォーマットされていない
	JE	WRT_DISK_CHK_FORMAT
	JMP	WRT_DISK_CHK_EXIT

WRT_DISK_CHK_ANTHER_DISK:

 TX_PRINT 8,10,TC_WHITE_RV,"コピー先のディスクは別のデータが入っています。"
 TX_PRINT 8,12,TC_WHITE,"このままディスクコピーを行うならばリターンキーを押してください。"
 TX_PRINT 8,14,TC_WHITE,"中止するならば f.3 か ESC を押してください。"
	TX_UWAIT			; user wait.
	PUSH	AX
	TX_CLEAR 8,10,70
	TX_CLEAR 8,12,70
	TX_CLEAR 8,14,70
	POP	AX
	CMP	AX,3			; 3=F3,11=ESC,12=ENTER
	JE	WRT_DISK_CHK_BREAK	;
	CMP	AX,11			;
	JE	WRT_DISK_CHK_BREAK	;
	JMP	WRT_DISK_CHK_EXIT	;

WRT_DISK_CHK_FORMAT:
	CALL	PYSICAL_FORMAT		; 物理フォーマット
	TX_CLEAR 8,14,70

	CALL	DCWR_ERR_CHK		; 書込み時エラーチェック
	CMP	AX,1			; 1=再度書込み実行
	JE	WRT_DISK_CHK_FORMAT	;
	CMP	AX,2			; 2=致命的なエラー
	JE	WRT_DISK_CHK_ERROR	;
	CMP	AX,3			; 3=中止
	JE	WRT_DISK_CHK_BREAK	;

WRT_DISK_CHK_EXIT:
	MOV	AX,0			; 0=normal.
	RET
WRT_DISK_CHK_ERROR:
	MOV	AX,1			; 1=error.
	RET
WRT_DISK_CHK_BREAK:
	MOV	AX,2			; 2=user break.
	RET
WRT_DISK_CHK	ENDP


; ****************************************************
;	書込みディスクのチェック(dup mode)
; ****************************************************

WRT_DISK_CHK_D	PROC	NEAR
	CALL	WRDISK_CHECK		; 書込みディスクのチェック
	CMP	AX,0			; 0=あたらしい
	JE	WRT_DISK_CHK_D_EXIT
	CMP	AX,1			; 1=データ有り
	JE	WRT_DISK_CHK_D_EXIT
	CMP	AX,2			; 2=中止
	JE	WRT_DISK_CHK_D_BREAK
	CMP	AX,3			; 3=フォーマットされていない
	JE	WRT_DISK_CHK_D_FORMAT
	JMP	WRT_DISK_CHK_D_EXIT

WRT_DISK_CHK_D_FORMAT:
	CALL	PYSICAL_FORMAT		; 物理フォーマット
	TX_CLEAR 8,14,70

	CALL	DCWR_ERR_CHK		; 書込み時エラーチェック
	CMP	AX,1			; 1=再度書込み実行
	JE	WRT_DISK_CHK_D_FORMAT	;
	CMP	AX,2			; 2=致命的なエラー
	JE	WRT_DISK_CHK_D_ERROR	;
	CMP	AX,3			; 3=中止
	JE	WRT_DISK_CHK_D_BREAK	;

WRT_DISK_CHK_D_EXIT:
	MOV	AX,0			; 0=normal.
	RET
WRT_DISK_CHK_D_ERROR:
	MOV	AX,1			; 1=error.
	RET
WRT_DISK_CHK_D_BREAK:
	MOV	AX,2			; 2=user break.
	RET
WRT_DISK_CHK_D	ENDP


; ****************************************************
;	2HD disk copy dirve number set.
;	-I- AX : read disk drive.
;	    BX : write disk drive.
; ****************************************************

DRVNOSET	PROC	NEAR
	AND	AX,11B
	AND	BX,11B
	AND	DUNIT,0FFF0H		; デバイス識別・ユニット番号（DA/UA)
	AND	DUNITWRT,0FFF0H		; デバイス識別・ユニット番号（DA/UA)WR
	OR	DUNIT,AX		; デバイス識別・ユニット番号（DA/UA)
	OR	DUNITWRT,BX		; デバイス識別・ユニット番号（DA/UA)WR
	RET
DRVNOSET	ENDP


; ****************************************************
;	2HD disk copy dirve number read.
;	-O- AX : read disk drive.
;	    BX : write disk drive.
; ****************************************************

DRVNORED	PROC	NEAR
	MOV	AX,DUNIT		; デバイス識別・ユニット番号（DA/UA)
	MOV	BX,DUNITWRT		; デバイス識別・ユニット番号（DA/UA)WR
	AND	AX,11B
	AND	BX,11B
	RET
DRVNORED	ENDP


; *********************************************************
;	書込みディスクのチェック
;	-O- AX : 0=あたらしい,1=データ有り,2=中止
;		3=フォーマットされていない
; *********************************************************

WRDISK_CHECK	PROC	NEAR

WRDISK_CHECK_RETRY:
	MOVX	DCYL,DCYL_DIR		; ＲＯＯＴ　シリンダ番号（Ｃ）
	MOVX	DHEAD,DHEAD_DIR		; ＲＯＯＴ　ヘッド番号（Ｈ）
	MOVX	DSECR,DSECR_DIR		; ＲＯＯＴ　セクタ番号（Ｒ）
	MOV	DLEN,SEC_BYTE		; セクタバイト数
	MOV	BUFFSEG,DS			; バッファ・セグメント
	MOV	BUFFOFS,OFFSET DIRCHKBUF	; dir check buffer.

	PUSH	DUNIT			; デバイス識別・ユニット番号（DA/UA)
	MOVX	DUNIT,DUNITWRT		; デバイス識別・ユニット番号（DA/UA)WR
	CALL	RDSECTOR		; セクタＲＥＡＤ
	POP	DUNIT			;

	CALL	DCWR_ERR_CHK		; 書込み時エラーチェック
	CMP	AX,1			; 1=再度書込み実行
	JE	WRDISK_CHECK_RETRY	;
	CMP	AX,2			; 2=致命的なエラー
	JE	WRDISK_CHECK_READ_ERR	;
	CMP	AX,3			; 3=中止
	JE	WRDISK_CHECK_BREAK	;

	CMP	DIRCHKBUF,0		;
	JNE	WRDISK_CHECK_ARI	;
	JMP	WRDISK_CHECK_NEW	;

WRDISK_CHECK_READ_ERR:
	JMP	WRDISK_CHECK_READ_UNFORMAT

WRDISK_CHECK_NEW:
	MOV	AX,0		; 0=あたらしい
	RET
WRDISK_CHECK_ARI:
	MOV	AX,1		; 1=データ有り
	RET
WRDISK_CHECK_BREAK:
	MOV	AX,2		; 2=中止
	RET
WRDISK_CHECK_READ_UNFORMAT:
	MOV	AX,3		; 3=フォーマットされていない
	RET
WRDISK_CHECK	ENDP


; ****************************************************
;	セクタＲＥＡＤ
;	-I- DCYL    : シリンダ番号（Ｃ）０ー７６
;	    DHEAD   : ヘッド番号（Ｈ）０ー１
;	    DSECR   : セクタ番号（Ｒ）１ー８（２６）
;	    DLEN    : データ長（ＤＴＬ）（バイト単位）
;	    BUFFSEG : バッファ・セグメント
;	    BUFFOFS : バッファ・オフセット
;	-O- DERROR : 0=正常,1=エラー
; ****************************************************

RDSECTOR	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	MOV	READ_RETRY,READ_RETCOUNT ; ＲＥＡＤ・リトライ回数
RDSECTOR_RETRY:
	MOVX	ES,SEG_TRACK_BUF	; segment track buffer.
	MOV	BP,0			;
	MOV	AL,BYTE PTR DUNIT	; デバイス識別・ユニット番号(DA/UA)
	MOV	BX,DLEN 		; データ長（ＤＴＬ）（バイト単位）
	MOV	CL,BYTE PTR DCYL 	; シリンダ番号（Ｃ）
	MOV	DH,BYTE PTR DHEAD	; ヘッド番号（Ｈ）
	MOV	DL,BYTE PTR DSECR	; セクタ番号（Ｒ）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）
	MOV	AH,DREAD		; ＲＥＡＤ　ＤＡＴＡ

	INT_FD_BIOS			; PC9801 disk/FD bios.
	JC	RDSECTOR_ERROR		;
RDSECTOR9:
	MOV	DX,SEG_TRACK_BUF	; segment track buffer.
	MOV	SI,0			;
	MOV	ES,BUFFSEG		; バッファ・セグメント
	MOV	DI,BUFFOFS		; バッファ・オフセット
	MOV	CX,DLEN			; データ長（ＤＴＬ）（バイト単位）
	PUSH	DS
	MOV	DS,DX
	REP	MOVSB
	POP	DS

	MOV	DERROR,0		; 0=正常
	RET				;

RDSECTOR_ERROR:				;
	CMP	AH,20H			; ＤＭＡ　Ｂｏｕｎｄａｒｙ
	JE	RDSECTOR_ERROR2		;

	CMP	AH,60H			; Not Ready. ユニットがノットレディ状態
	JE	RDSECTOR_ER_END		;

	DEC	READ_RETRY		; ＲＥＡＤ・リトライカウンタ
	JZ	RDSECTOR_ER_END		;

	MOV	AH,DRECAL		; ＲＥＣＡＬＩＢＲＡＴＥ
	INT_FD_BIOS			; PC9801 disk/FD bios.
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	JMP	RDSECTOR_RETRY		;

RDSECTOR_ERROR2:
	PUSH	AX
	TX_PRINT 8,24,TC_WHITE,"ＤＭＡバウンダリエラーです。"
	POP	AX
RDSECTOR_ER_END:
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	MOV	DERROR,1		; 1=エラー
	RET				;
RDSECTOR	ENDP


; ****************************************************
;	セクタＷＲＩＴＥ
;	-I- DCYL    : シリンダ番号（Ｃ）０ー７６
;	    DHEAD   : ヘッド番号（Ｈ）０ー１
;	    DSECR   : セクタ番号（Ｒ）１ー８（２６）
;	    DLENWRT : データ長（ＤＴＬ）（バイト単位）
;	    BUFFSEG : バッファ・セグメント
;	    BUFFOFS : バッファ・オフセット
;	-O- DERROR : 0=正常,1=エラー
; ****************************************************

WTSECTOR	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	MOV	DX,BUFFSEG		; バッファ・セグメント
	MOV	SI,BUFFOFS		; バッファ・オフセット
	MOVX	ES,SEG_TRACK_BUF	; segment track buffer.
	MOV	DI,0			;
	MOV	CX,DLENWRT 		; データ長（ＤＴＬ）（バイト単位）
	PUSH	DS
	MOV	DS,DX
	REP	MOVSB
	POP	DS

	MOV	WRITE_RETRY,WRITE_RETCOUNT ; ＷＲＩＴＥ・リトライ回数
WTSECTOR_RETRY:
	MOVX	ES,SEG_TRACK_BUF	; segment track buffer.
	MOV	BP,0			;
	MOV	AL,BYTE PTR DUNITWRT	; デバイス識別・ユニット番号(DA/UA)
	MOV	BX,DLENWRT 		; データ長（ＤＴＬ）（バイト単位）
	MOV	CL,BYTE PTR DCYL 	; シリンダ番号（Ｃ）
	MOV	DH,BYTE PTR DHEAD	; ヘッド番号（Ｈ）
	MOV	DL,BYTE PTR DSECR	; セクタ番号（Ｒ）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）
	MOV	AH,DWRITE		; ＷＲＩＴＥ　ＤＡＴＡ

	INT_FD_BIOS			; PC9801 disk/FD bios.
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

	MOV	AH,DRECAL		; ＲＥＣＡＬＩＢＲＡＴＥ
	INT_FD_BIOS			; PC9801 disk/FD bios.
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	JMP	WTSECTOR_RETRY		;

WTSECTOR_ERROR2:
	PUSH	AX
	TX_PRINT 8,24,TC_WHITE,"ＤＭＡバウンダリエラーです。"
	POP	AX
WTSECTOR_ER_END:			;
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	MOV	DERROR,1		; 1=エラー
	RET				;
WTSECTOR	ENDP


; ****************************************************
;	セクタＶＥＲＩＦＹ
;	-I- DCYL    : シリンダ番号（Ｃ）０ー７６
;	    DHEAD   : ヘッド番号（Ｈ）０ー１
;	    DSECR   : セクタ番号（Ｒ）１ー８（２６）
;	    DLENWRT : データ長（ＤＴＬ）（バイト単位）
;	    BUFFSEG : バッファ・セグメント
;	    BUFFOFS : バッファ・オフセット
;	-O- DERROR : 0=正常,1=エラー
;	    AX     : ベリファイ結果 0=同じ,1=異なる
; ****************************************************

VRFYSECTOR	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	MOV	READ_RETRY,READ_RETCOUNT ; ＲＥＡＤ・リトライ回数
VRFYSECTOR_RETRY:
	MOVX	ES,SEG_TRACK_BUF	; segment track buffer.
	MOV	BP,0			;
	MOV	AL,BYTE PTR DUNITWRT	; デバイス識別・ユニット番号(DA/UA)
	MOV	BX,DLENWRT 		; データ長（ＤＴＬ）（バイト単位）
	MOV	CL,BYTE PTR DCYL 	; シリンダ番号（Ｃ）
	MOV	DH,BYTE PTR DHEAD	; ヘッド番号（Ｈ）
	MOV	DL,BYTE PTR DSECR	; セクタ番号（Ｒ）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）
	MOV	AH,DREAD		; ＲＥＡＤ　ＤＡＴＡ

	INT_FD_BIOS			; PC9801 disk/FD bios.
	JC	VRFYSECTOR_ERROR	;

VRFYSECTOR9:
	MOV	DX,SEG_TRACK_BUF	; segment track buffer.
	MOV	SI,0			;
	MOV	ES,BUFFSEG		; バッファ・セグメント
	MOV	DI,BUFFOFS		; バッファ・オフセット
	MOV	CX,DLENWRT 		; データ長（ＤＴＬ）（バイト単位）
	CALL	MEM_COMP		; memory compear.
	MOV	DERROR,0		; 0=正常
	RET				;

VRFYSECTOR_ERROR:			;
	CMP	AH,20H			; ＤＭＡ　Ｂｏｕｎｄａｒｙ
	JE	VRFYSECTOR_ERROR2	;

	CMP	AH,60H			; Not Ready. ユニットがノットレディ状態
	JE	VRFYSECTOR_ER_END	;

	DEC	READ_RETRY		; ＲＥＡＤ・リトライカウンタ
	JZ	VRFYSECTOR_ER_END	;

	MOV	AH,DRECAL		; ＲＥＣＡＬＩＢＲＡＴＥ
	INT_FD_BIOS			; PC9801 disk/FD bios.
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	JMP	VRFYSECTOR_RETRY	;

VRFYSECTOR_ERROR2:
	PUSH	AX
	TX_PRINT 8,24,TC_WHITE,"ＤＭＡバウンダリエラーです。"
	POP	AX
VRFYSECTOR_ER_END:
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	MOV	DERROR,1		; 1=エラー
	MOV	AX,1			; ベリファイ結果 1=異なる
	RET				;
VRFYSECTOR	ENDP


; ****************************************************
;	物理フォーマット
;	-O-    AX : 0=正常, 2=ディスクエラー
;	            3=デバイスがノットレディ, 4=ライトプロテクト
; ****************************************************

PYSICAL_FORMAT	PROC	NEAR
	MOV	TRACK_NUMBER,77*2	; トラック番号

PYSICAL_FORMAT_LOOP:
	CMP	TRACK_NUMBER,0		; トラック番号
	JLE	PYSICAL_FORMAT_EXIT	;

	TX_PRINTV 8,14,TC_WHITE ,"フォーマット中　残り ",TRACK_NUMBER," です　　"

	DEC	TRACK_NUMBER		; トラック番号

	CALL	TRACK_TO_CYLINDER	; トラック番号からシリンダ番号とヘッド
	CALL	FORMATTR		; トラックのフォーマット
	CMP	DERROR,0		; 0=正常,1=エラー
	JNE	PYSICAL_FORMAT_ERROR	;

	JMP	PYSICAL_FORMAT_LOOP	;

PYSICAL_FORMAT_EXIT:
	MOV	AX,0			; 0=正常
	RET				;
PYSICAL_FORMAT_ERROR:
	CMP	DSTAT,60H		; ＮＲ／デバイスがノットレディ
	JE	PYSICAL_FORMAT_NOTRDY	;
	CMP	DSTAT,70H		; ＮＷ／ライトプロテクト
	JE	PYSICAL_FORMAT_W_PROTECT
PYSICAL_FORMAT_DISK_ER:
	MOV	AX,2			; 2=ディスクエラー
	RET				;
PYSICAL_FORMAT_NOTRDY:
	MOV	AX,3			; 3=デバイスがノットレディ
	RET				;
PYSICAL_FORMAT_W_PROTECT:
	MOV	AX,4			; 4=ライトプロテクト
	RET				;
PYSICAL_FORMAT	ENDP


; ****************************************************
;	トラック番号からシリンダ番号とヘッド
;	-I- TRACK_NUMBER : トラック番号
;	-O- DCYL         : シリンダ番号（Ｃ）０ー７６
;	    DHEAD        : ヘッド番号（Ｈ）０ー１
; ****************************************************

TRACK_TO_CYLINDER	PROC	NEAR
	MOV	DHEAD,0				; ヘッド番号（Ｈ）０ー１
	MOV	AX,TRACK_NUMBER			; トラック番号
	SHR	AX,1
	RCL	DHEAD,1				; ヘッド番号（Ｈ）０ー１
	MOV	DCYL,AX				; シリンダ番号（Ｃ）０ー７６
	RET
TRACK_TO_CYLINDER	ENDP


; ****************************************************
;	トラックのフォーマット
;	-I-   DCYL   : シリンダ番号（Ｃ）０ー７６
;	      DHEAD  : ヘッド番号（Ｈ）０ー１
;	-O-   DERROR : 0=正常,1=エラー
;	      DSTAT  : ステータス情報
; ****************************************************

FORMATTR	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	CALL	ID_BUFF_SET		; ＩＤデータバッファセット

	MOV	DLENFMT,32 		; データ長（ＤＴＬ）（バイト単位）

	MOV	SI,OFFSET SEC_ID_TBL	; セクタＩＤバッファ
	MOVX	ES,SEG_TRACK_BUF	; segment track buffer.
	MOV	DI,0			;
	MOV	CX,DLENFMT 		; データ長（ＤＴＬ）（バイト単位）
	REP	MOVSB

	MOVX	FORMAT_RETRY,FORMAT_RETCNT ; ＦＯＲＭＡＴ・リトライ回数
FORMATTR_RETRY:
	MOVX	ES,SEG_TRACK_BUF	; segment track buffer.
	MOV	BP,0			;
	MOV	AL,BYTE PTR DUNITWRT	; デバイス識別・ユニット番号（DA/UA)WR
	MOV	BX,DLENFMT 		; データ長（ＤＴＬ）(バイト単位)FORMAT
	MOV	CL,BYTE PTR DCYL 	; シリンダ番号（Ｃ）０ー７６
	MOV	DH,BYTE PTR DHEAD	; ヘッド番号（Ｈ）０ー１
	MOV	DL,BYTE PTR DDATPT	; データ部への書き込みﾃﾞｰﾀﾊﾟﾀｰﾝ（Ｄ）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）
	MOV	AH,BYTE PTR DFORMAT	; ＦＯＲＭＡＴ　ＴＲＡＣＫ

	INT_FD_BIOS			; PC9801 disk/FD bios.
	JB	FORMATTR_ERROR		;
FORMATTR9:
	MOV	DERROR,0		; 0=正常
	RET				;

FORMATTR_ERROR:				;
	CMP	AH,20H			; ＤＭＡ　Ｂｏｕｎｄａｒｙ
	JE	FORMATTR_ERROR2		;

	CMP	AH,60H			; Not Ready. ユニットがノットレディ状態
	JE	FORMATTR_ER_END		;

	DEC	FORMAT_RETRY		; ＦＯＲＭＡＴ・リトライカウンタ
	JZ	FORMATTR_ER_END		;

	MOV	AH,BYTE PTR DRECAL	; ＲＥＣＡＬＩＢＲＡＴＥ
	INT_FD_BIOS			; PC9801 disk/FD bios.
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	JMP	FORMATTR_RETRY		;

FORMATTR_ERROR2:
	PUSH	AX
	TX_PRINT 8,24,TC_WHITE,"ＤＭＡバウンダリエラーです。"
	POP	AX
FORMATTR_ER_END:
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	MOV	DERROR,1		; 1=エラー
	RET
FORMATTR	ENDP


; ****************************************************
;	ＩＤデータバッファセット
;	-I- DCYL   : シリンダ番号（Ｃ）０ー７６
;	    DHEAD  : ヘッド番号（Ｈ）０ー１
; ****************************************************

ID_BUFF_SET	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX

	MOV	AL,BYTE PTR DCYL		; シリンダ番号（Ｃ）０ー７６
	MOV	AH,BYTE PTR DHEAD		; ヘッド番号（Ｈ）０ー１

	MOV	BX,OFFSET SEC_ID_TBL		; セクタＩＤバッファ
	MOV	CX,TRK_SEC_CNT			; トラック当りのセクタ数
ID_BUFF_SET_LOOP:
	MOV	DS:[BX],AL			; シリンダ番号
	MOV	DS:[BX][1],AH			; ヘッド番号
	ADD	BX,4				; 4 byte pointer.
	LOOP	ID_BUFF_SET_LOOP		;

	POP	CX
	POP	BX
	POP	AX
	RET
ID_BUFF_SET	ENDP



; *********************************************************
;	memory compear.
;	-I- DX:SI : data1.
;	    ES:DI : data2.
;	    CX    : length.
;	-O- AX    : 0=same,1=error.
; *********************************************************

MEM_COMP	PROC	NEAR
	PUSH	DS

	MOV	DS,DX
	REPE	CMPSB
	JNE	MEM_COMP_ERROR

	MOV	AX,0		; 0=same.
	POP	DS
	RET
MEM_COMP_ERROR:
	MOV	AX,1		; 1=error.
	POP	DS
	RET
MEM_COMP	ENDP


; *********************************************************
;	DOS system reset.
; *********************************************************

DOSRESET	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX
	MOV	AH,0DH		; disk reset.
	INT	21H		; dos function.
	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
DOSRESET	ENDP

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

PUBLIC	DLEN				; データ長（ＤＴＬ）（バイト単位)
PUBLIC	DLENWRT				; データ長（ＤＴＬ）（バイト単位)WR
PUBLIC	DCYL				; シリンダ番号（Ｃ）
PUBLIC	DHEAD				; ヘッド番号（Ｈ）
PUBLIC	DSECR				; セクタ番号（Ｒ）
PUBLIC	DSECN				; セクタ長（Ｎ）
PUBLIC	DSTAT				; ステータス情報
PUBLIC	DERROR				; 0=正常,1=エラー
PUBLIC	BUFFSEG				; バッファ・セグメント
PUBLIC	BUFFOFS				; バッファ・オフセット

PUBLIC	DRVNUM1				; コピー元ドライブ
PUBLIC	DRVNUM2				; コピー先ドライブ

;		ＢＩＯＳコマンド識別コード

DREAD		DB	11110110B,0	; ＲＥＡＤ　ＤＡＴＡ
DWRITE		DB	01110101B,0	; ＷＲＩＴＥ　ＤＡＴＡ
DRECAL		DB	00100111B,0	; ＲＥＣＡＬＩＢＲＡＴＥ
DFORMAT		DW	01111101B	; ＦＯＲＭＡＴ　ＴＲＡＣＫ

DUNIT		DW	10010000B	; デバイス識別・ユニット番号（DA/UA)
DUNITWRT	DW	10010001B	; デバイス識別・ユニット番号（DA/UA)WR

DLEN		DW	0		; データ長（ＤＴＬ）（バイト単位)
DLENWRT		DW	0		; データ長（ＤＴＬ）（バイト単位)WR
DLENFMT 	DW	0		; データ長（ＤＴＬ）(バイト単位)FORMAT
DCYL		DW	0		; シリンダ番号（Ｃ）
DHEAD		DW	0		; ヘッド番号（Ｈ）
DSECR		DW	1		; セクタ番号（Ｒ）
DSECN		DW	03		; セクタ長（Ｎ）
DSTAT		DW	0		; ステータス情報
DERROR		DW	0		; 0=正常,1=エラー
DDATPT		DW	0		; データ部への書き込みﾃﾞｰﾀﾊﾟﾀｰﾝ（Ｄ）

READ_RETRY	DW	0		; ＲＥＡＤ・リトライカウンタ
WRITE_RETRY	DW	0		; ＷＲＩＴＥ・リトライカウンタ
FORMAT_RETRY	DW	0		; ＦＯＲＭＡＴ・リトライカウンタ

TRK_SEC_CNT	DW	8		; トラック当りのセクタ数
SEC_ID_TBL	LABEL	BYTE		; セクタＩＤバッファ
		;	C  H  R  N
		DB	00,00,01,03	; 1
		DB	00,00,02,03	; 2
		DB	00,00,03,03	; 3
		DB	00,00,04,03	; 4
		DB	00,00,05,03	; 5
		DB	00,00,06,03	; 6
		DB	00,00,07,03	; 7
		DB	00,00,08,03	; 8

BUFFSEG		DW	0		; バッファ・セグメント
BUFFOFS		DW	0		; バッファ・オフセット

TRACK_NUMBER	DW	0		; トラック番号
TRACK_COUNTER	DW	0		; トラックカウンタ

DRVNUM1		DW	0		; コピー元ドライブ
DRVNUM2		DW	0		; コピー先ドライブ

NOW_DCYL	DW	0		; 現在のシリンダ番号

TRACK_BUFFSEG	DW	0		; バッファ・セグメント
TRACK_BUFFOFS	DW	0		; バッファ・オフセット

DIRCHKBUF	DB	SEC_BYTE DUP (0)	; dir check buffer.

FLAG_VERIFY	DW	0		; ベリファイ結果 0=同じ,1=異なる

DATA	ENDS

	END
;
;	end of "DCOPY2HD.ASM"
;
