module adf_decision(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t t_stat,critical_value,
    output logic reject_unit_root,out_valid
);
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin reject_unit_root<=0;out_valid<=0;end
        else begin reject_unit_root<=t_stat<critical_value;out_valid<=in_valid;end
    end
endmodule

module johansen_decision(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t trace_stat,max_eigen_stat,
    input hft_fixed_pkg::q_t trace_critical,max_eigen_critical,
    output logic trace_reject,max_eigen_reject,out_valid
);
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin trace_reject<=0;max_eigen_reject<=0;out_valid<=0;end
        else begin trace_reject<=trace_stat>trace_critical;max_eigen_reject<=max_eigen_stat>max_eigen_critical;out_valid<=in_valid;end
    end
endmodule
