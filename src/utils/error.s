;===========================================================================
;		Gestion des erreurs
;===========================================================================

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
crlf1:
	BRK_KERNEL XCRLF
	rts

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
out1:
	BRK_KERNEL XWR0
	rts

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc prfild
	print fname, NOSAVE
	rts
.endproc

;----------------------------------------------------------------------
;
;----------------------------------------------------------------------
.proc prnamd
	print fname, NOSAVE
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
seter:
seter1:
	rts

