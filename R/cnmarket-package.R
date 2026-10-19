#' cnmarket: A-Share Market Regime-Aware Market Data Toolkit
#'
#' `cnmarket` fetches A-share (Mainland China) market data from the Tushare API
#' and enriches it with the trading rules that generic market-data packages
#' ignore: board-specific daily price limits, ST price limits, limit-up and
#' limit-down detection, trading-halt (suspension) detection, the T+1 sellable
#' date, and qfq/hfq price adjustment -- all backed by an on-disk cache.
#'
#' The two layers are deliberately separated:
#'
#' * **data layer** -- `cn_daily()`, `cn_stock_basic()`, `cn_trade_cal()` fetch
#'   and cache raw Tushare data as tidy tibbles.
#' * **regime layer** -- `cn_board()`, `cn_limit_pct()`, `cn_limit_rule()` and
#'   `cn_flag()` turn that data into A-share-regime-aware features.
#'
#' @keywords internal
"_PACKAGE"
