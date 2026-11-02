# hmac

HMAC wraps the OpenTitan multi-mode SHA-2 engine (256, 384, and 512) plus the HMAC key path. The datapath is much wider than UART or I2C, and the structure is regular arithmetic rather than the masked, multi-FSM AES subsystem.

| | |
| --- | --- |
| Category | `medium` |
| Top module | `hmac` |
| Complexity | 4 of 5. Heavier medium block. Wide and regular datapath. |
| Source files | 53 (17299 lines) |
| Include files | 7 |
| Upstream | `hw/ip/hmac/hmac.core` |

This directory is a closed, synthesizable RTL drop. It contains the OpenTitan IP and the generic primitives, TileLink, and packages that the top actually elaborates. Technology-specific primitives (Xilinx, ASAP7) are not included. `prim_flop` and the other `prim_*` leaf cells are the generic implementations, so a standard-cell library can map them.

The RTL is unmodified from OpenTitan `ccffab942d75b44fd7f319cc5d53e94a0452385d` (2026-11-02). License: Apache-2.0. See `source_manifest.tsv` for the upstream path of every file, and the repository `LICENSE`.

## Clocks and resets

- `clk_i`, starting period 12.0 ns. Starting period for a first timing run. The SHA-512 round is the deep cloud. Retune after the first synthesis in your library.

Resets, all asynchronous and active-low: `rst_ni`.

## Memory

None. This block does not instantiate an SRAM.

## How to run it

Elaborate `hmac` with `SYNTHESIS` defined, and put `rtl/include` on the include path. `filelist.f` already carries both:

```
+define+SYNTHESIS
+incdir+rtl/include
```

`sources.f` is the same list without those directives, for tools whose file reader does not accept `+define` or `+incdir`.

`SYNTHESIS` selects the empty assertion macros in `prim_assert.sv`. Leave it defined for synthesis and for the gate-level netlist you hand to place and route. Do not define `SIMULATION`. That macro turns `prim_cdc_rand_delay` into a randomized delay model (`$urandom`), which is not synthesizable. Without `SIMULATION` the cell is a wire. Do not define `SYNTHESIS_MEMORY_BLACK_BOXING`.

Recommended block-level flow:

1. Analyze `filelist.f` in order. Packages are first because several tools require that.
2. Elaborate `hmac` with the default parameters.
3. Read `constraints/hmac.sdc`.
4. In the SDC, uncomment `set_driving_cell` and name a buffer from your library. It is commented out so the file loads before a library is attached.
5. Compile to your standard-cell library. These drops do not instantiate `prim_clock_gating`. Turn on the tool clock-gating pass if you want integrated clock gates inserted on enabled flops.
6. Place and route the mapped netlist. The RTL uses packed structs for TileLink, alerts, and a few sideband bundles. Those structs are gone once the netlist is structural, which is what the P&R tool should read.

Design Compiler sketch, from this directory:

```tcl
set search_path [concat rtl/include $search_path]
analyze -format sverilog -define SYNTHESIS -vcs "-f filelist.f"
elaborate hmac
link
read_sdc constraints/hmac.sdc
compile_ultra
```

Genus sketch:

```tcl
set_db init_hdl_search_path {rtl/include}
read_hdl -sv -define SYNTHESIS -f filelist.f
elaborate hmac
read_sdc constraints/hmac.sdc
syn_generic
syn_map
```

If your analyzer rejects `+define` inside `filelist.f`, use `sources.f` and pass the define and the include directory as tool flags. The file order is the same.

## Place-and-route notes

- No SRAM. `u_tlul_adapter` is a `tlul_adapter_sram` bus window into the message FIFO, not a memory compiler macro. The FIFO and the SHA-2 engine are flops and arithmetic. Area will be dominated by the 64-bit SHA-512 round and the key registers.
- `keymgr_key_i` is a sideload key struct from `keymgr_dpe_pkg`. For a block-level run, constrain it as data inputs. Nothing in this drop instantiates the key manager.
- `idle_o` is a 4-bit multi-bit encoded value (`mubi4`), not a single status bit. Do not merge those bits.
- The message window on the TileLink bus is inside this top. Software writes the message through `tl_i` / `tl_o`. There is no second data port.
- A 12 ns starting period is a suggestion so the first compile produces slack you can read. It is not a measured closure target.

Constraint file: `constraints/hmac.sdc`.

- Periods are starting points for a first timing run in whatever library you load. Re-time the block after you see real slack. Nothing here was closed in a physical library.
- I/O delays are 40% of the primary period. Replace them with the budget from the surrounding SoC before you trust WNS.
- `set_driving_cell` is commented out so this SDC loads before a library is attached. Uncomment it and name a buffer from your library before you trust input slew.
- Resets are cut with `set_false_path`. Add a reset-buffer tree when you do real DFT and power-up sequencing.
- No scan chains are inserted. Scan and clock-gate test-enable hookup are later DFT steps on the mapped netlist.

## Interfaces the P&R boundary will see

- `tl_i`, `tl_o`: TileLink-UL host port (`tlul_pkg::tl_h2d_t`, `tlul_pkg::tl_d2h_t`). This drop does not include a crossbar. Constrain the struct members as data.
- Alert bundles where the IP has them: differential alert sender pins, one or two alerts.
- This top has no RACL ports.
- The IP's own functional pins (GPIO bits, UART TX/RX, I2C SCL/SDA, HMAC sideload and idle, AES key and entropy). See the top module header in `rtl/src/hmac.sv`.

## What was verified

The file list elaborates under Verilator 5.050 with `verilator --lint-only -Wno-WIDTHEXPAND --top-module hmac -f filelist.f`. That run exits cleanly, so the drop is closed. Verilator also reports `WIDTHEXPAND` on a few comparisons (the alert skew counter, and UART or HMAC FIFO level checks where those blocks are present). Those are upstream OpenTitan lint warnings, not missing modules, and `-Wno-WIDTHEXPAND` matches the usual waiver. This is not a timing or DRC result. No standard-cell library, synthesis, or place-and-route was run.
