module zscore_rolling(
    input logic clk,rst_n,in_valid,window_close,
    input hft_fixed_pkg::q_t x,
    output hft_fixed_pkg::q_t mean,variance,z,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    logic signed [95:0] sx,sxx; integer n; q_t m,v;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sx<=0;sxx<=0;n<=0;mean<=0;variance<=0;z<=0;out_valid<=0;end
        else begin
            out_valid<=0;
            if(in_valid) begin sx<=sx+x; sxx<=sxx+q_mul(x,x); n<=n+1; end
            if(window_close && n>1) begin
                m=q_div_ext(sx, q_from_int64(n));
                v=q_sub(q_div(sat64(sxx),q_from_int(n)),q_mul(m,m));
                if(v<0) v=0;
                mean<=m;variance<=v;z<=q_div(q_sub(x,m),q_sqrt(v));
                sx<=0;sxx<=0;n<=0;out_valid<=1;
            end
        end
    end
endmodule

module rolling_ols_2var(
    input logic clk,rst_n,in_valid,window_close,
    input hft_fixed_pkg::q_t x,y,
    output hft_fixed_pkg::q_t alpha,beta,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    function automatic logic signed [95:0] sat96_product_shift16(input logic signed [95:0] a, input logic signed [95:0] b);
        logic signed [191:0] p;
        begin p=a*b; sat96_product_shift16=p >>> 16; end
    endfunction
    logic signed [95:0] sx,sy,sxx,sxy; integer n; q_t den,num,b,a;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sx<=0;sy<=0;sxx<=0;sxy<=0;n<=0;alpha<=0;beta<=0;out_valid<=0;end
        else begin
            out_valid<=0;
            if(in_valid) begin sx<=sx+x;sy<=sy+y;sxx<=sxx+q_mul(x,x);sxy<=sxy+q_mul(x,y);n<=n+1;end
            if(window_close && n>2) begin
                den=$signed(n)*sxx-sat96_product_shift16(sx,sx); num=$signed(n)*sxy-sat96_product_shift16(sx,sy);
                b=q_div_ext(num,den);
                a=q_sub(q_div_ext(sy, q_from_int64(n)),q_mul(b,q_div_ext(sx, q_from_int64(n))));
                beta<=b;alpha<=a;sx<=0;sy<=0;sxx<=0;sxy<=0;n<=0;out_valid<=1;
            end
        end
    end
endmodule

module adf1_intercept(
    input logic clk,rst_n,in_valid,window_close,
    input hft_fixed_pkg::q_t y_lag,dy,
    output hft_fixed_pkg::q_t rho,intercept,t_stat,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    function automatic logic signed [95:0] sat96_product_shift16(input logic signed [95:0] a, input logic signed [95:0] b);
        logic signed [191:0] p; begin p=a*b; sat96_product_shift16=p>>>16; end
    endfunction
    logic signed [95:0] sx,sy,sxx,sxy,syy; integer n;
    q_t den,num,b,a,sse,mse,se,sxxc,sxyc,syyc,meanx,meany,prodxy,prodx2,prody2;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sx<=0;sy<=0;sxx<=0;sxy<=0;syy<=0;n<=0;rho<=0;intercept<=0;t_stat<=0;out_valid<=0;end
        else begin
            out_valid<=0;
            if(in_valid) begin sx<=sx+y_lag;sy<=sy+dy;sxx<=sxx+q_mul(y_lag,y_lag);sxy<=sxy+q_mul(y_lag,dy);syy<=syy+q_mul(dy,dy);n<=n+1;end
            if(window_close && n>2) begin
                den=q_sub(sat64(n*sxx),sat64(sat96_product_shift16(sx,sx)));
                num=q_sub(sat64(n*sxy),sat64(sat96_product_shift16(sx,sy)));
                b=q_div_ext(num,den);
                meanx=q_div_ext(sx, q_from_int64(n)); meany=q_div_ext(sy, q_from_int64(n));
                a=q_sub(meany,q_mul(b,meanx));
                prodxy=q_div_ext(sat96_product_shift16(sx,sy), q_from_int64(n));
                prodx2=q_div_ext(sat96_product_shift16(sx,sx), q_from_int64(n));
                prody2=q_div_ext(sat96_product_shift16(sy,sy), q_from_int64(n));
                sxxc=q_sub(sat64(sxx),prodx2); sxy_c=sat64(sxy); sxyc=q_sub(sat64(sxy),q_div_ext(sat96_product_shift16(sx,sy), q_from_int64(n)));
                syyc=q_sub(sat64(syy),prody2);
                sse=q_sub(syyc,q_mul(b,sxyc)); rho<=b;intercept<=a;
                if(n>2 && sse>0 && sxxc>0) begin mse=q_div(sse,q_from_int(n-2));se=q_sqrt(q_div(mse,sxxc));t_stat<=q_div(b,se);end else t_stat<=0;
                sx<=0;sy<=0;sxx<=0;sxy<=0;syy<=0;n<=0;out_valid<=1;
            end
        end
    end
endmodule

module engle_granger_stage1(
    input logic clk,rst_n,in_valid,window_close,
    input hft_fixed_pkg::q_t x,y,
    output hft_fixed_pkg::q_t alpha,beta,
    output logic out_valid
);
    rolling_ols_2var u_ols(.clk(clk),.rst_n(rst_n),.in_valid(in_valid),.window_close(window_close),.x(x),.y(y),.alpha(alpha),.beta(beta),.out_valid(out_valid));
endmodule

module engle_granger_spread(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x,y,alpha,beta,
    output hft_fixed_pkg::q_t spread,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin spread<=0;out_valid<=0;end
        else begin spread<=q_sub(y,q_add(alpha,q_mul(beta,x)));out_valid<=in_valid;end
    end
endmodule

module ou_mle_ar1(
    input logic clk,rst_n,in_valid,window_close,
    input hft_fixed_pkg::q_t x_t,x_prev,dt,
    output hft_fixed_pkg::q_t phi,kappa,mu,sigma2,half_life,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    function automatic logic signed [95:0] sat96_product_shift16(input logic signed [95:0] a, input logic signed [95:0] b);
        logic signed [191:0] p; begin p=a*b; sat96_product_shift16=p>>>16; end
    endfunction
    logic signed [95:0] sx,sy,sxx,sxy,syy; integer n;
    q_t den,num,phic,meanx,meany,muc,prodxx,prodxy,prodyy,sxxc,sxyc,syyc,sse,resvar,kc;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin sx<=0;sy<=0;sxx<=0;sxy<=0;syy<=0;n<=0;phi<=0;kappa<=0;mu<=0;sigma2<=0;half_life<=0;out_valid<=0;end
        else begin
            out_valid<=0;
            if(in_valid) begin sx<=sx+x_prev;sy<=sy+x_t;sxx<=sxx+q_mul(x_prev,x_prev);sxy<=sxy+q_mul(x_prev,x_t);syy<=syy+q_mul(x_t,x_t);n<=n+1;end
            if(window_close && n>2) begin
                prodxx=q_div_ext(sat96_product_shift16(sx,sx), q_from_int64(n));
                prodxy=q_div_ext(sat96_product_shift16(sx,sy), q_from_int64(n));
                prodyy=q_div_ext(sat96_product_shift16(sy,sy), q_from_int64(n));
                sxxc=q_sub(sat64(sxx),prodxx);sxyc=q_sub(sat64(sxy),prodxy);syyc=q_sub(sat64(syy),prodyy);
                den=sxxc; num=sxyc; phic=q_div(num,den);
                if(phic<=32'sh00000100) phic=32'sh00000100;
                if(phic>=32'sh0000FFF0) phic=32'sh0000FFF0;
                meanx=q_div_ext(sx, q_from_int64(n));meany=q_div_ext(sy, q_from_int64(n));
                muc=q_div(q_sub(meany,q_mul(phic,meanx)),q_sub(Q_ONE,phic));
                sse=q_sub(syyc,q_mul(phic,sxyc));
                resvar=q_div(sse,q_from_int(n));
                kc=q_div(q_neg(q_ln_pos(phic)),dt);
                phi<=phic;kappa<=kc;mu<=muc;
                sigma2<=q_div(q_mul(q_mul(Q_TWO,kc),resvar),q_sub(Q_ONE,q_mul(phic,phic)));
                half_life<=q_div(Q_LN2,kc);
                sx<=0;sy<=0;sxx<=0;sxy<=0;syy<=0;n<=0;out_valid<=1;
            end
        end
    end
endmodule

module kalman_pairs_2state(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t x_obs,y_obs,q_alpha,q_beta,r_meas,
    output hft_fixed_pkg::q_t alpha_state,beta_state,innovation,innovation_z,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t p00,p01,p10,p11,ph0,ph1,S,k0,k1,nv;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin alpha_state<=0;beta_state<=Q_ONE;p00<=Q_ONE;p01<=0;p10<=0;p11<=Q_ONE;innovation<=0;innovation_z<=0;out_valid<=0;end
        else if(in_valid) begin
            // Random-walk state model: x_t = x_{t-1}+w_t.
            p00=q_add(p00,q_alpha);p11=q_add(p11,q_beta);
            ph0=q_add(p00,q_mul(x_obs,p01));
            ph1=q_add(p10,q_mul(x_obs,p11));
            S=q_add(q_add(p00,q_mul(x_obs,q_add(p01,p10))),q_mul(x_obs,q_mul(p11,x_obs))); S=q_add(S,r_meas);
            nv=q_sub(y_obs,q_add(alpha_state,q_mul(beta_state,x_obs)));
            k0=q_div(ph0,S);k1=q_div(ph1,S);
            alpha_state<=q_add(alpha_state,q_mul(k0,nv)); beta_state<=q_add(beta_state,q_mul(k1,nv));
            p00<=q_sub(p00,q_mul(k0,ph0));p01<=q_sub(p01,q_mul(k0,ph1));
            p10<=q_sub(p10,q_mul(k1,ph0));p11<=q_sub(p11,q_mul(k1,ph1));
            innovation<=nv;innovation_z<=q_div(nv,q_sqrt(S));out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module johansen_2x2_core(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t m00,m01,m10,m11,
    input logic [31:0] sample_count,
    output hft_fixed_pkg::q_t lambda1,lambda2,trace_stat,max_eigen_stat,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    q_t tr,det,disc,l1,l2;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin lambda1<=0;lambda2<=0;trace_stat<=0;max_eigen_stat<=0;out_valid<=0;end
        else if(in_valid) begin
            tr=q_add(m00,m11);det=q_sub(q_mul(m00,m11),q_mul(m01,m10));
            disc=q_sqrt(q_max(q_sub(q_mul(tr,tr),q_mul(Q_TWO,q_mul(Q_TWO,det))),0));
            l1=q_div(q_add(tr,disc),Q_TWO);l2=q_div(q_sub(tr,disc),Q_TWO);
            l1=q_max(q_min(l1,32'sh0000FF00),0);l2=q_max(q_min(l2,32'sh0000FF00),0);
            lambda1<=l1;lambda2<=l2;
            max_eigen_stat<=q_mul(q_from_int($signed(sample_count)) , q_neg(q_ln_pos(q_sub(Q_ONE,l1))));
            trace_stat<=q_mul(q_from_int($signed(sample_count)),q_neg(q_add(q_ln_pos(q_sub(Q_ONE,l1)),q_ln_pos(q_sub(Q_ONE,l2)))));
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule

module vecm_2asset(
    input logic clk,rst_n,in_valid,
    input hft_fixed_pkg::q_t dx0,dx1,lag_x0,lag_x1,lag_dx0,lag_dx1,
    input hft_fixed_pkg::q_t pi00,pi01,pi10,pi11,g00,g01,g10,g11,c0,c1,
    output hft_fixed_pkg::q_t y0,y1,
    output logic out_valid
);
    import hft_fixed_pkg::*;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin y0<=0;y1<=0;out_valid<=0;end
        else if(in_valid) begin
            y0<=q_add(c0,q_add(q_add(q_mul(pi00,lag_x0),q_mul(pi01,lag_x1)),q_add(q_mul(g00,lag_dx0),q_mul(g01,lag_dx1))));
            y1<=q_add(c1,q_add(q_add(q_mul(pi10,lag_x0),q_mul(pi11,lag_x1)),q_add(q_mul(g10,lag_dx0),q_mul(g11,lag_dx1))));
            out_valid<=1;
        end else out_valid<=0;
    end
endmodule
