; "PSMAIN.ASM" PC-9801UV11 make by R.H 1989/11/13
;			1990/10/09 R.H
;	E X E L O A D    c o m m a n d   s h e l l .
;
;
;
; command.

INCLUDE	TSTSET.INC

CODE	SEGMENT	PUBLIC	'CODE'
	ASSUME	CS:CODE,DS:DATA

PUBLIC	PSMAIN			; programers command shell.

EXTRN	I21HSET:NEAR		; 割込みを設定
EXTRN	I21HRST:NEAR		; 割込み元に戻す
EXTRN	I21HDRV:NEAR		; デフォルトドライブ番号
EXTRN	I21HRET:NEAR		; プロセスへの戻りアドレス設定

EXTRN	CMTYPE:NEAR		; テキストファイルの表示

EXTRN	CMIOCK:NEAR		; Ｉ／Ｏ変化チェック
EXTRN	CMCKEY:NEAR		; キー入力ＢＩＯＳチェック
EXTRN	CMCTMP:NEAR		; 秘密変数の表示等
EXTRN	CMCEXE:NEAR		; 標準ＤＯＳのロードモジュールチェック
EXTRN	CMCMEM:NEAR		; メモリーダンプ
EXTRN	CMCSNS:NEAR		; センスコマンドテスト
EXTRN	CMCSN2:NEAR		; 旧センスコマンドテスト
EXTRN	CMCSN3:NEAR		; センスコマンドテストＷＡＩＴ付き

EXTRN	CMDIR:NEAR		; ＤＩＲ
EXTRN	CMFAT:NEAR		; ＦＡＴダンプ

EXTRN	CMLET:NEAR		; 計算機能

EXTRN	CMLOAD:NEAR		; ＬＯＡＤ
EXTRN	CMLCOM:NEAR		; ＬＯＡＤ／ＣＯＭファイル
EXTRN	CMLEXE:NEAR		; ＬＯＡＤ／ＥＸＥファイル

EXTRN	CMPCOM:NEAR		; 標準ＣＯＭプロセス
EXTRN	CMPROC:NEAR		; 標準ＤＯＳプロセス

EXTRN	CMKILL:NEAR		; ＫＩＬＬ
EXTRN	CMFFIL:NEAR		; 真っ白のファイルを作る
EXTRN	CMCOPY:NEAR		; ＣＯＰＹ

EXTRN	CMFORM:NEAR		; ディスクフォーマッティング

EXTRN	CMMINT:NEAR		; メモリ管理初期化
EXTRN	CMFREE:NEAR		; フリーエリアの開始位置
EXTRN	CMMALC:NEAR		; 使用エリアの確保
EXTRN	CMMCUT:NEAR		; 使用エリアの開放

EXTRN	SSSEEK:NEAR		; クラスタのシーク

EXTRN	PRNAH:NEAR		; print ah reg.
EXTRN	PRINT:NEAR		; print string.
EXTRN	DECSTR:NEAR		; val DX to dec string.
EXTRN	INPUT:NEAR		; string input.
EXTRN	STRDEC:NEAR		; dec string to DX reg.
EXTRN	HEXSTR:NEAR		; val DX to hex string.
EXTRN	STRHEX:NEAR		; hex string to DX reg.
EXTRN	BINSTR:NEAR		; val DX to bin string.
EXTRN	STRBIN:NEAR		; bin string to DX reg.
EXTRN	STRCMP:NEAR		; string compare.
EXTRN	CLS:NEAR		; text clear.
EXTRN	CSLON:NEAR		; cursole on.
EXTRN	CSLOFF:NEAR		; cursole off.
EXTRN	INPCHR:NEAR		; 1 char input.
EXTRN	CHPUT:NEAR		; print of ascii character.
EXTRN	KESCAP:NEAR		; ESC key & break check & pause.
EXTRN	KEYLOD:NEAR		; key buffer read.
EXTRN	PRNAB:NEAR		; print of a register(BIN).
EXTRN	LOCATE:NEAR		; locate.
EXTRN	LFPRN:NEAR		; line feed.
EXTRN	D10STR:NEAR		; i*4 value -> decimal string.

EXTRN	FFDRV:NEAR		; カレントドライブ設定

