module black_scholes_put(
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
            sqrtT=q_sqrt(T);d1=q_div(q_add(q_ln_pos(q_div(S,K)),q_mul(q_add(r,q_mul(sigma,sigma)>>>1),T)),q_mul(sigma,sqrtT));d2=q_sub(d1,q_mul(sigma,sqrtT));Nd1=q_cdf(d1);Nd2=q_cdf(d2);disc=q_exp(q_neg(q_mul(r,T)));phi=q_mul(Q_INV_SQRT_2PI,q_exp(q_neg(q_mul(d1,d1))>>>1));
            // More directly: P = K e^-rT N(-d2) - S N(-d1)
            price<=q_sub(q_mul(K,q_mul(disc,q_cdf(q_neg(d2)))),q_mul(S,q_cdf(q_neg(d1))));
            delta<=q_sub(Nd1,Q_ONE);gamma<=q_div(phi,q_mul(S,q_mul(sigma,sqrtT)));vega<=q_mul(q_mul(S,phi),sqrtT);
            theta<=q_sub(q_neg(q_div(q_mul(q_mul(S,phi),sigma),q_mul(Q_TWO,sqrtT))),q_mul(r,q_mul(K,q_mul(disc,q_cdf(q_neg(d2))))));out_valid<=1;
        end else out_valid<=0;
    end
endmodule
