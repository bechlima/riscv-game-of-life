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

/* BEGIN:main */
main:
    li   sp, CUSTOM_VAR_END

start_game_main:
    li   a0, 0
    jal  reset_game
    jal  get_input
    li   s0, 0

game_loop:
    bnez s0, start_game_main

continue_game:
    jal  select_action
    jal  update_state
    jal  update_gsa
    jal  mask
    jal  draw_gsa
    jal  decrement_step
    mv   s0, a0
    jal  get_input
    jal   game_loop


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
    li  t0, CURR_STATE
    lw  t1, 0(t0)
    li  t2, RUN
    bne t1, t2, end_wait
    li  t0, 1
    slli t0, t0, 19
    li  t2, SPEED
    lw  t1, 0(t2)
    beqz t1, end_wait
delay:
    sub  t0, t0, t1
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
/* Affiche le GSA courant sur la matrice de LEDs (en rouge seulement)
   en préservant les murs bleus dessinés par mask. */
draw_gsa:
    addi sp, sp, -20
    sw   ra, 16(sp)
    sw   s0, 12(sp)
    sw   s1, 8(sp)
    sw   s2, 4(sp)
    sw   s3, 0(sp)

    li   s0, 0                  # y = 0
    li   s1, N_GSA_LINES        # = 10 lignes
    li   s2, LEDS               # base LED register

draw_row:
    beq  s0, s1, draw_end       # fin si y == 10
    mv   a0, s0
    jal  get_gsa                # a0 = ligne du GSA
    mv   t0, a0                 # t0 = pattern logique de la ligne

    # --- Construire le mot de contrôle LED ---
    slli t1, s0, 4              # bits [7:4] = sélection de ligne
    ori  t1, t1, 0xF            # bits [3:0] = toutes colonnes

    li   t2, 1
    slli t2, t2, 8              # bit [8] = rouge
    or   t1, t1, t2             # ajoute la couleur rouge

    slli t3, t0, 16             # bits [31:16] = contenu du GSA
    or   t1, t1, t3             # combine sélection + couleur + données

    # --- Préserver les murs bleus existants (bit 10) ---
    lw   t4, 0(s2)              # lire l’état LED courant
    andi t5, t4, 0x400          # extraire bit bleu
    or   t1, t1, t5             # le réappliquer

    sw   t1, 0(s2)              # écrire la ligne dans les LEDs

    addi s0, s0, 1              # y++
    j    draw_row

draw_end:
    lw   ra, 16(sp)
    lw   s0, 12(sp)
    lw   s1, 8(sp)
    lw   s2, 4(sp)
    lw   s3, 0(sp)
    addi sp, sp, 20
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
    or  t5, t5, t6
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

/* BEGIN:change_speed */
change_speed:
    li t0, 1
    li t2, 10
    li t3, SPEED
    lw t1, 0(t3)
    beq a0, t0, decrement
    beq t1, t2, end_change
    addi t1, t1, 1
    j cont_change
decrement:
    beq t1, t0, end_change
    sub t1, t1, t0
cont_change:
    sw t1, 0(t3)
end_change:
    ret
/* END:change_speed */

/* BEGIN:pause_game */
pause_game:
    li t0, PAUSE
    lw t1, 0(t0)
    li t2, 1
    xor t1, t1, t2
    sw t1, 0(t0)
    ret
/* END:pause_game */

/* BEGIN:change_steps */
change_steps:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   t0, 8(sp)
    sw   t1, 4(sp)
    sw   t2, 0(sp)

    li   t0, CURR_STEP
    lw   t1, 0(t0)           # Load current step counter

    # --- Extract digits ---
    andi t2, t1, 0xF         # ones
    srli t3, t1, 4
    andi t3, t3, 0xF         # tens
    srli t4, t1, 8
    andi t4, t4, 0xF         # hundreds

    # --- Increment selected digit ---
    beqz a0, check_tens
    addi t2, t2, 1           # increment ones
    j apply_carry
check_tens:
    beqz a1, check_hundreds
    addi t3, t3, 1           # increment tens
    j apply_carry
check_hundreds:
    beqz a2, finish_change
    addi t4, t4, 1           # increment hundreds

apply_carry:
    # Handle overflow for ones -> tens
    li t5, 10
    blt t2, t5, skip_tens_carry
    li t2, 0
    addi t3, t3, 1
skip_tens_carry:

    # Handle overflow for tens -> hundreds
    blt t3, t5, skip_hundreds_carry
    li t3, 0
    addi t4, t4, 1
skip_hundreds_carry:

    # Cap hundreds at 9 (no carry beyond)
    blt t4, t5, finish_change
    li t4, 9

finish_change:
    # Recombine digits
    slli t4, t4, 8
    slli t3, t3, 4
    or   t1, t4, t3
    or   t1, t1, t2
    sw   t1, 0(t0)

    lw   ra, 12(sp)
    lw   t0, 8(sp)
    lw   t1, 4(sp)
    lw   t2, 0(sp)
    addi sp, sp, 16
    ret
/* END:change_steps */

/* BEGIN:set_seed */
set_seed:
    addi sp, sp, -32
    sw   ra, 28(sp)
    sw   s0, 24(sp)    # line index
    sw   s1, 20(sp)    # seed pointer
    sw   s2, 16(sp)
    sw   s3, 12(sp)
    sw   s4, 8(sp)
    sw   s5, 4(sp)

    # --- record selected seed ID ---
    li   t0, SEED
    sw   a0, 0(t0)

    # --- bounds check ---
    li   t1, N_SEEDS
    bge  a0, t1, fallback_random_seed

    # --- find address of seed[a0] ---
    la   s1, SEEDS
    slli t2, a0, 2
    add  s1, s1, t2
    lw   s1, 0(s1)          # pointer to chosen seed

    li   s0, 0              # current line index
    li   s3, N_GSA_LINES    # total lines

copy_loop:
    bge  s0, s3, end_set_seed

    lw   s2, 0(s1)          # load one seed line
    mv   a0, s2             # a0 = line value
    mv   a1, s0             # a1 = row index

    # --- fully protect registers before set_gsa ---
    addi sp, sp, -16
    sw   s0, 0(sp)
    sw   s1, 4(sp)
    sw   s2, 8(sp)
    sw   s3, 12(sp)
    jal  set_gsa
    lw   s0, 0(sp)
    lw   s1, 4(sp)
    lw   s2, 8(sp)
    lw   s3, 12(sp)
    addi sp, sp, 16

    addi s1, s1, 4
    addi s0, s0, 1
    j    copy_loop

fallback_random_seed:
    jal  random_gsa

end_set_seed:
    lw   ra, 28(sp)
    lw   s0, 24(sp)
    lw   s1, 20(sp)
    lw   s2, 16(sp)
    lw   s3, 12(sp)
    lw   s4, 8(sp)
    lw   s5, 4(sp)
    addi sp, sp, 32
    ret
/* END:set_seed */

/* BEGIN:increment_seed */
increment_seed:
    addi sp, sp, -8
    sw   ra, 0(sp)

    li   t0, CURR_STATE
    lw   t1, 0(t0)
    li   t2, INIT
    li   t3, SEED
    lw   t4, 0(t3)
    li   t5, N_SEEDS

    beq  t1, t2, check_init
    bge  t4, t5, do_random
    j    do_random

check_init:
    li   t6, N_SEEDS-1
    bge  t4, t6, do_random
    addi t4, t4, 1
    sw   t4, 0(t3)
    mv   a0, t4
    jal  set_seed
    j    end_increment_seed

do_random:
    jal  random_gsa

end_increment_seed:
    lw   ra, 0(sp)
    addi sp, sp, 8
    ret
/* END:increment_seed */

