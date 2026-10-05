# FPGA HFT Trading System

```text
10GbE → PHY/PCS → MAC → IPv4 → UDP/TCP → MoldUDP64 / SoupBinTCP → NASDAQ ITCH → Order Book → Quantitative RTL → Risk → OUCH → 10GbE
```

A modular FPGA-based High-Frequency Trading research platform implementing the complete **market-data-to-order datapath** in deterministic hardware. The architecture combines low-latency Ethernet processing, exchange-protocol decoding, hardware order-book reconstruction, market-microstructure analytics, quantitative trading models, FPGA-native arithmetic, deterministic risk controls, and order-entry processing.

## Architecture at a Glance

```text
                    NASDAQ / MARKET VENUE
                            │
                            ▼
                    ┌───────────────┐
                    │   10GbE PHY   │
                    │   10GBASE-R   │
                    │   64B/66B PCS │
                    └───────┬───────┘
                            ▼
                    ┌───────────────┐
                    │  Ethernet MAC │
                    │    XGMII      │
                    └───────┬───────┘
                            ▼
                    ┌───────────────┐
                    │ IPv4 / UDP /  │
                    │      TCP      │
                    └───────┬───────┘
                            ▼
                 ┌──────────────────────┐
                 │ CORE 2: PROTOCOL     │
                 │ MoldUDP64 / ITCH     │
                 │ SoupBinTCP / OUCH    │
                 │ GLIMPSE / Recovery   │
                 └──────────┬───────────┘
                            ▼
                 ┌──────────────────────┐
                 │ CORE 3: MARKET STATE │
                 │ L3 / L2 Order Book   │
                 │ BBO / Queue / Depth  │
                 └──────────┬───────────┘
                            ▼
                 ┌──────────────────────┐
                 │ CORE 4: QUANT RTL    │
                 │ Microstructure       │
                 │ Stat-Arb / MM        │
                 │ Hawkes / Volatility  │
                 │ ML / Arbitrage       │
                 └──────────┬───────────┘
                            ▼
                       SIGNAL FUSION
                            ▼
                       RISK ENGINE
                            ▼
                          OUCH
                            ▼
                    SoupBinTCP / TCP
                            ▼
                       IPv4 / MAC
                            ▼
                          10GbE
```

---

# 1. Four Core Hardware Units

| Core       | Hardware Unit                    | Main Responsibility                                                                   |
| ---------- | -------------------------------- | ------------------------------------------------------------------------------------- |
| **Core 1** | **10GbE Network Fabric**         | PHY, PCS, 64B/66B, XGMII, MAC, IPv4, UDP, TCP, CRC/checksums                          |
| **Core 2** | **Exchange Protocol Fabric**     | MoldUDP64, sequence/gap handling, ITCH 5.0, SoupBinTCP, GLIMPSE, OUCH                 |
| **Core 3** | **Market-State Fabric**          | L3 order storage, price-level aggregation, L2 depth, BBO, queue state, symbol routing |
| **Core 4** | **Quantitative Decision Fabric** | OBI/OFI, microprice, volatility, Hawkes, stat-arb, A-S, GLFT, ML, execution, risk     |

This separation keeps the **wire/protocol path independent from the trading model path**.

---

# 2. Core 1 — 10GbE Network Fabric

## Pipeline

```text
10GbE SFP+
    │
    ▼
GT / SerDes
    │
    ▼
10GBASE-R PCS
    │
    ├── 64B/66B decode
    ├── block synchronization
    ├── scrambler / descrambler
    └── gearbox
    │
    ▼
XGMII
    │
    ▼
Ethernet MAC
    │
    ├── destination/source MAC
    ├── VLAN
    ├── frame boundary
    └── CRC/FCS
    │
    ▼
IPv4
    │
    ├── header validation
    ├── protocol demux
    └── checksum
    │
    ├───────────────┐
    ▼               ▼
   UDP              TCP
```

| Block     | Technology          | Optimization                       |
| --------- | ------------------- | ---------------------------------- |
| PHY       | 10GBASE-R           | Direct/high-speed SerDes interface |
| PCS       | 64B/66B             | Parallel block processing          |
| Scrambler | $x^{58}+x^{39}+1$   | Combinational XOR network          |
| XGMII     | 64-bit stream       | Wire-speed word processing         |
| MAC       | Ethernet            | Cut-through frame processing       |
| IPv4      | L3                  | Early header extraction            |
| UDP       | Datagram            | Low-overhead market-data ingress   |
| TCP       | Reliable transport  | Stateful order/session path        |
| CRC       | CRC32               | Streaming CRC datapath             |

