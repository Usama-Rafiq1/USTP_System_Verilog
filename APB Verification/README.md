# APB Protocol Verification Using SystemVerilog OOP

An APB (Advanced Peripheral Bus) slave register file, verified by a
class-based testbench built from **basic SystemVerilog OOP only**:
plain classes, constructors, properties, and methods (tasks/functions).
No interfaces, no virtual interfaces, no constrained-random, no
mailboxes/semaphores, no inheritance/polymorphism.

## Files

- [`apb_design.sv`](apb_design.sv) — `module apb_slave`, a 4-register,
  32-bit register file with plain individual ports (`PADDR`, `PSEL`,
  `PENABLE`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`, `PSLVERR`) — no
  `interface`/`modport`. `WAIT_CYCLES` holds `PREADY` low for extra
  cycles so the testbench actually has to poll it instead of assuming a
  fixed-length transfer.
- [`apb_tb.sv`](apb_tb.sv) — the OOP testbench:
  - `apb_transaction` — one APB transfer: `addr`, `wdata`, `rdata`,
    `write`. Built with a constructor (`new`); has a `display()` method.
  - `apb_generator` — hands out a fixed, directed list of transactions
    (three writes, then read-backs of the same three addresses) one at
    a time through `has_next()` / `next()`.
  - `apb_driver` — `drive()` runs one APB transfer: SETUP phase for one
    cycle, then ACCESS held until `PREADY` goes high.
  - `apb_scoreboard` — remembers what was last written to each register
    and checks read-backs against it, printing PASS/FAIL per transfer
    and a final tally via `report()`.
  - `module apb_tb` — instantiates `apb_slave`, builds one of each
    class, and drives the transaction list through
    generator → driver → scoreboard.

## Why the APB signals are plain globals, not an interface

A class object has no fixed place in the module hierarchy, so a class
method can't normally reach a signal declared inside a module — that's
normally solved with a **virtual interface**, which is beyond "basics of
OOP." Instead, `PCLK`/`PRESETn`/`PADDR`/... are declared once at file
scope, outside any module. That makes them ordinary global variables:
`apb_tb` connects them to the DUT's ports, and every class method
(e.g. `apb_driver::drive()`) refers to them directly by name. This is
the simplest way to let a class touch real signals without interfaces,
virtual interfaces, or `ref` ports.

## A tooling note

This was developed and run against the Icarus Verilog installed
locally (`iverilog -V` reports `12.0-devel`). That build turned out to
have several real bugs specific to classes, found and worked around
while building this:

- **`ref` task/function ports aren't implemented** (`sorry: Reference
  ports not supported yet`) — this is why the bus signals are globals
  rather than passed into `apb_driver::drive()` by reference.
- **An unpacked array of vectors as a class property crashes codegen**
  (`Assertion failed: ivl_type_packed_lsb(...)`) — `apb_scoreboard`
  therefore uses four separate `exp_reg0..exp_reg3` properties instead
  of `logic [31:0] expected [0:3]`.
- **A class-typed array property indexed with a variable, and any class
  method that `return`s an object handle, both crash elaboration**
  (`Assertion failed: darray`) — `apb_generator` therefore hands
  transaction fields out through `output` arguments instead of storing
  an array of `apb_transaction` objects or returning one from a
  function; the object itself is built with `new()` at the call site.
- **`function new(T x); this.x = x; endfunction`** — a constructor
  argument with the *same name* as the property it initializes silently
  corrupts or crashes (`Assertion failed: val.size() >= wid`). Every
  constructor here uses a differently-named argument
  (`new(logic [31:0] a_addr, ...)`) and assigns without `this.`.
- **Bit-selecting a class property straight through a handle**
  (`tr.addr[3:2]`) silently returns the *whole* field instead of the
  slice, with no error at all. `apb_scoreboard::note_write()` /
  `check_read()` copy the field into a local variable first and slice
  that instead.
- **`class_property++` doesn't reliably persist** — `pass_count++`
  stayed stuck at 1 no matter how many times it ran; the explicit form
  `pass_count = pass_count + 1;` works correctly. Used throughout.

None of this reflects the SystemVerilog OOP concepts being verified —
every one of the above is a documented crash or silent wrong-answer in
this specific Icarus build, isolated with small standalone repros
before being worked around here. A full-featured simulator (Questa,
VCS, Xcelium) would not need any of these workarounds; the more
straightforward version of each construct (an `expected[]` array in the
scoreboard, `pass_count++`, a `next()` that returns an
`apb_transaction`, etc.) would work as normally written there.

## Running it

```bash
iverilog -g2012 -o sim apb_design.sv apb_tb.sv
vvp sim
gtkwave wave.vcd   # optional, to view the waveform
```

Expected output:

```
[DRV] WRITE addr=0 data=deadbeef
[DRV] WRITE addr=4 data=12345678
[DRV] WRITE addr=8 data=cafef00d
[DRV] READ  addr=0 data=deadbeef
  PASS: addr=0 got=deadbeef
[DRV] READ  addr=4 data=12345678
  PASS: addr=4 got=12345678
[DRV] READ  addr=8 data=cafef00d
  PASS: addr=8 got=cafef00d
---------------------------------
Scoreboard: 3 PASS, 0 FAIL
---------------------------------
```

This was also verified to actually catch failures, not just report
PASS: temporarily breaking the DUT's address decode (`PRDATA` always
reading register 0) correctly flipped two of the three checks to FAIL
with the right expected/got values, confirming the scoreboard logic
itself is sound.
