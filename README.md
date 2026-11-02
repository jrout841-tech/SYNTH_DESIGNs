# SYNTH_DESIGNs

Five synthesizable OpenTitan blocks, packaged so a physical-design team can run synthesis and place-and-route without the rest of the OpenTitan tree.

These are RTL drops, not mapped gate-level netlists. A place-and-route tool needs a netlist in your standard-cell library. Synthesize the RTL here, then place and route the mapped netlist. No cell library was available when this repository was built, so the RTL was not mapped.

## Categories

The split follows what changes a P&R run, not the software-visible feature set.

| Directory | Top | Sources | Lines | Starting clocks | Memory |
| --- | --- | --- | --- | --- | --- |
| `simple/gpio` | `gpio` | 40 | 18120 | `clk_i` 10 ns | none |
| `simple/uart` | `uart` | 45 | 10714 | `clk_i` 10 ns | none |
| `medium/i2c` | `i2c` | 59 | 17558 | `clk_i` 10 ns | 464 x 13 SRAM |
| `medium/hmac` | `hmac` | 53 | 17299 | `clk_i` 12 ns | none |
| `complex/aes` | `aes` | 93 | 29221 | `clk_i` 15 ns, `clk_edn_i` 20 ns | none |

**Simple.** `gpio` and `uart`. One clock, no SRAM, control and pin logic only. GPIO is the smaller of the two (32-pin register file, filters, interrupts). UART adds baud and shift FSMs and flop FIFOs.

**Medium.** `i2c` and `hmac`. I2C is protocol control (controller, target, bus monitor) plus one 464 x 13 SRAM. HMAC is a wide SHA-2 256/384/512 datapath with no SRAM. HMAC is the heavier medium block.

**Complex.** `aes`. Masked AES-128/192/256 with CTR and GCM, two clocks (`clk_i` and `clk_edn_i`), life-cycle and entropy sidebands, and a much larger combinational cloud in the DOM S-box.

Line counts include the generated register file and shared packages such as `prim_secded_pkg` and `prim_mubi_pkg`. GPIO has more lines than UART because its 32-pin register file is generated per pin. The category is the P&R problem (clocks, memory, datapath, control), not the line count.

Each design directory is self-contained. Shared OpenTitan primitives are copied into every design that uses them, so you can synthesize one block without setting up the others.

## What is in a design directory

| Path | Purpose |
| --- | --- |
| `README.md` | Top, clocks, memories, tool sketch, P&R notes |
| `filelist.f` | Ordered SystemVerilog list, with `+define+SYNTHESIS` and `+incdir` |
| `sources.f` | Same files, no tool directives |
| `rtl/src` | Compilation units |
| `rtl/include` | `` `include `` files (`prim_assert.sv` and the memory-load header) |
| `constraints/<top>.sdc` | Starting clocks, I/O delays, reset false path |
| `source_manifest.tsv` | Upstream path of every shipped file |

Primitives are the generic implementations (`prim_generic`), so flops, buffers, and the I2C RAM are behavioral and mappable. These five blocks do not instantiate `prim_clock_gating`. Xilinx and ASAP7 leaves are not in the file list.

## Synthesis flags

Define `SYNTHESIS`. That turns OpenTitan assertions into empty macros. Do not define `SIMULATION`, or `prim_cdc_rand_delay` becomes a `$urandom` model. Do not define `SYNTHESIS_MEMORY_BLACK_BOXING`. That macro strips the memory model and leaves RAM outputs undriven.

Do not compile `rtl/include` as separate compilation units. Those files are included.

## Upstream and license

Unmodified RTL from the OpenTitan project, commit `ccffab942d75b44fd7f319cc5d53e94a0452385d` (2026-11-02):

https://github.com/lowRISC/opentitan/tree/ccffab942d75b44fd7f319cc5d53e94a0452385d

Licensed under the Apache License, Version 2.0. See `LICENSE` and `NOTICE`. Copyright headers in the RTL are unchanged. File lists, constraints, and these READMEs were added to make each block a standalone P&R experiment. They are not part of upstream OpenTitan.

Earl Grey is the top used where a block is generated per chip. GPIO in this drop is the Earl Grey autogen with `NumIOs` of 32.
