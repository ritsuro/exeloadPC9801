; "LINKEND.ASM" PC9801UV11 make by R.H 1992/01/28
;
;
;	link end buffers area.
;
;
; public subroutine.

CLST_LENGTH	EQU	1024		; クラスタのバイト数
LEN_CLAST	EQU	1024		; クラスタバイト数
FAT_CLAST 	EQU	4		; ＦＡＴテーブルクラスタ数
;READWT.ASMもなおせ
;ＤＫＦＯＲＭ．ＡＳＭもなおせ
;ｌｉｎｋｅｎｄ．ＡＳＭもなおせ
;SSDIR.ASMのDIRMAXもなおせ
ROOT_CLAST 	EQU	1		; ＲＯＯＴＤＩＲクラスタ数
;;;;ROOT_CLAST	EQU	6		; ＲＯＯＴＤＩＲクラスタ数
STRING_LEN 	EQU	255		; string length.

DATA	SEGMENT	PUBLIC	'DATA'

PUBLIC	CLST_BUFF		; クラスタバッファ
PUBLIC	CLST_BUFF_W		; クラスタバッファ
PUBLIC	FAT1			; ＦＡＴテーブル
PUBLIC	ROOTDIR1		; ＲＯＯＴＤＩＲ
PUBLIC	FAT2			; ＦＡＴテーブル
PUBLIC	ROOTDIR2		; ＲＯＯＴＤＩＲ
PUBLIC	STRINGS			; string buffer.

CLST_BUFF	DB	CLST_LENGTH DUP (?)	; クラスタバッファ
CLST_BUFF_W	DB	CLST_LENGTH DUP (?)	; クラスタバッファ

FAT1		DB LEN_CLAST*FAT_CLAST DUP (?)		; ＦＡＴテーブル
ROOTDIR1	DB LEN_CLAST*ROOT_CLAST DUP (?)		; ＲＯＯＴＤＩＲ
		DB 2 DUP (?)
FAT2		DB LEN_CLAST*FAT_CLAST DUP (?)		; ＦＡＴテーブル
ROOTDIR2	DB LEN_CLAST*ROOT_CLAST DUP (?)		; ＲＯＯＴＤＩＲ
		DB 2 DUP (?)

STRINGS	DB	1 DUP (?)		; buffer length.
	DB	1 DUP (?)		; character length.
	DB	STRING_LEN DUP (?)	; string.

DATA	ENDS

	END
;
;	end of "LINKEND.ASM"
;
