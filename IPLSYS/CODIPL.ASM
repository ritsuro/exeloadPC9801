; "CODIPL.ASM" PC-9801UV11 make by R.H 1989/12/01
;	modify	ver0.23 1990/10/04
;	modify	ver0.24 1991/01/24
;	modify	ver0.25 1991/12/28
;	modify	ver0.26 1992/08/04
;	modify	ver0.27 1993/03/24
;	modify	ver0.28 1993/05/12
;
;	E X E L O A D    I P L   k i t .
;
;	I P L   c o d e .
;
;	ＩＰＬコード（イニシャルプログラムローダ）
;
;
;	1991/01/16 ＥＰＳＯＮ　ＰＣ－３８６ＬＳＸの
;		３．５ｉｎｃｈドライブ対策の為、リトライ回数を
;		５回から１０回に変更した。
;
;		READ_RETCOUNT 	EQU	10	; リード・リトライ回数
;
;		このドライブは冬季、電源ＯＮ時から回転が安定するまで、
;		時間がかかるようだ。
;
;	1993/05/12 ＩＰＬ領域のディスク情報を付加
;
;

CODIPL	SEGMENT	PUBLIC	'CODIPL'
	ASSUME	CS:CODIPL,DS:CODIPL

PUBLIC	IPLTOP				; ＩＰＬコードの先頭
PUBLIC	IPLEND				; ＩＰＬコードの終わり


;	ＩＰＬソースコード（１０２４バイト以内）

IPLTOP	LABEL	FAR			; ＩＰＬコードの先頭

SYS_SEC_CNT	EQU	8		; システムセクタのセクタ数

TEXT_TOP	EQU	0		; テキストＶＲＡＭオフセット
TEXT_ADDRESS	EQU	0A000H		; テキストＶＲＡＭセグメント

SYSMAIN_OFSET	EQU	0		; システムオフセット
SYSMAIN_SEG	EQU	060H		; システムセグメント

					; 最小
MIN_CYLINDER	EQU	0		; シリンダ番号（Ｃ）０
MIN_HEAD	EQU	0		; ヘッド番号（Ｈ）０
MIN_SECTOR	EQU	1		; セクタ番号（Ｒ）１

					; 最大
MAX_CYLINDER	EQU	76		; シリンダ番号（Ｃ）７６
MAX_HEAD	EQU	1		; ヘッド番号（Ｈ）１
MAX_SECTOR	EQU	8		; セクタ番号（Ｒ）２６

					; システムの先頭
SYS_CYLINDER	EQU	0		; シリンダ番号（Ｃ）
SYS_HEAD	EQU	1		; ヘッド番号（Ｈ）
SYS_SECTOR	EQU	4		; セクタ番号（Ｒ）

SEC_BYTE	EQU	1024		; セクタバイト数

READ_RETCOUNT 	EQU	10		; リード・リトライ回数
KICK_RETRY	EQU	3		; ドライブキック・リトライ

CHR_LF		EQU	0AH		; ＬＦ


;	main program.

IPL_TOP:
	JMP	SHORT IPL_CODE_START	;+0 short jump.(2byte)
	NOP				;+2 NOP
		;3456789A		;
	DB	"EXELOAD0"		;+3 naming.
IPLHEADER	LABEL	BYTE		; IPL code header.
I_BYTE_SEC	DW	1024		;+0Bh byte/sector.
I_SEC_CLAST	DB	1		;+0Dh sector/clast.
I_RESERVE_SEC	DW	1		;+0Eh reserved sector.
I_FAT_COPY	DB	2		;+10h FAT copy count.
I_ENTRY_COUNT	DW	192		;+11h root dir entry count.
I_FULL_SEC	DW	1232		;+13h full sector count.
I_MEDIA_DISC	DB	0FEH		;+15h dos media discripta.
I_SEC_FAT	DW	2		;+16h sector/FAT.
I_SEC_TRACK	DW	8		;+18h sector/track.
I_HEAD_COUNT	DW	2		;+1Ah head count.
I_DARK_SEC	DW	0		;+1Ch dark sector.

