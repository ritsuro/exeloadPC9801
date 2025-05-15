; "DCOPYDUP.ASM" PC98series make by R.H 1993/07/02
;
;
;	2HD disk copy.(multi copy)
;
;
; (C) 1993 ritsurou hashimoto.

INCLUDE	TSTSET.INC
INCLUDE	DCOPYDEF.INC
INCLUDE	TEXTVIEW.INC

DRVNUMMAX_FIX	EQU	4		; １ＭＦＤ固定ドライブ数
DISK_RESULT_TOP	EQU	0564H		; リザルトステータス情報アドレス
DISK_EQUIP	EQU	055CH		; 接続ユニット
RDISK_EQUIP	EQU	0488H		; ＲＡＭドライブ接続状況識別ビット

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

PUBLIC	DCOPYDUP			; 2HD disk copy.(multi copy)

PUBLIC	SET_SHORICHU			; 処理中ディスクセット
PUBLIC	SHOW_DRV_CHECK			; ドライブ接続チェック表
PUBLIC	SHOW_FDDOORS			; ＦＤドライブドア開閉チェック表

EXTRN	DCOPYEMS_RD:NEAR		; 2HD disk all read.
EXTRN	DCOPYEMS_WT:NEAR		; 2HD disk all wtite.
EXTRN	DCOPYEMS_VR:NEAR		; 2HD disk all verify.

EXTRN	DRVNOSET:NEAR			; 2HD disk copy dirve number set.
EXTRN	WRT_DISK_CHK:NEAR		; 書込みディスクのチェック
EXTRN	WRT_DISK_CHK_D:NEAR		; 書込みディスクのチェック(dup mode)
EXTRN	DOSRESET:NEAR			; DOS system reset.

EXTRN	MEMOPN:NEAR			; real memory open.
EXTRN	MEMCLS:NEAR			; real memory close.
EXTRN	MEMSEK:NEAR			; real memory seek.

EXTRN	VMEMOPN:NEAR			; vram memory open.
EXTRN	VMEMCLS:NEAR			; vram memory close.
EXTRN	VMEMSEK:NEAR			; vram memory seek.

EXTRN	CCCKCR:NEAR			; key buffer clear.
EXTRN	CCCFKY:NEAR			; function key.


; ****************************************************
;	2HD disk copy.(multi copy)
;	-O- AX : 0=通常,1=中止
; ****************************************************

DCOPYDUP	PROC	NEAR
	MOV	USE_EMS_PAGE,0		; use EMS page.
	MOV	USE_MEM_PAGE,0		; use main memory page.
	MOV	USE_VRM_PAGE,0		; use vram memory page.

	TX_FRMCLS_D			; frame inside clear screen.
	TX_FRAME_D			; frame.

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
	JNB	DCOPYDUP_2		;
	MOV	AX,0			;
DCOPYDUP_2:				;
	MOV	USE_EMS_MAX_PAGE,AX	; use EMS max page.

	MOV	BX,USE_EMS_MAX_PAGE	; use EMS max page.
	CALL	EMSOPN2			; EMS open.(bank count set)
	MOV	USE_EMS_PAGE,BX		; use EMS page.
	CMP	AX,1			; 0=normal,1=EMS none,2=memory full,3=error
	JE	DCOPYDUP_INP_EMS_NONE
	CMP	AX,2
	JE	DCOPYDUP_INP_EMS_NONE
	CMP	AX,0
	JNE	DCOPYDUP_INP_EMS_NONE

	TX_PRINTV 71,0,TC_CYAN ,"EMS ",USE_EMS_PAGE,"p "

	JMP	DCOPYDUP_INP_SRT_MENU

DCOPYDUP_INP_EMS_NONE:
	MOV	USE_EMS_PAGE,0		; use EMS page.

DCOPYDUP_INP_SRT_MENU:
	MOV	AX,USE_MEM_PAGE		; use main memory page.
	ADD	AX,USE_VRM_PAGE		; use vram memory page.
	ADD	AX,USE_EMS_PAGE		; use EMS page.
	CMP	AX,MAXCILINDER		; max cilinder.
	JB	DCOPYDUP_ERROR_NO_MEM	;

	CALL	DOSRESET		; DOS system reset.

DCOPYDUP_INP_DRV1:
	TX_FRMCLS_D			; frame inside clear screen.

	CALL	SHOW_DRV_CHECK		; ドライブ接続チェック表

	MOV	DRVNUM1,1		; コピー元ドライブ
	MOV	DRVNUM2,2		; コピー元ドライブ

	MOV	AX,DRVNUM1		; コピー元ドライブ
	MOV	BX,DRVNUM2		; コピー先ドライブ
	DEC	AX
	DEC	BX
	CALL	DRVNOSET		; 2HD disk copy dirve number set.

DCOPYDUP_READ:
	MOV	COUNT_WRITE_DISK,0	; 書込みディスク数
	TX_CLEAR 2,3,18

	TX_CLEAR 8,18,70
	TX_CLEAR 8,20,70
	TX_PRINT 8,20,TC_WHITE,"ディスクコピーしないで終了するときは、f.3 か ESC を押して下さい。"
	TX_PRINT 8,9,TC_YELLOW_RV,"ドライブに元ディスクをセットして下さい。"
	CALL	FD_RD_SET		; ＦＤ読込みドライブセット
	TX_CLEAR 8,9,70
	CMP	AX,3			; 3=F3,11=ESC
	JE	DCOPYDUP_QUIT		;
	CMP	AX,11			;
	JE	DCOPYDUP_QUIT		;


	TX_CLEAR 8,14,70
	TX_PRINT 8,14,TC_WHITE_RV,"読込み中"
	TX_CLEAR 8,18,70
	TX_CLEAR 8,20,70
	TX_PRINT 8,18,TC_WHITE,"ディスクコピーを中断するときは、f.3 か ESC を押して下さい。"

	MOV	READ_CRR_DCYL,MAXCILINDER-1	; 読込み・現在シリンダ番号
	CALL	DCOPYEMS_RD			; 2HD disk all read.
	CMP	AX,2				; 0=normal,1=error,2=EMSerror.
	JE	DCOPYDUP_ERROR_EMS_RD		;
	CMP	AX,0				;
	JNE	DCOPYDUP_ERROR_READ		;
	CMP	FLAG_BREAK,1			; flag break.
	JE	DCOPYDUP_BREAK_R		;

	TX_CLEAR 8,14,70
	TX_PRINT 8,14,TC_WHITE_RV,"読込み完了しました。"

DCOPYDUP_LOOP:
	TX_CLEAR 8,18,70
	TX_CLEAR 8,20,70
	TX_PRINT 8,18,TC_WHITE,"読込み直す時は、ESC を押してください。"
	TX_PRINT 8,20,TC_WHITE,"ディスクコピーしないで終了するときは、f.3 を押してください。"

	TX_PRINT 8,9,TC_YELLOW_RV,"ドライブにコピー先ディスクをセットして下さい。"
	CALL	FD_WT_SET		; ＦＤ書込みドライブセット

	TX_CLEAR 8,9,70
	CMP	AX,3			; 3=F3,11=ESC,12=ENTER
	JE	DCOPYDUP_EXIT		;
	CMP	AX,11			;
	JE	DCOPYDUP_READ		;

	TX_CLEAR 8,14,70
	TX_PRINT 8,14,TC_WHITE_RV,"ディスクコピー中"
	TX_CLEAR 8,18,70
	TX_CLEAR 8,20,70
	TX_PRINT 8,18,TC_WHITE,"ディスクコピーを中断するときは、f.3 か ESC を押して下さい。"

	MOV	AX,DRVNUM2		; コピー先ドライブ
	CALL	SET_SHORICHU		; 処理中ディスクセット
	CALL	WRT_DISK_CHK_D		; 書込みディスクのチェック
	PUSH	AX			;
	MOV	AX,0			;
	CALL	SET_SHORICHU		; 処理中ディスクセット
	POP	AX			;
	CMP	AX,1			; 0=normal,1=error,2=user break.
	JE	DCOPYDUP_ERROR_WRITE	;
	CMP	AX,2			;
	JE	DCOPYDUP_BREAK_W	;

	MOV	WRITE_CRR_DCYL,MAXCILINDER-1	; 書込み・現在シリンダ番号
	CALL	DCOPYEMS_WT		; 2HD disk all wtite.
	CMP	AX,2			; 0=normal,1=error,2=EMSerror.
	JE	DCOPYDUP_ERROR_EMS_RD	;
	CMP	AX,0			;
	JNE	DCOPYDUP_ERROR_WRITE	;
	CMP	FLAG_BREAK,1		; flag break.
	JE	DCOPYDUP_BREAK_W	;

	MOV	VERIFY_CRR_DCYL,MAXCILINDER-1	; 照合・現在シリンダ番号
	CALL	DCOPYEMS_VR		; 2HD disk all verify.
	CMP	AX,2			; 0=normal,1=error,2=EMSerror.
	JE	DCOPYDUP_ERROR_EMS_RD	;
	CMP	AX,0			;
	JNE	DCOPYDUP_ERROR_WRITE	;
	CMP	FLAG_BREAK,1		; flag break.
	JE	DCOPYDUP_BREAK_W	;
	CMP	BX,0			; verify 0=same,1=error.
	JNE	DCOPYDUP_ERROR_VERIFY

	TX_CLEAR 8,14,70
	TX_PRINT 8,14,TC_WHITE_RV,"ディスクコピー出来ました。"

	INC	COUNT_WRITE_DISK	; 書込みディスク数
	TX_PRINTV 2,3,TC_CYAN ,"生産数 ",COUNT_WRITE_DISK," 枚 "

	JMP	DCOPYDUP_LOOP

