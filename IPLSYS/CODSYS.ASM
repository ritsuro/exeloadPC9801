; "CODSYS.ASM" PC-9801UV11 make by R.H 1989/12/01
;	modify	ver0.23 1990/10/04
;
;	E X E L O A D    I P L   k i t .
;
;	s y s t e m    c o d e .
;
;	システムコード（ＥＸＥＬＯＡＤ．ＳＹＳ）
;
;	1990/07/15 ＥＰＳＯＮ製ＰＣ－３８６Ｍのドライブ対策で
;	　　FDDOOR（ＦＤドライブドア開閉チェック）のセンスコマンド(04H)を
;	　　新センスコマンド(84H)に変更したが双方ともバグらしきもの
;	　　がある為、強制的にディスクを読ませるステータスを返すようにした。
;
;
;	このファイル(CODSYS.ASM)以外でセグメント CODSYS を使用しない事。
;

CODSYS	SEGMENT	PUBLIC	'CODSYS'
	ASSUME	CS:CODSYS,DS:CODSYS

PUBLIC	SYSTOP				; システムコードの先頭
PUBLIC	SYSEND				; システムコードの終わり

;	システムソースコード

SYSTOP	LABEL	FAR			; システムコードの先頭

SEC_BYTE	EQU	1024		; セクタバイト数
CHR_LF		EQU	0AH		; ＬＦ
TEXT_TOP	EQU	0		; テキストＶＲＡＭオフセット
TEXT_ADDRESS	EQU	0A000H		; テキストＶＲＡＭセグメント
EXELOAD_TOP_SEG	EQU	60H		; このシステムの先頭セグメント


;　ここが、ＣＳ＝６０Ｈ，ＩＰ＝０番地になるようにロードして下さい
;　６０Ｈ＋システムサイズのパラグラフを、ロードセグメントとします
;　ジャンプ前にＤＸにロードドライブ番号（０ー３）をセットして下さい
;　ちなみにＩＰＬではＤＡ／ＵＡをセットしています

EXELOAD:
	CLI				;
	MOV	AX,CS			;
	MOV	DS,AX			;
	MOV	SEG_DATA,AX		; データセグメント
	MOV	SEG_CHASHB,AX		; ディスクキャッシュバッファ
	MOV	SS,AX			; スタックポインタ
	MOV	SP,OFFSET SYS_STACK_TOP	;
	STI				;

	MOV	LOAD_DRIVE,DX		; ロードドライブ番号（あなたが指定）


	; ＥＸＥＬＯＡＤ．ＳＹＳからＰＳＨＥＬＬ．ＥＸＥへ
	; カレントドライブ番号受渡しの為、
	; ＩＮＴ２２ｈのベクターテーブルを使います。
	; あまり、美しい方法ではないので必要ないときは
	; 外して下さい。
	;		ｖｅｃｔｏｒ２２Ｈ　ｏｆｆｓｅｔ＝（カレントドライブ）
	;		ｖｅｃｔｏｒ２２Ｈ　ｓｅｇｍｅｎｔ＝６５３２１

	MOV	AX,0			;
	MOV	ES,AX			;
	MOV	AX,LOAD_DRIVE		; ロードドライブ番号
	MOV	ES:[22H*4+2],AX		; seg.
	MOV	AX,65321		; パスワード６５３２１
	MOV	ES:[22H*4],AX		; ofs.


	CALL	INT21HSET		; ＩＮＴ２１Ｈの設定

	CALL	ALOC_LOAD_SEG		; ロードセグメントの決定
	CALL	ALOC_SYS_SEG		; システム入れ換えセグメントの決定

	CALL	SYSSTART		; ＰＳＨＥＬＬ．ＥＸＥの実行

	CALL	EXESTART		; ＡＵＴＯＥＸＥＣ．ＥＸＥの実行

	MOV	SI,OFFSET MESSAGE_TOP	; エラー時のメッセージ出力
	CALL	PRINT			;
MUGEN:					; 停止
	JMP	MUGEN			;


		DW	64 DUP (0)	; システムスタックセグメント
SYS_STACK_TOP	LABEL	WORD		;


;	標準ＤＯＳ用プロセスの実行
;	-I- TOP_LOAD_SEG  : ロード時先頭セグメントアドレス
;	    TOP_RELOC_SEG : リロケート時先頭セグメントアドレス
;	    PROC_SIZE_LOW : 標準ＤＯＳ実行ファイルのサイズ(LOW)
;	    PROC_SIZE_HI  : 標準ＤＯＳ実行ファイルのサイズ(HI)

EXEC_PROCESS	PROC	NEAR

	;	コード転送

	MOV	AX,TOP_LOAD_SEG		; ロード時先頭セグメントアドレス
	CMP	AX,TOP_RELOC_SEG	; リロケート時先頭セグメントアドレス
	JE	EXEC_PROCESS_SET	;

	MOV	CX,PROC_SIZE_HI		; 標準ＤＯＳ実行ファイルのサイズ(HI)
	JCXZ	EXEC_PROCESS_2		;
	PUSH	DS			;
	MOV	ES,TOP_RELOC_SEG	; リロケート時先頭セグメントアドレス
	MOV	AX,TOP_LOAD_SEG		; ロード時先頭セグメントアドレス
	MOV	DS,AX			;
EXEC_PROCESS_1:				;
	PUSH	CX			;
	MOV	CX,8000H		;
	REP	MOVSW			;
	MOV	AX,ES			;
	ADD	AX,1000H		;
	MOV	ES,AX			;
	MOV	AX,DS			;
	ADD	AX,1000H		;
	MOV	DS,AX			;
	POP	CX			;
	LOOP	EXEC_PROCESS_1		;
	POP	DS			;

EXEC_PROCESS_2:				;
	PUSH	DS			;
	MOV	SI,0			;
	MOV	DI,0			;
	MOV	CX,PROC_SIZE_LOW	; 標準ＤＯＳ実行ファイルのサイズ(LOW)
	MOV	ES,TOP_RELOC_SEG	; リロケート時先頭セグメントアドレス
	MOV	AX,TOP_LOAD_SEG		; ロード時先頭セグメントアドレス
	MOV	DS,AX			;
	REP	MOVSB			;
	POP	DS			;


	;	各ポインタ設定

EXEC_PROCESS_SET:			;
	MOV	AX,SS			;
	MOV	EXE_SAVE_SS,AX		;
	MOV	AX,SP			;
	MOV	EXE_SAVE_SP,AX		;

	CLI				; 割り込み禁止

	MOV	AX,TOP_RELOC_SEG	; リロケート時先頭セグメントアドレス
	ADD	AX,EXE_SS		; スタックセグメン（ＳＳ）初期値
	MOV	SS,AX			;

	MOV	AX,EXE_SP		; スタックポインタ（ＳＰ）初期値
	MOV	SP,AX			;

	MOV	AX,TOP_RELOC_SEG	; リロケート時先頭セグメントアドレス
	ADD	AX,EXE_CS		; コードセグメント（ＣＳ）の初期値
	MOV	START_SEG,AX		; スタートセグメントアドレス

	MOV	AX,EXE_IP	; インストラクションポインタ（ＩＰ）の初期値
	MOV	START_OFFSET,AX	; スタートオフセットアドレス


	;	実行コードへジャンプ

	STI				; 割り込み許可
	JMP	DWORD PTR START_ADDRESS	; スタートアドレス

EXEC_PROCESS	ENDP



EXE_SAVE_SS	DW 0	; スタックセグメント退避
EXE_SAVE_SP	DW 0	; スタックポインタ退避

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


LOAD_SEG	DW 0	; 標準ＤＯＳ実行ファイルのロードアドレス先頭
RELOC_SEG	DW 0	; 標準ＤＯＳ実行ファイルのリロケートアドレス先頭

TOP_LOAD_SEG	DW 0	; ロード時先頭セグメントアドレス
TOP_RELOC_SEG	DW 0	; リロケート時先頭セグメントアドレス

PROC_SIZE	LABEL	DWORD ; 標準ＤＯＳ実行ファイルのサイズ
PROC_SIZE_LOW	DW 0	; 標準ＤＯＳ実行ファイルのサイズ(LOW)
PROC_SIZE_HI	DW 0	; 標準ＤＯＳ実行ファイルのサイズ(HI)

START_ADDRESS	LABEL	DWORD	; スタートアドレス
START_OFFSET	DW 0	; スタートオフセットアドレス
START_SEG	DW 0	; スタートセグメントアドレス



;	もし新システムへの入れ換えが行われるならば
;	ここから先のエリアは、切り放されます。（オーバライト）

SYSNEW_LOAD_START	LABEL	BYTE	; 新システムのロードアドレス




;	システム入れ換えセグメントの決定
;	-O- LOADSYS_SEGMENT : ロード新システムセグメント

ALOC_SYS_SEG	PROC	NEAR
	MOV	BX,OFFSET SYSNEW_LOAD_START	; 新システムのロードアドレス
	SUB	BX,OFFSET SYSTOP		; システムの先頭
	INC	BX			;
	MOV	AX,BX			;
	SHR	BX,1			; / 16
	SHR	BX,1			;
	SHR	BX,1			;
	SHR	BX,1			;
	AND	AX,0FH			;
	JZ	ALOC_SYS_SEG2		;
	INC	BX			;
ALOC_SYS_SEG2:				; この値がこのシステムの
					; パラグラフサイズ

	ADD	BX,EXELOAD_TOP_SEG	; このシステムの先頭セグメント
	MOV	LOADSYS_SEGMENT,BX	; ロード新システムセグメント
	RET
ALOC_SYS_SEG	ENDP


;	ロードセグメントの決定
;	-O- LOAD_SEGMENT : ロードセグメント

ALOC_LOAD_SEG	PROC	NEAR
	MOV	BX,OFFSET SYSEND_ALL	; システムの終わり（バッファ含む）
	SUB	BX,OFFSET SYSTOP	; システムの先頭
	INC	BX			;
	MOV	AX,BX			;
	SHR	BX,1			; / 16
	SHR	BX,1			;
	SHR	BX,1			;
	SHR	BX,1			;
	AND	AX,0FH			;
	JZ	ALOC_LOAD_SEG2		;
	INC	BX			;
ALOC_LOAD_SEG2:				; この値がこのシステムの
					; パラグラフサイズ

	ADD	BX,EXELOAD_TOP_SEG	; このシステムの先頭セグメント
	MOV	LOAD_SEGMENT,BX		; ロードセグメント
	RET
ALOC_LOAD_SEG	ENDP


;	ＰＳＨＥＬＬ．ＥＸＥの実行

SYSSTART	PROC	NEAR
	CALL	SRTDRV			; 立ち上がりドライブ番号の設定
	CMP	AX,0			; 0=正常, 2=ディスクエラー
	JNE	SYSSTART_EXIT

	MOV	SI,OFFSET SYS_FILE_NAME	; ＳＹＳＴＥＭファイル名
	MOV	AX,LOAD_SEGMENT		; ロードセグメント
	MOV	ES,AX			; フリーエリアの開始位置
	CALL	CMLOAD			; ＬＯＡＤ

	CMP	AX,0			; 0=正常
	JNE	SYSSTART_EXIT		; 1=該当ファイル無し, 2=ディスクエラー

	MOV	AX,DX			; 読み込みファイル長さ(HI)
					; AX:CX 実行ファイルのサイズ
	MOV	DX,LOAD_SEGMENT 	; 実行ファイルのロードアドレス
	MOV	BX,LOADSYS_SEGMENT	; 実行ファイルのリロケートアドレス
	CALL	CMPROC			; 標準ＤＯＳプロセス

SYSSTART_EXIT:
	RET
SYSSTART	ENDP


;	ＡＵＴＯＥＸＥＣ．ＥＸＥの実行

EXESTART	PROC	NEAR
	CALL	SRTDRV			; 立ち上がりドライブ番号の設定
	CMP	AX,0			; 0=正常, 2=ディスクエラー
	JNE	EXESTART_EXIT

	MOV	SI,OFFSET EXE_FILE_NAME	; 実行ファイル名
	MOV	AX,LOAD_SEGMENT		; ロードセグメント
	MOV	ES,AX			; フリーエリアの開始位置
	CALL	CMLOAD			; ＬＯＡＤ

	CMP	AX,0			; 0=正常
	JNE	EXESTART_EXIT		; 1=該当ファイル無し, 2=ディスクエラー

	MOV	AX,DX			; 読み込みファイル長さ(HI)
					; AX:CX 実行ファイルのサイズ
	MOV	DX,LOAD_SEGMENT 	; 実行ファイルのロードアドレス
	MOV	BX,LOAD_SEGMENT		; 実行ファイルのリロケートアドレス
	CALL	CMPROC			; 標準ＤＯＳプロセス

EXESTART_EXIT:
	RET
EXESTART	ENDP


;	立ち上がりドライブ番号の設定
;	-O- AX : 0=正常, 2=ディスクエラー

SRTDRV	PROC	NEAR
	MOV	AX,0			;
	MOV	ES,AX			;

;;;;;;	MOV	AL,BYTE PTR ES:[584H]	; 立ち上げディスクのＤＡ／ＵＡ 

	MOV	AL,BYTE PTR LOAD_DRIVE	; ロードドライブ番号
	MOV	AH,0			;
	AND	AX,11B			;
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	RET
SRTDRV	ENDP

;	ユーザドライブ番号の設定
;	-I- AX : １ＭＦＤドライブ番号（１ー４）
;	-O- AX : 0=正常, 2=ディスクエラー

USRDRV	PROC	NEAR
	DEC	AX			;
	AND	AX,11B			;
	CALL	SSRDRV			; ドライブ番号の設定（０ー３）
	RET				;
USRDRV	ENDP


;****************************************************************
;*	E X E L O A D						*
;****************************************************************

LOAD_DRIVE	DW	0	; ロードドライブ番号

;****************************************************************
;*	E X E L O A D						*
;****************************************************************

; "SSPROC.ASM" PC-9801UV11 make by R.H 1989/11/23
;
;	E X E L O A D     P R O C   c o m m a n d .
;
;
;
; command.

;***;	CODE	SEGMENT	PUBLIC	'CODE'
;***;	
;***;		ASSUME	CS:CODE,DS:DATA,ES:DATA
;***;	
;***;	PUBLIC	CMPROC		; 標準ＤＯＳプロセス
;***;	

;	標準ＤＯＳプロセス
;	-I- DX    : 標準ＤＯＳ実行ファイルのロードアドレス先頭
;	    BX    : 標準ＤＯＳ実行ファイルのリロケートアドレス先頭
;	    AX:CX : 標準ＤＯＳ実行ファイルのサイズ
;	別のセグメントでリロケート処理をして、実行直前に実行セグメント
;	へコピーするように変更しました。これでＥＸＥＬＯＡＤ本体を
;	実行エリアに使用することが可能になる。

CMPROC	PROC	NEAR
	MOV	LOAD_SEG,DX  ; 標準ＤＯＳ実行ファイルのロードアドレス先頭
	MOV	RELOC_SEG,BX ; 標準ＤＯＳ実行ファイルのリロケートアドレス先頭
	MOV	PROC_SIZE_LOW,CX ; 標準ＤＯＳ実行ファイルのサイズ(LOW)
	MOV	PROC_SIZE_HI,AX  ; 標準ＤＯＳ実行ファイルのサイズ(HI)

	CALL	PARASET      ; 標準ＤＯＳプロセスパラメータセット
	CALL	EXEC_RELOC   ; 標準ＤＯＳ実行ファイルのリロケーション
	CALL	EXEC_PROCESS ; 標準ＤＯＳ用プロセスの実行
	RET
CMPROC	ENDP


;	標準ＤＯＳ実行ファイルのリロケーション
;	-I- LOAD_SEG  : 標準ＤＯＳ実行ファイルのロードアドレス先頭
;	    RELOC_SEG : 標準ＤＯＳ実行ファイルのリロケートアドレス先頭
;	-O- TOP_SEG   : 先頭セグメントアドレス
;	    TOP_LOAD_SEG  : ロード時先頭セグメントアドレス
;	    TOP_RELOC_SEG : リロケート時先頭セグメントアドレス

EXEC_RELOC	PROC	NEAR

			; 標準ＤＯＳ実行ファイルのロードアドレス先頭
	MOV	AX,LOAD_SEG
			; ヘッダの大きさ（パラグラフ数／16byte単位）
	ADD	AX,EXE_HEAD_SIZE
			; ロード時先頭セグメントアドレス
	MOV	TOP_LOAD_SEG,AX


			; 標準ＤＯＳ実行ファイルのリロケートアドレス先頭
	MOV	AX,RELOC_SEG
			; ヘッダの大きさ（パラグラフ数／16byte単位）
	ADD	AX,EXE_HEAD_SIZE
			; リロケート時先頭セグメントアドレス
	MOV	TOP_RELOC_SEG,AX


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
	MOV	AX,ES:[BX]	; リロケート対象のアドレス（セグメント）
	ADD	AX,TOP_LOAD_SEG	; ロード時先頭セグメントアドレス
	MOV	ES,AX
	INC	BX
	INC	BX

	MOV	AX,TOP_RELOC_SEG ; リロケート時先頭セグメントアドレス
	ADD	ES:[DI],AX

	LOOP	EXEC_RELOC2
EXEC_RELOC_SKIP:

	RET
EXEC_RELOC	ENDP





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


;***;	
;***;	CODE	ENDS
;***;	
;***;	
;***;	DATA	SEGMENT	PUBLIC	'DATA'
;***;
;***;	DATA	ENDS
;***;		END
;
;	end of "SSPROC.ASM"
;


;****************************************************************
;*	E X E L O A D						*
;****************************************************************

; "SSLOAD.ASM" PC-9801UV11 make by R.H 1989/11/10
;
;	E X E L O A D     L O A D    c o m m a n d .
;
;
;
; command.

;***;	CODE	SEGMENT	PUBLIC	'CODE'
;***;	
;***;		ASSUME	CS:CODE,DS:DATA,ES:DATA
;***;	
;***;	PUBLIC	CMLOAD			; ＬＯＡＤ
;***;	
;***;	EXTRN	FFOPEN:NEAR		; ファイルオープン
;***;	EXTRN	FFCLOS:NEAR		; ファイルクローズ
;***;	EXTRN	FFREAD:NEAR		; ファイルの読み出し
;***;	EXTRN	PRINT:NEAR		; 文字列の表示
;***;	EXTRN	KESCAP:NEAR		; ESC key & break check & pause.
;***;	
;***;	EXTRN	HEXSTR:NEAR		; DX -> hex string.

READ_PARAGRAPH	EQU	64	; read paragraph length.
READ_LEN	EQU	16*64	; read length.
CHR_CR		EQU	0DH	; calig return.
CHR_LF		EQU	0AH	; line feed.


;
;	ＬＯＡＤ
;	-I- DS:SI : ファイル名
;	    ES    : フリーエリアの開始位置（パラグラフ値）
;	-O- CX    : 読み込みファイル長さ(LOW)
;	    DX    : 読み込みファイル長さ(HI)
;	    AX    : 0=正常, 1=該当ファイル無し, 2=ディスクエラー

CMLOAD	PROC	NEAR
	CALL	FFOPEN		; ファイルオープン
	CMP	AX,1		; file not found.
	JE	CMLOAD99	;
	CMP	AX,2		; ディスクエラー
	JE	CMLOAD_ERR_OPEN	;

	MOV	LOAD_LEN_LOW,0	; 読み込みファイル長さ(LOW)
	MOV	LOAD_LEN_HI,0	; 読み込みファイル長さ(HI)

	MOV	DI,0		; load memory area offset = 0 + ES*16
CMLOAD2:
	MOV	CX,READ_LEN	; read length.

	CALL	FFREAD		; ファイルの読み出し
	CMP	AX,2		; ディスクエラー
	JE	CMLOAD_ERROR	;
	CMP	AX,1		; E.O.F
	JE	CMLOAD8		;

	ADD	LOAD_LEN_LOW,DX		; 読み込みファイル長さ(LOW)
	ADC	LOAD_LEN_HI,0		; 読み込みファイル長さ(HI)

;***;	CALL	KESCAP		; ESC key & break check & pause.
;***;	CMP	AX,0
;***;	JNE	CMLOAD_BREAK

	MOV	AX,ES			;
	ADD	AX,READ_PARAGRAPH	; read paragraph length.
	MOV	ES,AX			;

	JMP	CMLOAD2
CMLOAD8:	
	CALL	FFCLOS			; ファイルクローズ

	MOV	CX,LOAD_LEN_LOW		; 読み込みファイル長さ(LOW)
	MOV	DX,LOAD_LEN_HI		; 読み込みファイル長さ(HI)

	MOV	SI,OFFSET MSG_MARK	; Ｅ．Ｏ．Ｆマーク
	CALL	PRINT			;
	MOV	AX,0			; normal.
	RET

CMLOAD99:
	MOV	AX,1			; file not found.
	RET
CMLOAD_ERROR:
	MOV	SI,OFFSET MSG_DISK_ERROR
	CALL	PRINT			;
	MOV	AX,2			; ディスクエラー
	RET
CMLOAD_ERR_OPEN:
	MOV	SI,OFFSET MSG_OPEN_ERROR
	CALL	PRINT			;
	MOV	AX,2			; ディスクエラー
	RET
;***;CMLOAD_BREAK:
;***;	MOV	SI,OFFSET MSG_BREAK
;***;	CALL	PRINT			; 処理中断
;***;	MOV	AX,0			; normal.
;***;	RET
CMLOAD	ENDP

;***;	CODE	ENDS
;***;	
;***;	
;***;	DATA	SEGMENT	PUBLIC	'DATA'

		EVEN
LOAD_LEN	LABEL	DWORD		; 読み込みファイル長さ
LOAD_LEN_LOW	DW	0		; 読み込みファイル長さ(LOW)
LOAD_LEN_HI	DW	0		; 読み込みファイル長さ(HI)

MSG_MARK	DB	"[E]",CHR_LF,0	; Ｅ．Ｏ．Ｆマーク

MSG_DISK_ERROR	DB	CHR_LF,CHR_LF,CHR_LF,CHR_LF,CHR_LF
		DB	"ﾃﾞｨ ｽ ｸ ｴ ﾗ ｰ",CHR_LF,0
MSG_OPEN_ERROR	DB	CHR_LF,CHR_LF,CHR_LF,CHR_LF,CHR_LF,CHR_LF
		DB	"ｵ ｰ ﾌﾟﾝ ｴ ﾗ ｰ",CHR_LF,0

;***;	DATA	ENDS
;***;		END
;
;	end of "SSLOAD.ASM"
;

;****************************************************************
;*	E X E L O A D						*
;****************************************************************

; "DOSIO.ASM" PC-9801UV11 make by R.H 1989/11/04
;
;	E X E L O A D    D i s k   l i b r a l y .
;
;
;
; public subroutine.

;***;
;***;CODE	SEGMENT	PUBLIC	'CODE'
;***;
;***;	ASSUME	CS:CODE,DS:DATA,ES:DATA
;***;
;***;
;***;PUBLIC	FFOPEN			; ファイルオープン
;***;PUBLIC	FFCLOS			; ファイルクローズ
;***;PUBLIC	FFREAD			; ファイルの読み出し
;***;
;***;
;***;EXTRN	SSRSRT:NEAR		; ファイルの先頭クラスタ番号の取り出し
;***;EXTRN	SSRRED:NEAR		; クラスタの読み出し
;***;

CLST_LENGTH	EQU	1024	; クラスタのバイト数

;
;	ファイルオープン
;	-I- DS:SI : ファイル名
;	-O- AX    : 0=正常, 1=該当ファイルがない, 2=ディスクエラー

FFOPEN	PROC	NEAR
	CALL	SSRSRT		; ファイルの先頭クラスタ番号の取り出し
	MOV	NOWCLST,DX	; 現在のクラスタ番号

	MOV	FILE_LEN_LOW,CX	; ファイルの長さ
	MOV	FILE_LEN_HI,BX	; (long integer)

	MOV	FILE_PNT_LOW,CX	; 読み出しファイルの残りバイト数
	MOV	FILE_PNT_HI,BX	; (long integer)

	MOV	NOWCOUNT,0	; クラスタバッファ内の残りバイト数
	MOV	NEXT_EOF,0	; next E.O.F
	RET
FFOPEN	ENDP

;
;	ファイルクローズ
;

FFCLOS	PROC	NEAR
	RET
FFCLOS	ENDP


;	ファイルの読み出し
;	-I- ES:DI    : データバッファのアドレス
;	    CX       : 読み込みデータのバイト数
;	-O- ES:[DI]  : データ
;	    DX       : 読み込み出来たバイト数
;	    AX       : 1=Ｅ．Ｏ．Ｆ（もう続きのデータは無い）
;		     : 2=ディスクエラー

FFREAD	PROC	NEAR
	PUSH	DI			;
	PUSH	CX			;

	CALL	BUFFCLAER		; es:[di]cx buffer 0 clear.

	CALL	FILE_LEN_CHECK		; ファイル長さチェック

	MOV	NOWBYTE_LEN,CX		; 指定バイト数
	MOV	NOWREAD_LEN,CX		; 読み出し残りバイト数

	CMP	AX,1			; 1=Ｅ．Ｏ．Ｆ
	JNE	FFREAD00		;
	JMP	FFREAD99
FFREAD00:
	CMP	NOWBYTE_LEN,0		; data counter=0.
	JNE	FFREAD1			;
	JMP	FFREAD9			; normal end.
FFREAD1:
	CMP	NEXT_EOF,1		; next E.O.F
	JNE	FFREAD11		;
	JMP	FFREAD99		; E.O.F
FFREAD11:
	CMP	NOWCOUNT,0		; ｸﾗｽﾀバッファ内の残りバイト数
	JNE	FFREAD4			;

;	読み込みループスタート

FFREAD2:
	MOV	DX,NOWCLST		; 現在のクラスタ番号
	CALL	SSRRED			; クラスタの読み出し
	MOV	NOWCLST,DX		;
	CMP	AX,2			; 2=ディスクエラー
	JNE	FFREAD21		;
	JMP	FFREAD_ERROR		;
FFREAD21:
	CMP	AX,1			; 1=E.O.F
	JNE	FFREAD22		;
	JMP	FFREAD88		; E.O.F check.
FFREAD22:
	CALL	FFMOV			; buffer copy.
	MOV	NOWCOUNT,CLST_LENGTH	; クラスタのバイト数

FFREAD4:
	MOV	CX,NOWREAD_LEN		; 読み出し残りバイト数
	CMP	CX,NOWCOUNT		; バッファ内の残りバイト数
	JBE	FFREAD5			; バッファ内のデータで足りる？

	MOV	CX,NOWCOUNT		; バッファ内の残りバイト数
	MOV	SI,OFFSET CLST_BUFF_END	; クラスタバッファの後ろ
	SUB	SI,CX			;
	SUB	NOWREAD_LEN,CX		; 読み出し残りバイト数
	MOV	NOWCOUNT,0		; バッファ内の残りバイト数
	REP	MOVSB			; 転送

	JMP	FFREAD2			; 次のクラスタの読み込み

;	読み込みループ終わり

FFREAD5:
	MOV	CX,NOWREAD_LEN		; 読み出し残りバイト数
	MOV	SI,OFFSET CLST_BUFF_END	; クラスタバッファの後ろ
	SUB	SI,NOWCOUNT		;
	MOV	NOWREAD_LEN,0		; 読み出し残りバイト数
	SUB	NOWCOUNT,CX		; バッファ内の残りバイト数
	REP	MOVSB			; 転送

	JMP	FFREAD9			; 読み込み終わり
FFREAD88:
	MOV	CX,NOWBYTE_LEN		; 指定バイト数と
	CMP	CX,NOWREAD_LEN		; 読み出し残りバイト数が同じ？
	JE	FFREAD99		;  E.O.F
	CMP	NOWREAD_LEN,0		; 読み出し残りバイト数が余る？
	JNE	FFREAD999		;  next E.O.F

FFREAD9:
	MOV	AX,0			; normal.
	JMP	FFREAD_EXIT		;
FFREAD99:
	MOV	AX,1			; E.O.F
	JMP	FFREAD_EXIT		;
FFREAD999:
	MOV	AX,0			; normal.
	MOV	NEXT_EOF,1		; next E.O.F
	JMP	FFREAD_EXIT		;
FFREAD_ERROR:
	MOV	AX,2			; ディスクエラー
FFREAD_EXIT:
	MOV	DX,NOWBYTE_LEN		; 指定バイト数
	SUB	DX,NOWREAD_LEN		; 読み出し残りバイト数
	POP	CX			;
	POP	DI			;
	RET				;
FFREAD	ENDP


;
;	ファイル長さチェック
;	-I/O-  CX  : 読み出しバイト数
;	-O-    AX  : 0=正常, 1=Ｅ．Ｏ．Ｆ

FILE_LEN_CHECK	PROC	NEAR
	CMP	FILE_PNT_HI,0	; 読み出しファイルの残りバイト数(HI)
	JNE	FILE_LEN_CHECK5	;
	CMP	FILE_PNT_LOW,0	; 読み出しファイルの残りバイト数(LOW)
	JNE	FILE_LEN_CHECK2	;

	MOV	AX,1		; E.O.F
	RET

FILE_LEN_CHECK2:
	CMP	CX,FILE_PNT_LOW	; 読み出しバイト数と残りバイト数(LOW)
	JBE	FILE_LEN_CHECK5	; 読み出すバイト数が小さい？

	MOV	CX,FILE_PNT_LOW	; 残りの読み出しバイト数はこれだけ
FILE_LEN_CHECK5:
	SUB	FILE_PNT_LOW,CX	; 読み出しファイルの残りバイト数計算
	SBB	FILE_PNT_HI,0	; 
	MOV	AX,0		; normal.
	RET
FILE_LEN_CHECK	ENDP



;	バッファ０クリア
;	-I- ES:DI    : データバッファのアドレス
;	    CX       : 読み込みデータのバイト数

BUFFCLAER	PROC	NEAR
	PUSH	DI
	PUSH	CX

	MOV	AL,0
	REP	STOSB

	POP	CX
	POP	DI	
	RET
BUFFCLAER	ENDP


;	buffer copy.
;	-I- DS:SI	; クラスタデータ
;	-O- CLST_BUFF	; クラスタバッファ

FFMOV	PROC	NEAR
	PUSH	ES
	PUSH	DI
	MOV	AX,SEG_DATA		; クラスタバッファ
	MOV	ES,AX			;
	MOV	DI,OFFSET CLST_BUFF	;
	MOV	CX,CLST_LENGTH		; クラスタのバイト数
	REP	MOVSB
	POP	DI
	POP	ES
	RET
FFMOV	ENDP

;***;
;***;CODE	ENDS
;***;
;***;
;***;DATA	SEGMENT	PUBLIC	'DATA'
;***;
;	ソース後方を参照せよ
;	これは、ディスク上には載せない
;***;
;***;CLST_BUFF	DB	CLST_LENGTH DUP (0)	; クラスタバッファ
;***;CLST_BUFF_END	LABEL	BYTE		; クラスタバッファの後ろ
;***;
	EVEN

NEXT_EOF	DW	0	; next E.O.F=1

NOWCLST		DW	0	; 現在のクラスタ番号

NOWCOUNT	DW	0	; クラスタバッファ内の残りバイト数

NOWBYTE_LEN	DW	0	; 指定バイト数

NOWREAD_LEN	DW	0	; 読み出し残りバイト数

FILE_LEN_LOW	DW	0	; ファイルの長さ
FILE_LEN_HI	DW	0	; (long integer)

FILE_PNT_LOW	DW	0	; 読み出しファイルの残りバイト数
FILE_PNT_HI	DW	0	; (long integer)

;***;DATA	ENDS
;***;	END
;
;	end of "DOSIO.ASM"
;


;****************************************************************
;*	E X E L O A D						*
;****************************************************************

; "READWT.ASM" PC-9801UV11 make by R.H 1990/09/25
;
;	E X E L O A D    D I S K    R e a d / W r i t e    c a l l .
;
;
;
; public subroutine.( chash buffer read/write )


;
;	もし、このプログラムのセグメントＣＨＡＳＨＢがＤＭＡの
;	バンクの境界（２ＦＦＦＦＨ等）にまたがる心配がなければ
;	ＣＨＡＳＨ＿ＢＵＦＦＥＲ１とＣＨＡＳＨ＿ＢＵＦＦＥＲ２
;	を同じ１６Ｋバイトのエリアにしてかまわない
;
;	例）
;	CHASH_BUFFER1	LABEL	BYTE
;	CHASH_BUFFER2	DB	1024*16 DUP (0)
;
;	1990/07/15 ＥＰＳＯＮ製ＰＣ－３８６Ｍのドライブ対策で
;	　　FDDOOR（ＦＤドライブドア開閉チェック）のセンスコマンド(04H)を
;	　　新センスコマンド(84H)に変更したが双方ともバグらしきもの
;	　　がある為、強制的にディスクを読ませるステータスを返すようにした。
;

;***;CODE	SEGMENT	PUBLIC	'CODE'
;***;
;***;	ASSUME	CS:CODE,DS:DATA,ES:DATA
;***;
;***;PUBLIC	SSRDRV		; ドライブ番号の設定（０ー３）
;***;PUBLIC	SSRDNO		; ドライブ番号の取得（０ー３）
;***;
;***;			; ＤＩＲ
;***;PUBLIC	SSRDIR		; ＦＡＴ＋ＲＯＯＴの読み出し
;***;PUBLIC	SSWDIR		; ＦＡＴ＋ＲＯＯＴの書き込み
;***;
;***;			; ＲＥＡＤ
;***;PUBLIC	SSRSRT		; ファイルの先頭クラスタ番号の取り出し	(OPEN)
;***;PUBLIC	SSRRED		; クラスタの読み出し			(READ)
;***;
;***;			; ＷＲＩＴＥ
;***;PUBLIC	SSWENT		; ディレクトリ・エントリの取得		(OPEN)
;***;PUBLIC	SSWWRT		; クラスタの書き込み			(WRITE)
;***;PUBLIC	SSWEOF		; クラスタの書き込み終了		(EOF)
;***;PUBLIC	SSWSET		; エントリ・データの書き込み		(CLOSE)
;***;
;***;			; ＫＩＬＬ
;***;PUBLIC	SSKILL		; ファイルの削除
;***;
;***;			; ＴＯＯＬＳ
;***;PUBLIC	SSDSKF		; ディスクの空きクラスタ数
;***;PUBLIC	SSFDDV		; ＦＤドライブドア開閉チェック
;***;
;***;
;***;EXTRN	PRINT:NEAR	; 文字列の表示
;***;

DIRENTLEN	EQU	20H		; １つのディレクトリ・エントリの長さ

FLNLEN		EQU	8		; ファイル名の長さ
FLTLEN		EQU	3		; 拡張子の長さ

;					; 各オフセット値
FDMNAM		EQU	0		; ファイル名
FDMTYP		EQU	8H		; 拡張子
FDMATR		EQU	0BH		; ファイル属性
FDMSYS		EQU	0CH		; システム予約
FDMTIM		EQU	16H		; ファイル更新時刻
FDMDAT		EQU	18H		; ファイル更新年月日
FDMCLS		EQU	1AH		; ファイルの最初のクラスタ
FDMSIZ		EQU	1CH		; ファイルサイズ

;	５’２ＨＤの場合です
DIRMAX		EQU	192		; ディレクトリ最大数
LEN_CLAST	EQU	1024		; クラスタバイト数
LEN_SECTOR	EQU	1024		; セクタバイト数
FAT_CLAST 	EQU	4		; ＦＡＴテーブルクラスタ数
ROOT_CLAST 	EQU	6		; ＲＯＯＴＤＩＲクラスタ数
CLAST_OFFSET	EQU	9		; クラスタ開始位置のセクタオフセット
MAX_SECTOR	EQU	8		; トラック当りのセクタ数
MAX_CYLINDER	EQU	77		; 最大シリンダ数
MIN_CLAST	EQU	2		; 最小クラスタ番号
MAX_CLAST	EQU	8*2*77-9-1	; 最大クラスタ番号

DIR_ERASE	EQU	0E5H		; ディレクトリ削除マーク

FAT_FREE_CLAST	EQU	0		; 空きクラスタ(FAT)
FAT_EOF_CLAST	EQU	0FFFH		; ファイルの最後のクラスタ(FAT)
FAT_END_CLAST	EQU	0FF8H		; ファイル本体クラスタの最小値(FAT)

DISK_RESULT_TOP	EQU	0564H 		; リザルトステータス情報アドレス

READ_RETCOUNT 	EQU	10		; ＲＥＡＤ・リトライ回数
WRITE_RETCOUNT 	EQU	10		; ＷＲＩＴＥ・リトライ回数

OFF_CYLINDER	EQU	9999		; シリンダはロードされていない

CHR_LF		EQU	0AH		; ＬＦ（ラインフィード）
CHR_CR		EQU	0DH		; ＣＲ（キャリッジリターン）


;	ファイルの先頭クラスタ番号の取り出し
;	-I- DS:SI : ファイル名
;	-O- DX    : クラスタ番号
;	    CX    : ファイルサイズ（下位ワード）
;	    BX    : ファイルサイズ（上位ワード）
;	    AX    : 0=正常, 1=該当ファイルがない, 2=ディスクエラー

SSRSRT	PROC	NEAR
	PUSH	ES			;
	PUSH	DI			;
	PUSH	SI			;
	CALL	LOAD_FDTOP		; ＦＡＴ＋ＲＯＯＴのロード
	CMP	DERROR,1		; 0=正常,1=エラー
	JE	SSRSRT_ERROR		;

	CALL	FLNSET			; 指定ファイル名のカラム合わせ
	CALL	ROOTCK			; 指定ファイル名をＲＯＯＴから検索
	CMP	AX,0			; 0=見つからない
	JE	SSRSRT8			;

	MOV	SI,ETADRS 		; ディレクトリ・エントリのオフセット
	MOV	DX,WORD PTR DS:[SI][FDMCLS]	; ファイルの最初のクラスタ
	MOV	CX,WORD PTR DS:[SI][FDMSIZ]	; ファイルサイズ下位
	MOV	BX,WORD PTR DS:[SI][FDMSIZ+2]	; ファイルサイズ上位

	MOV	AX,0			; 0=正常
	POP	SI			;
	POP	DI			;
	POP	ES			;
	RET				;
SSRSRT8:
	MOV	DX,0			;
	MOV	AX,1			; 1=該当ファイルがない
	POP	SI			;
	POP	DI			;
	POP	ES			;
	RET				;
SSRSRT_ERROR:
	MOV	DX,0			;
	MOV	AX,2			; 2=ディスクエラー
	POP	SI			;
	POP	DI			;
	POP	ES			;
	RET				;
SSRSRT	ENDP


;	クラスタの読み出し
;	-I- DX : 読み出すクラスタ番号
;	-O- DX : 次のクラスタ番号
;	    DATA:SI : クラスタバッファ
;	    AX : 0=正常, 1=E.O.F, 2=ディスクエラー

SSRRED	PROC	NEAR
	PUSH	ES			;
	PUSH	DI			;

	CMP	DX,MAX_CLAST		; 最大クラスタ番号
	JNBE	SSRRED99		;
	CMP	DX,MIN_CLAST		; 最小クラスタ番号
	JB	SSRRED99		;

	MOV	PNTNOW,DX		; 現在のクラスタ番号
	CALL	LODCLS			; クラスタロード
	CALL	NXTNUM			; 次のクラスタ番号を取り出す
	MOV	DX,PNTNXT		; 続きのクラスタ番号

	MOV	SI,OFFSET SCDATA	; セクタバッファ

	CMP	DERROR,1		; 1=エラー
	JE	SSRRED_ERROR		;

	MOV	AX,0			; 0=正常
	POP	DI			;
	POP	ES			;
	RET				;
SSRRED99:
	MOV	AX,1			; 1=E.O.F
	POP	DI			;
	POP	ES			;
	RET				;
SSRRED_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	POP	DI			;
	POP	ES			;
	RET				;
SSRRED	ENDP



;	ＦＤドライブドア開閉チェック
;	-I- AX : １ＭＦＤドライブ番号（０ー３）
;	-O- AX : 0=前と変わらず,1=ドアを開閉した,2=ドアが開きっぱなし

SSFDDV	PROC	NEAR
	PUSH	BX
	PUSH	CX
	PUSH	DX
	PUSH	DI
	PUSH	SI
	PUSH	ES
	CALL	FDRSLT	; ＦＤドライブドア開閉チェック(ﾘｻﾞﾙﾄｽﾃｰﾀｽﾁｪｯｸ)
	POP	ES
	POP	SI
	POP	DI
	POP	DX
	POP	CX
	POP	BX
	RET
SSFDDV	ENDP



;	指定ファイル名をＲＯＯＴディレクトリから検索
;	-I- FLNAME : ファイル名
;	-O- AX     : 0=見つからない,1=見つかった
;	    ETADRS : ディレクトリ・エントリのオフセットアドレス
;	    BX     : 見つかったディレクトリの通し番号

ROOTCK	PROC	NEAR
	MOV	AX,DS			;
	MOV	ES,AX			;

	MOV	BX,0			; 見つかったディレクトリの通し番号
	MOV	DI,OFFSET ROOTDIR	; ＲＯＯＴＤＩＲ

	MOV	CX,DIRMAX		; ディレクトリ最大数
ROOTCK1:				;
	MOV	ETADRS,DI		; エントリのオフセットアドレス
	MOV	SI,OFFSET FLNAME	;
	CMP	BYTE PTR ES:[DI],0	; end of dir.
	JE	ROOTCK8			;

	PUSH	CX			;
	MOV	CX,FLNLEN+FLTLEN	; ファイル名の長さ
ROOTCK2:CMPSB				; 文字列の照合
	JNE	ROOTCK3			;
	LOOP	ROOTCK2			;
	POP	CX			;
	JMP	ROOTCK9			;

ROOTCK3:				;
	DEC	CX			;
	ADD	DI,CX			; ＲＯＯＴＤＩＲのポインタを進める
	ADD	DI,DIRENTLEN - ( FLNLEN + FLTLEN )
	INC	BX			; 見つかったディレクトリの通し番号
	POP	CX			;
	LOOP	ROOTCK1			;

ROOTCK8:
	MOV	AX,0			; 0=見つからない
	RET				;
ROOTCK9:
	MOV	AX,1			; 1=見つかった
	RET				;
ROOTCK	ENDP



;	次のクラスタ番号を取り出す
;	-I- PNTNOW : 現在のクラスタ番号
;	-O- PNTNXT : 続きのクラスタ番号

NXTNUM	PROC	NEAR
	MOV	AX,PNTNOW		; 現在のクラスタ番号
	SHR	AX,1			; / 2
	MOV	SI,AX			; ＦＡＴテーブルのアドレスポインタ
	ADD	SI,AX			;
	ADD	SI,AX			; ( * 3 )

	MOV	AX,PNTNOW		; 現在のクラスタ番号
	SHR	AX,1			; 奇数か偶数かの判定
	JB	NXTNUM2			;

					; 偶数の場合
	MOV	AX,WORD PTR FAT[SI]	;
	AND	AX,0FFFH		; 3 nible.
	MOV	PNTNXT,AX		; 続きのクラスタ番号
	RET				;

NXTNUM2:				; 奇数の場合
	MOV	AX,WORD PTR FAT[SI+1]	;
	SHR	AX,1			;
	SHR	AX,1			; 1 nible shift.
	SHR	AX,1			;
	SHR	AX,1			;
	MOV	PNTNXT,AX		; 続きのクラスタ番号
	RET
NXTNUM	ENDP




;	クラスタロード
;	-I- PNTNOW	: 現在のクラスタ番号
;	-O- DATA:[SCDATA] : セクタのデータ
;	    DERROR	: 0=正常,1=エラー

LODCLS	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	MOV	AX,PNTNOW		; 現在のクラスタ番号
	ADD	AX,CLAST_OFFSET		;
	CALL	LODSEC			; 論理レコード・ＲＥＡＤ
	RET				;
LODCLS	ENDP


;	論理レコード・ＲＥＡＤ
;	-I- AX		: 論理レコード番号
;	-O- DATA:[SCDATA] : セクタのデータ
;	    DERROR 	: 0=正常,1=エラー

LODSEC	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	MOV	DX,AX			;
	SHR	AX,1			;
	SHR	AX,1			;
	SHR	AX,1			;
	AND	DX,07H			; ８で割る（ＡＸ答え、ＤＸ余り）

	INC	DX			;
	MOV	DSECR,DX		; セクタ番号（Ｒ）１ー８（２６）

	MOV	DHEAD,AX		; ヘッド番号（Ｈ）０ー１
	AND	DHEAD,0001H		; 偶数と奇数

	SHR	AX,1			;
	MOV	DCYL,AX			; シリンダ番号（Ｃ）０ー７６

	CALL	READSSS			; セクターＲＥＡＤ

	RET
LODSEC	ENDP



;	セクターＲＥＡＤ
;	-I- DCYL  : シリンダ番号（Ｃ）０ー７６
;	    DHEAD : ヘッド番号（Ｈ）０ー１
;	    DSECR : セクタ番号（Ｒ）１ー８（２６）
;	-O- DATA:[SCDATA] : セクタのデータ
;	    DERROR : 0=正常,1=エラー
;	-I/O- NOWCYLINDER : 現在のシリンダー

READSSS	PROC	NEAR
	PUSH	DI			;
	PUSH	SI			;
	MOV	DERROR,0		; 0=正常

;*DEB*;	PRVH	"ss DCYL  ",DCYL ; シリンダ番号（Ｃ）０ー７６
;*DEB*;	PRVH	"ss DHEAD ",DHEAD; ヘッド番号（Ｈ）０ー１
;*DEB*;	PRVH	"ss DSECR ",DSECR; セクタ番号（Ｒ）１ー８（２６）
;*DEB*;	CALL	KESCAP

	MOV	AX,DCYL			; シリンダ番号（Ｃ）０ー７６
	CMP	AX,NOWCYLINDER		; 現在のシリンダー
	JE	READSSSGET		;


	CALL	RDCYLN			; シリンダーＲＥＡＤ
	CMP	DERROR,0		; 1=エラー
	JNZ	READSSS99		;

	MOV	AX,DCYL			; シリンダ番号（Ｃ）０ー７６
	MOV	NOWCYLINDER,AX		; 現在のシリンダー
READSSSGET:
	MOV	AX,SEG_DATA		; セクタバッファ
	MOV	ES,AX			;
	MOV	DI,OFFSET SCDATA	;

	PUSH	DS			;
	MOV	SI,DHEAD		; ヘッド番号（Ｈ）０ー１
	MOV	CL,13			; * ( 1024*8 )
	SHL	SI,CL			; * ( 1024*8 )
	MOV	BX,DSECR		; セクタ番号（Ｒ）１ー８（２６）
	DEC	BX			;
	MOV	CL,10			; * ( 1024 )
	SHL	BX,CL			; * ( 1024 )
	ADD	SI,BX			;
	ADD	SI,CHASH_BUFF_ADRS	; キャッシュバッファのアドレス
	MOV	AX,SEG_CHASHB		;
	MOV	DS,AX			;
	MOV	CX,LEN_SECTOR/2		; セクタバイト数
	REP	MOVSW			;
	POP	DS			;
READSSS99:
	POP	SI			;
	POP	DI			;
	RET				;
READSSS	ENDP



;	シリンダーＲＥＡＤ（高速処理／出力はキャッシュバッファへ）
;	このルーチンは大変デリケートなので扱いに注意して下さい
;
;	-I-   DCYL   : シリンダ番号（Ｃ）０ー７６
;	-I/O- CHASH_BUFF_ADRS		: キャッシュバッファアドレス
;	-O-   CHASHB:[CHASH_BUFF_ADRS]	: キャッシュバッファ
;	      DERROR : 0=正常,1=エラー

RDCYLN	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	MOV	READ_RETRY,READ_RETCOUNT ; ＲＥＡＤ・リトライ回数
RDCYLN_RETRY:
	MOV	AX,SEG_CHASHB		; キャッシュバッファ
	MOV	ES,AX			;
	MOV	BP,CHASH_BUFF_ADRS	; キャッシュバッファのアドレス

	MOV	AL,BYTE PTR DUNIT	; デバイス識別・ユニット番号(DA/UA)
	MOV	BX,WORD PTR DLEN 	; データ長（ＤＴＬ）（バイト単位）
	MOV	CL,BYTE PTR DCYL 	; シリンダ番号（Ｃ）０ー７６
	MOV	DH,0		 	; ヘッド番号（Ｈ）０ー１
	MOV	DL,1		 	; セクタ番号（Ｒ）１ー８（２６）
	MOV	CH,BYTE PTR DSECN	; セクタ長（Ｎ）
	MOV	AH,BYTE PTR DREAD	; ＲＥＡＤ　ＤＡＴＡ

	INT	1BH			; ディスクＢＩＯＳ
	JB	RDCYLN_ERROR		;
	MOV	AH,BYTE PTR DREAD	; ＲＥＡＤ　ＤＡＴＡ
	AND	AH,11101111B		; SEEKを現在トラックからの読み出しに
RDCYLN9:
	MOV	DERROR,0		; 0=正常
	RET				;

RDCYLN_ERROR:				;
	CMP	AH,20H			; ＤＭＡ　Ｂｏｕｎｄａｒｙ
	JNE	RDCYLN_ERROR2		;

	MOV	AX,OFFSET CHASH_BUFFER2	; バンクを避けるためバッファ
	CMP	AX,CHASH_BUFF_ADRS	; を替える
	JNE	RDCYLN_BNK_SET		; バッファ１、２？
	MOV	AX,OFFSET CHASH_BUFFER1	;
RDCYLN_BNK_SET:
	MOV	CHASH_BUFF_ADRS,AX	; キャッシュバッファのアドレス

	JMP	RDCYLN_RETRY		;

RDCYLN_ERROR2:
	CMP	AH,60H			; Not Ready. ユニットがノットレディ状態
	JE	RDCYLN_ER_END		;

	DEC	READ_RETRY		; ＲＥＡＤ・リトライカウンタ
	JZ	RDCYLN_ER_END		;

	MOV	AH,BYTE PTR DRECAL	; ＲＥＣＡＬＩＢＲＡＴＥ
	INT	1BH			; ディスクＢＩＯＳ
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	JMP	RDCYLN_RETRY		;

RDCYLN_ER_END:				;
	MOV	BYTE PTR DSTAT,AH	; ステータス情報
	MOV	DERROR,1		; 1=エラー
	RET				;
RDCYLN	ENDP




;	ＦＡＴ＋ＲＯＯＴの読み出し
;	-O- AX : 0=正常, 2=ディスクエラー

