; "READWT.ASM" PC-9801UV11 make by R.H 1990/09/25
;		modify 1992/02/11
;
;	E X E L O A D    D I S K    R e a d / W r i t e    c a l l .
;
;
;
; public subroutine.( chash buffer read/write )

INCLUDE	TSTSET.INC

;
;	カレントドライブは DOSIO.ASM で管理される
;
;
;	MODROOTFAT（現在のＦＡＴ内容(0=READ,1=WRITE)）
;
;		ディレクトリ・エントリの取得(SSWENT)と
;		ＦＡＴへクラスタ番号を書き込む(FATSET)によって
;		１(WRITE)がセットされ、
;		ＦＡＴ＆ＲＯＯＴセーブ(SAVFAT)と
;		ＦＡＴ＆ＲＯＯＴロード(LODFAT)と
;		ＦＡＴ＋ＲＯＯＴのセーブ(SAVE_FDTOP)によって
;		０(READ)がセットされます。
;
;	LOADFAT_LOG（0=ロードが必要,1=ＦＡＴロード済み）
;
;		あまり美しくないが、０にセットすると
;		ＦＡＴ＋ＲＯＯＴのロード(LOAD_FDTOP)でドアの開閉に
;		関係無くＦＡＴをロードする。
;
;［削除］1990/07/15 ＥＰＳＯＮ製ＰＣ－３８６Ｍのドライブ対策で
;［削除］FDDOOR（ＦＤドライブドア開閉チェック）のセンスコマンド(04H)を
;［削除］新センスコマンド(84H)に変更したが双方ともバグらしきもの
;［削除］がある為、強制的にディスクを読ませるステータスを返すようにした。
;
;
; public subroutine.( entry i/o )


CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,ES:DATA

PUBLIC	SSRDRV		; ドライブ番号の設定（０ー３）
PUBLIC	SSRDNO		; ドライブ番号の取得（０ー３）
PUBLIC	SSRRST		; ドライブのリセット（０ー３）

			; ＤＩＲ
PUBLIC	SSRDIR		; ＦＡＴ＋ＲＯＯＴの読み出し
PUBLIC	SSWDIR		; ＦＡＴ＋ＲＯＯＴの書き込み

			; ＲＥＡＤ
PUBLIC	SSRSRT		; ファイルの先頭クラスタ番号の取り出し	(OPEN)

			; ＷＲＩＴＥ
PUBLIC	SSWENT		; ディレクトリ・エントリの取得		(OPEN)
PUBLIC	SSWSET		; エントリ・データの書き込み		(CLOSE)

			; ＫＩＬＬ
PUBLIC	SSKILL		; ファイルの削除

			; ＴＯＯＬＳ
PUBLIC	SSSEEK		; クラスタのシーク
PUBLIC	SSDSKF		; ディスクの空きクラスタ数
PUBLIC	SSDSKS		; ドライブ情報
PUBLIC	SSFDDV		; ＦＤドライブドア開閉チェック

PUBLIC	NXTNUM		; 次のクラスタ番号を取り出す
PUBLIC	NXTFRE		; 次の空きクラスタを捜す
PUBLIC	FATSET		; ＦＡＴへクラスタ番号を書き込む

EXTRN	SSRRRD:NEAR	; 連続レコード順次読み出し
EXTRN	SSWRWT:NEAR	; 連続レコード順次書き込み

EXTRN	PRINT:NEAR	; 文字列の表示


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

;;;;DIRMAX	EQU	32		; ディレクトリ最大数
DIRMAX		EQU	192		; ディレクトリ最大数

SECTOR_CLAST	EQU	1		; セクタ数／１クラスタ当り
LEN_CLAST	EQU	1024		; クラスタバイト数
LEN_SECTOR	EQU	1024		; セクタバイト数
FAT_CLAST 	EQU	4		; ＦＡＴテーブルクラスタ数

;ＤＫＦＯＲＭ．ＡＳＭもなおせ
;ｌｉｎｋｅｎｄ．ＡＳＭもなおせ
;SSDIR.ASMのDIRMAXもなおせ
ROOT_CLAST 	EQU	1		; ＲＯＯＴＤＩＲクラスタ数
;;;;ROOT_CLAST	EQU	6		; ＲＯＯＴＤＩＲクラスタ数

CLAST_OFFSET	EQU	9		; クラスタ開始位置のセクタオフセット
MAX_SECTOR	EQU	8		; トラック当りのセクタ数
MAX_CYLINDER	EQU	77		; 最大シリンダ数
MIN_CLAST	EQU	2		; 最小クラスタ番号
MAX_CLAST	EQU	8*2*77-10	; 最大クラスタ番号

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


;	ディレクトリ・エントリの取得
;	-I- DS:SI : ファイル名
;	-O- DX    : ディレクトリ・エントリＩＤ
;	    AX    : 0=正常, 1=ディレクトリに空きがない, 2=ディスクエラー

