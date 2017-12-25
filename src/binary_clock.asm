.include "binary_clock.inc"

/********************************************************************************
 *      R A M
 *******************************************************************************/
.DSEG
hours:     .byte 1
minutes:   .byte 1
seconds:   .byte 1


/********************************************************************************
 *      F L A S H
 *******************************************************************************/
.CSEG
	/* Interrupt vectors table */
	.org	$000	; RESET External Pin, Power-on Reset, Brown-out Reset, Watchdog Reset, and JTAG AVR Reset
		rjmp reset
	.org	$002 	; INT0 External Interrupt Request 0
		reti
	.org	$004	; INT1 External Interrupt Request 1
		reti
	.org	$006	; INT2 External Interrupt Request 2
		reti
	.org	$008	; TIMER2 COMP Timer/Counter2 Compare Match
		reti
	.org	$00A	; TIMER2 OVF Timer/Counter2 Overflow
		rjmp timer2_overflow_isr
	.org	$00C	; TIMER1 CAPT Timer/Counter1 Capture Event
		reti
	.org	$00E	; TIMER1 COMPA Timer/Counter1 Compare Match A
		reti
	.org	$010	; TIMER1 COMPB Timer/Counter1 Compare Match B
		reti
	.org	$012	; TIMER1 OVF Timer/Counter1 Overflow
		reti
	.org	$014	; TIMER0 COMP Timer/Counter0 Compare Match
		reti
	.org	$016	; TIMER0 OVF Timer/Counter0 Overflow
		reti
	.org	$018	; SPI, STC Serial Transfer Complete
		reti
	.org	$01A	; USART, RXC USART, Rx Complete
		reti
	.org	$01C	; USART, UDRE USART Data Register Empty
		reti
	.org	$01E	; USART, TXC USART, Tx Complete
		reti
	.org	$020	; ADC ADC Conversion Complete
		reti
	.org	$022	; EE_RDY EEPROM Ready
		reti
	.org	$024	; ANA_COMP Analog Comparator
		reti
	.org	$026	; TWI Two-wire Serial Interface
		reti
	.org	$028	; SPM_RDY Store Program Memory Ready
		reti

; -------------------------------------------------------------------------------
/* Startup initialization */	
reset:
	; Stack pointer initialization
	ldi TMPREG, Low(RAMEND)
	out SPL, TMPREG 
	ldi TMPREG, High(RAMEND)
	out SPH, TMPREG

	cli ; Disable interrupts


	/*
	 * Timer0 configuration. It's used for delays
	 */
	ldi TMPREG, (0 << CS02) | (1 << CS01) | (0 << CS00)
	out TCCR0, TMPREG

	/*
	 * Timer/Counter2 configuration.
	 * Watch quartz is connected to TOSC1 and TOSC2 pins, which is 
	 * external clock input for Timer/Counter2. 
	 */
    ; Timer/Counter2 Overflow Interrupt Enable
	SETB TIMSK, TOIE2, TMPREG
	
	/*
	 * Configure prescaler to 128 (1 overflow interrupt per second) by
     * setting Timer2 clock select (CS2) bits to 101.
	 */
	ldi TMPREG, (1 << CS22) | (0 << CS21) | (1 << CS20)
	out TCCR2, TMPREG

	; Configure Timer2 to use a external crystal oscillator.
	SETB ASSR, AS2, TMPREG	

	/* Initialize clock */
	rcall startup_clock_init

	/* Initialize required I/O ports for LEDs */
	; Configure ports to output mode
	ldi TMPREG, 0xFF	
	out DDRA, TMPREG
	SETB DDRC, CCOL5, TMPREG
	SETB DDRC, CCOL6, TMPREG 
	rcall clock_ports_reset

	/* Initialize I/O ports for buttons */
	; Configure ports as PullUp I/O 
	SETB PORTC, BTN_STOP, TMPREG
	SETB PORTC, BTN_SWITCH, TMPREG
	SETB PORTC, BTN_SET, TMPREG
		
	sei ; Enable interrupts

	; Start program
	rjmp main

; -------------------------------------------------------------------------------
startup_clock_init:

	/* Reset clock status register */
	ldi CLK_STATUS, 0x00

	/* Restore time from EEEPROM */
	; Restore hours
	ldi EADDRL, low(eHours)
	ldi EADDRH, high(eHours)
	rcall eread_proc
	sts hours, EDATA
	cpi EDATA, 24 ; Max hours
	brlo restore_minutes
	; Set hours = 0 if restored valus is not correct ( >= 24)
	ldi TMPREG, 0x00
	sts hours, TMPREG
	
	; Restore minutes
	restore_minutes:
	ldi EADDRL, low(eMinutes)
	ldi EADDRH, high(eMinutes)
	rcall eread_proc
	sts minutes, EDATA
	cpi EDATA, 60 ; Max minutes
	brlo restore_seconds
	; Set minutes = 0 if restored valus is not correct ( >= 60)
	ldi TMPREG, 0x00
	sts minutes, TMPREG

	; Restore seconds
	restore_seconds:
	ldi EADDRL, low(eSeconds)
	ldi EADDRH, high(eSeconds)
	rcall eread_proc
	sts seconds, EDATA
	brlo continue_init
	; Set seconds = 0 if restored valus is not correct ( >= 60)
	ldi TMPREG, 0x00
	sts seconds, TMPREG
	continue_init:

	/* Set clock status to active */	
	ori CLK_STATUS, 1 << CLK_ACTIVE

	/* Start displaying from seconds */
	ldi CDISP_STATUS, 1 << CDISP_SEC_LOW

	/* Start time set from seconds */
	ori CLK_STATUS, 1 << CLK_SET_SECONDS

	ret

; -------------------------------------------------------------------------------
clock_ports_reset:
    ; Rows to GND
	CLRB PORTA, CROW1, TMPREG
	CLRB PORTA, CROW2, TMPREG
	CLRB PORTA, CROW3, TMPREG
	CLRB PORTA, CROW4, TMPREG


	; Columns to VCC
	SETB PORTA, CCOL1, TMPREG
	SETB PORTA, CCOL2, TMPREG
	SETB PORTA, CCOL3, TMPREG
	SETB PORTA, CCOL4, TMPREG
	SETB PORTC, CCOL5, TMPREG
	SETB PORTC, CCOL6, TMPREG
	ret

; -------------------------------------------------------------------------------
; Read from EEPROM
eread_proc:	
	sbic eecr, eewe
	rjmp eread_proc
	out EEARL, EADDRL
	out EEARH, EADDRH
	sbi EECR, EERE
	in EDATA, EEDR
	ret

; -------------------------------------------------------------------------------
; Write to EEPROM
ewrite_proc:	
	sbic eecr, eewe
	rjmp ewrite_proc
	cli
	out EEARL, EADDRL
	out EEARH, EADDRH
	out EEDR, EDATA
	sbi EECR, EEMWE
	sbi EECR, EEWE
	sei
	ret

; -------------------------------------------------------------------------------
/* 
 * Splits time value stored in ATIME on two didgits stored in HTIME and LTIME.
 * For example, if ATIME = 37 then HTIME will be = 3 and LTIME = 7
 */
time_split:
	ldi HTIME, 0x00
	ldi LTIME, 0x00	

	time_split_loop:
	cpi PPARAM, 0x0A
	brlo time_split_return
	subi PPARAM, 0x0A
	inc HTIME
	rjmp time_split_loop

	time_split_return:
	mov LTIME, PPARAM
	ret

; -------------------------------------------------------------------------------
set_row:
	sbrc PPARAM, 0
	SETB PORTA, CROW4, TMPREG1
	sbrc PPARAM, 1
	SETB PORTA, CROW3, TMPREG1
	sbrc PPARAM, 2
	SETB PORTA, CROW2, TMPREG1
	sbrc PPARAM, 3
	SETB PORTA, CROW1, TMPREG1
	ret

