# risc-v-snake 🐍

snake game written in risc-v assembly, running on a custom 32-bit processor designed in verilog. runs on a **digilent arty a7-100t fpga** and produces graphics through vga.

### cpu
- custom risc-v 32-bit processor (rv32i base instruction set)
- multi-cycle architecture, 100 mhz clock
- instruction decoder, alu, register file, control logic
- instruction rom and 8 kib data ram
- mmio for buttons, leds, timer, random-number generator and vga graphics

### snake game
- assembly for rv32i
- 40 × 30 tile game board
- vga output at 640 × 480 resolution
- movement using fpga buttons
- classic snake game mechanics
- game restarts using rst 

### graphics
- vga output using a pmod module
- 16 × 16 pixel tiles
- tile memory for storing the game board

## repository structure

```text
RVSnake/
├── assembler/        # python assembler
├── constraints/      # pin and timing constraints
├── design sources/   # verilog modules
├── game code/        # assembly program
└── instructions/     # machine code
```

## controls

btn0 – right
btn1 – left
btn2 – up
btn3 – down

## implementation

1. open the project in vivado
2. add sources and constraints
3. load program.hex
4. synthesis, implementation, bitstream