DCOPYDUP_BREAK_R:
	TX_CLEAR 8,14,70
	TX_PRINT 8,14,TC_RED_RV,"読込みを中止しました。"
	JMP	DCOPYDUP_READ

DCOPYDUP_BREAK_W:
	TX_CLEAR 8,14,70
	TX_PRINT 8,14,TC_RED_RV,"ディスクコピーを中止しました。"
	JMP	DCOPYDUP_LOOP

DCOPYDUP_ERROR_READ:
	TX_CLEAR 8,14,70
	TX_PRINT 8,14,TC_RED_RV,"コピー元ディスクが読めませんでした。"
	JMP	DCOPYDUP_READ

DCOPYDUP_ERROR_WRITE:
	TX_CLEAR 8,14,70
	TX_PRINT 8,14,TC_RED_RV,"このディスクには書き込めませんでした。"
	JMP	DCOPYDUP_LOOP

DCOPYDUP_ERROR_VERIFY:
	TX_CLEAR 8,14,70
	TX_PRINT 8,14,TC_RED_RV,"照合エラー、このディスクにはディスクコピー出来ません。"
	JMP	DCOPYDUP_LOOP

DCOPYDUP_ERROR_NO_MEM:
	TX_PRINT 8,13,TC_WHITE_RV,"メモリーが足りません"
	JMP	DCOPYDUP_ERROR_END

DCOPYDUP_ERROR_EMS_RD:
	TX_PRINT 8,13,TC_WHITE_RV,"ＥＭＳのエラーです"
	JMP	DCOPYDUP_ERROR_END

DCOPYDUP_ERROR_END:
	TX_CLEAR 8,14,70
	TX_CLEAR 8,18,70
	TX_PRINT 8,18,TC_WHITE,"致命的なエラーの為、ディスクコピーを実行出来ません。"
	TX_PRINT 8,20,TC_WHITE,"何かキーを押すと終了します。"
	CALL	TXVW_UWAIT2		; user wait2.(anther key)
	JMP	DCOPYDUP_QUIT		;

DCOPYDUP_EXIT:
	CALL	EMSCLS			; EMS close.
	CALL	VMEMCLS			; vram memory close.
	CALL	MEMCLS			; real memory close.
	MOV	AX,0			; 0=通常
	RET
DCOPYDUP_QUIT:
	CALL	EMSCLS			; EMS close.
	CALL	VMEMCLS			; vram memory close.
	CALL	MEMCLS			; real memory close.
	MOV	AX,1			; 1=中止
	RET
DCOPYDUP	ENDP


; *********************************************************
;	ＦＤ読込みドライブセット
;	-O- AX : 0=FDset,3=F3,11=ESC
; *********************************************************

FD_RD_SET	PROC	NEAR

FD_RD_SET_RETRY:
	CALL	TXT_FD_WAIT		; ＦＤセット待ち
	CMP	AX,0			; 0=FDset,3=F3,11=ESC
	JNE	FD_RD_SET_EXIT		;

	MOV	BX,0			;
	MOV	CX,DRVNUMMAX_FIX	; １ＭＦＤ固定ドライブ数
FD_RD_SET_LOOP:				;
	CMP	DRIVE_SETNOW[BX],1	; ＦＤセット状況 1=未アクセスＦＤ
	JE	FD_RD_SET_5		;
	INC	BX			;
	LOOP	FD_RD_SET_LOOP		;

	JMP	FD_RD_SET_RETRY

