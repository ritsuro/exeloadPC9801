; "SSADRS.ASM" PC-9801UV11 make by R.H 1989/11/22
;
;	E X E L O A D    a d d r e s s   t a b l e   s e t .
;
;
;
; command.

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	CMMINT		; メモリ管理初期化
PUBLIC	CMFREE		; フリーエリアの開始位置
PUBLIC	CMFREC		; フリーエリアのサイズ
PUBLIC	CMMALC		; 使用エリアの確保
PUBLIC	CMMCUT		; 使用エリアの開放
PUBLIC	CMMFST		; 使用エリアの設定
PUBLIC	CMMPSP		; ＰＳＰセグメントの設定
PUBLIC	CMMPSG		; ＰＳＰセグメントの取得
PUBLIC	CMMPES		; プログラムの後ろエリアの設定
PUBLIC	CMMPEG		; プログラムの後ろエリアの取得
PUBLIC	CMMPFR		; プログラムエリアの開放
PUBLIC	CMMMAX		; メモリの上限



EXTRN	HEXSTR:NEAR	; val DX to hex string.
EXTRN	PRINT:NEAR	; print string.

CHR_CR		EQU	0DH	; calig return.
CHR_LF		EQU	0AH	; line feed.
EOS		EQU	0	; end of string.


;	メモリ管理初期化
;	-I- DX : このプログラムのサイズ（パラグラフ）

CMMINT	PROC	NEAR
	MOV	MYPRG_SIZE_PAR,DX	; このプログラムのサイズ（パラグラフ）
	ADD	DX,SEG CODE		;
	MOV	ADRS_MIN,DX		; 空きエリア（パラグラフ）下限
	MOV	ADRS_FRE,DX		; 空きエリア（パラグラフ）先頭
	MOV	ADRS_PSP,DX		; ＰＳＰエリア（パラグラフ）
	RET
CMMINT	ENDP


;	フリーエリアの開始位置（パラグラフ値）
;	-O- ES : フリーエリアの開始パラグラフ値

CMFREE	PROC	NEAR
	MOV	ES,ADRS_FRE		; 空きエリア（パラグラフ）先頭
	RET
CMFREE	ENDP


;	フリーエリアのサイズ
;	-O- DX : フリーエリアのサイズ（パラグラフ値）

CMFREC	PROC	NEAR
	MOV	DX,ADRS_MAX		; 空きエリア（パラグラフ）上限＋１
	SUB	DX,ADRS_FRE		; 空きエリア（パラグラフ）先頭
	RET
CMFREC	ENDP


;	使用エリアの確保（パラグラフ値）
;	-I- DX : 確保パラグラフ値

CMMALC	PROC	NEAR
	PUSH	DX
	ADD	DX,ADRS_PSP		; ＰＳＰエリア（パラグラフ）
	MOV	ADRS_FRE,DX		; 空きエリア（パラグラフ）先頭
	POP	DX
	RET
CMMALC	ENDP


;	使用エリアの開放（パラグラフ値）
;	-I- ES : 開放するメモリのパラグラフ値

CMMCUT	PROC	NEAR
	MOV	ADRS_FRE,ES		; 空きエリア（パラグラフ）先頭
	MOV	ADRS_PNEXT,ES		; プログラムの直後エリア

	MOV	AX,ADRS_FRE		; 空きエリア（パラグラフ）先頭
	CMP	AX,ADRS_MIN		; 空きエリア（パラグラフ）下限
	JNB	CMMCUT_EXIT		;
	MOV	AX,ADRS_MIN		; 下限
	MOV	ADRS_FRE,AX		; 先頭
CMMCUT_EXIT:
	RET
CMMCUT	ENDP


;	使用エリアの設定
;	-I- DX : フリーエリアの開始パラグラフ値

CMMFST	PROC	NEAR
	MOV	ADRS_FRE,DX		; 空きエリア（パラグラフ）先頭
	RET
CMMFST	ENDP


;	ＰＳＰセグメントの設定
;	-I- DX : ＰＳＰセグメント値

CMMPSP	PROC	NEAR
	MOV	ADRS_PSP,DX		; ＰＳＰエリア（パラグラフ）
	RET
CMMPSP	ENDP


;	ＰＳＰセグメントの取得
;	-O- ES : ＰＳＰセグメント値

CMMPSG	PROC	NEAR
	MOV	ES,ADRS_PSP		; ＰＳＰエリア（パラグラフ）
	RET
CMMPSG	ENDP


;	プログラムの後ろエリアの設定
;	-I- DX : 後ろエリアセグメント値

CMMPES	PROC	NEAR
	MOV	ADRS_PNEXT,DX		; プログラムの直後エリア（パラグラフ）
	RET
CMMPES	ENDP


;	プログラムの後ろエリアの取得
;	-O- ES : 後ろエリアセグメント値

CMMPEG	PROC	NEAR
	MOV	ES,ADRS_PNEXT		; プログラムの直後エリア（パラグラフ）
	RET
CMMPEG	ENDP


;	プログラムエリアの開放

CMMPFR	PROC	NEAR
	MOV	AX,ADRS_FRE		; 空きエリア（パラグラフ）先頭
	MOV	BX,ADRS_PSP		; ＰＳＰエリア（パラグラフ）

	CMP	AX,BX			; 空きエリア先頭の方が小さければ
	JB	CMMPFR_4		; 空きエリア先頭まで開放する。

	MOV	AX,ADRS_PSP		; ＝ＰＳＰエリア（パラグラフ）
	MOV	ADRS_FRE,AX		; 空きエリア（パラグラフ）先頭
	MOV	ADRS_PNEXT,AX		; プログラムの直後エリア（パラグラフ）
	JMP	CMMPFR_5
CMMPFR_4:
	MOV	AX,ADRS_FRE		; ＝空きエリア（パラグラフ）先頭
	MOV	ADRS_PSP,AX		; ＰＳＰエリア（パラグラフ）
	MOV	ADRS_PNEXT,AX		; プログラムの直後エリア（パラグラフ）
CMMPFR_5:
	RET
CMMPFR	ENDP


;	メモリの上限
;	-O- ES : 空きエリア（パラグラフ）上限＋１

CMMMAX	PROC	NEAR
	MOV	ES,ADRS_MAX		; 空きエリア（パラグラフ）上限＋１
	RET
CMMMAX	ENDP


CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

MYPRG_SIZE_PAR	DW	0		; このプログラムのサイズ（パラグラフ）

ADRS_MIN	DW	0		; 空きエリア（パラグラフ）下限
ADRS_MAX	DW	0A000H		; 空きエリア（パラグラフ）上限＋１

ADRS_PSP	DW	0		; ＰＳＰエリア（パラグラフ）
ADRS_PNEXT	DW	0		; プログラムの直後エリア（パラグラフ）
ADRS_FRE	DW	0		; 空きエリア（パラグラフ）先頭

DATA	ENDS

	END
;
;	end of "SSADRS.ASM"
;
