.include "macros/utils.mac"

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
.proc cmnd_extract
		; Interdit l'écrasement des fichiers
		lda	#$ff
		sta	keep_old_files

		getcwd	cwd
		; print	(cwd), NOSAVE
		; crlf

		jsr	archive_open
		bne	loop

	errFopen:
		lda	#e13
		sec
		rts

	loop:
;		crlf

		jsr	archive_read_bloc

		lda	BUFFER+st_header::name
		jeq	close

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
		jsr	archive_calc_size

		ldx	#$03
	loop1:
		lda	pfac,x
		sta	bin_value,x
		dex
		bpl	loop1

		; Conserve le nombre d'octets contenus dans le dernier bloc
		lda	bin_value
		sta	bloc_bytes
		lda	bin_value+1
		and	#$01
		sta	bloc_bytes+1

		; -V?
		bit	opt
		bvc	extract

	verbose:
		crlf
		print	BUFFER+st_header::name
.if 0
		; Verbose pout tar -tvf
		lda	BUFFER+st_header::type
		.byte	$00, XWR0

		; .byte	$00, XWR0
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
.endif
		cputc	' '

	extract:
		lda	BUFFER+st_header::type
		cmp	#'5'
		beq	extract_dir

		cmp	#'0'
		beq	extract_file

		print	unsupported_type
		print	BUFFER+st_header::name
		crlf
		jsr	archive_calc_blocs

		jsr	archive_skip
		; saut inconditionnel (archive_skip: sortie avec Z=1)
		;beq	loop
		jmp	loop

	extract_dir:
		jsr	mkdir
		bcs	close_err
		;beq	loop
		jmp	loop

	extract_file:
		jsr	mkfile
		bcs	close_err
		;beq	loop
		jmp	loop

	close:
		jsr	archive_close
		rts

	close_err:
		pha
		jsr	archive_close
		pla
		sec
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
.proc mkdir
;		print	mkdir_msg
		jsr	mkpath
		bcs	end

		; Sauvegarde Y pour plus tard
		; (longueur de path)
		tya
		pha

;		print	path
		; print	BUFFER+st_header::name, NOSAVE
;		crlf

		jsr	archive_calc_blocs

		jsr	archive_close

		ldx	#<path
		ldy	#>path
		pla
		jsr	_mkdir

		jsr	archive_reopen
		bne	end
		jsr	archive_skip

	end:
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
.proc mkfile
;		print	extract_msg
		jsr	mkpath
		bcs	end

;		print	path
		; print	BUFFER+st_header::name, NOSAVE
;		crlf

		jsr	archive_calc_blocs

		jsr	file_exists
		bcs	extract

		; keep_old_file = False?
		lda	keep_old_files
		beq	extract

	error:
		; e25: <FNAME> delete protected
		; e26: <FNAME> write protected
		; e28: <FNAME> permission denied
		; -V?
		bit	opt
		bvs	error2
		crlf
		print	BUFFER+st_header::name
	error2:
		print	overwrite_msg
		jsr	archive_skip

		; Si on veut stopper complètement l'extraction
		;lda	#e25
		;sec

		rts

	extract:
		jsr	archive_extract
		; crlf

	end:
		rts

.endproc

;----------------------------------------------------------------------
;
; Entrée:
;
; Sortie:
;	A: $00 ou code erreur e10
;	X: Nombre de caractères de st_header::name (pointe sur le \0 final)
;	Y: Nombre total de caractères (pointe sur le \0 final)
;	C: 0->Ok, 1->Erreur
;
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc mkpath
		ldx	#$ff

		ldy	#$ff
	loop:
		iny