SSRDIR	PROC	NEAR
	PUSH	BX			;
	PUSH	CX			;
	PUSH	DX			;
	PUSH	DI			;
	PUSH	SI			;
	PUSH	ES			;
	CALL	LOAD_FDTOP		; ＦＡＴ＋ＲＯＯＴのロード
					; （ドア開閉スキップ付き）
	CMP	DERROR,1		; ディスクエラー
	JE	SSRDIR_ERROR		;

	MOV	AX,0			; 0=正常
	POP	ES			;
	POP	SI			;
	POP	DI			;
	POP	DX			;
	POP	CX			;
	POP	BX			;
	RET				;
SSRDIR_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	POP	ES			;
	POP	SI			;
	POP	DI			;
	POP	DX			;
	POP	CX			;
	POP	BX			;
	RET				;
SSRDIR	ENDP



;	ＦＡＴ＋ＲＯＯＴのロード（ドア開閉スキップ付き）
;	-O-   DERROR 		: 0=正常,1=エラー

LOAD_FDTOP	PROC	NEAR
	PUSH	SI			;
	MOV	DERROR,0		; 0=正常

	CALL	DRVNO			; ドライブ番号の取得
	CALL	FDDOOR			; ＦＤドライブドア開閉チェック

	CMP	AX,0			; 0=前と変わらず,1=ドアを開閉した
	JNE	LOAD_FDTOP_LOAD		; 2=ドアが開きっぱなし

	CMP	LOADFAT_LOG,0		; 0=ロードが必要
	JE	LOAD_FDTOP_LOAD		;

	JMP	LOAD_FDTOP9		;

LOAD_FDTOP_LOAD:			;
	MOV	NOWCYLINDER,OFF_CYLINDER ; シリンダはロードされていない

	MOV	LOADFAT_LOG,0		; 0=ロードが必要
	CALL	LODFAT			; ＦＡＴ＆ＲＯＯＴロード
	CMP	DERROR,0		; 0=正常
	JNE	LOAD_FDTOP9		;
	MOV	LOADFAT_LOG,1		; 1=ＦＡＴロード済み
LOAD_FDTOP9:
	POP	SI			;
	RET				;
LOAD_FDTOP	ENDP



;	ＦＡＴ＆ＲＯＯＴロード
;	（ＦＡＴとＲＯＯＴディレクトリは連続しています）
;	-O- DERROR 	: 0=正常,1=エラー

LODFAT	PROC	NEAR
	MOV	DERROR,0		; 0=正常

	MOV	AX,SEG_DATA		;
	MOV	ES,AX			;
	MOV	DI,OFFSET FAT		; ＦＡＴテーブル

	MOV	NUM,1			; レコード番号
	MOV	CX,FAT_CLAST+ROOT_CLAST	; ＦＡＴ＋ＲＯＯＴクラスタ数
LODFAT2:				;
	PUSH	CX			;
	MOV	AX,NUM			; レコード番号
	PUSH	ES			;
	PUSH	DI			;
	CALL	LODSEC			; 論理レコード・ＲＥＡＤ
	POP	DI			;
	POP	ES			;
	MOV	SI,OFFSET SCDATA	;
	MOV	CX,LEN_CLAST		; クラスタの内容－＞ＦＡＴテーブル
	REP	MOVSB			;
	POP	CX			;
	CMP	DERROR,1		; エラー
	JE	LODFAT_ERROR		;
	INC	NUM			; レコード番号
	LOOP	LODFAT2			;
	RET
LODFAT_ERROR:				; エラー
	RET				;
LODFAT	ENDP


;	ドライブ番号の取得
;	-O- AX : １ＭＦＤドライブ番号

DRVNO	PROC	NEAR
	MOV	AX,DUNIT		; デバイス識別・ユニット番号（DA/UA）
	AND	AX,00000011B		; DA/UA=100100dd
	RET				;
DRVNO	ENDP


;	ドライブ番号の設定（０ー３）
;	-I- AX : １ＭＦＤドライブ番号
;	-O- AX : 0=正常, 2=ディスクエラー

SSRDRV	PROC	NEAR
	PUSH	BX			;
	PUSH	CX			;
	PUSH	DX			;
	PUSH	DI			;
	PUSH	SI			;
	PUSH	ES			;

	MOV	BX,AX			; ドライブ番号
	CALL	DRVNO			; ドライブ番号の取得
	CMP	BX,AX			;
	JE	SSRDRV2			;
	MOV	LOADFAT_LOG,0		; 0=ロードが必要
SSRDRV2:
	AND	BL,011B			;
	AND	BYTE PTR DUNIT,11111100B
	OR	BYTE PTR DUNIT,BL	;

	CALL	LOAD_FDTOP		; ＦＡＴ＋ＲＯＯＴのロード

	CMP	DERROR,1		; ディスクエラー
	JE	SSRDRV_ERROR		;

	POP	ES			;
	POP	SI			;
	POP	DI			;
	POP	DX			;
	POP	CX			;
	POP	BX			;
	MOV	AX,0			; 0=正常
	RET				;
SSRDRV_ERROR:
	POP	ES			;
	POP	SI			;
	POP	DI			;
	POP	DX			;
	POP	CX			;
	POP	BX			;
	MOV	AX,2			; 2=ディスクエラー
	RET				;
SSRDRV	ENDP


;	ドライブ番号の取得（０ー３）
;	-O- AX : １ＭＦＤドライブ番号

SSRDNO	PROC	NEAR
	MOV	AX,DUNIT		;
	AND	AX,011B			;
	RET
SSRDNO	ENDP



;	ＦＤドライブドア開閉チェック
;	-I- AX : １ＭＦＤドライブ番号（０ー３）
;	-O- AX : 0=前と変わらず,1=ドアを開閉した,2=ドアが開きっぱなし
;
;	1990/07/15 ＥＰＳＯＮ製ＰＣ－３８６Ｍのドライブ対策で
;	　　FDDOOR（ＦＤドライブドア開閉チェック）のセンスコマンド(04H)を
;	　　新センスコマンド(84H)に変更したが双方ともバグらしきもの
;	　　がある為、強制的にディスクを読ませるステータスを返すようにした。

FDDOOR	PROC	NEAR
	PUSH	DX			;
	PUSH	BX			;
	PUSH	ES			;
	CALL	FDRSLT			; ＦＤドライブドア開閉チェック(ﾘｻﾞﾙﾄ)
	CMP	AX,2			; 2=ドアが開きっぱなし
	JNE	FDDOOR_9		;
	MOV	AX,1			;
FDDOOR_9:
	POP	ES			;
	POP	BX			;
	POP	DX			;
	RET				;

;*NON*;	PUSH	DX
;*NON*;	PUSH	BX
;*NON*;	PUSH	ES
;*NON*;
;*NON*;	PUSH	AX	;
;*NON*;	CALL	FDRSLT	; ＦＤドライブドア開閉チェック(ﾘｻﾞﾙﾄｽﾃｰﾀｽﾁｪｯｸ)
;*NON*;	POP	BX	; BX=drive number.
;*NON*;	CMP	AX,2	; 0=前と変わらず,1=ドアを開閉した,2=ドアが開きっぱなし
;*NON*;	JNE	FDDOOR9	;
;*NON*;
;*NON*;;*NON*;
;*NON*;;*NON*;	; ユーザがキーボードを叩いたら
;*NON*;;*NON*;	; ちょっとＦＤの状態を調べてあげる
;*NON*;;*NON*;
;*NON*;;*NON*;	MOV	AH,01H	; キーバッファ状態のセンス
;*NON*;;*NON*;	INT	18H	; BIOS call.
;*NON*;;*NON*;	CMP	BH,00H	; 0=無効
;*NON*;;*NON*;	JE	FDDOOR_NO_SET
;*NON*;;*NON*;
;*NON*;
;*NON*;	; リザルトステータス・テーブルに反映されない
;*NON*;	; 場合に対してもＢＩＯＳでチェックする
;*NON*;
;*NON*;	MOV	AL,BL			; AX=ドライブ番号
;*NON*;					; 90Hは１ＭＦＤであることを示す
;*NON*;	OR	AL,90H			; AL=デバイス識別・ユニット番号(DA/UA)
;*NON*;	MOV	AH,BYTE PTR DSENSE	; ＳＥＮＳＥ
;*NON*;	INT	1BH			; ディスクＢＩＯＳ
;*NON*;
;*NON*;	JB	FDDOOR_NO_SET		; CF=1 異常終了
;*NON*;
;*NON*;	TEST	AH,60H			; 60H=ＮＲ／媒体がセットされていない
;*NON*;	JNZ	FDDOOR_NO_SET		;
;*NON*;FDDOOR_SET:
;*NON*;	MOV	AX,1			; 1=ドアを開閉した
;*NON*;	JMP	FDDOOR9
;*NON*;FDDOOR_NO_SET:
;*NON*;	MOV	AX,2			; 2=ドアが開きっぱなし
;*NON*;FDDOOR9:
;*NON*;	POP	ES
;*NON*;	POP	BX
;*NON*;	POP	DX
;*NON*;	RET
FDDOOR	ENDP




;	ＦＤドライブドア開閉チェック（リザルトステータスチェック）
;	-I- AX : １ＭＦＤドライブ番号（０ー３）
;	-O- AX : 0=前と変わらず,1=ドアを開閉した,2=ドアが開きっぱなし

FDRSLT	PROC	NEAR
	PUSH	DX			;
	PUSH	BX			;
	PUSH	ES			;

	MOV	DX,AX			; DX=ドライブ番号

	MOV	BX,AX			;
	SHL	BX,1			;
	SHL	BX,1			;
	SHL	BX,1			; * 8
	ADD	BX,DISK_RESULT_TOP	; リザルトステータス情報アドレス
	MOV	AX,0			;
	MOV	ES,AX			;
	MOV	AL,BYTE PTR ES:[BX]	; disk result status ST0.

		;  |iiSenHuu|		;
		;  |ccEcrDss|		;
		;  |10    10|		;
	AND	AL,11001000B		;

	CMP	AL,0			;
	JNE	FDRSLT5			;
	MOV	AX,0			; 0=前と変わらず
	JMP	FDRSLT9			;
FDRSLT5:
	CMP	AL,11000000B		;
	JNE	FDRSLT6			;
	MOV	AX,1			; 1=ドアを開閉した
	JMP	FDRSLT9			;
FDRSLT6:
	CMP	AL,11001000B		;
	JNE	FDRSLT7			;
	MOV	AX,2			; 2=ドアが開きっぱなし
	JMP	FDRSLT9			;
