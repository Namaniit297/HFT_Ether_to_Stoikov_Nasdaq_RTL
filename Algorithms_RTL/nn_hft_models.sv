module cnn1d_relu #(
    parameter int N=16,
    parameter int K=3
)(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x [0:N-1],
    input hft_fixed_pkg::q_t w [0:K-1],bias,
    output hft_fixed_pkg::q_t y [0:N-K],
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t acc; integer i,j;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin for(i=0;i<=N-K;i=i+1)y[i]<=0;out_valid<=0;end
        else if(in_valid) begin
            for(i=0;i<=N-K;i=i+1) begin acc=bias;for(j=0;j<K;j=j+1)acc=q_add(acc,q_mul(w[j],x[i+j]));if(acc<0)acc=0;y[i]<=acc;end
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module lstm_cell_4(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x[0:3],h_prev[0:3],c_prev[0:3],
    input hft_fixed_pkg::q_t wi[0:3][0:3],ui[0:3][0:3],bi[0:3],
    input hft_fixed_pkg::q_t wf[0:3][0:3],uf[0:3][0:3],bf[0:3],
    input hft_fixed_pkg::q_t wo[0:3][0:3],uo[0:3][0:3],bo[0:3],
    input hft_fixed_pkg::q_t wg[0:3][0:3],ug[0:3][0:3],bg[0:3],
    output hft_fixed_pkg::q_t h[0:3],c[0:3],
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t si,sf,so,sg,ii,ff,oo,gg; integer i,j;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin for(i=0;i<4;i=i+1) begin h[i]<=0;c[i]<=0;end out_valid<=0;end
        else if(in_valid) begin
            for(i=0;i<4;i=i+1) begin
                si=bi[i];sf=bf[i];so=bo[i];sg=bg[i];
                for(j=0;j<4;j=j+1) begin
                    si=q_add(si,q_mul(wi[i][j],x[j]));si=q_add(si,q_mul(ui[i][j],h_prev[j]));
                    sf=q_add(sf,q_mul(wf[i][j],x[j]));sf=q_add(sf,q_mul(uf[i][j],h_prev[j]));
                    so=q_add(so,q_mul(wo[i][j],x[j]));so=q_add(so,q_mul(uo[i][j],h_prev[j]));
                    sg=q_add(sg,q_mul(wg[i][j],x[j]));sg=q_add(sg,q_mul(ug[i][j],h_prev[j]));
                end
                ii=q_sigmoid(si);ff=q_sigmoid(sf);oo=q_sigmoid(so);gg=q_tanh(sg);
                c[i]<=q_add(q_mul(ff,c_prev[i]),q_mul(ii,gg));
                h[i]<=q_mul(oo,q_tanh(q_add(q_mul(ff,c_prev[i]),q_mul(ii,gg))));
            end
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module attention_4x4(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t q[0:3],
    input hft_fixed_pkg::q_t k[0:3][0:3],
    input hft_fixed_pkg::q_t v[0:3][0:3],
    output hft_fixed_pkg::q_t y[0:3],
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t score[0:3],e[0:3],den,outv[0:3],acc; integer i,j;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin for(i=0;i<4;i=i+1)y[i]<=0;out_valid<=0;end
        else if(in_valid) begin
            // Single-head scaled dot-product attention with D=4, so sqrt(D)=2.
            for(i=0;i<4;i=i+1) begin
                score[i]=0;
                for(j=0;j<4;j=j+1) score[i]=q_add(score[i],q_mul(q[j],k[i][j]));
                score[i]=q_div(score[i],Q_TWO);
                e[i]=q_exp(score[i]);
            end
            den=0;for(i=0;i<4;i=i+1)den=q_add(den,e[i]);
            for(j=0;j<4;j=j+1) begin
                acc=0;
                for(i=0;i<4;i=i+1) acc=q_add(acc,q_mul(q_div(e[i],den),v[i][j]));
                y[j]<=acc;
            end
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module decision_tree_4leaf(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x0,x1,th0,th1,score0,score1,score2,score3,
    output hft_fixed_pkg::q_t score,
    output logic out_valid
);
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin score<=0;out_valid<=0;end
        else if(in_valid) begin
            if(x0<th0) score<= (x1<th1)?score0:score1; else score<= (x1<th1)?score2:score3;
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule
