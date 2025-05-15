; "DOSWRT.ASM" PC-9801UV11 make by R.H 1990/09/27
;
;	E X E L O A D    D i s k / w r i t e   l i b r a l y .
;
;	カレントドライブは DOSIO.ASM で管理される
;
;		DOSIO.ASM FFDRV(カレントドライブ設定)
;		public FLCURT: カレントドライブ
;
;	ファイルＯＰＥＮ中は次のルーチンはＣＡＬＬしないこと。
;
;		FWKILL(ファイルの削除)
;		FWFREE(ディスクの空き容量)
;		FWREST(ディスクのリセット)
;
;
; public subroutine.

INCLUDE	TSTSET.INC

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:DATA

PUBLIC	FWOPEN			; ファイルの書き込み開始
PUBLIC	FWCLOS			; ファイルの書き込み終了
PUBLIC	FWRITE			; ファイルの書き込み

PUBLIC	FWKILL			; ファイルの削除

PUBLIC	FWFREE			; ディスクの空き容量
PUBLIC	FWREST			; ディスクのリセット

EXTRN	SSWCSR:NEAR		; クラスタ順次書き込み開始
EXTRN	SSWPLN:NEAR		; クラスタ順次書き込み数設定
EXTRN	SSWWTS:NEAR		; クラスタ順次書き込み
EXTRN	SSWCED:NEAR		; クラスタ順次書き込み終了

EXTRN	SSRDRV:NEAR		; ドライブ番号の設定（０ー３）
EXTRN	SSRDNO:NEAR		; ドライブ番号の取得（０ー３）
EXTRN	SSRRST:NEAR		; ドライブのリセット

EXTRN	SSWENT:NEAR		; ディレクトリ・エントリの取得
EXTRN	SSWSET:NEAR		; エントリ・データの書き込み

EXTRN	SSKILL:NEAR		; ファイルの削除

EXTRN	SSDSKF:NEAR		; ディスクの空きクラスタ数
EXTRN	SSDSKS:NEAR		; ドライブ情報

FLALLLEN	EQU	32	; 指定ファイル名最大長さ

OFF_CLAST	EQU	0	; 先頭のクラスタは書き込まれていない
CLST_LENGTH	EQU	1024	; クラスタのバイト数


;	ファイルの書き込み開始
;	-I- DS:SI : ファイル名
;	-O- AX    : 0=正常, 1=ディレクトリに空きがない, 2=ディスクエラー

FWOPEN	PROC	NEAR
	PUSH	SI			;

	MOV	FLAG_WRTSTART,0		; フラグ・書き込みスタート=1

	CALL	PATH_GET		; パス名／ファイル名ＧＥＴ

	MOV	AX,FLDRIVE		; ドライブ番号
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	CMP	AX,0			; 0=正常,1=番号エラ,2=ディスクエラ
	JNE	FWOPEN_DISK_ERROR	;

	MOV	SI,OFFSET FLNAME	; 指定ファイル名
	CALL	SSKILL			; ファイルの削除
	CMP	AX,2			; 2=ディスクエラー
	JE	FWOPEN_DISK_ERROR

	MOV	SI,OFFSET FLNAME	; 指定ファイル名
	CALL	SSWENT			; ディレクトリ・エントリの取得
	CMP	AX,1			; 1=ディレクトリに空きがない
	JE	FWOPEN_DIR_EMPTY	;
	CMP	AX,2			; 2=ディスクエラー
	JE	FWOPEN_DISK_ERROR	;

	MOV	DIR_ENTRY_ID,DX		; ディレクトリ・エントリＩＤ

	MOV	CLSTCOUNT,0		; クラスタバッファ内のデータバイト数
	MOV	SRTCLST,0		; ファイルの最初のクラスタ
	MOV	FILE_LEN_LOW,0		; ファイルの長さ
	MOV	FILE_LEN_HI,0		; (long integer)

	CALL	CLSTCLAER		; クラスタバッファ０クリア

	MOV	AX,0			; 0=正常
	POP	SI			;
	RET				;
FWOPEN_DIR_EMPTY:
	MOV	AX,1			; 1=ディレクトリに空きがない
	POP	SI			;
	RET				;
FWOPEN_DISK_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	POP	SI			;
	RET
FWOPEN	ENDP



;	ファイルの書き込み終了
;	-O- AX  : 0=正常, 1=ディスクに空き無し, 2=ディスクエラー

FWCLOS	PROC	NEAR
	MOV	AX,FLDRIVE		; ドライブ番号
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	CMP	AX,0			; 0=正常,1=番号エラ,2=ディスクエラ
	JNE	FWCLOS_DISK_ERROR	;

	CMP	CLSTCOUNT,0		; クラスタバッファ内のデータバイト数
	JE	FWCLOS_EOF		;

	CALL	FWR_CLST		; クラスタバッファの書き込み
	CMP	AX,4			; 4=空きエリアが無い
	JE	FWCLOS_FULL		;
	CMP	AX,2			; 2=ディスクエラー
	JE	FWCLOS_DISK_ERROR	;