;		beq	error
		cpy	#max_path
		bcs	error

		lda	(cwd),y
		sta	path,y
		bne	loop

		; ajoute un '/' à la fin de CWD si il n'y en n'a pas
		; (on pourrait simplifier en comparant Y à 1, dans ce cas
		;  CWD == '/')
		dey
		lda	#'/'
		cmp	(cwd),y
		beq	suite
		iny
		sta	path,y

	suite:
		iny
		beq	error
		cpy	#max_path
		bcs	error

		inx
		lda	BUFFER+st_header::name,x
		sta	path,y
		bne	suite

		clc
		rts

	error:
		lda	#e10
		sec
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
.proc archive_extract
		; Taille du bloc à écrire
		lda	#<$0200
		sta	bloc_size
		lda	#>$0200
		sta	bloc_size+1

		lda	#$00
		sta	file_pos
		sta	file_pos+1
		sta	file_pos+2
		sta	file_pos+3

		; Créé le répertoire de destination
		; Nécessaire dans le cas de: tar -cvf archive.tar dir/fichier
		; au lieu de: tar -cvf archive.tar dir/*
		jsr	opendir

		; Teste la taille du fichier
		; /!\ saute un fichier de taille nulle
;		lda	pfac+1
;		beq	test

	loop:
;		jsr	StopOrCont
;		bcc	cont
;		lda	#e4
;		bcs	end

	cont:
		jsr	save_bloc

		lda	pfac+1
		bne	dec_pfac_1

		lda	pfac+2
		bne	dec_pfac_2

		lda	pfac+3
		bne	dec_pfac_3
		beq	end

	dec_pfac_3:
		dec	pfac+3
;		beq	end

	dec_pfac_2:
		dec	pfac+2
;		beq	end

	dec_pfac_1:
		dec	pfac+1
		bne	loop
		lda	pfac+1

	test:
		lda	pfac+2
		bne	loop
		lda	pfac+3
		bne	loop
	end:
		clc
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
.proc save_bloc
		; -V?
		bit	opt
		bvc	save
		print	save_bloc_msg

	save:
		jsr	archive_read_bloc
		jsr	archive_close

		jsr	file_open
		jsr	file_append_bloc
		jsr	file_close

		jsr	archive_reopen
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
;	- archive_close
;	- archive_reopen
;----------------------------------------------------------------------
.proc file_exists
		jsr	archive_close

		fopen	path, O_RDONLY
		cmp	#$ff
		bne	true
		cpx	#$ff
		bne	true

	; false:
		.byte $00, XCLOSE
		jsr	archive_reopen
		sec
		rts

	true:
		.byte $00, XCLOSE
		jsr	archive_reopen
		clc
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
.proc file_close
		jsr	file_tell
		fclose (fp)

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
;.proc file_open
;		; O_RDWR non supporté actuellement par le kernel
;		; (force CH376_CMD_FILE_CREATE)
;		fopen	path, O_RDWR
;		sta	fp
;		stx	fp+1
;		eor	fp+1
;
;		rts
;.endproc

.proc file_open
		lda	file_pos
		ora	file_pos+1
		ora	file_pos+2
		ora	file_pos+2
		bne	reopen

		; 1ère ouverture du fichier
		fopen	path, O_RDONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		beq	create

		; ici le fichier existe
		;lda	keep_old_files
		;bne	error

		; On peut l'écraser
		unlink	path

	create:
		;fopen	path, O_CREAT | O_WRONLY
		;fopen	path, O_WRONLY
		fopen	path, O_CREAT | O_WRONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		rts

	reopen:
		; fopen	path, O_RDWR
		; fopen	path, O_WRONLY
		;fopen	path, O_RDONLY
		fopen	path, O_WRONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		rts

;	error:
;		; e25: <FNAME> delete protected
;		; e26: <FNAME> write protected
;		; e28: <FNAME> permission denied
;		fclose (fp)
;		print	overwrite_msg, NOSAVE
;		lda	#e25
;		sec
;		rts
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
.proc file_append_bloc
		jsr	file_seek
		; TODO: remonter code erreur file_seek
		jmp	file_write_bloc
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
.proc file_write_bloc
		; Vérifie si la taille est nulle
		; ou si il s'agit du dernier bloc
		lda	pfac+3
		bne	write_bloc
		lda	pfac+2
		bne	write_bloc
		lda	pfac+1
		beq	end

		cmp	#$01
		bne	write_bloc

		; Dernier bloc, on n'écrit que les derniers octets
		lda	bloc_bytes
		sta	bloc_size
		lda	bloc_bytes+1
		sta	bloc_size+1

		; Si octets restants == 0, il faut écrire un bloc complet
		bne	write_bloc
		cmp	bloc_size
		bne	write_bloc
		; Taille du bloc = $0200
		lda	#>$0200
		sta	bloc_size+1

	write_bloc:
		fwrite BUFFER, (bloc_size), 1, fp
		; TODO: voir code erreur de fwrite
	end:
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
.proc opendir
		; Optimisation possible si on est sûr que path est
		; un chemin absolu (dans ce cas, on peut remettre
		; le "bne loop" plus bas:
		; lda	#$00
		; tay
		lda	#$00
		ldy	#$ff
	loop:
		iny
		ldx	path,y
		beq	end

		cpx	#'/'
		bne	loop

		; On ne peut pas utiliser "bne loop" si path[0] =='/'
		; (chemin absolu)
		; tya
		; bne	loop
		jmp	loop

	end:
		pha
		jsr	archive_close
		ldx	#<path
		ldy	#>path
		pla
		jsr	_mkdir
		; TODO: tester éventuelle erreur de _mkdir
		jsr	archive_reopen
		rts
.endproc


;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.pushseg
	.zeropage
		unsigned short cwd
.popseg

.pushseg
	.segment "BSS"
		unsigned char path[max_path]
		unsigned short bloc_size
		unsigned short bloc_bytes

;		unsigned char save_a
;		unsigned char save_x
;		unsigned char save_y
.popseg

;----------------------------------------------------------------------
;				DATAS
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
		unsupported: .asciiz "unsupported option\r\n"
		unsupported_type: .asciiz "?? "
;		mkdir_msg: .asciiz "mkdir "
;		extract_msg: .asciiz "extract "
		save_bloc_msg: .asciiz "."
		overwrite_msg: .asciiz ": File exists"
.popseg

