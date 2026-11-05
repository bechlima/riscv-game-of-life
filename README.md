# Game of Life in RISC-V Assembly

Conway's Game of Life in bare-metal RV32I assembly, for the memory-mapped LED-matrix board used in EPFL CS-200 (Computer Architecture), autumn 2025.

## Features
- 12×10 grid stored in two game-state arrays (GSA0/GSA1) that alternate each generation, with wrap-around neighbour counting
- Rendering to the LED matrix through memory-mapped I/O, plus a step counter on the seven-segment displays
- Button-driven state machine with **INIT** (choose or seed a pattern), **RAND** (random board) and **RUN** (simulate) states
- Run-time controls for speed, pause, step count (with decimal carry on the display) and seeding
- Random boards from a memory-mapped random-number source, plus 4 preset seed patterns

All code is in `game_of_life.s`. Memory-mapped addresses such as `LEDS = 0x50000000`, `SEVEN_SEGS = 0x60000000` and `BUTTONS = 0x70000004` are defined at the top of the file.

## Build
Needs a RISC-V GNU toolchain (`riscv64-unknown-linux-gnu-gcc`, targeting `rv32i`/`ilp32`):

```bash
make assembly_game_of_life     # -> out/game_of_life.bin
```

The binary runs on the course's simulator or FPGA board. The `Dockerfile` is the course's reference environment (Arch Linux with the RISC-V toolchain and Verilator). It is kept for reference only, because the toolchain download link it uses may no longer work.

Toolchain files and the platform specification © EPFL CS-200 course staff.
