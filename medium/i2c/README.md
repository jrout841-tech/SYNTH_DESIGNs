# i2c

I2C has a controller FSM, a target FSM, a bus monitor, clock stretching, and four logical FIFOs packed into one synchronous 1-port SRAM (464 words by 13 bits). That mix of control and a real memory is a useful mid-size P&R case.

| | |
| --- | --- |
| Category | `medium` |
| Top module | `i2c` |
| Complexity | 3 of 5. Protocol control plus one small SRAM. |
| Source files | 59 (17558 lines) |
| Include files | 8 |
| Upstream | `hw/ip/i2c/i2c.core` |

This directory is a closed, synthesizable RTL drop. It contains the OpenTitan IP and the generic primitives, TileLink, and packages that the top actually elaborates. Technology-specific primitives (Xilinx, ASAP7) are not included. `prim_flop` and the other `prim_*` leaf cells are the generic implementations, so a standard-cell library can map them.

The RTL is unmodified from OpenTitan `ccffab942d75b44fd7f319cc5d53e94a0452385d` (2026-11-02). License: Apache-2.0. See `source_manifest.tsv` for the upstream path of every file, and the repository `LICENSE`.

## Clocks and resets

- `clk_i`, starting period 10.0 ns. Functional clock. SCL is an oversampled data pin, not a clock port.

Resets, all asynchronous and active-low: `rst_ni`.

## Memory

One synchronous 1-port SRAM, 464 x 13, ECC off, 1-cycle read latency.

- Wrapper: `i2c_core/u_fifos/u_ram_1p`
- Leaf to swap or infer: `i2c_core/u_fifos/u_ram_1p/gen_ram_inst[0].u_mem` (`prim_ram_1p`)

## How to run it

Elaborate `i2c` with `SYNTHESIS` defined, and put `rtl/include` on the include path. `filelist.f` already carries both:

```
+define+SYNTHESIS
+incdir+rtl/include
```

`sources.f` is the same list without those directives, for tools whose file reader does not accept `+define` or `+incdir`.

`SYNTHESIS` selects the empty assertion macros in `prim_assert.sv`. Leave it defined for synthesis and for the gate-level netlist you hand to place and route. Do not define `SIMULATION`. That macro turns `prim_cdc_rand_delay` into a randomized delay model (`$urandom`), which is not synthesizable. Without `SIMULATION` the cell is a wire. Do not define `SYNTHESIS_MEMORY_BLACK_BOXING`.

Recommended block-level flow:

1. Analyze `filelist.f` in order. Packages are first because several tools require that.
2. Elaborate `i2c` with the default parameters.
3. Read `constraints/i2c.sdc`.
4. In the SDC, uncomment `set_driving_cell` and name a buffer from your library. It is commented out so the file loads before a library is attached.
5. Compile to your standard-cell library. These drops do not instantiate `prim_clock_gating`. Turn on the tool clock-gating pass if you want integrated clock gates inserted on enabled flops.
6. Place and route the mapped netlist. The RTL uses packed structs for TileLink, alerts, and a few sideband bundles. Those structs are gone once the netlist is structural, which is what the P&R tool should read.

Design Compiler sketch, from this directory:

```tcl
set search_path [concat rtl/include $search_path]
analyze -format sverilog -define SYNTHESIS -vcs "-f filelist.f"
elaborate i2c
link
read_sdc constraints/i2c.sdc
compile_ultra
```

Genus sketch:

```tcl
set_db init_hdl_search_path {rtl/include}
read_hdl -sv -define SYNTHESIS -f filelist.f
elaborate i2c
read_sdc constraints/i2c.sdc
syn_generic
syn_map
```

If your analyzer rejects `+define` inside `filelist.f`, use `sources.f` and pass the define and the include directory as tool flags. The file order is the same.

## Place-and-route notes

- Treat `cio_scl_*` and `cio_sda_*` as data I/O. The bus clock is oversampled by `clk_i`. Creating a clock on SCL will fight the RTL.
- The only hard memory is the 464 x 13 FIFO SRAM. Two practical choices: leave `prim_ram_1p` behavioral and let synthesis infer a small memory or flops, or replace that leaf with a foundry macro of depth 464 and width 13 (or the next larger compilable macro) and keep the 1-cycle read latency.
- Do not define `SYNTHESIS_MEMORY_BLACK_BOXING`. That macro empties `prim_ram_1p` and leaves the read data undriven. It is an OpenTitan elaboration shortcut, not a P&R black box.
- `ram_cfg_i` / `ram_cfg_o` are the memory configuration struct. Tie the request side off if the macro has no equivalent pins, and leave the response side unused.
- FIFO depths in this RTL are `FifoDepth` 64 and `AcqFifoDepth` 268, packed into the single RAM by `i2c_fifos`.

Constraint file: `constraints/i2c.sdc`.

- Periods are starting points for a first timing run in whatever library you load. Re-time the block after you see real slack. Nothing here was closed in a physical library.
- I/O delays are 40% of the primary period. Replace them with the budget from the surrounding SoC before you trust WNS.
- `set_driving_cell` is commented out so this SDC loads before a library is attached. Uncomment it and name a buffer from your library before you trust input slew.
- Resets are cut with `set_false_path`. Add a reset-buffer tree when you do real DFT and power-up sequencing.
- No scan chains are inserted. Scan and clock-gate test-enable hookup are later DFT steps on the mapped netlist.

## Interfaces the P&R boundary will see

- `tl_i`, `tl_o`: TileLink-UL host port (`tlul_pkg::tl_h2d_t`, `tlul_pkg::tl_d2h_t`). This drop does not include a crossbar. Constrain the struct members as data.
- Alert bundles where the IP has them: differential alert sender pins, one or two alerts.
- RACL policy pins where the IP has them. With the default `EnableRacl` of 0 on GPIO, UART, and I2C, the internal checker is parameterized off, but the ports remain on the top.
- The IP's own functional pins (GPIO bits, UART TX/RX, I2C SCL/SDA, HMAC sideload and idle, AES key and entropy). See the top module header in `rtl/src/i2c.sv`.

## What was verified

The file list elaborates under Verilator 5.050 with `verilator --lint-only -Wno-WIDTHEXPAND --top-module i2c -f filelist.f`. That run exits cleanly, so the drop is closed. Verilator also reports `WIDTHEXPAND` on a few comparisons (the alert skew counter, and UART or HMAC FIFO level checks where those blocks are present). Those are upstream OpenTitan lint warnings, not missing modules, and `-Wno-WIDTHEXPAND` matches the usual waiver. This is not a timing or DRC result. No standard-cell library, synthesis, or place-and-route was run.
