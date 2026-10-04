module twap_scheduler(
    input logic clk,rst_n,in_valid,
    input logic [31:0] total_qty,num_slices,slice_index,
    output logic [31:0] slice_qty,qty_last,
    output logic out_valid
);
    logic [63:0] base;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin slice_qty<=0;qty_last<=0;out_valid<=0;end
        else if(in_valid && num_slices!=0) begin
            base=total_qty/num_slices;
            slice_qty<=base[31:0];
            qty_last<= total_qty - base*(num_slices-1);
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module vwap_scheduler(
    input logic clk,rst_n,in_valid,
    input logic [31:0] total_qty,
    input hft_fixed_pkg::q_t volume_fraction,
    output logic [31:0] target_qty,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t q;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin target_qty<=0;out_valid<=0;end
        else if(in_valid) begin q=q_mul(q_from_int($signed(total_qty)),volume_fraction);target_qty<=q_to_int(q);out_valid<=1;end else out_valid<=0;
    end
endmodule

module pov_scheduler(
    input logic clk,rst_n,in_valid,
    input logic [31:0] market_volume,
    input hft_fixed_pkg::q_t participation,
    output logic [31:0] target_qty,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t q;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin target_qty<=0;out_valid<=0;end
        else if(in_valid) begin q=q_mul(q_from_int($signed(market_volume)),participation);target_qty<=q_to_int(q);out_valid<=1;end else out_valid<=0;
    end
endmodule

module almgren_chriss_schedule(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t X0,T,sigma,eta,lambda_risk,
    input logic [31:0] step_index,num_steps,
    output hft_fixed_pkg::q_t remaining_x,target_trade,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t kapp,kt,knext,den,xnow,xnext,t_now,t_next;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin remaining_x<=0;target_trade<=0;out_valid<=0;end
        else if(in_valid && num_steps!=0 && eta>0 && lambda_risk>0) begin
            // AC continuous optimum for linear temporary impact/Brownian risk:
            // x(t)=X0*sinh(kappa*(T-t))/sinh(kappa*T),
            // kappa=sqrt(lambda*sigma^2/eta).
            kapp=q_sqrt(q_div(q_mul(lambda_risk,q_mul(sigma,sigma)),eta));
            t_now=q_div(q_mul(T,q_from_int($signed(step_index))),q_from_int($signed(num_steps)));
            if(step_index<num_steps) t_next=q_div(q_mul(T,q_from_int($signed(step_index+1))),q_from_int($signed(num_steps))); else t_next=T;
            kt=q_mul(kapp,q_sub(T,t_now)); knext=q_mul(kapp,q_sub(T,t_next));
            den=q_sinh(q_mul(kapp,T));
            if(den!=0) begin xnow=q_mul(X0,q_div(q_sinh(kt),den)); xnext=q_mul(X0,q_div(q_sinh(knext),den));end
            else begin xnow=0;xnext=0;end
            remaining_x<=xnow;target_trade<=q_sub(xnow,xnext);out_valid<=1;
        end else if(in_valid) begin remaining_x<=0;target_trade<=0;out_valid<=1;end
        else out_valid<=0;
    end
endmodule

module smart_order_router_2venue(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t px_a,px_b,fee_a,fee_b,slip_a,slip_b,lat_penalty_a,lat_penalty_b,
    input logic [31:0] qty,
    output logic selected_venue,
    output logic [31:0] selected_qty,
    output hft_fixed_pkg::q_t expected_cost_a,expected_cost_b,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin selected_venue<=0;selected_qty<=0;expected_cost_a<=0;expected_cost_b<=0;out_valid<=0;end
        else if(in_valid) begin
            expected_cost_a<=q_add(px_a,q_add(fee_a,q_add(slip_a,lat_penalty_a)));
            expected_cost_b<=q_add(px_b,q_add(fee_b,q_add(slip_b,lat_penalty_b)));
            selected_venue <= (q_add(px_b,q_add(fee_b,q_add(slip_b,lat_penalty_b))) < q_add(px_a,q_add(fee_a,q_add(slip_a,lat_penalty_a))));
            selected_qty<=qty;out_valid<=1;
        end else out_valid<=0;
    end
endmodule
