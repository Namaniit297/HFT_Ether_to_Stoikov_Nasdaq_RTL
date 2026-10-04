// Integration wrapper: exposes a common feature/state bus and selects one
// mathematical model per family. Complex estimators are deliberately kept as
// independent modules so they can be compared, bypassed, or replicated.
module hft_quant_model_bank(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t mid,bid,ask,bid_qty_q,ask_qty_q,inventory,
    input hft_fixed_pkg::q_t gamma,kappa,tau,sigma,sigma2,
    input logic [2:0] mm_model_sel,
    output hft_fixed_pkg::q_t microprice,obi,as_reservation,as_spread,mm_bid,mm_ask,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t as_bid,as_ask;
    logic as_v;
    microprice_l1 u_mp(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.bid_px(bid),.ask_px(ask),.bid_qty(q_to_int(bid_qty_q)),.ask_qty(q_to_int(ask_qty_q)),.microprice(microprice),.out_valid());
    avellaneda_stoikov_mm u_as(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.mid(mid),.inventory(inventory),.gamma(gamma),.sigma2(sigma2),.tau(tau),.kappa(kappa),.reservation_price(as_reservation),.total_spread(as_spread),.bid_price(as_bid),.ask_price(as_ask),.out_valid(as_v));
    always_comb begin
        case(mm_model_sel)
            3'd0: begin mm_bid=as_bid;mm_ask=as_ask;end
            3'd1: begin mm_bid=q_sub(mid,sigma);mm_ask=q_add(mid,sigma);end
            3'd2: begin mm_bid=q_sub(microprice,sigma);mm_ask=q_add(microprice,sigma);end
            default: begin mm_bid=as_bid;mm_ask=as_ask;end
        endcase
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) out_valid<=0; else out_valid<=in_valid;
    end
endmodule
