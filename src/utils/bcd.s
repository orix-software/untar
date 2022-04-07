;----------------------------------------------------------------------
;
; Entrée:
;	LSB-LSB+3: Valeur binaire
;
; Sortie:
;	TR0-TR4: Valeur BCD (LSB en premier)
; Variables:
;	Modifiées:
;		-
;	Utilisées:
;		-
; Sous-routines:
;	-
;----------------------------------------------------------------------
.proc bin2bcd
		ldx	#$04          ; Clear BCD accumulator
		lda	#$00

	BRM:
		sta	TR0,x        ; Zeros into BCD accumulator
		dex
		bpl	BRM

		sed               ; Decimal mode for add.

		ldy	#$20          ; Y has number of bits to be converted

	BRN:
		asl	LSB           ; Rotate binary number into carry
		rol	NLSB
		rol	NMSB
		rol	MSB

	;-------
	; Pour MSB en premier dans BCDA
	;    ldx #$05
	;
	;BRO:
	;    lda BCDA-1,X
	;    adc BCDA-1,X
	;    sta BCDA-1,x
	;    dex
	;    bne BRO

	; Pour LSB en premier dans BCDA

	BCDA := (TR0-$FB) & $ff ; = $0C

		ldx	#$fb          ; X will control a five byte addition.

	BRO:
		lda	BCDA,x    ; Get least-signficant byte of the BCD accumulator
		adc	BCDA,x    ; Add it to itself, then store.
		sta	BCDA,x
		inx               ; Repeat until five byte have been added
		bne	BRO

		dey               ; et another bit rom the binary number.
		bne	BRN

		cld               ; Back to binary mode.
		rts               ; And back to the program.

.endproc

;----------------------------------------------------------------------
;
; Entrée:
;	YA: Adresse de la chaine
;	TR0-TR4: Valeur BCD (LSB en premier)
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
.proc bcd2str
		sta	RES
		sty	RES+1

		ldx	#$04          ; Nombre d'octets à convertir
		ldy	#$00
	;	clc

	loop:
		; BCDA: LSB en premier
		lda	TR0,X
		pha
		; and #$f0
		lsr
		lsr
		lsr
		lsr
		clc
		adc	#'0'
		sta	(RES),Y

		pla
		and	#$0f
		adc	#'0'
		iny
		sta	(RES),y

		iny
		dex
		bpl	loop

		lda	#$00
		sta	(RES),y
		rts

.endproc

