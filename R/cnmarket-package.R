#' cnmarket: A-Share Regime-Aware Market Data
#'
#' `cnmarket` fetches A-share (Mainland China) market data from Tushare or the
#' public Tencent endpoint and enriches it with trading rules that generic
#' market-data packages
#' ignore: board-specific daily price limits, ST price limits, limit-up and
#' limit-down detection, trading-halt (suspension) detection, the T+1 sellable
#' date, and qfq/hfq price adjustment -- all backed by an on-disk cache.
#'
#' The two layers are deliberately separated:
#'
#' * **data layer** -- `cn_daily()` fetches and caches Tushare or Tencent bars;
#'   `cn_stock_basic()` and `cn_trade_cal()` provide Tushare metadata as tidy
#'   tibbles.
#' * **regime layer** -- `cn_board()`, `cn_limit_pct()`, `cn_limit_rule()` and
#'   `cn_flag()` turn that data into A-share-regime-aware features.
#'
#' @keywords internal
"_PACKAGE"
