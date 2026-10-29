.section ".word"
 /* Emplacements mémoire de l'état du jeu */
 .equ CURR_STATE, 0x90001000 /* État actuel du jeu */
 .equ GSA_ID, 0x90001004 /* ID du GSA contenant l’état actuel */
 .equ PAUSE, 0x90001008 /* Indique si le jeu est en pause ou en exécution */
 .equ SPEED, 0x9000100C /* Vitesse actuelle du jeu */
 .equ CURR_STEP, 0x90001010 /* Nombre d’étapes restantes */
 .equ SEED, 0x90001014 /* Graine utilisée pour initialiser le jeu */
 .equ GSA0, 0x90001018 /* Adresse de départ du Game State Array 0 */
 .equ GSA1, 0x90001058 /* Adresse de départ du Game State Array 1 */
 .equ CUSTOM_VAR_START, 0x90001200 /* Début de la plage mémoire libre pour variables personnalisées */
 .equ CUSTOM_VAR_END, 0x90001300 /* Fin de la plage mémoire libre */
 .equ RANDOM, 0x40000000 /* Adresse du générateur de nombres aléatoires */
 .equ LEDS, 0x50000000 /* Adresse du registre des LEDs */
 .equ SEVEN_SEGS, 0x60000000 /* Adresse de l’afficheur 7 segments */
 .equ BUTTONS, 0x70000004 /* Adresse du registre des boutons */

 /* États du jeu */
 .equ INIT, 0 /* État d’initialisation */
 .equ RAND, 1 /* État aléatoire */
 .equ RUN, 2 /* État en cours d’exécution */

 /* Couleurs (format 0bBGR) */
 .equ RED, 0x100 /* Rouge */
 .equ BLUE, 0x400 /* Bleu */

 /* Boutons */
 .equ JT, 0x10
 .equ JB, 0x8
 .equ JL, 0x4
 .equ JR, 0x2
 .equ JC, 0x1
 .equ BUTTON_2, 0x80
 .equ BUTTON_1, 0x20
 .equ BUTTON_0, 0x40

 /* Sélection des LEDs */
 .equ ALL, 0xF

 /* Constantes */
 .equ N_SEEDS, 4 /* Nombre de graines prédéfinies */
 .equ N_GSA_LINES, 10 /* Nombre de lignes dans le GSA */
 .equ N_GSA_COLUMNS, 12 /* Nombre de colonnes dans le GSA */
 .equ MAX_SPEED, 10 /* Vitesse maximale */
 .equ MIN_SPEED, 1 /* Vitesse minimale */
 .equ PAUSED, 0x00 /* Valeur indiquant le jeu en pause */
 .equ RUNNING, 0x01 /* Valeur indiquant le jeu en cours */

.section ".text.init"
 .globl main

main:

 li sp, CUSTOM_VAR_END /* Initialise le pointeur de pile (la pile descend vers le bas) */
 li a0, 0

start_game_main:
 li a0, 0
 call reset_game /* Réinitialise le jeu à son état initial */
 call get_input /* Lit l’entrée des boutons */
 li s0, 0 # 0 = faux, >0 = vrai (flag pour recommencer ou continuer)

game_loop:
 bnez s0, start_game_main /* Si s0 != 0, relancer le jeu */

continue_game:
 jal select_action /* Sélectionne l’action selon les boutons */
 jal update_state /* Met à jour l’état du jeu */
 jal update_gsa /* Calcule la nouvelle génération du GSA */
 #jal clear_leds
 jal mask /* Applique le masque des murs */
 
 jal draw_gsa /* Dessine le GSA à l’écran */
 jal decrement_step /* Décrémente le nombre d’étapes */
 mv s0, a0 /* Sauvegarde le résultat dans s0 (0 = continuer, 1 = recommencer) */
 jal get_input /* Lit l’entrée des boutons */

 j game_loop /* Boucle infinie principale */


/* BEGIN:clear_leds */
/* Efface toutes les LEDs de l’écran (met à 0) */
clear_leds:
 la t0, LEDS # Charge l’adresse du registre LED
 li t1, 0x00007FF # Valeur pour éteindre toutes les LEDs
 sw t1, 0(t0) # Écrit dans le registre
 ret
