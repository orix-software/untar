.feature string_escapes

.feature c_comments

.macpack longbranch

/*
Méta données fichier:
	Position: 4 (ByteLocate)
	Taille  : 4
	Adresse chargement? : 4

	Nom Fichier: 64 (précédé par la longueur, terminé par un 0, dernier caractère +$80?)
	---------
	12+64 => 76 octets

Fichier:
	Data: n

---

Créer un répertoire avec les méta données?

3 20 00 / 2 00 => 1 90

pfac3		pfac2		pfac1		pfac0
0000 0000	0000 0011	0010 0000	0000 0000  => 0000 0001  1001 0000

/ $200 => (pfac3 -> pfac1) >> 1
===============
; ======
*/

;----------------------------------------------------------------------
;                       cc65 includes
;----------------------------------------------------------------------
.include "telestrat.inc"
.include "fcntl.inc"

;----------------------------------------------------------------------
;			Orix Kernel includes
;----------------------------------------------------------------------
.include "kernel/src/include/kernel.inc"

;----------------------------------------------------------------------
;			Orix SDK includes
;----------------------------------------------------------------------
.include "SDK.mac"
.include "SDK.inc"
.include "types.mac"
.include "errors.inc"

;----------------------------------------------------------------------
;				Imports
;----------------------------------------------------------------------

; From sopt
;.import spar1, sopt1, calposp, incr
;.import loupch1
.importzp cbp
.importzp opt
;.import inbuf
spar := spar1
sopt := sopt1

; From ermes
;.import ermes

; From ermtb
;.import ermtb

;----------------------------------------------------------------------
;				Exports
;----------------------------------------------------------------------
.export _main

; Pour ermes
.export crlf1, out1
.export prfild, prnamd
.export seter1

.exportzp xtrk, psec
.export drive

;----------------------------------------------------------------------
;			Librairies
;----------------------------------------------------------------------

;----------------------------------------------------------------------
; Defines / Constants
;----------------------------------------------------------------------

typedef .struct st_header
	unsigned char name[100]		; Nom du fichier
	unsigned char mode[8]		; Permissions
	unsigned char uid[8]		; Propriétaire (inutilisé si format étendu)
	unsigned char gid[8]		; Groupe (inutilisé si format étendu)
	unsigned char size[12]		; Taille du fichier en octets. La taille doit être nulle si le fichier est un fichier spécial (lien symbolique, tuyau nommé, "device" par blocs ou par caractères, etc)
	unsigned char mtime[12]		; Dernière modification en temps Unix.
	unsigned char chksum[8]		; Somme de contrôle de l'en-tête où ce champ est considéré comme rempli d'espaces (valeur ascii 32)
	unsigned char type		; Type de fichier
	unsigned char linkname[100]	; Nom du fichier pointé par ce lien symbolique (Si le type indique un lien symbolique)

	unsigned char magic[6]		; ce champ indique s'il s'agit d'un en-tête étendu. Il vaut alors "ustar".
	unsigned char version[2]	; les caractères « 00 » indiquent un format POSIX 1003.1-1990. Deux espaces indique le format vieux GNU (à ne plus utiliser).
	unsigned char uname[32]		; nom de l'utilisateur propriétaire sous forme d'une chaîne de caractères d'au plus 32 caractères. S'il est présent, ce champ doit être utilisé à la place de uid.
	unsigned char gname[32]		; nom du groupe propriétaire sous forme d'une chaîne de caractères d'au plus 32 caractères. S'il est présent, ce champ doit être utilisé à la place de gid.
	unsigned char devmajor[8]	; ce champ représente le numéro majeur si ce fichier est de type "device" par blocs ou par caractères
	unsigned char devminor[8]	; ce champ représente le numéro mineur, si ce fichier est de type "device" par blocs ou par caractères
	unsigned char prefix[155]

	unsigned char unused[12]
.endstruct

	LSB  := bin_value+0
	NLSB := bin_value+1
	NMSB := bin_value+2
	MSB  := bin_value+3

	max_path := KERNEL_MAX_PATH_LENGTH

	VERBOSE .set 1

;----------------------------------------------------------------------
;				Page Zéro
;----------------------------------------------------------------------
.zeropage
	unsigned short fp
	unsigned char modestr[4]

	unsigned char xtrk
	unsigned char psec

;----------------------------------------------------------------------
;				Variables
;----------------------------------------------------------------------
.segment "DATA"
	char str[11]
	char fname[max_path]
	magic: .asciiz "ustar  "

	unsigned char drive

	unsigned char keep_old_files