/* BEGIN:update_state */
update_state:
    addi sp, sp, -16
    sw   ra, 12(sp)

    mv   t0, a0
    li   t2, CURR_STATE
    lw   t3, 0(t2)

    andi t1, t0, 0x08
    beqz t1, check_jr
    li   t4, RAND
    beq  t3, t4, do_reset
    li   t4, RUN
    beq  t3, t4, do_reset
    j    check_jr

do_reset:
    jal  reset_game
    li   t3, INIT
    sw   t3, 0(t2)
    j    end_update

check_jr:
    andi t1, t0, 0x02
    beqz t1, check_jc
    li   t4, INIT
    beq  t3, t4, enter_rand
    li   t4, RAND
    beq  t3, t4, enter_run
    j    check_jc

enter_rand:
    li   t3, RAND
    sw   t3, 0(t2)
    jal  random_gsa
    li   t0, PAUSE
    sw   x0, 0(t0)
    j    end_update

enter_run:
    li   t3, RUN
    sw   t3, 0(t2)
    li   t0, PAUSE
    li   t1, RUNNING
    sw   t1, 0(t0)
    j    end_update

check_jc:
    andi t1, t0, 0x01
    beqz t1, end_update
    li   t2, CURR_STATE
    lw   t3, 0(t2)
    li   t4, RUN
    bne  t3, t4, end_update
    li   t2, PAUSE
    lw   t3, 0(t2)
    xori t3, t3, 1
    sw   t3, 0(t2)

end_update:
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret
/* END:update_state */

/* BEGIN:select_action */
select_action:
    addi sp, sp, -8
    sw   ra, 0(sp)
    sw   a0, 4(sp)

    li   t0, CURR_STATE
    lw   t1, 0(t0)

    li   t2, INIT
    beq  t1, t2, handle_init_state
    li   t2, RAND
    beq  t1, t2, handle_rand_state
    li   t2, RUN
    beq  t1, t2, handle_run_state
    j    end_select_action

handle_init_state:
    andi t5, a0, JC
    bnez t5, cycle_seed
    andi t5, a0, JR
    bnez t5, start_game
    andi t5, a0, BUTTON_0
    bnez t5, change_steps_units
    andi t5, a0, BUTTON_1
    bnez t5, change_steps_tens
    andi t5, a0, BUTTON_2
    bnez t5, change_steps_hundreds
    j    end_select_action

handle_rand_state:
    andi t5, a0, JC
    bnez t5, replace_with_random_gsa
    andi t5, a0, JR
    bnez t5, start_game
    andi t5, a0, BUTTON_0
    bnez t5, change_steps_units
    andi t5, a0, BUTTON_1
    bnez t5, change_steps_tens
    andi t5, a0, BUTTON_2
    bnez t5, change_steps_hundreds
    j    end_select_action

handle_run_state:
    andi t5, a0, JC
    bnez t5, start_game
    andi t5, a0, JR
    bnez t5, increase_speed_action
    andi t5, a0, JL
    bnez t5, decrease_speed_action
    andi t5, a0, JB
    bnez t5, reset_action
    andi t5, a0, JT
    bnez t5, replace_with_random_gsa
    j    end_select_action

cycle_seed:
    call increment_seed
    j    end_select_action

start_game:
    jal  pause_game
    j    end_select_action

change_steps_units:
    li   a0, 1
    li   a1, 0
    li   a2, 0
    jal  change_steps
    j    end_select_action

change_steps_tens:
    li   a1, 1
    li   a0, 0
    li   a2, 0
    jal  change_steps
    j    end_select_action

change_steps_hundreds:
    li   a2, 1
    li   a0, 0
    li   a1, 0
    jal  change_steps
    j    end_select_action

increase_speed_action:
    li   a0, 0
    jal  change_speed
    j    end_select_action

decrease_speed_action:
    li   a0, 1
    jal  change_speed
    j    end_select_action

reset_action:
    jal  reset_game
    j    end_select_action

replace_with_random_gsa:
    jal  random_gsa
    j    end_select_action

