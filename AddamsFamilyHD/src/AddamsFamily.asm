;*---------------------------------------------------------------------------
; Program:	AddamsFamily.asm
; Contents:	Slave for "Addams Family" (c) 1992 Ocean
; Author:	Codetapper, DJ Mike
; Version:	2.0
; Requires:	WHDLoad 20+, 512k chip ram minimum
; Copyright:	Public Domain
; Language:	68000 Assembler
; Translator:	vasm
;---------------------------------------------------------------------------*

		INCDIR	"Include:"
		INCLUDE	whdload.i
		INCLUDE	whdmacros.i
		INCLUDE hardware/custom.i

MAINADDR	equ	$1000
EXPMEM_SIZE	equ	$c000

_base		SLAVE_HEADER			;ws_Security + ws_ID
		dc.w	20			;ws_Version
		dc.w	WHDLF_NoError|WHDLF_ClearMem
_BaseSize	dc.l	$80000			;ws_BaseMemSize (512k)
		dc.l	0
		dc.w	_Start-_base		;ws_GameLoader
		dc.w	_data-_base
		dc.w	0			;ws_DontCache
_keydebug	dc.b	0			;ws_keydebug
_keyexit	dc.b	$59			;ws_keyexit = F10
_expmem		dc.l	-EXPMEM_SIZE		;ws_ExpMem (optional)
		dc.w	_name-_base		;ws_name
		dc.w	_copy-_base		;ws_copy
		dc.w	_info-_base		;ws_info
		dc.w	0                       ;ws_kickname
		dc.l	0                       ;ws_kicksize
		dc.w	0                       ;ws_kickcrc
		dc.w	_config-_base		;ws_config
		dc.w	0			;ws_MemConfig
		
_name		dc.b	"The Addams Family",0
_copy		dc.b	"1992 Ocean",0
_info		dc.b	"Installed and fixed by Codetapper/Action! & DJ Mike",-1
	IFD	SLVDEBUG
		dc.b	"!!! WARNING !!! DEBUG BUILD !!! "
	ENDIF
		dc.b	"Version 2.0 "
		dc.b	"("
		INCBIN	"T:date"
		dc.b	")"
		; dc.b	-1,"Keys: Help - Toggle infinite lives "
		; dc.b	10,"       Del - Toggle infinite energy"
		; dc.b	10,"        F6 - Give Fezi-Copter      "
		; dc.b	-1,"Thanks to Chris Vella and Carlo Pirri"
		; dc.b	10,"for sending the originals!"
		dc.b	0
		even
_config		dc.b	"C1:X:Infinite Lives:0;"
		dc.b	"C1:X:Infinite Energy:1;"
		dc.b	0
		even

		BITDEF	C1,LIVES,0
		BITDEF	C1,ENERGY,1


; PL_SA $addr1,$addr2 - shortcut for "PL_S addr1,addr2-addr1"
PL_SA		MACRO
	IFNE	NARG-2
		FAIL	arguments "PL_SA addr1 addr2"
	ENDC
		PL_S	(\1),(\2-(\1))
		ENDM

; PL_PSSA $addr1,_Subroutine,$addr2 - shortcut for "PL_PS addr1,_Subroutine" then "PL_SA addr1+6,addr2"
PL_PSSA		MACRO
	IFNE	NARG-3
		FAIL	arguments "PL_PSSA addr1 routine addr2"
	ENDC
		PL_PS	(\1),(\2)
		PL_SA	((\1)+6),(\3)
		ENDM

STARTRASTERWAIT	MACRO
		IFNE	NARG-1
			FAIL	arguments "STARTRASTERWAIT lines"
		ENDC
		movem.l	d0-d1,-(sp)
		move.l	#(\1)-1,d1
		bra	_RasterWait
		ENDM
