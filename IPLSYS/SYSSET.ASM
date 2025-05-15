; "SYSSET.ASM" PC-9801UV11 make by R.H 1989/12/01
;
;	E X E L O A D    I P L   k i t .
;
;	I P L   &   s y s t e m    w r i t e .
;
;	ＩＰＬとシステムの書き込み

INCLUDE	TSTSET.INC

CODIPL	SEGMENT	PUBLIC	'CODIPL'
	EXTRN	IPLTOP:FAR		; ＩＰＬコードの先頭
	EXTRN	IPLEND:FAR		; ＩＰＬコードの終わり
CODIPL	ENDS


CODSYS	SEGMENT	PUBLIC	'CODSYS'
	EXTRN	SYSTOP:FAR		; システムコードの先頭
	EXTRN	SYSEND:FAR		; システムコードの終わり
CODSYS	ENDS


CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	SYSSET			; システムの２ＨＤＦＤへの転送


EXTRN	SCWINI:NEAR		; 初期設定
EXTRN	SCWSET:NEAR		; 論理レコード設定
EXTRN	SCWSEQ:NEAR		; セクター順次書き込み
EXTRN	SCWDRV:NEAR		; ドライブ番号の設定（０ー３）


SYSTEM_SIZE	EQU	65530	; システムサイズの上限

;	５’２ＨＤの場合です

SEC_BYTE	EQU	1024	; セクタバイト数

REC_IPL		EQU	0	; ＩＰＬの先頭レコード
REC_FAT		EQU	1	; ＦＡＴの先頭レコード
REC_ROOT	EQU	5	; ＲＯＯＴの先頭レコード
REC_CLAST	EQU	11	; クラスタの先頭レコード
CLAST_TOP	EQU	2	; 先頭クラスタ番号

END_SEC_MARK	EQU	0FFFH	; 最後のセクタマーク


;	システムの２ＨＤＦＤへの転送
;	-I- DX : ドライブ番号（０ー３）
;	-O- AX : 0=正常,1=エラー

SYSSET	PROC	NEAR
	MOV	DRVNO,DX		; ドライブ番号

	CALL	IPL_SIZE_CHECK		; ＩＰＬのサイズチェック
	CMP	AX,0			; 0=正常,1=サイズオバー
	JNE	SYSSET_IPL_SIZE_OV	;

	CALL	SYS_SIZE_CHECK		; システムのサイズチェック
	CMP	AX,0			; 0=正常,1=サイズオバー
	JNE	SYSSET_SYS_SIZE_OV	;

	CALL	DIR_SET			; ディレクトリィセット

	CALL	SCWINI		; 初期設定

	MOV	AX,DRVNO	;
	CALL	SCWDRV		; ドライブ番号の設定（０ー３）

	CALL	SAVE_IPL	; ＩＰＬセーブ
	CMP	AX,0		;
	JNE	SYSSET_ERROR	;

	CALL	SAVE_SYS	; システムセーブ
	CMP	AX,0		;
	JNE	SYSSET_ERROR	;

	CALL	SAVE_FAT	; ＦＡＴセーブ
	CMP	AX,0		;
	JNE	SYSSET_ERROR	;

	CALL	SAVE_ROOT	; ＲＯＯＴセーブ
	CMP	AX,0		;
	JNE	SYSSET_ERROR	;

	PRF	"システム転送成功しました"
	MOV	AX,0			; 0=正常
	RET
SYSSET_ERROR:
	PRF	"エラーのため終了します"
	MOV	AX,1			; 1=エラー
	RET
SYSSET_SYS_SIZE_OV:
	PRF	"システムサイズエラー"
	MOV	AX,1			; 1=エラー
	RET
SYSSET_IPL_SIZE_OV:
	PRF	"ＩＰＬサイズエラー"
	MOV	AX,1			; 1=エラー
	RET
SYSSET	ENDP


;	ＩＰＬのサイズチェック
;	-O- AX : 0=正常,1=サイズオバー