FWCLOS_EOF:
	CALL	SSWCED			; クラスタ順次書き込み終了

	MOV	DX,SRTCLST		; ファイルの最初のクラスタ
	MOV	CX,FILE_LEN_LOW		; ファイルの長さ（下位ワード）
	MOV	BX,FILE_LEN_HI		; (long integer)（上位ワード）
	MOV	AX,DIR_ENTRY_ID		; ディレクトリ・エントリＩＤ

	CALL	SSWSET			; エントリ・データの書き込み
	CMP	AX,2			; 2=ディスクエラー
	JE	FWCLOS_DISK_ERROR	;

	MOV	AX,0			; 0=正常
	RET				;
FWCLOS_FULL:
	MOV	AX,1			; 1=ディスクに空き無し
	RET				;
FWCLOS_DISK_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	RET				;
FWCLOS	ENDP



;	ファイルの書き込み
;	-I- DX:[SI]  : データ
;	    CX       : 書き込みデータのバイト数
;	-O- AX       : 0=正常, 1=ディスクに空き無し, 2=ディスクエラー

FWRITE	PROC	NEAR
	PUSH	DX			;
	PUSH	SI			;

	MOV	WRTSEG,DX		; 書き込みデータセグメント
	MOV	WRTPOINT,SI		; 書き込みデータポインタ
	MOV	WRTCOUNT,CX		; 書き込みバイト数

	CMP	WRTCOUNT,0		; 書き込みバイト数
	JMPEQ	FWRITE_EXIT		;

	MOV	AX,WRTCOUNT		; 書き込みバイト数
	ADD	FILE_LEN_LOW,AX		; ファイルの長さ（下位ワード）
	ADC	FILE_LEN_HI,0		; (long integer)（上位ワード）

	CMP	FLAG_WRTSTART,1		; フラグ・書き込みスタート=1
	JE	FWRITE_2NDWRT		;

FWRITE_1STWRT:
	CALL	SSWCSR			; クラスタ順次書き込み開始

	CALL	WRITEPLAN		; 書き込み計画
	CMP	AX,4			; 4=空きが無い
	JMPEQ	FWRITE_FULL		;
	CMP	AX,5			; 5=指定クラスタ数が０
	JMPEQ	FWRITE_EXIT		;

	MOV	SRTCLST,DX		; ファイルの最初のクラスタ
	MOV	FLAG_WRTSTART,1		; フラグ・書き込みスタート=1
	JMP	FWRITE_LOOP		;

FWRITE_2NDWRT:
	MOV	AX,CLST_LENGTH		; クラスタのバイト数
	SUB	AX,CLSTCOUNT		; クラスタバッファ内のデータバイト数
	CMP	WRTCOUNT,AX		; 書き込みバイト数
	JMPBE	FWRITE_MOV_ONLY		;

	MOV	DX,WRTSEG		; 書き込みデータセグメント
	MOV	SI,WRTPOINT		; 書き込みデータポインタ
	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,OFFSET CLST_BUFF_W	; クラスタバッファ
	ADD	DI,CLSTCOUNT		; クラスタバッファ内のデータバイト数
	MOV	CX,CLST_LENGTH		; クラスタのバイト数
	SUB	CX,CLSTCOUNT		; －クラスタバッファ内のデータバイト数
	PUSH	DS			;
	MOV	DS,DX			;
	REP	MOVSB			; copy.
	POP	DS			;

	MOV	AX,CLST_LENGTH		; クラスタのバイト数
	SUB	AX,CLSTCOUNT		; －クラスタバッファ内のデータバイト数
	SUB	WRTCOUNT,AX		; 書き込みバイト数
	ADD	WRTPOINT,AX		; 書き込みデータポインタ

	MOV	CLSTCOUNT,0		; クラスタバッファ内のデータバイト数

	CALL	FWR_CLST		; クラスタバッファの書き込み
	CMP	AX,4			; 4=空きエリアが無い
	JMPEQ	FWRITE_FULL		;
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	FWRITE_ERROR		;
	CMP	AX,3			; 3=書き込み計画終了
	JE	FWRITE_2NDPLN		;

FWRITE_2NDPLN:
	CALL	WRITEPLAN		; 書き込み計画
	CMP	AX,4			; 4=空きが無い
	JE	FWRITE_FULL		;
	CMP	AX,5			; 5=指定クラスタ数が０
	JE	FWRITE_EXIT		;