CHR_SPACE	EQU	20H	; space.
CHR_TAB		EQU	09H	; tab.
CHR_LF		EQU	0AH	; line feed.
CHR_CR		EQU	0DH	; calig return.
EOS		EQU	0	; end of string.
STRING_LEN	EQU	128	; string buffer length.
TOKEN_MAX	EQU	4	; token max.


;	programers command shell.
;	-I- DX:cullent drive number.

PSMAIN	PROC	NEAR
	PUSH	DX
	CALL	I21HSET		; 割込みを設定
	POP	DX

	CALL	SETUNIT		; unit name set.

	CMP	AX,2		; disk error.
	JNE	PSHELL_2	;
	MOV	SI,OFFSET MES_NOT_DIR
	CALL	PRINT		;
PSHELL_2:
	CALL	AUTOEXEC	; autoexec
	CALL	CINIT		; shell init.
PSHELL_INP:
	CALL	CINP		; console input.
	CALL	CCHECK		; check.
	CMP	NONE,1		; none?
	JE	PSHELL_INP	;

	CALL	CCMP		; comp. -> COMMAND_NUM
	CMP	NOT_FOUND,1	; 1=not found.
	JE	PSHELL_PROCESS	;

	CALL	TOKADR		; token get address.

	CALL	SPACE_CUT	; space cut.

	CALL	CCOMMAND	; command processer.
	CMP	EXIT,1		; exit?
	JE	PSHELL_END	;

	JMP	PSHELL_INP	; next.

PSHELL_PROCESS:
	CALL	CPROCESS	; process.
	CMP	AX,0		; 0=正常,1=プロセスはない
	JE	PSHELL_NEXT	;

	MOV	SI,OFFSET CLINE	; コマンドライン
	CALL	PRINT		;
	MOV	SI,OFFSET MSG_TYPE_ERROR
	CALL	PRINT		;

PSHELL_NEXT:
	JMP	PSHELL_INP	; next.
PSHELL_END:
	CALL	CFIN		; shell finale.

	CALL	I21HRST		; 割込み元に戻す
	RET
PSMAIN	ENDP


;	shell init.

CINIT	PROC	NEAR
;*NON*;	CALL	CLS
	MOV	SI,OFFSET MES_WELCOME
	CALL	PRINT
	RET
CINIT	ENDP


;	console input.
;	-O- DS:SI :string address.

CINP	PROC	NEAR
	CALL	CLR_CLINE
	MOV	SI,OFFSET MES_PROMPT
	CALL	PRINT
	CALL	INPUT
	PUSH	SI
	MOV	SI,OFFSET MES_CRLF
	CALL	PRINT
	POP	SI
	RET
CINP	ENDP


;	check.
;	-I- DS:SI : string address.
;	-O- CLINE : command line.
;	    NONE  : 1=none, 0=normal.

CCHECK	PROC	NEAR
	CALL	CNTL_SPACE		; control code -> space.
	CALL	COLUM_SET		; string colum set.
	MOV	DI,OFFSET CLINE		;
	CALL	STRING_COPY		;
	CMP	CLINE,EOS		; none string ?
	JE	CCHECK_NONE		;
	CALL	COLUM_ESE		; special command colum.
	MOV	NONE,0		; normal.
	RET
CCHECK_NONE:
	MOV	NONE,1		; none!
	RET
CCHECK	ENDP


;	comp.
;	-I-   CLINE       : command line.
;	-O-   COMMAND_NUM : command number.
;	      NOT_FOUND   : 0=normal, 1=not found.

CCMP	PROC	NEAR
	MOV	COMMAND_NUM,0		; command number.
CCMP_SEARCH:
	MOV	BX,COMMAND_NUM		;
	CMP	BX,COMMAND_MAX		; command max.
	JE	CCMP_NOT_FOUND		;

	SHL	BX,1			;
	MOV	DI,OFFSET CLINE		; command line.
	MOV	SI,DS:COMMAND_TABLE[BX]	; token table.

	CALL	TOKEN_COMP		; token comp.
	CMP	AX,1			; 1=same
	JE	CCMP_FIND		;

	INC	COMMAND_NUM		;
	JMP	CCMP_SEARCH		;

CCMP_FIND:
	MOV	NOT_FOUND,0		; normal.
	JMP	CCMP9

