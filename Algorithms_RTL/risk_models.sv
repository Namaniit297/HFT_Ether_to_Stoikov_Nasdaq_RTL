module parametric_var_normal(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t portfolio_value,volatility,z_quantile,horizon,
    output hft_fixed_pkg::q_t var_loss,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin var_loss<=0;out_valid<=0;end
        else if(in_valid) begin var_loss<=q_mul(q_mul(q_mul(portfolio_value,volatility),z_quantile),q_sqrt(horizon));out_valid<=1;end else out_valid<=0;
    end
endmodule

module expected_shortfall_normal(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t portfolio_value,volatility,alpha_tail,z_quantile,
    output hft_fixed_pkg::q_t es_loss,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t z,phi,tail;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin es_loss<=0;out_valid<=0;end
        else if(in_valid) begin
            z=z_quantile;
            phi=q_mul(Q_INV_SQRT_2PI,q_exp(q_neg(q_mul(z,z))>>>1));
            tail=q_sub(Q_ONE,alpha_tail);
            es_loss<=q_mul(q_mul(portfolio_value,volatility),q_div(phi,tail));out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module volatility_target_position(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t target_vol,current_vol,capital_per_unit,
    output logic signed [31:0] position_size,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t ratio,size;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin position_size<=0;out_valid<=0;end
        else if(in_valid) begin ratio=q_div(target_vol,current_vol);size=q_div(ratio,capital_per_unit);position_size<=q_to_int(size);out_valid<=1;end else out_valid<=0;
    end
endmodule

module max_drawdown_monitor(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t pnl,
    output hft_fixed_pkg::q_t peak,drawdown,
    output logic breach,
    input hft_fixed_pkg::q_t limit,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t pk,dd;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin pk<=0;peak<=0;drawdown<=0;breach<=0;out_valid<=0;end
        else if(in_valid) begin
            pk=q_max(pk,pnl);dd=q_sub(pk,pnl);peak<=pk;drawdown<=dd;breach<=dd>limit;out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module deterministic_risk_gate(
    input logic clk,rst_n,in_valid,
    input logic signed [31:0] position,order_qty,
    input logic signed [31:0] max_position,
    input hft_fixed_pkg::q_t order_price,reference_price,price_band,
    input logic kill_switch,rate_ok,credit_ok,
    output logic approved,
    output logic [7:0] reject_reason,
    output logic out_valid
);
    logic pos_ok,price_ok;
    always_comb begin
        pos_ok = ($signed(position)+$signed(order_qty) <= $signed(max_position)) && ($signed(position)+$signed(order_qty) >= -$signed(max_position));
        price_ok = q_abs(order_price-reference_price)<=price_band;
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin approved<=0;reject_reason<=0;out_valid<=0;end
        else if(in_valid) begin
            approved<=pos_ok && price_ok && !kill_switch && rate_ok && credit_ok;
            if(kill_switch) reject_reason<=8'h01; else if(!pos_ok) reject_reason<=8'h02; else if(!price_ok) reject_reason<=8'h04; else if(!rate_ok) reject_reason<=8'h08; else if(!credit_ok) reject_reason<=8'h10; else reject_reason<=0;
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule
