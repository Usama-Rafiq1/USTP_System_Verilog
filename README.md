# USTP System Verilog Lab Work

SystemVerilog lab exercises. Each top-level folder is one lab/assignment,
with its own README covering what's implemented and how to run it.

## Structure

```
SVerilog/
├── APB/                 APB interface with master/slave modports + virtual-interface testbench
├── APB Verification/    APB slave verified with basic-OOP-only SystemVerilog classes
```

### APB: Interface, Modports, Virtual Interface

- [`apb_design.sv`](APB/apb_design.sv): `apb_if` interface with
  `master`/`slave` modports, and a small `apb_slave` register file behind
  the slave modport
- [`apb_tb.sv`](APB/apb_tb.sv): a class-based driver that reaches the bus
  through a `virtual apb_if.master` handle, writes/reads back three
  registers with self-checking pass/fail output

See [`APB/README.md`](APB/README.md) for details, including a note on
which parts of this could and couldn't be run through the Icarus Verilog
installed locally. It doesn't support interface-typed module ports or
virtual interfaces at all, which is a real tooling limitation, not a
shortcut taken in the code.

### APB Verification: Basic OOP (transaction, generator, driver, scoreboard)

- [`apb_design.sv`](APB%20Verification/apb_design.sv): the same APB
  slave register file, but with plain individual ports instead of an
  interface.
- [`apb_tb.sv`](APB%20Verification/apb_tb.sv): a testbench built only
  from basic SystemVerilog OOP. `apb_transaction`, `apb_generator`,
  `apb_driver`, and `apb_scoreboard` classes are composed together in
  the top module. No interfaces, virtual interfaces, constrained
  random, or mailboxes/semaphores.

See [`APB Verification/README.md`](APB%20Verification/README.md) for
details, including several real Icarus Verilog class-handling bugs that
turned up and had to be worked around while building it.

## Tools

- [Icarus Verilog](http://iverilog.icarus.com/) (`iverilog`, `vvp`) for compilation and simulation
- [GTKWave](http://gtkwave.sourceforge.net/) for viewing `.vcd` waveform dumps

## Running a simulation

From inside a lab's folder, e.g. `APB`:

```bash
iverilog -g2012 -o sim apb_design.sv apb_tb.sv
vvp sim
gtkwave wave.vcd
```