IPL_SIZE_CHECK	PROC	NEAR
	MOV	AX,OFFSET IPLEND	; ＩＰＬコードの終わり
	SUB	AX,OFFSET IPLTOP	; ＩＰＬコードの先頭
	INC	AX			; ＩＰＬコードのサイズです

	PRV	"ＩＰＬコードのサイズ＝",AX

	CMP	AX,SEC_BYTE		; セクタバイト数
	JNBE	IPL_SIZE_CHECK_ER

	MOV	AX,0		;0=正常
	RET
IPL_SIZE_CHECK_ER:
	MOV	AX,1		;1=サイズオバー
	RET
IPL_SIZE_CHECK	ENDP


;	システムのサイズチェック
;	-O- AX : 0=正常,1=サイズオバー

SYS_SIZE_CHECK	PROC	NEAR
	MOV	AX,OFFSET SYSEND	; システムコードの終わり
	SUB	AX,OFFSET SYSTOP	; システムコードの先頭
	INC	AX			; システムコードのサイズです

	PRV	"システムコードのサイズ＝",AX

	CMP	AX,SYSTEM_SIZE		; システムサイズの上限
	JNBE	SYS_SIZE_CHECK_ER

	MOV	AX,0		;0=正常
	RET
SYS_SIZE_CHECK_ER:
	MOV	AX,1		;1=サイズオバー
	RET
SYS_SIZE_CHECK	ENDP



;	ＩＰＬセーブ
;	-O- AX : 0=正常,1=エラー

SAVE_IPL	PROC	NEAR
	MOV	AX,REC_IPL		; ＩＰＬの先頭レコード
	CALL	SCWSET			; 論理レコード設定

	MOV	DX,SEG CODIPL		; ＩＰＬコードのセグメント
	MOV	BX,OFFSET IPLTOP	; ＩＰＬコードの先頭
	CALL	SCWSEQ			; セクター順次書き込み
	CMP	AX,0	; 0=正常,1=エラー,2=最後のセクタに書き込んだ
	JNE	SAVE_IPL_ERROR

	MOV	AX,0			;0=正常
	RET
SAVE_IPL_ERROR:
	PRF	"ＩＰＬ書き込みエラー"
	MOV	AX,1			; 1=エラー
	RET
SAVE_IPL	ENDP



;	システムセーブ
;	-I/O- FAT_SEC_TOP : ＦＡＴを書きます
;	-O- AX : 0=正常,1=エラー

SAVE_SYS	PROC	NEAR
	MOV	AX,REC_CLAST		; クラスタの先頭レコード
	CALL	SCWSET			; 論理レコード設定

	MOV	AX,CLAST_TOP		; 先頭クラスタ番号
	MOV	PNTNXT,AX		; 続きのクラスタ番号

	MOV	AX,OFFSET SYSTOP	; システムコードの先頭
	MOV	NOWOFFSET,AX		; 書き込みポインタ
SAVE_SYS_LOOP:
	MOV	AX,PNTNXT		; 続きのクラスタ番号
	MOV	PNTNOW,AX		; 現在のクラスタ番号
	INC	PNTNXT			; 続きのクラスタ番号更新
	CALL	FATSET			; ＦＡＴにクラスタ番号をセット

	MOV	DX,SEG CODSYS		; システムコードのセグメント
	MOV	BX,NOWOFFSET		; 書き込みポインタ
	CALL	SCWSEQ			; セクター順次書き込み

	CMP	AX,0	; 0=正常,1=エラー,2=最後のセクタに書き込んだ
	JNE	SAVE_SYS_ERROR

	ADD	NOWOFFSET,SEC_BYTE	; 次のオフセットへ

	MOV	AX,NOWOFFSET		;
	CMP	AX,OFFSET SYSEND	; システムコードの終わり
	JBE	SAVE_SYS_LOOP		; ループエンド

	MOV	PNTNXT,END_SEC_MARK	; 最後のセクタマーク
	CALL	FATSET			; ＦＡＴにクラスタ番号をセット

	MOV	AX,0			; 0=正常
	RET