CCMP_NOT_FOUND:
	MOV	NOT_FOUND,1		; not found.
CCMP9:
	RET
CCMP	ENDP


;	process.
;	-I- CLINE     : コマンドライン
;	-O- AX        : 0=正常,1=プロセスはない

CPROCESS	PROC	NEAR
	CALL	CMFREE			; フリーエリアの開始位置

	MOV	SI,OFFSET CLINE		; コマンドライン
	CALL	CMLCOM			; ＬＯＡＤ／ＣＯＭファイル
	CMP	AX,0			; 0=正常, 1=ファイル無し, 2=エラー
	JE	CPROCESS_COM		;


	CALL	CMFREE			; フリーエリアの開始位置

	MOV	SI,OFFSET CLINE		; コマンドライン
	CALL	CMLEXE			; ＬＯＡＤ／ＥＸＥファイル
	CMP	AX,0			; 0=正常, 1=ファイル無し, 2=エラー
	JE	CPROCESS_EXE		;

	JMP	CPROCESS_NONE		;

CPROCESS_COM:
	CALL	CMPCOM			; 標準ＣＯＭプロセス
	JMP	CPROCESS_EXIT		;
CPROCESS_EXE:
	CALL	CMPROC			; 標準ＤＯＳプロセス
	JMP	CPROCESS_EXIT		;
CPROCESS_EXIT:
	MOV	AX,0			; 0=正常
	RET

CPROCESS_NONE:
	MOV	AX,1			; 1=プロセスはない
	RET
CPROCESS	ENDP


;	command processer.
;	-I-   COMMAND_NUM : command number.
;	      CLINE       : command line.
;	      CTOKEN[]    : token address table.
;	      TOKEN_CNT   : token count.
;	-O-   EXIT        : 1=exit, 0=normal.

CCOMMAND	PROC	NEAR
	MOV	BX,COMMAND_NUM
	CMP	BX,COMMAND_MAX
	JL	CCOMMAND_JUMP
	RET

CCOMMAND_JUMP:
	SHL	BX,1		; word pointer.
	JMP	WORD PTR CS:CCOMMAND_TBL[BX]
		EVEN
CCOMMAND_TBL	LABEL	WORD
	DW	CM_DIR		; directory.
	DW	CM_TYPE		; type of text file.
	DW	CM_CLS		; clear screen.
	DW	CM_IOCK		; I/O test.
	DW	CM_CKEY		; check key.
	DW	CM_DNO		; drive number(1-4)
	DW	CM_LET		; calc.
	DW	CM_CTMP		; temp parameter dump.
	DW	CM_EXIT		; exit shell.
	DW	CM_CEXE		; DOS load module check.
	DW	CM_HELP		; help.
	DW	CM_LOAD		; file load to memory.
	DW	CM_FREE		; free area.
	DW	CM_CMEM		; memory dump.
	DW	CM_PROC		; standard dos proccess.
	DW	CM_15		; sense(command/status) command test.
	DW	CM_16		; sense(SENSE) command test.
	DW	CM_17		; file kill.
	DW	CM_18		; fill file creat.
	DW	CM_19		; FAT dump.
	DW	CM_20		; file copy.
	DW	CM_21		; FORMAT.
	DW	CM_22		; com proccess.
	DW	CM_23		; センスコマンドテストＷＡＩＴ付き
	DW	CM_24		; seek speed test.
	DW	CM_25
	DW	CM_26
	DW	CM_27
	DW	CM_28
	DW	CM_29
	DW	CM_30
CM_DIR:					; directory.
	CALL	CMDIR			; ＤＩＲ
	RET

CM_TYPE:				; type of text file.
	MOV	SI,CTOKEN[2]		; token address table.
	CALL	CMTYPE			; テキストファイルの表示
	RET

CM_CLS:					; clear screen.
	CALL	CLS			; text clear.
	CALL	CSLOFF			; cursole off.
	RET

CM_IOCK:				; I/O test.
	MOV	SI,CTOKEN[2]		; token address table.
	CALL	STRHEX			; hex string to DX reg.
	CALL	CMIOCK			; Ｉ／Ｏ変化チェック
	RET

CM_CKEY:				; check key.
	CALL	CMCKEY			; キー入力ＢＩＯＳチェック
	RET