/* END:clear_leds */

/* BEGIN:set_pixel */
/* Allume un pixel rouge donné par ses coordonnées (a0 = x, a1 = y) */
set_pixel:
 la t0, LEDS
 add t3, a1, zero # Copie la coordonnée Y

 sll t3, t3, 4 # Décale Y dans les bits [7:4]
 or t2, a0, t3 # Combine X et Y dans t2

 li t4, 0x1 # Active le bit de couleur rouge
 slli t4, t4, 8 # Décale en position [10:8] (BGR)
 or t2, t2, t4 # Ajoute la couleur au mot de contrôle

 li t5, 0x1 # Valeur du pixel = 1 (LED allumée)
 sll t5, t5, 16 # Décale en position [31:16] (valeur LED)
 or t2, t2, t5 # Combine tout

 sw t2, 0(t0) # Écrit le mot final dans le registre LED
 ret 
/* END:set_pixel */

/* BEGIN:wait */
/* Crée un délai dépendant de la vitesse du jeu (SPEED) */
wait:
 li t0 , CURR_STATE
 lw t1 , 0(t0)
 li t2 , RUN
 bne t1 , t2 , no_wait

 la t0, SPEED # Charge l’adresse de la vitesse
 lw t2, 0(t0) # Charge la vitesse actuelle
 li t3, 1

 li t1, 0x1 # Initialise le compteur de délai
 slli t1, t1, 3 # Décale pour obtenir une grande valeur (≈ 2^6 = 64 itérations)

loop:
 sub t1, t1, t2 # Décrémente le compteur selon la vitesse
 bgeu t1, t3, loop # Continue tant que le compteur > 0
no_wait : 
 ret
/* END:wait */

/* BEGIN:set_gsa */
/* Écrit une ligne (a0) dans le GSA courant à l’index de ligne y = a1 */
set_gsa:
 addi sp, sp, -4
 sw ra, 0(sp)
 la t0, GSA_ID # Charge l’adresse de l’ID de GSA
 lw t0, 0(t0)
 beq t0, zero, select_set_gsa0 # Si GSA_ID == 0, utiliser GSA 0
 bne t0, zero, select_set_gsa1 # Si GSA_ID == 1, utiliser GSA 1

select_set_gsa0: 
 li t1, GSA0 # Base de GSA 0
 j next_set_gsa
select_set_gsa1:
 li t1, GSA1 # Base de GSA 1

next_set_gsa:
 slli t4, a1, 2 # y * 4 = décalage en octets
 add t1, t1, t4 # Adresse de la ligne choisie dans le GSA sélectionné
 sw a0, 0(t1) # Écrit la ligne a0 dans le GSA

 lw ra, 0(sp)
 addi sp, sp, 4
 ret
/* END:set_gsa */

/* BEGIN:get_gsa */
/* Lit la ligne y = a0 depuis le GSA courant et la renvoie dans a0 */
get_gsa:
 addi sp, sp, -4 
 sw ra, 0(sp)

 la t0, GSA_ID # Charge l’adresse de l’ID de GSA
 lw t0, 0(t0)
 beq t0, zero, select_get_gsa0 # Si GSA_ID == 0, utiliser GSA 0
 bne t0, zero, select_get_gsa1 # Si GSA_ID == 1, utiliser GSA 1

select_get_gsa0: 
 li t1, GSA0 # Base de GSA 0
 j next_get_gsa
select_get_gsa1:
 li t1, GSA1 # Base de GSA 1
 
next_get_gsa:
 slli t4, a0, 2 # y * 4 = décalage en octets
 add t1, t1, t4 # Adresse de la ligne y
 lw a0, 0(t1) # Charge la ligne dans a0 (valeur de retour)

 lw ra, 0(sp) # Restaure ra
 addi sp, sp, 4
 ret
/* END:get_gsa */

/* BEGIN:draw_gsa */
/* Affiche le GSA courant sur la matrice de LEDs (en rouge) */
draw_gsa:
 addi sp, sp, -20 
 sw ra, 0(sp)
 sw a0, 4(sp)

 li t0, LEDS
 li a0, 0
 li s1, 0

