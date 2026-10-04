module cross_exchange_arbitrage(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t bid_a,ask_a,bid_b,ask_b,total_cost,
    input logic [31:0] qty_a_bid,qty_a_ask,qty_b_bid,qty_b_ask,max_qty,
    output logic buy_a_sell_b,buy_b_sell_a,
    output hft_fixed_pkg::q_t edge_a_to_b,edge_b_to_a,
    output logic [31:0] arb_qty,
    output logic out_valid
);
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin buy_a_sell_b<=0;buy_b_sell_a<=0;edge_a_to_b<=0;edge_b_to_a<=0;arb_qty<=0;out_valid<=0;end
        else if(in_valid) begin
            edge_a_to_b<=bid_b-ask_a-total_cost; edge_b_to_a<=bid_a-ask_b-total_cost;
            buy_a_sell_b <= (bid_b > ask_a+total_cost); buy_b_sell_a <= (bid_a > ask_b+total_cost);
            if(buy_a_sell_b) arb_qty <= (qty_a_ask<qty_b_bid ? qty_a_ask:qty_b_bid) > max_qty ? max_qty : (qty_a_ask<qty_b_bid ? qty_a_ask:qty_b_bid);
            else if(buy_b_sell_a) arb_qty <= (qty_b_ask<qty_a_bid ? qty_b_ask:qty_a_bid) > max_qty ? max_qty : (qty_b_ask<qty_a_bid ? qty_b_ask:qty_a_bid);
            else arb_qty<=0;
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module basis_arbitrage(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t future_price,spot_price,fair_basis,threshold,
    output hft_fixed_pkg::q_t basis,residual,
    output logic cash_and_carry,reverse_cash_and_carry,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin basis<=0;residual<=0;cash_and_carry<=0;reverse_cash_and_carry<=0;out_valid<=0;end
        else if(in_valid) begin
            basis<=q_sub(future_price,spot_price); residual<=q_sub(q_sub(future_price,spot_price),fair_basis);
            cash_and_carry<=q_sub(q_sub(future_price,spot_price),fair_basis)>threshold;
            reverse_cash_and_carry<=q_sub(q_sub(future_price,spot_price),fair_basis)<q_neg(threshold);out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module triangular_arbitrage(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t r_ab,r_bc,r_ca,cost_fraction,
    output hft_fixed_pkg::q_t gross_ratio,net_ratio,
    output logic opportunity,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t gross,cost;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin gross_ratio<=0;net_ratio<=0;opportunity<=0;out_valid<=0;end
        else if(in_valid) begin gross=q_mul(q_mul(r_ab,r_bc),r_ca);cost=q_pow_pos(q_sub(Q_ONE,cost_fraction),Q_ONE);gross_ratio<=gross; cost=q_sub(Q_ONE,cost_fraction); net_ratio<=q_mul(gross,cost); opportunity<=q_mul(gross,cost)>Q_ONE;out_valid<=1;end else out_valid<=0;
    end
endmodule

module lead_lag_regression(
    input logic clk,rst_n,in_valid,window_close,
    input hft_fixed_pkg::q_t leader_return,follower_return,
    output hft_fixed_pkg::q_t beta,prediction,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    function automatic logic signed [95:0] sat96_product_shift16(input logic signed [95:0] a, input logic signed [95:0] b);
        logic signed [191:0] p; begin p=a*b; sat96_product_shift16=p>>>16; end
    endfunction
    logic signed [95:0] sx,sy,sxx,sxy; integer n;
    q_t den,num,b;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sx<=0;sy<=0;sxx<=0;sxy<=0;n<=0;beta<=0;prediction<=0;out_valid<=0;end
        else begin
            out_valid<=0;
            if(in_valid) begin sx<=sx+leader_return;sy<=sy+follower_return;sxx<=sxx+$signed(leader_return)*$signed(leader_return);sxy<=sxy+$signed(leader_return)*$signed(follower_return);n<=n+1;end
            if(window_close && n>2) begin den=$signed(n)*sxx-sat96_product_shift16(sx,sx);num=$signed(n)*sxy-sat96_product_shift16(sx,sy);b=q_div_ext(num,den);beta<=b;prediction<=q_mul(b,leader_return);sx<=0;sy<=0;sxx<=0;sxy<=0;n<=0;out_valid<=1;end
        end
    end
endmodule
