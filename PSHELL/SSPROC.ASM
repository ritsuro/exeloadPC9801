; "SSPROC.ASM" PC-9801UV11 make by R.H 1989/11/23
;	modify	1990/10/05 com prccess.
;
;	E X E L O A D     P R O C   c o m m a n d .
;
;
;
; command.

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:DATA

PUBLIC	CMPCOM			; 標準ＣＯＭプロセス
PUBLIC	CMPROC			; 標準ＤＯＳプロセス

EXTRN	I21HRET:NEAR		; プロセスへの戻りアドレス設定

EXTRN	CMMINT:NEAR		; メモリ管理初期化
EXTRN	CMFREE:NEAR		; フリーエリアの開始位置
EXTRN	CMMALC:NEAR		; 使用エリアの確保
EXTRN	CMMCUT:NEAR		; 使用エリアの開放
EXTRN	CMMFST:NEAR		; 使用エリアの設定
EXTRN	CMMPSP:NEAR		; ＰＳＰセグメントの設定
EXTRN	CMMPSG:NEAR		; ＰＳＰセグメントの取得
EXTRN	CMMPES:NEAR		; プログラムの後ろエリアの設定
EXTRN	CMMPEG:NEAR		; プログラムの後ろエリアの取得
EXTRN	CMMPFR:NEAR		; プログラムエリアの開放
EXTRN	CMMMAX:NEAR		; メモリの上限


RETFAR	MACRO			; ＦＡＲリターン
	DB	11001011B	; RETF
	ENDM



;	標準ＣＯＭプロセス
;	-I- BX : 標準ＤＯＳプロセスのヘッダアドレス先頭
;	    DX : 標準ＤＯＳ実行ファイルのロードアドレス先頭
;	    ES : 標準ＤＯＳ実行ファイルのロード後フリーエリア

CMPCOM	PROC	NEAR
	MOV	TOP_SEG,BX	; 先頭セグメントアドレス
	MOV	HEAD_SEG,BX	; 標準ＤＯＳプロセスのヘッダアドレス先頭
	MOV	LOAD_SEG,DX	; 標準ＤＯＳ実行ファイルのロードアドレス先頭
	MOV	FREE_SEG,ES	; 標準ＤＯＳ実行ファイルのロード後フリーエリア

	CALL	COM_PROCESS	; 標準ＣＯＭプロセスの実行
	RET
CMPCOM	ENDP


;	標準ＣＯＭプロセスの実行
;	-I-  TOP_SEG : 先頭セグメントアドレス
;	     FREE_SEG: 標準ＤＯＳ実行ファイルのロード後フリーエリア

COM_PROCESS	PROC	NEAR
	MOV	DX,TOP_SEG		; 先頭セグメントアドレス
	CALL	CMMPSP			; ＰＳＰセグメントの設定

	MOV	DX,FREE_SEG		; 確保パラグラフ値
	CALL	CMMPES			; プログラムの後ろエリアの設定

	CALL	CMMMAX			; メモリの上限
	MOV	DX,ES			; 最大取る
	CALL	CMMFST			; 使用エリアの設定

	MOV	AX,OFFSET COM_PROCESS_INTER	; 戻りオフセットアドレス
	MOV	DX,SEG CODE			; 戻りセグメントアドレス
	CALL	I21HRET			; プロセスへの戻りアドレス設定

	MOV	EXE_SAVE_SS,SS		; スタックの退避
	MOV	EXE_SAVE_SP,SP		;

	CLI				; 割り込み禁止
	MOV	SS,TOP_SEG		; 先頭セグメントアドレス
	MOV	SP,0FFFEH		; スタックポインタ（ＳＰ）初期値

	MOV	AX,TOP_SEG		; 先頭セグメントアドレス
	MOV	START_SEG,AX		; スタートセグメントアドレス

	MOV	AX,100H			; インストラクションポインタの初期値
	MOV	START_OFFSET,AX		; スタートオフセットアドレス

	PUSH	START_SEG		; スタートセグメントアドレス
	PUSH	START_OFFSET		; スタートオフセットアドレス

	MOV	AX,START_SEG		; データセグメント
	MOV	ES,AX			;
	MOV	DS,AX			;

	STI				; 割り込み許可
	RETFAR				; プロセスへのジャンプ