IPL_CODE_START:

	MOV	AX,CS			;
	MOV	DS,AX			;
	MOV	ES,AX			;
	MOV	SS,AX			; stack pointer set.
	MOV	SP,STACK_HI_TOP		;

	MOV	AX,0			; key bord beep off.
	MOV	ES,AX			;
	OR	BYTE PTR ES:[0500H],00100000B	; D5set.

	CALL	SRTDRV			; 立ち上がりドライブ番号の設定

	CALL	TEXT_INIT		; text init.

	MOV	SI,OFFSET MESSAGE_TOP	; タイトル
	CALL	MESSAGE			;

	MOV	AX,SYSMAIN_OFSET	; システムオフセット
	MOV	LOAD_OFSET,AX		; system load offset.

	MOV	AX,SYSMAIN_SEG		; システムセグメント
	MOV	LOAD_SEG,AX		; system load segment.


	CALL	SYSLOAD			; システムロード
	CMP	AX,0			; 0=正常,1=エラー
	JE	IPL_RDY			;

	MOV	SI,OFFSET MESSAGE_OKOSU	; ドライブをたたき起こす！
	CALL	MESSAGE			;

	CALL	DRV_KICK		; ドライブキック！

	CALL	SYSLOAD			; システムロード
	CMP	AX,0			; 0=正常,1=エラー
	JNE	IPL_ERR			; エラーメッセージ

IPL_RDY:
	MOV	SI,OFFSET MESSAGE_RDY	; "ＲＤＹ"
	CALL	MESSAGE			;

	MOV	AX,SYSMAIN_OFSET	; システムオフセット
	MOV	START_OFFSET,AX		; スタートオフセットアドレス

	MOV	AX,SYSMAIN_SEG		; システムセグメント
	MOV	START_SEG,AX		; スタートセグメントアドレス

	CALL	SYSCHECK		; システムチェックマーク

	CALL	SRTDRVNO		; 立ち上がりドライブ番号の取得
					; DX=立ち上げディスクのＤＡ／ＵＡ

	JMP	DWORD PTR START_ADDRESS	; スタートアドレス
					; いってらっしゃーい


IPL_ERR:				; エラーメッセージ
	MOV	SI,OFFSET MESSAGE_DERROR
	CALL	MESSAGE			;
MUGEN:
	JMP	MUGEN


;	text init.

TEXT_INIT:
	MOV	AH,0AH			; CRT mode set.
	MOV	AL,00000000B		; 80*25.
	INT	18H			; CRT bios.

	MOV	AH,0CH			; TEXT on ( GDC )
	INT	18H			; CRT bios.

	RET


;	システムチェックマーク

SYSCHECK:
	MOV	AX,SYSMAIN_SEG		; システムセグメント
	MOV	ES,AX			;
	MOV	DI,SYSMAIN_OFSET	; システムオフセット
	MOV	DL,ES:[DI]		;

	MOV	AX,TEXT_ADDRESS		;
	MOV	ES,AX			;
	MOV	DI,TEXT_TOP+2		;
	MOV	ES:[DI],DL		;
	RET				;



;	システムロード
;	-I- LOAD_OFSET	; system load offset.
;	    LOAD_SEG	; system load segment.
;	-O- AX 		: 0=正常,1=エラー

SYSLOAD:
	MOV	AX,SYS_CYLINDER		; シリンダ番号（Ｃ）
	MOV	READ_CYLINDER,AX	; シリンダ番号（Ｃ）
	MOV	AX,SYS_HEAD		; ヘッド番号（Ｈ）
	MOV	READ_HEAD,AX		; ヘッド番号（Ｈ）
	MOV	AX,SYS_SECTOR		; セクタ番号（Ｒ）
	MOV	READ_SECTOR,AX		; セクタ番号（Ｒ）
	MOV	CX,SYS_SEC_CNT		; system sector count.
SYSLOAD2:
	PUSH	CX			;
	MOV	DX,LOAD_SEG		; system load segment.
	MOV	BX,LOAD_OFSET		; system load offset.
	CALL	SCSEQ			;
	POP	CX			;

	CMP	AX,0			; 0=正常
	JNE	SYSLOAD_ERROR		;

	ADD	LOAD_OFSET,SEC_BYTE	; セクタバイト数

	LOOP	SYSLOAD2		;

	MOV	AX,0			; 正常
	RET				;
SYSLOAD_ERROR:
	MOV	AX,1			; エラー
	RET				;


	

;	セクター順次読み込み
;	-I- DX : バッファセグメント
;	    BX : バッファオフセット
;	-O- AX : 0=正常,1=エラー,2=最後のセクタに書き込んだ

