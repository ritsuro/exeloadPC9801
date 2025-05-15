; "DKFROM.ASM" PC-9801UV11 make by R.H 1990/10/01
;
;	E X E L O A D    D I S K    F o r m a t   c a l l .
;
;
;
; public subroutine.


INCLUDE	TSTSET.INC

CHASHB	SEGMENT	PUBLIC	'CHASHB'
CHASHB	ENDS

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:CHASHB

PUBLIC	DKFORM			; ディスクのフォーマット
PUBLIC	DKFDNO			; フォーマットのドライブ番号の設定（０ー３）

EXTRN	SSRDRV:NEAR		; ドライブ番号の設定（０ー３）
EXTRN	SSRDNO:NEAR		; ドライブ番号の取得（０ー３）
EXTRN	SSRRST:NEAR		; ドライブのリセット

EXTRN	SSWDIR:NEAR		; ＦＡＴ＋ＲＯＯＴの書き込み


;	ディスクのフォーマット
;	-O- AX : 0=正常, 2=ディスクエラー
;	         3=デバイスがノットレディ, 4=ライトプロテクト

DKFORM	PROC	NEAR
	CALL	SSRRST			; ドライブのリセット

	CALL	PYSICAL_FORMAT		; 物理フォーマット
	CMP	AX,0			;
	JNE	DKFORM_EXIT		;

	CALL	SSRDNO			; ドライブ番号の取得（０ー３）
	MOV	SAVE_DNO,AX		; １ＭＦＤドライブ番号退避

	CALL	DNOGET			; ドライブ番号の取得
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）

	CALL	LOGICAL_FORMAT		; 論理フォーマット

	PUSH	AX			;
	MOV	AX,SAVE_DNO		; １ＭＦＤドライブ番号退避
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	POP	AX			;

DKFORM_EXIT:
	RET
DKFORM	ENDP


;	フォーマットのドライブ番号の設定（０ー３）
;	-I- AX : １ＭＦＤドライブ番号

DKFDNO	PROC	NEAR
	PUSH	AX
	CALL	DNOSET			; ドライブ番号の設定
	POP	AX
	RET
DKFDNO	ENDP



;	論理フォーマット
;	-O- AX : 0=正常, 2=ディスクエラー

LOGICAL_FORMAT	PROC	NEAR
	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,ADRSFAT		; ROOT ＦＡＴアドレス
	MOV	CX,FAT_CLAST		; 　ＦＡＴテーブルクラスタ数
	ADD	CX,ROOT_CLAST		; ＋ＲＯＯＴＤＩＲクラスタ数
	MOV	AX,LEN_CLAST		; ＊クラスタバイト数
	MUL	CX			;
	MOV	CX,AX			;
	MOV	AL,0			;
	REP	STOSB			; ０クリア

	MOV	DI,ADRSFAT		; ROOT ＦＡＴアドレス
	MOV	AX,FAT_ID_1		; ＦＡＴＩＤ
	STOSB				;
	MOV	AX,FAT_ID_2		;
	STOSB				;
	MOV	AX,FAT_ID_3		;
	STOSB				;

	CALL	SSWDIR			; ＦＡＴ＋ＲＯＯＴの書き込み
	RET
LOGICAL_FORMAT	ENDP


;	物理フォーマット
;	-O- AX : 0=正常, 2=ディスクエラー
;	         3=デバイスがノットレディ, 4=ライトプロテクト

PYSICAL_FORMAT	PROC	NEAR
	MOV	DCYL,0			; シリンダ番号（Ｃ）０ー７６
	MOV	DHEAD,0			; ヘッド番号（Ｈ）０ー１

PYSICAL_FORMAT_LOOP:
	PRV	"DCYL=",DCYL
	PRV	"DHEAD=",DHEAD

	CALL	FORMATTR		; トラックのフォーマット
	CMP	DERROR,1		; 1=エラー
	JE	PYSICAL_FORMAT_ERROR	;

	XOR	DHEAD,1			; ヘッド番号（Ｈ）０ー１
	CMP	DHEAD,0			;
	JNE	PYSICAL_FORMAT_NEXT	;
	INC	DCYL			; シリンダ番号（Ｃ）０ー７６