SSWENT	PROC	NEAR
	CALL	LOAD_FDTOP		; ＦＡＴ＋ＲＯＯＴのロード
	CMP	DERROR,1		; 1=エラー
	JE	SSWENT_ERROR		;

	CALL	FLNSET			; 指定ファイル名のカラム合わせ

	CALL	ROOTFR			; 空きエントリをＲＯＯＴから検索
	CMP	AX,0			; 0=空きエントリが無い
	JE	SSWENT_NONE		;

	MOV	DX,BX			; 見つかったディレクトリの通し番号
					; DX = エントリＩＤ

	MOV	SI,ETADRS 		; ディレクトリ・エントリのオフセット
	MOV	WORD PTR DS:[SI][FDMCLS],0	; ファイルの最初のクラスタ
	MOV	WORD PTR DS:[SI][FDMSIZ],0	; ファイルサイズ下位
	MOV	WORD PTR DS:[SI][FDMSIZ+2],0	; ファイルサイズ上位
	MOV	BYTE PTR DS:[SI][FDMATR],20H	; ファイル属性
	MOV	WORD PTR DS:[SI][FDMTIM],0	; ファイル更新時刻
	MOV	WORD PTR DS:[SI][FDMDAT],0	; ファイル更新年月日

	MOV	DI,ETADRS 		; ディレクトリ・エントリのオフセット
	ADD	DI,FDMNAM		; ファイル名(offset)
	MOV	CX,FLNLEN+FLTLEN	; ファイル名の長さ＋拡張子の長さ
	MOV	SI,OFFSET FLNAME	; ファイル名
	MOV	AX,DS			;
	MOV	ES,AX			;
	REP	MOVSB			; ファイル名セット

	MOV	MODROOTFAT,1		; 現在のＦＡＴ内容(0=READ,1=WRITE)

	MOV	AX,0			; 0=正常
	RET				;
SSWENT_NONE:
	MOV	AX,1			; 1=ディレクトリに空きがない
	RET				;
SSWENT_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	RET				;
SSWENT	ENDP


;	エントリ・データの書き込み
;	-I- DX    : ファイルの最初のクラスタ
;	    CX    : ファイルサイズ（下位ワード）
;	    BX    : ファイルサイズ（上位ワード）
;	    AX    : ディレクトリ・エントリＩＤ
;	-O- AX    : 0=正常, 2=ディスクエラー

SSWSET	PROC	NEAR
	PUSH	DX			;
	PUSH	BX			;
	CWD				; ディレクトリ・エントリＩＤ=AX
	MOV	BX,DIRENTLEN		; ディレクトリ・エントリの長さ
	IMUL	BX			;
	ADD	AX,ADRSROOTDIR		; ROOT ＲＯＯＴアドレス
	MOV	ETADRS,AX		; ディレクトリ・エントリのオフセット
	POP	BX			;
	POP	DX			;

	MOV	SI,ETADRS			;
	MOV	WORD PTR DS:[SI][FDMCLS],DX	; ファイルの最初のクラスタ
	MOV	WORD PTR DS:[SI][FDMSIZ],CX	; ファイルサイズ下位
	MOV	WORD PTR DS:[SI][FDMSIZ+2],BX	; ファイルサイズ上位

	CALL	SAVFAT			; ＦＡＴ＆ＲＯＯＴセーブ
	CMP	DERROR,0		; 1=エラー
	JNE	SSWSET_ERROR		;

	MOV	AX,0			; 0=正常
	RET				;
SSWSET_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	RET				;
SSWSET	ENDP


;	ファイルの削除
;	-I- DS:SI : ファイル名
;	-O- AX    : 0=正常, 1=該当ファイルがない, 2=ディスクエラー

SSKILL	PROC	NEAR
	PUSH	SI

	CALL	LOAD_FDTOP		; ＦＡＴ＋ＲＯＯＴのロード
	CMP	DERROR,1		; 0=正常,1=エラー
	JE	SSKILL_ERROR		;

	CALL	FLNSET			; 指定ファイル名のカラム合わせ
	CALL	ROOTCK			; 指定ファイル名をＲＯＯＴから検索
	CMP	AX,0			; 0=見つからない
	JE	SSKILL_NONE		;

	MOV	SI,ETADRS 		; ディレクトリ・エントリのオフセット
	MOV	DX,WORD PTR DS:[SI][FDMCLS]	; ファイルの最初のクラスタ
	CALL	FATCUT			; ＦＡＴ中のチェインをクリアする

	MOV	SI,ETADRS 		; ディレクトリ・エントリのオフセット
	MOV	WORD PTR DS:[SI][FDMCLS],0	; ファイルの最初のクラスタ
	MOV	WORD PTR DS:[SI][FDMSIZ],0	; ファイルサイズ下位
	MOV	WORD PTR DS:[SI][FDMSIZ+2],0	; ファイルサイズ上位
	MOV	BYTE PTR DS:[SI][FDMNAM],DIR_ERASE ; ディレクトリ削除マーク

	CALL	SAVFAT			; ＦＡＴ＆ＲＯＯＴセーブ
	CMP	DERROR,0		; 1=エラー
	JNE	SSKILL_ERROR		;

SSKILL_EXIT:
	MOV	AX,0			; 0=正常
	POP	SI			;
	RET				;
SSKILL_NONE:
	MOV	AX,1			; 1=該当ファイルがない
	POP	SI			;
	RET				;
SSKILL_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	POP	SI			;
	RET				;
SSKILL	ENDP


;	クラスタのシーク
;	-I- DX    : 先頭クラスタ番号
;	    CX    : 先頭から何クラスタか
;	-O- AX    : 0=正常, 1=範囲外
;	    DX    : クラスタ番号

SSSEEK	PROC	NEAR
	MOV	PNTNOW,DX		; 現在のクラスタ番号
	JCXZ	SSSEEK_EXIT		;
SSSEEK_LOOP:				;
	CMP	DX,FAT_END_CLAST	; ファイル本体クラスタの最小値(FAT)
	JNB	SSSEEK_ERROR		;
	MOV	PNTNOW,DX		; 現在のクラスタ番号
	PUSH	CX			;
	CALL	NXTNUM			; 次のクラスタ番号を取り出す
	POP	CX			;
	MOV	DX,PNTNXT		; 続きのクラスタ番号
	LOOP	SSSEEK_LOOP		;

SSSEEK_EXIT:
	MOV	AX,0			; 0=正常
	RET
SSSEEK_ERROR:
	MOV	DX,PNTNOW		; 現在のクラスタ番号
	MOV	AX,1			; 1=範囲外
	RET
SSSEEK	ENDP


;	ディスクの空きクラスタ数
;	-O- DX  : 空きクラスタ数
;	    AX  : 0=正常, 2=ディスクエラー

