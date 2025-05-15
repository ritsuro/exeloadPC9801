; "DCOPYEMS.ASM" PC98series make by R.H 1993/06/28
;
;
;	2HD disk copy.(use EMS memory)
;
;
; (C) 1993 ritsurou hashimoto.

INCLUDE	TSTSET.INC
INCLUDE	DCOPYDEF.INC
INCLUDE	TEXTVIEW.INC

EMMCOD	SEGMENT	PUBLIC	'EMMCOD'

	ASSUME	CS:EMMCOD

;	FAR call.

EXTRN	EMSCHK:FAR		; EMS check.
EXTRN	EMSOPN:FAR		; EMS open.
EXTRN	EMSOPN2:FAR		; EMS open.(bank count set)
EXTRN	EMSCLS:FAR		; EMS close.
EXTRN	EMSSEK:FAR		; EMS seek.
EXTRN	EMS64K:FAR		; EMS seek 64k frame.

EMMCOD	ENDS

SEGFREE	SEGMENT	PUBLIC	'SEGFREE'
SEGFREE	ENDS

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	DCOPY2HDEMS			; 2HD disk copy.(use EMS memory)

PUBLIC	DCOPYEMS_RD			; 2HD disk all read.
PUBLIC	DCOPYEMS_WT			; 2HD disk all wtite.
PUBLIC	DCOPYEMS_VR			; 2HD disk all verify.

EXTRN	SET_SHORICHU:NEAR		; 処理中ディスクセット
EXTRN	SHOW_DRV_CHECK:NEAR		; ドライブ接続チェック表
EXTRN	SHOW_FDDOORS:NEAR		; ＦＤドライブドア開閉チェック表

EXTRN	DRVNOSET:NEAR			; 2HD disk copy dirve number set.
EXTRN	P_CPY_S_DISK:NEAR		; １ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー元ディスク交換
EXTRN	P_CPY_D_DISK:NEAR		; １ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー先ディスク交換
EXTRN	DCRD_ERR_CHK:NEAR		; 読込み時エラーチェック
EXTRN	DCWR_ERR_CHK:NEAR		; 書込み時エラーチェック
EXTRN	RDSECTOR:NEAR			; セクタＲＥＡＤ
EXTRN	WTSECTOR:NEAR			; セクタＷＲＩＴＥ
EXTRN	VRFYSECTOR:NEAR			; セクタＶＥＲＩＦＹ
EXTRN	WRT_DISK_CHK:NEAR		; 書込みディスクのチェック
EXTRN	DOSRESET:NEAR			; DOS system reset.

EXTRN	MEMOPN:NEAR			; real memory open.
EXTRN	MEMCLS:NEAR			; real memory close.
EXTRN	MEMSEK:NEAR			; real memory seek.

EXTRN	VMEMOPN:NEAR			; vram memory open.
EXTRN	VMEMCLS:NEAR			; vram memory close.
EXTRN	VMEMSEK:NEAR			; vram memory seek.


; ****************************************************
;	2HD disk copy.(use EMS memory)
;	-O- AX : 0=通常,1=中止
; ****************************************************

DCOPY2HDEMS	PROC	NEAR
	MOV	USE_EMS_PAGE,0		; use EMS page.
	MOV	USE_MEM_PAGE,0		; use main memory page.
	MOV	USE_VRM_PAGE,0		; use vram memory page.

	TX_FRMCLS			; frame inside clear screen.

	TX_PRINTVH 40,0,TC_CYAN ,"free ",<SEG SEGFREE>,"h "

	CALL	MEMOPN			; real memory open.
	MOV	USE_MEM_PAGE,BX		; use main memory page.

	TX_PRINTV 54,0,TC_CYAN ,"mem ",USE_MEM_PAGE,"p "

	CALL	VMEMOPN			; vram memory open.
	MOV	USE_VRM_PAGE,BX		; use vram memory page.

	TX_PRINTV 62,0,TC_CYAN ,"vram ",USE_VRM_PAGE,"p "

	MOV	AX,MAXCILINDER		; max cilinder.
	MOV	BX,USE_MEM_PAGE		; use main memory page.
	ADD	BX,USE_VRM_PAGE		; use vram memory page.
	SUB	AX,BX			;
	JNB	DCOPY2HDEMS_2		;
	MOV	AX,0			;