PYSICAL_FORMAT_NEXT:			;
	MOV	AX,DCYL			; シリンダ番号（Ｃ）０ー７６
	CMP	AX,MAX_CYLINDER		; 最大シリンダ数
	JNB	PYSICAL_FORMAT_EXIT	;
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


;	トラックのフォーマット
;	-I-   DCYL   : シリンダ番号（Ｃ）０ー７６
;	      DHEAD  : ヘッド番号（Ｈ）０ー１
;	-I/O- SEC_ID_BUF_ADRS   : セクタＩＤバッファのアドレス
;	      DERROR : 0=正常,1=エラー
;	      DSTAT  : ステータス情報

FORMATTR	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	CALL	ID_BUFF_SET		; ＩＤデータバッファセット

	MOV	AX,FORMAT_RETCNT	; ＦＯＲＭＡＴ・リトライ回数
	MOV	FORMAT_RETRY,AX		; ＦＯＲＭＡＴ・リトライカウンタ
FORMATTR_RETRY:
	MOV	AX,SEG CHASHB
	MOV	ES,AX
	MOV	BP,SEC_ID_BUF_ADRS	; セクタＩＤバッファのアドレス

	MOV	AL,BYTE PTR DUNIT	; デバイス識別・ユニット番号(DA/UA)
	MOV	BX,WORD PTR DLEN 	; データ長（ＤＴＬ）（バイト単位）
	MOV	CL,BYTE PTR DCYL 	; シリンダ番号（Ｃ）０ー７６
	MOV	DH,BYTE PTR DHEAD	; ヘッド番号（Ｈ）０ー１
	MOV	DL,BYTE PTR DDATPT	; データ部への書き込みﾃﾞｰﾀﾊﾟﾀｰﾝ（Ｄ）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）

	MOV	AH,BYTE PTR DFORMAT	; ＦＯＲＭＡＴ　ＴＲＡＣＫ
	INT	1BH			; ディスクＢＩＯＳ
	JB	FORMATTR_ERROR		;
FORMATTR9:
	MOV	DERROR,0		; 0=正常
	RET				;

FORMATTR_ERROR:				;
	CMP	AH,20H			; ＤＭＡ　Ｂｏｕｎｄａｒｙ
	JNE	FORMATTR_ERROR2		;

	MOV	AX,OFFSET SEC_ID_TBL2	; セクタＩＤバッファ
	CMP	AX,SEC_ID_BUF_ADRS	; セクタＩＤバッファのアドレス
	JNE	FORMATTR_BNK_SET	; バッファ１、２？
	MOV	AX,OFFSET SEC_ID_TBL1	; セクタＩＤバッファ
FORMATTR_BNK_SET:			;
	MOV	SEC_ID_BUF_ADRS,AX	; セクタＩＤバッファのアドレス
	CALL	ID_BUFF_SET		; ＩＤデータバッファセット
	JMP	FORMATTR_RETRY		;

FORMATTR_ERROR2:
	CMP	AH,60H			; Not Ready. ユニットがノットレディ状態
	JE	FORMATTR_ER_END		;

	DEC	FORMAT_RETRY		; ＦＯＲＭＡＴ・リトライカウンタ
	JZ	FORMATTR_ER_END		;

	MOV	AH,BYTE PTR DRECAL	; ＲＥＣＡＬＩＢＲＡＴＥ
	INT	1BH			; ディスクＢＩＯＳ
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	JMP	FORMATTR_RETRY		;

FORMATTR_ER_END:
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	MOV	DERROR,1		; 1=エラー
	RET
FORMATTR	ENDP


;	ＩＤデータバッファセット
;	-I- DCYL   : シリンダ番号（Ｃ）０ー７６
;	    DHEAD  : ヘッド番号（Ｈ）０ー１
;	    SEC_ID_BUF_ADRS : セクタＩＤバッファのアドレス