SSDSKF	PROC	NEAR
	CALL	LOAD_FDTOP		; ＦＡＴ＋ＲＯＯＴのロード
	CMP	DERROR,1		; 0=正常,1=エラー
	JE	SSDSKF_ERROR		;

	CALL	CNTFRE			; 空きクラスタ数を調べる

	MOV	DX,FRE_CLAST		; 空きクラスタ数
	MOV	AX,0			; 0=正常
	RET				;
SSDSKF_ERROR:
	MOV	DX,0			;
	MOV	AX,2			; 2=ディスクエラー
	RET				;
SSDSKF	ENDP


;	ドライブ情報
;	-O- DS:BX  : ディスク情報テーブルアドレス
;	    AX     : 0=正常, 2=ディスクエラー
;
;	ディスク情報テーブル
;	DS:SI->	[ セクタ数／１クラスタ   ]
;		[ 空きクラスタ数         ]
;		[ バイト数／１セクタ     ]
;		[ クラスタ数／１ドライブ ]

SSDSKS	PROC	NEAR
	MOV	DISK_INFORMATION,SECTOR_CLAST	; セクタ数／１クラスタ
	MOV	DISK_INFORMATION[2],0		; 空きクラスタ数
	MOV	DISK_INFORMATION[4],LEN_SECTOR	; セクタバイト数
	MOV	DISK_INFORMATION[6],MAX_CLAST	; クラスタ数／１ドライブ

	CALL	SSDSKF				; ディスクの空きクラスタ数
	CMP	AX,0				;
	JNE	SSDSKS_ERROR			;

	MOV	DISK_INFORMATION[2],DX		; 空きクラスタ数

SSDSKS_EXIT:
	MOV	SI,OFFSET DISK_INFORMATION	; ディスク情報テーブル
	MOV	AX,0				; 0=正常
	RET
SSDSKS_ERROR:
	MOV	SI,OFFSET DISK_INFORMATION	; ディスク情報テーブル
	MOV	AX,2				; 2=ディスクエラー
	RET
SSDSKS	ENDP


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



;	ＦＡＴ中のチェインをクリアする
;	-I- DX : チェイン先頭

FATCUT	PROC	NEAR
FATCUT_LOOP:
	CMP	DX,MAX_CLAST		; 最大クラスタ番号
	JNBE	FATCUT_LOOPEND		;
	CMP	DX,MIN_CLAST		; 最小クラスタ番号
	JB	FATCUT_LOOPEND		;

	MOV	PNTNOW,DX		; 現在のクラスタ番号
	CALL	NXTNUM			; 次のクラスタ番号を取り出す
	MOV	DX,FAT_FREE_CLAST	; 空きクラスタ(FAT)
	CALL	FATSET			; ＦＡＴへクラスタ番号を書き込む

	MOV	DX,PNTNXT		; 続きのクラスタ番号

	JMP	FATCUT_LOOP		;
FATCUT_LOOPEND:				;
	RET
FATCUT	ENDP



;	指定ファイル名をＲＯＯＴディレクトリから検索
;	-I- FLNAME : ファイル名
;	-O- AX     : 0=見つからない,1=見つかった
;	    ETADRS : ディレクトリ・エントリのオフセットアドレス
;	    BX     : 見つかったディレクトリの通し番号

ROOTCK	PROC	NEAR
	MOV	AX,DS			;
	MOV	ES,AX			;

	MOV	BX,0			; 見つかったディレクトリの通し番号
	MOV	DI,ADRSROOTDIR		; ROOT ＲＯＯＴアドレス

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



;	空きエントリをＲＯＯＴディレクトリから検索
;	-O- AX     : 0=空きエントリが無い,1=見つかった
;	    ETADRS : ディレクトリ・エントリのオフセットアドレス
;	    BX     : 見つかったディレクトリの通し番号

ROOTFR	PROC	NEAR
	MOV	BX,0			; 見つかったディレクトリの通し番号
	MOV	SI,ADRSROOTDIR		; ROOT ＲＯＯＴアドレス

	MOV	CX,DIRMAX		; ディレクトリ最大数
ROOTFR_LOOP:				;
	MOV	ETADRS,SI		; エントリのオフセットアドレス
	CMP	BYTE PTR DS:[SI],0	; end of dir.
	JE	ROOTFR9			;
	CMP	BYTE PTR DS:[SI],DIR_ERASE ; ディレクトリ削除マーク
	JE	ROOTFR9			;

	ADD	SI,DIRENTLEN		; ＲＯＯＴＤＩＲのポインタを進める
	INC	BX			; 見つかったディレクトリの通し番号
	LOOP	ROOTFR_LOOP		;
ROOTFR8:
	MOV	AX,0			; 0=空きエントリが無い
	RET				;
ROOTFR9:
	MOV	AX,1			; 1=見つかった
	RET				;
ROOTFR	ENDP



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
	ADD	SI,ADRSFAT		;ROOT ＦＡＴアドレス
	MOV	AX,WORD PTR DS:[SI]	;
	AND	AX,0FFFH		; 3 nible.
	MOV	PNTNXT,AX		; 続きのクラスタ番号
	RET				;

NXTNUM2:				; 奇数の場合
	ADD	SI,ADRSFAT		;ROOT ＦＡＴアドレス
	MOV	AX,WORD PTR DS:[SI+1]	;
	SHR	AX,1			;
	SHR	AX,1			; 1 nible shift.
	SHR	AX,1			;
	SHR	AX,1			;
	MOV	PNTNXT,AX		; 続きのクラスタ番号
	RET
NXTNUM	ENDP



;	次の空きクラスタを捜す
;	-I- PNTNOW : 現在のクラスタ番号
;	-O- PNTFRE : 次の空きクラスタ番号
;	    AX     : 0=通常,1=空きセクタ無し

NXTFRE	PROC	NEAR
	MOV	AX,PNTNOW		; 現在のクラスタ番号
	INC	AX			;
	MOV	PNTFRE,AX		; 次の空きクラスタ番号

NXTFRE_LOOP:				;
	CMP	PNTFRE,MAX_CLAST	; 最大クラスタ番号ならば
	JNBE	NXTFRE_RESEARECH	; もう一度先頭から検索

	MOV	AX,PNTFRE		; 次の空きクラスタ番号
	SHR	AX,1			; / 2
	MOV	SI,AX			; ＦＡＴテーブルのアドレスポインタ
	ADD	SI,AX			;
	ADD	SI,AX			; ( * 3 )

	MOV	AX,PNTFRE		; 次の空きクラスタ番号
	SHR	AX,1			; 奇数か偶数かの判定
	JB	NXTFRE2			;

					; 偶数の場合
	ADD	SI,ADRSFAT		;ROOT ＦＡＴアドレス
	MOV	AX,WORD PTR DS:[SI]	;
	AND	AX,0FFFH		; 3 nible.
	JMP	NXTFRE3			;
NXTFRE2:				; 奇数の場合
	ADD	SI,ADRSFAT		;ROOT ＦＡＴアドレス
	MOV	AX,WORD PTR DS:[SI+1]	;
	SHR	AX,1			;
	SHR	AX,1			; 1 nible shift.
	SHR	AX,1			;
	SHR	AX,1			;
NXTFRE3:				;
	CMP	AX,FAT_FREE_CLAST	; 空きクラスタ(FAT)
	JE	NXTFRE_HIT		;

	INC	PNTFRE			; 次の空きクラスタ番号
	JMP	NXTFRE_LOOP		; LOOP END.


NXTFRE_RESEARECH:			;
	MOV	PNTFRE,MIN_CLAST	; 最小クラスタ番号
NXTFRE_LOOP2:				;
	MOV	AX,PNTFRE		;
	CMP	AX,PNTNOW		; 現在のクラスタ番号ならば
	JNB	NXTFRE_NONE		; 空きクラスタ無し

	MOV	AX,PNTFRE		; 次の空きクラスタ番号
	SHR	AX,1			; / 2
	MOV	SI,AX			; ＦＡＴテーブルのアドレスポインタ
	ADD	SI,AX			;
	ADD	SI,AX			; ( * 3 )

	MOV	AX,PNTFRE		; 次の空きクラスタ番号
	SHR	AX,1			; 奇数か偶数かの判定
	JB	NXTFRE4			;

					; 偶数の場合
	ADD	SI,ADRSFAT		;ROOT ＦＡＴアドレス
	MOV	AX,WORD PTR DS:[SI]	;
	AND	AX,0FFFH		; 3 nible.
	JMP	NXTFRE5			;
NXTFRE4:				; 奇数の場合
	ADD	SI,ADRSFAT		;ROOT ＦＡＴアドレス
	MOV	AX,WORD PTR DS:[SI+1]	;
	SHR	AX,1			;
	SHR	AX,1			; 1 nible shift.
	SHR	AX,1			;
	SHR	AX,1			;
NXTFRE5:				;
	CMP	AX,0FF8H		; クラスタ番号は空きクラスタか？
	JNB	NXTFRE_HIT		;

	INC	PNTFRE			; 次の空きクラスタ番号
	JMP	NXTFRE_LOOP2		;

NXTFRE_HIT:
	MOV	AX,0			; 0=通常
	RET				;
NXTFRE_NONE:
	MOV	AX,1			; 1=空きクラスタ無し
	RET				;
NXTFRE	ENDP



;	空きクラスタ数を調べる
;	-O- FRE_CLAST : 空きクラスタ数

CNTFRE	PROC	NEAR
	PUSH	PNTNOW			; 現在のクラスタ番号
	PUSH	PNTNXT			; 続きのクラスタ番号

	MOV	FRE_CLAST,0		; 空きクラスタ数

	MOV	AX,MIN_CLAST		; 最小クラスタ番号
	MOV	PNTNOW,AX		; 現在のクラスタ番号

CNTFRE_LOOP:
	MOV	AX,PNTNOW		; 現在のクラスタ番号
	CMP	AX,MAX_CLAST		; 最大クラスタ番号を越えたら終り
	JNBE	CNTFRE_EXIT		;

	CALL	NXTNUM			; 次のクラスタ番号を取り出す

	CMP	PNTNXT,FAT_FREE_CLAST	; 空きクラスタ(FAT)か？
	JNE	CNTFRE_SKIP		;
	INC	FRE_CLAST		; 空きクラスタ数インクリメント
CNTFRE_SKIP:				;
	INC	PNTNOW			; 現在のクラスタ番号

	JMP	CNTFRE_LOOP		;

CNTFRE_EXIT:
	POP	PNTNXT			;
	POP	PNTNOW			;
	RET
CNTFRE	ENDP



;	ＦＡＴへクラスタ番号を書き込む
;	-I- PNTNOW : 書き込むＦＡＴのクラスタ位置
;	    DX     : 書き込むクラスタ番号
;
;	-I/O- MODROOTFAT : 現在のＦＡＴ内容(0=READ,1=WRITE)
;
;	    PNTNOW（ＦＡＴのクラスタ位置）がＦＦＦｈの場合は書き込まない

