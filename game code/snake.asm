
# snake for 640x480 VGA, 40x30 tiles (16x16 pixels)
# BTN0 right, BTN1 left, BTN2 up, BTN3 down
# CPU RAM 0x0000-0x1fff; tile MMIO 0x2008; timer 0x2500; RNG 0x2504
# snake coordinates are tile indices stored as 32-bit words at RAM address 4*i.
# tile: 0 empty, 1 body, 2 head, 3 food, 4 wall.
# x19 return address for spawn_food
# x20 length, x21 head index, x22 food index, x23 direction
# x24 head x, x25 head y, x26 tile base, x27 timer base
# x28 previous tick, x31 tick interval; x1-x18 scratch

start:
    lui x26, 0x2
    addi x26, x26, 8          # graphics base 0x2008
    lui x27, 0x2
    addi x27, x27, 1280       # timer base 0x2500
    lui x31, 0x2FAF
    addi x31, x31, 128       # 2,000,000 clocks = 20 ms

    # fill tile memory with empty cells and walls
    addi x1, x0, 0            # tile index
    addi x2, x0, 0            # current column
    add x3, x26, x0           # write pointer
    addi x4, x0, 1200         # tile count
    addi x5, x0, 40           # row width
    addi x6, x0, 1160         # first tile of last row
    addi x7, x0, 39           # last column
    addi x8, x0, 4            # wall tile type

clear_board:
    bltu x1, x5, draw_wall
    bgeu x1, x6, draw_wall
    beq x2, x0, draw_wall
    beq x2, x7, draw_wall
    sb x0, 0(x3)
    jal x0, clear_next

draw_wall:
    sb x8, 0(x3)

clear_next:
    addi x1, x1, 1
    addi x2, x2, 1
    addi x3, x3, 1
    bne x2, x5, col_done
    addi x2, x0, 0

col_done:
    bltu x1, x4, clear_board

    # initial head at (20,15), index 620
    addi x20, x0, 1           # length
    addi x24, x0, 20
    addi x25, x0, 15
    addi x21, x0, 620
    addi x23, x0, 0           # stopped until a button press
    sw x21, 0(x0)             # snake[0] = head tile index
    add x1, x26, x21
    addi x2, x0, 2
    sb x2, 0(x1)

    jal x19, spawn_food
    lw x28, 0(x27)            # start time

main_loop:
    # read buttons and select direction; reject reversals
    lw x1, -1276(x27)         # buttons 0x2004, timer 0x2500
    andi x2, x1, 1
    bne x2, x0, choose_right
    andi x2, x1, 2
    bne x2, x0, choose_left
    andi x2, x1, 4
    bne x2, x0, choose_up
    andi x2, x1, 8
    bne x2, x0, choose_down
    jal x0, wait_tick

choose_right:
    addi x2, x0, 2
    beq x23, x2, wait_tick
    addi x23, x0, 1
    jal x0, wait_tick

choose_left:
    addi x2, x0, 1
    beq x23, x2, wait_tick
    addi x23, x0, 2
    jal x0, wait_tick

choose_up:
    addi x2, x0, 4
    beq x23, x2, wait_tick
    addi x23, x0, 3
    jal x0, wait_tick

choose_down:
    addi x2, x0, 3
    beq x23, x2, wait_tick
    addi x23, x0, 4

wait_tick:
    beq x23, x0, main_loop
    lw x1, 0(x27)
    sub x2, x1, x28
    bltu x2, x31, main_loop
    add x28, x1, x0

    # calculate new head coordinates
    add x5, x24, x0
    add x6, x25, x0
    addi x2, x0, 1
    beq x23, x2, move_right
    addi x2, x0, 2
    beq x23, x2, move_left
    addi x2, x0, 3
    beq x23, x2, move_up
    addi x6, x6, 1
    jal x0, check_walls

move_right:
    addi x5, x5, 1
    jal x0, check_walls

move_left:
    addi x5, x5, -1
    jal x0, check_walls

