; "SSDIR.ASM" PC-9801UV11 make by R.H 1989/11/17
;
;	E X E L O A D    D I R   c o m m a n d .
;
;
;
; command.


;	ディレクトリィ表示、５’２ＨＤ用

INCLUDE	TSTSET.INC

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	CMDIR			; ＤＩＲ
PUBLIC	CMFAT			; ＦＡＴダンプ

EXTRN	SSRDIR:NEAR		; ＦＡＴ＋ＲＯＯＴの読み出し
EXTRN	SSDSKF:NEAR		; ディスクの空きクラスタ数


; ５’２ＨＤの場合です

;READWT.ASMもなおせ
;ＤＫＦＯＲＭ．ＡＳＭもなおせ
;ｌｉｎｋｅｎｄ．ＡＳＭもなおせ
;SSDIR.ASMのDIRMAXもなおせ
DIRMAX	EQU	32	; ディレクトリィ最大数
;;;;DIRMAX		EQU	192	; ディレクトリィ最大数

MIN_CLAST	EQU	2		; 最小クラスタ番号
MAX_CLAST	EQU	8*2*77-10	; 最大クラスタ番号

CLST_LENGTH	EQU	1024	; クラスタのバイト数

ENDDIR		EQU	0	; ディレクトリィの終わり


;	ＤＩＲ
;	-O- AX    : 0=正常, 2=ディスクエラー

CMDIR	PROC	NEAR
	CALL	SSRDIR		; ＦＡＴ＋ＲＯＯＴの読み出し

	CMP	AX,0
	JMPEQ	CMDIR3
	PRF	"ディスクがセットされていません"
	MOV	AX,2
	RET
CMDIR3:
	CALL	DIRLST		; ディレクトリィ表示
	RET
CMDIR	ENDP


;	ＦＡＴダンプ
;	-O- AX    : 0=正常, 2=ディスクエラー

CMFAT	PROC	NEAR
	CALL	SSRDIR		; ＦＡＴ＋ＲＯＯＴの読み出し

	CMP	AX,0
	JMPEQ	CMFAT3
	PRF	"ディスクがセットされていません"
	MOV	AX,2
	RET
CMFAT3:
	CALL	FATLIST		; ＦＡＴリスト
	RET
CMFAT	ENDP


;
;	ディレクトリィリスト
;

DIRLST	PROC	NEAR
	PRF "/.no../filename/typ/at/time/date/clst/.size.../"

	MOV	NUM,0			; 通し番号

	MOV	BX,ADRSROOTDIR		; ROOT ＲＯＯＴアドレス
	MOV	CX,DIRMAX		; ディレクトリィ最大数
DIRLST2:
	CMP	BYTE PTR DS:[BX],ENDDIR	; ディレクトリィの終わり
	JMPEQ	DIRLST9

	CALL	DIRDSP			; ディレクトリィ表示

	CALL	KESCAP		; ESC key & break check & pause.
	CMP	AX,1
	JMPEQ	DIRLST_ESC
	CMP	AX,2
	JMPEQ	DIRLST_BREAK
	CMP	AX,0
	JNE	DIRLST_EXIT


	LOOP	DIRLST2
DIRLST9:

	CALL	DSKFREE			; ディスクの空き容量
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	DIRLST_END		;

	PUSH	CX			;
	PUSH	BX			;
	MOV	DX,BX			;
	CALL	HEXSTR			;
	CALL	PRINT			;
	MOV	DX,CX			;
	CALL	HEXSTR			;
	CALL	PRINT			;
	PR	"h / "			;
	POP	BX			;
	POP	CX			;


	MOV	AX,CX			; ファイルサイズ（下位ワード）
	MOV	DX,BX			; ファイルサイズ（上位ワード）
	CALL	D10STR			; i*4 value -> decimal string.
	CALL	PRINT			; print.
	PRF	" バイトの空きエリアがあります"

DIRLST_END:
	RET
DIRLST_EXIT:
	PRF	"[EXIT...]"
	RET
DIRLST_ESC:
	PRF	"[ESC]"
	RET
DIRLST_BREAK:
	PRF	"[break]"
	RET
DIRLST	ENDP



;
;	ディレクトリィ表示
;
;	-I- DS:BX : ディレクトリィアドレス
;		（ＢＸ：処理後ポインタ更新します）

DIRDSP	PROC	NEAR
	PUSH	CX

	PR	"."

	MOV	DX,NUM		;
	CALL	DECSTR		;
	CALL	PRINT		;

	PR	"."

	MOV	AH,DS:[BX]	; ファイル名
	CMP	AH,0E5H		; Ｅ５ｈはファイル削除のマーク
	JNE	DIRDSP11	;
	PR	"<del>"		;
	JMP	DIRDSP12	;
DIRDSP11:			;
	PRCH			;
DIRDSP12:			;
	INC	BX		;

	MOV	CX,7		;
