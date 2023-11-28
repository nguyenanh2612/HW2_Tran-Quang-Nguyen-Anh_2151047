;
; AssemblerApplication1.asm
;
; Created: 11/27/2023 12:32:21 PM
; Author : DELL
;


; Replace with your application code
;;;;;;;;;;;;;;;;;;;;;define lcd ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.equ   lcd = porta ; 
.equ   lcd_dr = ddra ;
.equ   rs     = 0
.equ   rw     = 1 
.equ   en     = 2 
;;;;;;;;;;;;;;;;;;;;; define spi ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.equ MOSI = 5
.equ MISO = 6
.equ SS	  = 4
.equ SCK  = 7
;;;;;;;;;;;;;;;;;;;;; program ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.org 0x0000
	rjmp reset_handler
.org 0x0002
	rjmp ISR_INT
.org 0x0040
;;;;;;;;;;;;;;;;; data table ;;;;;;;;;;;;;;;;;;;;;;;;;;
tab: .db '0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'
;;;;;;;;;;;;;;;; reset handler ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
reset_handler: 
	ldi r16, high (ramend) 
	out sph, r16 
	ldi r16, low (ramend) 
	out spl, r16
	 
	rcall port_init
	rcall set_up_lcd 
	rcall spi_init
	rcall UART0_INIT
	rcall inter_init 

	sei 
main: 
	rjmp main 
;;;;;;;;;;;;;;;; ISR INT ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ISR_INT: 
	cbi portc, 0 ;;;; master busy 
	cbi portb, SS ;;; start spi 
	nop 
	nop 
	nop 
	nop 
	rcall spi_trans
;;;;;;;;;;; take out the data from the table ;;;;;;;;;;;;;;;;;;;;
	ldi zh, high( tab << 1 )
	ldi zl, low( tab << 1 )
	add zl, r20 
	clr r20 
	adc zh, r20
	lpm r17, z 
;;;;;;;;;;; send to uart ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	mov r16, r17 
	rcall uart_sendchar
;;;;;;;;;;; sen to  lcd  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	rcall display_data
	sbi portc, 0
	reti
;;;;;;;;;;; uart send char ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
uart_sendchar: 
	push r17 
uart_senchar_wait: 
	lds r17, ucsr0a 
	sbrs r17, udre0
	rjmp uart_senchar_wait
	sts udr0, r16 
	pop r17 
	ret 
;;;;;;;;;;;;;;;; spi transfer ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_trans: 
	clr r17 
	out SPDR0, r17 
wait_trans:
	in r17, SPSR0 
	sbrs r17, SPIF0 
	rjmp wait_trans 
	sbi portb, SS
	in r20, SPDR0 
	ret 
	
		 
;;;;;;;;;;;;;;;; spi init ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
spi_init: 
	ldi r16, ( 1 << MOSI) | ( 1 << SCK ) | ( 1 << SS )
	out ddrb, r16 
	sbi portb, SS 
	ldi r16, ( 1<< SPE0) | ( 1 << MSTR0) | ( 1 << SPR00) 
	out SPCR0, r16
	ret   
;;;;;;;;;;;;;;;; uart init ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
UART0_INIT:
	LDI R16,0x00 
	STS UBRR0H,R16
	LDI R16,51 
	STS UBRR0L,R16
 ; Set frame format: 8 data bits, no parity, 1 stop bit
	ldi r16, (1 << UCSZ01) | (1 << UCSZ00)
	sts UCSR0C, r16
 ; Enable transmitter and receiver
	ldi r16, (1 << TXEN0) 
	sts UCSR0B, r16
	ret
;;;;;;;;;;;;;;;;port init ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
port_init: 
	cbi ddrd , 2 ;;;; input IRQ 
	sbi ddrc , 0 ;;;;; master busy output 
	sbi portc, 0 ;;;; master free (initial) 
	ret 
;;;;;;;;;;;;;;;; interrupt init ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
inter_init: 
	ldi r16,(1<<ISC01)
	sts EICRA,R16
	// INT0 enable, falling active
	ldi R16, (1<<INT0)
	out EIMSK, R16
	ret
;;;;;;;;;;;;;;;; lcd init   ;;;;;;;;;;;;;;;;;;;;
lcd_init: 
	cbi lcd, rs ; send command 
	mov r17, r18; 
	rcall out_lcd_8bit
	mov r17,r19 
	rcall out_lcd_8bit 
	ldi r16, 20
	rcall delay; wait for clear screen 
	mov r17, r20 
	rcall out_lcd_8bit 
	mov r17, r21 
	rcall out_lcd_8bit
	ret
;;;;;;;;;;;;;; start diplay data;;;;;;;;;;;;;;;;;;;;;;;;;;;;
display_data:
    cbi lcd, rs 
	ldi r17, 0x80 ; line 1, position 1 
	call out_lcd_8bit
	sbi lcd, rs
	lds r17, UDR0
	call out_lcd_8bit 
	ret 
;;;;;;;;;;;;;;;; lcd set_up ;;;;;;;;;;;;;;;;;;;;
set_up_lcd: 
	ldi r16, 0xff
	out lcd_dr, r16;  set port a is output 
	cbi lcd, rs ; rs =0
	cbi lcd, rw ; rw = 0
	cbi lcd, en ; en = 0
	ldi r16 , 250 
	rcall delay 
	ldi r16 , 250 
	rcall delay    ; wait for lcd power up 
	ldi r17, 0x20  ; command: 0x2  ; set cursor to the initial position 
	rcall out_lcd_4bit
	ldi r19, 0x01  ; clear the screen 
	ldi r20, 0x0f  ; display on, cursor off 
	ldi r21, 0x06  ; shift cursor to right 

	rcall lcd_init 
	ret 
;;;;;;;;;;;;;; send_command_4_bits_length;;;;;;;;;;;;;;;;;;;;
out_lcd_4bit: 
	out lcd, r17 
	sbi lcd, en
	cbi lcd, en
	ret
;;;;;;;;;;;;;; send command 8 bít length ;;;;;;;;;;;;;;;;;;;;;
out_lcd_8bit: 
	ldi r16, 8
	rcall delay; wait 4 . 10-4 s 
	in  r16 , lcd 
	andi r16, 1
	push r16
	push r17 
	andi r17, 0xf0
	or   r17,r16 
	rcall out_lcd_4bit 
	pop r17 
	pop r16 
	swap r17 
	andi r17, 0xf0 
	or   r17, r16 
	rcall out_lcd_4bit 
	ret 

;;;;;;;;;;;;; delay ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
delay:  
	mov r15, r16	; copy r16 1mc  
	ldi r16, 200	; r16 = 200 1mc 
loop: 
	mov r14 , r16   ; r14 = r16 1mc
loop1: 
	dec r14       ; decrease r14 1mc
	brne loop1    ; 2/1 mc 
	dec r15       ; decrease r15 1mc 
	brne loop     ; 2/1 mc 
	ret 	      ; 4mc 