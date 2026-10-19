# cnmarket 0.1.0

* 首个公开发布版本。
* 数据层：`cn_daily()`（按年分片、qfq/hfq 复权）、`cn_stock_basic()`、`cn_trade_cal()`。
* 制度层：`cn_board()`、`cn_limit_pct()`、`cn_limit_rule()`、`cn_flag()`（涨跌停/停牌/连板/T+1 标签）。
* 配置层：token 与磁盘缓存管理（`cn_set_token()`、`cn_set_cache_dir()`、`cn_use_cache()`、`cn_cache_clear()`）。