end_select_action:
    lw   ra, 0(sp)
    lw   a0, 4(sp)
    addi sp, sp, 8
    ret
/* END:select_action */

/* BEGIN:cell_fate */
cell_fate:
    li   t0, 3
    li   t1, 2
    beqz a1, dead_cell
    blt  a0, t1, dead
    bgt  a0, t0, dead
    j    alive
dead_cell:
    beq  a0, t0, alive
dead:
    li   a0, 0
    j    end_fate
alive:
    li   a0, 1
end_fate:
    ret
/* END:cell_fate */

/* BEGIN:find_neighbours */
find_neighbours:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s0, 8(sp)
    sw   s1, 4(sp)

    mv   s0, a0
    mv   s1, a1

    addi t2, s1, -1
    addi t3, s1, 1
    li   t4, N_GSA_LINES
    bltz t2, fix_top
    bge  t3, t4, fix_bottom
    j    y_wrap_done
fix_top:
    li   t2, N_GSA_LINES-1
fix_bottom:
    li   t3, 0
y_wrap_done:
    mv   a0, t2
    jal  get_gsa
    mv   t2, a0

    mv   a0, s1
    jal  get_gsa
    mv   t4, a0

    mv   a0, t3
    jal  get_gsa
    mv   t3, a0

    addi t5, s0, -1
    bltz t5, fix_left
    li   t6, N_GSA_COLUMNS
    bge  s0, t6, fix_right
    j    x_wrap_done
fix_left:
    li   t5, N_GSA_COLUMNS-1
    j    x_wrap_done
fix_right:
    li   t5, 0
x_wrap_done:
    srl  t2, t2, t5
    srl  t3, t3, t5
    srl  t4, t4, t5
    li   a0, 0x7
    and  t2, t2, a0
    and  t3, t3, a0
    and  t4, t4, a0
    add  t2, t2, t3
    add  t2, t2, t4
    li   a0, 0
count_loop:
    andi t1, t2, 1
    add  a0, a0, t1
    srli t2, t2, 1
    bnez t2, count_loop
    li   t5, 1
    sll  t5, t5, s0
    and  a1, t4, t5
    snez a1, a1
    sub  a0, a0, a1

    lw   ra, 12(sp)
    lw   s0, 8(sp)
    lw   s1, 4(sp)
    addi sp, sp, 16
    ret
/* END:find_neighbours */

/* BEGIN:update_gsa */
update_gsa:
    addi sp, sp, -32
    sw   ra, 28(sp)
    sw   s0, 24(sp)
    sw   s1, 20(sp)
    sw   s2, 16(sp)
    sw   s3, 12(sp)
    sw   s4, 8(sp)

    li   t0, PAUSE
    lw   t1, 0(t0)
    beqz t1, end_gsa

    li   s1, 0
    li   s2, N_GSA_LINES
    li   s4, N_GSA_COLUMNS

generate_updated_gsa:
    beq  s1, s2, end_gen
    li   s3, 0
    li   s0, 0

generate_updated_gsa_elem:
    beq  s3, s4, finished_gen
    mv   a0, s3
    mv   a1, s1
    jal  find_neighbours
    jal  cell_fate
    slli s0, s0, 1
    or   s0, s0, a0
    addi s3, s3, 1
    j    generate_updated_gsa_elem

finished_gen:
    mv   a0, s0
    mv   a1, s1
    li   t0, GSA_ID
    lw   t1, 0(t0)
    xori t1, t1, 1
    sw   t1, 0(t0)
    jal  set_gsa
    xori t1, t1, 1
    sw   t1, 0(t0)
    addi s1, s1, 1
    j    generate_updated_gsa

end_gen:
    li   t0, GSA_ID
    lw   t1, 0(t0)
    xori t1, t1, 1
    sw   t1, 0(t0)

end_gsa:
    lw   ra, 28(sp)
    lw   s0, 24(sp)
    lw   s1, 20(sp)
    lw   s2, 16(sp)
    lw   s3, 12(sp)
    lw   s4, 8(sp)
    addi sp, sp, 32
    ret