ID_BUFF_SET	PROC	NEAR
	PUSH	ES
	PUSH	AX
	PUSH	BX
	PUSH	CX

	MOV	AX,SEG CHASHB
	MOV	ES,AX

	MOV	AL,BYTE PTR DCYL		; シリンダ番号（Ｃ）０ー７６
	MOV	AH,BYTE PTR DHEAD		; ヘッド番号（Ｈ）０ー１

	MOV	BX,SEC_ID_BUF_ADRS		; セクタＩＤバッファのアドレス
	MOV	CX,TRK_SEC_CNT			; トラック当りのセクタ数
ID_BUFF_SET_LOOP:
	MOV	ES:[BX],AL			; シリンダ番号
	MOV	ES:[BX][1],AH			; ヘッド番号
	ADD	BX,4				; 4 byte pointer.
	LOOP	ID_BUFF_SET_LOOP		;

	POP	CX
	POP	BX
	POP	AX
	POP	ES
	RET
ID_BUFF_SET	ENDP


;	ドライブ番号の設定
;	-I- AX : １ＭＦＤドライブ番号

DNOSET	PROC	NEAR
	AND	BYTE PTR DUNIT,11111100B	;
	OR	BYTE PTR DUNIT,AL		;
	RET
DNOSET	ENDP


;	ドライブ番号の取得
;	-O- AX : １ＭＦＤドライブ番号

DNOGET	PROC	NEAR
	MOV	AX,DUNIT		;
	AND	AX,011B			;
	RET
DNOGET	ENDP


CODE	ENDS



CHASHB	SEGMENT	PUBLIC	'CHASHB'

EXTRN	SEC_ID_TBL1:WORD		; セクタＩＤバッファ
EXTRN	SEC_ID_TBL2:WORD		; セクタＩＤバッファ

;	"READWT.ASM"を参照の事
;	SEC_ID_TBL1	LABEL	BYTE		; セクタＩＤバッファ
;			;	C  H  R  N
;			DB	00,00,01,03	; 1
;			DB	00,00,02,03	; 2
;			DB	00,00,03,03	; 3
;			DB	00,00,04,03	; 4
;			DB	00,00,05,03	; 5
;			DB	00,00,06,03	; 6
;			DB	00,00,07,03	; 7
;			DB	00,00,08,03	; 8
;	SEC_ID_TBL2	LABEL	BYTE		; セクタＩＤバッファ
;			;	C  H  R  N
;				同	上

CHASHB	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

EXTRN	ADRSFAT:WORD			; ROOT ＦＡＴアドレス
EXTRN	ADRSROOTDIR:WORD		; ROOT ＲＯＯＴアドレス

;		ＢＩＯＳコマンド識別コード

;			MM-S....	;
;			TFrK0110	;
DREAD		DW	11110110B	; ＲＥＡＤ　ＤＡＴＡ
DWRITE		DW	11110101B	; ＷＲＩＴＥ　ＤＡＴＡ
DRECAL		DW	00100111B	; ＲＥＣＡＬＩＢＲＡＴＥ
DSENSE		DW	04H		; ＳＥＮＳＥ
DFORMAT		DW	01111101B	; ＦＯＲＭＡＴ　ＴＲＡＣＫ
;			100100dd	;
DUNIT		DW	10010001B	; デバイス識別・ユニット番号（DA/UA）

;		ＩＤＲ（ＩＤ情報）

DLEN		DW	SECTOR_ID_LEN	; データ長（ＤＴＬ）（バイト単位）
DCYL		DW	0		; シリンダ番号（Ｃ）０ー７６
DHEAD		DW	0		; ヘッド番号（Ｈ）０ー１
DSECR		DW	1		; セクタ番号（Ｒ）１ー８（２６）
DSECN		DW	03		; セクタ長（Ｎ）
					; 00/128, 01/256, 02/512, 03/1024
DDATPT		DW	0		; データ部への書き込みﾃﾞｰﾀﾊﾟﾀｰﾝ（Ｄ）
DSTAT		DW	0		; ステータス情報
DERROR		DW	0		; 0=正常,1=エラー

FORMAT_RETCNT	DW	10		; ＦＯＲＭＡＴ・リトライ回数
FORMAT_RETRY	DW	0		; ＦＯＲＭＡＴ・リトライカウンタ

MAX_CYLINDER	DW	77		; 最大シリンダ数