SCSEQ:
	MOV	BUFF_SEG,DX		; バッファセグメント
	MOV	BUFF_OFSET,BX		; バッファオフセット

	MOV	AX,READ_CYLINDER	; シリンダ番号（Ｃ）
	MOV	DCYL,AX			;
	MOV	AX,READ_HEAD		; ヘッド番号（Ｈ）
	MOV	DHEAD,AX		;
	MOV	AX,READ_SECTOR		; セクタ番号（Ｒ）
	MOV	DSECR,AX		;

	CALL	SCREAD			; セクターリード
	CMP	DERROR,0		; 0=正常,1=エラー
	JNE	SCSEQ_ERROR

	INC	READ_SECTOR		; セクタ番号（Ｒ）
	CMP	READ_SECTOR,MAX_SECTOR	;
	JBE	SCSEQ8			;

	MOV	READ_SECTOR,MIN_SECTOR	;
	INC	READ_HEAD		; ヘッド番号（Ｈ）
	CMP	READ_HEAD,MAX_HEAD	;
	JBE	SCSEQ8			;

	MOV	READ_HEAD,MIN_HEAD	;
	INC	READ_CYLINDER		; シリンダ番号（Ｃ）
	CMP	READ_CYLINDER,MAX_CYLINDER
	JBE	SCSEQ8			;

	JMP	SCSEQ_ENDSEC		;
SCSEQ8:
	MOV	AX,0			; 0=正常
	RET				;
SCSEQ_ERROR:
	MOV	AX,1			; 1=エラー
	RET				;
SCSEQ_ENDSEC:
	MOV	AX,2			; 2=最後のセクタを読み込んだ
	RET				;




;	セクターリード
;	-I- DCYL  : シリンダ番号（Ｃ）０ー７６
;	    DHEAD : ヘッド番号（Ｈ）０ー１
;	    DSECR : セクタ番号（Ｒ）１ー８（２６）
;	    BUFF_SEG	; バッファセグメント
;	    BUFF_OFSET	; バッファオフセット
;	-O- BUFF_SEG_OF[BUFF_OFSET] ; セクタのデータ
;	    DERROR : 0=正常,1=エラー

SCREAD:
	MOV	DERROR,0		; 0=正常

	MOV	AX,READ_RETCOUNT	; リード・リトライカウンタ
	MOV	READ_RETRY,AX		;

	MOV	AX,BUFF_SEG		; バッファセグメント
	MOV	ES,AX			;
	MOV	BP,BUFF_OFSET		; バッファオフセット

	MOV	AL,BYTE PTR DUNIT	; デバイス識別・ユニット番号(DA/UA)
	MOV	BX,WORD PTR DLEN	; データ長（ＤＴＬ）（バイト単位）
	MOV	CL,BYTE PTR DCYL	; シリンダ番号（Ｃ）０ー７６
	MOV	DH,BYTE PTR DHEAD	; ヘッド番号（Ｈ）０ー１
	MOV	DL,BYTE PTR DSECR	; セクタ番号（Ｒ）１ー８（２６）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）
SCREAD5:
	MOV	AH,BYTE PTR DREAD	; ＲＥＡＤ　ＤＡＴＡ
	INT	1BH		 	; ディスクＢＩＯＳ
	MOV	BYTE PTR DSTAT,AH	; ステータス情報

	JNB	SCREAD9			; 正常終了

	DEC	READ_RETRY	  	; リード・リトライカウンタ
	JZ	SCREAD99

	MOV	AL,BYTE PTR DUNIT	; デバイス識別・ユニット番号(DA/UA)
	MOV	AH,BYTE PTR DRECAL	; ＲＥＣＡＬＩＢＲＡＴＥ
	INT	1BH		  	; ディスクＢＩＯＳ
	MOV	BYTE PTR DSTAT,AH	; ステータス情報

	JMP	SCREAD5			;
SCREAD9:
	MOV	DERROR,0		; 0=正常
	RET				;
SCREAD99:
	MOV	DERROR,1		; 1=エラー
	RET



;	立ち上がりドライブ番号の設定

SRTDRV:
	MOV	AX,0			;
	MOV	ES,AX			;
	MOV	AL,BYTE PTR ES:[584H]	; 立ち上げディスクのＤＡ／ＵＡ [584h]
	MOV	BYTE PTR DUNIT,AL	;
	RET				;


;	立ち上がりドライブ番号の取得
;	-O- DX : 立ち上げディスクのＤＡ／ＵＡ

SRTDRVNO:
	MOV	DX,0			;
	MOV	ES,DX			;
	MOV	DL,BYTE PTR ES:[584H]	; 立ち上げディスクのＤＡ／ＵＡ
	RET				;


;	ドライブキック！
;	-I- LOAD_OFSET	; system load offset.
;	    LOAD_SEG	; system load segment.

DRV_KICK:
	MOV	CX,KICK_RETRY		; ドライブキック・リトライ
	JCXZ	DRV_KICK_EXIT		;
