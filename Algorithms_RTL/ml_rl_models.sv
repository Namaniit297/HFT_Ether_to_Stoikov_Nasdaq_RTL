module linear_regression_predictor #(
    parameter int N=16
)(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x [0:N-1],w [0:N-1],bias,
    output hft_fixed_pkg::q_t y,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t sum; integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin y<=0;out_valid<=0;end
        else begin sum=bias;for(i=0;i<N;i=i+1)sum=q_add(sum,q_mul(x[i],w[i]));y<=sum;out_valid<=in_valid;end
    end
endmodule

module logistic_regression_predictor #(
    parameter int N=8
)(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x [0:N-1],w [0:N-1],bias,
    output hft_fixed_pkg::q_t probability,logit,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t z; integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin probability<=0;logit<=0;out_valid<=0;end
        else if(in_valid) begin z=bias;for(i=0;i<N;i=i+1) z=q_add(z,q_mul(x[i],w[i]));logit<=z;probability<=q_div(Q_ONE,q_add(Q_ONE,q_exp(q_neg(z))));out_valid<=1;end else out_valid<=0;
    end
endmodule

module mlp_8_16_3(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x [0:7],
    input hft_fixed_pkg::q_t w1 [0:15][0:7],b1[0:15],
    input hft_fixed_pkg::q_t w2 [0:2][0:15],b2[0:2],
    output hft_fixed_pkg::q_t y [0:2],
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t h[0:15];q_t z;integer i,j;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin for(i=0;i<16;i=i+1)h[i]<=0;for(i=0;i<3;i=i+1)y[i]<=0;out_valid<=0;end
        else if(in_valid) begin
            for(i=0;i<16;i=i+1) begin h[i]=b1[i];for(j=0;j<8;j=j+1)h[i]=q_add(h[i],q_mul(w1[i][j],x[j]));if(h[i]<0)h[i]=0;end
            for(i=0;i<3;i=i+1) begin z=b2[i];for(j=0;j<16;j=j+1)z=q_add(z,q_mul(w2[i][j],h[j]));y[i]<=z;end
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module q_learning_update(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t qsa,reward,max_next_q,alpha,discount,
    output hft_fixed_pkg::q_t qsa_new,td_error,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t td;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin qsa_new<=0;td_error<=0;out_valid<=0;end
        else if(in_valid) begin
            td=q_sub(q_add(reward,q_mul(discount,max_next_q)),qsa);
            qsa_new<=q_add(qsa,q_mul(alpha,td));td_error<=td;out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module ppo_clip_objective(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t ratio,advantage,eps,
    output hft_fixed_pkg::q_t objective,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t hi,lo,a,b;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin objective<=0;out_valid<=0;end
        else if(in_valid) begin
            lo=q_sub(Q_ONE,eps);hi=q_add(Q_ONE,eps);
            a=q_mul(ratio,advantage);b=q_mul(q_min(q_max(ratio,lo),hi),advantage);
            objective<=q_min(a,b);out_valid<=1;
        end else out_valid<=0;
    end
endmodule