SAVE_SYS_ERROR:
	PRF	"システム書き込みエラー"
	MOV	AX,1			; 1=エラー
	RET
SAVE_SYS	ENDP



;	ＦＡＴセーブ
;	-I- FAT_SEC_TOP : 先頭のＦＡＴ
;	    FAT_SEC2    : ２セクタ目のＦＡＴ
;	    FAT_SEC3    : ３セクタ目のＦＡＴ
;	    FAT_SEC4    : ４セクタ目のＦＡＴ
;	-O- AX : 0=正常,1=エラー

SAVE_FAT	PROC	NEAR
	MOV	AX,REC_FAT		; ＦＡＴの先頭レコード
	CALL	SCWSET			; 論理レコード設定

	MOV	DX,SEG DATA		; ＦＡＴのセグメント
	MOV	BX,OFFSET FAT_SEC_TOP	; ＦＡＴのオフセット１
	CALL	SCWSEQ			; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_FAT_ERROR

	MOV	DX,SEG DATA		; ＦＡＴのセグメント
	MOV	BX,OFFSET FAT_SEC2	; ＦＡＴのオフセット２
	CALL	SCWSEQ			; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_FAT_ERROR

	MOV	DX,SEG DATA		; ＦＡＴのセグメント
	MOV	BX,OFFSET FAT_SEC3	; ＦＡＴのオフセット３
	CALL	SCWSEQ			; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_FAT_ERROR

	MOV	DX,SEG DATA		; ＦＡＴのセグメント
	MOV	BX,OFFSET FAT_SEC4	; ＦＡＴのオフセット４
	CALL	SCWSEQ			; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_FAT_ERROR

	MOV	AX,0			; 0=正常
	RET
SAVE_FAT_ERROR:
	PRF	"ＦＡＴ書き込みエラー"
	MOV	AX,1			; 1=エラー
	RET
SAVE_FAT	ENDP



;	ＲＯＯＴセーブ
;	-I- FDIR_SYS_ENTRY : 先頭ディレクトリィセット
;	    FDIR_FULL_SET  : そのほかのディレクトリィセット
;	-O- AX : 0=正常,1=エラー

SAVE_ROOT	PROC	NEAR
	MOV	AX,REC_ROOT		; ＲＯＯＴの先頭レコード
	CALL	SCWSET			; 論理レコード設定

	MOV	DX,SEG DATA		 ; セグメント
	MOV	BX,OFFSET FDIR_SYS_ENTRY ; 先頭ディレクトリィセット１
	CALL	SCWSEQ			 ; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_ROOT_ERROR

	MOV	DX,SEG DATA		 ; セグメント
	MOV	BX,OFFSET FDIR_FULL_SET  ; そのほかのディレクトリィ２
	CALL	SCWSEQ			 ; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_ROOT_ERROR

	MOV	DX,SEG DATA		 ; セグメント
	MOV	BX,OFFSET FDIR_FULL_SET  ; そのほかのディレクトリィ３
	CALL	SCWSEQ			 ; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_ROOT_ERROR

	MOV	DX,SEG DATA		 ; セグメント
	MOV	BX,OFFSET FDIR_FULL_SET  ; そのほかのディレクトリィ４
	CALL	SCWSEQ			 ; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_ROOT_ERROR

	MOV	DX,SEG DATA		 ; セグメント
	MOV	BX,OFFSET FDIR_FULL_SET  ; そのほかのディレクトリィ５
	CALL	SCWSEQ			 ; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_ROOT_ERROR

	MOV	DX,SEG DATA		 ; セグメント
	MOV	BX,OFFSET FDIR_FULL_SET  ; そのほかのディレクトリィ６
	CALL	SCWSEQ			 ; セクター順次書き込み
	CMP	AX,0
	JNE	SAVE_ROOT_ERROR

	MOV	AX,0			; 0=正常
	RET