;----------------------------------------------------------------------
; Variables et buffers
;----------------------------------------------------------------------
.segment "CODE"
	; struct st_header, BUFFER;
	BUFFER: .tag st_header


.segment "BSS"
	unsigned long bin_value

;----------------------------------------------------------------------
;			Segments vides
;----------------------------------------------------------------------
.segment "STARTUP"
;	startup:
;		jsr	init			; dons le segment "ONCE"
;		jsr	zerobss			; dans le segment "CODE"
;		jsr	_main
;						; restaure ce qui a été sauvegardé par init
;		rts

.segment "INIT"
; contient normalement des données sauvegardées par init qui est dans le segment "ONCE"
;	init:
;		rts
	startup:
		jsr	zerobss

		; XMAINARGS
		; .byte $00, $2c

		; sta	argv
		; sty	argv+1
		; stx	argc

		lda	#<BUFEDT
		ldy	#>BUFEDT
		sta	cbp
		sty	cbp+1

		; Saute le nom de la commande
		ldy	#$00
	loop:
		lda	(cbp),y
		beq	go
		cmp	#' '
		beq	go
		iny
		bne	loop

	go:
		; Calcule l'adresse du premier paramètre
		clc
		tya
		adc	cbp
		tay
		lda	#$00
		adc	cbp+1

		jsr	_main
		rts

.proc zerobss
		lda	#<__BSS_RUN__
		sta	ptr01
		lda	#>__BSS_RUN__
		sta	ptr01+1
		lda	#0
		tay

	; Clear full pages

	L1:
		ldx	#>__BSS_SIZE__
		beq	L3
	L2:
		sta	(ptr01),y
		iny
		bne	L2
		inc	ptr01+1
		dex
		bne	L2

	; Clear remaining page (y is zero on entry)

	L3:
		cpy	#<__BSS_SIZE__
		beq	L4
		sta	(ptr01),y
		iny
		bne	L3

	; Done

	L4:
		rts

		rts
.endproc

.segment "ONCE"
;	once:
;		rts
MODULE , , startup

;----------------------------------------------------------------------
;				Programme
;----------------------------------------------------------------------
.segment "CODE"


.proc _main
		;ldy	#<(BUFEDT+.strlen("UNTAR"))
		;lda	#>(BUFEDT+.strlen("UNTAR"))

		; Entrée avec YA = Adresse premier argument

	getopt:
		jsr	sopt
		.asciiz "FVTXH"
		bcs	error

		cpx	#$00
		;beq	error
		bne	help
		jsr	cmnd_version
		prints	"missing arguments"
		crlf
		rts

	help:
		; -H?
		cpx	#$08
		bne	file
		jmp	cmnd_help

	file:
		; -F?
		cpx	#$80
		bcc	error_no_filename

		jsr	getfname
		bcs	error

	list:
		; -T?
		txa
		and	#$20
		beq	extract

		jsr	cmnd_list
		bcc	end
		bcs	error

	extract:
		txa
		and	#$10
		beq	unknown_option

		jsr	cmnd_extract
		bcc	end
		bcs	error

	unknown_option:
		lda	#e15
		.byte	$2c

	error_no_filename:
		lda #e12
		sec

	error:
		jsr ermes
	end:
		crlf
		rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "cmnd/version.s"

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "cmnd/help.s"

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "cmnd/list.s"

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "cmnd/extract.s"

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "utils/archive.s"

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "utils/bcd.s"

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "utils/strbin.s"

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "utils/error.s"

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "utils/fcntl.s"

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.include "utils/ch376.s"

;================================================================================
;
;================================================================================
;.segment "CODE"
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
.proc getfname
	; AY : adresse du paramètre suivant
	; cbp:   ''          ''
	;sty dskname
	;sta dskname+1

	ldy #$ff
  loop:
	iny
	lda (cbp),y
	sta fname,y
	beq endloop
	cmp #$0d
	beq endloop
	cmp #' '
	bne loop

  endloop:
	cpy #00
	beq error_no_filename

	; Termine la chaîne par un nul
;	cmp #$00
;	beq ajuste

	lda #$00
	;sta (cbp),y
	sta fname,y
	;iny

	; Ajuste cbp
;  ajuste:
;	clc
;	tya
;	adc cbp
;	sta cbp
;	bcc skip
;	inc cbp+1
;
;  skip:
;	clc
	jsr calposp
	rts

  error_no_filename:
	lda #e12
	sec
	rts
.endproc

;================================================================================
;
;================================================================================