FATSET	PROC	NEAR
	CMP	PNTNOW,FAT_END_CLAST	; ファイル本体クラスタの最小値(FAT)
	JNB	FATSET_EXIT		;

	AND	DX,0FFFH		; 3 nible mask.

	MOV	AX,PNTNOW		; 現在のクラスタ番号
	SHR	AX,1			; / 2
	MOV	SI,AX			; ＦＡＴテーブルのアドレスポインタ
	ADD	SI,AX			;
	ADD	SI,AX			; ( * 3 )
	ADD	SI,ADRSFAT		; ROOT ＦＡＴアドレス

	MOV	AX,PNTNOW		; 現在のクラスタ番号
	SHR	AX,1			; 奇数か偶数かの判定
	JB	FATSET2			;

					; 偶数の場合
	AND	WORD PTR DS:[SI],0F000H	; 1 nible mask.
	OR	WORD PTR DS:[SI],DX	;
	JMP	FATSET3			;
FATSET2:				; 奇数の場合
	AND	WORD PTR DS:[SI+1],0FH	; 1 nible mask.
	SHL	DX,1			;
	SHL	DX,1			; 1 nible shift.
	SHL	DX,1			;
	SHL	DX,1			;
	OR	WORD PTR DS:[SI+1],DX	;
FATSET3:				;
	MOV	MODROOTFAT,1		; 現在のＦＡＴ内容(0=READ,1=WRITE)
FATSET_EXIT:				;
	RET				;
FATSET	ENDP


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



;	ＦＡＴ＋ＲＯＯＴの書き込み
;	-O- AX : 0=正常, 2=ディスクエラー

SSWDIR	PROC	NEAR
	PUSH	BX			;
	PUSH	CX			;
	PUSH	DX			;
	PUSH	DI			;
	PUSH	SI			;
	PUSH	ES			;

	CALL	SAVFAT			; ＦＡＴ＆ＲＯＯＴセーブ
	CMP	DERROR,1		; ディスクエラー
	JE	SSWDIR_ERROR		;

	MOV	AX,0			; 0=正常
	POP	ES			;
	POP	SI			;
	POP	DI			;
	POP	DX			;
	POP	CX			;
	POP	BX			;
	RET				;
SSWDIR_ERROR:
	MOV	AX,2			; 2=ディスクエラー
	POP	ES			;
	POP	SI			;
	POP	DI			;
	POP	DX			;
	POP	CX			;
	POP	BX			;
	RET				;
SSWDIR	ENDP


;	ＦＡＴ＋ＲＯＯＴのロード（ドア開閉スキップ付き）
;	-I/O- LOADFAT_LOG : 0=ロードが必要,1=ＦＡＴロード済み
;	-O-   DERROR      : 0=正常,1=エラー

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
	CALL	LODFAT			; ＦＡＴ＆ＲＯＯＴロード
	CMP	DERROR,0		; 0=正常
	JNE	LOAD_FDTOP9		;

	MOV	LOADFAT_LOG,1		; 1=ＦＡＴロード済み
LOAD_FDTOP9:
	POP	SI			;
	RET				;
LOAD_FDTOP	ENDP


;	ＦＡＴ＋ＲＯＯＴのセーブ
;	書き換えがなければディスクへはアクセスしない
;	-I/O- MODROOTFAT : 現在のＦＡＴ内容(0=READ,1=WRITE)
;	-O-   DERROR : 0=正常,1=エラー

SAVE_FDTOP	PROC	NEAR
	MOV	DERROR,0		; 0=正常,1=エラー

	CMP	MODROOTFAT,1		; 現在のＦＡＴ内容(0=READ,1=WRITE)
	JNE	SAVE_FDTOP_EXIT		;

	CALL	SAVFAT			; ＦＡＴ＆ＲＯＯＴセーブ
	CMP	DERROR,0		; ディスクエラー
	JNE	SAVE_FDTOP_EXIT		;
SAVE_FDTOP_EXIT:
	RET
SAVE_FDTOP	ENDP


;	ＦＡＴ＆ＲＯＯＴロード
;	（ＦＡＴとＲＯＯＴディレクトリは連続しています）
;	-O- DERROR 	: 0=正常,1=エラー

LODFAT	PROC	NEAR
	PUSH	DI

	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,ADRSFAT		;ROOT ＦＡＴアドレス
	MOV	DX,1			; レコード番号
	MOV	CX,FAT_CLAST+ROOT_CLAST	; ＦＡＴ＋ＲＯＯＴクラスタ数
	CALL	SSRRRD			; 連続レコード順次読み出し
	CMP	AX,0			; 0=正常, 2=ディスクエラー
	JNE	LODFAT_ERROR		;

	MOV	MODROOTFAT,0		; 現在のＦＡＴ内容(0=READ,1=WRITE)

	MOV	DERROR,0		; 0=正常
	POP	DI
	RET
LODFAT_ERROR:				;
	MOV	DERROR,1		; 1=エラー
	POP	DI
	RET				;
LODFAT	ENDP


;	ＦＡＴ＆ＲＯＯＴセーブ
;	（ＦＡＴとＲＯＯＴディレクトリは連続しています）
;	-O- DERROR 	: 0=正常,1=エラー

SAVFAT	PROC	NEAR
	PUSH	DI

	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,ADRSFAT		;ROOT ＦＡＴアドレス
	MOV	DX,1			; レコード番号
	MOV	CX,FAT_CLAST+ROOT_CLAST	; ＦＡＴ＋ＲＯＯＴクラスタ数
	CALL	SSWRWT			; 連続レコード順次書き込み
	CMP	AX,0			; 0=正常, 2=ディスクエラー
	JNE	SAVFAT_ERROR		;

	MOV	MODROOTFAT,0		; 現在のＦＡＴ内容(0=READ,1=WRITE)

	MOV	DERROR,0		; 0=正常
	POP	DI
	RET
SAVFAT_ERROR:				;
	MOV	DERROR,1		; 1=エラー
	POP	DI
	RET				;
SAVFAT	ENDP


;	ドライブ番号の取得
;	-O- AX : １ＭＦＤドライブ番号

DRVNO	PROC	NEAR
	MOV	AX,DUNIT		; デバイス識別・ユニット番号（DA/UA）
	AND	AX,00000011B		; DA/UA=100100dd
	RET				;
