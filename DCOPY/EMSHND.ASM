; "EMSHND.ASM" PC-9801UV11 make by R.H 1991/01/02
;
;	EMS handle.
;
; public subroutine.

INCLUDE	TSTSET.INC

;	EMMCOD -> CODE

CODE_IN		MACRO
	LOCAL	L1
	JMP	FAR PTR L1
CODE	SEGMENT	PUBLIC	'CODE'
	ASSUME	CS:CODE
L1:
	ENDM

;	CODE -> EMMCOD

CODE_OUT	MACRO
	LOCAL	L1
	JMP	FAR PTR L1
CODE	ENDS
	ASSUME	CS:EMMCOD
L1:
	ENDM


EMMCOD	SEGMENT	PUBLIC	'EMMCOD'

	ASSUME	CS:EMMCOD,DS:EMMDAT

;	FAR call.

PUBLIC	EMSCHK		; EMS check.
PUBLIC	EMSOPN		; EMS open.
PUBLIC	EMSOPN2		; EMS open.(bank count set)
PUBLIC	EMSCLS		; EMS close.
PUBLIC	EMSSEK		; EMS seek.
PUBLIC	EMS64K		; EMS seek 64k frame.


EXTRN	EMMCHK:NEAR			; EMM check.
EXTRN	EMM_G_S:NEAR			; EMM Get Status.
EXTRN	EMM_G_P_FA:NEAR			; EMM Get Page Frame Address.
EXTRN	EMM_G_U_PC:NEAR			; EMM Get Unallocated Page Count.
EXTRN	EMM_A_P:NEAR			; EMM Allocate Pages.
EXTRN	EMM_A_P2:NEAR			; EMM Allocate Pages.(bank count set)
EXTRN	EMM_MU_H_P:NEAR			; EMM Map/Unmap Handle Pages.
EXTRN	EMM_D_P:NEAR			; EMM Deallocate Pages.


;	EMS check.
;	-O- AX : 0=normal,1=EMS none,2=memory full,3=error
;	    BX : free page counter.
;	    DX : EMM page frame segment.

EMSCHK	PROC	FAR
	PUSH	DS
	MOV	AX,SEG EMMDAT
	MOV	DS,AX

	MOV	EMS_ON_FLAG,0		; EMS flag(1=on,0=off)

	CALL	EMMCHK			; EMM check.
	CMP	AX,0			; 0=none,1=EMMset
	JE	EMSCHK_NONE		;

	CALL	EMM_G_S			; EMM Get Status.
	CMP	AX,0			; EMM status (0=normal,0<>error)
	JNE	EMSCHK_ERROR		;

	CALL	EMM_G_P_FA		; EMM Get Page Frame Address.
	MOV	EMM_PAGE_FREAM_SEG,BX	; EMM page frame segment.
	CMP	AX,0			; EMM status (0=normal,0<>error)
	JNE	EMSCHK_ERROR		;

	CALL	EMM_G_U_PC		; EMM Get Unallocated Page Count.
	CMP	AX,0			; EMM status (0=normal,0<>error)
	JNE	EMSCHK_ERROR		;
	CMP	BX,0			; EMM unallocated page count.
	JE	EMSCHK_MEMORY_FULL	;

EMSCHK_NORMAL:
	MOV	DX,EMM_PAGE_FREAM_SEG	; EMM page frame segment.
	MOV	AX,0			; 0=normal.
	POP	DS
	RET
EMSCHK_NONE:
	MOV	BX,0			;
	MOV	DX,0			;
	MOV	AX,1			; 1=EMS none.
	POP	DS
	RET
EMSCHK_MEMORY_FULL:
	MOV	BX,0			;
	MOV	DX,0			;
	MOV	AX,2			; 2=memory full.
	POP	DS
	RET
EMSCHK_ERROR:
	MOV	BX,0			;
	MOV	DX,0			;
	MOV	AX,3			; 3=error.
	POP	DS
	RET
EMSCHK	ENDP


;	EMS open.
;	-O- AX : 0=normal,1=EMS none,2=memory full,3=error

EMSOPN	PROC	FAR
	PUSH	DS
	MOV	AX,SEG EMMDAT
	MOV	DS,AX

	MOV	EMS_ON_FLAG,0		; EMS flag(1=on,0=off)

	CALL	EMSCHK			; EMS check.
	CMP	AX,0			; 0=normal
	JNE	EMSOPN_EXIT		;

	CALL	EMM_A_P			; EMM Allocate Pages.
	CMP	AX,0			; EMM status (0=normal,0<>error)
	JNE	EMSOPN_ERROR		;

	MOV	EMS_ON_FLAG,1		; EMS flag(1=on,0=off)
EMSOPN_NORMAL:
	MOV	AX,0			; 0=normal.
	POP	DS
	RET
EMSOPN_ERROR:
	MOV	AX,3			; 3=error.
	POP	DS
	RET
EMSOPN_EXIT:
	POP	DS
	RET
EMSOPN	ENDP


;	EMS open.(bank count set)
;	-I- BX : use page count.
;	-O- AX : 0=normal,1=EMS none,2=memory full,3=error
;	    BX : allocate page counter.

EMSOPN2	PROC	FAR
	PUSH	DS
	MOV	AX,SEG EMMDAT
	MOV	DS,AX

	MOV	USER_PAGE_COUNT,BX	; user page count.

	MOV	EMS_ON_FLAG,0		; EMS flag(1=on,0=off)

	CALL	EMSCHK			; EMS check.
	CMP	AX,0			; 0=normal
	JNE	EMSOPN2_EXIT		;

	MOV	BX,USER_PAGE_COUNT	; user page count.
	CALL	EMM_A_P2		; EMM Allocate Pages.(bank count set)
	MOV	USER_PAGE_COUNT,BX	; user page count.

	CMP	AX,0			; EMM status (0=normal,0<>error)
	JNE	EMSOPN2_ERROR		;

	MOV	EMS_ON_FLAG,1		; EMS flag(1=on,0=off)
EMSOPN2_NORMAL:
	MOV	AX,0			; 0=normal.
	POP	DS
	RET
EMSOPN2_ERROR:
	MOV	BX,0			;
	MOV	AX,3			; 3=error.
	POP	DS
	RET
EMSOPN2_EXIT:
	MOV	BX,0
	POP	DS
	RET
EMSOPN2	ENDP


;	EMS close.
;	-O- AX : 0=normal,3=error

EMSCLS	PROC	FAR
	PUSH	DS
	MOV	AX,SEG EMMDAT
	MOV	DS,AX

	CMP	EMS_ON_FLAG,1		; EMS flag(1=on,0=off)
	JNE	EMSCLS_ERROR		;

	CALL	EMM_D_P			; EMM Deallocate Pages.
	CMP	AX,0			; EMM status (0=normal,0<>error)
	JNE	EMSCLS_ERROR		;

EMSCLS_NORMAL:
	MOV	AX,0			; 0=normal.
	POP	DS
	RET
EMSCLS_ERROR:
	MOV	AX,3			; 3=error.
	POP	DS
	RET
EMSCLS	ENDP


;	EMS seek.
;	(seek size 16kbyte.)
;	-I- BX : page number.
;	-O- ES : frame segment.
;	    AX : 0=normal,3=error

EMSSEK	PROC	FAR
	PUSH	DS
	MOV	AX,SEG EMMDAT
	MOV	DS,AX

	CMP	EMS_ON_FLAG,1		; EMS flag(1=on,0=off)
	JNE	EMSSEK_ERROR		;

	MOV	AX,0			; physical page number.
	CALL	EMM_MU_H_P		; EMM Map/Unmap Handle Pages.
	CMP	AX,0			; EMM status (0=normal,0<>error)
	JNE	EMSSEK_ERROR		;

EMSSEK_NORMAL:
	MOV	ES,EMM_PAGE_FREAM_SEG	; EMM page frame segment.
	MOV	AX,0			; 0=normal.
	POP	DS
	RET
EMSSEK_ERROR:
	MOV	ES,EMM_PAGE_FREAM_SEG	; EMM page frame segment.
	MOV	AX,3			; 3=error.
	POP	DS
	RET
EMSSEK	ENDP


;	EMS seek 64k frame.
;	-I- BX : top page number.
;	-O- ES : frame segment.
;	    AX : 0=normal,3=error

EMS64K	PROC	FAR
	PUSH	DS
	MOV	AX,SEG EMMDAT
	MOV	DS,AX

	CMP	EMS_ON_FLAG,1		; EMS flag(1=on,0=off)
	JNE	EMS64K_ERROR		;

	MOV	LOGI_PAGE_NUMBER,BX	; logical page number.
	MOV	PHYS_PAGE_NUMBER,0	; physical page number.

	MOV	CX,4			; 4 page.
EMS64K_LOOP:				;
	MOV	BX,LOGI_PAGE_NUMBER	; logical page number.
	MOV	AX,PHYS_PAGE_NUMBER	; physical page number.
	CALL	EMM_MU_H_P		; EMM Map/Unmap Handle Pages.
	CMP	AX,0			; EMM status (0=normal,0<>error)
	JNE	EMS64K_ERROR		;

	INC	LOGI_PAGE_NUMBER	; logical page number.
	INC	PHYS_PAGE_NUMBER	; physical page number.

	LOOP	EMS64K_LOOP		;

EMS64K_NORMAL:
	MOV	ES,EMM_PAGE_FREAM_SEG	; EMM page frame segment.
	MOV	AX,0			; 0=normal.
	POP	DS
	RET
EMS64K_ERROR:
	MOV	ES,EMM_PAGE_FREAM_SEG	; EMM page frame segment.
	MOV	AX,3			; 3=error.
	POP	DS
	RET
	RET
EMS64K	ENDP


EMMCOD	ENDS



EMMDAT	SEGMENT	PUBLIC	'EMMDAT'

EMS_ON_FLAG		DW	0	; EMS flag(1=on,0=off)
EMM_PAGE_FREAM_SEG	DW	0	; EMM page frame segment.
LOGI_PAGE_NUMBER	DW	0	; logical page number.
PHYS_PAGE_NUMBER	DW	0	; physical page number.

USER_PAGE_COUNT		DW	0	; user page count.

EMMDAT	ENDS

	END
;
;	end of "EMSHND.ASM"
;