FWRITE_LOOP:
	MOV	AX,CLST_LENGTH		; クラスタのバイト数
	CMP	WRTCOUNT,AX		; 書き込みバイト数
	JBE	FWRITE_LOOP_E		;

	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,OFFSET CLST_BUFF_W	; クラスタバッファ
	MOV	DX,WRTSEG		; 書き込みデータセグメント
	MOV	SI,WRTPOINT		; 書き込みデータポインタ
	MOV	CX,CLST_LENGTH		; クラスタのバイト数
	PUSH	DS			;
	MOV	DS,DX			;
	REP	MOVSB			; copy.
	POP	DS			;

	MOV	AX,CLST_LENGTH		; クラスタのバイト数
	SUB	WRTCOUNT,AX		; 書き込みバイト数
	ADD	WRTPOINT,AX		; 書き込みデータポインタ

	CALL	FWR_CLST		; クラスタバッファの書き込み
	CMP	AX,4			; 4=空きエリアが無い
	JE	FWRITE_FULL		;
	CMP	AX,2			; 2=ディスクエラー
	JE	FWRITE_ERROR		;
	CMP	AX,3			; 3=書き込み計画終了
	JE	FWRITE_EXIT		;

	JMP	FWRITE_LOOP		;

FWRITE_LOOP_E:				;

FWRITE_MOV_ONLY:			;
	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,OFFSET CLST_BUFF_W	; クラスタバッファ
	ADD	DI,CLSTCOUNT		; クラスタバッファ内のデータバイト数
	MOV	DX,WRTSEG		; 書き込みデータセグメント
	MOV	SI,WRTPOINT		; 書き込みデータポインタ
	MOV	CX,WRTCOUNT		; 書き込みバイト数
	JCXZ	FWRITE_77		;
	PUSH	DS			;
	MOV	DS,DX			;
	REP	MOVSB			; copy.
	POP	DS			;
FWRITE_77:
	MOV	AX,WRTCOUNT		; 書き込みバイト数
	ADD	CLSTCOUNT,AX		; クラスタバッファ内のデータバイト数

FWRITE_EXIT:
	MOV	AX,0			; 0=正常
	POP	SI			;
	POP	DX			;
	RET				;
FWRITE_FULL:
	MOV	AX,1			; 1=ディスクに空き無し
	POP	SI			;
	POP	DX			;
	RET				;
FWRITE_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	POP	SI			;
	POP	DX			;
	RET				;
FWRITE	ENDP


;	書き込み計画
;	-I- WRTCOUNT : 書き込みバイト数
;	-O- AX       : 0=正常,4=空きが無い,5=指定クラスタ数が０
;	    DX       : 開始クラスタ番号

WRITEPLAN	PROC	NEAR
	MOV	AX,WRTCOUNT		; 書き込みバイト数
	XOR	DX,DX			; DX=0
	MOV	BX,CLST_LENGTH		; ÷クラスタのバイト数
	DIV	BX			;
	CMP	DX,0			; 余り
	JE	WRITEPLAN_5		;
	INC	AX			;
WRITEPLAN_5:				; AX=クラスタ数
	MOV	CX,AX			; 読み出し開始クラスタ数
	CALL	SSWPLN			; クラスタ順次書き込み数設定
	RET
WRITEPLAN	ENDP


;	ファイルの削除
;	-I- DS:SI : ファイル名
;	-O- AX    : 0=正常, 1=該当ファイルがない, 2=ディスクエラー

FWKILL	PROC	NEAR
	PUSH	SI

	CALL	PATH_GET		; パス名／ファイル名ＧＥＴ

	MOV	AX,FLDRIVE		; ドライブ番号
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	CMP	AX,0			; 0=正常,1=番号エラ,2=ディスクエラ
	JNE	FWKILL_EXIT		;

	MOV	SI,OFFSET FLNAME	; 指定ファイル名
	CALL	SSKILL			; ファイルの削除

FWKILL_EXIT:
	POP	SI
	RET
FWKILL_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	POP	SI
	RET
FWKILL	ENDP


;	ディスクの空き容量
;	-I- DX : 0=カレントドライブ,1=A:,2=B:...
;	-O- DI : セクタ数／１クラスタ
;	    BX : 空きクラスタ数
;	    CX : バイト数／１セクタ
;	    DX : クラスタ数／１ドライブ
;	    AX : 0=正常, 2=エラー

FWFREE	PROC	NEAR
	PUSH	DX
	CALL	SSRDNO			; ドライブ番号の取得（０ー３）
	MOV	SAVE_DRIVE_NO,AX	; ドライブ番号の退避
	POP	DX

	MOV	INFO_DRIVE,DX		; ドライブ情報のドライブ番号
	DEC	INFO_DRIVE		;

	CMP	DX,0			; 0=カレントドライブ,1=A:,2=B:...
	JNE	FWFREE_SET		;
	MOV	DX,FLCURT		; カレントドライブ
	MOV	INFO_DRIVE,DX		; ドライブ情報のドライブ番号