DCOPY2HDEMS_2:				;
	MOV	USE_EMS_MAX_PAGE,AX	; use EMS max page.

	MOV	BX,USE_EMS_MAX_PAGE	; use EMS max page.
	CALL	EMSOPN2			; EMS open.(bank count set)
	MOV	USE_EMS_PAGE,BX		; use EMS page.
	CMP	AX,1			; 0=normal,1=EMS none,2=memory full,3=error
	JE	DCOPY2HDEMS_INP_EMS_NONE
	CMP	AX,2
	JE	DCOPY2HDEMS_INP_EMS_NONE
	CMP	AX,0
	JNE	DCOPY2HDEMS_INP_EMS_NONE

	TX_PRINTV 71,0,TC_CYAN ,"EMS ",USE_EMS_PAGE,"p "

	JMP	DCOPY2HDEMS_INP_SRT_MENU

DCOPY2HDEMS_INP_EMS_NONE:
	MOV	USE_EMS_PAGE,0		; use EMS page.

DCOPY2HDEMS_INP_SRT_MENU:

	CALL	DOSRESET		; DOS system reset.

DCOPY2HDEMS_INP_DRV1:
	TX_FRMCLS			; frame inside clear screen.

	CALL	SHOW_DRV_CHECK		; ドライブ接続チェック表
	CALL	SHOW_FDDOORS		; ＦＤドライブドア開閉チェック表

	TX_PRINT 8,18,TC_WHITE,"戻るときは、ESC を押してください。"
	TX_PRINT 8,20,TC_WHITE,"ディスクコピーしないで終了するときは、f.3 を押してください。"

	TX_PRINT 8,5,TC_YELLOW_RV,"コピー元のドライブ番号を数字キーで指定して下さい。"
	TX_1TO4N			; select number 1-4.
	CMP	BX,11			; 0=normal,3=F3,11=ESC
	JE	DCOPY2HDEMS_INP_DRV1	;
	CMP	BX,3			;
	JE	DCOPY2HDEMS_QUIT		;
	MOV	DRVNUM1,AX		; コピー元ドライブ
	TX_CLEAR 8,5,70
	TX_PRINT 8,5,TC_WHITE, "コピー元のドライブ番号"
	MOV	SI,DRVNUM1		; コピー元ドライブ
	DEC	SI
	SHL	SI,1
	TX_PRINTA 40,5,TC_WHITE,STR_DRV_NUM[SI]

DCOPY2HDEMS_INP_DRV2:
	TX_PRINT 8,7,TC_YELLOW_RV,"コピー先のドライブ番号を数字キーで指定して下さい。"
	TX_1TO4N			; select number 1-4.
	CMP	BX,11			; 0=normal,3=F3,11=ESC
	JE	DCOPY2HDEMS_INP_DRV1	;
	CMP	BX,3			;
	JE	DCOPY2HDEMS_QUIT		;
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

DCOPY2HDEMS_INP_RET:
	CALL	SHOW_FDDOORS		; ＦＤドライブドア開閉チェック表

	CMPX	DRVNUM1,DRVNUM2		; コピー元ドライブ : コピー先ドライブ
	JE	DCOPY2HDEMS_31		;
	TX_PRINT 8,9,TC_YELLOW_RV,"ドライブにディスクをセットしてリターンキーを押してください。"
	JMP	DCOPY2HDEMS_32
DCOPY2HDEMS_31:
	TX_PRINT 8,9,TC_YELLOW_RV,"コピー元ディスクをセットしてリターンキーを押してください。"
