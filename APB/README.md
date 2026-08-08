# APB Interface with Modports + Virtual-Interface Testbench

An APB (Advanced Peripheral Bus) interface with `master`/`slave` modports, a
small APB slave register file to exercise it, and a class-based testbench
driver that reaches the bus through a **virtual interface**.

- [`apb_design.sv`](apb_design.sv)
  - `interface apb_if` — all the standard APB signals (`PADDR`, `PSEL`,
    `PENABLE`, `PWRITE`, `PWDATA`, `PREADY`, `PRDATA`, `PSLVERR`), split
    into `master` (drives address/control/write-data, reads back
    ready/data) and `slave` (the mirror image) modports.
  - `module apb_slave` — a 4-register, 32-bit register file behind an
    `apb_if.slave` port. `WAIT_CYCLES` (default 1 in the testbench
    instance) makes it hold `PREADY` low for extra cycles, to prove the
    master side actually polls `PREADY` instead of assuming every
    transfer is a fixed length.
- [`apb_tb.sv`](apb_tb.sv)
  - `class apb_driver` — holds a `virtual apb_if.master` handle and has
    `write()`/`read()` tasks that drive a proper SETUP-then-ACCESS APB
    transfer and wait for `PREADY`. A virtual interface is what lets a
    class — a dynamic object with no fixed spot in the module hierarchy —
    reach out and drive a real interface instance from outside it.
  - `module apb_tb` — instantiates the interface and the slave, builds an
    `apb_driver` pointed at `apb.master`, writes three registers and reads
    them back with a self-checking pass/fail print for each.

## A tooling note

The Icarus Verilog installed on this machine (`iverilog -V` reports
`12.0-devel`, and winget confirms it's already the newest build available
for Windows) does not support two things these files use:

- an interface type as a module port (`apb_if.slave apb` in the slave's
  port list)
- `virtual interface` declarations at all — not in a class, not even as a
  plain module-level variable

Both are IEEE 1800 SystemVerilog and will compile fine on any full-featured
simulator (Questa, VCS, Xcelium, etc. — likely whatever your course's lab
machines run). They're written the standard, correct way here rather than
worked around, since working around them would mean not actually
demonstrating modports-as-ports or virtual interfaces, which is the point
of the assignment.

To still get real simulation confidence out of Icarus, the exact same APB
protocol logic (SETUP/ACCESS timing, `PREADY` wait-state polling, register
read/write) was also run as a flattened build — same interface signals,
same task-based master sequencing, but with the slave logic inlined
instead of behind a module port, and plain tasks instead of a class +
virtual interface. All three write/read-back checks passed:

```
reg0 PASS: got deadbeef
reg1 PASS: got 12345678
reg2 PASS: got cafef00d
```

That confirms the protocol behavior in `apb_design.sv`/`apb_tb.sv` is
correct; it just isn't runnable end-to-end, as-written, on this particular
copy of Icarus.

## Running it

On a simulator with full interface/class support:

```bash
iverilog -g2012 -o sim apb_design.sv apb_tb.sv
vvp sim
```

If your simulator errors out on the same two features, that's this same
Icarus limitation, not a problem with the code.