FD_RD_SET_5:				;
	INC	BX			;
	MOV	DRVNUM1,BX		; コピー元ドライブ
	MOV	AX,DRVNUM1		; コピー元ドライブ
	MOV	BX,DRVNUM2		; コピー先ドライブ
	DEC	AX
	DEC	BX
	CALL	DRVNOSET		; 2HD disk copy dirve number set.

	MOV	AX,0			; 0=FDset.
FD_RD_SET_EXIT:
	RET
FD_RD_SET	ENDP


; *********************************************************
;	ＦＤ書込みドライブセット
;	-O- AX : 0=FDset,3=F3,11=ESC
; *********************************************************

FD_WT_SET	PROC	NEAR

FD_WT_SET_RETRY:
	CALL	TXT_FD_WAIT		; ＦＤセット待ち
	CMP	AX,0			; 0=FDset,3=F3,11=ESC
	JNE	FD_WT_SET_EXIT		;

	MOV	BX,0			;
	MOV	CX,DRVNUMMAX_FIX	; １ＭＦＤ固定ドライブ数
FD_WT_SET_LOOP:				;
	CMP	DRIVE_SETNOW[BX],1	; ＦＤセット状況 1=未アクセスＦＤ
	JE	FD_WT_SET_5		;
	INC	BX			;
	LOOP	FD_WT_SET_LOOP		;

	JMP	FD_WT_SET_RETRY

FD_WT_SET_5:				;
	INC	BX			;
	MOV	DRVNUM2,BX		; コピー先ドライブ
	MOV	AX,DRVNUM1		; コピー元ドライブ
	MOV	BX,DRVNUM2		; コピー先ドライブ
	DEC	AX
	DEC	BX
	CALL	DRVNOSET		; 2HD disk copy dirve number set.

	MOV	AX,0			; 0=FDset.
FD_WT_SET_EXIT:
	RET
FD_WT_SET	ENDP



; *********************************************************
;	ＦＤセット待ち
;	-O- AX : 0=FDset,3=F3,11=ESC
;	    COUNT_SETNOW     : ＦＤセット数
;	    COUNT_SETNOW_AC  : 未アクセスＦＤ数
;	    DRIVE_SETNOW[]   : ＦＤセット状況
; *********************************************************

TXT_FD_WAIT	PROC	NEAR
	CALL	CCCKCR			; key buffer clear.
TXT_FD_WAIT_LOOP:
	CALL	SHOW_FDDOORS		; ＦＤドライブドア開閉チェック表
	CMP	COUNT_SETNOW_AC,0	; 未アクセスＦＤ数
	JNE	TXT_FD_WAIT_FDSET	;

	CALL	CCCFKY			; function key.
	CMP	AL,3
	JE	TXT_FD_WAIT_EXIT
	CMP	AL,11
	JE	TXT_FD_WAIT_EXIT

	JMP	TXT_FD_WAIT_LOOP

TXT_FD_WAIT_EXIT:
	RET
TXT_FD_WAIT_FDSET:
	MOV	AX,0		; 0=FDset.
	RET
TXT_FD_WAIT	ENDP


; *********************************************************
;	処理中ディスクセット
;	-I- AX : 処理中ドライブ番号(0=無し)
; *********************************************************

SET_SHORICHU	PROC	NEAR
	MOV	DRIVE_NUM_SHORI,AX	; 処理中ドライブ番号(0=無し)
	CALL	SHOW_FDDOORS		; ＦＤドライブドア開閉チェック表
	RET
SET_SHORICHU	ENDP


; *********************************************************
;	ＦＤドライブドア開閉チェック表
;	-O- COUNT_SETNOW     : ＦＤセット数
;	    COUNT_SETNOW_AC  : 未アクセスＦＤ数
;	    DRIVE_SETNOW[]   : ＦＤセット状況
; *********************************************************

SHOW_FDDOORS	PROC	NEAR
	CALL	FDDOORS			; ＦＤドライブドア開閉チェック

	MOV	LOC_XX,2		; locate x.
	MOV	LOC_YY,21		; locate y.
	MOV	FDDRVNUM,1		; ＦＤドライブ番号
	MOV	CX,DRVNUMMAX_FIX	; １ＭＦＤ固定ドライブ数