DRVNO	ENDP


;	ドライブ番号の設定
;	-I- AX : １ＭＦＤドライブ番号

DRVSET	PROC	NEAR
	AND	AL,011B			;
	AND	BYTE PTR DUNIT,11111100B
	OR	BYTE PTR DUNIT,AL	;
	RET
DRVSET	ENDP


;	ＲＯＯＴバッファ候補
;	-I- DRVNUM : 指定ドライブ
;	-O- DERROR : 0=正常,1=エラー

FAT_BUFF_SLCT	PROC	NEAR
	MOV	DERROR,0		;

	MOV	AX,DRVNUM		; 指定ドライブ
	CMP	AX,BUFDRIVE		; ROOT 対応ドライブ
	JMPEQ	FAT_BUFF_SLCT_EXIT

	MOV	SI,TBLBUFPNT		; テーブルレコード番号
	SHL	SI,1			; word pointer.
	MOV	AX,BUFDRIVE		; ROOT 対応ドライブ
	MOV	TBLBUFDRIVE[SI],AX	; 対応ドライブテーブル
	MOV	AX,BUFACCESS		; ROOT 未アクセス回数
	MOV	TBLBUFACCESS[SI],AX	; 未アクセス回数テーブル
	MOV	AX,MODROOTFAT		; ROOT ＦＡＴ内容(0=READ,1=WRITE)
	MOV	TBLMODROOTFAT[SI],AX	; ＦＡＴ内容(0=READ,1=WRITE)
	MOV	AX,LOADFAT_LOG		; ROOT0=ロードが必要,1=ＦＡＴロード済み
	MOV	TBLLOADFAT_LOG[SI],AX	; 0=ロードが必要,1=ＦＡＴロード済み

	MOV	DX,DRVNUM		; 指定ドライブ
	MOV	CX,TBLBUFMAX		; テーブルレコード数
	MOV	SI,OFFSET TBLBUFDRIVE	; 対応ドライブテーブル
	CALL	SCH_SAME_NUM		; テーブルから指定値サーチ
	CMP	AX,1			; 1=ok,0=none.
	JE	FAT_BUFF_SLCT_CHG	;

	MOV	CX,TBLBUFMAX		; テーブルレコード数
	MOV	SI,OFFSET TBLBUFACCESS	; 未アクセス回数テーブル
	CALL	SCH_BIG_NUM		; テーブルから最大値サーチ

	MOV	TBLBUFPNT,BX		; テーブルレコード番号
	SHL	BX,1			; サーチレコード(word pointer)

	MOV	AX,TBLBUFDRIVE[BX]	; 対応ドライブテーブル
	MOV	BUFDRIVE,AX		; ROOT 対応ドライブ
	MOV	AX,TBLBUFACCESS[BX]	; 未アクセス回数テーブル
	MOV	BUFACCESS,AX		; ROOT 未アクセス回数
	MOV	AX,TBLMODROOTFAT[BX]	; ＦＡＴ内容(0=READ,1=WRITE)
	MOV	MODROOTFAT,AX		; ROOT ＦＡＴ内容(0=READ,1=WRITE)
	MOV	AX,TBLLOADFAT_LOG[BX]	; 0=ロードが必要,1=ＦＡＴロード済み
	MOV	LOADFAT_LOG,AX		; ROOT0=ロードが必要,1=ＦＡＴロード済み
	MOV	AX,TBLADRSFAT[BX]	; ＦＡＴアドレステーブル
	MOV	ADRSFAT,AX		; ROOT ＦＡＴアドレス
	MOV	AX,TBLADRSROOTDIR[BX]	; ＲＯＯＴアドレステーブル
	MOV	ADRSROOTDIR,AX		; ROOT ＲＯＯＴアドレス

	MOV	AX,BUFDRIVE		; ROOT 対応ドライブ
	CALL	DRVSET			; ドライブ番号の設定

	CALL	SAVE_FDTOP		; ＦＡＴ＋ＲＯＯＴのセーブ
	CMP	DERROR,0		; 1=エラー
	JNE	FAT_BUFF_SLCT_EXIT	;

	MOV	BUFACCESS,0		; ROOT 未アクセス回数
	MOV	AX,DRVNUM		; 指定ドライブ
	MOV	BUFDRIVE,AX		; ROOT 対応ドライブ
	MOV	MODROOTFAT,0		; ROOT ＦＡＴ内容(0=READ,1=WRITE)
	MOV	LOADFAT_LOG,0		; ROOT0=ロードが必要,1=ＦＡＴロード済み

	MOV	AX,DRVNUM		; 指定ドライブ
	CALL	DRVSET			; ドライブ番号の設定

	CALL	LOAD_FDTOP		; ＦＡＴ＋ＲＯＯＴのロード
	JMP	FAT_BUFF_SLCT_EXIT

FAT_BUFF_SLCT_CHG:
	MOV	TBLBUFPNT,BX		; テーブルレコード番号
	SHL	BX,1			; サーチレコード(word pointer)

	MOV	AX,TBLBUFDRIVE[BX]	; 対応ドライブテーブル
	MOV	BUFDRIVE,AX		; ROOT 対応ドライブ
	MOV	AX,TBLBUFACCESS[BX]	; 未アクセス回数テーブル
	MOV	BUFACCESS,AX		; ROOT 未アクセス回数
	MOV	AX,TBLMODROOTFAT[BX]	; ＦＡＴ内容(0=READ,1=WRITE)
	MOV	MODROOTFAT,AX		; ROOT ＦＡＴ内容(0=READ,1=WRITE)
	MOV	AX,TBLLOADFAT_LOG[BX]	; 0=ロードが必要,1=ＦＡＴロード済み
	MOV	LOADFAT_LOG,AX		; ROOT0=ロードが必要,1=ＦＡＴロード済み
	MOV	AX,TBLADRSFAT[BX]	; ＦＡＴアドレステーブル
	MOV	ADRSFAT,AX		; ROOT ＦＡＴアドレス
	MOV	AX,TBLADRSROOTDIR[BX]	; ＲＯＯＴアドレステーブル
	MOV	ADRSROOTDIR,AX		; ROOT ＲＯＯＴアドレス

	MOV	BUFACCESS,0		; ROOT 未アクセス回数

	MOV	AX,DRVNUM		; 指定ドライブ
	CALL	DRVSET			; ドライブ番号の設定