DRV_KICK_LOOP:
	PUSH	CX

	MOV	AL,BYTE PTR DUNIT	; デバイス識別・ユニット番号(DA/UA)
	MOV	AH,BYTE PTR DRECAL	; ＲＥＣＡＬＩＢＲＡＴＥ
	INT	1BH		  	; ディスクＢＩＯＳ

	MOV	AX,LOAD_SEG		; system load segment.
	MOV	ES,AX			;
	MOV	BP,LOAD_OFSET		; system load offset.

	MOV	AL,BYTE PTR DUNIT	; デバイス識別・ユニット番号(DA/UA)
	MOV	BX,WORD PTR DLEN	; データ長（ＤＴＬ）（バイト単位）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）

	MOV	CL,16			; シリンダ番号（Ｃ）０ー７６
	MOV	DH,0			; ヘッド番号（Ｈ）０ー１
	MOV	DL,3			; セクタ番号（Ｒ）１ー８（２６）

	MOV	AH,BYTE PTR DREAD	; ＲＥＡＤ　ＤＡＴＡ
	INT	1BH		 	; ディスクＢＩＯＳ

	POP	CX			;
	LOOP	DRV_KICK_LOOP		;
DRV_KICK_EXIT:
	RET


;	message print.
;	-I- SI : message string address.

MESSAGE:
	MOV	AX,TEXT_ADDRESS		;
	MOV	ES,AX			;
	MOV	DI,TEXT_TOP		;
	MOV	DX,DI			; pointer save.
MESS_LOOP:
	LODSB				;
	CMP	AL,0			; end of string.
	JE	MESS_END		;
	CMP	AL,CHR_LF		;
	JNE	MESS_SKIP		;
	MOV	DI,DX			;
	ADD	DI,160			; next line.
	MOV	DX,DI			; pointer save.
	JMP	MESS_LOOP		;
MESS_SKIP:				;
	STOSB				;
	INC	DI			; text vram.
	JMP	MESS_LOOP		;
MESS_END:
	RET


MESSAGE_TOP:
DB "[ ] EXELOAD ver0.28 (C) R.Hashimoto 1989-1993 in shimorenjaku."
DB CHR_LF
DB 0

MESSAGE_DERROR:
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	"        ｼ ｽ ﾃ ﾑ   ｶﾞ   ﾐ ﾂ ｶ ﾘ ﾏ ｾ ﾝ ･････"
	DB	0

MESSAGE_OKOSU:		; ドライブをたたき起こす！
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	CHR_LF
	DB	"   d r i v e   k i c k !!"
	DB	0

MESSAGE_RDY:
	DB	CHR_LF
	DB	CHR_LF
	DB	"  RDY...."
	DB	0


; ＢＩＯＳコマンド識別コード
;		MM-S....
;		TFrK0110
DREAD	DW	11110110B	; ＲＥＡＤ　ＤＡＴＡ
DRECAL	DW	00100111B	; ＲＥＣＡＬＩＢＲＡＴＥ

;		100100dd
DUNIT	DW	10010001B	; デバイス識別・ユニット番号（DA/UA）

;	ＩＤＲ（ＩＤ情報）
DLEN	DW	SEC_BYTE	; データ長（ＤＴＬ）（バイト単位）
DCYL	DW	0		; シリンダ番号（Ｃ）０ー７６
DHEAD	DW	0		; ヘッド番号（Ｈ）０ー１
DSECR	DW	1		; セクタ番号（Ｒ）１ー８（２６）
DSECN	DW	03		; セクタ長（Ｎ）
				; 00/128, 01/256, 02/512, 03/1024
DSTAT	DW	0		; ステータス情報
DERROR	DW	0		; 0=正常,1=エラー

READ_RETRY	DW	0	; リード・リトライカウンタ

LOAD_OFSET	DW	0	; system load offset.
LOAD_SEG	DW	0	; system load segment.

BUFF_OFSET	DW	0	; バッファオフセット
BUFF_SEG	DW	0	; バッファセグメント

READ_CYLINDER	DW	0	; シリンダ番号（Ｃ）（０ー７６）
READ_HEAD	DW	0	; ヘッド番号（Ｈ）（０ー１）
READ_SECTOR	DW	0	; セクタ番号（Ｒ）（１ー２６）


START_ADDRESS	LABEL	DWORD	; スタートアドレス
START_OFFSET	DW 0		; スタートオフセットアドレス
START_SEG	DW 0		; スタートセグメントアドレス

				; スタックトップ・アドレス
STACK_HI_TOP	DW	( OFFSET IPLTOP ) + SEC_BYTE


;	ＩＰＬソースコード終わり

IPLEND	LABEL	FAR

	DB	1024 DUP (0)

CODIPL	ENDS

	END
;
;	end of "CODIPL.ASM"
;
