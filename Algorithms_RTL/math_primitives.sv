module q_reciprocal_exact #(
    parameter int LATENCY = 1
)(
    input  logic clk, rst_n, in_valid,
    input  hft_fixed_pkg::q_t x,
    output hft_fixed_pkg::q_t y,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t y_c;
    always_comb y_c = q_div(Q_ONE,x);
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin y<='0; out_valid<=1'b0; end
        else begin y<=y_c; out_valid<=in_valid; end
    end
endmodule

module q_reciprocal_nr #(
    parameter int ITERATIONS = 2
)(
    input  logic clk, rst_n, in_valid,
    input  hft_fixed_pkg::q_t x,
    output hft_fixed_pkg::q_t y,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t r;
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin y<='0; r<='0; out_valid<=1'b0; end
        else begin
            out_valid<=in_valid;
            if(in_valid) begin
                // Deterministic reference seed; the following NR iterations are
                // the actual algorithm and can later be fed by a ROM seed.
                r = q_div(Q_ONE,x);
                for(i=0;i<ITERATIONS;i=i+1)
                    r = q_mul(r, q_sub(Q_TWO,q_mul(x,r)));
                y <= r;
            end
        end
    end
endmodule

module q_log_poly(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x,
    output hft_fixed_pkg::q_t y,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin y<=0; out_valid<=0; end
        else begin y<=q_ln_pos(x); out_valid<=in_valid; end
    end
endmodule

module q_exp_poly(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x,
    output hft_fixed_pkg::q_t y,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin y<=0; out_valid<=0; end
        else begin y<=q_exp(x); out_valid<=in_valid; end
    end
endmodule

module q_sqrt_nr(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x,
    output hft_fixed_pkg::q_t y,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin y<=0; out_valid<=0; end
        else begin y<=q_sqrt(x); out_valid<=in_valid; end
    end
endmodule

module q_normal_cdf(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x,
    output hft_fixed_pkg::q_t y,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin y<=0; out_valid<=0; end
        else begin y<=q_cdf(x); out_valid<=in_valid; end
    end
endmodule