CM_DNO:					; drive number(1-4)
	MOV	SI,CTOKEN[2]		; token address table.
	CALL	STRDEC			; dec string to DX reg.
	CMP	DX,0			;
	JE	CM_DNO2			;
	CMP	DX,5			;
	JNB	CM_DNO2			;

	CALL	SETUNIT			; unit name set.

	CMP	AX,2			; disk error.
	JNE	CM_DNO2			;
	MOV	SI,OFFSET MES_NOT_DIR
	CALL	PRINT
CM_DNO2:
	RET

CM_LET:
	MOV	SI,CTOKEN[2]		; token address table.
	CALL	CMLET			; 計算機能
	RET

CM_CTMP:				; temp parameter dump.
	CALL	CMCTMP			; 秘密変数の表示等
	RET

CM_EXIT:				; exit shell.
	MOV	EXIT,1			; exit.
	RET

CM_CEXE:				; DOS load module check.
	MOV	SI,CTOKEN[2]		; token address table.
	CALL	CMCEXE			; 標準ＤＯＳのロードモジュールチェック
	RET

CM_HELP:				; help.
	CALL	HELPDSP			; help.
	RET

CM_LOAD:				; file load to memory.
	CALL	CMFREE			; フリーエリアの開始位置
	MOV	SI,CTOKEN[2]		; token address table.
	CALL	CMLOAD			; ＬＯＡＤ
	RET

CM_FREE:				; free area.
	CALL	CMFREE			; フリーエリアの開始位置
	MOV	SI,OFFSET MSG_FREE	;
	CALL	PRINT			;
	MOV	DX,ES			; フリーエリアの開始パラグラフ値
	CALL	HEXSTR			;
	CALL	PRINT			;
	MOV	SI,OFFSET MSG_SEGUNIT	;
	CALL	PRINT			;
	CALL	LFPRN			; line feed.
	RET
CM_CMEM:				; memory dump.
	MOV	SI,CTOKEN[2]		; token address table.
	CALL	STRADRS			; address string -> ES:DI
	CALL	CMCMEM			; メモリーダンプ
	RET
CM_PROC:				; standard dos proccess.
	CALL	CMFREE			; フリーエリアの開始位置
	CALL	CLS			; cls.
	MOV	DX,ES			;
	MOV	BX,ES			;
	MOV	AX,0A000H		;
	MOV	ES,AX			; 実行ファイルのロード後フリーエリア
	CALL	CMPROC			; 標準ＤＯＳプロセス

	CALL	CSLOFF			; cursole off.
	RET
CM_15:
	CALL	CMCSNS			; センスコマンドテスト
	RET
CM_16:
	CALL	CMCSN2			; 旧センスコマンドテスト
	RET
CM_17:
	MOV	SI,CTOKEN[2]		; token address table.
	CALL	CMKILL			; ＫＩＬＬ
	RET
CM_18:
	MOV	SI,CTOKEN[2]		; token address table.
	MOV	CX,10000		; file size.
	CALL	CMFFIL			; 真っ白のファイルを作る
	RET
CM_19:
	CALL	CMFAT			; ＦＡＴダンプ
	RET
CM_20:
	CMP	TOKEN_CNT,3		; token count.
	JL	CM_201			;
	MOV	SI,CTOKEN[2]		; token address table.
	MOV	BX,CTOKEN[4]		; token address table.
	CALL	CMCOPY			; ＣＯＰＹ
CM_201:
	RET

CM_21:
	CALL	CMFORM			; ディスクフォーマッティング
	RET
CM_22:
	CALL	CMFREE			; フリーエリアの開始位置
	CALL	CLS			; cls.
	MOV	DX,ES			;
	MOV	BX,ES			;
	SUB	BX,10H			; － 標準ＤＯＳプロセスのヘッダサイズ
	CALL	CMPCOM			; 標準ＣＯＭプロセス

	CALL	CSLOFF			; cursole off.
	RET
CM_23:
	CALL	CMCSN3			; センスコマンドテストＷＡＩＴ付き
	RET