DCOPY2HDEMS_32:

	TX_UWAIT			; user wait.
	TX_CLEAR 8,9,70
	CMP	AX,3			; 3=F3,11=ESC,12=ENTER
	JE	DCOPY2HDEMS_QUIT	;
	CMP	AX,11			;
	JE	DCOPY2HDEMS_INP_DRV2	;

	TX_CLEAR 8,18,70
	TX_CLEAR 8,20,70

	TX_PRINT 8,18,TC_WHITE,"ディスクコピーを中断するときは、f.3 か ESC を押してください。"

	MOV	READ_CRR_DCYL,MAXCILINDER-1	; 読込み・現在シリンダ番号
	MOV	WRITE_CRR_DCYL,MAXCILINDER-1	; 書込み・現在シリンダ番号
	MOV	VERIFY_CRR_DCYL,MAXCILINDER-1	; 照合・現在シリンダ番号

	JMP	DCOPY2HDEMS_INTER

DCOPY2HDEMS_LOOP:
	CALL	P_CPY_S_DISK		; １ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー元ディスク交換
	CMP	AX,1			; 0=正常,1=中止
	JE	DCOPY2HDEMS_BREAK	;
DCOPY2HDEMS_INTER:

	CALL	DCOPYEMS_RD		; 2HD disk all read.
	CMP	AX,2			; 0=normal,1=error,2=EMSerror.
	JE	DCOPY2HDEMS_ERROR_EMS_RD
	CMP	AX,0			;
	JNE	DCOPY2HDEMS_ERROR_READ
	CMP	FLAG_BREAK,1		; flag break.
	JE	DCOPY2HDEMS_BREAK	;

	CALL	P_CPY_D_DISK		; １ﾄﾞﾗｲﾌﾞｺﾋﾟｰのコピー先ディスク交換
	CMP	AX,1			; 0=正常,1=中止
	JE	DCOPY2HDEMS_BREAK	;

	CMP	WRITE_CRR_DCYL,MAXCILINDER-1	; 書込み・現在シリンダ番号
	JB	DCOPY2HDEMS_WRT

	MOV	AX,DRVNUM2		; コピー先ドライブ
	CALL	SET_SHORICHU		; 処理中ディスクセット
	CALL	WRT_DISK_CHK		; 書込みディスクのチェック
	PUSH	AX			;
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	POP	AX			;
	CMP	AX,1			; 0=normal,1=error,2=user break.
	JE	DCOPY2HDEMS_ERROR_WRITE	;
	CMP	AX,2			;
	JE	DCOPY2HDEMS_BREAK	;
DCOPY2HDEMS_WRT:

	CALL	DCOPYEMS_WT		; 2HD disk all wtite.
	CMP	AX,2			; 0=normal,1=error,2=EMSerror.
	JE	DCOPY2HDEMS_ERROR_EMS_RD
	CMP	AX,0			;
	JNE	DCOPY2HDEMS_ERROR_WRITE
	CMP	FLAG_BREAK,1		; flag break.
	JE	DCOPY2HDEMS_BREAK	;

	CALL	DCOPYEMS_VR		; 2HD disk all verify.
	CMP	AX,2			; 0=normal,1=error,2=EMSerror.
	JE	DCOPY2HDEMS_ERROR_EMS_RD
	CMP	AX,0			;
	JNE	DCOPY2HDEMS_ERROR_WRITE
	CMP	FLAG_BREAK,1		; flag break.
	JE	DCOPY2HDEMS_BREAK	;

	CMP	BX,0			; verify 0=same,1=error.
	JNE	DCOPY2HDEMS_ERROR_VERIFY

	CMP	VERIFY_CRR_DCYL,0	; 照合・現在シリンダ番号
	JL	DCOPY2HDEMS_COMPLITE

	JMP	DCOPY2HDEMS_LOOP

DCOPY2HDEMS_COMPLITE:
	TX_PRINT 8,13,TC_WHITE_RV,"ディスクコピー出来ました。"
	JMP	DCOPY2HDEMS_NEXTDISK

