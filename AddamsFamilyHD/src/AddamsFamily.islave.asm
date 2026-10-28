; Addams Family imager by DJ Mike
; Extracts real files from game disk, and decrypts them

		incdir	Includes:
		include	RawDIC.i


		SLAVE_HEADER
		dc.b	5				; Slave version
		dc.b	0				; Slave flags
		dc.l	.disk1				; Pointer to the first disk structure
		dc.l	.text				; Pointer to the text displayed in the imager window


		dc.b	"$VER: "
.text		dc.b	"Addams Family imager v1.0",10
		dc.b	"by DJ Mike "
		dc.b	"(14.10.2026)",0
		dc.b	0
		cnop	0,4

.disk1		dc.l	0				; Pointer to next disk structure
		dc.w	1				; Disk structure version
		dc.w	0				; Disk flags
		dc.l	_TrackList			; List of tracks which contain data
		dc.l	0				; UNUSED, ALWAYS SET TO 0!
		dc.l	FL_NULL	;_FileList			; List of files to be saved
		dc.l	0				; Table of certain tracks with CRC values
		dc.l	0				; Alternative disk structure, if CRC failed
		dc.l	0				; Called before a disk is read
		dc.l	_SaveFiles			; Called after a disk has been read

TRACKSIZE	equ	$1600

_TrackList	
		TLENTRY	0,159,TRACKSIZE,SYNC_STD,DMFM_STD
		TLEND

_FileList	FLENTRY	_filetable,$2c00,$1800
		FLEND

_filetable	dc.b	"filetable",0
		even

; a1 = disk image data
; a5 = rawdic base
; d0 = disk number
; => d0.l = errorcode
_SaveFiles	lea	($2c00,a1),a0
		; decrypt filetable
		addq	#2,a0
		move.w	#$12b,d7			; number of entries
.nextFile	moveq	#11,d6				; num characters in filename
.nextChar	move.b	(a0),d1
		ror.b	#4,d1
		move.b	d1,(a0)+
		dbra	d6,.nextChar
		eori.l	#$4e4e4e4e,(a0)+
		eori.l	#$4e4e4e4e,(a0)+
		cmp.l	#$ffffffff,(-20,a0)
		beq	.done
		; save file
		move.l	a0,a4
		move.l	-(a0),d1			; d1 = length
		move.l	-(a0),d0			; d0 = offset
		add.l	#$4400,d0			; correct offset
		lea	(-12,a0),a0			; a0 = filename
		; decrypt (unless DM.PRG)
		cmp.l	#'DM.P',(a0)
		beq	.noDecrypt
		move.l	d1,d6
		subq.l	#4,d6
		move.l	a1,a2
		add.l	d0,a2				; a2 = file in disk image
		moveq	#0,d2				; d2 = checksum
.decrypt	move.b	(a2),d3				; d3 = next encrypted byte
		eor.b	d6,d3
		eor.b	d3,d2				; csum ^= unencrypted byte
		ror.l	#1,d2
		move.b	d3,(a2)+
		subq.l	#1,d6
		bne	.decrypt
		tst.l	(a2)
		beq	_CRCError
		cmp.l	(a2),d2
		bne	_CRCError
		subq.l	#4,d1				; reduce size by 4 to omit checksum
.noDecrypt
		jsr	rawdic_SaveDiskFile(a5)
		move.l	a4,a0
		dbra	d7,.nextFile
.done
		moveq	 #IERR_OK,d0
		rts

_BytesToAscii	;d0 = input bytes - same on return
		;a0 = filename pointer - has new name on return
		movem.l	d0/d5-d6,-(sp)
		moveq	#3,d5			;produce filename - add 2 per extra byte
.nl0		move.b	d0,d6			;get next 4 bits of value
		and.b	#$0f,d6
		add.b	#'0',d6
		cmp.b	#'9',d6			;check if greater than '9'
		ble	.ns0
		add.b	#('a'-'9'-1),d6		;use 'A'-'F' instead
.ns0		move.b	d6,(6,a0,d5)		;this assumes 'disk1_' start for filename
		lsr.l	#4,d0
		dbra	d5,.nl0
		movem.l	(sp)+,d0/d5-d6
		rts
		
_SaveFilename	dc.b	"disk1_0000",0
		even

_CRCError	moveq	#IERR_CRCFAIL,d0
		rts