SAVE_ROOT_ERROR:
	PRF	"ＲＯＯＴ書き込みエラー"
	MOV	AX,1			; 1=エラー
	RET
SAVE_ROOT	ENDP



;	ＦＡＴにクラスタ番号をセットする
;	-I- PNTNOW : 現在のクラスタ番号
;	    PNTNXT : 続きのクラスタ番号

FATSET	PROC	NEAR
	MOV	AX,PNTNOW	; 現在のクラスタ番号
	SHR	AX,1		; /2
	MOV	SI,AX		; ＦＡＴテーブルのアドレスポインタ
	ADD	SI,AX		;
	ADD	SI,AX		; ( *3 )

	MOV	AX,PNTNOW	; 現在のクラスタ番号
	SHR	AX,1		; 奇数か偶数かの判定
	JB	FATSET2		;

				; 偶数の場合
	MOV	AX,PNTNXT	; 続きのクラスタ番号
	AND	WORD PTR FAT_SEC_TOP[SI],0F000H ; 3 nible
	OR	WORD PTR FAT_SEC_TOP[SI],AX	; 3 nible
	RET
FATSET2:			; 奇数の場合
	MOV	AX,PNTNXT	; 続きのクラスタ番号
	SHL	AX,1		;
	SHL	AX,1		; 1 nible shift.
	SHL	AX,1		;
	SHL	AX,1		;
	
	AND	WORD PTR FAT_SEC_TOP[SI+1],000FH ; 3 nible
	OR	WORD PTR FAT_SEC_TOP[SI+1],AX	; 3 nible
	RET
FATSET	ENDP


;	ディレクトリィセット

DIR_SET	PROC	NEAR
	MOV	AX,OFFSET SYSEND	; システムコードの終わり
	SUB	AX,OFFSET SYSTOP	; システムコードの先頭
	INC	AX			; システムコードのサイズです
	MOV	WORD PTR FSIZE,AX	; ファイルサイズ
	RET
DIR_SET	ENDP

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'
	EVEN
FDIR_SYS_ENTRY	LABEL	BYTE	; 先頭ディレクトリィセット
FNAME	DB	"EXELOAD "	; ファイル名
FTYPE	DB	"SYS"		; ファイルタイプ
FATR	DB	0		; ファイル属性
FSYS	DB	10 DUP (0)	; システム予約
FTIME	DW	0380H		; ファイル更新時刻  00:28:00
FDATE	DW	1A21H		; ファイル更新年月日 1993-01-01
FCLST	DW	CLAST_TOP	; ファイルの最初のクラスタ番号
FSIZE	DD	0		; ファイルサイズ
FDIR_FULL_SET	LABEL	BYTE	; そのほかのディレクトリィセット
FSET01	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET02	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET03	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET04	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET05	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET06	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET07	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET08	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET09	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET10	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET11	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET12	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET13	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET14	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET15	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET16	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET17	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET18	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET19	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET20	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET21	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET22	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET23	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET24	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET25	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET26	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET27	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET28	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET29	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET30	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET31	DB	0,"EXELOAD","NON",0,20 DUP (0)
FSET32	DB	0,"EXELOAD","NON",0,20 DUP (0)

FAT_SEC_TOP	LABEL	BYTE
	DB	0FEH,0FFH,0FFH
	DB	SEC_BYTE-3	DUP (0)
FAT_SEC2	LABEL	BYTE
	DB	SEC_BYTE	DUP (0)
FAT_SEC3	LABEL	BYTE
	DB	SEC_BYTE	DUP (0)
FAT_SEC4	LABEL	BYTE
	DB	SEC_BYTE	DUP (0)


NOWOFFSET	DW	0	; 書き込みポインタ

PNTNOW		DW	0	; 現在のクラスタ番号
PNTNXT		DW	0	; 続きのクラスタ番号

DRVNO		DW	0	; ドライブ番号

DATA	ENDS

	END
;
;	end of "SYSSET.ASM"
;
