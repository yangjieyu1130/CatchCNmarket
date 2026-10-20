# cnmarket

<!-- badges: start -->
[![R-CMD-check](https://github.com/yangjieyu1130/CatchCNmarket/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/yangjieyu1130/CatchCNmarket/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

**A股制度感知行情工具箱**（A-Share Market Regime-Aware Market Data Toolkit）。

`cnmarket` 基于 [Tushare](https://tushare.pro) API 获取 A 股行情数据，并内建了通用行情包忽略的 **A 股交易制度规则**：分板块涨跌停、ST 涨跌停、涨跌停/停牌识别、T+1 可卖日、连板统计、前/后复权，全部带本地磁盘缓存。

## 与现有 R 包的区分度

| | quantmod / TTR | 现有 R 版 Tushare 封装 | **cnmarket** |
|---|---|---|---|
| 数据口径 | 美股 | A 股 | A 股 |
| 分板块涨跌停（主板10%/创业科创20%/北交所30%） | 无 | 无 | 内置 |
| ST 5% 涨跌停识别 | 无 | 无 | 自动（按名称识别） |
| 涨跌停价 / 涨停跌停标记 / 连板数 | 无 | 无 | 内置 |
| 停牌识别 | 无 | 无 | 内置 |
| T+1 可卖日 | 无 | 无 | 内置（联动交易日历） |
| qfq/hfq 复权 | 无 | 部分 | 内置（本地按 adj_factor 计算） |
| 本地缓存 / 离线复用 / 省积分 | 无 | 无 | 内置 |

## 安装

```r
# 需要 R >= 4.1
# install.packages("pak")
pak::pak("yangjieyu1130/CatchCNmarket")
```

## 快速开始

```r
library(cnmarket)

# 配置 token（或设置环境变量 TUSHARE_TOKEN）
cn_set_token("你的tushare_token")

# 拉行情（自动按年分片、缓存、可选复权）
bars <- cn_daily("300750.SZ", "20240101", "20240331", adjust = "qfq")

# 打制度标签：涨跌停价、是否涨跌停、停牌、连板数、T+1 可卖日
tagged <- cn_flag(bars)

# 单标的涨跌停规则速查
cn_limit_rule("688981.SH")              # 科创板 → 20%
cn_limit_rule("600519.SH", is_st = TRUE) # 主板 ST → 5%
```

`cn_flag()` 新增列：

- `board` / `limit_pct` — 板块与适用涨跌停幅度
- `limit_up` / `limit_down` — 由 `pre_close` 定价的涨跌停价
- `is_limit_up` / `is_limit_down` — 收盘是否触及涨/跌停
- `is_suspended` — 停牌（缺量或零成交）
- `up_streak` / `down_streak` — 连板数
- `sellable_date` — T+1 可卖日（自动跨周末/节假日）

## 主要函数

**数据层**：`cn_daily()`、`cn_stock_basic()`、`cn_trade_cal()`
**配置层**：`cn_set_token()`、`cn_set_cache_dir()`、`cn_use_cache()`、`cn_cache_clear()`
**制度层**：`cn_board()`、`cn_limit_pct()`、`cn_limit_rule()`、`cn_flag()`
**预测层**：`cn_arima()`

## 初级行情预测（非季节性 ARIMA）

```r
fc <- cn_arima("000001.SZ", n_ahead = 5)   # order = "auto" 按 AIC 网格搜索 (p,d,q ∈ 0..2)
fc
#>   h trade_date forecast lo80 hi80 lo95 hi95
#>   1 20261021      11.4 11.3 11.6 11.2 11.7
#>   ...（未来交易日自动跳过周末/节假日）
attr(fc, "order")                           # 自动选出的 (p, d, q)
```

- 输入灵活：直接给 `ts_code`（自动拉近一年日线）、给 `cn_daily()` 的数据框、或给数值向量
- 默认对**对数价格**建模再指数回变换，保证预测值非负、方差更稳
- 未来 `trade_date` 联动交易日历；离线时日期为 `NA`，`h` 列仍标记预测步数
- 可显式指定 `order = c(p, d, q)`，区间置信度用 `level` 调整
- 定位是**单变量统计基线**（无季节性、无外生变量、无机制切换），不构成投资建议

## 缓存

所有 API 响应以 RDS 缓存在本地（默认 `tools::R_user_dir("cnmarket", "cache")`），命中缓存不发请求，省积分、可离线；`cn_use_cache(FALSE)` 可关闭，`refresh = TRUE` 可强制刷新。

## License

MIT
