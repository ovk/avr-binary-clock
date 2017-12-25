.include "m32def.inc"	; AT Mega32 definitions

/* Temp register */
.def TMPREG  = R16
.def TMPREG1 = R17

/* Registers for time split proc */
.def HTIME = R18
.def LTIME = R19

/* To pass in procedures */
.def PPARAM = R20

/* Clock status */
.def CLK_STATUS = R21

.equ CLK_ACTIVE 		= 0
.equ BTN_STOP_PRESSED 	= 1
.equ BTN_SET_PRESSED 	= 2
.equ BTN_SWITCH_PRESSED = 3
.equ CLK_SET_SECONDS 	= 4
.equ CLK_SET_MINUTES 	= 5
.equ CLK_SET_HOURS 		= 6
.equ CLK_DISP_SWITCHED	= 7


/* Ports connected to LEDs */
.equ CROW1 = 0 ; PA0
.equ CROW2 = 1 ; PA1
.equ CROW3 = 2 ; PA2
.equ CROW4 = 3 ; PA3

.equ CCOL1 = 4 ; PA4
.equ CCOL2 = 5 ; PA5
.equ CCOL3 = 6 ; PA6
.equ CCOL4 = 7 ; PA7
.equ CCOL5 = 5 ; PC5
.equ CCOL6 = 4 ; PC4

/* Buttons */
.equ BTN_STOP 	= 1 ; PC1
.equ BTN_SWITCH = 2 ; PC2
.equ BTN_SET 	= 3 ; PC3

/* To store clock display status */
.def CDISP_STATUS 	= R22
.equ CDISP_SEC_LOW 	= 0
.equ CDISP_SEC_HIGH = 1
.equ CDISP_MIN_LOW 	= 2
.equ CDISP_MIN_HIGH = 3
.equ CDISP_HOUR_LOW = 4
.equ CDISP_HOUR_HIGH = 5

/* Registers for EEPROM access */
.def EADDRL = R23
.def EADDRH = R24
.def EDATA  = R25

/*
 * Set bit using temporary register
 * SETB TARGET_REGISTER, BIT_NUMBER, TEMP_REGISTER (R16-R31)
 */
.MACRO	SETB
	.if @0 < 0x20	; Low IO
		sbi	@0, @1	; The CBI and SBI instructions work with registers $00 to $1F only
	.else
		.if @0 < 0x40			; High IO
			in @2, @0			; Save to temp register
			ori @2, (1 << @1)	; Set bit
			out @0, @2			; Copy to IO register
		.else					; Memory
			lds @2, @0			; Load from SRAM to register
			ori @2, (1 << @1)	; Set bit
			sts @0, @2			; Copy to SRAM
		.endif
	.endif
.ENDM

/*
 * Clear bit using temporary register
 * CLRB TARGET_REGISTER, BIT_NUMBER, TEMP_REGISTER (R16-R31)
 */
.MACRO	CLRB
	.if @0 < 0x20		; Low IO
		cbi @0,@1
	.else
		.if @0<0x40		; High IO
			in @2, @0
			andi @2, ~(1 << @1)
			out @0, @2
		.else			; Memory
			lds @2, @0
			andi @2, ~(1 << @1)
			sts @0, @2
		.endif
	.endif
.ENDM

/*
 * Invert bit using register
 * INVB TARGET_REGISTER, BIT_NUMBER, TEMP_REGISTER1 (R16-R31), TEMP_REGISTER2 (R16-R31)
 */
.MACRO	INVB
	.if	@0 < 0x40	; IO
		in	@2, @0
		ldi	@3, (1 << @1)
		eor	@3, @2
		out	@0, @3
	.else			; SRAM
		lds	@2, @0
		ldi	@3, (1 << @1)
		eor	@2, @3
		sts	@0, @2
	.endif
.ENDM

/*
 * 
 */
.MACRO COLUMN_TO_GND
	.if @0 == 0
		CLRB PORTA, CCOL1, TMPREG
	.endif
	.if @0 == 1
		CLRB PORTA, CCOL2, TMPREG
	.endif
	.if @0 == 2
		CLRB PORTA, CCOL3, TMPREG
	.endif
	.if @0 == 3
		CLRB PORTA, CCOL4, TMPREG
	.endif
	.if @0 == 4
		CLRB PORTC, CCOL5, TMPREG
	.endif
	.if @0 == 5
		CLRB PORTC, CCOL6, TMPREG
	.endif
.ENDM

/*
 * 
 */
.MACRO COLUMN_TO_VCC
	.if @0 == 0
		SETB PORTA, CCOL1, TMPREG
	.endif
	.if @0 == 1
		SETB PORTA, CCOL2, TMPREG
	.endif
	.if @0 == 2
		SETB PORTA, CCOL3, TMPREG
	.endif
	.if @0 == 3
		SETB PORTA, CCOL4, TMPREG
	.endif
	.if @0 == 4
		SETB PORTC, CCOL5, TMPREG
	.endif
	.if @0 == 5
		SETB PORTC, CCOL6, TMPREG
	.endif
.ENDM

/*
 *
 */
.MACRO DISPLAY_COLUMN
	cli
	COLUMN_TO_VCC @0 ; Which column to deactivate (displayed previous)
	COLUMN_TO_GND @1 ; Which column to activate (current)
	
	lds PPARAM, @2 ; What will be displayed: seconds/minutes/hours
	rcall time_split

	mov PPARAM, @3 ; Low or high part: LTIME/HITIME
	rcall set_row

	sei
.ENDM