loop2:
 add t2, a0, zero # t2 = coordonnée de ligne (y)

 sw t2, 8(sp)
 sw t0, 12(sp)
 sw s1, 16(sp)
 jal get_gsa # a0 contient la valeur de la ligne y
 lw t2, 8(sp) # Restaure t2 (index de ligne)
 lw t0, 12(sp)
 lw s1, 16(sp)

 li t3, 0xF # Sélectionne toutes les colonnes
 slli t2, t2, 4 # Place la sélection de ligne dans [7:4]
 or t2, t2, t3 # Ajoute la sélection des colonnes

 li t4, 0x1
 slli t4, t4, 8 # Active la couleur rouge (bit [8])
 or t2, t2, t4 # Ajoute la couleur au mot de contrôle

 slli t5, a0, 16 # Place la valeur de la ligne dans [31:16]
 or t2, t2, t5 # Combine la valeur avec la sélection et la couleur

 sw t2, 0(t0) # Écrit le mot de contrôle dans le registre LED

 addi s1, s1, 1 # y++
 addi a0, s1, 0
 li t5, 10
 blt s1, t5, loop2 # Répéter pour les 10 lignes

 lw ra, 0(sp)
 lw a0, 4(sp) 
 addi sp, sp, 20
 nop 
 ret
/* END:draw_gsa */

/* BEGIN:random_gsa */
/* Remplit le GSA courant avec des valeurs aléatoires (1 bit par cellule) */
random_gsa: 
 addi sp, sp, -12 # Alloue l’espace pile
 sw ra, 0(sp) # Sauvegarde ra
 sw a0, 4(sp)
 li t0, 0 # y = 0
 
randomize_row:
 li t2, RANDOM # Adresse du générateur aléatoire
 lw t3, 0(t2) # Charge une valeur aléatoire 32 bits
 li t4, 0 # Accumulateur de la ligne (12 bits utiles)
 li t5, 12 # Nombre de bits à traiter

loop_bits:
 andi t6, t3, 1 # Bit de poids faible (mod 2)
 slli t4, t4, 1 # Déplace pour insérer le nouveau bit
 or t4, t4, t6 # Insère le bit (0 mort / 1 vivant)
 srli t3, t3, 1 # Prochain bit aléatoire
 addi t5, t5, -1 # Décrémente le compteur de bits
 bnez t5, loop_bits # Continue jusqu’à 12 bits

 mv a0, t4 # a0 = ligne construite
 mv a1, t0 # a1 = index de ligne (y)
 sw t0, 8(sp)
 call set_gsa # Écrit la ligne dans le GSA courant
 lw t0, 8(sp)

 addi t0, t0, 1 # y++
 li t5, 10 # 10 lignes dans le GSA
 blt t0, t5, randomize_row # Si y < 10, continuer

 lw ra, 0(sp) # Restaure ra
 lw a0, 4(sp)
 addi sp, sp, 12 # Libère la pile
 ret
/* END:random_gsa */
/* BEGIN:change_speed */
/* Modifie la vitesse du jeu :
 a0 = 0 → augmente la vitesse
 a0 = 1 → diminue la vitesse */
change_speed:
 li t0, SPEED # Adresse de la vitesse actuelle du jeu
 lw t1, 0(t0) # Charge la valeur actuelle de la vitesse (1 à 10)
 li t3, 1

 beq a0, zero, increase_speed # Si a0 == 0, aller à l’augmentation
 beq a0, t3, decrease_speed # Si a0 == 1, aller à la diminution
 ret # Sinon, rien à faire

increase_speed:
 li t2, 10 # Vitesse maximale = 10
 beq t1, t2, end_speed # Si déjà au max, ne pas modifier
 addi t1, t1, 1 # Incrémente la vitesse
 sw t1, 0(t0) # Met à jour la RAM
 j end_speed

decrease_speed:
 li t2, 1 # Vitesse minimale = 1
 ble t1, t2, end_speed # Si déjà au minimum, ne pas modifier
 addi t1, t1, -1 # Décrémente la vitesse
 sw t1, 0(t0) # Met à jour la RAM

end_speed:
 ret
/* END:change_speed */

