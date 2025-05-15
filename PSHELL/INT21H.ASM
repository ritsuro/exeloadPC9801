; "INT21H.ASM" PC-9801UV11 make by R.H 1990/10/05
;
;	E X E L O A D    "INT 21H"  d r i v e r .
;
;
;
; public subroutine.( software interrupt )

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:DATA

PUBLIC	I21HSET			; 割込みを設定
PUBLIC	I21HRST			; 割込み元に戻す
PUBLIC	I21HDRV			; デフォルトドライブ番号
PUBLIC	I21HRET			; プロセスへの戻りアドレス設定

EXTRN	CMMINT:NEAR		; メモリ管理初期化
EXTRN	CMFREE:NEAR		; フリーエリアの開始位置
EXTRN	CMFREC:NEAR		; フリーエリアのサイズ
EXTRN	CMMALC:NEAR		; 使用エリアの確保
EXTRN	CMMCUT:NEAR		; 使用エリアの開放
EXTRN	CMMFST:NEAR		; 使用エリアの設定
EXTRN	CMMPSP:NEAR		; ＰＳＰセグメントの設定
EXTRN	CMMPSG:NEAR		; ＰＳＰセグメントの取得
EXTRN	CMMPES:NEAR		; プログラムの後ろエリアの設定
EXTRN	CMMPEG:NEAR		; プログラムの後ろエリアの取得
EXTRN	CMMPFR:NEAR		; プログラムエリアの開放
EXTRN	CMMMAX:NEAR		; メモリの上限


EXTRN	FWOPEN:NEAR		; ファイルの書き込み開始
EXTRN	FWCLOS:NEAR		; ファイルの書き込み終了
EXTRN	FWRITE:NEAR		; ファイルの書き込み

EXTRN	FWKILL:NEAR		; ファイルの削除
EXTRN	FWFREE:NEAR		; ディスクの空き容量
EXTRN	FWREST:NEAR		; ディスクのリセット

EXTRN	FFOPEN:NEAR		; ファイルオープン
EXTRN	FFCLOS:NEAR		; ファイルクローズ
EXTRN	FFREAD:NEAR		; ファイルの読み出し
EXTRN	FFSEEK:NEAR		; ファイルポインタシーク

EXTRN	FFDRV:NEAR		; カレントドライブ設定

EXTRN	CCCIN:NEAR		; console in.
EXTRN	CCCOUT:NEAR		; print character.
EXTRN	CCCRD:NEAR		; read key buffer.



;	割込みを設定

I21HSET	PROC	NEAR
	CALL	VECSET_INT21H_SAVE	; ベクタ退避
	CALL	VECSET_INT21H		; ベクタセット
	RET
I21HSET	ENDP



;	割込み元に戻す

I21HRST	PROC	NEAR
	CALL	VECSET_INT21H_LOAD	;　ベクタ復元
	RET
I21HRST	ENDP


;	デフォルトドライブ番号
;	-I- DX : １ＭＦＤドライブ番号（０ー３）

I21HDRV	PROC	NEAR
	MOV	LOAD_DRIVE,DX		; ロードドライブ番号
	RET
I21HDRV	ENDP


;	プロセスへの戻りアドレス設定
;	-I- AX : 戻りオフセットアドレス
;	    DX : 戻りセグメントアドレス

I21HRET	PROC	NEAR
	MOV	RET_OFFSET,AX		; リターンオフセットアドレス
	MOV	RET_SEG,DX		; リターンセグメントアドレス
	RET
I21HRET	ENDP


VEC_INT21H_OFST	EQU	21H*4		; int 21h
VEC_INT21H_SEG	EQU	21H*4+2		;

;	ベクタセット

VECSET_INT21H	PROC	NEAR
	CLI

	MOV	AX,0		; 0 base.
	MOV	ES,AX		;

	MOV	WORD PTR ES:[VEC_INT21H_OFST],OFFSET INT21H

	MOV	WORD PTR ES:[VEC_INT21H_SEG],SEG CODE

	STI
	RET
VECSET_INT21H	ENDP

;	ベクタ退避

VECSET_INT21H_SAVE	PROC	NEAR
	CLI

	MOV	AX,0		; 0 base.
	MOV	ES,AX		;

	MOV	AX,WORD PTR ES:[VEC_INT21H_OFST]
	MOV	SAVE_VEC_INT21H_OFST,AX	; ＩＮＴ２１Ｈベクタオフセット退避

	MOV	AX,WORD PTR ES:[VEC_INT21H_SEG]
	MOV	SAVE_VEC_INT21H_SEG,AX	; ＩＮＴ２１Ｈベクタセグメント退避

	STI
	RET
VECSET_INT21H_SAVE	ENDP

;	ベクタ復元

VECSET_INT21H_LOAD	PROC	NEAR
	CLI

	MOV	AX,0		; 0 base.
	MOV	ES,AX		;

	MOV	AX,SAVE_VEC_INT21H_OFST	; ＩＮＴ２１Ｈベクタオフセット退避
	MOV	WORD PTR ES:[VEC_INT21H_OFST],AX

	MOV	AX,SAVE_VEC_INT21H_SEG	; ＩＮＴ２１Ｈベクタセグメント退避
	MOV	WORD PTR ES:[VEC_INT21H_SEG],AX

	STI
	RET
VECSET_INT21H_LOAD	ENDP




;	ＩＮＴ　２１Ｈ　割込みファンクション

INT21H	PROC	NEAR
	CMP	AH,62H			; ６２Ｈまで対応
	JNBE	INT21H_SKIP		;

	PUSH	BP			;
	MOV	BP,AX			; ＡＨ＝ファンクション番号
	SHR	BP,1			;1
	SHR	BP,1			;2
	SHR	BP,1			;3
	SHR	BP,1			;4
	SHR	BP,1			;5
	SHR	BP,1			;6
	SHR	BP,1			;7
	SHR	BP,1			;8
	SHL	BP,1			; word pointer.
	CALL	WORD PTR CS:INT21H_VEC_TBL[BP]
	POP	BP

INT21H_SKIP:
	IRET

	EVEN
