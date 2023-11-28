;
; AssemblerApplication1.asm
;
; Created: 11/27/2023 11:57:24 AM
; Author : DELL
;


; Replace with your application code
.equ mosi = 5
.equ miso = 6
.equ sck  = 7
.equ ss	  = 4
.equ DDR_SPI = ddrb

.org 0x0000
	rjmp reset_handler
.org 0x0040 
reset_handler: 
	ldi r16, high(ramend) 
	out sph, r16 
	ldi r16, low(ramend) 
	out spl, r16
	call SPI_SlaveInit
	call port_init

main: 
	rcall keypad_scan 
	out portc, r23 
	cpi r23, 0xff 
	breq main 
wait_master: 
    sbis pind, 1 
	rjmp wait_master 
	rcall SPI_Trans
	rjmp main   

;;;;;;;;; SPI transmit ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SPI_Trans: 
	cbi portd,0 ; key pressed 
wait_transmit:
	sbic pinb , ss
	rjmp wait_transmit 
	out SPDR0, r23 
	sbi portd, 0 
	ret 
;;;;;;;;; port initial ;;;;;;;;;;;;;;;;;;;;;;;
port_init: 
	sbi ddrd, 0; output IRQ
	sbi portd, 0 ; 1 mean no key_press 
	cbi ddrd, 1 ; master_busy signal  
	ldi r16, 0xff
	out ddrc , r16
	ret 
;;;;;;;;;slave set_up ;;;;;;;;;;;;;;;;;;;;;;;;;;;
SPI_SlaveInit:
; Set MISO output, all others input
	ldi r17,(1 << miso)
	out DDR_SPI,r17
; Enable SPI
	ldi r17,(1<<SPE0)|(1<<SPR00)
	out SPCR0,r17
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ATmega324PA keypad scan function; Scans a 4x4 keypad connected to PORTA;C3-C0 connect to PA3-PA0
;R3-R0 connect to PA7-PA4
; Returns the key value (0-15) or 0xFF if no key is pressed
keypad_scan:
	ldi r20, 0b00001111 ; set upper 4 bits of PORTD as input with pull-up, lower 4 bits as output
	out DDRA, r20
	ldi r20, 0b11111111 ; enable pull up resistor
	out PORTA, r20
	ldi r22, 0b11110111 ; initial col mask
	ldi r23, 0 ; initial pressed row value
	ldi r24,3 ;scanning col index
keypad_scan_loop: 
	out porta, r22
	nop 
	sbic pina, 4 
	rjmp keypad_scan_check_col2
	rjmp keypad_scan_found
keypad_scan_check_col2: 
	sbic pina, 5 
	rjmp keypad_scan_check_col3 
	ldi r23, 1 
	rjmp keypad_scan_found
keypad_scan_check_col3: 
	sbic pina, 6 
	rjmp keypad_scan_check_col4 
	ldi r23, 2 
	rjmp keypad_scan_found 
keypad_scan_check_col4: 
	sbic pina, 7 
	rjmp keypad_scan_next_row
	ldi r23, 3 
	rjmp keypad_scan_found 

keypad_scan_next_row: 
	cpi r24, 0 
	breq keypad_scan_not_found 
	ror r22
	dec r24 
	rjmp keypad_scan_loop 

keypad_scan_found: 
	lsl r23
	lsl r23 
	add r23, r24 
	ret 

keypad_scan_not_found: 
	ldi r23, 0xff 
	ret 