/* BEGIN:pause_game */
/* Met le jeu en pause ou le reprend (inversion de l’état courant) */
pause_game:
 li t0, PAUSE # Adresse de la variable "pause"
 lw t1, 0(t0) # Charge la valeur actuelle (0 ou 1)
 li t2, 1
 xor t1, t1, t2 # Inverse la valeur (0↔️1)
 sw t1, 0(t0) # Sauvegarde le nouvel état
 ret
/* END:pause_game */

/* BEGIN:change_steps */
/* Incrémente les chiffres du compteur d’étapes (CURR_STEP) selon les boutons :
 - a0 = bouton unités (BUTTON_0)
 - a1 = bouton dizaines (BUTTON_1)
 - a2 = bouton centaines (BUTTON_2) */
change_steps:
 li t0, CURR_STEP # Adresse du compteur d’étapes
 lw t1, 0(t0) # Valeur actuelle
 li t2, 0 # Position du chiffre (0, 4, 8 bits)
 li t3, 3 # 3 chiffres à traiter (centaines, dizaines, unités)

 # Combine les boutons actifs dans t4
 andi t4, a0, 1
 slli t5, a1, 1
 or t4, t4, t5
 slli t5, a2, 2
 or t4, t4, t5

steps_loop:
 andi t5, t4, 0x1 # Vérifie si le bouton courant est pressé
 beqz t5, skip_increment # Si non, passer au suivant

 srl t5, t1, t2 # Extrait le chiffre courant
 andi t5, t5, 0xF # Isole le chiffre (4 bits)
 addi t5, t5, 1 # Incrémente le chiffre
 andi t5, t5, 0xF # Reste dans la base 16 (0-F)

 li t6, 0xF
 sll t6, t6, t2 # Prépare le masque d’effacement du chiffre courant
 not t6, t6
 and t1, t1, t6 # Efface le chiffre existant
 sll t5, t5, t2 # Replace le chiffre incrémenté
 or t1, t1, t5 # Écrit la nouvelle valeur

skip_increment:
 addi t2, t2, 4 # Passe au chiffre suivant (+4 bits)
 srli t4, t4, 1 # Passe au bouton suivant
 addi t3, t3, -1
 bne t3, zero, steps_loop # Répéter pour 3 chiffres

 sw t1, 0(t0) # Sauvegarde la nouvelle valeur
 ret
/* END:change_steps */

/* BEGIN:set_seed */
/* Copie une graine prédéfinie dans le GSA courant selon l’ID donné (a0) */
set_seed:
 addi sp, sp, -16 
 sw ra, 0(sp) 
 sw a0, 4(sp) 
 
 li t2, SEED 
 la t0, SEEDS # Base du tableau de graines
 slli t1, a0, 2 # a0 * 4 = décalage vers la graine correspondante
 add t0, t0, t1
 lw t0, 0(t0) # t0 = adresse de la graine choisie
 li t1, 0 # Index de ligne
 li t3, N_SEEDS
 bgeu a0, t3, set_random # Si ID >= nombre de graines, passer à l’aléatoire

set_seed_loop:
 lw t2, 0(t0) # Charge la ligne de la graine
 mv a0, t2 # a0 = ligne
 mv a1, t1 # a1 = index de ligne
 sw t0, 8(sp)
 sw t1, 12(sp)
 jal set_gsa # Écrit la ligne dans le GSA courant
 lw t0, 8(sp)
 lw t1, 12(sp)

 addi t0, t0, 4 # Ligne suivante
 addi t1, t1, 1
 li t3, 10
 blt t1, t3, set_seed_loop # Répéter jusqu’à 10 lignes

set_random:
 lw ra, 0(sp)
 lw a0, 4(sp)
 addi sp, sp, 16
 ret
/* END:set_seed */

/* BEGIN:increment_seed */
/* Passe à la graine suivante ou génère une graine aléatoire si nécessaire */
increment_seed:
 addi sp, sp, -8
 sw ra, 0(sp)
 sw a0, 4(sp)

 li t0, CURR_STATE # État du jeu
 lw t1, 0(t0)
 li t3, SEED
 lw t4, 0(t3) # ID de graine actuelle

 li t2, INIT
 beq t1, t2, handle_init # Si état INIT → gérer comme initialisation

 li t5, N_SEEDS # Nombre total de graines disponibles
 beq t4, t5, handle_rand # Si ID == N_SEEDS → aléatoire