INT21H_VEC_TBL	LABEL	WORD
	DW	OFFSET FUNC00		;
	DW	OFFSET FUNC01		;
	DW	OFFSET FUNC02		;
	DW	OFFSET FUNC03		;
	DW	OFFSET FUNC04		;
	DW	OFFSET FUNC05		;
	DW	OFFSET FUNC06		;
	DW	OFFSET FUNC07		;
	DW	OFFSET FUNC08		;
	DW	OFFSET FUNC09		;
	DW	OFFSET FUNC0A		;
	DW	OFFSET FUNC0B		;
	DW	OFFSET FUNC0C		;
	DW	OFFSET FUNC0D		;
	DW	OFFSET FUNC0E		;
	DW	OFFSET FUNC0F		;

	DW	OFFSET FUNC10		;
	DW	OFFSET FUNC11		;
	DW	OFFSET FUNC12		;
	DW	OFFSET FUNC13		;
	DW	OFFSET FUNC14		;
	DW	OFFSET FUNC15		;
	DW	OFFSET FUNC16		;
	DW	OFFSET FUNC17		;
	DW	OFFSET FUNC18		;
	DW	OFFSET FUNC19		;
	DW	OFFSET FUNC1A		;
	DW	OFFSET FUNC1B		;
	DW	OFFSET FUNC1C		;
	DW	OFFSET FUNC1D		;
	DW	OFFSET FUNC1E		;
	DW	OFFSET FUNC1F		;

	DW	OFFSET FUNC20		;
	DW	OFFSET FUNC21		;
	DW	OFFSET FUNC22		;
	DW	OFFSET FUNC23		;
	DW	OFFSET FUNC24		;
	DW	OFFSET FUNC25		;
	DW	OFFSET FUNC26		;
	DW	OFFSET FUNC27		;
	DW	OFFSET FUNC28		;
	DW	OFFSET FUNC29		;
	DW	OFFSET FUNC2A		;
	DW	OFFSET FUNC2B		;
	DW	OFFSET FUNC2C		;
	DW	OFFSET FUNC2D		;
	DW	OFFSET FUNC2E		;
	DW	OFFSET FUNC2F		;

	DW	OFFSET FUNC30		;
	DW	OFFSET FUNC31		;
	DW	OFFSET FUNC32		;
	DW	OFFSET FUNC33		;
	DW	OFFSET FUNC34		;
	DW	OFFSET FUNC35		;
	DW	OFFSET FUNC36		;
	DW	OFFSET FUNC37		;
	DW	OFFSET FUNC38		;
	DW	OFFSET FUNC39		;
	DW	OFFSET FUNC3A		;
	DW	OFFSET FUNC3B		;
	DW	OFFSET FUNC3C		;
	DW	OFFSET FUNC3D		;
	DW	OFFSET FUNC3E		;
	DW	OFFSET FUNC3F		;

	DW	OFFSET FUNC40		;
	DW	OFFSET FUNC41		;
	DW	OFFSET FUNC42		;
	DW	OFFSET FUNC43		;
	DW	OFFSET FUNC44		;
	DW	OFFSET FUNC45		;
	DW	OFFSET FUNC46		;
	DW	OFFSET FUNC47		;
	DW	OFFSET FUNC48		;
	DW	OFFSET FUNC49		;
	DW	OFFSET FUNC4A		;
	DW	OFFSET FUNC4B		;
	DW	OFFSET FUNC4C		;
	DW	OFFSET FUNC4D		;
	DW	OFFSET FUNC4E		;
	DW	OFFSET FUNC4F		;

	DW	OFFSET FUNC50		;
	DW	OFFSET FUNC51		;
	DW	OFFSET FUNC52		;
	DW	OFFSET FUNC53		;
	DW	OFFSET FUNC54		;
	DW	OFFSET FUNC55		;
	DW	OFFSET FUNC56		;
	DW	OFFSET FUNC57		;
	DW	OFFSET FUNC58		;
	DW	OFFSET FUNC59		;
	DW	OFFSET FUNC5A		;
	DW	OFFSET FUNC5B		;
	DW	OFFSET FUNC5C		;
	DW	OFFSET FUNC5D		;
	DW	OFFSET FUNC5E		;
	DW	OFFSET FUNC5F		;

	DW	OFFSET FUNC60		;
	DW	OFFSET FUNC61		;
	DW	OFFSET FUNC62		;
INT21H	ENDP


;	割込みからの復帰（キャリーフラグを返す）
;
;	ルーチン INT21H	へ戻らず、直接ＩＲＥＴを行う。
;	そのときキャリーフラグを返す。
;
;	用法）	JMP	IRETALL		; 割込みからの復帰

IRETALL	PROC	NEAR
	POP	BP			; ＲＥＴの復帰アドレスを取り除く

	MOV	BP,SP			;
	JB	IRETALL_1		; ｃｆがセットされているか
	AND	WORD PTR SS:[BP][4+2],0FFFEH ; cf reset.
	JMP	SHORT IRETALL_2		;
IRETALL_1:
	OR	WORD PTR SS:[BP][4+2],00001H ; cf set.
IRETALL_2:
	POP	BP			; 退避してあるＢＰを復帰する
	; SS:SP [  I P  ] +0		;
	;       [  C S  ] +2		;
	;       [ flags ] +4		;
	IRET				; 割込み終了
IRETALL	ENDP



;	プロセスからの復帰
;
;	ルーチン INT21H	へ戻らず、ＩＲＥＴによって
;	RET_ADDRESS（リターンアドレス／I21HRETにて設定）へ戻る
;
;	用法）	JMP	IRETEND		; プロセスからの復帰

IRETEND	PROC	NEAR
	POP	BP			; ＲＥＴの復帰アドレスを取り除く

	MOV	BP,SP			;
	PUSH	AX			;
	PUSH	DS			;
	MOV	AX,SEG DATA		;
	MOV	DS,AX			;
	MOV	AX,RET_OFFSET		; リターンオフセットアドレス
	MOV	WORD PTR SS:[BP][0+2],AX ; リターンオフセットアドレス
	MOV	AX,RET_SEG		; リターンセグメントアドレス
	MOV	WORD PTR SS:[BP][2+2],AX ; リターンセグメントアドレス
	POP	DS			;
	POP	AX			;

	POP	BP			; 退避してあるＢＰを復帰する
	; SS:SP [  I P  ] +0		;
	;       [  C S  ] +2		;
	;       [ flags ] +4		;
	IRET				; 割込み終了
IRETEND	ENDP


;	割込みからの復帰（ゼロフラグを返す）
;
;	ルーチン INT21H	へ戻らず、直接ＩＲＥＴを行う。
;	そのときゼロフラグを返す。
;
;	用法）	JMP	IRET_ZF		; 割込みからの復帰

IRET_ZF	PROC	NEAR
	POP	BP			; ＲＥＴの復帰アドレスを取り除く

	MOV	BP,SP			;
	JZ	IRET_ZF_1		; ｚｆがセットされているか
	AND	WORD PTR SS:[BP][4+2],0FFBFH ; zf reset.
	JMP	SHORT IRET_ZF_2		;
IRET_ZF_1:
	OR	WORD PTR SS:[BP][4+2],00040H ; zf set.
IRET_ZF_2:
	POP	BP			; 退避してあるＢＰを復帰する
	; SS:SP [  I P  ] +0		;
	;       [  C S  ] +2		;
	;       [ flags ] +4		;
	IRET				; 割込み終了
IRET_ZF	ENDP


;	プログラムの終了
;	-O- AX : 0=プロセス終了

FUNC00	PROC	NEAR
	MOV	AX,0			; 0=通常のプロセス終了
	JMP	IRETEND			; プロセスからの復帰
FUNC00	ENDP

FUNC01	PROC	NEAR
	RET
FUNC01	ENDP


;	１文字出力
;	-I- DL : 出力する文字

FUNC02	PROC	NEAR
	CALL	PUTCHRS			; １文字出力
	RET
FUNC02	ENDP


FUNC03	PROC	NEAR
	RET
FUNC03	ENDP

FUNC04	PROC	NEAR
	RET
FUNC04	ENDP

FUNC05	PROC	NEAR
	RET
FUNC05	ENDP


;	コンソール入出力
;	-I- DL : 0FFH ならば１文字入力 0FFH以外ならば
;	         DL=出力する文字
;	-O- AL : 入力文字