DCOPY2HDEMS_BREAK:
	TX_PRINT 8,13,TC_WHITE_RV,"ディスクコピーを中止します。"
	JMP	DCOPY2HDEMS_NEXTDISK

DCOPY2HDEMS_ERROR_READ:
	TX_PRINT 8,13,TC_WHITE_RV,"コピー元ディスクが読めませんでした。"
	JMP	DCOPY2HDEMS_NEXTDISK

DCOPY2HDEMS_ERROR_WRITE:
	TX_PRINT 8,13,TC_WHITE_RV,"このディスクには書き込めませんでした。"
	JMP	DCOPY2HDEMS_NEXTDISK

DCOPY2HDEMS_ERROR_VERIFY:
	TX_PRINT 8,13,TC_WHITE_RV,"このディスクにはディスクコピー出来ません。"
	JMP	DCOPY2HDEMS_NEXTDISK

DCOPY2HDEMS_ERROR_EMS_RD:
	TX_PRINT 8,13,TC_WHITE_RV,"ＥＭＳのエラーです"
	JMP	DCOPY2HDEMS_ERROR_END

DCOPY2HDEMS_NEXTDISK:
	TX_CLEAR 8,14,70
	TX_CLEAR 8,18,70
 TX_PRINT 8,18,TC_WHITE,"次のディスクコピーを行うときはリターンキーを押してください。"
 TX_PRINT 8,20,TC_WHITE,"ディスクコピーしないで終了するときは、f.3 か ESC を押してください。"
	TX_UWAIT			; user wait.
	TX_CLEAR 8,13,70
	CMP	AX,3			; 3=F3,11=ESC,12=ENTER
	JE	DCOPY2HDEMS_EXIT	;
	CMP	AX,11			;
	JE	DCOPY2HDEMS_EXIT	;
	TX_CLEAR 8,18,70
	TX_CLEAR 8,20,70
	TX_PRINT 8,18,TC_WHITE,"戻るときは、ESC を押してください。"
	TX_PRINT 8,20,TC_WHITE,"ディスクコピーしないで終了するときは、f.3 を押してください。"
	JMP	DCOPY2HDEMS_INP_RET
DCOPY2HDEMS_ERROR_END:
	TX_CLEAR 8,14,70
	TX_CLEAR 8,18,70
	TX_PRINT 8,18,TC_WHITE,"致命的なエラーの為、ディスクコピーを実行出来ません。"
	TX_PRINT 8,20,TC_WHITE,"何かキーを押すと終了します。"
	CALL	TXVW_UWAIT2		; user wait2.(anther key)
	JMP	DCOPY2HDEMS_QUIT	;

DCOPY2HDEMS_EXIT:
	CALL	EMSCLS			; EMS close.
	CALL	VMEMCLS			; vram memory close.
	CALL	MEMCLS			; real memory close.
	MOV	AX,0			; 0=通常
	RET
DCOPY2HDEMS_QUIT:
	CALL	EMSCLS			; EMS close.
	CALL	VMEMCLS			; vram memory close.
	CALL	MEMCLS			; real memory close.
	MOV	AX,1			; 1=中止
	RET
DCOPY2HDEMS	ENDP


; ****************************************************
;	2HD disk all read.
;	-I/O- READ_CRR_DCYL : 読込み・現在シリンダ番号
;	-O-   FLAG_BREAK : flag break.
;	      AX         : 0=normal,1=error,2=EMSerror.
; ****************************************************

DCOPYEMS_RD	PROC	NEAR
	MOV	FLAG_BREAK,0		; flag break.

	MOV	AX,DRVNUM1		; コピー元ドライブ
	CALL	SET_SHORICHU		; 処理中ディスクセット

	MOVX	CNT_EMS_PAGE,USE_EMS_PAGE ; use EMS page.
	MOVX	CNT_MEM_PAGE,USE_MEM_PAGE ; use main memory page.
	MOVX	CNT_VRM_PAGE,USE_VRM_PAGE ; use vram memory page.

	MOV	DLEN,1024*16		; データ長（ＤＴＬ）（バイト単位）