FAT_CLAST 	DW	4		; ＦＡＴテーブルクラスタ数
;READWT.ASMもなおせ
;ＤＫＦＯＲＭ．ＡＳＭもなおせ
;ｌｉｎｋｅｎｄ．ＡＳＭもなおせ
;SSDIR.ASMのDIRMAXもなおせ
ROOT_CLAST 	DW	1		; ＲＯＯＴＤＩＲクラスタ数
;;;;ROOT_CLAST 	DW	6		; ＲＯＯＴＤＩＲクラスタ数

LEN_CLAST	DW	1024		; クラスタバイト数
LEN_SECTOR	DW	1024		; セクタバイト数

FAT_ID_1	DW	0FEH		; ＦＡＴＩＤ
FAT_ID_2	DW	0FFH		;
FAT_ID_3	DW	0FFH		;

		EVEN
SECTOR_ID_LEN	DW	32		; セクターＩＤデータバッファ長
TRK_SEC_CNT	DW	8		; トラック当りのセクタ数
SEC_ID_BUF_ADRS	DW OFFSET SEC_ID_TBL1	; セクタＩＤバッファのアドレス

SAVE_DNO	DW	0		; １ＭＦＤドライブ番号退避

DATA	ENDS


;*;; ****************************************************
;*;;	ＩＰＬソースコード（１０２４バイト以内）
;*;; ****************************************************
;*;
;*;IPL	SEGMENT
;*;
;*;	ASSUME	CS:IPL,DS:IPL,ES:IPL,SS:IPL
;*;
;*;	STACK_HI_TOP	EQU	0FFFFH		; stack top.
;*;	TEXT_TOP	EQU	0		; text vram top offset.
;*;	TEXT_ADDRESS	EQU	0A000H		; text vram top segment.
;*;	CHR_LF		EQU	0AH		; line feed.
;*;
;*;IPL_CODE_TOP:
;*;	MOV	AX,CS				; segment register setup.
;*;	MOV	DS,AX				;
;*;	MOV	ES,AX				;
;*;	MOV	SS,AX				; stack pointer set.
;*;	MOV	SP,STACK_HI_TOP			;
;*;
;*;	CALL	TEXT_INIT			; text init.
;*;
;*;	MOV	SI,OFFSET MESSAGE_TOP		;
;*;	CALL	MESSAGE				; message print.
;*;
;*;BLACK_HOLE:
;*;	JMP	BLACK_HOLE
;*;
;*;
;*;;	text init.
;*;
;*;TEXT_INIT	PROC	NEAR
;*;	MOV	AH,0AH		; CRT mode set.
;*;	MOV	AL,00000000B	; 80*25.
;*;	INT	18H		; CRT bios.
;*;
;*;	MOV	AH,0CH		; TEXT on ( GDC )
;*;	INT	18H		; CRT bios.
;*;	RET
;*;TEXT_INIT	ENDP
;*;
;*;
;*;;	message print.
;*;;	-I- SI : message string address.
;*;
;*;MESSAGE	PROC	NEAR
;*;	MOV	AX,TEXT_ADDRESS		;
;*;	MOV	ES,AX			;
;*;	MOV	DI,TEXT_TOP		;
;*;	MOV	DX,DI			; pointer save.
;*;MESS_LOOP:
;*;	LODSB				;
;*;	CMP	AL,0			; end of string.
;*;	JE	MESS_END		;
;*;	CMP	AL,CHR_LF		;
;*;	JNE	MESS_SKIP		;
;*;	MOV	DI,DX			;
;*;	ADD	DI,160			; next line.
;*;	MOV	DX,DI			; pointer save.
;*;	JMP	MESS_LOOP		;
;*;MESS_SKIP:				;
;*;	STOSB				;
;*;	INC	DI			; text vram.
;*;	JMP	MESS_LOOP		;
;*;MESS_END:
;*;	RET
;*;MESSAGE	ENDP
;*;
;*;MESSAGE_TOP	LABEL	BYTE
;*;	DB	"data disk.",0
;*;
;*;IPL_CODE_END:
;*;
;*;IPL	ENDS
;*;
;*;; ****************************************************
;*;;	ＩＰＬソースコード終わり
;*;; ****************************************************

	END
;
;	end of "DKFROM.ASM"
;
