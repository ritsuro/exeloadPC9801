; "SSFORM.ASM" PC-9801UV11 make by R.H 1990/10/02
;
;	E X E L O A D    D I R   c o m m a n d .
;
;
;
; command.


;	２ＨＤディスクフォーマット

INCLUDE	TSTSET.INC

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA


PUBLIC	CMFORM			; ディスクフォーマッティング

EXTRN	DKFORM:NEAR		; ディスクのフォーマット
EXTRN	DKFDNO:NEAR		; フォーマットのドライブ番号の設定（０ー３）

;	ディスクフォーマッティング

CMFORM	PROC	NEAR

CMFORM_RETRY:
	INP	"フォーマットするディスクのドライブ番号は ['Q':exit]:"
	CALL	STRDEC			; string -> i*2value.
	MOV	AX,DX			;
	DEC	AX			; 0 <- 1 , 1 <- 2 ....
	CMP	AX,4			;
	JL	CMFORM_START		;	
	PRF	"ドライブ番号は１から４まで"
	JMP	CMFORM_RETRY		;

CMFORM_START:				;	
	MOV	AX,DX			; １ＭＦＤドライブ番号（０ー３）
	DEC	AX			; 0 <- 1 , 1 <- 2 ....
	CALL	DKFDNO			; フォーマットのドライブ番号の設定
	PR	"ドライブ "
	CALL	DECSTR			; i*2value -> string.
	CALL	PRINT			; print.
	INP	" のフォーマットを開始します ['Q':exit]:"
	CALL	DKFORM			; ディスクのフォーマット
	CMP	AX,2			; 2=ディスクエラー
	JE	CMFORM_DISK_ERROR	;
	CMP	AX,3			; 3=デバイスがノットレディ
	JE	CMFORM_NOT_READY	;
	CMP	AX,4			; 4=ライトプロテクト
	JE	CMFORM_W_PROTECT	;
CMFORM_COMPLETE:
	PRF	"フォーマットが終了しました"
	RET
CMFORM_DISK_ERROR:
	PRF	"このディスクは壊れています"
	RET
CMFORM_NOT_READY:
	PRF	"ディスクがセットされていません"
	RET
CMFORM_W_PROTECT:
	PRF	"このディスクにはライトプロテクトがついています"
	RET
CMFORM	ENDP

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'
DATA	ENDS

	END
;
;	end of "SSFORM.ASM"
;
