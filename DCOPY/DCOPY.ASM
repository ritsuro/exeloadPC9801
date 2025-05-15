; "DCOPY.ASM" PC98series make by R.H 1993/06/28
;
;
;	DCOPY.EXE
;
;	2HD(1024byte,8sector)disk copy.
;
;	２ＨＤディスクコピー
;
;
; (C) 1993 ritsurou hashimoto.

CODE	SEGMENT	PUBLIC	'CODE'
CODE	ENDS
DATA	SEGMENT	PUBLIC	'DATA'
DATA	ENDS
EMMCOD	SEGMENT	PUBLIC	'EMMCOD'
EMMCOD	ENDS
EMMDAT	SEGMENT	PUBLIC	'EMMDAT'
EMMDAT	ENDS
STACK	SEGMENT	STACK
	DW	1000 DUP (?)
TOP_OF_STACK	LABEL	WORD	; stack pointer.
STACK	ENDS
SEGFREE	SEGMENT	PUBLIC	'SEGFREE'
SEGFREE	ENDS

INCLUDE	TSTSET.INC
INCLUDE	DCOPYDEF.INC
INCLUDE	TEXTVIEW.INC

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA,SS:STACK

EXTRN	GETARG:NEAR			; get argument.

EXTRN	DCOPY2HD:NEAR			; 2HD disk copy.
EXTRN	DCOPY2HDEMS:NEAR		; 2HD disk copy.(use EMS memory)
EXTRN	DCOPYDUP:NEAR			; 2HD disk copy.(multi copy)

EXTRN	DRVNOSET:NEAR			; 2HD disk copy dirve number set.
EXTRN	DRVNORED:NEAR			; 2HD disk copy dirve number read.

START:
	PUSH	DS			; save DS.

	MOV	AX,SEG DATA		; DS = DATA segment.
	MOV	DS,AX			;
	MOV	SEG_DOS2X_PSP,ES	; current PSP segment.(DOSver2.x)

	MOV	AX,SEG STACK		; stack segment.
	MOV	SS,AX			;
	MOV	SP,OFFSET TOP_OF_STACK	; stack pointer.

	CALL	MAIN			; main proc.

	MOV	AH,30H			; DOSversion get.
	INT	21H			;
	CMP	AL,0			; EXELOAD.SYS
	JE	EXELOAD_END		;

	POP	DS

	MOV	AH,4CH			; return to DOS.
	MOV	AL,0			;
	INT	21H			; end.
MUGEN:					;
	JMP	MUGEN			;

EXELOAD_END:
	CALL	TXVW_TXVIEWMODE		; set view text mode.
	TX_CLS				; frame inside clear screen.
	TX_PRINT 10,11,TC_WHITE ,"２ＨＤディスクコピーを終了します。"
MUGEN2:					;
	JMP	MUGEN2			;
	

; ****************************************************
;	メイン処理
; ****************************************************

MAIN	PROC	NEAR
	PRF	"DCOPY.EXE ver1.0 1993(C)R.Hashimoto"

	MOV	MODE_SW,'S'		; copy mode.'S'=standerd copy.

	CALL	GETARG			; get argument.
	CMP	CX,0			;
	JE	MAIN_NORMAL_COPY_START	;
	CMP	CX,1			;
	JNBE	MAIN_HELP		;

	MOV	BX,[SI]			; argument.
	MOV	AL,[BX]			; 'T'=simple copy,'S'=standerd copy.
	CMP	AL,'a'			;
	JB	MAIN_2			;
	SUB	AL,'a'-'A'		;
MAIN_2:					;
	MOV	MODE_SW,AL		; copy mode.
	CMP	AL,'T'			; 単純コピーモード"
	JE	MAIN_NORMAL_COPY_START	;
	CMP	AL,'S'			; 標準コピーモード"
	JE	MAIN_NORMAL_COPY_START	;
	CMP	AL,'R'			; 標準ｺﾋﾟｰﾓｰﾄﾞ(ｸﾞﾗﾌｨｯｸVRAMを使わない)
	JE	MAIN_NORMAL_COPY_START	;
	CMP	AL,'X'			; 複数コピーモード
	JE	MAIN_NORMAL_COPY_START	;
	JMP	MAIN_HELP		;

