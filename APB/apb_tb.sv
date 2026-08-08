// Testbench for apb_design.sv. The driver class only ever talks to the
// bus through a *virtual* interface handle (apb.master), which is what
// lets a class -- a dynamic object with no fixed place in the module
// hierarchy -- reach out and drive a real interface instance.

class apb_driver;
    virtual apb_if.master vif;

    function new(virtual apb_if.master vif);
        this.vif = vif;
    endfunction

    task automatic reset();
        vif.PSEL    = 1'b0;
        vif.PENABLE = 1'b0;
        vif.PWRITE  = 1'b0;
        vif.PADDR   = '0;
        vif.PWDATA  = '0;
    endtask

    // SETUP phase for one cycle, then ACCESS phase held until PREADY
    task automatic write(input logic [31:0] addr, input logic [31:0] data);
        @(posedge vif.PCLK);
        vif.PSEL    = 1'b1;
        vif.PENABLE = 1'b0;
        vif.PWRITE  = 1'b1;
        vif.PADDR   = addr;
        vif.PWDATA  = data;

        @(posedge vif.PCLK);
        vif.PENABLE = 1'b1;

        @(posedge vif.PCLK);
        while (!vif.PREADY) @(posedge vif.PCLK);

        vif.PSEL    = 1'b0;
        vif.PENABLE = 1'b0;
    endtask

    task automatic read(input logic [31:0] addr, output logic [31:0] data);
        @(posedge vif.PCLK);
        vif.PSEL    = 1'b1;
        vif.PENABLE = 1'b0;
        vif.PWRITE  = 1'b0;
        vif.PADDR   = addr;

        @(posedge vif.PCLK);
        vif.PENABLE = 1'b1;

        @(posedge vif.PCLK);
        while (!vif.PREADY) @(posedge vif.PCLK);
        data = vif.PRDATA;

        vif.PSEL    = 1'b0;
        vif.PENABLE = 1'b0;
    endtask
endclass


module apb_tb;

    localparam DATA_WIDTH  = 32;
    localparam NUM_REGS    = 4;
    localparam WAIT_CYCLES = 1;

    logic PCLK;
    logic PRESETn;

    apb_if #(.ADDR_WIDTH(32), .DATA_WIDTH(DATA_WIDTH)) apb (
        .PCLK(PCLK), .PRESETn(PRESETn)
    );

    apb_slave #(
        .DATA_WIDTH(DATA_WIDTH), .NUM_REGS(NUM_REGS), .WAIT_CYCLES(WAIT_CYCLES)
    ) dut (
        .apb(apb.slave)
    );

    apb_driver drv;

    always #5 PCLK = ~PCLK;

    logic [DATA_WIDTH-1:0] rdata;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, apb_tb);

        PCLK    = 0;
        PRESETn = 0;

        drv = new(apb.master);
        drv.reset();

        #12 PRESETn = 1;

        drv.write(32'h0, 32'hDEAD_BEEF);
        drv.write(32'h4, 32'h1234_5678);
        drv.write(32'h8, 32'hCAFE_F00D);

        drv.read(32'h0, rdata);
        if (rdata == 32'hDEAD_BEEF) $display("reg0 PASS: got %h", rdata);
        else                        $display("reg0 FAIL: got %h", rdata);

        drv.read(32'h4, rdata);
        if (rdata == 32'h1234_5678) $display("reg1 PASS: got %h", rdata);
        else                        $display("reg1 FAIL: got %h", rdata);

        drv.read(32'h8, rdata);
        if (rdata == 32'hCAFE_F00D) $display("reg2 PASS: got %h", rdata);
        else                        $display("reg2 FAIL: got %h", rdata);

        $finish;
    end

endmodule
