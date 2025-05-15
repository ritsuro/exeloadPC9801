; "SSFILE.ASM" PC-9801UV11 make by R.H 1990/09/28
;
;	E X E L O A D    f i l e   t o o l   c o m m a n d .
;
;
;
; command.


;	ＫＩＬＬ	ファイル削除コマンド
;	ＦＦＩＬ	真っ白のファイルを作る
;	ＣＯＰＹ	ファイルのコピー


INCLUDE	TSTSET.INC

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	CMKILL			; ＫＩＬＬ
PUBLIC	CMFFIL			; 真っ白のファイルを作る
PUBLIC	CMCOPY			; ＣＯＰＹ


EXTRN	FFOPEN:NEAR		; ファイルオープン
EXTRN	FFCLOS:NEAR		; ファイルクローズ
EXTRN	FFREAD:NEAR		; ファイルの読み出し

EXTRN	FWOPEN:NEAR		; ファイルの書き込み開始
EXTRN	FWCLOS:NEAR		; ファイルの書き込み終了
EXTRN	FWRITE:NEAR		; ファイルの書き込み

EXTRN	FWKILL:NEAR		; ファイルの削除

BUFF_LEN	EQU	16;256	; string buffer length.


;	ＫＩＬＬ
;	-I- DS:SI : ファイル名
;	-O- AX    : 0=正常, 1=該当ファイル無し, 2=ディスクエラー

CMKILL	PROC	NEAR
	CALL	FWKILL			; ファイルの削除
	CMP	AX,1			; 1=該当ファイルがない
	JMPEQ	CMKILL_FILE_NOT_FOUND	;
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	CMKILL_ERROR		;

	CALL	PRINT			; print.
	PRF	"を削除しました"
CMKILL_EXIT:
	MOV	AX,0			; 0=正常
	RET				;
CMKILL_FILE_NOT_FOUND:
	PRF	"ファイルが見つかりません"
	MOV	AX,1			; 1=該当ファイル無し
	RET				;
CMKILL_ERROR:
	PRF	"ディスクがセットされていません"
	MOV	AX,2			; 2=ディスクエラー
	RET				;
CMKILL	ENDP


;	真っ白のファイルを作成する
;	-I- DS:SI : ファイル名
;	    CX    : 書き込みデータのバイト数
;	-O- AX    : 0=正常, 1=ディレクトリに空きがない, 2=ディスクエラー
;	          : 3=ディスクに空き無し

CMFFIL	PROC	NEAR
	MOV	WRTCOUNT,CX		; 書き込みデータのバイト数

	CALL	FWOPEN			; ファイルの書き込み開始
	CMP	AX,1			; 1=ディレクトリに空きがない
	JMPEQ	CMFFIL_EMPTY		;
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	CMFFIL_ERROR		;

	MOV	CX,WRTCOUNT		; 書き込みデータのバイト数
CMFFIL_LOOP:				;
	PUSH	CX			;
	MOV	DX,DS			;
	MOV	SI,OFFSET FILDATA	; 空白を埋めるデータ
	MOV	CX,1			; 書き込みデータのバイト数
	CALL	FWRITE			; ファイルの書き込み
	POP	CX			;

	CMP	AX,1			; 1=ディスクに空き無し
	JMPEQ	CMFFIL_NONE_FRE		;
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	CMFFIL_ERROR		;

	LOOP	CMFFIL_LOOP		;


	CALL	FWCLOS			; ファイルの書き込み終了
	CMP	AX,1			; 1=ディレクトリに空きがない
	JMPEQ	CMFFIL_EMPTY		;
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	CMFFIL_ERROR		;


	CALL	PRINT			; print.
	PRF	"を作成しました"
CMFFIL_EXIT:
	MOV	AX,0			; 0=正常
	RET				;
CMFFIL_EMPTY:
	PRF	"ディレクトリに空きがありません"
	MOV	AX,1			; 1=ディレクトリに空きがない
	RET				;
CMFFIL_ERROR:
	PRF	"ディスクエラー"
	MOV	AX,2			; 2=ディスクエラー
	RET				;
CMFFIL_NONE_FRE:
	PRF	"ディスクに空きがありません"
	MOV	AX,3			; 3=ディスクに空き無し
	RET				;
CMFFIL	ENDP