FUNC06	PROC	NEAR
	CMP	DL,0FFH			; 0FFH ならば１文字入力
	JE	FUNC06_GET		;

	CALL	PUTCHRS			; １文字出力
	RET

FUNC06_GET:
	CALL	GETCHRS			; １文字入力
	OR	AL,AL			; なければｚｆをＯＮにする
	JMP	IRET_ZF			; 割込みからの復帰（ゼロフラグを返す）
FUNC06	ENDP


FUNC07	PROC	NEAR
	RET
FUNC07	ENDP

FUNC08	PROC	NEAR
	RET
FUNC08	ENDP


;	文字列の出力

FUNC09	PROC	NEAR
	CALL	PRINTS			; 文字列の表示
	RET
FUNC09	ENDP


;	文字列の入力

FUNC0A	PROC	NEAR
	CALL	INPUTS			; 文字列の入力
	RET
FUNC0A	ENDP


FUNC0B	PROC	NEAR
	RET
FUNC0B	ENDP

FUNC0C	PROC	NEAR
	RET
FUNC0C	ENDP


;	ディスクのリセット

FUNC0D	PROC	NEAR
	CALL	DISK_RESET	; ディスクのリセット
	RET
FUNC0D	ENDP


FUNC0E	PROC	NEAR
	RET
FUNC0E	ENDP


;	ＦＣＢファイルオープン

FUNC0F	PROC	NEAR
	CALL	FCBOPEN		; ＦＣＢファイルオープン
	RET
FUNC0F	ENDP


;	ＦＣＢファイルクローズ

FUNC10	PROC	NEAR
	CALL	FCBCLOSE	; ＦＣＢファイルクローズ
	RET
FUNC10	ENDP


FUNC11	PROC	NEAR
	RET
FUNC11	ENDP

FUNC12	PROC	NEAR
	RET
FUNC12	ENDP

FUNC13	PROC	NEAR
	RET
FUNC13	ENDP


;	ＦＣＢファイルＲＥＡＤ

FUNC14	PROC	NEAR
	CALL	FCBREAD		; ＦＣＢファイルＲＥＡＤ
	RET
FUNC14	ENDP


FUNC15	PROC	NEAR
	RET
FUNC15	ENDP

FUNC16	PROC	NEAR
	RET
FUNC16	ENDP

FUNC17	PROC	NEAR
	RET
FUNC17	ENDP

FUNC18	PROC	NEAR
	RET
FUNC18	ENDP

FUNC19	PROC	NEAR
	RET
FUNC19	ENDP


;	ＤＴＡセット

FUNC1A	PROC	NEAR
	CALL	DTASET		; ＤＴＡのセット
	RET
FUNC1A	ENDP


FUNC1B	PROC	NEAR
	RET
FUNC1B	ENDP

FUNC1C	PROC	NEAR
	RET
FUNC1C	ENDP

FUNC1D	PROC	NEAR
	RET
FUNC1D	ENDP

FUNC1E	PROC	NEAR
	RET
FUNC1E	ENDP

FUNC1F	PROC	NEAR
	RET
FUNC1F	ENDP

FUNC20	PROC	NEAR
	RET
FUNC20	ENDP

FUNC21	PROC	NEAR
	RET
FUNC21	ENDP

FUNC22	PROC	NEAR
	RET
FUNC22	ENDP

FUNC23	PROC	NEAR
	RET
FUNC23	ENDP

FUNC24	PROC	NEAR
	RET
FUNC24	ENDP

FUNC25	PROC	NEAR
	RET
FUNC25	ENDP

FUNC26	PROC	NEAR
	RET
FUNC26	ENDP

FUNC27	PROC	NEAR
	RET
FUNC27	ENDP

FUNC28	PROC	NEAR
	RET
FUNC28	ENDP

FUNC29	PROC	NEAR
	RET
FUNC29	ENDP

FUNC2A	PROC	NEAR
	RET
FUNC2A	ENDP

FUNC2B	PROC	NEAR
	RET
FUNC2B	ENDP

FUNC2C	PROC	NEAR
	RET
FUNC2C	ENDP

FUNC2D	PROC	NEAR
	RET
FUNC2D	ENDP

FUNC2E	PROC	NEAR
	RET
FUNC2E	ENDP

FUNC2F	PROC	NEAR
	RET
FUNC2F	ENDP

FUNC30	PROC	NEAR
	RET
FUNC30	ENDP


;	プロセスの常駐
;	-O- DX : 確保パラグラフ値
;	    AX : 2=プロセスの常駐

FUNC31	PROC	NEAR
	MOV	AX,2			; 2=プロセスの常駐
	JMP	IRETEND			; プロセスからの復帰
FUNC31	ENDP

FUNC32	PROC	NEAR
	RET
FUNC32	ENDP

FUNC33	PROC	NEAR
	RET
FUNC33	ENDP

FUNC34	PROC	NEAR
	RET
FUNC34	ENDP

FUNC35	PROC	NEAR
	RET
FUNC35	ENDP


;	ディスクの空き容量
;	-I- DL : 0=カレントドライブ,1=A:,2=B:...
;	-O- AX : セクタ数／１クラスタ，ドライブが無効のときは FFFFh
;	    BX : 空きクラスタ数
;	    CX : バイト数／１セクタ
;	    DX : クラスタ数／１ドライブ

FUNC36	PROC	NEAR
	CALL	DSK_FRE_SPACE	; ディスクの空き容量
	RET
FUNC36	ENDP


FUNC37	PROC	NEAR
	RET
FUNC37	ENDP



FUNC38	PROC	NEAR
	RET
FUNC38	ENDP

FUNC39	PROC	NEAR
	RET
FUNC39	ENDP

FUNC3A	PROC	NEAR
	RET
FUNC3A	ENDP

FUNC3B	PROC	NEAR
	RET
FUNC3B	ENDP


;	ハンドルクリエイト

FUNC3C	PROC	NEAR
	CALL	HANDLECREATE		; ハンドルクリエイト
	JMP	IRETALL			; 割込みからの復帰
FUNC3C	ENDP


;	ハンドルのオープン

FUNC3D	PROC	NEAR
	CALL	HANDLEOPEN		; ハンドルオープン
	JMP	IRETALL			; 割込みからの復帰
FUNC3D	ENDP


;	ハンドルのクローズ

FUNC3E	PROC	NEAR
	CALL	HANDLECLOSE		; ハンドルクローズ
	JMP	IRETALL			; 割込みからの復帰
FUNC3E	ENDP


;	ハンドルのＲＥＡＤ

FUNC3F	PROC	NEAR
	CALL	HANDLEREAD		; ハンドルＲＥＡＤ
	JMP	IRETALL			; 割込みからの復帰
FUNC3F	ENDP


;	ハンドルのＷＲＩＴＥ

FUNC40	PROC	NEAR
	CALL	HANDLEWRITE		; ハンドルＷＲＩＴＥ
	JMP	IRETALL			; 割込みからの復帰
FUNC40	ENDP


;	ファイルの削除
;	-I- DS:DX : パス名
;	-O- cf    : off:正常,on:異常
;	    AX    : cf=on : 02H=指定パスが無効

FUNC41	PROC	NEAR
	CALL	DISK_KILL		; ファイルの削除
	JMP	IRETALL			; 割込みからの復帰