MAIN_NORMAL_COPY_START:

MAIN_NORMAL_COPY:
	CALL	TXVW_TXVIEWMODE		; set view text mode.

	MOV	AL,MODE_SW		; copy mode.
	CMP	AL,'X'			; 複数コピーモード
	JE	MAIN_NORMAL_SKIP	;

	CALL	MAIN_TITLE		; タイトル
	CMP	AX,3			; 0=normal,3=F3,11=ESC,12=ENTER
	JE	MAIN_ERROR_COPY_QUIT	;
	CMP	AX,11			;
	JE	MAIN_ERROR_COPY_QUIT	;

MAIN_NORMAL_SKIP:
	MOV	AL,MODE_SW		; copy mode.
	CMP	AL,'T'			; 単純コピーモード
	JE	MAIN_NORMAL_SIM_MODE	;
	CMP	AL,'S'			; 標準コピーモード
	JE	MAIN_NORMAL_STD_MODE	;
	CMP	AL,'R'			; 標準ｺﾋﾟｰﾓｰﾄﾞ(ｸﾞﾗﾌｨｯｸVRAMを使わない)
	JE	MAIN_NORMAL_STD_MODE_NV	;
	CMP	AL,'X'			; 複数コピーモード
	JE	MAIN_NORMAL_DUP_MODE	;

	JMP	MAIN_ERROR_COPY_QUIT	;

MAIN_NORMAL_SIM_MODE:
	CALL	DCOPY2HD		; 2HD disk copy.
	CMP	AX,1			; 0=通常,1=中止,2=メモリ不足
	JE	MAIN_ERROR_COPY_BRAKE	;
	CMP	AX,2			;
	JE	MAIN_ERROR_COPY_MEMORY	;
	JMP	MAIN_NORMAL_COMPLETE	;

MAIN_NORMAL_STD_MODE_NV:
	MOV	FLAG_DISABLE_VRAM,1	; flag disable vram.
MAIN_NORMAL_STD_MODE:
	CALL	DCOPY2HDEMS		; 2HD disk copy.(use EMS memory)
	CMP	AX,1			; 0=通常,1=中止,2=メモリ不足
	JE	MAIN_ERROR_COPY_BRAKE	;
	CMP	AX,2			;
	JE	MAIN_ERROR_COPY_MEMORY	;
	JMP	MAIN_NORMAL_COMPLETE	;

MAIN_NORMAL_DUP_MODE:
	CALL	DCOPYDUP		; 2HD disk copy.(multi copy)
	CMP	AX,1			; 0=通常,1=中止,2=メモリ不足
	JE	MAIN_ERROR_COPY_BRAKE	;
	CMP	AX,2			;
	JE	MAIN_ERROR_COPY_MEMORY	;
	JMP	MAIN_NORMAL_COMPLETE	;


MAIN_NORMAL_COMPLETE:
	CALL	TXVW_RETDOSMODE		; return to DOS text mode.
	PRF	"ディスクコピーを終了します。"
	RET
MAIN_ERROR_COPY_QUIT:
	CALL	TXVW_RETDOSMODE		; return to DOS text mode.
	PRF	"終了します。"
	RET
MAIN_ERROR_COPY_BRAKE:
	CALL	TXVW_RETDOSMODE		; return to DOS text mode.
	PRF	"ディスクコピーを中止します。"
	RET
MAIN_ERROR_COPY_MEMORY:
	CALL	TXVW_RETDOSMODE		; return to DOS text mode.
	PRF	"メインメモリーが足りません。"
	RET
MAIN_HELP:
	CALL	MAINHELP		; ＨＥＬＰ
	RET
MAIN	ENDP

; ****************************************************
;	ＨＥＬＰ
; ****************************************************

MAINHELP	PROC	NEAR
	PRF	"２ＨＤディスクコピー"
	LF
	PRF	"DCOPY <オプション>"
	LF
	PRF	"  <オプション>"
	PRF	"  S  標準コピーモード(通常はこれを使います)"
	PRF	"  R  標準コピーモード(グラフィックVRAMを使わない)"
	PRF	"  T  単純コピーモード(標準コピーモードが使えないとき)"
	RET
MAINHELP	ENDP


; ****************************************************
;	タイトル
;	-O- AX : 3=F3,11=ESC,12=ENTER
; ****************************************************

MAIN_TITLE	PROC	NEAR
	TX_CLS				; clear screen.
	TX_FRAME			; frame.

TX_PRINT 8,5,TC_WHITE,"２ＨＤディスクコピーは９８シリーズの２ＨＤフロッピー"
TX_PRINT 8,6,TC_WHITE,"ディスクの複製ディスクを作るためのコピーツールです。"
TX_PRINT 8,8,TC_WHITE,"複製用のディスクは元のディスクと同数の２ＨＤフロッピーディスクを"
TX_PRINT 8,9,TC_WHITE,"用意してください。"

TX_PRINT 8,18,TC_WHITE,"次へ進むときは、リターンキーを押してください。"

TX_PRINT 8,20,TC_WHITE,"なにもしないで終了するときは、f.3 を押してください。"

	TX_UWAIT			; user wait.
	RET
MAIN_TITLE	ENDP

CODE	ENDS

DATA	SEGMENT	PUBLIC	'DATA'

PUBLIC	SEG_DOS2X_PSP			; current PSP segment.(DOSver2.x)
SEG_DOS2X_PSP	DW	0		; current PSP segment.(DOSver2.x)

EXTRN	FLAG_DISABLE_VRAM:WORD		; flag disable vram.

MODE_SW		DB	0,0		; copy mode.
					; 'T'=simple copy,'S'=standerd copy.

DATA	ENDS


;;CNT_ARGS	DW	0		; argument count.
;;STR_OPTION	DW	0		; cmdline option.
;;STR_SOUR_DRV_NUM	DW	0	; cmdline source drive number.
;;STR_DEST_DRV_NUM	DW	0	; cmdline destination drive number.
;;
;;	CALL	GETARG			; get argument.
;;	CMP	CX,0
;;	JE	MAIN_NORMAL_COPY
;;	CMP	CX,2
;;	JB	MAIN_HELP
;;
;;	MOV	AX,SEG_MAIN_MEM		; segment use main memory.
;;	CMP	AX,SEG SEGFREE
;;	JBE	MAIN_ERROR_MEMORY
;;
;;	MOV	CNT_ARGS,CX		; argument count.
;;	MOVX	STR_SOUR_DRV_NUM,[SI]	 ; cmdline source drive number.
;;	MOVX	STR_DEST_DRV_NUM,[SI][2] ; cmdline destination drive number.
;;	MOVX	STR_OPTION,[SI][4]	 ; cmdline option.
;;
;;	MOV	SI,STR_SOUR_DRV_NUM	; cmdline source drive number.
;;	CALL	STRDEC			;
;;	MOV	AX,DX			; read disk drive.
;;	DEC	AX
;;
;;	MOV	SI,STR_DEST_DRV_NUM	; cmdline destination drive number.
;;	CALL	STRDEC			;
;;	MOV	BX,DX			; write disk drive.
;;	DEC	BX
;;
;;	CMP	AX,3
;;	JNBE	MAIN_ERROR_DRIVE_NUMBER
;;	CMP	BX,3
;;	JNBE	MAIN_ERROR_DRIVE_NUMBER
;;
;;	CALL	DRVNOSET		; 2HD disk copy dirve number set.
;;
;;	PRVH	"SEG FREE:",<SEG SEGFREE>
;;
;;	PR	"ディスクドライブ "
;;	CALL	DRVNORED		; 2HD disk copy dirve number read.
;;	MOV	BX,AX
;;	SHL	BX,1
;;	MOV	SI,STR_DRV_NUM[BX]	; drive name.
;;	CALL	PRINT
;;	PR	" から "
;;	CALL	DRVNORED		; 2HD disk copy dirve number read.
;;	SHL	BX,1
;;	MOV	SI,STR_DRV_NUM[BX]	; drive name.
;;	CALL	PRINT
;;	PRF	" へディスクコピーします。"
;;
;;	CMP	CNT_ARGS,2		; argument count.
;;	JE	MAIN_NORMAL_COPY	;
;;
;;MAIN_ERROR_DRIVE_NUMBER:
;;	PRF	"ドライブ番号は１から４までです"
;;	RET


	END	START
;
;	end of "DCOPY.ASM"
;
