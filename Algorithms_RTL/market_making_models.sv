module avellaneda_stoikov_mm(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t mid,inventory,gamma,sigma2,tau,kappa,
    output hft_fixed_pkg::q_t reservation_price,total_spread,bid_price,ask_price,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t inv_pen,volterm,gk,logterm,two_over_gamma,half;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin reservation_price<=0;total_spread<=0;bid_price<=0;ask_price<=0;out_valid<=0;end
        else if(in_valid) begin
            inv_pen=q_mul(q_mul(q_mul(inventory,gamma),sigma2),tau);
            volterm=q_mul(q_mul(gamma,sigma2),tau);
            gk=q_div(gamma,kappa);
            logterm=q_mul(q_div(Q_TWO,gamma),q_ln_pos(q_add(Q_ONE,gk)));
            reservation_price<=q_sub(mid,inv_pen);
            total_spread<=q_add(volterm,logterm);
            half=q_div(q_add(volterm,logterm),Q_TWO);
            bid_price<=q_sub(q_sub(mid,inv_pen),half);
            ask_price<=q_add(q_sub(mid,inv_pen),half);
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module glft_mm_closed_form(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t mid,sigma,gamma,xi,Delta,k,A,inventory,
    output hft_fixed_pkg::q_t c1,c2,bid_depth,ask_depth,bid_price,ask_price,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t ratio,tmp,powterm,root,half,skew;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin c1<=0;c2<=0;bid_depth<=0;ask_depth<=0;bid_price<=0;ask_price<=0;out_valid<=0;end
        else if(in_valid) begin
            ratio=q_div(q_mul(xi,Delta),k);
            tmp=q_add(Q_ONE,ratio);
            c1<=q_div(q_ln_pos(tmp),q_mul(xi,Delta));
            powterm=q_pow_pos(tmp,q_add(q_div(k,q_mul(xi,Delta)),Q_ONE));
            root=q_sqrt(q_mul(q_div(gamma,q_mul(q_mul(Q_TWO,A),q_mul(Delta,k))),powterm));
            c2<=root;
            half=q_add(q_div(q_ln_pos(tmp),q_mul(xi,Delta)),q_mul(q_mul(Delta,Q_HALF),q_mul(sigma,root)));
            skew=q_mul(sigma,root);
            bid_depth<=q_add(half,q_mul(skew,inventory));
            ask_depth<=q_sub(half,q_mul(skew,inventory));
            bid_price<=q_sub(mid,q_add(half,q_mul(skew,inventory)));
            ask_price<=q_add(mid,q_sub(half,q_mul(skew,inventory)));
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module inventory_skew_quote(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t fair,half_spread,inventory,inventory_limit,skew_per_unit,
    output hft_fixed_pkg::q_t bid,ask,skew,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin bid<=0;ask<=0;skew<=0;out_valid<=0;end
        else if(in_valid) begin
            skew<=q_mul(skew_per_unit,q_div(inventory,inventory_limit));
            bid<=q_sub(q_sub(fair,half_spread),q_mul(skew_per_unit,q_div(inventory,inventory_limit)));
            ask<=q_add(q_sub(fair,q_mul(skew_per_unit,q_div(inventory,inventory_limit))),half_spread);
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module alpha_adjusted_mm(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t as_reservation,alpha_signal,alpha_scale,half_spread,inventory_shift,
    output hft_fixed_pkg::q_t fair,bid,ask,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t f;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin fair<=0;bid<=0;ask<=0;out_valid<=0;end
        else if(in_valid) begin
            f=q_add(as_reservation,q_mul(alpha_signal,alpha_scale)); fair<=f;
            bid<=q_sub(q_sub(f,inventory_shift),half_spread);
            ask<=q_add(q_sub(f,inventory_shift),half_spread); out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module queue_aware_quote_filter(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t bid_candidate,ask_candidate,
    input hft_fixed_pkg::q_t fill_prob_bid,fill_prob_ask,
    input hft_fixed_pkg::q_t min_fill_prob,
    output hft_fixed_pkg::q_t bid_out,ask_out,
    output logic cancel_bid,cancel_ask,
    output logic out_valid
);
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin bid_out<=0;ask_out<=0;cancel_bid<=0;cancel_ask<=0;out_valid<=0;end
        else if(in_valid) begin
            bid_out<=bid_candidate;ask_out<=ask_candidate;
            cancel_bid<=fill_prob_bid<min_fill_prob;cancel_ask<=fill_prob_ask<min_fill_prob;out_valid<=1;
        end else out_valid<=0;
    end
endmodule
