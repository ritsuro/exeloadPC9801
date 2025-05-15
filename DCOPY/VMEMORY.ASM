; "VMEMORY.ASM" PC98series make by R.H 1993/06/30
;
;
;	vram memory handle.
;
;
; public subroutine.

INCLUDE	TSTSET.INC

DEBUG_FLAG_1	EQU	0		; debug flag no.1

PC98VRAM_SEG_G0	EQU	0A800H		; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇO
PC98VRAM_SEG_G1	EQU	0B000H		; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇP
PC98VRAM_SEG_G2	EQU	0B800H		; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇQ
PC98VRAM_SEG_G3	EQU	0E000H		; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇR

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	VMEMOPN			; vram memory open.
PUBLIC	VMEMCLS			; vram memory close.
PUBLIC	VMEMSEK			; vram memory seek.

EXTRN	VRMGRPMDE:NEAR		; vram graphic mode.
EXTRN	VRMRETMDE:NEAR		; vram graphic mode ret.
EXTRN	VRMSTOP:NEAR		; vram graphic stop.
EXTRN	VRMCLR:NEAR		; ÇuÇqÇ`ÇlÉNÉäÉA
EXTRN	VRM98DP:NEAR		; PC98 vram show bank.
EXTRN	VRM98WT:NEAR		; PC98 vram write bank.
EXTRN	VRM98NOW:NEAR		; PC98 vram bank now.


;	vram memory open.
;	-O- BX : free page counter.

VMEMOPN	PROC	NEAR
	CMP	FLAG_DISABLE_VRAM,0	; flag disable vram.
	JNE	VMEMOPN_EXIT

	CALL	VRMGRPMDE		; vram graphic mode.

	CALL	VRMSTOP			; vram graphic stop.

	MOV	AX,0			; 0=VRAM0 show, 1=VRAM1 show.
	CALL	VRM98DP			; PC98 vram show bank.

	MOV	AX,0			; 0=VRAM0 write,1=VRAM1 write.
	CALL	VRM98WT			; PC98 vram write bank.

	CALL	VRMCLR			; ÇuÇqÇ`ÇlÉNÉäÉA

	CALL	VRAM_MEM_CHK		; vram memory check.

IF DEBUG_FLAG_1	; debug flag no.1
	MOV	BX,0
	MOV	CX,PAGE_MAX_VRAMMEM
VMEMOPN_5:
	PRVH	"TBL_VRAM_SEG[*]=",TBL_VRAM_SEG[BX]
	INC	BX
	INC	BX
	LOOP	VMEMOPN_5
	INP	"WAIT"
ENDIF

VMEMOPN_EXIT:
	MOV	BX,PAGE_MAX_VRAMMEM	; page max vram memory.
	RET
VMEMOPN	ENDP


;	vram memory check.

VRAM_MEM_CHK	PROC	NEAR
	MOV	PAGE_MAX_VRAMMEM,0	; page max vram memory.

	MOV	BANK_NUM,0		; 0=VRAM0 write,1=VRAM1 write.
	MOV	CX,2			;
VRAM_MEM_CHK_LOOP_A:			;
	PUSH	CX			;
	MOV	AX,BANK_NUM		; 0=VRAM0 write,1=VRAM1 write.
	CALL	VRM98WT			; PC98 vram write bank.

	MOV	BX,0			;
	MOV	CX,MAX_VRAM_BANK_SEG	; max vram bank segment.
VRAM_MEM_CHK_LOOP:			;
	PUSH	CX			;
	PUSH	BX			;

	MOV	ES,TBL_VRAM_BANK_SEG[BX] ; vram bank segment.
	CALL	VRAM_AREA_CHK		; vram area check.
	CMP	AX,0			; 0=normal,1=none.
	JNE	VRAM_MEM_CHK_NEXT	;

	MOV	BX,PAGE_MAX_VRAMMEM	; page max vram memory.
	SHL	BX,1			; word pointer.
	MOV	TBL_VRAM_SEG[BX],ES	; vram segment table.
	MOVX	TBL_VRAM_BANK[BX],BANK_NUM	; 0=VRAM0 write,1=VRAM1 write.

	INC	PAGE_MAX_VRAMMEM	; page max vram memory.
VRAM_MEM_CHK_NEXT:			;
	POP	BX			;
	INC	BX			;
	INC	BX			;
	POP	CX			;
	LOOP	VRAM_MEM_CHK_LOOP	;
	INC	BANK_NUM		; 0=VRAM0 write,1=VRAM1 write.
	POP	CX			;
	LOOP	VRAM_MEM_CHK_LOOP_A	;

	RET