FUNC41	ENDP

;	ファイル・ポインタの移動

FUNC42	PROC	NEAR
	CALL	MOVFILEPTR		; ファイルポインタの移動
	JMP	IRETALL			; 割込みからの復帰
FUNC42	ENDP


FUNC43	PROC	NEAR
	RET
FUNC43	ENDP

FUNC44	PROC	NEAR
	RET
FUNC44	ENDP

FUNC45	PROC	NEAR
	RET
FUNC45	ENDP

FUNC46	PROC	NEAR
	RET
FUNC46	ENDP

FUNC47	PROC	NEAR
	RET
FUNC47	ENDP


;	メモリの割り当て
;	-I- BX       : 割り当てるメモリサイズ（パラグラフサイズ）
;	-O- cf       : off:正常,on:異常
;	    cf=0  AX : 割り当てられたフリーエリアの先頭セグメント
;	    cf=1  AX : 08H=空きメモリが足りない
;	    cf=1  BX : フリーエリアのサイズ（パラグラフサイズ）

FUNC48	PROC	NEAR
	CALL	PUSH_ALL		; ＰＵＳＨＡＬＬ

	CALL	CMFREC			; フリーエリアのサイズ
	CMP	BX,DX			; フリーエリアと割り当てるサイズ
	JNBE	FUNC48_ERROR		; (BX>DX)足りなければエラー

	CALL	CMMMAX			; メモリの上限

	CALL	CMFREE			; フリーエリアの開始位置

	MOV	SAVE_AX,ES		; フリーエリアの開始パラグラフ値

	CALL	POP_ALL			; ＰＯＰＡＬＬ
	CLC				; ｃｆ＝ｏｆｆ
	JMP	IRETALL			; 割込みからの復帰（キャリーフラグ）

FUNC48_ERROR:
	MOV	SAVE_BX,DX		; フリーエリアのサイズ
	MOV	SAVE_AX,08H		; 空きメモリが足りない

	CALL	POP_ALL			; ＰＯＰＡＬＬ
	STC				; ｃｆ＝ｏｎ
	JMP	IRETALL			; 割込みからの復帰（キャリーフラグ）
FUNC48	ENDP


;	メモリの開放
;	-I- ES : 開放するメモリのパラグラフ値

FUNC49	PROC	NEAR
	CALL	MEMCUT			; メモリの開放
	JMP	IRETALL			; 割込みからの復帰
FUNC49	ENDP


;	メモリの割り当ての変更
;	-I- ES       : メモリ領域のセグメント値
;	    BX       : 割り当てるメモリサイズ（パラグラフサイズ）
;	-O- cf       : off:正常,on:異常
;	    cf=1  AX : 08H=メモリが足りない
;	    cf=1  BX : 最大サイズ（パラグラフサイズ）

FUNC4A	PROC	NEAR
	CALL	PUSH_ALL		; ＰＵＳＨＡＬＬ

	CALL	CMMPSG			; ＰＳＰセグメントの取得
	MOV	DX,ES			; ＰＳＰセグメント値
	ADD	DX,BX			; 割り当てるメモリ（パラグラフサイズ）

	PUSH	DX			;
	CALL	CMMPEG			; プログラムの後ろエリアの取得
	POP	DX			;

	MOV	AX,ES			; ES=後ろエリアセグメント値
	CMP	DX,AX			; DX=ユーザの指定
	JB	FUNC4A_ERROR		; (DX<AX)足りなければエラー

	MOV	ES,DX			; フリーエリアの開始パラグラフ値
	CALL	CMFREE			; フリーエリアの開始位置

	CALL	POP_ALL			; ＰＯＰＡＬＬ
	CLC				; ｃｆ＝ｏｆｆ
	JMP	IRETALL			; 割込みからの復帰（キャリーフラグ）

FUNC4A_ERROR:
	CALL	CMMPEG			; プログラムの後ろエリアの取得
	MOV	BX,ES			; BX=後ろエリアセグメント値

	CALL	CMMPSG			; ＰＳＰセグメントの取得
	MOV	AX,ES			; AX=ＰＳＰセグメント値

	SUB	BX,AX			; BX = 必要なサイズ

	MOV	SAVE_BX,BX		; 最大サイズ（パラグラフサイズ）
	MOV	SAVE_AX,08H		; メモリが足りない

	CALL	POP_ALL			; ＰＯＰＡＬＬ
	STC				; ｃｆ＝ｏｎ
	JMP	IRETALL			; 割込みからの復帰（キャリーフラグ）
	RET
FUNC4A	ENDP



FUNC4B	PROC	NEAR
	RET
FUNC4B	ENDP


;	プロセスの終了
;	-O- AX : 0=プロセス終了

FUNC4C	PROC	NEAR
	MOV	AX,0			; 0=通常のプロセス終了
	JMP	IRETEND			; プロセスからの復帰
FUNC4C	ENDP


FUNC4D	PROC	NEAR
	RET
FUNC4D	ENDP

FUNC4E	PROC	NEAR
	RET
FUNC4E	ENDP

FUNC4F	PROC	NEAR
	RET
FUNC4F	ENDP



FUNC50	PROC	NEAR
	RET
FUNC50	ENDP

FUNC51	PROC	NEAR
	RET
FUNC51	ENDP

FUNC52	PROC	NEAR
	RET
FUNC52	ENDP

FUNC53	PROC	NEAR
	RET
FUNC53	ENDP

FUNC54	PROC	NEAR
	RET
FUNC54	ENDP

FUNC55	PROC	NEAR
	RET
FUNC55	ENDP

FUNC56	PROC	NEAR
	RET
FUNC56	ENDP

FUNC57	PROC	NEAR
	RET
FUNC57	ENDP

FUNC58	PROC	NEAR
	RET
FUNC58	ENDP

FUNC59	PROC	NEAR
	RET
FUNC59	ENDP

FUNC5A	PROC	NEAR
	RET
FUNC5A	ENDP

FUNC5B	PROC	NEAR
	RET
FUNC5B	ENDP

FUNC5C	PROC	NEAR
	RET
FUNC5C	ENDP

FUNC5D	PROC	NEAR
	RET
FUNC5D	ENDP

FUNC5E	PROC	NEAR
	RET
FUNC5E	ENDP

FUNC5F	PROC	NEAR
	RET
FUNC5F	ENDP

FUNC60	PROC	NEAR
	RET
FUNC60	ENDP

FUNC61	PROC	NEAR
	RET
FUNC61	ENDP


;	ＰＳＰアドレスの取得
;	-O- BX : ＰＳＰセグメント値

FUNC62	PROC	NEAR
	CALL	PSPGET		; ＰＳＰアドレスの取得
	RET
FUNC62	ENDP


; ***************************************************************
;	コンソール関係
; ***************************************************************

;	文字列の入力
;	-I- DS:DX : バッファ
;		+0:最大入力文字列（ＣＲも含む）
;		+1:実際の入力された文字数（ＣＲを含まない）
;	        +2:入力された文字列

