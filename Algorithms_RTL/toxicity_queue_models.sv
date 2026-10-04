module vpin_bvc #(
    parameter int BUCKETS=32
)(
    input logic clk,rst_n,in_valid,bucket_close,
    input hft_fixed_pkg::q_t buy_volume,sell_volume,
    input hft_fixed_pkg::q_t bucket_volume,
    output hft_fixed_pkg::q_t vpin,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t abs_imb,imb_sum; integer count;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin imb_sum<=0;count<=0;vpin<=0;out_valid<=0;end
        else begin
            out_valid<=0;
            if(in_valid && bucket_close) begin
                abs_imb=q_abs(q_sub(buy_volume,sell_volume));
                imb_sum<=q_add(imb_sum,abs_imb);
                count=count+1;
                if(count>=BUCKETS-1) begin
                    vpin<=q_div(q_add(imb_sum,abs_imb),q_mul(q_from_int(BUCKETS),bucket_volume));
                    imb_sum<=0;count=0;out_valid<=1;
                end
            end
        end
    end
endmodule

module kyle_lambda_online(
    input logic clk,rst_n,in_valid,window_close,
    input hft_fixed_pkg::q_t signed_flow,price_change,
    output hft_fixed_pkg::q_t lambda,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t sf,sp,sff,sfp; integer n;
    q_t den,num;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sf<=0;sp<=0;sff<=0;sfp<=0;n<=0;lambda<=0;out_valid<=0;end
        else begin
            out_valid<=0;
            if(in_valid) begin
                sf<=q_add(sf,signed_flow); sp<=q_add(sp,price_change);
                sff<=q_add(sff,q_mul(signed_flow,signed_flow));
                sfp<=q_add(sfp,q_mul(signed_flow,price_change)); n<=n+1;
            end
            if(window_close && n>1) begin
                den=q_sub(sff,q_div(q_mul(sf,sf),q_from_int(n)));
                num=q_sub(sfp,q_div(q_mul(sf,sp),q_from_int(n)));
                lambda<=q_div(num,den); out_valid<=1;
                sf<=0;sp<=0;sff<=0;sfp<=0;n<=0;
            end
        end
    end
endmodule

module adverse_selection_estimator(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t fill_price,mid_at_fill,mid_after,
    input logic fill_buy_side,
    output hft_fixed_pkg::q_t adverse_cost,
    output logic adverse_is_bad,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t delta;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin adverse_cost<=0;adverse_is_bad<=0;out_valid<=0;end
        else begin
            out_valid<=in_valid;
            if(in_valid) begin
                delta=q_sub(q_abs(q_sub(mid_after,mid_at_fill)),q_abs(q_sub(fill_price,mid_at_fill)));
                adverse_cost<=q_max(delta,0);
                adverse_is_bad <= fill_buy_side ? (mid_after > fill_price) : (mid_after < fill_price);
            end
        end
    end
endmodule

module queue_fill_probability_poisson(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t lambda_rate, horizon,
    input logic [31:0] queue_ahead,
    output hft_fixed_pkg::q_t fill_probability,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t mu, cdf_sum, term; integer k;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin fill_probability<=0;out_valid<=0;end
        else if(in_valid) begin
            // P(N>=K)=1-P(N<=K-1), N~Poisson(lambda*T).
            if(queue_ahead==0) begin fill_probability<=Q_ONE; out_valid<=1; end
            else begin
            mu=q_mul(lambda_rate,horizon);
            term=q_exp(q_neg(mu)); cdf_sum=term;
            for(k=1;k<33;k=k+1) begin
                if(k<=queue_ahead-1) begin
                    term=q_mul(term,q_div(mu,q_from_int(k)));
                    cdf_sum=q_add(cdf_sum,term);
                end
            end
            fill_probability<=q_sub(Q_ONE,q_min(cdf_sum,Q_ONE));
            out_valid<=1;
            end
        end else out_valid<=0;
    end
endmodule

module queue_position_tracker(
    input logic clk,rst_n,
    input logic event_valid,
    input logic [1:0] event_type, // 0=market consume,1=ahead cancel,2=join ahead
    input logic [31:0] event_qty,
    input logic [31:0] my_qty,
    output logic [31:0] ahead_qty,
    output logic filled,
    output logic out_valid
);
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin ahead_qty<=0;filled<=0;out_valid<=0;end
        else begin
            out_valid<=event_valid; filled<=0;
            if(event_valid) begin
                case(event_type)
                    2'd0,2'd1: begin
                        if(event_qty>=ahead_qty) ahead_qty<=0; else ahead_qty<=ahead_qty-event_qty;
                        if(event_type==0 && event_qty>=ahead_qty+my_qty) filled<=1;
                    end
                    2'd2: ahead_qty<=ahead_qty+event_qty;
                    default: ;
                endcase
            end
        end
    end
endmodule
