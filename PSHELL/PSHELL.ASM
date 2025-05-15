; "PSHELL.ASM" PC-9801UV11 make by R.H 1989/10/23
;
;	E X E L O A D    S h e l l  No.1
;
;
;
;	MY_SYSTEM_SIZE　はプログラムサイズです。（改造時に大きくしてね！）
;
;	NADIAバージョン
;	READWT.ASMの１００行目前後
;
;	DIRMAX		EQU	192		; ディレクトリ最大数
;	ROOT_CLAST 	EQU	6		; ＲＯＯＴＤＩＲクラスタ数
;				を
;	DIRMAX		EQU	32		; ディレクトリ最大数
;	ROOT_CLAST 	EQU	1		; ＲＯＯＴＤＩＲクラスタ数
;				に
;
;	SEC_ID_TBL1(セクタＩＤバッファ)と
;	SEC_ID_TBL2(セクタＩＤバッファ)の間は１０２４バイト以上あけること
;	SEC_ID_TBL2はバウンダリエラー用の予備です。（"DKFROM.ASM"で使用）
;	
; command shell.


;	セグメントはこの順番にする

CODE	SEGMENT	PUBLIC	'CODE'
CODE	ENDS
DATA	SEGMENT	PUBLIC	'DATA'
DATA	ENDS
STACK	SEGMENT	STACK
	DW	1600 DUP (?)
TOP_OF_STACK	LABEL	WORD
STACK	ENDS
CHASHB	SEGMENT	PUBLIC	'CHASHB'	; ディスクキャッシュバッファ
CHASHB	ENDS				; （トラックバッファ）

;	タイトル

DATA	SEGMENT	PUBLIC	'DATA'

SYSTEM_NAME	LABEL	BYTE
 DB "[ ] PSHELL  ver0.17 (C) R.Hashimoto 1989-1993 in shimorenjaku.",13,10
 DB "                        PRIME2 version. (root entry 32)",0

MY_SYSTEM_SIZE	DW	0FA0H		; このプログラムのサイズ（パラグラフ）

;		リンクマップ
;	 Start  Stop   Length Name                   Class            Group
;	 00000H 03641H 03642H CODE                   CODE
;	 03650H 0A5E4H 06F95H DATA                   DATA
;	 0A5F0H 0B26FH 00C80H STACK                  
;	 0B270H 0F2BFH 04050H CHASHB                 CHASHB
;		------これにＥＸＥのヘッダサイズを
;		加算したのがプログラムサイズです。（改造時に大きくしてね！）

DATA	ENDS


VECTOR22H_OFFSET	EQU	22H*4		; ベクタ２２ｈ
VECTOR22H_SEG		EQU	22H*4+2		;


INCLUDE TSTSET.INC

CODE	SEGMENT	PUBLIC	'CODE'
	ASSUME	CS:CODE,DS:DATA,SS:STACK,ES:DATA

EXTRN	CMMINT:NEAR		; メモリ管理初期化
EXTRN	FFOPEN:NEAR		; ファイルオープン
EXTRN	FFCLOS:NEAR		; ファイルクローズ
EXTRN	FFREAD:NEAR		; ファイルの読み出し
EXTRN	SSRDRV:NEAR		; ドライブ番号の設定（０ー３）
EXTRN	CLS:NEAR		; text clear.
EXTRN	CSLON:NEAR		; cursole on.
EXTRN	CSLOFF:NEAR		; cursole off.
EXTRN	PSMAIN:NEAR		; programers command shell.


START:	PUSH	DS

	MOV	AX,SEG DATA
	MOV	DS,AX

	MOV	AX,SS			; stack segment.
	MOV	SAVE_SS,AX		;
	MOV	SAVE_SP,SP		; stack pointer.

	MOV	AX,SEG STACK		; stack segment.
	MOV	SS,AX			;
	MOV	SP,OFFSET TOP_OF_STACK	; stack pointer.

	CALL	CSLOFF			;cursole off.

	CALL	MAIN

	CALL	CSLON			;cursole on.

	MOV	AX,SAVE_SS		;
	MOV	SS,AX			; stack segment.
	MOV	SP,SAVE_SP		; stack pointer.

	POP	DS
FINALE:	MOV	AH,4CH
	MOV	AL,0
	INT	21H

	JMP	$


;	ＭＡＩＮ　ＰＲＯＣ

MAIN	PROC	NEAR
	LC	0,3			; LOCATE 3,0
	MOV	SI,OFFSET SYSTEM_NAME	;
	CALL	PRINT			;

	LC	4,4			; LOCATE 4,4
	PRVH	"SEG CODE :",<SEG CODE>

	MOV	DX,MY_SYSTEM_SIZE	; このプログラムのサイズ（パラグラフ）
	CALL	CMMINT			; メモリ管理初期化

MAIN00:

;*;	LC	4,5
;*;	INP	"１ＭＦＤドライブ番号(1,2,3,4):"
;*;	CALL	STRDEC			;
;*;	CMP	DX,0			;
;*;	JE	MAIN00			;
;*;	CMP	DX,5			;
;*;	JNB	MAIN00			;
;*;	MOV	AX,DX			; １ＭＦＤドライブ番号
;*;	DEC	AX			;
;*;	LC	0,7			; LOCATE 0,7


	; ＥＸＥＬＯＡＤ．ＳＹＳからＰＳＨＥＬＬ．ＥＸＥへ
	; カレントドライブ番号受渡しの為、
	; ＩＮＴ２２ｈのベクターテーブルを使います。
	; あまり、美しい方法ではないので必要ないときは
	; 外して下さい。
	;		ｖｅｃｔｏｒ２２Ｈ　ｏｆｆｓｅｔ＝（カレントドライブ）
	;		ｖｅｃｔｏｒ２２Ｈ　ｓｅｇｍｅｎｔ＝６５３２１

	MOV	AX,0			;
	MOV	ES,AX			;
	MOV	AX,65321		; パスワード６５３２１
	CMP	ES:[VECTOR22H_OFFSET],AX ; ofs.
	JNE	MAIN_DEFALT		;

	MOV	DX,ES:[VECTOR22H_SEG]	; ロードドライブ番号
	AND	DX,11B			;
	INC	DX			; DX : 1=1MFD#0,2=1MFD#1....

	CLI				;
	MOV	AX,OFFSET DUMMY_HOOK	; 危険なのでダミーに引っかけておく
	MOV	BX,SEG CODE		;
	MOV	ES:[VECTOR22H_OFFSET],AX
	MOV	ES:[VECTOR22H_SEG],BX	;
	STI				;

	JMP	MAIN_55			;

MAIN_DEFALT:				;
	MOV	AX,0			;
	MOV	ES,AX			;
	MOV	AL,BYTE PTR ES:[584H]	;
	MOV	AH,0			;
	AND	AX,11B			;
	MOV	DX,AX			; １ＭＦＤドライブ番号
	INC	DX			; DX : 1=1MFD#0,2=1MFD#1....
;*DBG*;	PRVH	"立ち上げディスクのＤＡ／ＵＡ [584h]:",AX
MAIN_55:

	CALL	BUFFER_SETUP		; バッファ・セットアップ

					; -I- DX:cullent drive number.
	CALL	PSMAIN			; programers command shell.
	RET
MAIN	ENDP


;	バッファ・セットアップ

BUFFER_SETUP	PROC	NEAR
	MOV	AX,SEG CHASHB
	MOV	ES,AX

	MOV	SI,OFFSET SEC_ID_TABLE	; セクタＩＤテーブル
	MOV	DI,OFFSET SEC_ID_TBL1	; セクタＩＤバッファ
	MOV	CX,32/2
	REP	MOVSW

	MOV	SI,OFFSET SEC_ID_TABLE	; セクタＩＤテーブル
	MOV	DI,OFFSET SEC_ID_TBL2	; セクタＩＤバッファ
	MOV	CX,32/2
	REP	MOVSW

	MOV	DI,OFFSET CHASH_BUFFER_START
	MOV	CX,1024*16+4
	XOR	AL,AL			; AL=0
	REP	STOSB

	RET
BUFFER_SETUP	ENDP


;	ダミーフック

DUMMY_HOOK	PROC	NEAR
	IRET
DUMMY_HOOK	ENDP


CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

SAVE_SS	DW	0	; stack segment.
SAVE_SP	DW	0	; stack pointer.

SEC_ID_TABLE	LABEL	BYTE		; セクタＩＤテーブル
		;	C  H  R  N
		DB	00,00,01,03	; 1
		DB	00,00,02,03	; 2
		DB	00,00,03,03	; 3
		DB	00,00,04,03	; 4
		DB	00,00,05,03	; 5
		DB	00,00,06,03	; 6
		DB	00,00,07,03	; 7
		DB	00,00,08,03	; 8

DATA	ENDS


;	ディスクキャッシュバッファ
;	悩めるＤＭＡバッファの群たち・・・
;
;	SEC_ID_TBL1(セクタＩＤバッファ)と
;	SEC_ID_TBL2(セクタＩＤバッファ)の間は１０２４バイト以上あけること
;	SEC_ID_TBL2はバウンダリエラー用の予備です。（"DKFROM.ASM"で使用）

CHASHB	SEGMENT	PUBLIC	'CHASHB'

PUBLIC	SEC_ID_TBL1			; セクタＩＤバッファ
PUBLIC	SEC_ID_TBL2			; セクタＩＤバッファ

PUBLIC	CHASH_BUFFER1			; トラックバッファ
PUBLIC	CHASH_BUFFER2			; トラックバッファ

SEC_ID_TBL1	LABEL	BYTE		; セクタＩＤバッファ
		;	C  H  R  N
		DB	4 DUP (?)	; 1
		DB	4 DUP (?)	; 2
		DB	4 DUP (?)	; 3
		DB	4 DUP (?)	; 4
		DB	4 DUP (?)	; 5
		DB	4 DUP (?)	; 6
		DB	4 DUP (?)	; 7
		DB	4 DUP (?)	; 8

CHASH_BUFFER_START	LABEL	BYTE	; バッファ・スタート
		DB	2 DUP (?)	;
CHASH_BUFFER1	LABEL	BYTE		; トラックバッファ
CHASH_BUFFER2	DB	1024*16 DUP (?)	; トラックバッファ
		DB	2 DUP (?)	;
CHASH_BUFFER_END	LABEL	BYTE	; バッファ・スタート

SEC_ID_TBL2	LABEL	BYTE		; セクタＩＤバッファ
		;	C  H  R  N
		DB	4 DUP (?)	; 1
		DB	4 DUP (?)	; 2
		DB	4 DUP (?)	; 3
		DB	4 DUP (?)	; 4
		DB	4 DUP (?)	; 5
		DB	4 DUP (?)	; 6
		DB	4 DUP (?)	; 7
		DB	4 DUP (?)	; 8

CHASHB	ENDS

	END	START
;
;	end of "PSHELL.ASM"
;
