// APB (Advanced Peripheral Bus) slave: a small register file that
// speaks plain APB protocol (SETUP phase, then ACCESS held until
// PREADY).
//
// Plain module ports on purpose here, no interface/modport and no
// virtual interface, since the testbench only uses basic
// SystemVerilog OOP (classes, constructors, methods).
module apb_slave #(
    parameter DATA_WIDTH  = 32,
    parameter ADDR_WIDTH  = 32,
    parameter NUM_REGS    = 4,
    parameter WAIT_CYCLES = 1
) (
    input  logic                  PCLK,
    input  logic                  PRESETn,
    input  logic [ADDR_WIDTH-1:0] PADDR,
    input  logic                  PSEL,
    input  logic                  PENABLE,
    input  logic                  PWRITE,
    input  logic [DATA_WIDTH-1:0] PWDATA,
    output logic                  PREADY,
    output logic [DATA_WIDTH-1:0] PRDATA,
    output logic                  PSLVERR
);

    localparam SEL_BITS = $clog2(NUM_REGS);

    logic [DATA_WIDTH-1:0] regs [0:NUM_REGS-1];
    logic [7:0]            wait_cnt;
    integer                i;

    // Holds PREADY low for WAIT_CYCLES extra cycles once PSEL/PENABLE
    // are both up, so a driver that ignores PREADY and just assumes a
    // fixed-length transfer would end up reading or writing the wrong
    // cycle.
    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            wait_cnt <= 8'd0;
        else if (PSEL && PENABLE) begin
            if (wait_cnt < WAIT_CYCLES)
                wait_cnt <= wait_cnt + 8'd1;
        end else begin
            wait_cnt <= 8'd0;
        end
    end

    assign PREADY  = PSEL && PENABLE && (wait_cnt >= WAIT_CYCLES);
    assign PSLVERR = 1'b0;

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= '0;
        end else if (PSEL && PENABLE && PREADY && PWRITE) begin
            regs[PADDR[SEL_BITS+1:2]] <= PWDATA;
        end
    end

    assign PRDATA = regs[PADDR[SEL_BITS+1:2]];

endmodule