STARTRASTERWAIT_REG	MACRO
		IFNE	NARG-1
			FAIL	arguments "STARTRASTERWAIT_REG <dX>"
		ENDC
		movem.l	d0-d1,-(sp)
		move.w	\1,d1
		and.l	#$ffff,d1
		divu	#40,d1
		beq	_RasterWaitDone
		subq.l	#1,d1
		bra	_RasterWait
		ENDM
_RasterWait	
.int2w1		move.b	(_custom+vhposr),d0
.int2w2		cmp.b	(_custom+vhposr),d0
		beq	.int2w2
		dbf	d1,.int2w1
_RasterWaitDone	movem.l	(sp)+,d0-d1
		rts

; Push WHDL-modified registers onto stack (optionally add extra regs)
PUSHWHD		MACRO
	IFNE	NARG
		movem.l	d0-d1/a0-a2/\1,-(sp)
	ELSE
		movem.l	d0-d1/a0-a2,-(sp)
	ENDC
		ENDM

; Pop WHDL-modified registers from stack (optionally add extra regs)
POPWHD		MACRO
	IFNE	NARG
		movem.l	(sp)+,d0-d1/a0-a2/\1
	ELSE
		movem.l	(sp)+,d0-d1/a0-a2
	ENDC
		ENDM

; Push all registers onto stack (except a7)
PUSHALL		MACRO
		movem.l	d0-d7/a0-a6,-(sp)
		ENDM

; Pop all registers from stack (except a7)
POPALL		MACRO
		movem.l	(sp)+,d0-d7/a0-a6
		ENDM

;------------------------------------------------------------------------------

_Start		lea	(_resload,pc),a1
		move.l	a0,(a1)			;save for later
		move.l	a0,a2

		; Enable instruction cache by default, as now SMC is fixed this
		; is better for machines that support it
		move.l	#CACRF_EnableI,d0
		move.l	d0,d1
		jsr	resload_SetCACR(a2)

		lea     (_CustomTags,pc),a0
                jsr     (resload_Control,a2)

		; Clear palette
		lea	$dff180,a0
		moveq	#32-1,d0
.clr		move.w	#0,(a0)+
		dbf	d0,.clr

		; bsr	_SetupKeyboard

		bsr	_ResetStack
		bsr	_InitFastMem			; setup fast mem relocations

		; Load game exe
		lea	MAINADDR,a3

		lea	_MainExe(pc),a0
		move.l	a3,a1
		move.l	_resload(pc),a2
		jsr	resload_LoadFileDecrunch(a2)

		lea	_PL_Main(pc),a0			;Patch main executable
		move.l	a3,a1
		jsr	resload_Patch(a2)

		; Setup CIAB timer to use for delay after DMA off
                lea     _ciab,a0
                move.b  #$7f,ciaicr(a0)
DMADELAY=300 ; calibrated to give no extra delay on A500, but still fix audio on fast machines
                move.b  #DMADELAY&$ff,ciatalo(a0)
                move.b  #DMADELAY>>8,ciatahi(a0)
                move.b  #CIAICRF_SETCLR!CIAICRF_TA,ciaicr(a0)

		; set WHDLTAG_DBGADR_SET to start of game exe to make debugging easier
		move.l	#0,-(sp)			; TAG_DONE
		move.l	a3,-(sp)
		move.l	#WHDLTAG_DBGADR_SET,-(sp)
		move.l	sp,a0
		jsr	resload_Control(a2)
		add.l	#12,sp

		; set dummy coplist
		bsr	_WaitVB
		lea	$200,a0
		move.l	#$fffffffe,(a0)
		move.l	a0,$dff080
		; enable OS DMA (NOTE: sometimes may need DMAF_SPRITE too)
		move.w	#DMAF_SETCLR|DMAF_MASTER|DMAF_RASTER|DMAF_COPPER|DMAF_BLITTER,(_custom+dmacon)
		
		jmp	($70bc,a3)

FEZ_SETTING	EQU	MAINADDR+$2b8c			; player Fez state
SHOES_SETTING	EQU	MAINADDR+$2cbe
SHOES_SETTING_B	EQU	MAINADDR+$2cbc

