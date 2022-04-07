;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc cmnd_list
		jsr	open_archive
		bne	loop

	errFopen:
		lda	#e13
		sec
		rts

	loop:
		jsr	read_bloc

;		jsr	StopOrCont
;		bcs	close


		lda	BUFFER+st_header::name
		beq	close

		; Optimisation: ne faire le test suivant uniquement
		; pour le premier bloc lu
		jsr	archive_check

		; Force type numérique: octal
		; /!\ écrase le dernier caractère du gid (c'est un $00)
		lda	#'@'
		; Calcule la taille du fichier en octet
		; résultat dans pfac
		sta	BUFFER-1+st_header::size
		; conversion octal -> binaire
		jsr	calc_size

		ldx	#$03
	loop1:
		lda	pfac,x
		sta	bin_value,x
		dex
		bpl	loop1

		; -V?
		bit	opt
		bvc	display_name

	verbose:
		; 0000755
		lda	BUFFER+st_header::mode+4
		jsr	mode2str
		print	modestr, NOSAVE

		lda	BUFFER+st_header::mode+5
		jsr	mode2str
		print	modestr, NOSAVE

		lda	BUFFER+st_header::mode+6
		jsr	mode2str
		print	modestr, NOSAVE

		print	#' ', NOSAVE

		; On suppose une archive ustar
		; TODO: faire un test pour le type d'archive
		print	BUFFER+st_header::uname, NOSAVE
		print	#'/', NOSAVE
		print	BUFFER+st_header::gname, NOSAVE

;		print	#' '
;		print	#' '
;		print	BUFFER+st_header::size


		jsr	bin2bcd
		lda	#<str
		ldy	#>str
		jsr	bcd2str
		jsr	display_size

		print	#' ', NOSAVE

	display_name:
		print	BUFFER+st_header::name, NOSAVE
		.byte $00, XCRLF
		jsr	calc_blocs

		jsr	archive_skip
		; saut inconditionnel (archive_skip: sortie avec Z=1, et C=0,
		; ou C=1 si Ctrl+C)
		bcc	loop

	close:
		jsr	close_archive
		rts

.endproc