CM_24:					; seek speed test.
	INP	"start clast : "
	CALL	STRDEC
	PUSH	DX
	INP	"clast count : "
	CALL	STRDEC
	MOV	CX,DX		; 先頭から何クラスタか
	POP	DX		; 先頭クラスタ番号
	CALL	SSSEEK		; クラスタのシーク
	PRV	"0=正常,1=範囲外 :",AX
	PRV	"クラスタ番号    :",DX
	RET
CM_25:
CM_26:
CM_27:
CM_28:
CM_29:
CM_30:
	RET
CCOMMAND	ENDP


;	shell finale.

CFIN	PROC	NEAR
	MOV	SI,OFFSET MES_BYE
	CALL	PRINT
	RET
CFIN	ENDP


;	string calum set.
;	-I- DS:SI  : string address.

COLUM_SET	PROC	NEAR
	PUSH	SI

	MOV	AX,DS
	MOV	ES,AX

	MOV	DI,SI
	MOV	BX,SI
COLUM_SET2:
	LODSB			; 1 char get.
	CMP	AL,EOS
	JE	COLUM_SET9

	CMP	AL,CHR_SPACE
	JNE	COLUM_SET5
COLUM_SET3:
	LODSB			; 1 char get.
	CMP	AL,EOS
	JE	COLUM_SET9
	CMP	AL,CHR_SPACE
	JE	COLUM_SET3

	CMP	DI,BX		; command line top?
	JE	COLUM_SET5	;
	MOV	BYTE PTR DS:[DI],CHR_SPACE
	INC	DI
COLUM_SET5:
	STOSB			; 1 char put.
	JMP	COLUM_SET2
COLUM_SET9:
;;;;	MOV	BYTE PTR DS:[DI],CHR_CR	; calig return.
	MOV	BYTE PTR DS:[DI],EOS	; end of string.
	POP	SI
	RET
COLUM_SET	ENDP



;	token get address.
;	-I- CLINE     : string address.
;	-O- CTOKEN    : token address table.
;	    TOKEN_CNT : token count.

TOKADR	PROC	NEAR
	MOV	BX,0			;
	MOV	CX,TOKEN_MAX		; token max.
TOKADR_1:				;
	MOV	DS:CTOKEN[BX],OFFSET CLINE_END ; token address table.
	INC	BX			;
	INC	BX			;
	LOOP	TOKADR_1		;

	MOV	TOKEN_CNT,0		; token count.
	MOV	SI,OFFSET CLINE		; string address.
TOKADR_LOOP:
	CMP	TOKEN_CNT,TOKEN_MAX	; token max.
	JNB	TOKADR_EXIT		; max token!

TOKADR_LOOP2:
	LODSB				; 1 character get.
	CMP	AL,EOS			;
	JE	TOKADR_EXIT		; check EOS.
	CMP	AL,CHR_SPACE		; space.
	JE	TOKADR_LOOP2		;

	DEC	SI			;
	MOV	BX,TOKEN_CNT		; token count.
	SHL	BX,1			; word pointer.
	MOV	DS:CTOKEN[BX],SI	; token address table.
	INC	SI			;
	INC	TOKEN_CNT		; token count.

TOKADR_LOOP3:
	LODSB				; 1 character get.
	CMP	AL,EOS			;
	JE	TOKADR_EXIT		; check EOS.
	CMP	AL,CHR_SPACE		; space.
	JNE	TOKADR_LOOP3		;

	JMP	TOKADR_LOOP		;
TOKADR_EXIT:
	RET
TOKADR	ENDP


;	space cut.
;	-I/O- CLINE : string address.

SPACE_CUT	PROC	NEAR
	MOV	SI,OFFSET CLINE		; string address.
	MOV	CX,STRING_LEN		; string buffer length.
SPACE_CUT_LOOP:
	CMP	DS:[SI],BYTE PTR CHR_SPACE ; space.
	JNE	SPACE_CUT_NEXT		;
	MOV	DS:[SI],BYTE PTR EOS	; EOS.
SPACE_CUT_NEXT:
	INC	SI			;
	LOOP	SPACE_CUT_LOOP		;
	RET
SPACE_CUT	ENDP



;	special command colum.
;	-I- CLINE  : string address.

COLUM_ESE	PROC	NEAR
	PUSH	SI

	MOV	SI,OFFSET CLINE		; command line.
	MOV	AL,DS:[SI]
	CMP	AL,'='
	JE	COLUM_ESE_1CHR
	CMP	AL,'?'
	JE	COLUM_ESE_1CHR
	JMP	COLUM_ESE9