FWFREE_SET:
	MOV	AX,INFO_DRIVE		; ドライブ情報のドライブ番号
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	CMP	AX,0			; 0=正常,1=番号エラ,2=ディスクエラ
	JMPNE	FWFREE_ERROR		;

	CALL	SSDSKS			; ドライブ情報
	CMP	AX,2			; 2=ディスクエラー
	JE	FWFREE_ERROR		;

	MOV	DI,DS:[SI]		; [ セクタ数／１クラスタ   ]
	MOV	BX,DS:[SI][2]		; [ 空きクラスタ数         ]
	MOV	CX,DS:[SI][4]		; [ バイト数／１セクタ     ]
	MOV	DX,DS:[SI][6]		; [ クラスタ数／１ドライブ ]

	MOV	AX,0			; 0=正常
	JMP	FWFREE_EXIT		;
FWFREE_ERROR:
	MOV	DI,0
	MOV	BX,0
	MOV	CX,0
	MOV	DX,0
	MOV	AX,2			; 2=ディスクエラー
FWFREE_EXIT:
	PUSH	AX
	MOV	AX,SAVE_DRIVE_NO	; ドライブ番号の退避
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	POP	AX
	RET
FWFREE	ENDP


;	ディスクのリセット

FWREST	PROC	NEAR
	MOV	RESET_DRIVE,0		; リセットのドライブ番号
FWREST_LOOP:
	MOV	AX,RESET_DRIVE		; リセットのドライブ番号
	CALL	SSRRST			; ドライブのリセット
	CMP	AX,1			; 1=ドライブ番号エラー
	JE	FWREST_EXIT		;

	INC	RESET_DRIVE		; リセットのドライブ番号
	JMP	FWREST_LOOP		;
FWREST_EXIT:
	RET
FWREST	ENDP


;	クラスタバッファの書き込み
;	-I-   CLST_BUFF_W	: クラスタバッファ
;	-O-   AX        : 0=正常, 2=ディスクエラー, 3=書き込み計画終了
;			  4=空きエリアが無い

FWR_CLST	PROC	NEAR
	MOV	AX,FLDRIVE		; ドライブ番号
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	CMP	AX,0			; 0=正常,1=番号エラ,2=ディスクエラ
	JNE	FWR_CLST_ERROR_DISK	;

	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,OFFSET CLST_BUFF_W	; クラスタバッファ
	CALL	SSWWTS			; クラスタ順次書き込み

	CALL	CLSTCLAER		; クラスタバッファ０クリア
	RET				;
FWR_CLST_ERROR_DISK:
	MOV	AX,2			; 2=ディスクエラー
	RET
FWR_CLST	ENDP


;	クラスタバッファ０クリア

CLSTCLAER	PROC	NEAR
	PUSH	ES
	PUSH	DI
	PUSH	CX
	PUSH	AX

	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,OFFSET CLST_BUFF_W	; クラスタバッファ
	MOV	CX,CLST_LENGTH		; クラスタのバイト数
	MOV	AL,0			;
	REP	STOSB			;

	POP	AX
	POP	CX
	POP	DI
	POP	ES
	RET
CLSTCLAER	ENDP



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

EXTRN	FLCURT:WORD			; カレントドライブ

EXTRN	CLST_BUFF_W:BYTE		; クラスタバッファ
;*;CLST_BUFF_W	DB	CLST_LENGTH DUP (0)	; クラスタバッファ

		EVEN
DIR_ENTRY_ID	DW	0	; ディレクトリ・エントリＩＤ

SRTCLST		DW	0	; ファイルの最初のクラスタ

WRTCOUNT	DW	0	; 書き込みバイト数
WRTPOINT	DW	0	; 書き込みデータポインタ
WRTSEG		DW	0	; 書き込みデータセグメント
CLSTCOUNT	DW	0	; クラスタバッファ内のデータバイト数

FLAG_WRTSTART	DW	0	; フラグ・書き込みスタート=1

FILE_LEN_LOW	DW	0	; ファイルの長さ
FILE_LEN_HI	DW	0	; (long integer)

FLDRIVE		DW	0			; ドライブ番号
FLPATH		DB	"  ",0,0		; パス名

FLNAME		DB	FLALLLEN DUP (' ')	; 指定ファイル名
		DB	0,0			;

INFO_DRIVE	DW	0	; ドライブ情報のドライブ番号
RESET_DRIVE	DW	0	; リセットのドライブ番号
SAVE_DRIVE_NO	DW	0	; ドライブ番号の退避

DATA	ENDS
	END
;
;	end of "DOSWRT.ASM"
;