DIRDSP2:			;
	MOV	AH,DS:[BX]	;
	PRCH			;
	INC	BX		;
	LOOP	DIRDSP2		;

	PR	"."

	MOV	CX,3		;
DIRDSP3:			; 拡張子
	MOV	AH,DS:[BX]	; 
	PRCH			;
	INC	BX		;
	LOOP	DIRDSP3		;

	PR	","

	MOV	AH,DS:[BX]	;
	CALL	PRNAH		; ファイル属性
	INC	BX		;

	PR	","

	ADD	BX,10		; システム予約なのでスキップ

	MOV	CX,2		;
DIRDSP4:			; ファイル更新時刻
	MOV	AH,DS:[BX]	; 
	CALL	PRNAH		;
	INC	BX		;
	LOOP	DIRDSP4		;

	PR	","

	MOV	CX,2		;
DIRDSP5:			; ファイル更新年月日
	MOV	AH,DS:[BX]	; 
	CALL	PRNAH		;
	INC	BX		;
	LOOP	DIRDSP5		;

	PR	","

	MOV	DX,DS:[BX]	; ファイルの最初のクラスタ番号
	CALL	HEXSTR		;
	CALL	PRINT		;
	INC	BX		;
	INC	BX		;

	PR	","


	MOV	DX,DS:[BX+2]	; ファイルサイズ
	CALL	HEXSTR		;
	CALL	PRINT		;
	MOV	DX,DS:[BX]	;
	CALL	HEXSTR		;
	CALL	PRINT		;
	ADD	BX,4		;

	LF

	POP	CX

	INC	NUM		; 通し番号

	RET
DIRDSP	ENDP


;	ディスクの空き容量
;	-O- CX  : ファイルサイズ（下位ワード）
;	    BX  : ファイルサイズ（上位ワード）
;	    AX  : 0=正常, 2=ディスクエラー

DSKFREE	PROC	NEAR
	CALL	SSDSKF			; ディスクの空きクラスタ数
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	DSKFREE_ERROR		;

	MOV	AX,DX			; 空きクラスタ数
	MOV	DX,0			;
	MOV	BX,CLST_LENGTH		; クラスタのバイト数
	MUL	BX			;
	MOV	BX,DX			; ファイルサイズ（上位ワード）
	MOV	CX,AX			; ファイルサイズ（下位ワード）

	MOV	AX,0			; 0=正常
	RET
DSKFREE_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	RET
DSKFREE	ENDP




;	ＦＡＴリスト

FATLIST	PROC	NEAR
	MOV	PNTNOW,0		; =0

FATLIST_LOOP:
	CALL	NXTNUM			; 次のクラスタ番号を取り出す

	MOV	DX,PNTNXT		; 続きのクラスタ番号
	CALL	HEXSTR			;
	INC	SI			;
	CALL	PRINT			;
	PR	" "			;

	INC	PNTNOW			; 現在のクラスタ番号

	CALL	KESCAP			; ESC key & break check & pause.
	CMP	AX,0			;
	JNE	FATLIST_EXIT		;

	CMP	PNTNOW,MAX_CLAST	; 最大クラスタ番号
	JBE	FATLIST_LOOP		;

FATLIST_EXIT:				;
	LF
	RET
FATLIST	ENDP


;	次のクラスタ番号を取り出す
;	-I- PNTNOW : 現在のクラスタ番号
;	-O- PNTNXT : 続きのクラスタ番号

NXTNUM	PROC	NEAR
	MOV	AX,PNTNOW		; 現在のクラスタ番号
	SHR	AX,1			; / 2
	MOV	SI,AX			; ＦＡＴテーブルのアドレスポインタ
	ADD	SI,AX			;
	ADD	SI,AX			; ( * 3 )
	ADD	SI,ADRSFAT		; ROOT ＦＡＴアドレス

	MOV	AX,PNTNOW		; 現在のクラスタ番号
	SHR	AX,1			; 奇数か偶数かの判定
	JB	NXTNUM2			;

					; 偶数の場合
	MOV	AX,WORD PTR DS:[SI]	;
	AND	AX,0FFFH		; 3 nible.
	MOV	PNTNXT,AX		; 続きのクラスタ番号
	RET				;

NXTNUM2:				; 奇数の場合
	MOV	AX,WORD PTR DS:[SI+1]
	SHR	AX,1			;
	SHR	AX,1			; 1 nible shift.
	SHR	AX,1			;
	SHR	AX,1			;
	MOV	PNTNXT,AX		; 続きのクラスタ番号
	RET
NXTNUM	ENDP

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

EXTRN	ADRSFAT:WORD		; ROOT ＦＡＴアドレス
EXTRN	ADRSROOTDIR:WORD	; ROOT ＲＯＯＴアドレス

NUM		DW	0	; counter.

PNTNOW		DW	0	; 現在のクラスタ番号
PNTNXT		DW	0	; 続きのクラスタ番号

DATA	ENDS

	END
;
;	end of "SSDIR.ASM"
;