handle_init:
 li t6, 3
 beq t4, t6, handle_rand # Si dernière graine → aléatoire
 addi t4, t4, 1 # Passe à la graine suivante
 sw t4, 0(t3) # Met à jour l’ID
 mv a0, t4
 call set_seed # Charge la nouvelle graine dans le GSA
 j end_increment_seed

handle_rand:
 jal random_gsa # Génère un GSA aléatoire

end_increment_seed:
 lw ra, 0(sp)
 lw a0, 4(sp)
 addi sp, sp, 8
 ret
/* END:increment_seed */
/* BEGIN:update_state */
/* Met à jour l’état global du jeu en fonction des boutons pressés */
update_state:
 addi sp, sp, -4
 sw ra, 0(sp)

 li t0, CURR_STATE # Adresse de l’état actuel du jeu
 lw t1, 0(t0) # Charge l’état courant

 li t2, INIT # Si INIT
 beq t1, t2, check_init_state
 li t2, RAND # Si RAND
 beq t1, t2, check_rand_state
 li t2, RUN # Si RUN
 beq t1, t2, check_run_state
 j end_update_state

check_init_state:
 andi s1, a0, JC # Vérifie JC (changer de graine)
 bnez s1, increment_jc_count
 andi s1, a0, JR # Vérifie JR (lancer le jeu)
 bnez s1, transition_to_run
 j end_update_state

check_rand_state:
 andi s1, a0, JC # JC = nouvelle graine aléatoire
 andi s1, a0, JR # JR = passer à l’exécution
 bnez s1, transition_to_run
 j end_update_state

check_run_state:
 andi s1, a0, JB # JB = réinitialiser
 bnez s1, reset_game_to_init
 j end_update_state

increment_jc_count:
 li t4, N_SEEDS # Nombre total de graines prédéfinies
 li t2, SEED
 lw t3, 0(t2)
 bgeu t3, t4, transition_to_rand # Si on a dépassé les graines → RAND
 j end_update_state

transition_to_rand:
 li t2, RAND
 sw t2, 0(t0)
 j end_update_state

transition_to_run:
 li t2, RUN
 sw t2, 0(t0)
 j end_update_state

reset_game_to_init:
 call reset_game

end_update_state:
 lw ra, 0(sp)
 addi sp, sp, 4
 ret
/* END:update_state */

/* BEGIN:select_action */
/* Exécute une action en fonction de l’état courant et du bouton pressé */
select_action:
 addi sp, sp, -8
 sw ra, 0(sp)
 sw a0, 4(sp)

 li t0, CURR_STATE
 lw t1, 0(t0)

 li t2, INIT
 beq t1, t2, handle_init_state
 li t2, RAND
 beq t1, t2, handle_rand_state
 li t2, RUN
 beq t1, t2, handle_run_state
 j end_select_action

# --- État INIT ---
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
 j end_select_action

# --- État RAND ---
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
 j end_select_action

# --- État RUN ---
handle_run_state:
 andi t5, a0, JC # JC = pause / reprise
 bnez t5, start_game
 andi t5, a0, JR # JR = vitesse +
 bnez t5, increase_speed_action
 andi t5, a0, JL # JL = vitesse -
 bnez t5, decrease_speed_action
 andi t5, a0, JB # JB = reset
 bnez t5, end_select_action
 andi t5, a0, JT # JT = GSA aléatoire
 bnez t5, replace_with_random_gsa
 j end_select_action

# --- Actions associées ---
cycle_seed:
 call increment_seed
 j end_select_action

start_game:
 jal pause_game
 j end_select_action

change_steps_units:
 li a0, 1
 li a1, 0
 li a2, 0
 jal change_steps
 j end_select_action

change_steps_tens:
 li a1, 1
 li a0, 0
 li a2, 0
 jal change_steps
 j end_select_action

change_steps_hundreds:
 li a2, 1
 li a0, 0
 li a1, 0
 jal change_steps
 j end_select_action

increase_speed_action:
 li a0, 0
 jal change_speed
 j end_select_action

decrease_speed_action:
 li a0, 1
 jal change_speed
 j end_select_action