/* END:update_gsa */

/* BEGIN:get_input */
/* Reads the button register and returns the lowest active bit in a0.
   If multiple buttons are pressed, only the least significant one is considered. */
get_input:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   t0, 0(sp)

    li   t0, BUTTONS
    lw   a0, 0(t0)          # Read buttons
    beqz a0, no_press

    # Find least significant active bit
    li   t1, 1
find_lsb:
    and  t2, a0, t1
    bnez t2, found_press
    slli t1, t1, 1
    j    find_lsb

found_press:
    mv   a0, t1              # Return only the LSB active bit
    sw   zero, 0(t0)         # Clear button register
    j    done_input

no_press:
    li   a0, 0               # No button pressed

done_input:
    lw   ra, 4(sp)
    lw   t0, 0(sp)
    addi sp, sp, 8
    ret
/* END:get_input */

/* BEGIN:decrement_step */
decrement_step:
    li   t0, RUN
    li   t1, CURR_STATE
    lw   t2, 0(t1)
    beq  t2, t0, running
    j    display_step
running:
    li   t0, PAUSE
    lw   t1, 0(t0)
    li   t2, 1
    beq  t1, t2, not_paused
    j    display_step
not_paused:
    li   t0, CURR_STEP
    lw   t1, 0(t0)
    beqz t1, ret_one
    sub  t1, t1, t2
    sw   t1, 0(t0)
display_step:
    li   t0, CURR_STEP
    lw   t1, 0(t0)
    mv   t0, t1
    andi t1, t0, 0xF
    srli t0, t0, 4
    andi t2, t0, 0xF
    srli t0, t0, 4
    andi t3, t0, 0xF
    srli t0, t0, 4
    andi t4, t0, 0xF
    la   t5, font_data
    slli t6, t1, 2
    add  t6, t5, t6
    lw   t1, 0(t6)
    slli t6, t2, 2
    add  t6, t5, t6
    lw   t2, 0(t6)
    slli t6, t3, 2
    add  t6, t5, t6
    lw   t3, 0(t6)
    slli t6, t4, 2
    add  t6, t5, t6
    lw   t4, 0(t6)
    slli t4, t4, 24
    slli t3, t3, 16
    slli t2, t2, 8
    or   t4, t4, t3
    or   t4, t4, t2
    or   t4, t4, t1
    li   t5, SEVEN_SEGS
    sw   t4, 0(t5)
    li   a0, 0
    ret
ret_one:
    li   a0, 1
    ret
/* END:decrement_step */

/* BEGIN:reset_game */
reset_game:
    addi sp, sp, -16
    sw   ra, 12(sp)
    li   t0, CURR_STATE
    li   t1, INIT
    sw   t1, 0(t0)
    li   t0, CURR_STEP
    li   t1, 1
    sw   t1, 0(t0)
    la   t2, font_data
    lw   t4, 4(t2)
    lw   t3, 0(t2)
    lw   t1, 0(t2)
    lw   t0, 0(t2)
    slli t0, t0, 24
    slli t1, t1, 16
    slli t3, t3, 8
    or   t0, t0, t1
    or   t0, t0, t3
    or   t0, t0, t4
    li   t5, SEVEN_SEGS
    sw   t0, 0(t5)
    jal  clear_leds
    li   t0, SEED
    sw   x0, 0(t0)
    li   t0, GSA_ID
    sw   x0, 0(t0)
    li   t0, PAUSE
    sw   x0, 0(t0)
    li   t0, SPEED
    li   t1, 1
    sw   t1, 0(t0)
    li   a0, 0
    jal  set_seed
    jal  draw_gsa
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret
/* END:reset_game */

/* BEGIN:mask */
/* Applies the mask for the current seed:
   - Keeps masked cells dead in the GSA
   - Draws blue walls for masked (dead) cells */
