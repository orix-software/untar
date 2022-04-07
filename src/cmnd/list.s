;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc cmnd_list
		jsr	archive_open
		bne	loop

	errFopen:
		lda	#e13
		sec
		rts

	loop:
		jsr	archive_read_bloc

		lda	BUFFER+st_header::name
		beq	close

		; Optimisation: ne faire le test suivant uniquement
		; pour le premier bloc lu
		jsr	archive_check

		; conversion octal -> binaire
		jsr	archive_calc_size

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
		;lda	BUFFER+st_header::type
		jsr	type2str
		.byte	$00, XWR0
		; print	BUFFER+st_header::type, NOSAVE

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
		jsr	archive_calc_blocs

		jsr	archive_skip
		; saut inconditionnel (archive_skip: sortie avec Z=1)
		beq	loop

	close:
		jsr	archive_close
		rts

.endproc