COLUM_ESE_1CHR:
	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,OFFSET CLINE		; command line.
	ADD	DI,STRING_LEN-2		; string buffer length - 2
	MOV	SI,DI			;
	DEC	SI			;
	MOV	CX,STRING_LEN-3		;
	CLI				;
	STD				; dec pointer.
	REP	MOVSB			;
	CLD				; inc pointer.
	STI				;
	INC	SI
	MOV	BYTE PTR DS:[SI],CHR_SPACE
	DEC	SI
	CALL	PRINT
COLUM_ESE9:
	POP	SI
	RET
COLUM_ESE	ENDP


;	control code -> space.
;	-I- DS:SI : string address.

CNTL_SPACE	PROC	NEAR
	PUSH	SI
CNTL_SPACE1:
	MOV	AL,BYTE PTR DS:[SI]	; 1 char get.
	CMP	AL,EOS
	JE	CNTL_SPACE_EXIT

	CMP	AL,CHR_SPACE
	JNB	CNTL_SPACE2
	MOV	BYTE PTR DS:[SI],CHR_SPACE	; cntl -> space.
CNTL_SPACE2:
	INC	SI
	JMP	CNTL_SPACE1

CNTL_SPACE_EXIT:
	POP	SI
	RET
CNTL_SPACE	ENDP


;	string copy.( max : STRING_LEN )
;	-I- DS:SI : source index.
;	    DS:DI : dest index.

STRING_COPY	PROC	NEAR
	PUSH	SI
	PUSH	DI

	MOV	AX,DS
	MOV	ES,AX
	MOV	CX,0
STRING_COPY2:
	INC	CX
	CMP	CX,STRING_LEN	; string buffer length.
	JGE	STRING_COPY9
	LODSB
	CMP	AL,EOS
	JE	STRING_COPY9
	STOSB
	JMP	STRING_COPY2
STRING_COPY9:
	MOV	BYTE PTR ES:[DI],EOS	; end of string.
	POP	DI
	POP	SI
	RET
STRING_COPY	ENDP


;	token comp.
;	-I- DS:SI : token 1.
;	    DS:DI : token 2.
;	-O- AX    : 1=same, 0=not equl.

TOKEN_COMP	PROC	NEAR
	PUSH	SI
	PUSH	DI
TOKEN_COMP2:
	MOV	AL,DS:[SI]
	CMP	AL,EOS
	JE	TOKEN_COMP4
	CMP	AL,CHR_SPACE
	JE	TOKEN_COMP4

	CMP	AL,DS:[DI]
	JNE	TOKEN_COMP_NOT
	INC	SI
	INC	DI
	JMP	TOKEN_COMP2

TOKEN_COMP4:
	MOV	AL,DS:[DI]
	CMP	AL,EOS
	JE	TOKEN_COMP_OK
	CMP	AL,CHR_SPACE
	JE	TOKEN_COMP_OK

TOKEN_COMP_NOT:
	MOV	AX,0	; not equl.
	JMP	TOKEN_COMP9
TOKEN_COMP_OK:
	MOV	AX,1	; same.
TOKEN_COMP9:
	POP	DI
	POP	SI
	RET
TOKEN_COMP	ENDP


;	command line clear.
;	-I/O- CLINE : command line.

CLR_CLINE 	PROC	NEAR
	MOV	AX,DS
	MOV	ES,AX
	MOV	AL,0
	MOV	DI,OFFSET CLINE		; command line.
	MOV	CX,STRING_LEN		; command line length.
	REP	STOSB
	RET
CLR_CLINE 	ENDP


;	help.

HELPDSP	PROC	NEAR
	MOV	BX,0
	MOV	CX,COMMAND_MAX
	MOV	NUM,0
HELPDSP2:
	MOV	SI,DS:COMMAND_TABLE[BX]
	CALL	PRINT
	MOV	SI,OFFSET MES_CRLF
	CALL	PRINT
	INC	BX
	INC	BX
	INC	NUM
	CMP	NUM,20
	JL	HELPDSP6
	MOV	SI,OFFSET MES_WAIT
	CALL	PRINT
	CALL	INPUT
	CALL	LFPRN			; line feed.
	MOV	NUM,0
HELPDSP6:
	LOOP	HELPDSP2

	RET
HELPDSP	ENDP


;	autoexec

AUTOEXEC	PROC	NEAR
	MOV	CLINE[0],'P'			; コマンドライン
	MOV	CLINE[1],'M'			; コマンドライン
	MOV	CLINE[2],'2'			; コマンドライン
	MOV	CLINE[3],0			; コマンドライン
	CALL	CPROCESS			; process.
	RET
;*;	MOV	CLINE[0],'P'			; コマンドライン
;*;	MOV	CLINE[1],'M'			; コマンドライン
;*;	MOV	CLINE[2],'D'			; コマンドライン
;*;	MOV	CLINE[3],0			; コマンドライン
;*;	CALL	CPROCESS			; process.
;*;
;*;	MOV	CLINE[0],'A'			; コマンドライン
;*;	MOV	CLINE[1],'U'			; コマンドライン
;*;	MOV	CLINE[2],'T'			; コマンドライン
;*;	MOV	CLINE[3],'O'			; コマンドライン
;*;	MOV	CLINE[4],'E'			; コマンドライン
;*;	MOV	CLINE[5],'X'			; コマンドライン
;*;	MOV	CLINE[6],'E'			; コマンドライン
;*;	MOV	CLINE[7],'C'			; コマンドライン
;*;	MOV	CLINE[8],0			; コマンドライン
;*;	CALL	CPROCESS			; process.
;*;	RET
AUTOEXEC	ENDP



;	unit name set.
;	-I- DX : 1=1MFD#0,2=1MFD#1,3=1MFD#2,4=1MFD#3
;	-O- MES_PROMPT : prompt meggage.
;	    AX : 0=正常, 2=ディスクエラー


SETUNIT	PROC	NEAR
	PUSH	SI
	PUSH	DX

	CALL	HEXSTR		; val DX to hex string.
	MOV	AL,BYTE PTR DS:[SI][3]
	MOV	BYTE PTR MES_PROMPT[1],AL

	DEC	DX		;
	CALL	I21HDRV		; デフォルトドライブ番号
	MOV	AX,DX		; １ＭＦＤドライブ番号
	CALL	FFDRV		; カレントドライブ設定

	POP	DX
	POP	SI
	RET
SETUNIT	ENDP


;	address string -> ES:DI
;	-I- DS:SI  : address string.     XXXXX
;	-O- ES     : segment address.
;	    DI     : offset address.

STRADRS	PROC	NEAR
	PUSH	SI

	MOV	HEXADRS,SI		; hex buffer address.

	CMP	BYTE PTR DS:[SI][4],'0'	;
	JL	STRADRS3

	MOV	AL,DS:[SI]		;
	MOV	HEXBUF,AL		;
	MOV	SI,OFFSET HEXBUF	;
	CALL	STRHEX			; offset=DX
	MOV	ES,DX			; segment=ES

	MOV	SI,HEXADRS		; hex buffer address.
	ADD	SI,1			;
	CALL	STRHEX			; offset=DI
	MOV	DI,DX			;

	JMP	STRADRS4
STRADRS3:
	CALL	STRHEX			; offset=DX
	MOV	DI,DX			;
	MOV	AX,0			;
	MOV	ES,AX			; segment=0
STRADRS4:
	POP	SI
	RET
STRADRS	ENDP


CODE	ENDS



DATA	SEGMENT	PUBLIC	'DATA'

CLINE 		DB	STRING_LEN DUP (0)	; （先頭１バイトは文字列長さ）
CLINE_END	DB	EOS,EOS			;

TOKEN_CNT	DW	0			; token count.
CTOKEN		DW	TOKEN_MAX DUP (0)	; token address table.

		EVEN
COMMAND_NUM	DW	0			; command number.
COMMAND_MAX	DW	25			; command max.
COMMAND_TABLE	LABEL	WORD
	DW	OFFSET LL00
	DW	OFFSET LL01
	DW	OFFSET LL02
	DW	OFFSET LL03
	DW	OFFSET LL04
	DW	OFFSET LL05
	DW	OFFSET LL06
	DW	OFFSET LL07
	DW	OFFSET LL08
	DW	OFFSET LL09
	DW	OFFSET LL10
	DW	OFFSET LL11
	DW	OFFSET LL12
	DW	OFFSET LL13
	DW	OFFSET LL14
	DW	OFFSET LL15
	DW	OFFSET LL16
	DW	OFFSET LL17
	DW	OFFSET LL18
	DW	OFFSET LL19
	DW	OFFSET LL20
	DW	OFFSET LL21
	DW	OFFSET LL22
	DW	OFFSET LL23
	DW	OFFSET LL24
	DW	OFFSET LL25
	DW	OFFSET LL26
	DW	OFFSET LL27
	DW	OFFSET LL28
	DW	OFFSET LL29
	DW	OFFSET LL30

;		torkn, help message
LL00	DB	"DIR   ＤＩＲ"						,EOS
LL01	DB	"TYPE  <filename> テキストファイルの表示"		,EOS
LL02	DB	"CLS   クリア"						,EOS
LL03	DB	"IOCK  <i/o address> Ｉ／Ｏ変化チェック"		,EOS
LL04	DB	"CKEY  キー入力ＢＩＯＳチェック"			,EOS
LL05	DB	"DNO   <drive number> カレントドライブの変更（１－４）"	,EOS
LL06	DB	"=     <valie> １６進変換"				,EOS
LL07	DB	"CTMP  秘密変数の表示等"				,EOS
LL08	DB	"EXIT  シェルの終了"					,EOS
LL09	DB	"CEXE  <filename> 標準ＤＯＳのロードモジュールチェック"	,EOS
LL10	DB	"HELP  ＨＥＬＰ"					,EOS
LL11	DB	"LOAD  <filename> ＬＯＡＤ"				,EOS
LL12	DB	"FREE  フリーエリアの開始位置"				,EOS
LL13	DB	"CMEM  <address>  メモリーダンプ"			,EOS
LL14	DB	"PROC  標準ＤＯＳプロセス"				,EOS
LL15	DB	"CSNS  センスコマンドテスト  sense(command/status)"	,EOS
LL16	DB	"CSN2  旧センスコマンドテストsense(SENSE)"		,EOS
LL17	DB	"KILL  <filename> ＫＩＬＬ"				,EOS
LL18	DB	"FFIL  <filename> 真っ白のファイルを作る"		,EOS
LL19	DB	"FAT   ＦＡＴダンプ"					,EOS
LL20	DB	"COPY  <file1> <file2> ＣＯＰＹ"			,EOS
LL21	DB	"FORMAT  ディスクフォーマッティング"			,EOS
LL22	DB	"COM   標準ＣＯＭプロセス"				,EOS
LL23	DB	"CSN3  センスコマンドテストＷＡＩＴ付き"		,EOS
LL24	DB	"SSK   seek speed test."				,EOS
LL25	DB	"end."							,EOS
LL26	DB	EOS
LL27	DB	EOS
LL28	DB	EOS
LL29	DB	EOS
LL30	DB	EOS



MES_PROMPT	DB	"[ ]",EOS
MES_CRLF	DB	CHR_CR,CHR_LF,EOS
MES_WELCOME	DB	"ようこそピーシェルの世界へ",CHR_CR,CHR_LF
		DB	"大文字と小文字の区別があります。ＣＡＰＳロックを忘れないように・・",CHR_CR,CHR_LF,EOS
MES_BYE		DB	"さようなら・・・",CHR_CR,CHR_LF,EOS
MES_NOT_DIR	DB	"ディレクトリィがロード出来ない",CHR_CR,CHR_LF,EOS
MES_WAIT	DB	"　次ページ",EOS
MSG_FREE	DB	"フリーエリアの先頭=",EOS
MSG_SEGUNIT	DB	"0h",EOS
MSG_TYPE_ERROR	DB	"....?",CHR_CR,CHR_LF,EOS

		EVEN
HEXBUF		DB	"0000",0,0	; hex conv buffer.
HEXADRS		DW	0		; hex buffer address.

NONE		DW	0		; 1=none
EXIT		DW	0		; 1=exit?
NOT_FOUND	DW	0		; 1=not found.

NUM		DW	0		; 通し番号

DATA	ENDS

	END
;
;	end of "PSMAIN.ASM"
;
