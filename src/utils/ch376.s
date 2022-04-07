.include "include/ch376.inc"

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
.proc FileOpen
		lda	#CH376_FILE_OPEN
		sta	CH376_COMMAND

		jmp	WaitResponse
.endproc

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
.proc DirCreate
		lda	#CH376_DIR_CREATE
		sta	CH376_COMMAND
		jsr	WaitResponse

		; Fichier existant?
		cmp	#CH376_ERR_FOUND_NAME

		; Répertoire créé ou existant
		cmp	#CH376_USB_INT_SUCCESS
		rts
.endproc

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
.proc WaitResponse
		ldy     #$ff

	loop1:
		ldx     #$ff
	loop2:
		lda     CH376_COMMAND
		bmi     loop

		lda     #$22
		sta     CH376_COMMAND
		lda     CH376_DATA
		rts

	loop:
		dex
		bne     loop2

		dey
		bne     loop1

		rts
.endproc