replace_with_random_gsa:
 jal random_gsa
 j end_select_action

end_select_action:
 lw ra, 0(sp)
 lw a0, 4(sp)
 addi sp, sp, 8
 ret
/* END:select_action */

/* BEGIN:cell_fate */
/* Détermine le futur d’une cellule selon le nombre de voisins vivants :
 - a0 = nombre de voisins
 - a1 = état actuel de la cellule (0 = morte, 1 = vivante)
 Retour : a0 = nouvel état (0 ou 1) */
cell_fate:
 addi sp, sp, -4
 sw ra, 0(sp)

 li t0, 3
 beq a0, t0, alive # 3 voisins → vivante

 li t0, 2
 beq a0, t0, check_alive # 2 voisins → dépend de l’état actuel

 li a0, 0 # <2 ou >3 voisins → morte
 j end_cell_fate

check_alive:
 beq a1, zero, dead # Si morte et 2 voisins → reste morte
 li a0, 1 # Si vivante et 2 voisins → reste vivante
 j end_cell_fate

alive:
 li a0, 1
 j end_cell_fate

dead:
 li a0, 0

end_cell_fate:
 lw ra, 0(sp)
 addi sp, sp, 4
 ret
/* END:cell_fate */

/* BEGIN:find_neighbours */
/* Calcule le nombre de voisins vivants d’une cellule (x=a0, y=a1)
 et retourne aussi l’état actuel de cette cellule */
find_neighbours:
 addi sp, sp, -24
 sw ra, 0(sp)

 mv s0, a0 # x
 mv s1, a1 # y
 li t0, 0 # compteur de voisins

 mv a0, s1 # a0 = y
 sw t0, 4(sp)
 jal get_gsa # récupère la ligne y
 lw t0, 4(sp)
 srl t1, a0, s0 # isole le bit x
 andi t1, t1, 1 # t1 = état de la cellule (0/1)

 li t2, -1 # delta_x
 li t3, -1 # delta_y

check_neighbour:
 add t4, s0, t2 # x voisin
 li t5, 12
 bge t4, t5, wrap_x_low
loop4:
 blt t4, zero, wrap_x_high
 j skip_wrap_x

wrap_x_low:
 li t4, 0
 j loop4

wrap_x_high:
 li t4, 11

skip_wrap_x:
 add t5, s1, t3 # y voisin
 li t6, 10
 bge t5, t6, wrap_y_low
loop5:
 blt t5, zero, wrap_y_high
 j skip_wrap_y

wrap_y_low:
 li t5, 0
 j loop5

wrap_y_high:
 li t5, 9

skip_wrap_y:
 mv a0, t5
 sw t0, 4(sp)
 sw t4, 8(sp)
 sw t1, 12(sp)
 sw t2, 16(sp)
 sw t3, 20(sp)
 jal get_gsa
 lw t0, 4(sp)
 lw t4, 8(sp)
 lw t1, 12(sp)
 lw t2, 16(sp)
 lw t3, 20(sp)

 srl t6, a0, t4
 andi t6, t6, 1
 add t0, t0, t6 # compte si voisin vivant

 addi t2, t2, 1
 li t4, 2
 bgeu t2, t4, reset_x
 j check_neighbour

reset_x:
 li t2, -1
 addi t3, t3, 1
 blt t3, t4, check_neighbour

 mv a0, t0
 mv a1, t1
 bne a1, zero, minus_1
 j end_find_neighbours

minus_1:
 beq a0, zero, end_find_neighbours
 addi a0, a0, -1

end_find_neighbours:
 lw ra, 0(sp)
 addi sp, sp, 24
 ret
/* END:find_neighbours */

/* BEGIN:update_gsa */
/* Calcule la prochaine génération du GSA selon les règles du jeu */
update_gsa:
 addi sp, sp, -20
 sw ra, 0(sp)
 sw a0, 4(sp)

 li t0, PAUSE
 lw t1, 0(t0)
 li t2, 1
 bne t1, t2, end_update_gsa # Si le jeu est en pause, quitter

 li t0, 0 # y = 0

gsa_update_loop:
 mv a0, t0
 sw t0, 8(sp)
 jal get_gsa
 lw t0, 8(sp)
 mv s0, a0 # ligne actuelle

 li t1, 0 # x = 0
 
update_gsa_columns:
 mv a0, t1
 mv a1, t0

 sw t0, 8(sp)
 sw t1, 12(sp)
 sw s0, 16(sp)
 call find_neighbours
 lw t0, 8(sp)
 lw t1, 12(sp)
 lw s0, 16(sp)

 sw t0, 8(sp)
 sw t1, 12(sp)
 call cell_fate
 lw t0, 8(sp)
 lw t1, 12(sp)

 li t2, 1
 sll t2, t2, t1
 sll a0, a0, t1
 not t2, t2
 and s0, s0, t2
 or s0, s0, a0

 addi t1, t1, 1
 li t2, 12
 bltu t1, t2, update_gsa_columns

 mv a0, s0
 mv a1, t0

 li t2, GSA_ID
 lw t3, 0(t2)
 xori t3, t3, 1
 sw t3, 0(t2)

 sw t0, 8(sp)
 sw t2, 12(sp)
 jal set_gsa
 lw t0, 8(sp)
 lw t2, 12(sp)

 lw t3, 0(t2)
 xori t3, t3, 1
 sw t3, 0(t2)

 addi t0, t0, 1
 li t1, 0
 li t2, 10
 bltu t0, t2, gsa_update_loop

invert_gsa:
 li t2, GSA_ID
 lw t3, 0(t2)
 xori t3, t3, 1
 sw t3, 0(t2)

end_update_gsa:
 lw ra, 0(sp)
 lw a0, 4(sp)
 addi sp, sp, 20
 ret
/* END:update_gsa */
/* BEGIN:get_input */
/* Lit la valeur du registre des boutons et la retourne dans a0.
 Si plusieurs boutons sont pressés, seul le bit le moins significatif est conservé. */
get_input:
 addi sp, sp, -4
 sw ra, 0(sp)
 li t0, BUTTONS # Adresse du registre des boutons
 lw a0, 0(t0) # Lecture des boutons dans a0

 li t1, 0x1 # Masque de départ (bit 0)

get_lsb:
 and t2, a0, t1 # Test du bit courant
 bnez t2, return_input # Si trouvé, retour
 slli t1, t1, 1 # Passe au bit suivant
 bnez a0, get_lsb # Continue si d'autres bits actifs

return_input:
 sw zero, 0(t0) # Réinitialise le registre des boutons
 lw ra, 0(sp)
 addi sp, sp, 4
 ret
/* END:get_input */

/* BEGIN:decrement_step */
/* Décrémente le compteur d’étapes (CURR_STEP) et met à jour l’afficheur 7 segments.
 Retourne a0 = 1 si terminé, sinon a0 = 0. */
decrement_step:
 addi sp, sp, -8
 sw ra, 0(sp)
 sw t0, 4(sp)

 li t0, CURR_STEP
 lw t1, 0(t0)
 li t2, PAUSE
 lw t4, 0(t2)
 li t3, 1
 bne t4, t3, display # Si jeu non en cours, juste afficher

 beqz t1, case_0 # Si 0, terminé
 addi t1, t1, -1 # Sinon décrémenter
 sw t1, 0(t0)

display:
 li t6, 0 # Compteur de digits
 li t2, 4 # Nombre de digits (7-seg = 4)
 li t0, 0 # Résultat final
 la t3, font_data # Table des caractères

digits_loop:
 andi t5, t1, 0xF # Extrait un chiffre (4 bits)
 slli t5, t5, 2 # *4 pour indexer la table
 add t4, t5, t3
 lw t5, 0(t4) # Charge le pattern du chiffre
 sll t5, t5, t6 # Décale pour placer au bon digit
 or t0, t0, t5 # Ajoute au mot de sortie
 srli t1, t1, 4 # Passe au chiffre suivant
 addi t6, t6, 8 # Décalage suivant (8 bits)
 addi t2, t2, -1
 bnez t2, digits_loop

 li t6, SEVEN_SEGS
 sw t0, 0(t6) # Affiche sur le 7-segment
 li a0, 0 # Indique que le jeu continue
 j end_decrement_step

case_0:
 li a0, 1 # Étapes terminées

end_decrement_step:
 lw ra, 0(sp)
 lw t0, 4(sp)
 addi sp, sp, 8
 ret
/* END:decrement_step */

/* BEGIN:reset_game */
/* Réinitialise complètement le jeu à son état initial :
 - CURR_STATE = INIT
 - CURR_STEP = 1
 - PAUSE = 0
 - GSA = graine 0
 - GSA_ID = 0
 - SPEED = 1 */
reset_game:
 addi sp, sp, -4
 sw ra, 0(sp)

 li t0, CURR_STATE
 li t2, INIT
 sw t2, 0(t0)

 li t0, CURR_STEP
 li t1, 1
 sw t1, 0(t0)

 li t0, PAUSE
 li t1, 0
 sw t1, 0(t0)

 call decrement_step # Met à jour l’afficheur
 call clear_leds # Efface toutes les LEDs

 li t1, 0 # Graine 0
 mv a0, t1
 li t2, SEED
 sw a0, 0(t2)
 jal set_seed # Charge la graine 0
 jal draw_gsa # Affiche le GSA

 li t0, GSA_ID
 li t1, 0
 sw t1, 0(t0)

 li t0, SPEED
 li t1, 1
 sw t1, 0(t0)

 lw ra, 0(sp)
 addi sp, sp, 4
 ret
/* END:reset_game */

/* BEGIN:mask */
/* Applique le masque correspondant à la graine actuelle :
 - Rend les murs bleus sur les LEDs.
 - Garantit que les murs restent toujours morts dans le GSA. */
mask:
 addi sp, sp, -16
 sw ra, 0(sp)
 sw a0, 4(sp)

 li t0, GSA_ID
 lw t1, 0(t0)

 li t0, SEED
 lw t2, 0(t0)
 li t4, N_SEEDS
 la t3, MASKS

 bltu t2, t4, continue
 li t2, 4 # Masque aléatoire = dernier masque

continue:
 slli t2, t2, 2
 add t3, t3, t2
 lw t3, 0(t3) # t3 = adresse du masque choisi
 li t0, 0 # y = 0
 call mask_loop

mask_loop:
 mv a0, t0
 sw t0, 8(sp)
 sw t3, 12(sp)
 jal get_gsa
 lw t0, 8(sp)
 lw t3, 12(sp)

 lw t2, 0(t3) # Charge la ligne de masque
 and a0, a0, t2 # Applique le masque (0 = mur)
 mv a1, t0
 sw t0, 8(sp)
 sw t2, 12(sp)
 jal set_gsa
 lw t0, 8(sp)
 lw t2, 12(sp)

 li t4, LEDS
 slli t5, t0, 4
 addi t5, t5, 0xF
 li t6, 0x1
 slli t6, t6, 10 # Couleur bleue
 or t5, t5, t6
 not t2, t2
 slli t2, t2, 16
 add t5, t5, t2
 sw t5, 0(t4) # Affiche la ligne bleue des murs

 addi t0, t0, 1
 addi t3, t3, 4
 li t2, 10
 blt t0, t2, mask_loop

 lw ra, 0(sp)
 lw a0, 4(sp)
 addi sp, sp, 16
 ret
/* END:mask */

/* Table de conversion pour l’afficheur 7 segments */
font_data:
 .word 0x3F # 0
 .word 0x06 # 1
 .word 0x5B # 2
 .word 0x4F # 3
 .word 0x66 # 4
 .word 0x6D # 5
 .word 0x7D # 6
 .word 0x07 # 7
 .word 0x7F # 8
 .word 0x6F # 9
 .word 0x77 # A
 .word 0x7C # B
 .word 0x39 # C
 .word 0x5E # D
 .word 0x79 # E
 .word 0x71 # F

/* --- GRAINES PRÉDÉFINIES --- */
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

/* Tableau des graines */
SEEDS:
 .word seed0
 .word seed1
 .word seed2
 .word seed3

/* --- MASQUES DES MURS --- */
mask0:
 .rept 10
 .word 0xFFF
 .endr

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
 .rept 10
 .word 0x7FF
 .endr

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

/* Tableau des masques */
MASKS:
 .word mask0
 .word mask1
 .word mask2
 .word mask3
 .word mask4