FAT_BUFF_SLCT_EXIT:
	INC	BUFACCESS		; ROOT 未アクセス回数

	MOV	SI,OFFSET TBLBUFACCESS	; 未アクセス回数テーブル
	MOV	CX,TBLBUFMAX		; テーブルレコード数
	CALL	TBLINCLIMENT		; テーブルインクリメント

	RET
FAT_BUFF_SLCT	ENDP


;	テーブルから指定値サーチ
;	-I- DX    : 指定値
;	    DS:SI : テーブル
;	    CX    : テーブルレコード数
;	-O- AX    : 1=ok,0=none.
;	    BX    : サーチレコード

SCH_SAME_NUM	PROC	NEAR
	MOV	BX,0
SCH_SAME_NUM_LOOP:
	LODSW
	CMP	AX,DX			; 指定値
	JE	SCH_SAME_NUM_SCH	;
	INC	BX			; サーチレコード
	LOOP	SCH_SAME_NUM_LOOP	;

	MOV	AX,0			; 0=none.
	RET
SCH_SAME_NUM_SCH:
	MOV	AX,1			; 1=ok.
	RET
SCH_SAME_NUM	ENDP


;	テーブルから最大値サーチ
;	-I- DS:SI : テーブル
;	    CX    : テーブルレコード数
;	-O- BX    : サーチレコード

SCH_BIG_NUM	PROC	NEAR
	MOV	DI,0
	MOV	BX,0
	MOV	DX,0
	JCXZ	SCH_BIG_NUM_EXIT
SCH_BIG_NUM_LOOP:
	LODSW
	CMP	AX,DX			; 指定値
	JBE	SCH_BIG_NUM_NEXT	;
	MOV	DX,AX			;
	MOV	DI,BX			; サーチレコード
SCH_BIG_NUM_NEXT:
	INC	BX			;
	LOOP	SCH_BIG_NUM_LOOP	;

SCH_BIG_NUM_EXIT:
	MOV	BX,DI			; サーチレコード
	RET
SCH_BIG_NUM	ENDP


;	テーブルインクリメント
;	-I- DS:SI : テーブル
;	    CX    : テーブルレコード数

TBLINCLIMENT	PROC	NEAR

	JCXZ	TBLINCLIMENT_EXIT
TBLINCLIMENT_LOOP:
	INC	WORD PTR DS:[SI]
	INC	SI
	INC	SI
	LOOP	TBLINCLIMENT_LOOP
TBLINCLIMENT_EXIT:
	RET
TBLINCLIMENT	ENDP


;	ドライブ番号の設定（０ー３）
;	-I- AX : １ＭＦＤドライブ番号
;	-O- AX : 0=正常,1=ドライブ番号エラー,2=ディスクエラー

SSRDRV	PROC	NEAR
	PUSH	BX			;
	PUSH	CX			;
	PUSH	DX			;
	PUSH	DI			;
	PUSH	SI			;
	PUSH	ES			;

	MOV	DRVNUM,AX		; 指定ドライブ

	CMP	AX,LAST_DRIVE		; 最後のドライブ番号
	JNBE	SSRDRV_DNO_ERROR	;

	CALL	FAT_BUFF_SLCT		; ＲＯＯＴバッファ候補
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
SSRDRV_DNO_ERROR:
	POP	ES			;
	POP	SI			;
	POP	DI			;
	POP	DX			;
	POP	CX			;
	POP	BX			;
	MOV	AX,1			; 1=ドライブ番号エラー
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
	CALL	DRVNO			; ドライブ番号の取得
	RET
SSRDNO	ENDP


;	ドライブのリセット（０ー３）
;	-I- AX : １ＭＦＤドライブ番号（０ー３）
;	-O- AX : 0=正常,1=ドライブ番号エラー,2=ディスクエラー

SSRRST	PROC	NEAR
	PUSH	BX			;
	PUSH	CX			;
	PUSH	DX			;
	PUSH	DI			;
	PUSH	SI			;
	PUSH	ES			;

	CMP	AX,LAST_DRIVE		; 最後のドライブ番号
	JNBE	SSRRST_DNO_ERROR	;

	MOV	RESET_DRIVE,AX		; リセットドライブ番号

	MOV	BX,RESET_DRIVE		; リセットドライブ番号
	MOV	DS:DISK_DOOR_INI[BX],0FFH ; ディスク開閉初期ﾌﾗｸﾞ

	CALL	DRVNO			; ドライブ番号の取得
	CMP	AX,RESET_DRIVE		; リセットドライブ番号
	JNE	SSRRST_NORMAL		;

	CALL	SAVE_FDTOP		; ＦＡＴ＋ＲＯＯＴのセーブ
	CMP	DERROR,0		; 1=エラー
	JNE	SSRRST_ERROR		;
SSRRST_NORMAL:
	MOV	AX,0			; 0=正常
	JMP	SSRRST_EXIT		;
SSRRST_DNO_ERROR:
	MOV	AX,1			; 1=ドライブ番号エラー
	JMP	SSRRST_EXIT		;
SSRRST_ERROR:
	MOV	AX,2			; 2=ディスクエラー
SSRRST_EXIT:
	POP	ES			;
	POP	SI			;
	POP	DI			;
	POP	DX			;
	POP	CX			;
	POP	BX			;
	RET
SSRRST	ENDP


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
;*DBG*;	PRV "１ＭＦＤドライブ番号（０ー３）=",AX
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
;*DBG*;	PRV	"0=前と変わらず,1=ドアを開閉した,2=ドアが開きっぱなし=",AX
	RET				;
FDRSLT	ENDP



;	指定ファイル名のカラム合わせ ex. "TEST.ASM"->"TEST____ASM"
;	-I- DS:SI  : ファイル名
;	-O- FLNAME : ファイル名

FLNSET	PROC	NEAR
	PUSH	SI			;

;*NON*;	CALL	SPACE_PLESS		; ブランク抜き

	MOV	AX,SEG DATA		;
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

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

PUBLIC	ADRSFAT				; ROOT ＦＡＴアドレス
PUBLIC	ADRSROOTDIR			; ROOT ＲＯＯＴアドレス

PUBLIC	PNTNOW				; 現在のクラスタ番号
PUBLIC	PNTNXT				; 続きのクラスタ番号
PUBLIC	PNTFRE				; 次の空きクラスタ番号

PUBLIC	DREAD				; ＲＥＡＤ　ＤＡＴＡ
PUBLIC	DWRITE				; ＷＲＩＴＥ　ＤＡＴＡ
PUBLIC	DRECAL				; ＲＥＣＡＬＩＢＲＡＴＥ
PUBLIC	DUNIT				; デバイス識別・ユニット番号（DA/UA）

EXTRN	FAT1:BYTE			; ＦＡＴテーブル
EXTRN	ROOTDIR1:BYTE			; ＲＯＯＴＤＩＲ
EXTRN	FAT2:BYTE			; ＦＡＴテーブル
EXTRN	ROOTDIR2:BYTE			; ＲＯＯＴＤＩＲ

LAST_DRIVE	DW	3		; 最後のドライブ番号＝３

;		ＢＩＯＳコマンド識別コード

;			MM-S....	;
;			TFrK0110	;
DREAD		DW	11110110B	; ＲＥＡＤ　ＤＡＴＡ
DWRITE		DW	01110101B	; ＷＲＩＴＥ　ＤＡＴＡ
DRECAL		DW	00100111B	; ＲＥＣＡＬＩＢＲＡＴＥ
DSENSE		DW	04H		; ＳＥＮＳＥ
;			100100dd	;
DUNIT		DW	10010000B	; デバイス識別・ユニット番号（DA/UA）
DERROR		DW	0		; 0=正常,1=エラー

DISK_DOOR_INI	DB 0FFH,0FFH,0FFH,0FFH	; ディスク開閉初期ﾌﾗｸﾞ

BUFDRIVE	DW	0		;ROOT 対応ドライブ
BUFACCESS	DW	0		;ROOT 未アクセス回数
MODROOTFAT	DW	0		;ROOT ＦＡＴ内容(0=READ,1=WRITE)
LOADFAT_LOG	DW	0		;ROOT 0=ロードが必要,1=ＦＡＴロード済み
ADRSFAT		DW	FAT1		;ROOT ＦＡＴアドレス
ADRSROOTDIR	DW	ROOTDIR1	;ROOT ＲＯＯＴアドレス

TBLBUFMAX	DW	2		; テーブルレコード数
TBLBUFPNT	DW	0		; テーブルレコード番号
TBLBUFDRIVE	LABEL	WORD		; 対応ドライブテーブル
		DW	2 DUP (0)
TBLBUFACCESS	LABEL	WORD		; 未アクセス回数テーブル
		DW	2 DUP (0)
TBLMODROOTFAT	LABEL	WORD		; ＦＡＴ内容(0=READ,1=WRITE)
		DW	2 DUP (0)
TBLLOADFAT_LOG	LABEL	WORD		; 0=ロードが必要,1=ＦＡＴロード済み
		DW	2 DUP (0)
TBLADRSFAT	LABEL	WORD		; ＦＡＴアドレステーブル
		DW	FAT1,FAT2
TBLADRSROOTDIR	LABEL	WORD		; ＲＯＯＴアドレステーブル
		DW	ROOTDIR1,ROOTDIR2

;*;FAT1		DB LEN_CLAST*FAT_CLAST DUP (0)		; ＦＡＴテーブル
;*;ROOTDIR1	DB LEN_CLAST*ROOT_CLAST DUP (0)		; ＲＯＯＴＤＩＲ
;*;		DB 0,0
;*;FAT2		DB LEN_CLAST*FAT_CLAST DUP (0)		; ＦＡＴテーブル
;*;ROOTDIR2	DB LEN_CLAST*ROOT_CLAST DUP (0)		; ＲＯＯＴＤＩＲ
;*;		DB 0,0

FLNAME		DB	FLNLEN DUP (20H) ; ファイル名
FLTYPE		DB	FLTLEN DUP (20H) ; 拡張子
		DB	0,0		 ;

		EVEN			;
ETADRS		DW	0		; ディレクトリ・エントリのオフセット

NUM		DW	0		; レコード番号

DRVNUM		DW	0		; 指定ドライブ

PNTNOW		DW	0		; 現在のクラスタ番号
PNTNXT		DW	0		; 続きのクラスタ番号
PNTFRE		DW	0		; 次の空きクラスタ番号
FRE_CLAST	DW	0		; 空きクラスタ数

DISK_INFORMATION	LABEL	WORD	; ディスク情報テーブル
		DW	0		;[ セクタ数／１クラスタ   ]
		DW	0		;[ 空きクラスタ数         ]
		DW	0		;[ バイト数／１セクタ     ]
		DW	0		;[ クラスタ数／１ドライブ ]

RESET_DRIVE	DW	0		; リセットドライブ番号

DATA	ENDS

	END

;
;	end of "READWT.ASM"
;
