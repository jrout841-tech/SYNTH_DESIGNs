# aes

AES is the stress case: AES-128/192/256, CTR and GCM, a cipher core with first-order masking, PRNGs for clearing and masking, life-cycle escalation, shadowed control registers, and a second clock for the entropy interface.

| | |
| --- | --- |
| Category | `complex` |
| Top module | `aes` |
| Complexity | 5 of 5. Largest block in this drop. |
| Source files | 93 (29221 lines) |
| Include files | 6 |
| Upstream | `hw/ip/aes/aes.core` |

This directory is a closed, synthesizable RTL drop. It contains the OpenTitan IP and the generic primitives, TileLink, and packages that the top actually elaborates. Technology-specific primitives (Xilinx, ASAP7) are not included. `prim_flop` and the other `prim_*` leaf cells are the generic implementations, so a standard-cell library can map them.

The RTL is unmodified from OpenTitan `ccffab942d75b44fd7f319cc5d53e94a0452385d` (2026-11-02). License: Apache-2.0. See `source_manifest.tsv` for the upstream path of every file, and the repository `LICENSE`.

## Clocks and resets

- `clk_i`, starting period 15.0 ns. Main cipher and register clock. Masked SubBytes dominates. Retune after the first library synthesis.
- `clk_edn_i`, starting period 20.0 ns. Entropy-distribution clock. The RTL synchronizes this domain into `clk_i`.

Resets, all asynchronous and active-low: `rst_ni`, `rst_shadowed_ni`, `rst_edn_ni`.

## Memory

None. This block does not instantiate an SRAM.

## How to run it

Elaborate `aes` with `SYNTHESIS` defined, and put `rtl/include` on the include path. `filelist.f` already carries both:

```
+define+SYNTHESIS
+incdir+rtl/include
```

`sources.f` is the same list without those directives, for tools whose file reader does not accept `+define` or `+incdir`.

`SYNTHESIS` selects the empty assertion macros in `prim_assert.sv`. Leave it defined for synthesis and for the gate-level netlist you hand to place and route. Do not define `SIMULATION`. That macro turns `prim_cdc_rand_delay` into a randomized delay model (`$urandom`), which is not synthesizable. Without `SIMULATION` the cell is a wire. Do not define `SYNTHESIS_MEMORY_BLACK_BOXING`.

Recommended block-level flow:

1. Analyze `filelist.f` in order. Packages are first because several tools require that.
2. Elaborate `aes` with the default parameters.
3. Read `constraints/aes.sdc`.
4. In the SDC, uncomment `set_driving_cell` and name a buffer from your library. It is commented out so the file loads before a library is attached.
5. Compile to your standard-cell library. These drops do not instantiate `prim_clock_gating`. Turn on the tool clock-gating pass if you want integrated clock gates inserted on enabled flops.
6. Place and route the mapped netlist. The RTL uses packed structs for TileLink, alerts, and a few sideband bundles. Those structs are gone once the netlist is structural, which is what the P&R tool should read.

Design Compiler sketch, from this directory:

```tcl
set search_path [concat rtl/include $search_path]
analyze -format sverilog -define SYNTHESIS -vcs "-f filelist.f"
elaborate aes
link
read_sdc constraints/aes.sdc
compile_ultra
```

Genus sketch:

```tcl
set_db init_hdl_search_path {rtl/include}
read_hdl -sv -define SYNTHESIS -f filelist.f
elaborate aes
read_sdc constraints/aes.sdc
syn_generic
syn_map
```

If your analyzer rejects `+define` inside `filelist.f`, use `sources.f` and pass the define and the include directory as tool flags. The file order is the same.

## Place-and-route notes

- Default parameters are the OpenTitan security configuration: `SecMasking` 1 and `SecSBoxImpl` DOM. That is the netlist you want for a real P&R stress test. Setting `SecMasking` to 0 is a smaller debug run, not the configuration shipped here.
- Two clocks. `clk_edn_i` and `clk_i` are treated as asynchronous in the supplied SDC because the RTL has synchronizers between them. If your SoC ties both ports to one physical clock, delete the second `create_clock`, drive both ports from that clock, and remove the `set_clock_groups` command.
- `rst_shadowed_ni` resets shadowed control registers. `rst_edn_ni` resets the entropy-domain logic. All three resets are asynchronous and active-low.
- `lc_escalate_en_i` is a life-cycle escalation token. `edn_i` / `edn_o` are the entropy request and response structs. `keymgr_key_i` is the sideload key. For a block-level experiment, constrain all of these as data I/O. The key manager, life-cycle controller, and EDN are not inside this drop.
- No `prim_clock_gating` instances. `prim_flop_en` is a flip-flop with a synchronous data enable. A synthesis clock-gating pass can turn those enables into integrated clock gates.
- No SRAM. Area is combinational logic in the masked S-box and the GHASH multiply, plus a large number of flops for key, data, and state.

Constraint file: `constraints/aes.sdc`.

- Periods are starting points for a first timing run in whatever library you load. Re-time the block after you see real slack. Nothing here was closed in a physical library.
- I/O delays are 40% of the primary period. Replace them with the budget from the surrounding SoC before you trust WNS.
- `set_driving_cell` is commented out so this SDC loads before a library is attached. Uncomment it and name a buffer from your library before you trust input slew.
- Resets are cut with `set_false_path`. Add a reset-buffer tree when you do real DFT and power-up sequencing.
- No scan chains are inserted. Scan and clock-gate test-enable hookup are later DFT steps on the mapped netlist.

## Interfaces the P&R boundary will see

- `tl_i`, `tl_o`: TileLink-UL host port (`tlul_pkg::tl_h2d_t`, `tlul_pkg::tl_d2h_t`). This drop does not include a crossbar. Constrain the struct members as data.
- Alert bundles where the IP has them: differential alert sender pins, one or two alerts.
- This top has no RACL ports.
- The IP's own functional pins (GPIO bits, UART TX/RX, I2C SCL/SDA, HMAC sideload and idle, AES key and entropy). See the top module header in `rtl/src/aes.sv`.

## What was verified

The file list elaborates under Verilator 5.050 with `verilator --lint-only -Wno-WIDTHEXPAND --top-module aes -f filelist.f`. That run exits cleanly, so the drop is closed. Verilator also reports `WIDTHEXPAND` on a few comparisons (the alert skew counter, and UART or HMAC FIFO level checks where those blocks are present). Those are upstream OpenTitan lint warnings, not missing modules, and `-Wno-WIDTHEXPAND` matches the usual waiver. This is not a timing or DRC result. No standard-cell library, synthesis, or place-and-route was run.
