; "MEMORYS.ASM" PC98series make by R.H 1993/06/30
;
;
;	real memory handle.
;
;
; public subroutine.

SEGFREE	SEGMENT	PUBLIC	'SEGFREE'
SEGFREE	ENDS

PAGE_SIZE_PARA	EQU	400H		; 1 page size paragraph.

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	MEMOPN			; real memory open.
PUBLIC	MEMCLS			; real memory close.
PUBLIC	MEMSEK			; real memory seek.


;	real memory open.
;	-O- BX : free page counter.

MEMOPN	PROC	NEAR
	CALL	REAL_MEM_CHK		; real memory check.
	MOV	BX,PAGE_MAX_REALMEM	; page max real memory.
	RET
MEMOPN	ENDP


;	real memory check.

REAL_MEM_CHK	PROC	NEAR
	MOV	AX,0A000H		; real memory end.
	SUB	AX,SEG SEGFREE		;
	JB	REAL_MEM_CHK_1		;
	SUB	AX,400H			;
	JB	REAL_MEM_CHK_1		;
	SUB	AX,10H			; + 256byte.
	JNB	REAL_MEM_CHK_2		;
REAL_MEM_CHK_1:
	MOV	AX,0			;
REAL_MEM_CHK_2:
	MOV	DX,0			;
	MOV	BX,PAGE_SIZE_PARA	; 1 page size paragraph.
	DIV	BX			;
	MOV	PAGE_MAX_REALMEM,AX	; page max real memory.

	MOV	AX,SEG SEGFREE		;
	ADD	AX,10H			; + 256byte.
	MOV	SEG_START_REALMEM,AX	; segment start real memory.

	RET
REAL_MEM_CHK	ENDP


;	real memory close.

MEMCLS	PROC	NEAR
	RET
MEMCLS	ENDP


;	real memory seek.
;	(seek size 16kbyte.)
;	-I- BX : page number.
;	-O- ES : frame segment.
;	    AX : 0=normal,3=error

MEMSEK	PROC	NEAR
	CMP	BX,PAGE_MAX_REALMEM	; page max real memory.
	JNB	MEMSEK_ERROR		;

	MOV	AX,PAGE_SIZE_PARA	; 1 page size paragraph.
	MUL	BX			;
	ADD	AX,SEG_START_REALMEM	; segment start real memory.
	MOV	ES,AX			;
MEMSEK_EXIT:
	MOV	AX,0			; 0=normal
	RET
MEMSEK_ERROR:
	MOV	AX,3			; 3=error
	RET
MEMSEK	ENDP


CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

PAGE_MAX_REALMEM	DW	0	; page max real memory.

SEG_START_REALMEM	DW	0	; segment start real memory.

DATA	ENDS

	END
;
;	end of "MEMORYS.ASM"
;
