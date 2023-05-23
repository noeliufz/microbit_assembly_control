# Assignemnt overview
For this assignment, I created two display status: a breathing heart and a word loop displaying "HELLO!".

I used the SysTick Timer to realize the display of word loop and GPIO interrupts to enable to choose from the two display status 
using button A (a breathing heart) and button B (word display).

For the breathing heat, the basic pulse-width modulation (PWM) is used.
# Word display details
I firstly stored all the column status of "HELLO!" to display in data as `hello_row` as half word, and a word pointer `word_pointer` as well to point to the 
first column to display on the 5x5 LED matrix.

Before the main funciton, I enabled the system tick timer by setting the `SYST_CSR` and `SYST_RVR` to `16 000 000` as the reload value.

As time goes on the system tick timer counts down to 0, the value of word pointer will be updated by incrementing by 2 in the function `SysTick_Handler`
as the half word takes up 2 bytes in memory or back to 0 to restart displaying the word from the beginning when it touches the end of the half word "!".

# Breathing heart display details
I used the normal way to create a scanning loop. To implement a basic PWM, the delay time after turning on LEDs is stored in memory as `pulse`.
It will be updated after every loop is finished by left shifting by 1 at the phase of decreasing the lightness or right shifting by 1 at the phase of increasing the 
lightness. The incresing and decresing direction will be changed when it touches the edges of `0` and `0x20000` which can be custom set in the funciton. This is implemented by storing a direction value `pulse` which `0` to 
left shifting and `1` to right shifting. So the value of the delay after the LEDs on will be from `0b0`, `0b1`, `0b10` ... to `0x20000`. 

The delay time after turning off the LEDs in the scanning loop will be calculated by minusing a certain value, here I set it to be `0x10020` by the `pulse` value
stored in the memory. This will decrease the total display time of low lightness during the whole process to display a better breathing heart.

# Display status switch details
I stored the address of two status functions `beat_loop` and `word_loop` in memory as `loop_option` and the offset of `loop_option` in memory as `loop_pointer`.

In the main loop, the value of `loop_pointer` will be loaded and be added to the address of `loop_option` to get the chosen loop funtion address and load it to 
program counter. This is to say, if the value store in `loop_pointer` is 0, the program counter will be redirected to `beat_loop` and 1 to `word_loop`. And at the
end of each loop function, the CPU will implement the statement `b main_loop` and go back to main function again to get the offset and goes on again the chosen loop.

Before starting the main loop, I combined the events of pressing button A with `GPIOTE_CONFIG0` and button B with `GPIOTE_CONFIG1` so that we can resign two 
different handler events to handle the two events in `GPIOTE_IRQHandler` by adding an IF statement to see whose value is set to 1 in `GPIOTE_EVENTS_IN0` and
`GPIOTE_EVENTS_IN1`. In the handler function, the value stored in `loop_pointer` will be updated in terms of which button is pressed and clear the events by 
resetting the value to 0 in `GPIOTE_EVENTS_IN0` or `GPIOTE_EVENTS_IN1` and then call the `bx lr` to go back to the program. When the CPU executes again the `main_loop` function, the program 
counter will be loaded by the updated value in `loop_pointer` so that in this way, we can change the display status by pressing button A to breathing heart and
button B to word loop.

Likewise, I also set the prioity to make the system tick timer's interruption prior to the GPIOTE interrupt so that the system tick timer will not stop after one
GPIOTE interrupts the execution of CPU.