DCOPYEMS_RD_LOOP:
	TX_PRINTV 8,14,TC_WHITE ,"読込み中　残り ",READ_CRR_DCYL," です  "	; print value.
	CALL	SHOW_FDDOORS		; ＦＤドライブドア開閉チェック表

	CALL	MEM_SEQ_ALLOC		; memory sequence allocation.
	CMP	AX,1			; 0=normal,1=error,2=memory end.
	JE	DCOPYEMS_RD_ERROR_EMS	;
	CMP	AX,2
	JE	DCOPYEMS_RD_EXIT

DCOPYEMS_RD_READ:
	MOVX	BUFFSEG,ES		; EMS frame segment.
	MOV	BUFFOFS,0		; バッファ・オフセット

DCOPYEMS_RD_RETRY:
	MOVX	DCYL,READ_CRR_DCYL	; 読込み・現在シリンダ番号
	MOV	DHEAD,0			; ヘッド番号（Ｈ）
	MOV	DSECR,1			; セクタ番号（Ｒ）
	CALL	RDSECTOR		; セクタＲＥＡＤ

	CALL	DCRD_ERR_CHK		; 読込み時エラーチェック
	CMP	AX,1			; 1=再度読込み実行
	JE	DCOPYEMS_RD_RETRY	;
	CMP	AX,2			; 2=致命的なエラー
	JE	DCOPYEMS_RD_ERROR_READ	;
	CMP	AX,3			; 3=中止
	JE	DCOPYEMS_RD_BREAK	;

	DEC	READ_CRR_DCYL		; 読込み・現在シリンダ番号
	CMP	READ_CRR_DCYL,0		; 読込み・現在シリンダ番号
	JL	DCOPYEMS_RD_EXIT

	JMP	DCOPYEMS_RD_LOOP

DCOPYEMS_RD_EXIT:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,0			; 0=normal.
	RET
DCOPYEMS_RD_BREAK:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	FLAG_BREAK,1		; flag break.
	MOV	AX,0			; 0=normal.
	RET
DCOPYEMS_RD_ERROR_READ:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,1			; 1=error.
	RET
DCOPYEMS_RD_ERROR_EMS:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,2			; 2=EMSerror.
	RET
DCOPYEMS_RD	ENDP


; ****************************************************
;	2HD disk all wtite.
;	-I/O- WRITE_CRR_DCYL : 書込み・現在シリンダ番号
;	-O-   FLAG_BREAK : flag break.
;	      AX         : 0=normal,1=error,2=EMSerror.
; ****************************************************

DCOPYEMS_WT	PROC	NEAR
	MOV	FLAG_BREAK,0		; flag break.

	MOV	AX,DRVNUM2		; コピー先ドライブ
	CALL	SET_SHORICHU		; 処理中ディスクセット

	MOVX	CNT_EMS_PAGE,USE_EMS_PAGE ; use EMS page.
	MOVX	CNT_MEM_PAGE,USE_MEM_PAGE ; use main memory page.
	MOVX	CNT_VRM_PAGE,USE_VRM_PAGE ; use vram memory page.

	MOV	DLENWRT,1024*8		; データ長（ＤＴＬ）（バイト単位）書込

DCOPYEMS_WT_LOOP:
	TX_PRINTV 8,14,TC_WHITE ,"書込み中　残り ",WRITE_CRR_DCYL," です  "	; print value.
	CALL	SHOW_FDDOORS		; ＦＤドライブドア開閉チェック表

	CALL	MEM_SEQ_ALLOC		; memory sequence allocation.
	CMP	AX,1			; 0=normal,1=error,2=memory end.
	JE	DCOPYEMS_WT_ERROR_EMS	;
	CMP	AX,2
	JE	DCOPYEMS_WT_EXIT

DCOPYEMS_WT_WRITE:
	MOV	BUFFSEG,ES		; EMS frame segment.
	MOV	BUFFOFS,0		; バッファ・オフセット

DCOPYEMS_WT_RETRY1:
	MOVX	DCYL,WRITE_CRR_DCYL	; 書込み・現在シリンダ番号
	MOV	DHEAD,0			; ヘッド番号（Ｈ）
	MOV	DSECR,1			; セクタ番号（Ｒ）
	CALL	WTSECTOR		; セクタＷＲＩＴＥ

	CALL	DCWR_ERR_CHK		; 書込み時エラーチェック
	CMP	AX,1			; 1=再度書込み実行
	JE	DCOPYEMS_WT_RETRY1	;
	CMP	AX,2			; 2=致命的なエラー
	JE	DCOPYEMS_WT_ERROR_WRITE	;
	CMP	AX,3			; 3=中止
	JE	DCOPYEMS_WT_BREAK	;

	ADD	BUFFOFS,1024*8		; バッファ・オフセット
DCOPYEMS_WT_RETRY2:
	MOVX	DCYL,WRITE_CRR_DCYL	; 書込み・現在シリンダ番号
	MOV	DHEAD,1			; ヘッド番号（Ｈ）
	MOV	DSECR,1			; セクタ番号（Ｒ）
	CALL	WTSECTOR		; セクタＷＲＩＴＥ

	CALL	DCWR_ERR_CHK		; 書込み時エラーチェック
	CMP	AX,1			; 1=再度書込み実行
	JE	DCOPYEMS_WT_RETRY2	;
	CMP	AX,2			; 2=致命的なエラー
	JE	DCOPYEMS_WT_ERROR_WRITE	;
	CMP	AX,3			; 3=中止
	JE	DCOPYEMS_WT_BREAK	;

	DEC	WRITE_CRR_DCYL		; 書込み・現在シリンダ番号
	CMP	WRITE_CRR_DCYL,0	; 書込み・現在シリンダ番号
	JL	DCOPYEMS_WT_EXIT

	JMP	DCOPYEMS_WT_LOOP

DCOPYEMS_WT_EXIT:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,0			; 0=normal.
	RET
DCOPYEMS_WT_BREAK:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	FLAG_BREAK,1		; flag break.
	MOV	AX,0			; 0=normal.
	RET
DCOPYEMS_WT_ERROR_WRITE:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,1			; 1=error.
	RET
DCOPYEMS_WT_ERROR_EMS:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,2			; 1=EMSerror.
	RET
DCOPYEMS_WT	ENDP





; ****************************************************
;	2HD disk all verify.
;	-I/O- VERIFY_CRR_DCYL : 照合・現在シリンダ番号
;	-O- FLAG_BREAK : flag break.
;	    AX         : 0=normal,1=error,2=EMSerror.
;	    BX         : verify 0=same,1=error.
; ****************************************************

DCOPYEMS_VR	PROC	NEAR
	MOV	FLAG_BREAK,0		; flag break.

	MOV	AX,DRVNUM2		; コピー先ドライブ
	CALL	SET_SHORICHU		; 処理中ディスクセット

	MOVX	CNT_EMS_PAGE,USE_EMS_PAGE ; use EMS page.
	MOVX	CNT_MEM_PAGE,USE_MEM_PAGE ; use main memory page.
	MOVX	CNT_VRM_PAGE,USE_VRM_PAGE ; use vram memory page.

	MOV	DLENWRT,1024*16		; データ長（ＤＴＬ）（バイト単位）書込

DCOPYEMS_VR_LOOP:
	TX_PRINTV 8,14,TC_WHITE ,"照合中　　残り ",VERIFY_CRR_DCYL," です  "	; print value.
	CALL	SHOW_FDDOORS		; ＦＤドライブドア開閉チェック表

	CALL	MEM_SEQ_ALLOC		; memory sequence allocation.
	CMP	AX,1			; 0=normal,1=error,2=memory end.
	JE	DCOPYEMS_VR_ERROR_EMS
	CMP	AX,2
	JE	DCOPYEMS_VR_EXIT

DCOPYEMS_VR_READ:
	MOVX	BUFFSEG,ES		; frame segment.
	MOV	BUFFOFS,0		; バッファ・オフセット

DCOPYEMS_VR_RETRY:
	MOVX	DCYL,VERIFY_CRR_DCYL	; 照合・現在シリンダ番号
	MOV	DHEAD,0			; ヘッド番号（Ｈ）
	MOV	DSECR,1			; セクタ番号（Ｒ）
	CALL	VRFYSECTOR		; セクタＶＥＲＩＦＹ
	MOV	FLAG_VERIFY,AX		; ベリファイ結果 0=同じ,1=異なる

	CALL	DCWR_ERR_CHK		; 書込み時エラーチェック
	CMP	AX,1			; 1=再度書込み実行
	JE	DCOPYEMS_VR_RETRY	;
	CMP	AX,2			; 2=致命的なエラー
	JE	DCOPYEMS_VR_ERROR_READ	;
	CMP	AX,3			; 3=中止
	JE	DCOPYEMS_VR_BREAK	;

	CMP	FLAG_VERIFY,0		; ベリファイ結果 0=同じ,1=異なる
	JNE	DCOPYEMS_VR_VERIFY_ERR	;

	DEC	VERIFY_CRR_DCYL		; シリンダ番号（Ｃ）
	CMP	VERIFY_CRR_DCYL,0	; シリンダ番号（Ｃ）
	JL	DCOPYEMS_VR_EXIT

	JMP	DCOPYEMS_VR_LOOP

DCOPYEMS_VR_EXIT:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,0			; 0=normal.
	MOV	BX,0			; verify 0=same.
	RET
DCOPYEMS_VR_VERIFY_ERR:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,0			; 0=normal.
	MOV	BX,1			; verify 1=error.
	RET
DCOPYEMS_VR_BREAK:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	FLAG_BREAK,1		; flag break.
	MOV	AX,0			; 0=normal.
	MOV	BX,1			; verify 1=error.
	RET
DCOPYEMS_VR_ERROR_READ:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,1			; 1=error.
	MOV	BX,1			; verify 1=error.
	RET
DCOPYEMS_VR_ERROR_EMS:
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	MOV	AX,2			; 1=EMSerror.
	MOV	BX,1			; verify 1=error.
	RET
DCOPYEMS_VR	ENDP


; ****************************************************
;	memory sequence allocation.
;	-O- AX : 0=normal,1=error,2=memory end.
;	    ES : memory frame segment.
; ****************************************************

MEM_SEQ_ALLOC	PROC	NEAR
	CMP	CNT_MEM_PAGE,0		; use main memory page.(16kbytes)
	JLE	MEM_SEQ_ALLOC_VRAM_SEEK	;
	DEC	CNT_MEM_PAGE		; use main memory page.(16kbytes)

	TX_PRINTV 0,24,TC_CYAN ,"mem ",CNT_MEM_PAGE,"   "

	MOV	BX,CNT_MEM_PAGE		; use main memory page.(16kbytes)
	CALL	MEMSEK			; real memory seek.
	CMP	AX,0			; 0=normal,3=error
	JNE	MEM_SEQ_ALLOC_ERROR	;

	JMP	MEM_SEQ_ALLOC_EXIT	;

MEM_SEQ_ALLOC_VRAM_SEEK:
	CMP	CNT_VRM_PAGE,0		; count vram memory page.
	JLE	MEM_SEQ_ALLOC_EMS_SEEK	;
	DEC	CNT_VRM_PAGE		; count vram memory page.

	TX_PRINTV 0,24,TC_CYAN ,"vram ",CNT_VRM_PAGE,"   "

	MOV	BX,CNT_VRM_PAGE		; count vram memory page.
	CALL	VMEMSEK			; vram memory seek.
	CMP	AX,0			; 0=normal,3=error
	JNE	MEM_SEQ_ALLOC_ERROR	;

	JMP	MEM_SEQ_ALLOC_EXIT	;