BG_D7_LOOP_PTR	EQU	$80
BG_D6_LOOP_PTR	EQU	$82

_PL_Main	PL_START
		PL_S	$70c0,4				; don't change SP
		PL_PSS	$712c,_ResetStackGame,2		; reset SP
		PL_L	$70ce+2,$80			; only write vectors up to $80, not $400
		PL_L	$37d8,-1			; disable expmem check (not needed)
		PL_PSSA	$32ee,_LoadFile,$3312		; replace disk loader
		PL_PSS	$82ac,_Copylock,2		; Rob Northen Copylock
		PL_PS	$88a6,_Copylock
		PL_PS	$59e4,_Keyboard			; Detect quit key + cheat keys
		PL_L	$70e0,$7fffc			; Fix write overflowing 512k chip 
		PL_R	$1142c				; remove cache clear/CACR modify
		PL_P	$1119e,_EmptyDbfDynamicD7	; empty dbf
		PL_L	$6e8c,$1fe0000			; remove bad copperlist entry
		PL_L	$6e84,$1fe0000			; fix anti-Action Replay copperlist (breaks OS swap)
		PL_R	$3166				; disable disk access
		PL_PS	$5f80,_MusicDMAOff		; start timer after DMA off
		PL_PS	$633c,_FixAudioWait		; add missing wait to audio DMA
		PL_P	$26a86,_DecrunchA		; patch decrunch to use fast version
		PL_P	$26ac8,_DecrunchB		; patch decrunch to use fast version
		PL_P	$118b2,_UpdateGameBpl		; slightly faster bpl update
		; Game playfield clear performance fix
		; Original uses 2 blits to clear playfield but can do it in one
		; (which means we don't wait for 2nd blit once tile queues are built).
		; Size $5f words * $100 lines -> ((4 * $5f) << 6) + ($100 / 4)
		PL_W	$10212+2,0			; bltdmod 4c -> 0
		PL_W	$10228+2,((5*$13*4)<<6)		 ; bltsize $40 words width
		PL_R	$1023c				; skip 2nd blt clear
		; DMA performance fix - ddfstop is 4 bytes later than it needs to be!
		; (Game bitmap is $26 bytes wide but only $22 bytes is ever shown due to window).
		PL_W	$6edc+2,$b8			; fix ddfstop
		PL_W	$6ee8+2,$26-$22			; score bpl1mod
		PL_W	$6eec+2,$26-$22			; score bpl2mod
		PL_W	$6f24+2,$be-$22			; game bpl1mod
		PL_W	$6f28+2,$be-$22			; game bpl2mod
		; Blitter waits
		PL_PS	$7e28,_BlitWait_64_a6
		PL_PS	$10202,_BlitWait_74_a6
		PL_PS	$10ada,_BlitWait_64_a6
		PL_PS	$10b54,_BlitWait_64_a6
		PL_PS	$10c02,_BlitWait_64_a6
		PL_PS	$10d16,_BlitWait_64_a6
		PL_PS	$10dac,_BlitWait_64_a6
		PL_PS	$12234,_Blitwait_a6
		PL_PS	$103c8,_BlitWait_103c8
		PL_P	$12398,_BlitWait_SnoopFix	; fix missing blitwait + snoop error on 060
		; Fix self-modifying code in background generator.
		PL_L	$f690+4,BG_D6_LOOP_PTR		; store d6 loop count to temp addr
		PL_L	$f698+4,BG_D7_LOOP_PTR		; store d7 loop count to temp addr
		PL_L	$f6c4+4,BG_D7_LOOP_PTR		; store d7 loop count to temp addr
		PL_W	$f6d8,$3c38			; move.w #x,d6 -> move.w BG_D6_LOOP_PTR.w,d6
		PL_W	$f6d8+2,BG_D6_LOOP_PTR
		PL_W	$f6de,$3e38			; move.w #x,d7 -> move.w BG_D7_LOOP_PTR.w,d7
		PL_W	$f6de+2,BG_D7_LOOP_PTR
		PL_P	$1147a,_UpdateSpritePtrs	; replace sprite ptr update to fix SMC
		; Infinite lives
		PL_IFC1X C1B_LIVES
		PL_W	$d9d0+2,0
		PL_ENDIF
		PL_IFC1X C1B_ENERGY
		PL_W	$d94c,$600e
		PL_ENDIF
		PL_END

; MED player fails to wait after disabling audio DMA before playing new note.
; On A500 this seems to be OK because there is enough code to act as a delay.
; On fast machines, we setup a timer each time channel DMA is turned off,
; then 
_FixAudioWait	; If timer still active, we didn't wait long enough
.doTest		btst.b  #CIACRAB_START,_ciab+ciacra
		bne	.doTest
		move.w	d0,$dff096
		rts

_MusicDMAOff	move.w	d4,$dff096			; original code
		; start timer - check this during _FixAudioWait to see if sufficient delay
		move.b  #CIACRAF_LOAD!CIACRAF_RUNMODE!CIACRAF_START,_ciab+ciacra
		rts

_ResetStackGame	move.w	#$2700,SR			; original code
; Reset SP to end of whichever memory we're using.
; Mostly paranoia to avoid stack growing on repeat plays.
; d7/a0 safe
; => Z: no expmem
_ResetStack	move.l	(sp),a0				; a0 = return addr
		lea	$1000,sp
		; SP to fast mem
		move.l	_expmem(pc),d7
		beq	.noExpMem
		add.l	#EXPMEM_SIZE,d7
		move.l	d7,sp
.noExpMem	movem.l	a0,-(sp)
		rts

; Game routine @ $1147a (calling during lev3 int) updates all 8 sprite pointers.
; But uses SMC to modify instrs @ $114ae + $114f8 to alter sprite constants pushed to (X,a5).
; Rewrite this whole block of code to use d0-d7 for sprite pointers instead of (a5),
; pulling modified sprite constants from original instructions.
GOMEZSPR1_PTR	EQU	MAINADDR+$114ae+2
GOMEZSPR2_PTR	EQU	MAINADDR+$114b6+2
GOMEZSPR3_PTR	EQU	MAINADDR+$114be+2
GOMEZSPR4_PTR	EQU	MAINADDR+$114c6+2

CLIST_SPR	EQU	MAINADDR+$6e90
CLIST_BPLCON1	EQU	MAINADDR+$6f1e
CLIST_BPL1L	EQU	MAINADDR+$6f2e

; Replacement for sprite update routine in lev3 interrupt.
; Original uses SMC that alters values in move instructions.
; This version uses registers d0-d7 to hold sprite pointers, then updates copperlist.
_UpdateSpritePtrs
		; Gomez
		move.l	GOMEZSPR1_PTR,d4
		move.l	GOMEZSPR2_PTR,d5
		move.l	GOMEZSPR3_PTR,d6
		move.l	GOMEZSPR4_PTR,d7
		; Fez / right panel
		tst.w	MAINADDR+$8b2a
		bne	.hideRightPanel
		tst.w	MAINADDR+$2c04			; >=0 show right panel (pills)
		bmi	.showFez
.showRightPanel	move.l	#MAINADDR+$ff92,d2
		move.l	#MAINADDR+$1009a,d3
		bra	.doneRightPanel
.showFez	tst.w	FEZ_SETTING			; !0 shows Fez
		beq	.hideRightPanel
		move.l	MAINADDR+$114f8+2,d2
		move.l	MAINADDR+$11500+2,d3
		bra	.doneRightPanel
.hideRightPanel	move.l	#MAINADDR+$111a4,d2
		move.l	#MAINADDR+$111a4,d3
.doneRightPanel
		; Update sprite priority if Gomez is behind playfield
		tst.w	MAINADDR+$2b8e
		bne	.gomezBehindPF
		tst.w	MAINADDR+$c33c
		bne	.gomezBehindPF
.gomezFrontPF	move.w	#$24,($104,a6)
		bra	.doneGomezPF
.gomezBehindPF	move.w	#9,($104,a6)
.doneGomezPF

		; left panel
		tst.w	MAINADDR+$8b2a
		bne	.hideLeftPanel
		cmpi.l	#$4000a,MAINADDR+$2b36
		bne	.showLeftPanel
.hideLeftPanel	move.l	#MAINADDR+$111a4,d0		; empty sprite
		move.l	#MAINADDR+$111a4,d1		; empty sprite
		bra	.doneLeftPanel
.showLeftPanel	move.l	#MAINADDR+$fb5a,d0
		move.l	#MAINADDR+$fd76,d1
.doneLeftPanel
		; update copperlist sprite ptrs (using d0-d7 instead of a5)
		lea	CLIST_SPR,a0
		; sprite 1
		move.w	d0,(0*8+6,a0)
		swap	d0
		move.w	d0,(0*8+2,a0)
		; sprite 2
		move.w	d1,(1*8+6,a0)
		swap	d1
		move.w	d1,(1*8+2,a0)
		; sprite 3
		move.w	d2,(2*8+6,a0)
		swap	d2
		move.w	d2,(2*8+2,a0)
		; sprite 4
		move.w	d3,(3*8+6,a0)
		swap	d3
		move.w	d3,(3*8+2,a0)
		; sprite 5
		move.w	d4,(4*8+6,a0)
		swap	d4
		move.w	d4,(4*8+2,a0)
		; sprite 6
		move.w	d5,(5*8+6,a0)
		swap	d5
		move.w	d5,(5*8+2,a0)
		; sprite 7
		move.w	d6,(6*8+6,a0)
		swap	d6
		move.w	d6,(6*8+2,a0)
		; sprite 8
		move.w	d7,(7*8+6,a0)
		swap	d7
		move.w	d7,(7*8+2,a0)
		rts

; Slightly faster copperlist bpl update for OCS.
_UpdateGameBpl	
		lea	CLIST_BPLCON1,a0		; bplcon1
		move.w	d1,(a0)
		lea	CLIST_BPL1L,a0			; bitplanes 1-5
		REPT	5
		IFNE	REPTN
		addi.l	#$26,d0
		ENDIF
		move.w	d0,(a0)+			; bpl hi
		addq	#2,a0
		swap	d0
		move.w	d0,(a0)+			; bpl lo
		addq	#2,a0
		swap	d0
		ENDR
		rts

_InitFastMem	move.l	_expmem(pc),d0
		beq	.done
		move.l	d0,a0
		lea	_DecrunchTemp(pc),a1
		move.l	a0,(a1)
.done		rts

; ==============================================================================
; Extra blitter waits needed for fast CPUs		
_BlitWait_103c8	ori.l	#$9f00000,d0
		bra	_BlitWait
_BlitWait_64_a6	bsr	_BlitWait
		move.w	#0,($64,a6)
		rts
_BlitWait_74_a6	bsr	_BlitWait
		move.w	#0,($74,a6)
		rts
_Blitwait_a6	lea	$dff000,a6
_BlitWait	BLITWAIT
		rts

; fix move.w (sp)+,<custom reg> not allowed on snoop+060.
; Also fix missing blitwait!
_BlitWait_SnoopFix	
		bsr	_BlitWait
		move.w	(sp),($62,a6)
		addq.l	#2,sp
		move.l	a2,($50,a6)
		jmp	MAINADDR+$123a0

; Fixes empty DBF loop
_EmptyDbfDynamicD7
		movem.l	d0-d1,-(sp)
		move.l	d7,d1
		divu	#40,d1
		bra	_RasterWait

; Copylock is a traditional Rob Northen v2 but with a sneaky extra bit of code,
; that takes a set of values passed by the game (exe +$7094) and decrypts them,
; ultimately forming a stack of return addresses the code works through, which if
; incorrect will just cause the game to crash or fail to load necessary data.
; Stack on exit is following exe addresses:
; +$58ec (check copylock key)
; +$11932 (set a6=$dff000)
; +$73c8 (load agomez.spr)
; +$11744 (load apanel.spr)
; +$10cd6 (load aobjects.spr)
; +$fb52 (store decrypt key to +$2b32)
_Copylock	movem.l	MAINADDR+$7094,d0-d7/a0-a6
		movem.l	d0-a7,-(a7)
		move.l	#$3D742CF1,(a7)
		move.l	(a7),$60.w
		lea	8(a7),a0
		lea	$24(a7),a1
		move.l	#$8dadd684,d0		;Decryption ID
		moveq	#2,d2
		move.l	d0,d3
		lsl.l	#2,d0
.loop		move.l	(a0)+,d1
		sub.l   d0,d1
		move.l  d1,(a1)+
		add.l   d0,d0
		addq.b  #1,d2
		cmp.b   #8,d2
		bne.s   .loop
		move.l  d3,(a1)+
		movem.l (a7)+,d0-a0		; NOT a1-a7 as these are actual return values!
		move.w	#$2100,sr		; extra code after copylock call
		rts

_Keyboard	movem.l	d2,-(sp)
		cmp.b	_keyexit(pc),d2
		beq	_exit
		
		cmpi.b	#$5f,d2			; help
		bne	.notLives
		bsr	_FlashInfLives
		bsr	_ToggleInfLives
		bra	.done
.notLives
		cmpi.b	#$46,d2			; del
		bne	.notEnergy
		bsr	_FlashInfEner
		bsr	_ToggleInfEner
		bra	.done
.notEnergy		
		cmpi.b	#$55,d2			; f6
		bne	.notFez
		move.w	#$ffff,FEZ_SETTING
.notFez
		cmpi.b	#$56,d2			; f7
		bne	.notShoes
		cmpi.w	#3,SHOES_SETTING
		beq	.notShoes
		addq.w	#1,SHOES_SETTING
		subq.w	#1,SHOES_SETTING_B
.notShoes
.done		movem.l	(sp)+,d2
		move.b	#1,($c00,a1)		;Stolen code
		rts

_ToggleInfLives	eori.w	#1,MAINADDR+$d9d0+2	; move.w #1,d0 -> move.w #0,d0
		rts
_FlashInfLives	cmpi.w	#1,MAINADDR+$d9d0+2
		beq	_FlashCheatOn
_FlashCheatOff	move.w	#$f00,$dff180
		rts
_FlashCheatOn	move.w	#$f0,$dff180
		rts

_ToggleInfEner	eori.w	#($4a79^$600e),MAINADDR+$d94c	; tst.w _Energy -> bra
		rts
_FlashInfEner	cmpi.w	#$4a79,MAINADDR+$d94c
		beq	_FlashCheatOn
		bra	_FlashCheatOff

; a0 = filename
; a1 = dest addr
; => d1.l = file length
_LoadFile	PUSHWHD
		move.l	_resload(pc),a2
		jsr	resload_LoadFileDecrunch(a2)
		; need file length in game variable
		move.l	d0,MAINADDR+$37d0
		POPWHD
		rts

; Decruncher for game files.
; a0 = src data
; a1 = ?
; a2 = dest buffer
_DecrunchTemp	dc.l	$68000				; temp buffer used in decrunch
DECR_TEMP_SIZE	EQU	$8000

_DecrunchA	moveq	#0,d6
		movea.l	d6,a5
		move.l	(8,a0),d0
		lea	(12,a0),a0
		; By default a2 is set by game to scratch area for decrunch (needs $8000 bytes).
		; Originally this was a scratch area reserved by the game,
		; but can be set to the screen buffer to save space.
		; If expmem is enabled we can use that instead for faster decrunch.
		move.l	_DecrunchTemp(pc),a2
		movea.l	a2,a3
		move.w	#0,d1
lbC000146	move.b	#$ff,(a3)+
		move.b	d1,(a3)+
		move.w	#$ffff,(a3)+
		addq.w	#1,d1
		cmpi.w	#$100,d1
		blt.b	lbC000146
		move.w	#9,d1
		move.w	#$10,d6
		lea	(lbC000222,pc),a4
		lea	(lbC0001B6,pc),a6
		move.w	#$102,d7
		jsr	(a6)
		move.w	d5,d3
		jsr	(a4)
		move.w	d5,d4
		rts

_DecrunchB	move.l	_DecrunchTemp(pc),a2
		jsr	(a6)
		cmp.w	d7,d5
		bne.b	lbC000192
		move.w	d7,d3
		add.w	d3,d3
		add.w	d3,d3

		movem.w	d2/d4,(a2,d3.w)
		addq.w	#1,d7
		move.w	d5,d3
		jsr	(a4)
		move.w	d5,d4
		bra.b	lbC0001AC

lbC000192	move.w	d5,d3
		jsr	(a4)
		move.w	d7,d3
		cmpi.w	#$1fff,d3
		bgt.b	lbC0001AC
		addq.w	#1,d7
		add.w	d3,d3
		add.w	d3,d3
		movem.w	d2/d4,(a2,d3.w)
		move.w	d5,d4
lbC0001AC	subi.l	#1,d0
		bne.b	_DecrunchB
		rts

lbC0001B6	swap	d7
		addq.l	#1,a5
		cmpa.w	#$fe,a5
		bne.b	lbC000202
		lea	(lbC0001C8,pc),a6
		moveq	#10,d1
		bra.b	lbC000202

lbC0001C8	swap	d7
		addq.l	#1,a5
		cmpa.w	#$2fe,a5
		bne.b	lbC000202
		lea	(lbC0001DA,pc),a6
		moveq	#11,d1
		bra.b	lbC000202

lbC0001DA	swap	d7
		addq.l	#1,a5
		cmpa.w	#$6fe,a5
		bne.b	lbC000202
		lea	(lbC0001EC,pc),a6
		moveq	#12,d1
		bra.b	lbC000202

lbC0001EC	swap	d7
		addq.l	#1,a5
		cmpa.w	#$efe,a5
		bne.b	lbC000202
		lea	(lbC0001FE,pc),a6
		moveq	#13,d1
		bra.b	lbC000202

lbC0001FE	swap	d7
		addq.l	#1,a5
lbC000202	move.l	(a0),d5
		lsr.l	d6,d5
		move.w	#$10,d7
		sub.w	d1,d7
		lsr.w	d7,d5
		sub.w	d1,d6
		cmpi.w	#1,d6
		bge.w	lbC00021E
		addi.w	#$10,d6
		addq.l	#2,a0
lbC00021E	swap	d7
		rts

lbC000222	add.w	d3,d3
		add.w	d3,d3
		lea	(a2,d3.w),a3
		move.w	(a3)+,d2
		move.w	(a3),d3
		bmi.b	lbC000238
		move.b	d2,-(sp)
		jsr	(a4)
		move.b	(sp)+,(a1)+
		rts

lbC000238	move.b	d2,(a1)+
		rts

_WaitVB		waitvb
		rts
		
;-----
; General data and exit routines
_exit		pea	TDREASON_OK
		bra	_end
_WrongVer	pea	TDREASON_WRONGVER
		bra	_end
_debug		pea	TDREASON_DEBUG
_end		move.l	(_resload,pc),-(a7)
		add.l	#resload_Abort,(a7)
		rts


_resload	dc.l	0			;address of resident loader
_CustomTags	dc.l	WHDLTAG_CUSTOM1_GET	; trainers
		dc.b	0,0,0
_Trainers	dc.b	0
		dc.l	0			;TAG_DONE
_data		dc.b	"data",0
_MainExe	dc.b	"DM.PRG",0
		even


;		include	"whdload/keyboard.s"

