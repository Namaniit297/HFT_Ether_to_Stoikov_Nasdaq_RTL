module glft_with_drift(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t mid,drift,sigma,gamma,k,A,inventory,
    output hft_fixed_pkg::q_t bid_depth,ask_depth,bid_price,ask_price,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t c0,c1,root,base,bias;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin bid_depth<=0;ask_depth<=0;bid_price<=0;ask_price<=0;out_valid<=0;end
        else if(in_valid) begin
            c0=q_div(q_ln_pos(q_add(Q_ONE,q_div(gamma,k))),gamma);
            root=q_sqrt(q_mul(q_div(q_mul(gamma,q_mul(sigma,sigma)),q_mul(q_mul(Q_TWO,k),A)),q_pow_pos(q_add(Q_ONE,q_div(gamma,k)),q_add(Q_ONE,q_div(k,gamma)))));
            c1=q_mul(sigma,root);
            base=q_add(c0,q_mul(Q_HALF,c1));
            bias=q_div(drift,q_mul(gamma,q_mul(sigma,sigma)));
            bid_depth<=q_add(base,q_mul(c1,q_add(inventory,q_neg(bias))));
            ask_depth<=q_add(base,q_mul(c1,q_sub(q_neg(inventory),q_neg(bias))));
            bid_price<=q_sub(mid,q_add(base,q_mul(c1,q_add(inventory,q_neg(bias)))));
            ask_price<=q_add(mid,q_add(base,q_mul(c1,q_sub(q_neg(inventory),q_neg(bias)))));
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule
