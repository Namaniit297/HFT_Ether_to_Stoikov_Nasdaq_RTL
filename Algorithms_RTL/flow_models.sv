module poisson_intensity_exp_distance(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t A,k,delta,
    output hft_fixed_pkg::q_t lambda,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin lambda<=0;out_valid<=0;end
        else begin lambda<=q_mul(A,q_exp(q_neg(q_mul(k,delta))));out_valid<=in_valid;end
    end
endmodule

module hawkes_2d_exp(
    input logic clk,rst_n,in_valid,
    input logic event_buy,event_sell,
    input hft_fixed_pkg::q_t dt,mu_buy,mu_sell,
    input hft_fixed_pkg::q_t beta,
    input hft_fixed_pkg::q_t a_bb,a_bs,a_sb,a_ss,
    output hft_fixed_pkg::q_t lambda_buy,lambda_sell,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t decay,hb,hs;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin hb<=0;hs<=0;lambda_buy<=0;lambda_sell<=0;out_valid<=0;end
        else if(in_valid) begin
            decay=q_exp(q_neg(q_mul(beta,dt)));
            hb=q_add(q_mul(hb,decay),q_add(event_buy?q_add(a_bb,0):0,event_sell?a_bs:0));
            hs=q_add(q_mul(hs,decay),q_add(event_buy?a_sb:0,event_sell?a_ss:0));
            lambda_buy<=q_add(mu_buy,hb); lambda_sell<=q_add(mu_sell,hs); out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module hawkes_4d_exp(
    input logic clk,rst_n,in_valid,
    input logic [3:0] event_mask,
    input hft_fixed_pkg::q_t dt,
    input hft_fixed_pkg::q_t mu [0:3],
    input hft_fixed_pkg::q_t beta,
    input hft_fixed_pkg::q_t alpha [0:3][0:3],
    output hft_fixed_pkg::q_t lambda [0:3],
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t h[0:3]; q_t decay; integer i,j;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            for(i=0;i<4;i=i+1) begin h[i]<=0;lambda[i]<=0;end
            out_valid<=0;
        end else if(in_valid) begin
            decay=q_exp(q_neg(q_mul(beta,dt)));
            for(i=0;i<4;i=i+1) begin
                h[i]=q_mul(h[i],decay);
                for(j=0;j<4;j=j+1) if(event_mask[j]) h[i]=q_add(h[i],alpha[i][j]);
                lambda[i]<=q_add(mu[i],h[i]);
            end
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module queue_reactive_intensity #(
    parameter int IMB_BINS=9,
    parameter int SPR_BINS=4,
    parameter int EVENTS=4
)(
    input logic clk,rst_n,in_valid,
    input logic signed [31:0] imbalance,
    input logic [31:0] spread_ticks,
    input logic [31:0] event_type,
    input hft_fixed_pkg::q_t intensity_rom [0:IMB_BINS*SPR_BINS*EVENTS-1],
    output hft_fixed_pkg::q_t lambda,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    integer ib,sb,idx;
    always_comb begin
        if(imbalance <= -32'sh0000E000) ib=0;
        else if(imbalance <= -32'sh0000A000) ib=1;
        else if(imbalance <= -32'sh00006000) ib=2;
        else if(imbalance <= -32'sh00002000) ib=3;
        else if(imbalance < 32'sh00002000) ib=4;
        else if(imbalance < 32'sh00006000) ib=5;
        else if(imbalance < 32'sh0000A000) ib=6;
        else if(imbalance < 32'sh0000E000) ib=7;
        else ib=8;
        if(spread_ticks==0) sb=0; else if(spread_ticks==1) sb=1; else if(spread_ticks<=3) sb=2; else sb=3;
        if(event_type<EVENTS) idx=((ib*SPR_BINS)+sb)*EVENTS+event_type; else idx=0;
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin lambda<=0;out_valid<=0;end
        else begin lambda<=intensity_rom[idx];out_valid<=in_valid;end
    end
endmodule