VRAM_MEM_CHK	ENDP


;	vram area check.
;	-I- ES : vram segment.
;	-O- AX : 0=normal,1=none.

VRAM_AREA_CHK	PROC	NEAR
	MOV	DI,0
	MOV	AL,ES:[DI]
	MOV	BYTE PTR ES:[DI],0FFH
	CMP	BYTE PTR ES:[DI],0FFH
	JNE	VRAM_AREA_CHK_NONE
	MOV	BYTE PTR ES:[DI],0
	CMP	BYTE PTR ES:[DI],0
	JNE	VRAM_AREA_CHK_NONE
	MOV	ES:[DI],AL

	MOV	DI,3FFFH
	MOV	AL,ES:[DI]
	MOV	BYTE PTR ES:[DI],0FFH
	CMP	BYTE PTR ES:[DI],0FFH
	JNE	VRAM_AREA_CHK_NONE
	MOV	BYTE PTR ES:[DI],0
	CMP	BYTE PTR ES:[DI],0
	JNE	VRAM_AREA_CHK_NONE
	MOV	ES:[DI],AL

	MOV	AX,0			; 0=normal.
	RET
VRAM_AREA_CHK_NONE:
	MOV	ES:[DI],AL
	MOV	AX,1			; 1=none.
	RET
VRAM_AREA_CHK	ENDP


;	vram memory close.

VMEMCLS	PROC	NEAR
	CMP	FLAG_DISABLE_VRAM,0	; flag disable vram.
	JNE	VMEMCLS_EXIT

	MOV	AX,0			; 0=VRAM0 write,1=VRAM1 write.
	CALL	VRM98WT			; PC98 vram write bank.

	MOV	AX,0			; 0=VRAM0 show, 1=VRAM1 show.
	CALL	VRM98DP			; PC98 vram show bank.

	CALL	VRMRETMDE		; vram graphic mode ret.
VMEMCLS_EXIT:
	RET
VMEMCLS	ENDP


;	vram memory seek.
;	(seek size 16kbyte.)
;	-I- BX : page number.
;	-O- ES : frame segment.
;	    AX : 0=normal,3=error

VMEMSEK	PROC	NEAR
	CMP	FLAG_DISABLE_VRAM,0	; flag disable vram.
	JNE	VMEMSEK_ERROR

	CMP	BX,PAGE_MAX_VRAMMEM		; page max vram memory.
	JNB	VMEMSEK_ERROR

	SHL	BX,1				; word pointer.
	MOV	ES,TBL_VRAM_SEG[BX]		; vram segment table.
	MOV	AX,TBL_VRAM_BANK[BX]		; vram bank table.
	PUSH	ES
	CALL	VRM98WT			; PC98 vram write bank.
	POP	ES
VMEMSEK_EXIT:
	MOV	AX,0			; 0=normal
	RET
VMEMSEK_ERROR:
	MOV	AX,3			; 3=error
	RET
VMEMSEK	ENDP


CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

PUBLIC	FLAG_DISABLE_VRAM			; flag disable vram.
FLAG_DISABLE_VRAM	DW	0		; flag disable vram.

PAGE_MAX_VRAMMEM	DW	0		; page max vram memory.

TBL_VRAM_SEG		DW	16 DUP (0)	; vram segment table.
TBL_VRAM_BANK		DW	16 DUP (0)	; vram bank table.

BANK_NUM		DW	0		; bank number.

MAX_VRAM_BANK_SEG	DW	8		; max vram bank segment.
TBL_VRAM_BANK_SEG	LABEL	WORD		; vram bank segment.
	DW	PC98VRAM_SEG_G0			; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇO
	DW	PC98VRAM_SEG_G0	+ 400H		; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇO
	DW	PC98VRAM_SEG_G1			; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇP
	DW	PC98VRAM_SEG_G1	+ 400H		; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇP
	DW	PC98VRAM_SEG_G2			; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇQ
	DW	PC98VRAM_SEG_G2	+ 400H		; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇQ
	DW	PC98VRAM_SEG_G3			; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇR
	DW	PC98VRAM_SEG_G3	+ 400H		; ÇuÇqÇ`ÇlÉvÉåÅ[ÉìÇR

DATA	ENDS

	END
;
;	end of "VMEMORY.ASM"
;