INPUTS	PROC	NEAR
	CALL	PUSH_ALL			; ＰＵＳＨＡＬＬ

	MOV	AX,SAVE_DS			; ユーザレジスタＤＳ
	MOV	DS,AX				;

	MOV	SI,DX				;
	MOV	AX,SEG DATA			;
	MOV	ES,AX				;
	MOV	AL,DS:[SI]			; 文字列バッファへ最大文字数
	MOV	ES:LINEBUF,AL			; セット

	PUSH	DS				; ユーザのバッファのアドレスを
	PUSH	DX				; 退避

	MOV	AX,SEG DATA			; ＤＡＴＡセグメントセット
	MOV	DS,AX				;

	MOV	DX,OFFSET LINEBUF		; 文字列バッファ
	CALL	CCCIN				; console in.

	POP	DI				; ユーザのバッファ
	POP	ES				;

	MOV	SI,OFFSET LINEBUF		; 文字列バッファ

	INC	SI				;
	INC	DI				;
	MOV	CH,0				;
	MOV	CL,DS:[SI]			; 入力された文字の長さ
	ADD	CX,2				;
	REP	MOVSB				;

	CALL	POP_ALL				; ＰＯＰＡＬＬ
	RET
INPUTS	ENDP



;	文字列の表示
;	-I- DS:DX : 文字列 ('$':end of string)

PRINTS	PROC	NEAR
	CALL	PUSH_ALL			; ＰＵＳＨＡＬＬ

	MOV	ES,SAVE_DS			; ユーザレジスタＤＳ
	MOV	BX,SAVE_DX			; ユーザレジスタＤＸ

	;	ＰＲＩＮＴ

PRINTS1:					;
	MOV	DL,ES:[BX]			;
	CMP	DL,'$'				; end of string
	JE	PRINTS2				;
	CALL	CCCOUT				; print character.
	INC	BX				;
	JMP	PRINTS1				;
PRINTS2:					;

	CALL	POP_ALL				; ＰＯＰＡＬＬ
	RET
PRINTS	ENDP


;	１文字出力
;	-I- DL : 出力する文字

PUTCHRS	PROC	NEAR
	CALL	PUSH_ALL			; ＰＵＳＨＡＬＬ

	CALL	CCCOUT				; print character.

	CALL	POP_ALL				; ＰＯＰＡＬＬ
	RET
PUTCHRS	ENDP


;	１文字入力
;	-O- AL : 入力された文字

GETCHRS	PROC	NEAR
	CALL	PUSH_ALL			; ＰＵＳＨＡＬＬ

	CALL	CCCRD				; read key buffer.

	MOV	BYTE PTR SAVE_AX,DL		; character code. (NULL=none)

	CALL	POP_ALL				; ＰＯＰＡＬＬ
	RET
GETCHRS	ENDP


; ***************************************************************
;	ＦＣＢ関係
; ***************************************************************

FCB		EQU	0				;
FCB_D		EQU	0				; DB 1 DUP (0)
FCB_FILENAME	EQU	0+1				; DB 8 DUP (0)
FCB_TYP		EQU	0+1+8				; DB 3 DUP (0)
FCB_CB		EQU	0+1+8+3				; DW
FCB_RS		EQU	0+1+8+3+2			; DW
FCB_FS		EQU	0+1+8+3+2+2			; DD
FCB_DM		EQU	0+1+8+3+2+2+4			; DW
FCB_DT		EQU	0+1+8+3+2+2+4+2			; DW
FCB_SYS		EQU	0+1+8+3+2+2+4+2+2		; DB 8 DUP (0)
FCB_CR		EQU	0+1+8+3+2+2+4+2+2+8		; DB
FCB_RR		EQU	0+1+8+3+2+2+4+2+2+8+1		; DD
BPOINT		EQU	0+1+8+3+2+2+4+2+2+8+1+4		; file buffer point.
DS_SEG		EQU	0+1+8+3+2+2+4+2+2+8+1+4+2	; user data segment.


;	ＦＣＢファイルオープン
;	-I- DS:DX : 初期化されたユーザＦＣＢ
; 	-O- AL    : 0=正常, FFh=ファイルがない

FCBOPEN	PROC	NEAR
	PUSH	BX
	PUSH	CX
	PUSH	DX

	PUSH	DI
	PUSH	SI
	PUSH	BP
	PUSH	DS
	PUSH	ES

	PUSH	AX

	;	ユーザＦＣＢの初期設定

	MOV	SI,DX				;
	MOV	WORD PTR DS:[SI][FCB_RS],128	; ＲＳ（レコードサイズ）
	MOV	AL,BYTE PTR DS:[SI][FCB_D]	; Ｄ（ドライブ番号）
	MOV	AH,0				; ＡＸ＝ユーザのドライブ番号

	;	ファイル名の設定

	MOV	BX,SEG DATA			;
	MOV	ES,BX				;
	MOV	DI,OFFSET FCB_FILE_NAME		;
	MOV	SI,DX				; ＦＣＢアドレス
	ADD	SI,FCB_FILENAME			;
	MOV	CX,11				; ファイル名は１１文字
	REP	MOVSB				;

	;	ＤＡＴＡセグメントの設定

	MOV	BX,SEG DATA			;
	MOV	DS,BX				;

	;	ドライブ番号の設定


	MOV	SI,OFFSET FCB_FILE_NAME		; ファイル名

	CMP	AX,0				; AX=ドライブ番号(0=ｶﾚﾝﾄﾄﾞﾗｲﾌﾞ)
	JE	FCBOPEN02			;
	ADD	AL,'A'-1			; A<-1, B<-2, C<-3, D<-4

	MOV	FCB_FILE_DRV_NM,AL		; ドライブ名

	MOV	SI,OFFSET FCB_FILE_DRV_NM	; ドライブ名
FCBOPEN02:					;

	;	ＯＰＥＮ

	CALL	FFOPEN				; ファイルオープン
	CMP	AX,0 				; 0=正常, 1=該当ファイルがない
	JE	FCBOPEN2			; 2=ディスクエラー

	;	後処理

FCBOPEN_ERROR:					;
	MOV	AL,0FFH				; FFh=ファイルがない
FCBOPEN2:					;

	POP	BX				; ＡＨを戻す
	MOV	AH,BH				;

	POP	ES
	POP	DS
	POP	BP
	POP	SI
	POP	DI

	POP	DX
	POP	CX
	POP	BX
	RET
FCBOPEN	ENDP



;	ＦＣＢファイルクローズ
;	-I- DS:DX : オープン中のユーザＦＣＢ
; 	-O- AL    : 0=正常, FFh=クローズ出来ない

FCBCLOSE	PROC	NEAR
	PUSH	BX
	PUSH	CX
	PUSH	DX

	PUSH	DI
	PUSH	SI
	PUSH	BP
	PUSH	DS
	PUSH	ES

	PUSH	AX

	;	ＤＡＴＡセグメントの設定

	MOV	BX,SEG DATA			;
	MOV	DS,BX				;

	;	ＣＬＯＳＥ

	CALL	FFCLOS

	MOV	AL,0

	POP	BX				; ＡＨを戻す
	MOV	AH,BH				;

	POP	ES
	POP	DS
	POP	BP
	POP	SI
	POP	DI

	POP	DX
	POP	CX
	POP	BX

	RET
FCBCLOSE	ENDP


;	ＦＣＢファイルＲＥＡＤ
;	-I- DS:DX : オープン中のユーザＦＣＢ
; 	-O- AL    : 0=正常
;	          : 1=Ｅ．Ｏ．Ｆ（もう続きのデータは無い）
;	          : 2=ディスクエラー

FCBREAD	PROC	NEAR
	PUSH	BX
	PUSH	CX
	PUSH	DX

	PUSH	DI
	PUSH	SI
	PUSH	BP
	PUSH	DS
	PUSH	ES

	PUSH	AX

	MOV	SI,DX				;

	MOV	CX,WORD PTR DS:[SI][FCB_RS]	; ＲＳ（レコードサイズ）

	MOV	BX,SEG DATA			;
	MOV	DS,BX				;

	MOV	AX,DTA_SEG			; ＤＴＡアドレス
	MOV	ES,AX				;
	MOV	DI,DTA_OFFSET			;

	CALL	FFREAD				; ファイルの読み出し

	POP	BX				; ＡＨを戻す
	MOV	AH,BH				;

	POP	ES
	POP	DS
	POP	BP
	POP	SI
	POP	DI

	POP	DX
	POP	CX
	POP	BX

	RET
FCBREAD	ENDP


;	ＤＴＡのセット
;	-I- DS:DX : セットするＤＴＡのアドレス

DTASET	PROC	NEAR
	PUSH	BX
	PUSH	ES

	MOV	BX,SEG DATA			;
	MOV	ES,BX				;

	MOV	ES:DTA_SEG,DS			; ＤＴＡアドレスセグメント
	MOV	ES:DTA_OFFSET,DX		; ＤＴＡアドレスオフセット

	POP	ES
	POP	BX
	RET
DTASET	ENDP


;	立ち上がりドライブ番号の設定
;	-O- AX : 0=正常,1=ドライブ番号エラー,2=ディスクエラー

SRTDRV	PROC	NEAR
	MOV	AL,BYTE PTR LOAD_DRIVE	; ロードドライブ番号
	MOV	AH,0			;
	AND	AX,11B			;
	CALL	FFDRV			; カレントドライブ設定
	RET
SRTDRV	ENDP


;	ユーザドライブ番号の設定
;	-I- AX : １ＭＦＤドライブ番号（０ー３）
;	-O- AX : 0=正常,1=ドライブ番号エラー,2=ディスクエラー

USRDRV	PROC	NEAR
	AND	AX,11B		;
	CALL	FFDRV		; カレントドライブ設定
	RET
USRDRV	ENDP





; ***************************************************************
;	ファイルハンドル関係
; ***************************************************************

;	いまのところ、書き込み中／読み込み中の２つのハンドルのみ
;	サポートします。従って同時にオープンできるファイル数は
;	ＲＥＡＤ／ＷＲＩＴＥともに一つずつです。

HANDLE_R	EQU	101		; 読み込み中ハンドル
HANDLE_W	EQU	102		; 書き込み中ハンドル

;	ハンドルクリエイト
;	-I- DS:DX : ハンドル名
;	-O- cf    : off:正常,on:異常
; 	    AX    : cf=off: ファイルハンドル
;	          ; cf=on : 3=ハンドル名が無効

HANDLECREATE	PROC	NEAR
	PUSH	DS
	PUSH	ES
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	BP

	;	ハンドル名の設定

	MOV	BX,SEG DATA			;
	MOV	ES,BX				;
	MOV	DI,OFFSET HANDLE_NAME		; ハンドル名
	MOV	SI,DX				; DS:DX : ハンドル名
	MOV	CX,ES:HANDLE_LEN		; ハンドル名最大長さ
	REP	MOVSB				;

	;	ＤＡＴＡセグメントの設定

	MOV	BX,SEG DATA			;
	MOV	DS,BX				;

	MOV	SI,OFFSET HANDLE_NAME		; ハンドル名
	CALL	FWOPEN				; ファイルの書き込み開始

	CMP	AX,0 				; 0=正常 1=ディレクトリ空無し
	JNE	HANDLECREATE_ERROR		; 2=ディスクエラー
	MOV	AX,HANDLE_W			; 書き込み中ハンドル
	CLC					; cf off.
	JMP	HANDLECREATE_EXIT		;
HANDLECREATE_ERROR:
	MOV	AX,3				; 3=ハンドル名が無効
	STC					; error=cf.
HANDLECREATE_EXIT:
	POP	BP
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
	POP	ES
	POP	DS
	RET
HANDLECREATE	ENDP



;	ハンドルオープン
;	-I- DS:DX : ハンドル名
;	-O- cf    : off:正常,on:異常
; 	    AX    : cf=off: ファイルハンドル
;	          ; cf=on : 2=ファイルがない

HANDLEOPEN	PROC	NEAR
	PUSH	DS
	PUSH	ES
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	BP

	;	ハンドル名の設定

	MOV	BX,SEG DATA			;
	MOV	ES,BX				;
	MOV	DI,OFFSET HANDLE_NAME		; ハンドル名
	MOV	SI,DX				; DS:DX : ハンドル名
	MOV	CX,ES:HANDLE_LEN		; ハンドル名最大長さ
	REP	MOVSB				;

	;	ＤＡＴＡセグメントの設定

	MOV	BX,SEG DATA			;
	MOV	DS,BX				;

	MOV	SI,OFFSET HANDLE_NAME		; ハンドル名
	CALL	FFOPEN				; ファイルオープン

	CMP	AX,0 				; 0=正常, 1=該当ファイルがない
	JNE	HANDLEOPEN_ERROR		; 2=ディスクエラー
	MOV	AX,HANDLE_R			; 読み込み中ハンドル
	CLC					; cf off.
	JMP	HANDLEOPEN_EXIT			;
HANDLEOPEN_ERROR:
	MOV	AX,2				; 2=ファイルがない
	STC					; error=cf.
HANDLEOPEN_EXIT:
	POP	BP
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
	POP	ES
	POP	DS
	RET
HANDLEOPEN	ENDP


;	ハンドルクローズ
;	-I- BX : ファイルハンドル
;	-O- cf : off:正常,on:異常
;	    AX : cf=on : 6=ファイルハンドルが無効

HANDLECLOSE	PROC	NEAR
	PUSH	DS
	PUSH	ES
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	BP

	;	ＤＡＴＡセグメントの設定

	MOV	AX,SEG DATA			;
	MOV	DS,AX				;

	CMP	BX,HANDLE_R			; 読み込み中ハンドル
	JE	HANDLECLOSE_R			;
	CMP	BX,HANDLE_W			; 書き込み中ハンドル
	JE	HANDLECLOSE_W			;

	STC					; error=cf.
	MOV	AX,6				; 6=ファイルハンドルが無効
	JMP	HANDLECLOSE_EXIT		;
HANDLECLOSE_R:
	CALL	FFCLOS				; ファイルクローズ
	CLC					; cf off.
	MOV	AX,0				;
	JMP	HANDLECLOSE_EXIT		;
HANDLECLOSE_W:
	CALL	FWCLOS				; ファイルの書き込み終了
	CMP	AX,0				; 0=正常, 1=ディスクに空き無し
	JNE	HANDLECLOSE_ERROR		; 2=ディスクエラー
	CLC					; cf off.
	MOV	AX,0				;
	JMP	HANDLECLOSE_EXIT		;
HANDLECLOSE_ERROR:
	STC					; cf : off:正常,on:異常
	MOV	AX,6				; 6=ファイルハンドルが無効
