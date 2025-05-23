; "V98DSPST.ASM" 1992/04/03 R.H  PCAT486/33 make by R.H 1989
;		"DSPSET.ASM" 1989/09/15 R.H PC-9801UV11 make by R.H 1989
;		modify  1989/12/08 R.H
;		dual PC 1992/04/03 R.H
;		modifay 1993/07/01 R.H port I/Ointo
;
;
;	�f�B�X�v���C���Z�b�g
;
;
;	PC-9801 technical data book p.116 GDC mode reg.
;
; public subroutine.

IN_GDC	MACRO	AA,NUM
;same;	IN	AL,NUM
	PUSH	DX
	MOV	DX,NUM			;
	CALL	IN_7220_GDC_PORT	; in  port 7220 GDC.
	POP	DX
	ENDM

OUTGDC	MACRO	NUM,AA
;same;	OUT	NUM,AL
	PUSH	DX
	MOV	DX,NUM			;
	CALL	OUT_7220_GDC_PORT	; out port 7220 GDC.
	POP	DX
	ENDM

PC98VRAM_SEG_G0	EQU	0A800H		; �u�q�`�l�v���[���O
PC98VRAM_SEG_G1	EQU	0B000H		; �u�q�`�l�v���[���P
PC98VRAM_SEG_G2	EQU	0B800H		; �u�q�`�l�v���[���Q
PC98VRAM_SEG_G3	EQU	0E000H		; �u�q�`�l�v���[���R
PC98VRMWIDTH	EQU	80		; �u�q�`�l��

CODE	SEGMENT	PUBLIC	'CODE'

	ASSUME	CS:CODE,DS:DATA

PUBLIC	VRMGRPMDE	; vram graphic mode.
PUBLIC	VRMRETMDE	; vram graphic mode ret.
PUBLIC	VRMSTOP		; vram graphic stop.
PUBLIC	VRMCLR		; �u�q�`�l�N���A
PUBLIC	VRM98DP		; PC98 vram show bank.
PUBLIC	VRM98WT		; PC98 vram write bank.
PUBLIC	VRM98NOW	; PC98 vram bank now.

EXTRN	GDCSRT:NEAR	; graphic start.
EXTRN	GDCSTP:NEAR	; graphic stop.
EXTRN	GDCSET:NEAR	; graphic mode set.
EXTRN	GDCWAT:NEAR	; GDC wait.


;	vram graphic mode.

VRMGRPMDE	PROC	NEAR
	CALL	GDCWAT			; GDC wait.

	MOV	BYTE PTR GMODE,11000000B; 640x400 mode.
	CALL	GDCSET			; graphic mode set.

	CALL	GDCWAT			; GDC wait.

	MOV	AL,1			;  16 color mode.
	OUTGDC	06AH,AL			;

	CALL	GDCWAT			; GDC wait.

	MOV	AL,00001000B		;  400 line mode.
	OUTGDC	068H,AL			;

	MOV	AX,0			; 0=VRAM0 show, 1=VRAM1 show.
	CALL	VRM98DP			; PC98 vram show bank.

	MOV	AX,0			; 0=VRAM0 write,1=VRAM1 write.
	CALL	VRM98WT			; PC98 vram write bank.

	CALL	GDCWAT			; GDC wait.

	CALL	GDCSRT			; graphic start.

	MOV	CX,200			;120;error=115 for PC-386VR 1992/02/19
VRMGRPMDE_WAIT_LLLL:
	PUSH	AX
	POP	AX
	LOOP	VRMGRPMDE_WAIT_LLLL

	CALL	GDCWAT			; GDC wait.
	RET
VRMGRPMDE	ENDP


;	vram graphic mode ret.

VRMRETMDE	PROC	NEAR
	RET
VRMRETMDE	ENDP


;	vram graphic stop.

VRMSTOP	PROC	NEAR
	CALL	GDCWAT			; GDC wait.

	CALL	GDCSTP			; graphic stop.

	MOV	CX,200			;120
VRMSTOP_WAIT_LLLL:
	PUSH	AX
	POP	AX
	LOOP	VRMSTOP_WAIT_LLLL
	RET
VRMSTOP	ENDP


;	�u�q�`�l�N���A

VRMCLR	PROC	NEAR
	MOV	AX,WORD PTR ARAVRM[0]	; vram plean 1.
	MOV	ES,AX
	MOV	DI,0
	MOV	CX,40*400
	MOV	AX,0
	REP	STOSW

	MOV	AX,WORD PTR ARAVRM[2]	; vram plean 2.
	MOV	ES,AX
	MOV	DI,0
	MOV	CX,40*400
	MOV	AX,0
	REP	STOSW

	MOV	AX,WORD PTR ARAVRM[4]	; vram plean 3.
	MOV	ES,AX
	MOV	DI,0
	MOV	CX,40*400
	MOV	AX,0
	REP	STOSW

	MOV	AX,WORD PTR ARAVRM[6]	; vram plean 4.
	MOV	ES,AX
	MOV	DI,0
	MOV	CX,40*400
	MOV	AX,0
	REP	STOSW

	RET
VRMCLR	ENDP


;	PC98 vram show bank.
;	-I- AX : 0=VRAM0 show, 1=VRAM1 show.

VRM98DP	PROC	NEAR
	AND	AL,01H
	OUTGDC	0A4H,AL
	MOV	VRM_DSP_MODE_NOW,AL	; vram write bank number.
	RET
VRM98DP	ENDP


;	PC98 vram write bank.
;	-I- AX : 0=VRAM0 write,1=VRAM1 write.

VRM98WT	PROC	NEAR
	AND	AL,01H
	OUTGDC	0A6H,AL
	MOV	VRM_WRT_MODE_NOW,AL	; vram write bank number.
	RET
VRM98WT	ENDP


;	PC98 vram bank now.
;	-O- AX : vram disp bank number.
;	    BX : vram write bank number.

VRM98NOW	PROC	NEAR
	MOV	AX,WORD PTR VRM_DSP_MODE_NOW	; vram disp bank number.
	MOV	BX,WORD PTR VRM_WRT_MODE_NOW	; vram write bank number.
	RET
VRM98NOW	ENDP



;	in  port 7220 GDC.
;	-I- DX : port number.
;	-O- AL : input data.

IN_7220_GDC_PORT	PROC	NEAR
	IN	AL,DX
	RET
IN_7220_GDC_PORT	ENDP

;	out port 7220 GDC.
;	-I- DX : port number.
;	    AL : output data.

OUT_7220_GDC_PORT	PROC	NEAR
	OUT	DX,AL
	RET
OUT_7220_GDC_PORT	ENDP

CODE	ENDS


DATA	SEGMENT	PUBLIC	'DATA'

EXTRN	GX1:WORD			;
EXTRN	GY1:WORD			; GRBIO subroutine parameter.
EXTRN	GX2:WORD			;
EXTRN	GY2:WORD			;
EXTRN	GMODE:WORD			;
EXTRN	GCODE:WORD			;
EXTRN	GCLR:WORD			;
EXTRN	GRD:WORD			;

VRM_DSP_MODE_NOW	DB	0,0	; vram write bank number.
VRM_WRT_MODE_NOW	DB	0,0	; vram write bank number.

ARAVRM	LABEL	WORD		; �u�q�`�l�v���[��
	DW	PC98VRAM_SEG_G0	; �u�q�`�l�v���[���O
	DW	PC98VRAM_SEG_G1	; �u�q�`�l�v���[���P
	DW	PC98VRAM_SEG_G2	; �u�q�`�l�v���[���Q
	DW	PC98VRAM_SEG_G3	; �u�q�`�l�v���[���R
	DW	PC98VRMWIDTH	; �u�q�`�l�v���[����

DATA	ENDS

	END
;
;	end of "V98DSPST.ASM"
;