; -------------------------------------------------------------------------------
button_stop_pressed:
	; If button is already pressed - do nothing
	sbrc CLK_STATUS, BTN_STOP_PRESSED
	ret

	; Remember that stop button pressed
	ori CLK_STATUS, 1 << BTN_STOP_PRESSED

	sbrs CLK_STATUS, CLK_ACTIVE
	rjmp activate_and_return

	/* Deactivate clock and save time to EEPROM */
	; Deactivate
	andi CLK_STATUS, ~(1 << CLK_ACTIVE)

	; Save to EEPROM
	; Save hours
	ldi EADDRL, low(eHours)
	ldi EADDRH, high(eHours)
	lds EDATA, hours
	rcall ewrite_proc

	; Save minutes
	ldi EADDRL, low(eMinutes)
	ldi EADDRH, high(eMinutes)
	lds EDATA, minutes
	rcall ewrite_proc

	; Save seconds
	ldi EADDRL, low(eSeconds)
	ldi EADDRH, high(eSeconds)
	lds EDATA, seconds
	rcall ewrite_proc
	ret

	/* Activate clock */
	activate_and_return:
	ori CLK_STATUS, 1 << CLK_ACTIVE
	ret

; -------------------------------------------------------------------------------
button_set_pressed:
	; If button is already pressed - do nothing
	sbrc CLK_STATUS, BTN_SET_PRESSED
	ret

	; Remember that set button is pressed
	ori CLK_STATUS, 1 << BTN_SET_PRESSED

	; If clock is active - do nothing
	sbrc CLK_STATUS, CLK_ACTIVE
	ret

	sbrc CLK_STATUS, CLK_SET_SECONDS
	rjmp set_seconds
	sbrc CLK_STATUS, CLK_SET_MINUTES
	rjmp set_minutes
	sbrc CLK_STATUS, CLK_SET_HOURS
	rjmp set_hours
	ret

	set_seconds:
	cli
	lds TMPREG, seconds
	inc TMPREG
	cpi TMPREG, 60 ; Max seconds
	brlo set_seconds_save
	; Set seconds = 0 
	ldi TMPREG, 0x00
	set_seconds_save:
	sts seconds, TMPREG
	rjmp button_set_pressed_finish

	set_minutes:
	cli
	lds TMPREG, minutes
	inc TMPREG
	cpi TMPREG, 60 ; Max minutes
	brlo set_minutes_save
	; Set minutes = 0 
	ldi TMPREG, 0x00
	set_minutes_save:
	sts minutes, TMPREG
	rjmp button_set_pressed_finish

	set_hours:
	cli
	lds TMPREG, hours
	inc TMPREG
	cpi TMPREG, 24 ; Max hours
	brlo set_hours_save
	; Set hours = 0 
	ldi TMPREG, 0x00
	set_hours_save:
	sts hours, TMPREG
	rjmp button_set_pressed_finish	

	button_set_pressed_finish:
	sei ;Enable interrupts
	ret

; -------------------------------------------------------------------------------
button_switch_pressed:
	; If button is already pressed - do nothing
	sbrc CLK_STATUS, BTN_SWITCH_PRESSED
	ret

	; Remember that switch button is pressed
	ori CLK_STATUS, 1 << BTN_SWITCH_PRESSED

	; If clock is active - do nothing
	sbrc CLK_STATUS, CLK_ACTIVE
	ret

	sbrc CLK_STATUS, CLK_SET_SECONDS
	rjmp switch_to_minutes
	sbrc CLK_STATUS, CLK_SET_MINUTES
	rjmp switch_to_hours
	sbrc CLK_STATUS, CLK_SET_HOURS
	rjmp switch_to_seconds
	ret

	switch_to_minutes:
	andi CLK_STATUS, ~(1 << CLK_SET_SECONDS)
	ori CLK_STATUS, 1 << CLK_SET_MINUTES
	ret

	switch_to_hours:
	andi CLK_STATUS, ~(1 << CLK_SET_MINUTES)
	ori CLK_STATUS, 1 << CLK_SET_HOURS
	ret

	switch_to_seconds:
	andi CLK_STATUS, ~(1 << CLK_SET_HOURS)
	ori CLK_STATUS, 1 << CLK_SET_SECONDS
	ret