HANDLECLOSE_EXIT:
	POP	BP
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
	POP	ES
	POP	DS
	RET
HANDLECLOSE	ENDP


;	ハンドルＲＥＡＤ
;	-I- DS:DX : バッファのアドレス
;	    CX    : 読み込みバイト数
;	    BX    : ファイルハンドル
;	-O- cf    : off:正常,on:異常
; 	    AX    : cf=off: 読み込めたバイト数。ＥＯＦならば０
;	          : cf=on : 6=ファイルハンドルが無効

HANDLEREAD	PROC	NEAR
	PUSH	DS
	PUSH	ES
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	BP

	CMP	BX,HANDLE_R			; 読み込み中ハンドル
	JNE	HANDLEREAD_HAND_ER		; ファイルハンドルが無効？


	MOV	AX,DS				;
	MOV	ES,AX				; データバッファのアドレス
	MOV	DI,DX				; データバッファのアドレス

	;	ＤＡＴＡセグメントの設定

	MOV	AX,SEG DATA			;
	MOV	DS,AX				;

	;	ＲＥＡＤ

	CALL	FFREAD				; ファイルの読み出し
	CMP	AX,2				; 2=ディスクエラー
	JE	HANDLEREAD_HAND_ER		;

	MOV	AX,DX				; 読み込み出来たバイト数
	CLC					; cf off.
	JMP	HANDLEREAD_EXIT			;
HANDLEREAD_HAND_ER:
	MOV	AX,6				; ファイルハンドルが無効
	STC					; error=cf.
HANDLEREAD_EXIT:
	POP	BP
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
	POP	ES
	POP	DS
	RET
HANDLEREAD	ENDP


;	ハンドルＷＲＩＴＥ
;	-I- DS:DX : データバッファのアドレス
;	    CX    : 書き込みバイト数
;	    BX    : ファイルハンドル
;	-O- cf    : off:正常,on:異常
; 	    AX    : cf=off: 書き込めたバイト数。
;	          : cf=on : 6=ファイルハンドルが無効

HANDLEWRITE	PROC	NEAR
	PUSH	DS
	PUSH	ES
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	BP

	CMP	BX,HANDLE_W			; 書き込み中ハンドル
	JNE	HANDLEWRITE_HAND_ER		; ファイルハンドルが無効？

	MOV	SI,DX				; データバッファのアドレス
	MOV	DX,DS				;

	;	ＤＡＴＡセグメントの設定

	MOV	AX,SEG DATA			;
	MOV	DS,AX				;

	;	ＷＲＩＴＥ

	PUSH	CX				;
	CALL	FWRITE				; ファイルの書き込み
	POP	CX				;
	CMP	AX,0				; 0=正常,1=ディスクに空き無し
	JNE	HANDLEWRITE_HAND_ER		; 2=ディスクエラー

	MOV	AX,CX				; 書き込めたバイト数。
	CLC					; cf off.
	JMP	HANDLEWRITE_EXIT		;
HANDLEWRITE_HAND_ER:
	MOV	AX,6				; ファイルハンドルが無効
	STC					; error=cf.
HANDLEWRITE_EXIT:
	POP	BP
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
	POP	ES
	POP	DS
	RET
HANDLEWRITE	ENDP


;	ファイルポインタの移動
;	-I- AL    : 移動モード （0:先頭から,1:現在位置から,2:終端から）
;	    BX    : ファイルハンドル
;	    CX:DX : 移動するバイト数
;	-O- cf    : off:正常,on:異常
;	    cf=off の場合
;	    DX:AX : 移動後の位置（先頭からのバイト数）
;	    cf=on  の場合
;	    AX    : 01H=移動モードが無効
;	          : 06H=ファイルハンドルがオープンされていない

MOVFILEPTR	PROC	NEAR
	PUSH	DS
	PUSH	ES
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	BP

	;	ＤＡＴＡセグメントの設定

	PUSH	AX
	MOV	AX,SEG DATA			;
	MOV	DS,AX				;
	POP	AX

	CMP	BX,HANDLE_R			; 読み込み中ハンドル
	JNE	MOVFILEPTR_ERROR_HANDLE		;

	;	ＳＥＥＫ

	CALL	FFSEEK				; ファイルポインタシーク
	CMP	AX,0				; 0=正常,1=移動モードが無効
	JNE	MOVFILEPTR_ERROR		; 6=オープンされていない

	MOV	AX,DX				; ファイル先頭からの位置
	MOV	DX,CX				; (long integer)

	CLC					; cf off.

	POP	BP
	POP	SI
	POP	DI
	POP	CX ;DX
	POP	CX
	POP	BX
	POP	ES
	POP	DS
	RET

MOVFILEPTR_ERROR:				;
	STC					; error=cf.
	JMP	MOVFILEPTR_EXIT			;
MOVFILEPTR_ERROR_HANDLE:			;
	MOV	AX,06H				; オープンされていない
	STC					; error=cf.
MOVFILEPTR_EXIT:				;
	POP	BP
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
	POP	ES
	POP	DS
	RET
MOVFILEPTR	ENDP


; ***************************************************************
;	プロセス関係
; ***************************************************************


;	メモリの開放
;	-I- ES : 開放するメモリのパラグラフ値

MEMCUT	PROC	NEAR
	PUSH	DS
	PUSH	ES
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	BP

	;	ＤＡＴＡセグメントの設定

	MOV	AX,SEG DATA
	MOV	DS,AX

					; ES=開放するメモリのパラグラフ値
	CALL	CMMCUT			; 使用エリアの開放（パラグラフ値）

	MOV	AX,0			;
	CLC				; cf off.
	POP	BP
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
	POP	ES
	POP	DS
	RET
MEMCUT	ENDP


;	ＰＳＰアドレスの取得
;	-O- BX : ＰＳＰセグメント値

PSPGET	PROC	NEAR
	CALL	PUSH_ALL		; ＰＵＳＨＡＬＬ

	CALL	CMMPSG			; ＰＳＰセグメントの取得
	MOV	SAVE_BX,ES		; ＰＳＰセグメント値

	CALL	POP_ALL			; ＰＯＰＡＬＬ
	RET
PSPGET	ENDP


;	ディスクの空き容量
;	-I- DL : 0=カレントドライブ,1=A:,2=B:...
;	-O- AX : セクタ数／１クラスタ，ドライブが無効のときは FFFFh
;	    BX : 空きクラスタ数
;	    CX : バイト数／１セクタ
;	    DX : クラスタ数／１ドライブ

DSK_FRE_SPACE	PROC	NEAR
	CALL	PUSH_ALL		; ＰＵＳＨＡＬＬ

	MOV	DH,0			;DX:0=カレントドライブ,1=A:,2=B:...
	CALL	FWFREE			; ディスクの空き容量
	CMP	AX,0			; 0=正常, 2=エラー
	JNE	DSK_FRE_SPACE_ERROR	;

	MOV	SAVE_AX,DI		; セクタ数／１クラスタ
	MOV	SAVE_BX,BX		; 空きクラスタ数
	MOV	SAVE_CX,CX		; バイト数／１セクタ
	MOV	SAVE_DX,DX		; クラスタ数／１ドライブ

	JMP	DSK_FRE_SPACE_EXIT