MEM_SEQ_ALLOC_EMS_SEEK:
	CMP	CNT_EMS_PAGE,0		; count EMS page.
	JLE	MEM_SEQ_ALLOC_MEMEND	;
	DEC	CNT_EMS_PAGE		; count EMS page.

	TX_PRINTV 0,24,TC_CYAN ,"EMS ",CNT_EMS_PAGE,"   "

	MOV	BX,CNT_EMS_PAGE		; count EMS page.
	CALL	EMSSEK			; EMS seek.(seek size 16kbyte.)
	CMP	AX,0			; 0=normal,3=error
	JNE	MEM_SEQ_ALLOC_ERROR	;

MEM_SEQ_ALLOC_EXIT:
	TX_PRINTVH 8,24,TC_CYAN ,"seg ",ES,"h"

	MOV	AX,0			; 0=normal.
	RET
MEM_SEQ_ALLOC_ERROR:
	MOV	AX,1			; 1=error.
	RET
MEM_SEQ_ALLOC_MEMEND:
	MOV	AX,2			; 2=memory end.
	RET
MEM_SEQ_ALLOC	ENDP


; ****************************************************
;	key buffer clear.
; ****************************************************

KEY_BUFFER_CLEAR	PROC	NEAR
KEY_BUFFER_CLEAR_LOOP:
	CALL	KEYLOD			; key buffer read.
	CMP	DX,0			; character code. (NULL=none)
	JNE	KEY_BUFFER_CLEAR_LOOP	;
	RET
KEY_BUFFER_CLEAR	ENDP

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

PUBLIC	USE_EMS_PAGE			; use EMS page.
PUBLIC	USE_MEM_PAGE			; use main memory page.
PUBLIC	USE_VRM_PAGE			; use vram memory page.
PUBLIC	FLAG_BREAK			; flag break.

PUBLIC	READ_CRR_DCYL			; 読込み・現在シリンダ番号
PUBLIC	WRITE_CRR_DCYL			; 書込み・現在シリンダ番号
PUBLIC	VERIFY_CRR_DCYL			; 照合・現在シリンダ番号

EXTRN	DLEN:WORD			; データ長（ＤＴＬ）（バイト単位）
EXTRN	DLENWRT:WORD			; データ長（ＤＴＬ）（バイト単位）書込
EXTRN	DCYL:WORD			; シリンダ番号（Ｃ）
EXTRN	DHEAD:WORD			; ヘッド番号（Ｈ）
EXTRN	DSECR:WORD			; セクタ番号（Ｒ）
EXTRN	DSECN:WORD			; セクタ長（Ｎ）
EXTRN	DSTAT:WORD			; ステータス情報
EXTRN	DERROR:WORD			; 0=正常,1=エラー
EXTRN	BUFFSEG:WORD			; バッファ・セグメント
EXTRN	BUFFOFS:WORD			; バッファ・オフセット

EXTRN	DRVNUM1:WORD			; コピー元ドライブ
EXTRN	DRVNUM2:WORD			; コピー先ドライブ

FLAG_BREAK	DW	0		; flag break.

CNT_EMS_PAGE	DW	0		; count EMS page.
CNT_MEM_PAGE	DW	0		; count main memory page.
CNT_VRM_PAGE	DW	0		; count vram memory page.

USE_EMS_PAGE	DW	0		; use EMS page.
USE_MEM_PAGE	DW	0		; use main memory page.
USE_VRM_PAGE	DW	0		; use vram memory page.

READ_CRR_DCYL	DW	0		; 読込み・現在シリンダ番号
WRITE_CRR_DCYL	DW	0		; 書込み・現在シリンダ番号
VERIFY_CRR_DCYL	DW	0		; 照合・現在シリンダ番号

FLAG_VERIFY	DW	0		; ベリファイ結果 0=同じ,1=異なる

USE_EMS_MAX_PAGE DW	0		; use EMS max page.

DATA	ENDS

	END
;
;	end of "DCOPYEMS.ASM"
;
