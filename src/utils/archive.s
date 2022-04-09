;Tar:
;	Blocs de 512 octets
;
;Entête:
;bloc 1: 256 octets
;	Nom 	Position 	Taille 	Description
;	name 	0 	100 	Nom du fichier
;	mode 	100 	8 	Permissions
;	uid 	108 	8 	Propriétaire (inutilisé si format étendu)
;	gid 	116 	8 	Groupe (inutilisé si format étendu)
;	size 	124 	12 	Taille du fichier en octets. La taille doit être nulle si le fichier est un fichier spécial (lien symbolique, tuyau nommé, "device" par blocs ou par caractères, etc)
;	mtime 	136 	12 	Dernière modification en temps Unix.
;	chksum 	148 	8 	Somme de contrôle de l'en-tête où ce champ est considéré comme rempli d'espaces (valeur ascii 32)
;	type flag 	156 	1 	Type de fichier
;	linkname 	157 	100 	Nom du fichier pointé par ce lien symbolique (Si le type indique un lien symbolique)
;
;bloc2: 256 octets
;	Les champs suivants ont été ajoutés par la norme POSIX 1003.1-1990.
;
;	Champ 	Position 	Taille 	Description
;	magic 	257 	6 	ce champ indique s'il s'agit d'un en-tête étendu. Il vaut alors "ustar".
;	version 	263 	2 	les caractères « 00 » indiquent un format POSIX 1003.1-1990. Deux espaces indique le format vieux GNU (à ne plus utiliser).
;	uname 	265 	32 	nom de l'utilisateur propriétaire sous forme d'une chaîne de caractères d'au plus 32 caractères. S'il est présent, ce champ doit être utilisé à la place de uid.
;	gname 	297 	32 	nom du groupe propriétaire sous forme d'une chaîne de caractères d'au plus 32 caractères. S'il est présent, ce champ doit être utilisé à la place de gid.
;	devmajor 	329 	8 	ce champ représente le numéro majeur si ce fichier est de type "device" par blocs ou par caractères
;	devminor 	337 	8 	ce champ représente le numéro mineur, si ce fichier est de type "device" par blocs ou par caractères
;	prefix 	345 	155
;	fin 	500 	0
;
;
;Type de fichier
;	Valeur 	Signification
;	'0' 	Fichier normal
;	(ASCII NUL) 	Fichier normal (usage obsolète)
;	'1' 	Lien matériel
;	'2' 	Lien symbolique
;	'3' 	Fichier spécial caractère
;	'4' 	Fichier spécial bloc
;	'5' 	Répertoire
;	'6' 	Tube nommé
;	'7' 	Fichier contigu.
;	'g' 	En-tête étendu POSIX.1-2001
;	'x' 	En-tête étendu avec méta-données POSIX.1-2001
;	'A-Z' 	Extensions format POSIX.1-1988
;
;Lecture par bloc de 256 octets
;
;	Openfile(fn)	; Ouverture du fichier
;
;		ReadBloc(2)	; Lecture de 2 blocs de 256 octets
;		Affiche(type, name, size)
;		Calcul du nombre de blocs de data à lire: round(size/512)  (blocs de 512 octets)
;		Lecture des datas
;
;	Fin si 2 blocs de 512 octets nuls
;
;Taille totale du fichier .tar : multiple de 10240 par défaut (20x512)
;
.include "include/ch376.inc"

;----------------------------------------------------------------------
;				DATAS
;----------------------------------------------------------------------
.pushseg
	.segment "RODATA"
	filetype_msg: .byte "-hlcbdp?"
.popseg

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc archive_open
		fopen	fname, O_RDONLY
		sta	fp
		stx	fp+1
		eor	fp+1
		rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc archive_reopen
		jsr	archive_open
		bne	seek
		lda	#e13
		sec
		rts

	seek:
		jsr	archive_seek
		rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc archive_check
		ldy	#$06
	loop:
		lda	BUFFER+st_header::magic,y
		cmp	magic,y
		bne	error
		dey
		bpl	loop
		rts

	error:
		; Oublie l'adresse de retour
		pla
		pla

		lda	#e29
		sec
		rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc archive_read_bloc
		fread	BUFFER, 512, 1, fp
;		jsr	archive_tell
		rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc archive_close
		jsr	archive_tell
		fclose (fp)
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
.proc archive_skip
		lda	pfac+1
		beq	test

	loop:
;		jsr	StopOrCont
;		bcc	cont
;		lda	#e4
;		bcs	end

	cont:
		jsr	archive_read_bloc

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
		clc
	end:
		rts

.endproc

;----------------------------------------------------------------------
; Sortie:
;	C=1 => Erreur
;	Résultat de la conversion dans pfac
;----------------------------------------------------------------------
.proc archive_calc_size

		; Force type numérique: octal
		; /!\ écrase le dernier caractère du gid (c'est un $00)
		lda	#'@'
		; Calcule la taille du fichier en octet
		; résultat dans pfac
		sta	BUFFER-1+st_header::size

		; conversion octal -> binaire
		ldx	#<(BUFFER-1+st_header::size)
		ldy	#>(BUFFER-1+st_header::size)
		jsr	strbin

		; Restaure le dernier caractère du gid
		lda	#$00
		sta	BUFFER-1+st_header::size

		rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc archive_calc_blocs
		; round(pfac/512)
		lsr	pfac+3
		ror	pfac+2
		ror	pfac+1
		bcs	add_one
		lda	pfac+0
		beq	end

	add_one:
		inc	pfac+1
		bne	end
		inc	pfac+2
		bne	end
		inc	pfac+3
	end:
		rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc mode2str
		; 36 octets si modestr est en page zéro, 36+7 sinon
		pha

		lda	#'-'
		sta	modestr
		sta	modestr+1
		sta	modestr+2
		lda	#$00
		sta	modestr+3


		; rwx
		pla
	exec:
		lsr
		bcc	write
		ldx	#'x'
		stx	modestr+2
	write:
		lsr
		bcc	read
		ldx	#'w'
		stx	modestr+1

	read:
		lsr
		bcc	end
		ldx	#'r'
		stx	modestr+0
	end:
		rts

.if 0
		; 16 octets (-2 si modestr est en page zero) +32 octets pour les chaines => 48 octets
		and	#$07
		asl
		asl
		clc
		adc	#<modestr
		sta	ptr01
		lda	#$00

		; On peut supprimer l'instruction suivante si modestr est en page zéro
		adc	#>modestr

		sta	ptr01+1
		rts
.endif
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc type2str
		sec
		lda	BUFFER+st_header::type
		beq	end
		sbc	#'0'
		cmp	#$07
		bcc	end
		lda	#$07
	end:
		tax
		lda	filetype_msg,x
		rts
.endproc

;----------------------------------------------------------------------
;               Suppression des '0' non significatifs
;----------------------------------------------------------------------
.proc display_size
		; Remplace les '0' non significatifs par des ' '
		ldy #$ff
		ldx #' '
	skip:
		iny
		cpy #$09
		beq display

		lda (RES),y
		cmp #'0'
		bne display

		txa
		sta (RES),y
		bne skip

	display:
		print	(RES)
		rts
.endproc