SHOW_FDDOORS_LOOP:
	PUSH	CX

	ADD	LOC_XX,4

	MOV	BX,FDDRVNUM		; ＦＤドライブ番号
	CMP	BX,DRIVE_NUM_SHORI	; 処理中ドライブ番号(0=無し)
	JE	SHOW_FDDOORS_SHORI	;

	DEC	BX			;
	CMP	DRIVE_SETNOW[BX],0	; ＦＤセット状況 0=無し
	JE	SHOW_FDDOORS_NONE	;
	CMP	DRIVE_SETNOW[BX],1	; ＦＤセット状況 1=未アクセスＦＤ
	JE	SHOW_FDDOORS_NOWSET	;
	CMP	DRIVE_SETNOW[BX],2	; ＦＤセット状況 2=既にアクセス済み
	JE	SHOW_FDDOORS_ACS	;
	CMP	DRIVE_SETNOW[BX],3	; ＦＤセット状況 3=立ち上がり前のﾃﾞｨｽｸ
	JE	SHOW_FDDOORS_OLD	;

SHOW_FDDOORS_NONE:
	TX_PRINT LOC_XX,LOC_YY,TC_BLUE_RV ,"　　　"
	JMP	SHOW_FDDOORS_NEXT
SHOW_FDDOORS_NOWSET:
	TX_PRINT LOC_XX,LOC_YY,TC_YELLOW_RV ,"未処理"
	JMP	SHOW_FDDOORS_NEXT
SHOW_FDDOORS_ACS:
	TX_PRINT LOC_XX,LOC_YY,TC_CYAN_RV ,"処理済"
	JMP	SHOW_FDDOORS_NEXT
SHOW_FDDOORS_OLD:
	TX_PRINT LOC_XX,LOC_YY,TC_BLUE_RV ,"　？　"
	JMP	SHOW_FDDOORS_NEXT
SHOW_FDDOORS_SHORI:
	TX_PRINT LOC_XX,LOC_YY,TC_WHITE_RV ,"処理中"
	JMP	SHOW_FDDOORS_NEXT
SHOW_FDDOORS_NEXT:
	ADD	LOC_XX,6
	INC	FDDRVNUM		; ＦＤドライブ番号
	POP	CX
	DEC	CX
	JCXZ	SHOW_FDDOORS_9
	JMP	SHOW_FDDOORS_LOOP
SHOW_FDDOORS_9:
	RET
SHOW_FDDOORS	ENDP


; *********************************************************
;	ＦＤドライブドア開閉チェック
;	-O- COUNT_SETNOW     : ＦＤセット数
;	    COUNT_SETNOW_AC  : 未アクセスＦＤ数
;	    DRIVE_SETNOW[]   : ＦＤセット状況
;	ＦＤセット状況  0=無し,1=未アクセスＦＤ,2=既にアクセス済み
;			3=立ち上がり前のﾃﾞｨｽｸ
; *********************************************************

FDDOORS	PROC	NEAR
	MOV	COUNT_SETNOW,0		; ＦＤセット数
	MOV	COUNT_SETNOW_AC,0	; 未アクセスＦＤ数

	MOV	DRVNO,0			; drive number.
	MOV	CX,DRVNUMMAX_FIX	; １ＭＦＤ固定ドライブ数
FDDOORS_LOOP:
	PUSH	CX			;
	MOV	BX,DRVNO		; drive number.
	CMP	DRIVE_EQUIP[BX],0	; 接続ユニット
	JE	FDDOORS_NONE		;
	CMP	DRIVE_RDISK[BX],0	; RAMドライブ接続
	JNE	FDDOORS_NONE		;

	MOV	AX,DRVNO		; drive number.
	CALL	FDRSLT			; 開閉チェック(ﾘｻﾞﾙﾄｽﾃｰﾀｽﾁｪｯｸ)
	CMP	AX,0			; 0=前と変わらず
	JE	FDDOORS_OLD		;
	CMP	AX,1			; 1=ドアを開閉した
	JE	FDDOORS_NOWSET		;
	CMP	AX,2			; 2=ドアが開きっぱなし
	JE	FDDOORS_NONE		;
	CMP	AX,3			; 3=以前からセットされていた
	JE	FDDOORS_OLDOLD		;