COM_PROCESS_INTER:			; プロセスの戻りアドレス
	MOV	CX,SEG DATA		;
	MOV	DS,CX			;

	CLI				;
	MOV	SS,EXE_SAVE_SS		; スタックの復帰
	MOV	SP,EXE_SAVE_SP		;
	STI				;

	CMP	AX,1			; 1=メモリの開放
	JE	COM_PROCESS_FREE	;
	CMP	AX,2			; プロセスの常駐
	JE	COM_PROCESS_KEEP	;
	JMP	COM_PROCESS_END		;

COM_PROCESS_KEEP:			; DX=確保パラグラフ値
	CALL	CMMALC			; 使用エリアの確保（パラグラフ値）
	JMP	COM_PROCESS_EXIT	;

COM_PROCESS_FREE:			; ES=開放するメモリのパラグラフ値
	CALL	CMMCUT			; 使用エリアの開放（パラグラフ値）
	JMP	COM_PROCESS_EXIT	;

COM_PROCESS_END:			;
	CALL	CMMPFR			; プログラムエリアの開放

COM_PROCESS_EXIT:
	RET
COM_PROCESS	ENDP




;	標準ＤＯＳプロセス
;	-I- BX : 標準ＤＯＳプロセスのヘッダアドレス先頭
;	    DX : 標準ＤＯＳ実行ファイルのロードアドレス先頭
;	    ES : 標準ＤＯＳ実行ファイルのロード後フリーエリア

CMPROC	PROC	NEAR
	MOV	HEAD_SEG,BX	; 標準ＤＯＳプロセスのヘッダアドレス先頭
	MOV	LOAD_SEG,DX	; 標準ＤＯＳ実行ファイルのロードアドレス先頭
	MOV	FREE_SEG,ES	; 標準ＤＯＳ実行ファイルのロード後フリーエリア

	CALL	PARASET		; 標準ＤＯＳプロセスパラメータセット
	CALL	EXEC_RELOC	; 標準ＤＯＳ実行ファイルのリロケーション
	CALL	EXEC_PROCESS	; 標準ＤＯＳ用プロセスの実行
	RET
CMPROC	ENDP



;	標準ＤＯＳ実行ファイルのリロケーション
;	-I- LOAD_SEG  : 標準ＤＯＳ実行ファイルのロードアドレス先頭
;	-O- TOP_SEG   : 先頭セグメントアドレス

EXEC_RELOC	PROC	NEAR
			; 標準ＤＯＳ実行ファイルのロードアドレス先頭
	MOV	AX,LOAD_SEG
			; ヘッダの大きさ（パラグラフ数／16byte単位）
	ADD	AX,EXE_HEAD_SIZE
	MOV	TOP_SEG,AX
			; 先頭セグメントアドレス


			; リロケーション情報のオフセット
	MOV	BX,EXE_RELOC_OFSET
			; リロケートの計算を必要とするアドﾚｽ値の個数
	MOV	CX,EXE_RELOC_CNT
	JCXZ	EXEC_RELOC_SKIP
EXEC_RELOC2:
			; 標準ＤＯＳ実行ファイルのロードアドレス先頭
	MOV	AX,LOAD_SEG
	MOV	ES,AX

	MOV	DI,ES:[BX] ; リロケート対象のアドレス（オフセット）
	INC	BX
	INC	BX
	MOV	AX,ES:[BX] ; リロケート対象のアドレス（セグメント）
	ADD	AX,TOP_SEG ; 先頭セグメントアドレス
	MOV	ES,AX
	INC	BX
	INC	BX

	MOV	AX,TOP_SEG	; 先頭セグメントアドレス
	ADD	WORD PTR ES:[DI],AX

	LOOP	EXEC_RELOC2
EXEC_RELOC_SKIP:

	RET
EXEC_RELOC	ENDP