; -------------------------------------------------------------------------------
/* ISR */
timer2_overflow_isr:
	; At first check if clock is active
	sbrs CLK_STATUS, CLK_ACTIVE
	reti

	/* Seconds */ 
	; Increment seconds
	lds TMPREG1, seconds
	inc TMPREG1
	sts seconds, TMPREG1
	
	; Check for seconds overflow
	cpi TMPREG1, 60
	brlo timer2_isr_finish

	; Set seconds = 0
	ldi TMPREG1, 0x00
	sts seconds, TMPREG1

	/* Minutes */ 
	; Increment minutes
	lds TMPREG1, minutes
	inc TMPREG1
	sts minutes, TMPREG1

	; Check for minutes overflow
	cpi TMPREG1, 60
	brlo timer2_isr_finish
	
	; Set minutes = 0
	ldi TMPREG1, 0x00
	sts minutes, TMPREG1
	
	/* Hours */	
	; Increment hours
	lds TMPREG1, hours
	inc TMPREG1
	sts hours, TMPREG1

	; Check for hours overflow
	cpi TMPREG1, 24
	brlo timer2_isr_finish
	
	; Set hours = 0
	ldi TMPREG1, 0x00
	sts hours, TMPREG1

	timer2_isr_finish:
	reti

; -------------------------------------------------------------------------------
/* Main program loop */
main:
	
	/* Scan buttons */
	; Scan stop button
	sbis PINC, BTN_STOP
	rcall button_stop_pressed
	; Remember that stop button was released
	sbic PINC, BTN_STOP
	andi CLK_STATUS, ~(1 << BTN_STOP_PRESSED)

	; Scan set button
	sbis PINC, BTN_SET
	rcall button_set_pressed
	; Remember that set button was released
	sbic PINC, BTN_SET
	andi CLK_STATUS, ~(1 << BTN_SET_PRESSED)
	
	; Scan switch button
	sbis PINC, BTN_SWITCH
	rcall button_switch_pressed
	; Remember that switch button was released
	sbic PINC, BTN_SWITCH
	andi CLK_STATUS, ~(1 << BTN_SWITCH_PRESSED)

	/* Check if it's time to switch displaying column */
	in TMPREG, TCNT0
	cpi TMPREG, 0x01
	brsh display_time
	andi CLK_STATUS, ~(1 << CLK_DISP_SWITCHED)

	; 
	rjmp main


display_time:
    ; If already switched - return to main
	sbrc CLK_STATUS, CLK_DISP_SWITCHED
	rjmp main

	; Indicate that displaying column switched
	ori CLK_STATUS, 1 << CLK_DISP_SWITCHED

	/* Reset rows */
	in TMPREG, PORTA
	andi TMPREG, 0xF0
	out PORTA, TMPREG
	
	sbrc CDISP_STATUS, CDISP_SEC_LOW
	rjmp seconds_low_display

	sbrc CDISP_STATUS, CDISP_SEC_HIGH
	rjmp seconds_high_display

	sbrc CDISP_STATUS, CDISP_MIN_LOW
	rjmp minutes_low_display

	sbrc CDISP_STATUS, CDISP_MIN_HIGH
	rjmp minutes_high_display

	sbrc CDISP_STATUS, CDISP_HOUR_LOW
	rjmp hours_low_display

	sbrc CDISP_STATUS, CDISP_HOUR_HIGH
	rjmp hours_high_display

	; Start from beginning
	ldi CDISP_STATUS, 1

	/* Seconds */
	seconds_low_display:
	DISPLAY_COLUMN 5, 0, seconds, LTIME
	rjmp display_finish
	
	seconds_high_display:
	DISPLAY_COLUMN 0, 1, seconds, HTIME
	rjmp display_finish

	/* Minutes */
	minutes_low_display:
	DISPLAY_COLUMN 1, 2, minutes, LTIME
	rjmp display_finish

	minutes_high_display:
	DISPLAY_COLUMN 2, 3, minutes, HTIME
	rjmp display_finish

	/* Hours */
	hours_low_display:
	DISPLAY_COLUMN 3, 4, hours, LTIME
	rjmp display_finish

	hours_high_display:
	DISPLAY_COLUMN 4, 5, hours, HTIME
	rjmp display_finish	

	
	display_finish:	
	lsl CDISP_STATUS
	rjmp main


/********************************************************************************
 *      E E E P R O M
 *******************************************************************************/
.ESEG
eHours:     .db 0x01
eMinutes:   .db 0x02
eSeconds:   .db 0x03

