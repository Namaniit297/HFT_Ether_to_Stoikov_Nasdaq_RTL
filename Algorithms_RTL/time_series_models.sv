module ar_p #(
    parameter int P=8
)(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x_in,
    input hft_fixed_pkg::q_t coeff [0:P-1],
    input hft_fixed_pkg::q_t intercept,
    output hft_fixed_pkg::q_t prediction,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t hist[0:P-1]; q_t sum; integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin for(i=0;i<P;i=i+1) hist[i]<=0;prediction<=0;out_valid<=0; end
        else if(in_valid) begin
            sum=intercept;
            sum=q_add(sum,q_mul(coeff[0],x_in));
            for(i=1;i<P;i=i+1) sum=q_add(sum,q_mul(coeff[i],hist[i-1]));
            prediction<=sum;
            for(i=P-1;i>0;i=i-1) hist[i]<=hist[i-1];
            hist[0]<=x_in;
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module ma_q #(
    parameter int Q=4
)(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t innovation,
    input hft_fixed_pkg::q_t theta [0:Q-1],
    input hft_fixed_pkg::q_t intercept,
    output hft_fixed_pkg::q_t output_value,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t eh[0:Q-1]; q_t sum; integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin for(i=0;i<Q;i=i+1) eh[i]<=0;output_value<=0;out_valid<=0;end
        else if(in_valid) begin
            sum=intercept+innovation;
            for(i=0;i<Q;i=i+1) sum=q_add(sum,q_mul(theta[i],eh[i]));
            output_value<=sum;
            for(i=Q-1;i>0;i=i-1) eh[i]<=eh[i-1];
            eh[0]<=innovation;out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module arima_101(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x_t,x_prev,innovation_prev,phi,theta,c,
    output hft_fixed_pkg::q_t prediction,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t dx;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin prediction<=0;out_valid<=0;end
        else if(in_valid) begin
            dx=q_sub(x_t,x_prev);
            prediction<=q_add(x_t,q_add(c,q_add(q_mul(phi,dx),q_mul(theta,innovation_prev))));
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module var_2x2(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x0,x1,
    input hft_fixed_pkg::q_t A00,A01,A10,A11,C0,C1,
    output hft_fixed_pkg::q_t y0,y1,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin y0<=0;y1<=0;out_valid<=0;end
        else begin
            y0<=q_add(C0,q_add(q_mul(A00,x0),q_mul(A01,x1)));
            y1<=q_add(C1,q_add(q_mul(A10,x0),q_mul(A11,x1)));
            out_valid<=in_valid;
        end
    end
endmodule

module cusum_change_detector(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x,drift,threshold,
    output logic positive_change,negative_change,
    output logic [31:0] positive_score,negative_score,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t sp,sn;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sp<=0;sn<=0;positive_change<=0;negative_change<=0;positive_score<=0;negative_score<=0;out_valid<=0;end
        else if(in_valid) begin
            sp=q_max(q_add(sp,q_sub(x,drift)),0);
            sn=q_min(q_add(sn,q_add(x,drift)),0);
            positive_change <= (sp>threshold); negative_change <= (q_abs(sn)>threshold);
            positive_score<=sp[31:0]; negative_score<=q_abs(sn);
            if(sp>threshold) sp=0; if(q_abs(sn)>threshold) sn=0;
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule
