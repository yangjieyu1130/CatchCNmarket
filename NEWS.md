# cnmarket 0.3.0

* 新增选股层 `cn_screen()` / `cn_screen_live()`：制度感知的多因子选股器，
  **制度因子**（A 股独有）与**技术因子**（base-R 实现，零新增依赖）混合筛选，
  可选 ARIMA 预测二次过滤与 z-score 加权打分。
* 新增 `R/indicators.R`：`roll_ma`、`roll_sd`、`roll_atr`、`pct_chg`、
  `vol_ratio`、`close_vs_ma`、`limit_up_count`、`halt_count`、`t1_downside`
  等滚动指标，base-R + `stats`，NA 安全。
* 新增制度因子：`board`、`is_st`、`limit_pct`、`up_streak` / `down_streak`、
  `limit_up_count_10d`、`halt_count_10d`、`t1_downside`、`sellable_date`。
* 新增技术因子：`pct_chg_5d` / `pct_chg_20d`、`vol_ratio_5_20`、
  `atr_pct`、`close_vs_ma20`、`vol_20d`。
* `cn_screen_live()` 预设打板接力策略：创业板/科创板弹性板、2-4 连板、
  近 10 日无停牌、ARIMA 预测上行。
* 输入校验前置：`cn_screen()` 在任何网络请求之前就检查 `universe` 类型
  和 `filters` 命名，避免 token 缺失时才暴露错误。

# cnmarket 0.2.0

* 新增预测层 `cn_arima()`：非季节性 ARIMA(p,d,q) 初级行情预测，支持
  `order = "auto"` AIC 网格搜索、对数价格建模、80%/95% 预测区间，未来
  交易日联动交易日历（离线时以 NA 占位）。

# cnmarket 0.1.0

* 首个公开发布版本。
* 数据层：`cn_daily()`（按年分片、qfq/hfq 复权）、`cn_stock_basic()`、`cn_trade_cal()`。
* 制度层：`cn_board()`、`cn_limit_pct()`、`cn_limit_rule()`、`cn_flag()`（涨跌停/停牌/连板/T+1 标签）。
* 配置层：token 与磁盘缓存管理（`cn_set_token()`、`cn_set_cache_dir()`、`cn_use_cache()`、`cn_cache_clear()`）。