;	標準ＤＯＳ用プロセスの実行
;	-I-  TOP_SEG : 先頭セグメントアドレス
;	     HEAD_SEG: 標準ＤＯＳプロセスのヘッダアドレス先頭
;	     FREE_SEG: 標準ＤＯＳ実行ファイルのロード後フリーエリア

EXEC_PROCESS	PROC	NEAR
	MOV	DX,HEAD_SEG		; ＰＳＰセグメント値
	CALL	CMMPSP			; ＰＳＰセグメントの設定

	MOV	DX,FREE_SEG		; 確保パラグラフ値
	CALL	CMMPES			; プログラムの後ろエリアの設定

	MOV	DX,FREE_SEG		; 確保パラグラフ値
	CALL	CMMFST			; 使用エリアの設定

	MOV	AX,OFFSET EXEC_PROCESS_INTER	; 戻りオフセットアドレス
	MOV	DX,SEG CODE		; 戻りセグメントアドレス
	CALL	I21HRET			; プロセスへの戻りアドレス設定

	MOV	EXE_SAVE_SS,SS		; スタックの退避
	MOV	EXE_SAVE_SP,SP		;

	CLI				; 割り込み禁止
	MOV	AX,TOP_SEG		; 先頭セグメントアドレス
	ADD	AX,EXE_SS		; スタックセグメン（ＳＳ）初期値
	MOV	SS,AX			;
	MOV	SP,EXE_SP		; スタックポインタ（ＳＰ）初期値

	MOV	AX,TOP_SEG		; 先頭セグメントアドレス
	ADD	AX,EXE_CS		; コードセグメント（ＣＳ）の初期値
	MOV	START_SEG,AX		; スタートセグメントアドレス

	MOV	AX,EXE_IP		; インストラクションポインタの初期値
	MOV	START_OFFSET,AX		; スタートオフセットアドレス

	PUSH	START_SEG		; スタートセグメントアドレス
	PUSH	START_OFFSET		; スタートオフセットアドレス

	MOV	AX,HEAD_SEG		; 標準ＤＯＳプロセスのヘッダアドレス		MOV	ES,AX			;
	MOV	DS,AX			;

	STI				; 割り込み許可
	RETFAR				; プロセスへのジャンプ

EXEC_PROCESS_INTER:			; プロセスの戻りアドレス
	MOV	CX,SEG DATA		;
	MOV	DS,CX			;

	CLI				;
	MOV	SS,EXE_SAVE_SS		; スタックの復帰
	MOV	SP,EXE_SAVE_SP		;
	STI				;

	CMP	AX,1			; 1=メモリの開放
	JE	EXEC_PROCESS_FREE	;
	CMP	AX,2			; プロセスの常駐
	JE	EXEC_PROCESS_KEEP	;
	JMP	EXEC_PROCESS_END	;

EXEC_PROCESS_KEEP:			; DX=確保パラグラフ値
	CALL	CMMALC			; 使用エリアの確保（パラグラフ値）
	JMP	COM_PROCESS_EXIT	;

EXEC_PROCESS_FREE:			; ES=開放するメモリのパラグラフ値
	CALL	CMMCUT			; 使用エリアの開放（パラグラフ値）
	JMP	COM_PROCESS_EXIT	;

EXEC_PROCESS_END:			;
	CALL	CMMPFR			; プログラムエリアの開放

EXEC_PROCESS_EXIT:
	RET
EXEC_PROCESS	ENDP


;	標準ＤＯＳプロセスパラメータセット
;	-I- LOAD_SEG ; 標準ＤＯＳ実行ファイルのロードアドレス先頭

