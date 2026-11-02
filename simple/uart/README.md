# uart

UART adds transmit and receive shift FSMs, a baud divider, and small flip-flop FIFOs. It is still one clock, with no SRAM macro and no crypto datapath.

| | |
| --- | --- |
| Category | `simple` |
| Top module | `uart` |
| Complexity | 2 of 5. Still a small peripheral, a step up from GPIO because of the line FSMs. |
| Source files | 45 (10714 lines) |
| Include files | 7 |
| Upstream | `hw/ip/uart/uart.core` |

This directory is a closed, synthesizable RTL drop. It contains the OpenTitan IP and the generic primitives, TileLink, and packages that the top actually elaborates. Technology-specific primitives (Xilinx, ASAP7) are not included. `prim_flop` and the other `prim_*` leaf cells are the generic implementations, so a standard-cell library can map them.

The RTL is unmodified from OpenTitan `ccffab942d75b44fd7f319cc5d53e94a0452385d` (2026-11-02). License: Apache-2.0. See `source_manifest.tsv` for the upstream path of every file, and the repository `LICENSE`.

## Clocks and resets

- `clk_i`, starting period 10.0 ns. Functional clock. Baud rate is divided down inside the block.

Resets, all asynchronous and active-low: `rst_ni`.

## Memory

None. This block does not instantiate an SRAM.

## How to run it

Elaborate `uart` with `SYNTHESIS` defined, and put `rtl/include` on the include path. `filelist.f` already carries both:

```
+define+SYNTHESIS
+incdir+rtl/include
```

`sources.f` is the same list without those directives, for tools whose file reader does not accept `+define` or `+incdir`.

`SYNTHESIS` selects the empty assertion macros in `prim_assert.sv`. Leave it defined for synthesis and for the gate-level netlist you hand to place and route. Do not define `SIMULATION`. That macro turns `prim_cdc_rand_delay` into a randomized delay model (`$urandom`), which is not synthesizable. Without `SIMULATION` the cell is a wire. Do not define `SYNTHESIS_MEMORY_BLACK_BOXING`.

Recommended block-level flow:

1. Analyze `filelist.f` in order. Packages are first because several tools require that.
2. Elaborate `uart` with the default parameters.
3. Read `constraints/uart.sdc`.
4. In the SDC, uncomment `set_driving_cell` and name a buffer from your library. It is commented out so the file loads before a library is attached.
5. Compile to your standard-cell library. These drops do not instantiate `prim_clock_gating`. Turn on the tool clock-gating pass if you want integrated clock gates inserted on enabled flops.
6. Place and route the mapped netlist. The RTL uses packed structs for TileLink, alerts, and a few sideband bundles. Those structs are gone once the netlist is structural, which is what the P&R tool should read.

Design Compiler sketch, from this directory:

```tcl
set search_path [concat rtl/include $search_path]
analyze -format sverilog -define SYNTHESIS -vcs "-f filelist.f"
elaborate uart
link
read_sdc constraints/uart.sdc
compile_ultra
```

Genus sketch:

```tcl
set_db init_hdl_search_path {rtl/include}
read_hdl -sv -define SYNTHESIS -f filelist.f
elaborate uart
read_sdc constraints/uart.sdc
syn_generic
syn_map
```

If your analyzer rejects `+define` inside `filelist.f`, use `sources.f` and pass the define and the include directory as tool flags. The file order is the same.

## Place-and-route notes

- Single clock domain. The baud tick is generated internally. Do not create a second clock for TX or RX.
- `cio_rx_i`, `cio_tx_o`, and `cio_tx_en_o` are the pad-facing pins. The line drivers themselves are outside this block.
- FIFOs are `prim_fifo` flip-flop FIFOs, not SRAMs. Expect them to map entirely to flops.
- Interrupt outputs are single-cycle levels registered in `clk_i`. Time them as normal outputs.

Constraint file: `constraints/uart.sdc`.

- Periods are starting points for a first timing run in whatever library you load. Re-time the block after you see real slack. Nothing here was closed in a physical library.
- I/O delays are 40% of the primary period. Replace them with the budget from the surrounding SoC before you trust WNS.
- `set_driving_cell` is commented out so this SDC loads before a library is attached. Uncomment it and name a buffer from your library before you trust input slew.
- Resets are cut with `set_false_path`. Add a reset-buffer tree when you do real DFT and power-up sequencing.
- No scan chains are inserted. Scan and clock-gate test-enable hookup are later DFT steps on the mapped netlist.

## Interfaces the P&R boundary will see

- `tl_i`, `tl_o`: TileLink-UL host port (`tlul_pkg::tl_h2d_t`, `tlul_pkg::tl_d2h_t`). This drop does not include a crossbar. Constrain the struct members as data.
- Alert bundles where the IP has them: differential alert sender pins, one or two alerts.
- RACL policy pins where the IP has them. With the default `EnableRacl` of 0 on GPIO, UART, and I2C, the internal checker is parameterized off, but the ports remain on the top.
- The IP's own functional pins (GPIO bits, UART TX/RX, I2C SCL/SDA, HMAC sideload and idle, AES key and entropy). See the top module header in `rtl/src/uart.sv`.

## What was verified

The file list elaborates under Verilator 5.050 with `verilator --lint-only -Wno-WIDTHEXPAND --top-module uart -f filelist.f`. That run exits cleanly, so the drop is closed. Verilator also reports `WIDTHEXPAND` on a few comparisons (the alert skew counter, and UART or HMAC FIFO level checks where those blocks are present). Those are upstream OpenTitan lint warnings, not missing modules, and `-Wno-WIDTHEXPAND` matches the usual waiver. This is not a timing or DRC result. No standard-cell library, synthesis, or place-and-route was run.