FDRSLT7:
	MOV	AX,2			; 2=ドアが開きっぱなし
FDRSLT9:
	MOV	BX,DX			; DX=ドライブ番号
	CMP	BYTE PTR DS:DISK_DOOR_INI[BX],0	; ディスク開閉初期ﾌﾗｸﾞ
	JZ	FDRSLT_RET		;

	MOV	BYTE PTR DS:DISK_DOOR_INI[BX],0	; ディスク開閉初期ﾌﾗｸﾞ
	CMP	AX,0			; 0=前と変わらず
	JNE	FDRSLT_RET		;
	MOV	AX,1			; 1=ドアを開閉した
FDRSLT_RET:				;
	POP	ES			;
	POP	BX			;
	POP	DX			;
	RET				;
FDRSLT	ENDP



;	指定ファイル名のカラム合わせ ex. "TEST.ASM"->"TEST____ASM"
;	-I- DS:SI  : ファイル名
;	-O- FLNAME : ファイル名

FLNSET	PROC	NEAR
	PUSH	SI			;

;*NON*;	CALL	SPACE_PLESS		; ブランク抜き

	MOV	AX,SEG_DATA		;
	MOV	ES,AX			;
	MOV	DI,OFFSET FLNAME	;
	MOV	CX,FLNLEN+FLTLEN	;
	MOV	AL,' '			;
	REP	STOSB			;

	MOV	DI,OFFSET FLNAME	;
	MOV	CX,FLNLEN+FLTLEN	;
FLNSET2:LODSB				;
	CMP	AL,'.'			; next type.
	JE	FLNSET4			;
	CMP	AL,20H			; end of string.
	JB	FLNSET9			;
	STOSB				;
	LOOP	FLNSET2			;
	JMP	FLNSET9			;

FLNSET4:				;
	MOV	DI,OFFSET FLTYPE	;
	MOV	CX,FLTLEN		;
FLNSET5:LODSB				;
	CMP	AL,'.'			; next type.
	JE	FLNSET9			;
	CMP	AL,20H			; end of string.
	JB	FLNSET9			;
	STOSB				;
	LOOP	FLNSET5			;

FLNSET9:				;
	POP	SI			;
	RET				;
FLNSET	ENDP


;*NON*;;	ブランク抜き
;*NON*;;	-I- DS:SI  : 文字列のアドレス
;*NON*;
;*NON*;SPACE_PLESS	PROC	NEAR		
;*NON*;	PUSH	DS			;
;*NON*;	PUSH	SI			;
;*NON*;
;*NON*;	MOV	DI,SI			;
;*NON*;SPACE_PLESS2:
;*NON*;	MOV	AL,DS:[SI]		;
;*NON*;	INC	SI			;
;*NON*;	CMP	AL,0			; end of string.
;*NON*;	JE	SPACE_PLESS8		;
;*NON*;	CMP	AL,20H			; space.
;*NON*;	JBE	SPACE_PLESS3		;
;*NON*;	MOV	DS:[DI],AL		;
;*NON*;	INC	DI			;
;*NON*;SPACE_PLESS3:
;*NON*;	JMP	SPACE_PLESS2		;
;*NON*;
;*NON*;SPACE_PLESS8:
;*NON*;	MOV	BYTE PTR DS:[DI],0	; end of string.
;*NON*;
;*NON*;	POP	SI			;
;*NON*;	POP	DS			;
;*NON*;	RET				;
;*NON*;SPACE_PLESS	ENDP

;***;CODE	ENDS
;***;
;***;
;***;
;***;;	ディスクキャッシュバッファ
;***;
;***;CHASHB	SEGMENT	PUBLIC	'CHASHB'
;***;	EVEN
;***;	DB	0
;***;	DB	0
;***;CHASH_BUFFER1	DB	1024*16 DUP (0)
;***;CHASH_BUFFER2	DB	1024*16 DUP (0)
;***;	DB	0
;***;	DB	0
;***;CHASHB	ENDS
;***;
;***;
;***;
;***;DATA	SEGMENT	PUBLIC	'DATA'
;***;
;***;PUBLIC	SSRFAT				; ＦＡＴグローバルアドレス
;***;PUBLIC	SSROOT				; ＲＯＯＴグローバルアドレス

;		ＢＩＯＳコマンド識別コード
		EVEN
;			MM-S....	;
;			TFrK0110	;
DREAD		DW	11110110B	; ＲＥＡＤ　ＤＡＴＡ
DWRITE		DW	11110101B	; ＷＲＩＴＥ　ＤＡＴＡ
DRECAL		DW	00100111B	; ＲＥＣＡＬＩＢＲＡＴＥ
DSENSE		DW	04H		; ＳＥＮＳＥ
;			100100dd	;
DUNIT		DW	10010001B	; デバイス識別・ユニット番号（DA/UA）

;		ＩＤＲ（ＩＤ情報）

DLEN		DW	LEN_SECTOR*16	; データ長（ＤＴＬ）（バイト単位）
DCYL		DW	0		; シリンダ番号（Ｃ）０ー７６
DHEAD		DW	0		; ヘッド番号（Ｈ）０ー１
DSECR		DW	1		; セクタ番号（Ｒ）１ー８（２６）
DSECN		DW	03		; セクタ長（Ｎ）
					; 00/128, 01/256, 02/512, 03/1024
DSTAT		DW	0		; ステータス情報
DERROR		DW	0		; 0=正常,1=エラー

DISK_DOOR_INI	DB 0FFH,0FFH,0FFH,0FFH	; ディスク開閉初期ﾌﾗｸﾞ

;***;		EVEN			;
;***;SCDATA		DB LEN_SECTOR DUP (0)	; セクタバッファ
;***;		DB 0,0			;

		EVEN			;
NOWCYLINDER	DW 0			; 現在のシリンダー
MODCYLINDER	DW 0			; 現在のシリンダ内容(0=READ,1=WRITE)
CHASH_BUFF_ADRS	DW CHASH_BUFFER1	; キャッシュバッファのアドレス

;***;		EVEN				;
;***;SSRFAT		LABEL	BYTE			; ＦＡＴｸﾞﾛｰﾊﾞﾙ
;***;FAT		DB LEN_CLAST*FAT_CLAST DUP (0)	; ＦＡＴテーブル
;***;SSROOT		LABEL	BYTE			; ＲＯＯＴｸﾞﾛｰﾊﾞﾙ
;***;ROOTDIR		DB LEN_CLAST*ROOT_CLAST DUP (0)	; ＲＯＯＴＤＩＲ

		EVEN			 ;
FLNAME		DB	FLNLEN DUP (20H) ; ファイル名
FLTYPE		DB	FLTLEN DUP (20H) ; 拡張子
		DB	0,0		 ;

		EVEN			;
ETADRS		DW	0		; ディレクトリ・エントリのオフセット

NUM		DW	0		; レコード番号

PNTNOW		DW	0		; 現在のクラスタ番号
PNTNXT		DW	0		; 続きのクラスタ番号
PNTFRE		DW	0		; 次の空きクラスタ番号
FRE_CLAST	DW	0		; 空きクラスタ数

READ_RETRY	DW	0		; ＲＥＡＤ・リトライカウンタ
WRITE_RETRY	DW	0		; ＷＲＩＴＥ・リトライカウンタ

LOADFAT_LOG	DW	0		; 0=ロードが必要,1=ＦＡＴロード済み

;***;DATA	ENDS
;***;
;***;	END

;
;	end of "READWT.ASM"
;

;****************************************************************
;*	E X E L O A D						*
;****************************************************************


; i*2 value -> hexdecimal string.
; -i- DX : i*2 value
; -o- SI : string address.
;         NULL=end of string.

HEXSTR	PROC	NEAR
	PUSH	AX
	PUSH	BX
	PUSH	CX

	MOV	SI,OFFSET BUFFER

	MOV	AL,DH
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	CALL	HEXSTR3
	MOV	AL,DH
	CALL	HEXSTR3

	MOV	AL,DL
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	SHR	AL,1
	CALL	HEXSTR3
	MOV	AL,DL
	CALL	HEXSTR3

	MOV	BYTE PTR [SI],0	;null.
	MOV	SI,OFFSET BUFFER		;string adrs.

	POP	CX
	POP	BX
	POP	AX
	RET

HEXSTR3:AND	AL,0FH
	CMP	AL,0AH	;if AL<0ah then
	JB	HEXSTR4
	ADD	AL,07H  ; ascii 'A'-'F'
HEXSTR4:ADD	AL,30H  ; ascii '0'-'9'
	MOV	BYTE PTR [SI],AL
	INC	SI
	RET

HEXSTR	ENDP


;	print of string.
;	-i- SI : string address.
;		NULL=end of string.

PRINT	PROC	NEAR

	PUSH	AX
	PUSH	BX
	PUSH	CX
	PUSH	DX

	PUSH	DI
	PUSH	SI
	PUSH	ES

	CALL	MESSAGE

	POP	ES
	POP	SI
	POP	DI

	POP	DX
	POP	CX
	POP	BX
	POP	AX
	RET
PRINT	ENDP


;	message print.
;	-i- SI : string address.
;		NULL=end of string.

MESSAGE:
	MOV	AX,TEXT_ADDRESS	;
	MOV	ES,AX		;
	MOV	DI,CRT_TOP	;
	MOV	DX,DI		; pointer save.
MESS_LOOP:
	LODSB			;
	CMP	AL,0		; end of string.
	JE	MESS_END	;
	CMP	AL,CHR_LF	;
	JNE	MESS_SKIP	;
	MOV	DI,DX		;
	ADD	DI,160		; next line.
	MOV	DX,DI		; pointer save.
	JMP	MESS_LOOP	;
MESS_SKIP:			;
	STOSB			;
	INC	DI		; text vram.
	JMP	MESS_LOOP
MESS_END:
	MOV	CRT_TOP,DI
	RET


;	ESC key & break check & pause.

KESCAP:
	RET


;	ＩＮＴ２１Ｈの設定

INT21HSET:
	MOV	AX,0
	MOV	ES,AX

	MOV	DI,84H		; ＩＮＴ２１Ｈのベクタアドレス

	MOV	AX,OFFSET DOSPROC  ;
	MOV	BX,EXELOAD_TOP_SEG ; このシステムの先頭セグメント

	MOV	ES:[DI][0],AX	; オフセット
	MOV	ES:[DI][2],BX	; セグメント

	RET