DSK_FRE_SPACE_ERROR:
	MOV	SAVE_AX,0FFFFH		;
	MOV	SAVE_BX,0		;
	MOV	SAVE_CX,0		;
	MOV	SAVE_DX,0		;
DSK_FRE_SPACE_EXIT:
	CALL	POP_ALL			; ＰＯＰＡＬＬ
	RET
DSK_FRE_SPACE	ENDP


;	ディスクのリセット

DISK_RESET	PROC	NEAR
	CALL	PUSH_ALL		; ＰＵＳＨＡＬＬ
	CALL	FWREST			; ディスクのリセット
	CALL	POP_ALL			; ＰＯＰＡＬＬ
	RET
DISK_RESET	ENDP


;	ファイルの削除
;	-I- DS:DX : パス名
;	-O- cf    : off:正常,on:異常
;	    AX    : cf=on : 02H=指定パスが無効

DISK_KILL	PROC	NEAR
	PUSH	DS
	PUSH	ES
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	BP

	;	ハンドル名の設定

	MOV	BX,SEG DATA			;
	MOV	ES,BX				;
	MOV	DI,OFFSET HANDLE_NAME		; ハンドル名
	MOV	SI,DX				; DS:DX : ハンドル名
	MOV	CX,ES:HANDLE_LEN		; ハンドル名最大長さ
	REP	MOVSB				;

	;	ＤＡＴＡセグメントの設定

	MOV	BX,SEG DATA			;
	MOV	DS,BX				;

	MOV	SI,OFFSET HANDLE_NAME		; ハンドル名
	CALL	FWKILL				; ファイルの削除
	CMP	AX,0				; 0=正常,1=該当ファイルがない
	JNE	DISK_KILL_ERROR			; 2=ディスクエラー

	CLC
	JMP	DISK_KILL_EXIT
DISK_KILL_ERROR:
	MOV	AX,02H				; 指定パスが無効
	STC					; error=cf.
DISK_KILL_EXIT:
	POP	BP
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
	POP	ES
	POP	DS
	RET
DISK_KILL	ENDP


; ***************************************************************
;	ＰＵＳＨＡ／ＰＯＰＡ
; ***************************************************************

;	ＰＵＳＨＡＬＬ
;	-O- SAVE_DS : ユーザレジスタＤＳ
;	    SAVE_AX : ユーザレジスタＡＸ
;	    SAVE_BX : ユーザレジスタＢＸ
;	    SAVE_CX : ユーザレジスタＣＸ
;	    SAVE_DX : ユーザレジスタＤＸ
;	    SAVE_DI : ユーザレジスタＤＩ
;	    SAVE_SI : ユーザレジスタＳＩ
;	    SAVE_BP : ユーザレジスタＢＰ
;	    DS      : ＤＡＴＡセグメント
;		ＤＳ以外のレジスタはユーザの値が保証される。

PUSH_ALL	PROC	NEAR
	PUSH	ES
	PUSH	AX
	MOV	AX,SEG DATA
	MOV	ES,AX
	MOV	ES:SAVE_DS,DS
	MOV	DS,AX
	POP	AX
	POP	ES

	MOV	SAVE_ES,ES
	MOV	SAVE_AX,AX
	MOV	SAVE_BX,BX
	MOV	SAVE_CX,CX
	MOV	SAVE_DX,DX
	MOV	SAVE_DI,DI
	MOV	SAVE_SI,SI
	MOV	SAVE_BP,BP

	RET
PUSH_ALL	ENDP


;	ＰＯＰＡＬＬ
;	-I- SAVE_DS : ユーザレジスタＤＳ
;	    SAVE_AX : ユーザレジスタＡＸ
;	    SAVE_BX : ユーザレジスタＢＸ
;	    SAVE_CX : ユーザレジスタＣＸ
;	    SAVE_DX : ユーザレジスタＤＸ
;	    SAVE_DI : ユーザレジスタＤＩ
;	    SAVE_SI : ユーザレジスタＳＩ
;	    SAVE_BP : ユーザレジスタＢＰ

POP_ALL		PROC	NEAR
	PUSH	DS

	PUSH	AX
	MOV	AX,SEG DATA
	MOV	DS,AX
	POP	AX

	MOV	ES,SAVE_ES
	MOV	AX,SAVE_AX
	MOV	BX,SAVE_BX
	MOV	CX,SAVE_CX
	MOV	DX,SAVE_DX
	MOV	DI,SAVE_DI
	MOV	SI,SAVE_SI
	MOV	BP,SAVE_BP

	POP	DS

	PUSH	ES
	PUSH	AX
	MOV	AX,SEG DATA
	MOV	ES,AX
	MOV	DS,ES:SAVE_DS
	POP	AX
	POP	ES

	RET
POP_ALL		ENDP

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

SAVE_VEC_INT21H_OFST	DW	0	; ＩＮＴ２１Ｈベクタオフセット退避
SAVE_VEC_INT21H_SEG	DW	0	; ＩＮＴ２１Ｈベクタセグメント退避

LOAD_DRIVE	DW	0		; ロードドライブ番号

;	コンソール関係

LINEBUF		DB	256 DUP (0)	; 文字列バッファ
		DB	0,0		;

;	プロセス関係

START_ADDRESS	LABEL	DWORD		; スタートアドレス
START_OFFSET	DW	0		; スタートオフセットアドレス
START_SEG	DW	0		; スタートセグメントアドレス

RET_ADDRESS	LABEL	DWORD		; リターンアドレス
RET_OFFSET	DW	0		; リターンオフセットアドレス
RET_SEG		DW	0		; リターンセグメントアドレス

SAVE_SP		DW	0		; スタックポインタ退避
SAVE_SS		DW	0		; スタックセグメント退避

SAVE_ES		DW	0		; ユーザレジスタＥＳ
SAVE_DS		DW	0		; ユーザレジスタＤＳ
SAVE_AX		DW	0		; ユーザレジスタＡＸ
SAVE_BX		DW	0		; ユーザレジスタＢＸ
SAVE_CX		DW	0		; ユーザレジスタＣＸ
SAVE_DX		DW	0		; ユーザレジスタＤＸ
SAVE_DI		DW	0		; ユーザレジスタＤＩ
SAVE_SI		DW	0		; ユーザレジスタＳＩ
SAVE_BP		DW	0		; ユーザレジスタＢＰ


;	ＦＣＢ関係

FCB_FILE_DRV_NM	DB	" :"		; ドライブ名
FCB_FILE_NAME	DB	8 DUP (0)	; ＦＣＢファイル名は８文字
FCB_FILE_ATR	DB	3 DUP (0)	; ＦＣＢ拡張子は３文字
		DB	0		; end of string.
DTA_SEG		DW	SEG DATA	; ＤＴＡアドレスセグメント
DTA_OFFSET	DW	OFFSET SYS_DTA	; ＤＴＡアドレスオフセット
SYS_DTA		DB	128 DUP (0)	; システムＤＡＴ


;	ハンドル関係

HANDLE_LEN	DW	128		; ハンドル名最大長さ
HANDLE_NAME	DB	128 DUP (0)	; ハンドル名
		DB	0,0		;


DATA	ENDS

	END

;
;	end of "INT21H.ASM"
;
