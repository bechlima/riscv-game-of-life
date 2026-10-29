.section ".word"
  .equ CURR_STATE, 0x90001000
  .equ GSA_ID, 0x90001004
  .equ PAUSE, 0x90001008
  .equ SPEED, 0x9000100C
  .equ CURR_STEP, 0x90001010
  .equ SEED, 0x90001014
  .equ GSA0, 0x90001018
  .equ GSA1, 0x90001058
  .equ CUSTOM_VAR_START, 0x90001200
  .equ CUSTOM_VAR_END, 0x90001300
  .equ RANDOM, 0x40000000
  .equ LEDS, 0x50000000
  .equ SEVEN_SEGS, 0x60000000
  .equ BUTTONS, 0x70000004

  .equ INIT, 0
  .equ RAND, 1
  .equ RUN, 2

  .equ RED, 0x100
  .equ BLUE, 0x400

  .equ JT, 0x10
  .equ JB, 0x8
  .equ JL, 0x4
  .equ JR, 0x2
  .equ JC, 0x1
  .equ BUTTON_2, 0x80
  .equ BUTTON_1, 0x20
  .equ BUTTON_0, 0x40

  .equ ALL, 0xF

  .equ N_SEEDS, 4
  .equ N_GSA_LINES, 10
  .equ N_GSA_COLUMNS, 12
  .equ MAX_SPEED, 10
  .equ MIN_SPEED, 1
  .equ PAUSED, 0x00
  .equ RUNNING, 0x01

.section ".text.init"
  .globl main

main:
    li sp, 0x90002000
    li t0, GSA_ID
    sw zero, 0(t0)
    jal random_gsa
    jal draw_gsa
.hang:
    j .hang

/* BEGIN:clear_leds */
clear_leds:
    li t0, 0x000007FF
    li t1, LEDS
    sw t0, 0(t1)
    ret
/* END:clear_leds */

/* BEGIN:set_pixel */
set_pixel:
    slli t0, a1, 4
    or t0, t0, a0
    li t1, 0x10100
    or t0, t0, t1
    li t1, LEDS
    sw t0, 0(t1)
    ret
/* END:set_pixel */

/* BEGIN:wait */
wait:
    li t0, CURR_STATE
    lw t1, 0(t0)
    li t2, RUN
    bne t1, t2, end_wait
    li t0, 1
    slli t0, t0, 19
    li t2, SPEED
    lw t1, 0(t2)
    beqz t1, end_wait
delay:
    sub t0, t0, t1
    bgtz t0, delay
end_wait:
    ret
/* END:wait */

/* BEGIN:set_gsa */
set_gsa:
    li t0, GSA_ID
    lw t1, 0(t0)
    beqz t1, use_gsa0_set
    li t2, GSA1
    j cont_set
use_gsa0_set:
    li t2, GSA0
cont_set:
    slli t3, a1, 2
    add t2, t2, t3
    sw a0, 0(t2)
    ret
/* END:set_gsa */

/* BEGIN:get_gsa */
get_gsa:
    li t0, GSA_ID
    lw t1, 0(t0)
    beqz t1, use_gsa0_get
    li t2, GSA1
    j cont_get
use_gsa0_get:
    li t2, GSA0
cont_get:
    slli t3, a0, 2
    add t2, t3, t2
    lw a0, 0(t2)
    ret
/* END:get_gsa */

/* BEGIN:draw_gsa */
draw_gsa:
    addi sp, sp, -8
    sw ra, 4(sp)
    sw s0, 0(sp)
    li s0, 0
.loop_rows:
    li t0, N_GSA_LINES
    beq s0, t0, .done
    mv a0, s0
    jal get_gsa
    slli t1, s0, 4
    ori t1, t1, 0xF
    li t2, 1
    slli t2, t2, 8
    or t1, t1, t2
    slli t3, a0, 16
    or t1, t1, t3
    li t4, LEDS
    sw t1, 0(t4)
    addi s0, s0, 1
    j .loop_rows
.done:
    lw ra, 4(sp)
    lw s0, 0(sp)
    addi sp, sp, 8
    ret
/* END:draw_gsa */

/* BEGIN:random_gsa */
random_gsa:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    li t0, 0
    li t1, N_GSA_LINES
    li t4, N_GSA_COLUMNS
generate_random_gsa_element:
    beq t0, t1, end_random
    li t3, 0
    li t5, 0
generate_random_sequence:
    beq t3, t4, finished
    li t2, RANDOM
    lw t6, 0(t2)
    andi t6, t6, 1
    sll t6, t6, t3
    or t5, t5, t6
    addi t3, t3, 1
    j generate_random_sequence
finished:
    mv s0, t0
    mv s1, t1
    mv a0, t5
    mv a1, t0
    jal set_gsa
    mv t0, s0
    mv t1, s1
    addi t0, t0, 1
    j generate_random_gsa_element
end_random:
    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    addi sp, sp, 16
    ret
/* END:random_gsa */

/* BEGIN:pause_game */
pause_game:
    li t0, PAUSE
    lw t1, 0(t0)
    li t2, 1
    xor t1, t1, t2
    sw t1, 0(t0)
    ret
/* END:pause_game */