FDDOORS_OLDOLD:				; 前と変わらず
	MOV	BX,DRVNO		; drive number.
	INC	COUNT_SETNOW		; ＦＤセット数
	MOV	DRIVE_SETNOW[BX],3	; ＦＤセット状況 3=立ち上がり前のﾃﾞｨｽｸ
	JMP	FDDOORS_NEXT
FDDOORS_OLD:				; 前と変わらず
	MOV	BX,DRVNO		; drive number.
	INC	COUNT_SETNOW		; ＦＤセット数
	MOV	DRIVE_SETNOW[BX],2	; ＦＤセット状況 2=既にアクセス済み
	JMP	FDDOORS_NEXT
FDDOORS_NOWSET:
	INC	COUNT_SETNOW		; ＦＤセット数
	INC	COUNT_SETNOW_AC		; 未アクセスＦＤ数
	MOV	DRIVE_SETNOW[BX],1	; ＦＤセット状況 1=未アクセスＦＤ
	JMP	FDDOORS_NEXT
FDDOORS_NONE:
	MOV	BX,DRVNO		; drive number.
	MOV	DRIVE_SETNOW[BX],0	; ＦＤセット状況 0=無し
FDDOORS_NEXT:
	INC	DRVNO			; drive number.
	POP	CX
	LOOP	FDDOORS_LOOP

FDDOORS_EXIT:
	RET
FDDOORS	ENDP


; *********************************************************
;	ＦＤドライブドア開閉チェック（リザルトステータスチェック）
;	-I- AX : １ＭＦＤドライブ番号
;	-O- AX : 0=前と変わらず,1=ドアを開閉した,2=ドアが開きっぱなし
;		3=以前からセットされていた
; *********************************************************

FDRSLT	PROC	NEAR
	PUSH	DX
	PUSH	BX
	PUSH	ES

	MOV	DX,AX			; DX=ドライブ番号

	MOV	BX,AX
	SHL	BX,1			; *2
	SHL	BX,1			; *4	
	SHL	BX,1			; *8
	ADD	BX,DISK_RESULT_TOP	; リザルトステータス情報アドレス
	MOV	AX,0			;
	MOV	ES,AX			;
	MOV	AL,BYTE PTR ES:[BX]	; disk result status ST0.
	;	  |iiSenHuu|
	;	  |ccEcrDss|
	;	  |10    10|
	AND	AL,11001000B

	CMP	AL,0			;
	JNE	FDRSLT5			;
	MOV	AX,0			; 0=前と変わらず
	JMP	FDRSLT9			;
FDRSLT5:
	CMP	AL,11000000B		;
	JNE	FDRSLT6			;
	MOV	AX,1			; 1=ドアを開閉した
	JMP	FDRSLT9
FDRSLT6:
	CMP	AL,11001000B		;
	JNE	FDRSLT7			;
	MOV	AX,2			; 2=ドアが開きっぱなし
	JMP	FDRSLT9
FDRSLT7:
	MOV	AX,2			; 2=ドアが開きっぱなし

FDRSLT9:				;
	MOV	BX,DX			; DX=ドライブ番号
	CMP	BYTE PTR DS:DISK_DOOR_INI[BX],0	; ディスク開閉初期ﾌﾗｸﾞ
	JZ	FDRSLT_RET		;

	CMP	AX,0			; 0=前と変わらず
	JE	FDRSLT_9OLD		;

	MOV	BYTE PTR DS:DISK_DOOR_INI[BX],0	; ディスク開閉初期ﾌﾗｸﾞ

	JMP	FDRSLT_RET		;

FDRSLT_9OLD:
	MOV	AX,3			; 3=以前からセットされていた
FDRSLT_RET:

	POP	ES
	POP	BX
	POP	DX
	RET
FDRSLT	ENDP


; *********************************************************
;	ドライブ接続チェック表
; *********************************************************

SHOW_DRV_CHECK	PROC	NEAR
	CALL	DRIVE_CHK		; ドライブ接続チェック

	MOV	LOC_XX,2		; locate x.
	MOV	LOC_YY,22		; locate y.
	MOV	FDDRVNUM,1		; ＦＤドライブ番号
	MOV	CX,DRVNUMMAX_FIX	; １ＭＦＤ固定ドライブ数
SHOW_DRV_CHECK_LOOP:
	PUSH	CX

	TX_PRINTV LOC_XX,LOC_YY,TC_CYAN ," FD#",FDDRVNUM," "

	ADD	LOC_XX,5

	MOV	BX,FDDRVNUM		; ＦＤドライブ番号
	DEC	BX			;

	CMP	DRIVE_EQUIP[BX],0	; 接続ユニット
	JE	SHOW_DRV_CHECK_6	;

	CMP	DRIVE_RDISK[BX],0	; RAMドライブ接続
	JE	SHOW_DRV_CHECK_4	;
	TX_PRINT LOC_XX,LOC_YY,TC_CYAN_RV ,"[RAM]"
	JMP	SHOW_DRV_CHECK_5
SHOW_DRV_CHECK_4:
	TX_PRINT LOC_XX,LOC_YY,TC_CYAN_RV ,"[FDD]"
SHOW_DRV_CHECK_5:
	JMP	SHOW_DRV_CHECK_7
SHOW_DRV_CHECK_6:
	TX_PRINT LOC_XX,LOC_YY,TC_RED_RV ,"[OFF]"
SHOW_DRV_CHECK_7:
	ADD	LOC_XX,5
	INC	FDDRVNUM		; ＦＤドライブ番号
	POP	CX
	LOOP	SHOW_DRV_CHECK_LOOP
	RET
SHOW_DRV_CHECK	ENDP


; *********************************************************
;	ドライブ接続チェック
; *********************************************************

DRIVE_CHK	PROC	NEAR
	MOVX	ES,0			;
	MOV	BX,0			; drive number.
	MOV	CX,DRVNUMMAX_FIX	; １ＭＦＤ固定ドライブ数
DRIVE_CHK_LOOP:				;
	PUSH	CX			;
	MOV	CL,BL			; drive number.
	MOV	AL,1			;
	SHL	AL,CL			; ビットＯＮならば接続

	TEST	ES:[DISK_EQUIP],AL	; 接続ユニット
	JZ	DRIVE_CHK_4		;
	MOV	DRIVE_EQUIP[BX],1	; 接続ユニット
DRIVE_CHK_4:				;

	TEST	ES:[RDISK_EQUIP],AL	; ＲＡＭドライブ接続状況識別ビット
	JZ	DRIVE_CHK_5		;
	MOV	DRIVE_RDISK[BX],1	; RAMドライブ接続
DRIVE_CHK_5:				;
	INC	BX			; drive number.
	POP	CX			;
	LOOP	DRIVE_CHK_LOOP		;

	RET
DRIVE_CHK	ENDP

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

EXTRN	USE_EMS_PAGE:WORD		; use EMS page.
EXTRN	USE_MEM_PAGE:WORD		; use main memory page.
EXTRN	USE_VRM_PAGE:WORD		; use vram memory page.
EXTRN	FLAG_BREAK:WORD			; flag break.

EXTRN	READ_CRR_DCYL:WORD		; 読込み・現在シリンダ番号
EXTRN	WRITE_CRR_DCYL:WORD		; 書込み・現在シリンダ番号
EXTRN	VERIFY_CRR_DCYL:WORD		; 照合・現在シリンダ番号

EXTRN	DRVNUM1:WORD			; コピー元ドライブ
EXTRN	DRVNUM2:WORD			; コピー先ドライブ

FLAG_VERIFY	DW	0		; ベリファイ結果 0=同じ,1=異なる

USE_EMS_MAX_PAGE DW	0		; use EMS max page.

DRIVE_EQUIP	DB	DRVNUMMAX_FIX DUP (0)	; 接続ユニット
DRIVE_RDISK	DB	DRVNUMMAX_FIX DUP (0)	; RAMドライブ接続

COUNT_SETNOW	DW	0			; ＦＤセット数
COUNT_SETNOW_AC	DW	0			; 未アクセスＦＤ数
DRIVE_SETNOW	DB	DRVNUMMAX_FIX DUP (0)	; ＦＤセット状況

DISK_DOOR_INI	DB	DRVNUMMAX_FIX DUP (0FFH) ; ディスク開閉初期ﾌﾗｸﾞ

COUNT_WRITE_DISK DW	0		; 書込みディスク数

DRIVE_NUM_SHORI	DW	0		; 処理中ドライブ番号(0=無し)

LOC_XX		DW	0		; locate x.
LOC_YY		DW	0		; locate y.
FDDRVNUM	DW	0		; ＦＤドライブ番号
DRVNO		DW	0		; drive number.

DATA	ENDS

	END
;
;	end of "DCOPYDUP.ASM"
;
