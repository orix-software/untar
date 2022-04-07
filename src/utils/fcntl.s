;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.zeropage
		; Pour _mkdir
		unsigned short work
.popseg

.pushseg
	; .segment "BSS"
	.segment "DATA"
		unsigned long fpos[2]
;		unsigned long archive_pos
;		unsigned long file_pos
		archive_fp = 0
		file_fp = 4

		; Utilisé par archive_extract et file_open
		file_pos = fpos+file_fp

;		unsigned char save_a
;		unsigned char save_x
;		unsigned char save_y
.popseg

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
.proc _mkdir
		; Adresse de le chaine
		stx	ptr01
		sty	ptr01+1

		; Longueur de la chaîne
		sta	work

		lda	#$00
		sta	work+1

		; Si le 1er caractère n'est pas '/' => ouverture relative
		ldy	#$00
		lda	#'/'
		cmp	(ptr01),Y
		bne	relative

		; Apres le test, .A contient '/' soit $2F (CH376_SET_FILENAME)

		; Ouverture racine
		sta	CH376_COMMAND
		sta	CH376_DATA

		; Open
		jsr	Open
		cmp	#CH376_ERR_OPEN_DIR
		bne	end

		inc	work+1

	relative:
		lda	work+1
		cmp	work
		bcs	end

		lda	#CH376_SET_FILENAME
		sta	CH376_COMMAND

	while:
		ldy	work+1
		cpy	work
		bcs	Create

		lda	(ptr01),Y

		cmp	#'/'
		bne	ZZ0007

		jsr	Create
		cmp	#CH376_USB_INT_SUCCESS
		bne	end

		inc	work+1
		ldy	work+1
		cpy	work
		bcs	end

		lda	#CH376_SET_FILENAME
		sta	CH376_COMMAND

		lda	(ptr01),Y

	ZZ0007:
		cmp	#'a'
		bcc	ZZ0009
		cmp	#'z'
		bcs	ZZ0009
		sbc	#$1f

	ZZ0009:
		sta	CH376_DATA
		inc	work+1
		jmp	while

	Open:
		lda	#$00
		sta	CH376_DATA
		jsr	FileOpen
		rts

	Create:
		lda	#$00
		sta	CH376_DATA
		jsr	DirCreate
	end:
;		; .AY = Code erreur, poids faible dans .A
;		tay
;		lda	#$00
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
.proc ftell
		pha

		lda	#CH376_READ_VAR32
		sta	CH376_COMMAND
		lda	#CH376_VAR_CURRENT_OFFSET
		sta	CH376_DATA

		lda	CH376_DATA
		sta	fpos,y

		lda	CH376_DATA
		sta	fpos+1,y

		lda	CH376_DATA
		sta	fpos+2,y

		lda	CH376_DATA
		sta	fpos+3,y

		pla
		rts
.endproc

.proc file_tell
;		sty	save_y
		ldy	#file_fp
		jsr	ftell
;		ldy	save_y
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
.proc fseek
		lda	#CH376_BYTE_LOCATE
		sta	CH376_COMMAND

		lda	fpos,y
		sta	CH376_DATA

		lda	fpos+1,y
		sta	CH376_DATA

		lda	fpos+2,y
		sta	CH376_DATA

		lda	fpos+3,y
		sta	CH376_DATA

		jsr	WaitResponse
		cmp	#CH376_USB_INT_SUCCESS

		rts
.endproc

.proc file_seek
;		sty	save_y
		ldy	#file_fp
		jsr	fseek
;		php
;		ldy	save_y
;		plp
		rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc archive_tell
;		sty	save_y
		ldy	#archive_fp
		jsr	ftell
;		ldy	save_y
		rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc archive_seek
;		sty	save_y
		ldy	#archive_fp
		jsr	fseek
;		php
;		ldy	save_y
;		plp
		rts
.endproc