PARASET	PROC	NEAR
	MOV	AX,LOAD_SEG
	MOV	ES,AX
	MOV	SI,0

	MOV	AX,WORD PTR ES:[SI][00H]
	MOV	EXE_MARK,AX	; ４Ｄｈ，５Ａｈマーク（標準ＤＯＳ）
	MOV	AX,WORD PTR ES:[SI][02H]
	MOV	EXE_END_BYTE,AX	; 最終ページ（512byte単位）の有効バイト数
	MOV	AX,WORD PTR ES:[SI][04H]
	MOV	EXE_PAGE,AX	; ページ数（512byte単位）
	MOV	AX,WORD PTR ES:[SI][06H]
	MOV	EXE_RELOC_CNT,AX ; リロケートの計算を必要とするアドﾚｽ値の個数
	MOV	AX,WORD PTR ES:[SI][08H]
	MOV	EXE_HEAD_SIZE,AX ; ヘッダの大きさ（パラグラフ数／16byte単位）
	MOV	AX,WORD PTR ES:[SI][0AH]
	MOV	EXE_HEEP_MIN,AX	; ヒープエリアの最小数
	MOV	AX,WORD PTR ES:[SI][0CH]
	MOV	EXE_HEEP_MAX,AX	; ヒープエリアの最大数
	MOV	AX,WORD PTR ES:[SI][0EH]
	MOV	EXE_SS,AX	; スタックセグメント（ＳＳ）初期値
	MOV	AX,WORD PTR ES:[SI][10H]
	MOV	EXE_SP,AX	; スタックポインタ（ＳＰ）初期値
	MOV	AX,WORD PTR ES:[SI][12H]
	MOV	EXE_SUM,AX	; チェックサム
	MOV	AX,WORD PTR ES:[SI][14H]
	MOV	EXE_IP,AX	; インストラクションポインタ（ＩＰ）の初期値
	MOV	AX,WORD PTR ES:[SI][16H]
	MOV	EXE_CS,AX	; コードセグメント（ＣＳ）の初期値
	MOV	AX,WORD PTR ES:[SI][18H]
	MOV	EXE_RELOC_OFSET,AX ; リロケーション情報のオフセット
	MOV	AX,WORD PTR ES:[SI][1AH]
	MOV	EXE_OVERLAY_NUM,AX ; 標準ＤＯＳオーバレイ番号
	RET
PARASET	ENDP


;	標準ＤＯＳ用ＩＮＴベクトルの設定
;

INTSET	PROC	NEAR
	RET
INTSET	ENDP



;	標準ＤＯＳ用ＩＮＴベクトルを設定以前に戻す
;

INTRESET	PROC	NEAR
	RET
INTRESET	ENDP



CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

EXE_SAVE_SS	DW	0	; スタックセグメント退避
EXE_SAVE_SP	DW	0	; スタックポインタ退避



EXE_MARK	DW 0	; ４Ｄｈ，５Ａｈマーク（標準ＤＯＳ）
EXE_END_BYTE	DW 0	; 最終ページ（512byte単位）の有効バイト数
EXE_PAGE	DW 0	; ページ数（512byte単位）
EXE_RELOC_CNT	DW 0	; リロケートの計算を必要とするアドﾚｽ値の個数
EXE_HEAD_SIZE	DW 0	; ヘッダの大きさ（パラグラフ数／16byte単位）
EXE_HEEP_MIN	DW 0	; ヒープエリアの最小数
EXE_HEEP_MAX	DW 0	; ヒープエリアの最大数
EXE_SS		DW 0	; スタックセグメント（ＳＳ）初期値
EXE_SP		DW 0	; スタックポインタ（ＳＰ）初期値
EXE_SUM		DW 0	; チェックサム
EXE_IP		DW 0	; インストラクションポインタ（ＩＰ）の初期値
EXE_CS		DW 0	; コードセグメント（ＣＳ）の初期値
EXE_RELOC_OFSET	DW 0	; リロケーション情報のオフセット
EXE_OVERLAY_NUM	DW 0	; 標準ＤＯＳオーバレイ番号


HEAD_SEG	DW 0	; 標準ＤＯＳプロセスのヘッダアドレス先頭
LOAD_SEG	DW 0	; 標準ＤＯＳ実行ファイルのロードアドレス先頭
FREE_SEG	DW 0	; 標準ＤＯＳ実行ファイルのロード後フリーエリア

TOP_SEG		DW 0	; 先頭セグメントアドレス

START_ADDRESS	LABEL	DWORD	; スタートアドレス
START_OFFSET	DW 0	; スタートオフセットアドレス
START_SEG	DW 0	; スタートセグメントアドレス



DATA	ENDS
	END
;
;	end of "SSPROC.ASM"
;
