module black_scholes_call(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t S,K,r,sigma,T,
    output hft_fixed_pkg::q_t price,delta,gamma,vega,theta,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t sqrtT,d1,d2,Nd1,Nd2,disc,phi;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin price<=0;delta<=0;gamma<=0;vega<=0;theta<=0;out_valid<=0;end
        else if(in_valid) begin
            sqrtT=q_sqrt(T);
            d1=q_div(q_add(q_ln_pos(q_div(S,K)),q_mul(q_add(r,q_mul(sigma,sigma)>>>1),T)),q_mul(sigma,sqrtT));
            d2=q_sub(d1,q_mul(sigma,sqrtT));
            Nd1=q_cdf(d1);Nd2=q_cdf(d2);
            disc=q_exp(q_neg(q_mul(r,T)));
            phi=q_mul(Q_INV_SQRT_2PI,q_exp(q_neg(q_mul(d1,d1))>>>1));
            price<=q_sub(q_mul(S,Nd1),q_mul(q_mul(K,disc),Nd2));
            delta<=Nd1;gamma<=q_div(phi,q_mul(S,q_mul(sigma,sqrtT)));vega<=q_mul(q_mul(S,phi),sqrtT);
            theta<=q_neg(q_add(q_div(q_mul(q_mul(S,phi),sigma),q_mul(Q_TWO,sqrtT)),q_add(q_mul(r,q_mul(K,q_mul(disc,Nd2))),q_neg(0))));
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module bs_implied_vol_newton(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t S,K,r,T,market_call,
    output hft_fixed_pkg::q_t sigma,
    output logic converged,out_valid
);
    import hft_fixed_pkg::*;
    q_t s,price,d,vega,err; integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sigma<=32'sh00008000;converged<=0;out_valid<=0;end
        else if(in_valid) begin
            s=32'sh00010000;
            for(i=0;i<6;i=i+1) begin
                // Reuse analytic call price/vega at current sigma.
                d=q_div(q_add(q_ln_pos(q_div(S,K)),q_mul(q_add(r,q_mul(s,s)>>>1),T)),q_mul(s,q_sqrt(T)));
                price=q_sub(q_mul(S,q_cdf(d)),q_mul(q_mul(K,q_exp(q_neg(q_mul(r,T)))),q_cdf(q_sub(d,q_mul(s,q_sqrt(T))))));
                vega=q_mul(q_mul(S,q_mul(Q_INV_SQRT_2PI,q_exp(q_neg(q_mul(d,d))>>>1))),q_sqrt(T));
                err=q_sub(price,market_call);
                if(q_abs(vega)>32'sh00000010) s=q_sub(s,q_div(err,vega));
                if(s<32'sh00001000) s=32'sh00001000; if(s>32'sh000A0000) s=32'sh000A0000;
            end
            sigma<=s;converged<=q_abs(err)<32'sh00000100;out_valid<=1;
        end else out_valid<=0;
    end
endmodule