move_up:
    addi x6, x6, -1

check_walls:
    beq x5, x0, game_over
    beq x6, x0, game_over
    addi x2, x0, 39
    bgeu x5, x2, game_over
    addi x2, x0, 29
    bgeu x6, x2, game_over

    # new index = new_y*40 + new_x
    slli x7, x6, 5
    slli x8, x6, 3
    add x7, x7, x8
    add x7, x7, x5
    addi x10, x0, 0           # growth flag
    bne x7, x22, check_body
    addi x10, x0, 1

check_body:
    # Collision with tail is permitted if it moves away this tick.
    addi x1, x0, 0

body_loop:
    beq x1, x20, do_move
    slli x2, x1, 2
    lw x3, 0(x2)
    bne x3, x7, body_next
    bne x10, x0, game_over    # growing: tail stays
    addi x4, x20, -1
    bne x1, x4, game_over

body_next:
    addi x1, x1, 1
    jal x0, body_loop

do_move:
    # erase old tail unless food eaten
    bne x10, x0, paint_body
    addi x1, x20, -1
    slli x2, x1, 2
    lw x3, 0(x2)
    add x4, x26, x3
    sb x0, 0(x4)

paint_body:
    # turn previous head into body, unless length=1 and no growth
    addi x1, x0, 1
    bne x20, x1, paint_old_head
    beq x10, x0, shift_body

paint_old_head:
    add x4, x26, x21
    addi x3, x0, 1
    sb x3, 0(x4)

shift_body:
    # move snake[i] to snake[i+1], from tail toward head
    addi x1, x20, -1

shift_loop:
    slli x2, x1, 2
    lw x3, 0(x2)
    sw x3, 4(x2)
    addi x1, x1, -1
    bge x1, x0, shift_loop

    sw x7, 0(x0)
    add x21, x7, x0
    add x24, x5, x0
    add x25, x6, x0
    add x4, x26, x21
    addi x3, x0, 2
    sb x3, 0(x4)

    
    beq x10, x0, main_loop

    # food eaten, increase snake length
    addi x20, x20, 1

    # speed up by 20 ms after each food
    lui x11, 0x1E8
    addi x11, x11, 1152       # 2,000,000 clocks = 20 ms

    # minimum movement interval = 100 ms
    lui x12, 0x989
    addi x12, x12, 1664       # 10,000,000 clocks = 100 ms

    # only increase speed if above minimum interval
    bgeu x12, x31, speed_done

    sub x31, x31, x11
    bltu x31, x12, set_min_speed
    jal x0, speed_done

set_min_speed:
    add x31, x12, x0

speed_done:
    addi x1, x0, 1064
    beq x20, x1, game_over   # filled playable grid; win/end
    jal x19, spawn_food
    jal x0, main_loop


# Generate food in non-wall, unoccupied tile.
# Use x1-x4, x8-x9 only; preserve game-state registers and x19.

spawn_food:
food_retry:
    lw x1, 4(x27)            # random x
    andi x2, x1, 63
    beq x2, x0, food_retry
    addi x3, x0, 39
    bgeu x2, x3, food_retry
    lw x1, 4(x27)            # random y
    andi x3, x1, 31
    beq x3, x0, food_retry
    addi x4, x0, 29
    bgeu x3, x4, food_retry
    slli x8, x3, 5
    slli x9, x3, 3
    add x8, x8, x9
    add x8, x8, x2
    addi x1, x0, 0

food_check:
    beq x1, x20, food_place
    slli x3, x1, 2
    lw x4, 0(x3)
    beq x4, x8, food_retry
    addi x1, x1, 1
    jal x0, food_check

food_place:
    add x22, x8, x0
    add x4, x26, x22
    addi x3, x0, 3
    sb x3, 0(x4)
    jalr x0, 0(x19)

game_over:
    addi x1, x0, 15
    sw x1, -1280(x27)        # all LEDs on

stopped:
    jal x0, stopped
