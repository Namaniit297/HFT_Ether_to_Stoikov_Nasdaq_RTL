module microprice_l1(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t bid_px,ask_px,
    input logic [31:0] bid_qty,ask_qty,
    output hft_fixed_pkg::q_t microprice,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t num,den,mp_c;
    always_comb begin
        num=q_add(q_mul(ask_px,q_from_int($signed(bid_qty))),q_mul(bid_px,q_from_int($signed(ask_qty))));
        den=q_from_int($signed(bid_qty+ask_qty));
        if(den==0) mp_c=q_mul(q_add(bid_px,ask_px),Q_HALF);
        else mp_c=q_div(num,den);
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin microprice<=0;out_valid<=0;end
        else begin microprice<=mp_c;out_valid<=in_valid;end
    end
endmodule

module weighted_mid_n(
    input logic clk,rst_n,in_valid,
    input int signed N,
    input hft_fixed_pkg::q_t bid_px [0:7],
    input hft_fixed_pkg::q_t ask_px [0:7],
    input logic [31:0] bid_qty [0:7],
    input logic [31:0] ask_qty [0:7],
    output hft_fixed_pkg::q_t fair,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t num_c,den_c,w_q; integer i;
    always_comb begin
        num_c=0; den_c=0;
        for(i=0;i<8;i=i+1) begin
            if(i<N) begin
                w_q=q_div(Q_ONE,q_from_int(i+1));
                num_c=q_add(num_c,q_mul(q_mul(bid_px[i],q_from_int($signed(bid_qty[i]))),w_q));
                num_c=q_add(num_c,q_mul(q_mul(ask_px[i],q_from_int($signed(ask_qty[i]))),w_q));
                den_c=q_add(den_c,q_mul(q_from_int($signed(bid_qty[i]+ask_qty[i])),w_q));
            end
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin fair<=0;out_valid<=0;end
        else begin fair <= (den_c==0)?0:q_div(num_c,den_c); out_valid<=in_valid; end
    end
endmodule

module obi_multilevel #(
    parameter int LEVELS=8
)(
    input logic clk,rst_n,in_valid,
    input logic [31:0] bid_qty [0:LEVELS-1],
    input logic [31:0] ask_qty [0:LEVELS-1],
    input hft_fixed_pkg::q_t weights [0:LEVELS-1],
    output hft_fixed_pkg::q_t obi,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t b,a,num,den,obi_c;
    integer i;
    always_comb begin
        b=0;a=0;
        for(i=0;i<LEVELS;i=i+1) begin
            b=q_add(b,q_mul(q_from_int($signed(bid_qty[i])),weights[i]));
            a=q_add(a,q_mul(q_from_int($signed(ask_qty[i])),weights[i]));
        end
        num=q_sub(b,a); den=q_add(b,a);
        if(den==0) obi_c=0; else obi_c=q_div(num,den);
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin obi<=0;out_valid<=0;end
        else begin obi<=obi_c;out_valid<=in_valid;end
    end
endmodule

module ofi_best_level(
    input logic clk,rst_n,in_valid,
    input logic signed [31:0] bid_px,bid_px_prev,ask_px,ask_px_prev,
    input logic [31:0] bid_qty,bid_qty_prev,ask_qty,ask_qty_prev,
    output logic signed [63:0] ofi,
    output logic out_valid
);
    logic signed [63:0] eb,ea;
    always_comb begin
        if(bid_px>bid_px_prev) eb=$signed({1'b0,bid_qty});
        else if(bid_px==bid_px_prev) eb=$signed({1'b0,bid_qty})-$signed({1'b0,bid_qty_prev});
        else eb=-$signed({1'b0,bid_qty_prev});
        if(ask_px>ask_px_prev) ea=-$signed({1'b0,ask_qty_prev});
        else if(ask_px==ask_px_prev) ea=$signed({1'b0,ask_qty_prev})-$signed({1'b0,ask_qty});
        else ea=$signed({1'b0,ask_qty});
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin ofi<=0;out_valid<=0;end
        else begin if(in_valid) ofi<=eb+ea; out_valid<=in_valid;end
    end
endmodule

module ofi_multilevel_incremental #(
    parameter int LEVELS=8
)(
    input logic clk,rst_n,in_valid,
    input logic signed [63:0] level_ofi [0:LEVELS-1],
    input hft_fixed_pkg::q_t inv_depth_norm [0:LEVELS-1],
    output hft_fixed_pkg::q_t integrated_ofi,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t acc; integer i;
    always_comb begin
        acc=0;
        for(i=0;i<LEVELS;i=i+1) acc=q_add(acc,q_mul(q_from_int(level_ofi[i][31:0]),inv_depth_norm[i]));
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin integrated_ofi<=0;out_valid<=0;end
        else begin integrated_ofi<=acc;out_valid<=in_valid;end
    end
endmodule

module trade_classifier_bvc(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t price_change,
    input hft_fixed_pkg::q_t sigma,
    input hft_fixed_pkg::q_t volume,
    output hft_fixed_pkg::q_t buy_volume,
    output hft_fixed_pkg::q_t sell_volume,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t prob;
    always_comb begin
        if(sigma>0) prob=q_cdf(q_div(price_change,sigma)); else prob=Q_HALF;
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin buy_volume<=0;sell_volume<=0;out_valid<=0;end
        else if(in_valid) begin buy_volume<=q_mul(volume,prob);sell_volume<=q_mul(volume,q_sub(Q_ONE,prob));out_valid<=1;end
        else out_valid<=0;
    end
endmodule