### Design philosophy

The network path uses **streaming and cut-through processing** wherever possible. Fixed header fields are extracted as soon as available instead of buffering complete packets before processing.

---

# 3. Core 2 — Exchange Protocol Fabric

## Market-Data Path

```text
UDP
 ↓
MoldUDP64
 ↓
Sequence Guard
 ↓
Gap Detector
 ↓
ITCH 5.0 Parser
 ↓
Symbol Filter
 ↓
Canonical Market Event
```

## Session / Order Path

```text
TCP
 ↓
SoupBinTCP
 ├── Login
 ├── Heartbeat
 ├── Sequenced Data
 └── Session State
       │
       ├── GLIMPSE snapshot
       │
       └── OUCH order entry
```

## Protocol Table

| Protocol       | Transport         | Purpose                               |
| -------------- | ----------------- | ------------------------------------- |
| **MoldUDP64**  | UDP               | Sequenced high-throughput market data |
| **ITCH 5.0**   | MoldUDP64 payload | NASDAQ order-book market events       |
| **SoupBinTCP** | TCP               | Session/sequenced transport           |
| **GLIMPSE**    | SoupBinTCP/TCP    | Snapshot / recovery                   |
| **OUCH**       | SoupBinTCP/TCP    | Native order entry                    |

NASDAQ's TotalView-ITCH feed and OUCH are designed for high-throughput market-data dissemination and low-latency order entry respectively. Exact protocol fields and version-specific behavior should always be validated against the official exchange specification. ([NASDAQ Trader][1])

## ITCH Message Handling

| Message                  | Hardware Action                           |
| ------------------------ | ----------------------------------------- |
| `A` — Add Order          | Allocate order state + update price level |
| `E` — Execute            | Reduce order quantity                     |
| `C` — Execute With Price | Reduce quantity + execution information   |
| `X` — Cancel             | Reduce displayed quantity                 |
| `D` — Delete             | Remove complete order                     |
| `U` — Replace            | Delete old state + create replacement     |
| `P` — Trade              | Trade/event processing                    |
| `R` — Directory          | Symbol/reference state                    |
| `S` — System             | Feed/system state                         |

### Parser architecture

```text
64/128-bit packet window
        │
        ▼
message-type detection
        │
        ▼
parallel field extraction
        │
        ▼
message-specific decoder
        │
        ▼
canonical_market_event
```

The architecture avoids carrying exchange-specific byte offsets into the strategy engine.

---

# 4. Core 3 — Market-State / Order Book Fabric

The order book converts the event stream into deterministic market state.

```text
                ITCH EVENT
                    │
                    ▼
             Symbol Router
                    │
           ┌────────┴────────┐
           ▼                 ▼
      Order-ID Store    Price-Level Store
     BRAM / CAM / Hash     BRAM / URAM
           │                 │
           └────────┬────────┘
                    ▼
               L3 ORDER BOOK
                    │
          ┌─────────┼─────────┐
          ▼         ▼         ▼
         BBO        L2      QUEUE
          │         │         │
          └─────────┼─────────┘
                    ▼
              MARKET STATE
```

## Memory architecture

| Structure           | Typical FPGA Resource | Function                        |
| ------------------- | --------------------- | ------------------------------- |
| Order-ID table      | BRAM / CAM / hash     | Fast order-reference lookup     |
| Order records       | BRAM                  | Price, side, quantity, validity |
| Price-level book    | BRAM / URAM           | Aggregated depth                |
| Active-level bitmap | LUTRAM / BRAM         | Fast active-level detection     |
| BBO state           | Registers             | Best bid/ask                    |
| Queue state         | Registers / BRAM      | Queue-ahead tracking            |
| CDC FIFO            | BRAM                  | Clock-domain crossing           |

### Order lifecycle

```text
ADD
 │
 ├── order lookup/allocation
 ├── order-store write
 ├── price-level increment
 └── BBO evaluation

EXECUTE / CANCEL
 │
 ├── order lookup
 ├── quantity reduction
 ├── price-level reduction
 └── level depletion check

DELETE
 │
 ├── order lookup
 ├── remove remaining quantity
 └── invalidate entry

REPLACE
 │
 ├── locate old order
 ├── remove old level contribution
 ├── invalidate old reference
 └── add replacement order
```

### BBO

```text
best_bid = highest active bid
best_ask = lowest active ask

spread = best_ask - best_bid

mid = (best_bid + best_ask) / 2
```

For deeper books, hierarchical priority encoders and price-level bitmaps can replace linear scanning.

---

# 5. Core 4 — Quantitative Decision Fabric

The quantitative engine consumes normalized market state rather than raw Ethernet packets.

```text
                   MARKET STATE
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
         BBO          QUEUE        TRADES
          │             │             │
          └─────────────┼─────────────┘
                        ▼
               MICROSTRUCTURE
                        │
             ┌──────────┼──────────┐
             ▼          ▼          ▼
            OBI        OFI      MICROPRICE
             │          │          │
             └──────────┼──────────┘
                        ▼
                    VOLATILITY
                        │
          ┌─────────────┼─────────────┐
          ▼             ▼             ▼
        EWMA            RV          GARCH
          │             │             │
          └─────────────┼─────────────┘
                        ▼
                   MODEL SELECT
                        │
       ┌────────────────┼─────────────────┐
       ▼                ▼                 ▼
  MARKET MAKING    STAT-ARBITRAGE      ARBITRAGE
       │                │                 │
      A-S           OU / Kalman       Cross-Venue
      GLFT          Cointegration        Basis
       │                │              Triangular
       └────────────────┼─────────────────┘
                        ▼
                      ML / RL
                        │
                        ▼
                   SIGNAL FUSION
                        │
                        ▼
                       RISK
                        │
                        ▼
                       OUCH
```

---

# 6. Market-Microstructure Models

| Model                 | Mathematical Definition                 | FPGA Role              |
| --------------------- | --------------------------------------- | ---------------------- |
| **OBI**               | $(Q_b-Q_a)/(Q_b+Q_a)$                   | Liquidity imbalance    |
| **Multi-Level OBI**   | Weighted depth imbalance                | Deeper-book signal     |
| **OFI**               | Incremental bid/ask queue changes       | Order-flow pressure    |
| **Integrated OFI**    | Windowed OFI                            | Short-horizon signal   |
| **Microprice**        | $(P_aQ_b+P_bQ_a)/(Q_b+Q_a)$             | Queue-aware fair value |
| **Signed Flow**       | $\epsilon_tV_t$                         | Aggressor pressure     |
| **VPIN/BVC**          | Volume-bucket imbalance                 | Flow toxicity          |
| **Kyle $\lambda$**    | $\Delta P=\lambda q+\epsilon$           | Price-impact estimate  |
| **Adverse Selection** | Post-fill price movement                | Passive-order quality  |
| **Queue Position**    | Quantity ahead                          | Fill probability       |

---

# 7. Stochastic Order-Flow Models

| Model               | Core Mathematics                              | RTL Implementation          |
| ------------------- | --------------------------------------------- | --------------------------- |
| Poisson             | $N_T\sim Poisson(\lambda T)$                  | Intensity/state accumulator |
| Exponential arrival | $P(\tau>t)=e^{-\lambda t}$                    | EXP core                    |
| Hawkes              | $\lambda_i=\mu_i+\sum_j\int\phi_{ij}dN_j$     | Stateful excitation         |
| Exponential Hawkes  | $\phi_{ij}(t)=\alpha_{ij}e^{-\beta_{ij}t}$    | Decay + excitation          |
| Hawkes 2D           | Buy/sell coupling                             | 2-state parallel engine     |
| Hawkes 4D           | MO/LO event coupling                          | 4-state excitation matrix   |
| Queue-Reactive      | State-dependent intensity                     | Calibrated ROM              |

---

# 8. Volatility / Time-Series Models

| Model               | Equation / Function                                             |
| ------------------- | --------------------------------------------------------------- |
| Realized Variance   | $RV=\sum r_i^2$                                                 |
| Realized Volatility | $\sigma=\sqrt{RV}$                                              |
| EWMA                | $\sigma_t^2=\lambda\sigma_{t-1}^2+(1-\lambda)r_{t-1}^2$         |
| Bipower Variation   | $\frac{\pi}{2}\sum \lvert r_i\rvert\,\lvert r_{i-1}\rvert$      |
| GARCH(1,1)          | $\sigma_t^2=\omega+\alpha r_{t-1}^2+\beta\sigma_{t-1}^2$        |
| AR(p)               | $c+\sum\phi_iX_{t-i}$                                           |
| MA(q)               | Weighted error history                                          |
| ARIMA               | Differencing + AR/MA                                            |
| VAR                 | Vector autoregression                                           |
| CUSUM               | Online regime/change detection                                  |

---

# 9. Statistical-Arbitrage Models

```text
Price A ─────┐
             ├──► OLS / Kalman ─► Hedge Ratio
Price B ─────┘                         │
                                       ▼
                                    Spread
                                       │
                ┌──────────────────────┼─────────────────────┐
                ▼                      ▼                     ▼
             ADF / EG                 OU                  Johansen
                │                      │                     │
                └──────────────────────┼─────────────────────┘
                                       ▼
                                    Z-Score
                                       │
                                       ▼
                                  Trade Signal
```

| Model              | Purpose                            |
| ------------------ | ---------------------------------- |
| Rolling statistics | Mean / variance                    |
| Z-score            | Mean-reversion distance            |
| OLS                | Hedge ratio                        |
| Engle-Granger      | Residual cointegration             |
| ADF                | Stationarity test                  |
| Johansen           | Multivariate cointegration         |
| VECM               | Error-correction dynamics          |
| OU                 | Mean-reverting spread              |
| OU MLE             | $\kappa,\mu,\sigma$ estimation     |
| Half-life          | $\ln 2/\kappa$                     |
| Kalman             | Dynamic hedge ratio                |
| Lead-Lag           | Cross-asset predictive relation    |

---

# 10. Market-Making Models

## Avellaneda-Stoikov

```text
mid + inventory + volatility + horizon
                  │
                  ▼
          reservation price
                  │
                  ▼
            optimal spread
             /         \
            ▼           ▼
          BID           ASK
```

Core equations:

```text
r = S - q * gamma * sigma^2 * tau

delta = gamma * sigma^2 * tau
      + (2 / gamma) * ln(1 + gamma / kappa)

bid = r - delta / 2
ask = r + delta / 2
```

| Model              | Purpose                          |
| ------------------ | -------------------------------- |
| Fixed spread       | Baseline                         |
| Weighted-mid       | Fair-value quoting               |
| Inventory skew     | Inventory control                |
| Avellaneda-Stoikov | Stochastic-control market making |
| GLFT               | Alternative closed-form MM       |
| Alpha-adjusted MM  | Incorporate predictive signal    |
| Toxicity-aware MM  | VPIN/flow-dependent widening     |
| Queue-aware MM     | Fill-quality-aware quoting       |

---

# 11. Execution / Routing

| Model          | Function                      |
| -------------- | ----------------------------- |
| TWAP           | Uniform time execution        |
| VWAP           | Volume-profile execution      |
| POV            | Participation-based execution |
| Almgren-Chriss | Impact/risk optimal execution |
| SOR            | Venue cost optimization       |

Representative SOR cost:

```text
expected_cost = price
              + fee
              - rebate
              + slippage
              + latency_penalty
```

---

# 12. Arbitrage

| Model             | Decision                                        |
| ----------------- | ----------------------------------------------- |
| Cross-Exchange    | $Bid_B-Ask_A-cost>0$                            |
| Latency Arbitrage | Trade stale quote before information propagates |
| Basis             | Futures − spot/basket − fair basis              |
| Triangular        | $R_{AB}R_{BC}R_{CA}>1$ after costs             |
| Lead-Lag          | Predict delayed venue/asset response            |

Cross-venue execution must include **leg risk**, because the first hedge leg can fill while the second does not.

---

# 13. ML / RL

| Model               | FPGA Mapping                    |
| ------------------- | ------------------------------- |
| Linear Regression   | Parallel MAC                    |
| Logistic Regression | MAC + sigmoid                   |
| MLP                 | DSP MAC array                   |
| CNN                 | Sliding-window MAC              |
| LSTM                | Recurrent MAC + nonlinear gates |
| Attention           | GEMM + normalization            |
| Decision Tree       | Comparator/mux network          |
| Q-Learning          | TD update                       |
| PPO                 | Policy/objective computation    |

Typical HFT feature vector:

```text
OBI
OFI
microprice - mid
spread
signed flow
trade intensity
volatility
depth
return
queue state
```

---

# 14. Shared Financial-Math Accelerator

All models share common fixed-point primitives.

```text
                 FINANCIAL MATH FABRIC
                          │
      ┌───────────────────┼────────────────────┐
      ▼                   ▼                    ▼
 Reciprocal              Sqrt                 Log
      │                   │                    │
      ▼                   ▼                    ▼
 Newton-Raphson      Newton-Raphson     LUT / Polynomial
      │                   │                    │
      └───────────────────┼────────────────────┘
                          ▼
                         Exp
                          │
                          ▼
                         CDF
                          │
                          ▼
                    MAC / Matrix
```

Default representation:

```text
Signed Q16.16
```

Mathematical primitives are candidates for:

```text
LUT
Piecewise polynomial
Newton-Raphson
Range-reduced approximation
Iterative / CORDIC-style implementation
```

The purpose is to measure:

```text
Numerical error
        ↔
Latency
        ↔
Fmax
        ↔
LUT / FF / DSP / BRAM
        ↔
Trading-decision accuracy
```

---

# 15. Deterministic Risk Fabric

Every order passes hardware risk before entering the order-entry path.

| Risk Check    | Example                           |
| ------------- | --------------------------------- |
| Position      | $\lvert q\rvert \le q_{max}$      |
| Quantity      | $Q\le Q_{max}$                    |
| Notional      | $\lvert QP\rvert \le N_{max}$     |
| Price Band    | $\lvert P-P_{ref}\rvert \le B$    |
| Order Rate    | $R\le R_{max}$                    |
| Drawdown      | $DD\le DD_{max}$                  |
| Credit        | Available trading credit          |
| Kill Switch   | Immediate order suppression       |
| Session State | Exchange session valid            |

```text
Position ──┐
Quantity ──┤
Notional ──┤
Price ─────┤
Rate ──────┼──► AND ─► ORDER APPROVED
Credit ────┤
Session ───┤
Kill ──────┘
```

The risk layer is intentionally deterministic and independent of the alpha model.

---

# 16. Hardware Optimization

The project focuses on FPGA-specific optimization techniques rather than direct software translation.

### Cut-through processing

```text
packet field available
        ↓
process immediately
```

### Deep pipelining

Every stage is registered so that one new input can be accepted per clock cycle.

### BRAM / URAM-aware design

Memory operations explicitly account for registered read latency and read-modify-write hazards.

### FPGA DSP utilization

Financial MACs, regressions, neural layers and polynomial approximations can map to DSP slices.

### Fixed-point optimization

Use the minimum precision that preserves:

```text
price tick
strategy threshold
risk threshold
decision accuracy
```

---

# 17. Recommended Repository Layout

```text
FPGA-HFT-Trading-System/
│
├── rtl/
│   ├── ether/
│   │   ├── phy/
│   │   ├── mac/
│   │   ├── ip4/
│   │   ├── udp/
│   │   └── tcp/
│   │
│   ├── protocols/
│   │   ├── moldudp64/
│   │   ├── soupbintcp/
│   │   ├── itch/
│   │   ├── glimpse/
│   │   └── ouch/
│   │
│   ├── Orderbook/
│   │   ├── order_storage/
│   │   ├── price_levels/
│   │   ├── bbo/
│   │   ├── queue/
│   │   └── multi_symbol/
│   │
│   ├── Algorithms_RTL/
│   │   └── strategy modules
│   │
│   └── Quant_RTL/
│       ├── math/
│       ├── microstructure/
│       ├── flow/
│       ├── volatility/
│       ├── time_series/
│       ├── stat_arb/
│       ├── market_making/
│       ├── execution/
│       ├── arbitrage/
│       ├── options/
│       ├── ml/
│       ├── rl/
│       └── risk/
│
├── tb/
├── reference/
│   ├── cpp/
│   └── python/
├── data/
│   ├── pcap/
│   └── itch/
├── docs/
├── scripts/
├── constraints/
├── synthesis/
├── rtl_sources.f
├── LICENSE
├── NOTICE.md
└── README.md
```

[1]: https://www.nasdaqtrader.com/
