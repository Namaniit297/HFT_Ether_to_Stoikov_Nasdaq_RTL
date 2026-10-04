module realized_variance_accum(
    input logic clk,rst_n,in_valid,window_close,
    input hft_fixed_pkg::q_t ret,
    output hft_fixed_pkg::q_t variance,
    output hft_fixed_pkg::q_t volatility,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t sumsq;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sumsq<=0;variance<=0;volatility<=0;out_valid<=0;end
        else begin
            out_valid<=0;
            if(in_valid) sumsq<=q_add(sumsq,q_mul(ret,ret));
            if(window_close) begin variance<=sumsq;volatility<=q_sqrt(sumsq);sumsq<=0;out_valid<=1;end
        end
    end
endmodule

module ewma_variance(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t ret,
    input hft_fixed_pkg::q_t lambda,
    input hft_fixed_pkg::q_t variance_init,
    output hft_fixed_pkg::q_t variance,
    output hft_fixed_pkg::q_t volatility,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t v;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v<=variance_init;variance<=variance_init;volatility<=q_sqrt(variance_init);out_valid<=0;end
        else if(in_valid) begin
            v<=q_add(q_mul(lambda,v),q_mul(q_sub(Q_ONE,lambda),q_mul(ret,ret)));
            variance<=q_add(q_mul(lambda,v),q_mul(q_sub(Q_ONE,lambda),q_mul(ret,ret)));
            volatility<=q_sqrt(q_add(q_mul(lambda,v),q_mul(q_sub(Q_ONE,lambda),q_mul(ret,ret))));
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module bipower_variation(
    input logic clk,rst_n,in_valid,window_close,
    input hft_fixed_pkg::q_t ret,
    output hft_fixed_pkg::q_t bv,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t prev_abs,acc;
    q_t pi_over2;
    initial pi_over2=32'sh00019220; // pi/2
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin prev_abs<=0;acc<=0;bv<=0;out_valid<=0;end
        else begin
            out_valid<=0;
            if(in_valid) begin
                if(prev_abs!=0) acc<=q_add(acc,q_mul(q_mul(prev_abs,q_abs(ret)),pi_over2));
                prev_abs<=q_abs(ret);
            end
            if(window_close) begin bv<=acc;acc<=0;prev_abs<=0;out_valid<=1;end
        end
    end
endmodule

module garch11(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t ret,
    input hft_fixed_pkg::q_t omega,alpha,beta,
    output hft_fixed_pkg::q_t variance,
    output hft_fixed_pkg::q_t volatility,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t v,next_v;
    always_comb begin
        next_v=q_add(omega,q_add(q_mul(alpha,q_mul(ret,ret)),q_mul(beta,v)));
        if(next_v<0) next_v=0;
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin v<=0;variance<=0;volatility<=0;out_valid<=0;end
        else if(in_valid) begin v<=next_v;variance<=next_v;volatility<=q_sqrt(next_v);out_valid<=1;end
        else out_valid<=0;
    end
endmodule