;	ＣＯＰＹ
;	-I- DS:SI : コピー元ファイル名
;	    DS:BX : コピー先ファイル名
;	-O- AX    : 0=正常, 1=ディレクトリに空きがない, 2=ディスクエラー
;	          : 3=ディスクに空き無し, 4=該当ファイルがない

CMCOPY	PROC	NEAR
	MOV	FL1_ADRS,SI		; ファイル名１
	MOV	FL2_ADRS,BX		; ファイル名２


	MOV	SI,FL1_ADRS		; ファイル名１
	CALL	PRINT			;
	PR	" を "
	MOV	SI,FL2_ADRS		; ファイル名２
	CALL	PRINT			;
	PRF	" へコピーします。"


	MOV	SI,FL1_ADRS		; ファイル名１
	CALL	FFOPEN			; ファイルオープン
	CMP	AX,1			; 該当ファイルがない
	JMPEQ	CMCOPY_NOT_FOUND	;
	CMP	AX,2			; ディスクエラー
	JMPEQ	CMCOPY_ERROR		;

	MOV	SI,FL2_ADRS		; ファイル名２
	CALL	FWOPEN			; ファイルの書き込み開始
	CMP	AX,1			; 1=ディレクトリに空きがない
	JMPEQ	CMCOPY_EMPTY		;
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	CMCOPY_ERROR		;


CMCOPY_LOOP:				;
	MOV	AX,DS			;
	MOV	ES,AX			;
	MOV	DI,OFFSET STRING_BUFF	; string buffer.
	MOV	CX,BUFF_LEN		; string buffer length.
	CALL	FFREAD			; ファイルの読み出し
	CMP	AX,1			; Ｅ．Ｏ．Ｆ
	JMPEQ	CMCOPY_LOOP_END		;
	CMP	AX,2			; ディスクエラー
	JMPEQ	CMCOPY_ERROR		;

	MOV	READ_LENGTH,DX		; 読み込み出来たバイト数

	MOV	DX,DS			;
	MOV	SI,OFFSET STRING_BUFF	; string buffer.
	MOV	CX,READ_LENGTH		; 読み込み出来たバイト数
	CALL	FWRITE			; ファイルの書き込み
	CMP	AX,1			; 1=ディスクに空き無し
	JMPEQ	CMCOPY_NONE_FRE		;
	CMP	AX,2			; ディスクエラー
	JMPEQ	CMCOPY_ERROR		;

	JMP	CMCOPY_LOOP		;
CMCOPY_LOOP_END:			;

	CALL	FFCLOS			; ファイルクローズ

	CALL	FWCLOS			; ファイルの書き込み終了
	CMP	AX,1			; 1=ディスクに空き無し
	JMPEQ	CMCOPY_NONE_FRE		;
	CMP	AX,2			; 2=ディスクエラー
	JMPEQ	CMCOPY_ERROR		;

	MOV	SI,FL2_ADRS		; ファイル名２
	CALL	PRINT			; print.
	PRF	"を作成しました"
CMCOPY_EXIT:
	MOV	AX,0			; 0=正常
	RET				;
CMCOPY_EMPTY:
	PRF	"ディレクトリに空きがありません"
	MOV	AX,1			; 1=ディレクトリに空きがない
	RET				;
CMCOPY_ERROR:
	PRF	"ディスクエラー"
	MOV	AX,2			; 2=ディスクエラー
	RET				;
CMCOPY_NONE_FRE:
	CALL	FWCLOS			; ファイルの書き込み終了
	PRF	"ディスクに空きがありません"
	MOV	AX,3			; 3=ディスクに空き無し
	RET				;
CMCOPY_NOT_FOUND:
	PRF	"ファイルが見つかりません"
	MOV	AX,4			; 4=該当ファイルがない
	RET				;
CMCOPY	ENDP



CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

WRTCOUNT	DW	0		; 書き込みデータのバイト数
FILDATA		DB	" ",0		; 空白を埋めるデータ

READ_LENGTH	DW	0		; 読み込み出来たバイト数

STRING_BUFF	DB	BUFF_LEN DUP (0)	; string buffer.

FL1_ADRS	DW	0		; ファイル名１
FL2_ADRS	DW	0		; ファイル名２

DATA	ENDS

	END
;
;	end of "SSFILE.ASM"
;
