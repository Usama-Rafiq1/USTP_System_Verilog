// APB (Advanced Peripheral Bus) interface with master/slave modports,
// plus a small APB slave to exercise it against.

interface apb_if #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input logic PCLK,
    input logic PRESETn
);

    logic [ADDR_WIDTH-1:0] PADDR;
    logic                  PSEL;
    logic                  PENABLE;
    logic                  PWRITE;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic                  PREADY;
    logic [DATA_WIDTH-1:0] PRDATA;
    logic                  PSLVERR;

    modport master (
        input  PCLK, PRESETn,
        output PADDR, PSEL, PENABLE, PWRITE, PWDATA,
        input  PREADY, PRDATA, PSLVERR
    );

    modport slave (
        input  PCLK, PRESETn,
        input  PADDR, PSEL, PENABLE, PWRITE, PWDATA,
        output PREADY, PRDATA, PSLVERR
    );

endinterface


// A 4-register, 32-bit register file behind an APB slave port.
// WAIT_CYCLES lets the slave insert extra wait states (PREADY held
// low) beyond the normal single ACCESS cycle, to prove the master
// side actually polls PREADY instead of assuming a fixed transfer
// length.
module apb_slave #(
    parameter DATA_WIDTH  = 32,
    parameter NUM_REGS    = 4,
    parameter WAIT_CYCLES = 0
) (
    apb_if.slave apb
);

    localparam SEL_BITS = $clog2(NUM_REGS);

    logic [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];
    logic [7:0]            wait_cnt;
    integer                i;

    always_ff @(posedge apb.PCLK or negedge apb.PRESETn) begin
        if (!apb.PRESETn)
            wait_cnt <= 8'd0;
        else if (apb.PSEL && apb.PENABLE) begin
            if (wait_cnt < WAIT_CYCLES)
                wait_cnt <= wait_cnt + 8'd1;
        end else begin
            wait_cnt <= 8'd0;
        end
    end

    assign apb.PREADY  = apb.PSEL && apb.PENABLE && (wait_cnt >= WAIT_CYCLES);
    assign apb.PSLVERR = 1'b0;

    always_ff @(posedge apb.PCLK or negedge apb.PRESETn) begin
        if (!apb.PRESETn) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= '0;
        end else if (apb.PSEL && apb.PENABLE && apb.PREADY && apb.PWRITE) begin
            regs[apb.PADDR[SEL_BITS+1:2]] <= apb.PWDATA;
        end
    end

    assign apb.PRDATA = regs[apb.PADDR[SEL_BITS+1:2]];

endmodule
