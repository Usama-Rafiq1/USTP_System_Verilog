// Class-based APB testbench built from basic SystemVerilog OOP only:
// plain classes, constructors, and methods (tasks/functions), composed
// together in the top module. No interfaces, no virtual interfaces, no
// constrained-random, no mailboxes/semaphores.
//
// A class object has no fixed place in the module hierarchy, so it
// normally can't see signals declared inside a module. To keep things
// to basics (no virtual interfaces), the APB bus signals below are
// declared at file scope, outside any module -- that makes them
// ordinary global variables that both apb_tb and the classes' methods
// can refer to directly by name.

logic        PCLK;
logic        PRESETn;
logic [31:0] PADDR;
logic        PSEL;
logic        PENABLE;
logic        PWRITE;
logic [31:0] PWDATA;
logic        PREADY;
logic [31:0] PRDATA;
logic        PSLVERR;


// One APB transfer: address + data going in, plus whatever comes back.
class apb_transaction;
    logic [31:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;
    bit          write;      // 1 = write, 0 = read

    function new(logic [31:0] a_addr, logic [31:0] a_wdata, bit a_write);
        addr  = a_addr;
        wdata = a_wdata;
        write = a_write;
    endfunction

    function void display(string tag);
        if (write)
            $display("[%s] WRITE addr=%0h data=%0h", tag, addr, wdata);
        else
            $display("[%s] READ  addr=%0h data=%0h", tag, addr, rdata);
    endfunction
endclass


// Hands out a fixed, directed list of transactions one at a time:
// three writes, then read-backs of the same three addresses.
//
// This keeps an index and hands the next transfer's fields out through
// `output` arguments instead of building an array of apb_transaction
// objects (or returning one from a function) -- both of those crash
// this machine's Icarus Verilog at code-generation time (a real tool
// bug, documented in the README).
class apb_generator;
    int idx = 0;

    function bit has_next();
        return idx < 6;
    endfunction

    task automatic next(output logic [31:0] addr, output logic [31:0] wdata, output bit write);
        case (idx)
            0: begin addr = 32'h0; wdata = 32'hDEAD_BEEF; write = 1'b1; end
            1: begin addr = 32'h4; wdata = 32'h1234_5678; write = 1'b1; end
            2: begin addr = 32'h8; wdata = 32'hCAFE_F00D; write = 1'b1; end
            3: begin addr = 32'h0; wdata = 32'h0;         write = 1'b0; end
            4: begin addr = 32'h4; wdata = 32'h0;         write = 1'b0; end
            default: begin addr = 32'h8; wdata = 32'h0;   write = 1'b0; end
        endcase
        idx = idx + 1;
    endtask
endclass


// Drives one APB transfer onto the global bus signals: SETUP phase for
// one cycle, then ACCESS held until PREADY goes high.
class apb_driver;
    task automatic drive(apb_transaction tr);
        @(posedge PCLK);
        PSEL    = 1'b1;
        PENABLE = 1'b0;
        PWRITE  = tr.write;
        PADDR   = tr.addr;
        PWDATA  = tr.wdata;

        @(posedge PCLK);
        PENABLE = 1'b1;

        @(posedge PCLK);
        while (!PREADY) @(posedge PCLK);

        if (!tr.write)
            tr.rdata = PRDATA;

        PSEL    = 1'b0;
        PENABLE = 1'b0;
    endtask
endclass


// Remembers what was last written to each register and checks read-back
// transactions against it, keeping a running pass/fail tally.
class apb_scoreboard;
    int pass_count = 0;
    int fail_count = 0;

    // One property per register instead of an array: an unpacked array
    // of vectors as a class property crashes this machine's Icarus
    // Verilog at code-generation time (a real tool bug, documented in
    // the README) -- four plain fields sidestep it.
    logic [31:0] exp_reg0, exp_reg1, exp_reg2, exp_reg3;

    function void set_exp(logic [1:0] sel, logic [31:0] val);
        case (sel)
            2'd0: exp_reg0 = val;
            2'd1: exp_reg1 = val;
            2'd2: exp_reg2 = val;
            2'd3: exp_reg3 = val;
        endcase
    endfunction

    function logic [31:0] get_exp(logic [1:0] sel);
        case (sel)
            2'd0: return exp_reg0;
            2'd1: return exp_reg1;
            2'd2: return exp_reg2;
            default: return exp_reg3;
        endcase
    endfunction

    // Bit-selecting a class property straight through a handle
    // (tr.addr[3:2]) silently returns the whole field instead of the
    // slice on this machine's Icarus Verilog -- another real tool bug.
    // Copying the field into a local variable first and slicing that
    // works correctly.
    function void note_write(apb_transaction tr);
        logic [31:0] a;
        a = tr.addr;
        set_exp(a[3:2], tr.wdata);
    endfunction

    function void check_read(apb_transaction tr);
        logic [31:0] a, exp;
        a   = tr.addr;
        exp = get_exp(a[3:2]);
        if (tr.rdata === exp) begin
            $display("  PASS: addr=%0h got=%0h", tr.addr, tr.rdata);
            // `pass_count++` on a class property is unreliable on this
            // machine's Icarus Verilog (stays stuck at 1) -- another
            // real tool bug; the explicit form works correctly.
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL: addr=%0h got=%0h expected=%0h", tr.addr, tr.rdata, exp);
            fail_count = fail_count + 1;
        end
    endfunction

    function void report();
        $display("---------------------------------");
        $display("Scoreboard: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("---------------------------------");
    endfunction
endclass


module apb_tb;

    localparam DATA_WIDTH  = 32;
    localparam NUM_REGS    = 4;
    localparam WAIT_CYCLES = 1;

    apb_slave #(
        .DATA_WIDTH(DATA_WIDTH), .NUM_REGS(NUM_REGS), .WAIT_CYCLES(WAIT_CYCLES)
    ) dut (
        .PCLK    (PCLK),
        .PRESETn (PRESETn),
        .PADDR   (PADDR),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PREADY  (PREADY),
        .PRDATA  (PRDATA),
        .PSLVERR (PSLVERR)
    );

    apb_generator  gen;
    apb_driver     drv;
    apb_scoreboard sb;

    always #5 PCLK = ~PCLK;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, apb_tb);

        PCLK    = 0;
        PRESETn = 0;
        PSEL    = 0;
        PENABLE = 0;
        PWRITE  = 0;
        PADDR   = 0;
        PWDATA  = 0;

        gen = new();
        drv = new();
        sb  = new();

        #12 PRESETn = 1;

        while (gen.has_next()) begin
            logic [31:0]   next_addr, next_wdata;
            bit            next_write;
            apb_transaction tr;

            gen.next(next_addr, next_wdata, next_write);
            tr = new(next_addr, next_wdata, next_write);

            drv.drive(tr);
            tr.display("DRV");

            if (tr.write)
                sb.note_write(tr);
            else
                sb.check_read(tr);
        end

        sb.report();
        $finish;
    end

endmodule
