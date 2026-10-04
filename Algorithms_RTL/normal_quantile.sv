module normal_quantile_approx(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t p,
    output hft_fixed_pkg::q_t z,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t guess,phi,cdf,err; integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin z<=0;out_valid<=0;end
        else if(in_valid) begin
            // Newton inversion of Phi(z)-p=0.
            if(p<=32'sh00004000) guess=-32'sh00020000;
            else if(p>=32'sh0000C000) guess=32'sh00020000;
            else guess=0;
            for(i=0;i<5;i=i+1) begin
                cdf=q_cdf(guess); phi=q_mul(Q_INV_SQRT_2PI,q_exp(q_neg(q_mul(guess,guess))>>>1)); err=q_sub(cdf,p);
                if(phi!=0) guess=q_sub(guess,q_div(err,phi));
            end
            z<=guess;out_valid<=1;
        end else out_valid<=0;
    end
endmodule

// Convenience module with the exact name used by risk_models.sv.
// Instantiate this block and route p into z_quantile when ES is needed.
