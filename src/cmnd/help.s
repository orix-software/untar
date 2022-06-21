;----------------------------------------------------------------------
;
; Entrée:
;
; Sortie:
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc cmnd_help
        print helpmsg
        clc
        rts
.endproc

;----------------------------------------------------------------------
;				DATAS
;----------------------------------------------------------------------
.pushseg
.segment "RODATA"
	helpmsg:
	    .byte $0a, $0d
	    .byte $1b,"C            untar utility\r\n\n"
	    .byte " ",$1b,"TSyntax:",$1b,"P\r\n"
	    .byte "    untar",$1b,"A-h\r\n"
	    .byte "    untar",$1b,"A-tf file\r\n"
	    .byte "    untar",$1b,"A-tvf file\r\n"
	    .byte "    untar",$1b,"A-xf file\r\n"
	    .byte "    untar",$1b,"A-xvf file"
	    .byte "\r\n"
	    .byte $00
.popseg