mask:
    addi sp, sp, -32
    sw   ra, 28(sp)
    sw   s0, 24(sp)
    sw   s1, 20(sp)
    sw   s2, 16(sp)
    sw   s3, 12(sp)

    # --- Select mask according to SEED ---
    li   t0, SEED
    lw   t1, 0(t0)           # t1 = current seed index
    li   t2, 4
    bge  t1, t2, use_mask4   # if seed >= 4 → use mask4

    la   t3, MASKS
    slli t4, t1, 2           # offset = seed * 4 bytes
    add  t3, t3, t4
    lw   t3, 0(t3)           # t3 = address of chosen mask
    j    mask_ready

use_mask4:
    la   t3, MASKS
    li   t4, 16
    add  t3, t3, t4
    lw   t3, 0(t3)

mask_ready:
    li   s0, 0               # y = 0
    li   s1, 10              # N_GSA_LINES = 10

row_loop:
    beq  s0, s1, mask_end

    lw   t1, 0(t3)           # load mask[y]
    mv   s2, t1
    mv   s3, s0

    # --- Apply mask to GSA line ---
    mv   a0, s3
    sw   t3, 8(sp)           # preserve mask pointer
    jal  get_gsa
    lw   t3, 8(sp)

    mv   t4, a0
    and  t4, t4, s2          # zero-out masked bits

    mv   a0, t4
    mv   a1, s3
    sw   t3, 8(sp)
    jal  set_gsa
    lw   t3, 8(sp)

    # --- Draw blue walls for masked-off bits ---
    not  s2, s2
    li   t5, 0xFFF
    and  s2, s2, t5

    slli t4, s2, 16          # [31:16] = data bits
    slli t6, s3, 4           # [7:4] = row select
    ori  t6, t6, 0x400       # [10] = blue color
    ori  t6, t6, 0xF         # [3:0] = all columns active
    or   t4, t4, t6          # combine fields
    li   t0, LEDS
    sw   t4, 0(t0)

    # advance to next mask line
    addi t3, t3, 4
    addi s0, s0, 1
    j    row_loop

mask_end:
    lw   ra, 28(sp)
    lw   s0, 24(sp)
    lw   s1, 20(sp)
    lw   s2, 16(sp)
    lw   s3, 12(sp)
    addi sp, sp, 32
    ret
/* END:mask */

/* 7-segment display */
font_data:
    .word 0x3F
    .word 0x06
    .word 0x5B
    .word 0x4F
    .word 0x66
    .word 0x6D
    .word 0x7D
    .word 0x07
    .word 0x7F
    .word 0x6F
    .word 0x77
    .word 0x7C
    .word 0x39
    .word 0x5E
    .word 0x79
    .word 0x71

seed0:
    .word 0xC00
    .word 0xC00
    .word 0x000
    .word 0x060
    .word 0x0A0
    .word 0x0C6
    .word 0x006
    .word 0x000
    .word 0x000
    .word 0x000

seed1:
    .word 0x000
    .word 0x000
    .word 0x05C
    .word 0x040
    .word 0x240
    .word 0x200
    .word 0x20E
    .word 0x000
    .word 0x000
    .word 0x000

seed2:
    .word 0x000
    .word 0x010
    .word 0x020
    .word 0x038
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000

seed3:
    .word 0x000
    .word 0x000
    .word 0x090
    .word 0x008
    .word 0x088
    .word 0x078
    .word 0x000
    .word 0x000
    .word 0x000
    .word 0x000

SEEDS:
    .word seed0
    .word seed1
    .word seed2
    .word seed3

mask0:
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF

mask1:
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0x1FF
    .word 0x1FF
    .word 0x1FF
    .word 0x1FF
    .word 0x1FF

mask2:
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF
    .word 0x7FF

mask3:
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0x000
    .word 0x000
    .word 0x000

mask4:
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0xFFF
    .word 0x000
    .word 0x000
    .word 0x000

MASKS:
    .word mask0
    .word mask1
    .word mask2
    .word mask3
    .word mask4