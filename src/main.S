.syntax unified
.global main
@ GPIOTE Constants
.set GPIOTE_EVENTS_IN0, 0x40006100
.set GPIOTE_EVENTS_IN1, 0x40006104
.set GPIOTE_INTENSET, 0x40006304
.set GPIOTE_CONFIG0, 0x40006510
.set GPIOTE_CONFIG1, 0x40006514

@ NVIC Constants
.set NVIC_ISER0, 0xE000E100

@ SYST Constants
.set SYST_CSR, 0xE000E010
.set SYST_RVR, 0xE000E014

.type main, %function
main:
  @ init leds
  bl init_leds
  @ enable systicker
  ldr r0, =SYST_CSR
  ldr r1, [r0]
  ldr r2, =0b111
  orr r1, r2
  str r1, [r0]
  @ set reload value
  ldr r0, =SYST_RVR
  ldr r1, [r0]
  ldr r2, =16000000
  str r2, [r0]

  @ configure GPIOTE_CONFIG[0] combine with button A
  ldr r0, =GPIOTE_CONFIG0
  ldr r1, =(1 | 14 << 8 | 0 << 13 | 1 << 16) @ |
  str r1, [r0]
  @ configure GPIOTE_CONFIG[1] combine with button B
  ldr r0, =GPIOTE_CONFIG1
  ldr r1, =(1 | 23 << 8 | 0 << 13 | 1 << 16) @ |
  str r1, [r0]

  @ enable Interrupts for GPIOTE[0] (id = 6)
  ldr r0, =GPIOTE_INTENSET
  @ enable IN0 and IN1
  ldr r1, =0b11
  str r1, [r0]

  @ 3: enable GPIOTE (interrupt #6 = NVIC_GPIOTE_ID) in NVIC_ISER0
  @ NVIC_ISER0: B3.4.4 in ARMv7-M Reference Manual
  ldr r0, =NVIC_ISER0
  ldr r1, =(1 << 6) @ set the 6th bit since NVIC_GPIOTE_ID = 6
  str r1, [r0]

  @ set systick priority, systick > GPIOTE
  ldr r0, =0xE000ED20
  ldr r3, [r0]
  ldr r1, =0b1
  lsl r1, #29
  orr r1, r3
  str r1, [r0]
  @ set GPIOTE priority
  ldr r0, =0xE000E404
  ldr r3, [r0]
  ldr r1, =0b1
  lsl r1, #21
  orr r1, r3
  str r1, [r0]
  
  @ start the main loop
  b main_loop

.type main_loop, %function
main_loop:
  @ load the loop option to choose from different display status
  ldr r0, =loop_option
  @ choose which to display
  ldr r1, =loop_pointer
  ldr r1, [r1]
  @ load the address of display to pc to start the loop
  ldr r0, [r0, r1]
  mov pc, r0

.type word_loop, %function
word_loop:
  @ store the registers
  push {r0, r1, r2, r3, lr}
  @ load the "HELLO" display columns
  ldr r3, =hello_col
  @ load the pointer to start the display with
  @ it will increment by system time ticker
  ldr r2, =word_pointer
  ldr r2, [r2]

  @ start scanning for each row
  ldr r0, =0b00001
  ldr r1, [r3, r2]
  bl word_scanning

  add r2, #2
  ldr r0, =0b00010
  ldr r1, [r3,r2]
  bl word_scanning
  
  add r2, #2
  ldr r0, =0b00100
  ldr r1, [r3,r2]
  bl word_scanning
  
  add r2, #2
  ldr r0, =0b01000
  ldr r1, [r3,r2]
  bl word_scanning

  add r2, #2
  ldr r0, =0b10000
  ldr r1, [r3,r2]
  bl word_scanning

  @ restore registers
  pop {r0, r1, r2, r3, lr}
  @ go back to main loop
  b main_loop

.type beat_loop, %function
beat_loop:
  @ load for each line and row to start a pwm scanning
  @ finally it will display as a breathing heart
  ldr r0, =0b00001
  ldr r1, =0b00110
  bl pwm_scanning

  ldr r0, =0b00010
  ldr r1, =0b01111
  bl pwm_scanning

  ldr r0, =0b00100
  ldr r1, =0b11110
  bl pwm_scanning

  ldr r0, =0b01000
  ldr r1, =0b01111
  bl pwm_scanning

  ldr r0, =0b10000
  ldr r1, =0b00110
  bl pwm_scanning

  @ load the increment or decrease display time option to r2
  @ 1 to increase display time; 0 to decrease
  ldr r1, =pulse
  @ load display time to r0
  ldr r0, [r1]
  ldr r2, [r1, 4]
  cmp r2, #1
  beq backward
  cmp r2, #0
  beq forward

backward:
  @ decrease display time by right shifting
  lsr r0, #1
  str r0, [r1]
  cmp r0, #1
  @ if touches 1, change the direction to increase for next loop
  beq change_dir_to_forward
  b continue
change_dir_to_forward:
  ldr r2, =0
  str r2, [r1, 4]
  b continue
forward:
  @ increase display time by left shifting
  lsl r0, #1
  str r0, [r1]
  @ if touches a certain value, change direction to decrese for next loop
  cmp r0, #0x20000
  beq change_dir_to_backward
  b continue
change_dir_to_backward:
  ldr r2, =1
  str r2, [r1, 4]
  b continue
continue:
  @ go back to main loop
  b main_loop


.size main, .-main
.type word_scanning, %function
@ args:
@   r0: coloumn state
@   r1: row state
word_scanning:
  push {r3}
  push {r2}
  push {lr}
  push {r1}
  @ use r0 to write column pins
  bl write_column_pins
  pop {r0}
  @ use r1 in parameters to write row pins
  bl write_row_pins

  ldr r0, =10000
  bl delay

  @ off the leds for a certain time
  ldr r0, =0b00000
  bl write_column_pins
  ldr r0, =0b00000
  bl write_row_pins
  ldr r0, =100
  bl delay
  
  @ restore registers
  pop {lr}
  pop {r2}
  pop {r3}
  bx lr

.type pwm_scanning, %function
@ args:
@   r0: coloumn state
@   r1: row state
pwm_scanning:
  push {r2}
  push {lr}
  push {r1}
  @ use r0 to write columns
  bl write_column_pins
  pop {r0}
  @ use r1 in parameter to write row
  bl write_row_pins

  @ load display time from memmory
  ldr r0, =pulse
  ldr r0, [r0]
  bl delay

  @ off the leds
  ldr r0, =0b00000
  bl write_column_pins
  ldr r0, =0b00000
  bl write_row_pins
  
  @ load display time from memory
  ldr r0, =pulse
  ldr r0, [r0]
  @ set the off delay time by minusing a certain value from the display time
  ldr r1, =0x10020
  sub r0, r1, r0
  bl delay
  
  @ restore registers
  pop {lr}
  pop {r2}
  bx lr

.global SysTick_Handler
.type SysTick_Handler, %function
SysTick_Handler:
  @ update word loop pointer in systick handler
  @ store the registers
  push {r0, r1}
  @ load the word pointer
  ldr r0, =word_pointer
  ldr r1, [r0]
  @ add 2 as the half word taks up 2 bytes
  add r1, #2
  @ store back the word pointer
  str r1, [r0]
  @ if it touches the end of the word, change back to the beginning
  cmp r1, #60
  beq restart
  @ restore registers
  pop {r0, r1}
  bx lr
restart:
  @ set the pointer to 0 to restart
  ldr r1, =0 
  str r1, [r0]
  pop {r0, r1}
  bx lr
.size SysTick_Handler, .-SysTick_Handler


.global GPIOTE_IRQHandler
.type GPIOTE_IRQHandler, %function
GPIOTE_IRQHandler:
  @ store registers
  push {r0, r1, r2, r3, lr}
  @ load the event from IN0
  ldr r0, =GPIOTE_EVENTS_IN0
  ldr r1, [r0]
  @ if the value is 1, then the interrupt is triggered by IN0 from button A
  @ else, the interrupt is triggered by IN1 from button B
  cmp r1, #1
  beq buttonA_pressed
  b buttonB_pressed
buttonA_pressed:
  @ load the pointer and update it to display breathing heart
  @ clear event
  ldr r1, =0
  str r1, [r0]
  ldr r0, =loop_pointer
  str r1, [r0]
  pop {r0, r1, r2, r3, lr}
  bx lr

buttonB_pressed:  
  @ load the pointer to display the word loop
  @ clear event
  ldr r1, =0
  ldr r0, =GPIOTE_EVENTS_IN1
  str r1, [r0]
  @ reset the word_pointer to 0 to restart displaying
  ldr r0, =word_pointer
  str r1, [r0]
  ldr r1, =4
  ldr r0, =loop_pointer
  str r1, [r0]
  pop {r0, r1, r2, r3, lr}
  bx lr


.data
hello_col:
  @ word "HELLO" display column status
  @ blank
  .hword 0b00000
  .hword 0b00000
  .hword 0b00000
  .hword 0b00000
  .hword 0b00000
  .hword 0b00000
  @ H
  .hword 0b11111
  .hword 0b00100
  .hword 0b00100
  .hword 0b11111
  .hword 0b00000
  @ E
  .hword 0b11111
  .hword 0b10101
  .hword 0b10101
  .hword 0b00000
  @ L
  .hword 0b11111
  .hword 0b10000
  .hword 0b10000
  .hword 0b00000
  @ L
  .hword 0b11111
  .hword 0b10000
  .hword 0b10000
  .hword 0b00000
  @ O
  .hword 0b01110
  .hword 0b10001
  .hword 0b10001
  .hword 0b01110
  .hword 0b00000
  @ !
  .hword 0b00000
  .hword 0b10111
  .hword 0b00000
  .hword 0b00000
  .hword 0b00000
  .hword 0b00000
word_pointer:
  @ pointer for word display loop
  @ point to the start byte to start display leds
  .word 0 

pulse:
  @ for breathing heart loop
  .word 1 @ time of display
  .word 0 @ direction, 0 forward, 1 backward

loop_option:
  @ option address for main loop to choose from: breathing heart loop; word display loop
  .word beat_loop
  .word word_loop
loop_pointer:
  @ pointer for main loop to choose
  @ it will be updated by interrupts
  @ default to start word loop so set the value to 4 (1 word for 4 bytes)
  .word 4