;	ＤＯＳ割り込みルーチン

DOSPROC:
	CMP	AH,50H		; ファンクションの上限 ?
	JNB	DOSPROC_EXIT	;

	CMP	AH,0FH		;
	JNE	DOSPROC0F	; ＯＰＥＮ
	CALL	DOSOPEN		;
	IRET			;
DOSPROC0F:			;

	CMP	AH,10H		;
	JNE	DOSPROC10	; ＣＬＯＳＥ
	CALL	DOSCLOSE	;
	IRET			;
DOSPROC10:			;

	CMP	AH,14H		;
	JNE	DOSPROC14	; ＲＥＡＤ
	CALL	DOSREAD		;
	IRET			;
DOSPROC14:			;

	CMP	AH,1AH		;
	JNE	DOSPROC1A	; ＤＴＡのセット
	CALL	DOSDTASET	;
	IRET			;
DOSPROC1A:			;

	CMP	AH,4CH		;
	JNE	DOSPROC4C	; プロセスの終了
	CALL	DOSPROCEND	;
	IRET			;
DOSPROC4C:			;

DOSPROC_EXIT:
	IRET


;	ファイルオープン

DOSOPEN:
	PUSH	BX
	PUSH	CX
	PUSH	DX

	PUSH	DI
	PUSH	SI
	PUSH	BP
	PUSH	DS
	PUSH	ES

	PUSH	AX

	MOV	SI,DX			 ;
	MOV	WORD PTR DS:[SI][14],128 ; ＲＳ（レコードサイズ）
	MOV	AL,BYTE PTR DS:[SI][0]	 ; Ｄ（ドライブ番号）
	MOV	AH,0			 ; ＡＸ＝ドライブ番号

	MOV	BX,EXELOAD_TOP_SEG	; このシステムの先頭セグメント
	MOV	ES,BX			;
	MOV	DI,OFFSET DOS_FILE_NAME	;

	MOV	SI,DX			; ＦＣＢアドレス
	INC	SI			;
	MOV	CX,11			; ファイル名は１１文字
	REP	MOVSB			;


	MOV	BX,EXELOAD_TOP_SEG	; このシステムの先頭セグメント
	MOV	DS,BX			;


	CMP	AX,0			; ドライブ番号(0=ｶﾚﾝﾄﾄﾞﾗｲﾌﾞ)
	JNE	DOSOPEN01		;
	CALL	SRTDRV			; 立ち上がりドライブ番号の設定
	JMP	DOSOPEN02		;
DOSOPEN01:				;
	CALL	USRDRV			; ユーザドライブ番号の設定
DOSOPEN02:				;
	CMP	AX,0			;
	JNZ	DOSOPEN_ERROR		;

	MOV	SI,OFFSET DOS_FILE_NAME	; ファイル名
	CALL	FFOPEN			; ファイルオープン

	CMP	AX,0 ; 0=正常, 1=該当ファイルがない, 2=ディスクエラー
	JE	DOSOPEN2
DOSOPEN_ERROR:
	MOV	AL,0FFH
DOSOPEN2:
	POP	BX

	MOV	AH,BH

	POP	ES
	POP	DS
	POP	BP
	POP	SI
	POP	DI

	POP	DX
	POP	CX
	POP	BX

	RET


;	ファイルクローズ

DOSCLOSE:
	PUSH	BX
	PUSH	CX
	PUSH	DX

	PUSH	DI
	PUSH	SI
	PUSH	BP
	PUSH	DS
	PUSH	ES

	PUSH	AX

	CALL	FFCLOS

	MOV	AL,0

	POP	BX
	MOV	AH,BH

	POP	ES
	POP	DS
	POP	BP
	POP	SI
	POP	DI

	POP	DX
	POP	CX
	POP	BX

	RET


;	ファイルシーケンシャルリード

DOSREAD:
	PUSH	BX
	PUSH	CX
	PUSH	DX

	PUSH	DI
	PUSH	SI
	PUSH	BP
	PUSH	DS
	PUSH	ES

	PUSH	AX

	MOV	SI,DX

	MOV	CX,WORD PTR DS:[SI][14]	; ＲＳ（レコードサイズ）

	MOV	BX,EXELOAD_TOP_SEG	; このシステムの先頭セグメント
	MOV	DS,BX			;

	MOV	AX,DTA_SEG		; ＤＴＡアドレス
	MOV	ES,AX			;
	MOV	DI,DTA_OFFSET		;

			;	-I- ES:DI: データバッファのアドレス
			;	    CX   : 読み込みデータのバイト数
	CALL	FFREAD	; ファイルの読み出し
			; AX: 1=Ｅ．Ｏ．Ｆ（もう続きのデータは無い）
			;     2=ディスクエラー

	POP	BX
	MOV	AH,BH

	POP	ES
	POP	DS
	POP	BP
	POP	SI
	POP	DI

	POP	DX
	POP	CX
	POP	BX

	RET


;	ＤＴＡのセット

DOSDTASET:
	PUSH	BX
	PUSH	CX
	PUSH	DX

	PUSH	DI
	PUSH	SI
	PUSH	BP
	PUSH	DS
	PUSH	ES

	PUSH	AX

	MOV	AX,DS

	MOV	BX,EXELOAD_TOP_SEG	; このシステムの先頭セグメント
	MOV	DS,BX			;

	MOV	DTA_SEG,AX	; ＤＴＡアドレスセグメント
	MOV	DTA_OFFSET,DX	; ＤＴＡアドレスオフセット

	POP	AX

	POP	ES
	POP	DS
	POP	BP
	POP	SI
	POP	DI

	POP	DX
	POP	CX
	POP	BX

	RET


;	プロセスの終了
;
;	（ＤＳ：［ＤＸ］＝次の実行ファイル名をセット）
;	この処理の後、ＣＳ＝６０Ｈ，ＩＰ＝０番地へ飛べば
;	実行ファイルを起動します。

DOSPROCEND:
	MOV	BX,EXELOAD_TOP_SEG	; このシステムの先頭セグメント
	MOV	ES,BX			;
	MOV	DI,OFFSET EXE_FILE_NAME	; 実行ファイル名

	MOV	SI,DX			; ＦＣＢアドレス
	MOV	CX,11			; ファイル名は１１文字
	REP	MOVSB			;
	RET

;****************************************************************
;*	E X E L O A D						*
;****************************************************************
		EVEN
DTA_SEG		DW	EXELOAD_TOP_SEG	; ＤＴＡアドレスセグメント
DTA_OFFSET	DW	OFFSET SYS_DTA	; ＤＴＡアドレスオフセット

DOS_FILE_NAME	DB	8 DUP (0)	; ファイル名は８文字
DOS_FILE_ATR	DB	3 DUP (0)	; 拡張子は３文字
		DB	0		; end of string.

SEG_DATA	DW	0		; データセグメント
SEG_CHASHB	DW	0		; ディスクキャッシュバッファ

LOAD_SEGMENT	DW	0		; ロードセグメント
LOADSYS_SEGMENT	DW	0		; ロード新システムセグメント

SYS_FILE_NAME	DB	"PSHELL  EXE",0	; ＳＹＳＴＥＭファイル名
EXE_FILE_NAME	DB	"AUTOEXECEXE",0	; 実行ファイル名

CRT_TOP		DW	TEXT_TOP	; ディスプレイロケート

MESSAGE_TOP:
DB	"************************************************",CHR_LF
DB	"* ｼｽﾃﾑ ｶﾞ ｳｺﾞｷﾏｾﾝ.  ｶﾝｶﾞｴﾗﾚﾙ  ｹﾞﾝｲﾝ ﾊ････      *",CHR_LF
DB	"* 1.'AUTOEXEC.EXE' ｶﾞ ﾐﾂｶﾗﾅｲ                   *",CHR_LF
DB	"* 2. ﾌﾛｯﾋﾟｰﾃﾞｨｽｸ  ｶﾞ  ｺﾜﾚﾀ                     *",CHR_LF
DB	"* 3. ｺﾉ PC ｶﾞ NEC ﾉ PC-9801 ﾄ ﾁｶﾞｳ             *",CHR_LF
DB	"* ｹﾞﾝｲﾝ ﾉ ﾜｶﾗﾅｲ ﾊﾞｱｲ ﾊ  ﾆｭｳｼｭ  ｻｷ ﾏﾃﾞ ﾄｲｱﾜｾﾖｳ! *",CHR_LF
DB	"*   E X E L O A D . S Y S  ｶﾞ  ｵﾂﾀｴｼﾏｼﾀ.       *",CHR_LF
DB	"************************************************",CHR_LF
DB	CHR_LF
DB	0
MSG_CLN:
DB	":",0

;****************************************************************
;*	E X E L O A D						*
;****************************************************************

;	システムソースコード終わり

SYSEND	LABEL	FAR			; システムコードの終わり

;****************************************************************
;*	E X E L O A D						*
;****************************************************************


;	空きバッファ群
;
;	ここから先はディスク上に乗せない


BUFFER		DB	256 DUP (0)		; 文字列

SYS_DTA		DB	128 DUP (0)		; システムＤＡＴ

		EVEN
SCDATA		DB	SEC_BYTE DUP (0)	; セクタバッファ
		DB	0,0			;

		EVEN
CHASH_BUFFER1	LABEL	BYTE	
CHASH_BUFFER2	DB	1024*16 DUP (0)		; ディスクキャッシュバッファ
		DB	0,0			;

		EVEN
SSRFAT		LABEL	BYTE				; ＦＡＴｸﾞﾛｰﾊﾞﾙ
FAT		DB	LEN_CLAST*FAT_CLAST DUP (0)	; ＦＡＴテーブル
SSROOT		LABEL	BYTE				; ＲＯＯＴｸﾞﾛｰﾊﾞﾙ
ROOTDIR		DB	LEN_CLAST*ROOT_CLAST DUP (0)	; ＲＯＯＴＤＩＲ

		EVEN
CLST_BUFF	DB	CLST_LENGTH DUP (0)	; クラスタバッファ
CLST_BUFF_END	LABEL	BYTE			; クラスタバッファの後ろ


;****************************************************************
;*	E X E L O A D						*
;****************************************************************

SYSEND_ALL	LABEL	BYTE		; システムの終わり（空きバッファ含む）

	DB	1024 DUP (0)

CODSYS	ENDS

	END
;
;	end of "CODSYS.ASM"
;
