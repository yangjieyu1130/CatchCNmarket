#' Fetch listed A-share basic profiles
#'
#' Wraps Tushare `stock_basic`. Results are cached on disk, so repeated calls
#' (e.g. the daily universe) hit the cache instead of the API.
#'
#' @param codes Optional character vector of `ts_code` values (e.g.
#'   `"600519.SH"`). `NULL` (default) returns the full listed universe.
#' @param refresh Force a fresh API call, bypassing the cache.
#' @return A tibble with columns `ts_code`, `symbol`, `name`, `area`, `industry`,
#'   `market`, `exchange`, `list_status`, `list_date`, `delist_date`, `is_hs`.
#'   `market` carries the board (主板/创业板/科创板/北交所) used by
#'   [cn_board()]; `name` keeps the current trading name (an `ST`/`*ST` prefix
#'   indicates a special-treatment stock).
#' @examples
#' \dontrun{
#' basic <- cn_stock_basic(c("600519.SH", "300750.SZ"))
#' }
#' @export
cn_stock_basic <- function(codes = NULL, refresh = FALSE) {
  key <- cn_key("stock_basic", if (is.null(codes)) "ALL" else sort(codes))
  cn_with_cache(key, {
    params <- list(list_status = "L")
    if (!is.null(codes)) params$ts_code <- paste(codes, collapse = ",")
    cn_api(
      "stock_basic", params,
      fields = paste(
        "ts_code", "symbol", "name", "area", "industry", "market",
        "exchange", "list_status", "list_date", "delist_date", "is_hs",
        sep = ","
      )
    )
  }, refresh = refresh)
}

#' Fetch the trading calendar
#'
#' Wraps Tushare `trade_cal`.
#'
#' @param start_date,end_date Date range (`YYYYMMDD`, `YYYY-MM-DD` or `Date`).
#' @param exchange Exchange code, `"SSE"` (Shanghai) by default.
#' @param refresh Force a fresh API call, bypassing the cache.
#' @return A tibble with columns `exchange`, `cal_date`, `is_open` (1 open /
#'   0 closed) and `pretrade_date`.
#' @examples
#' \dontrun{
#' cn_trade_cal("20240101", "20240131")
#' }
#' @export
cn_trade_cal <- function(start_date, end_date, exchange = "SSE", refresh = FALSE) {
  start_date <- cn_ymd(start_date)
  end_date <- cn_ymd(end_date)
  key <- cn_key("trade_cal", exchange, start_date, end_date)
  cn_with_cache(key, {
    cn_api(
      "trade_cal",
      list(exchange = exchange, start_date = start_date, end_date = end_date),
      fields = "exchange,cal_date,is_open,pretrade_date"
    )
  }, refresh = refresh)
}

# Open trading dates (character YYYYMMDD) in a range.
cn_open_dates <- function(start_date, end_date, exchange = "SSE", refresh = FALSE) {
  cal <- cn_trade_cal(start_date, end_date, exchange, refresh = refresh)
  sort(cal$cal_date[cal$is_open == 1])
}

# For each date, the next open trading date (the T+1 sellable date).
cn_next_trade_date <- function(trade_date, cal = NULL, refresh = FALSE) {
  td <- as.character(trade_date)
  if (length(td) == 0L) return(character(0))
  if (is.null(cal)) {
    hi <- as.Date(max(td), "%Y%m%d") + 15
    cal <- cn_trade_cal(
      format(min(as.Date(td, "%Y%m%d")) + 1, "%Y%m%d"),
      format(hi, "%Y%m%d"),
      refresh = refresh
    )
  }
  open <- sort(cal$cal_date[cal$is_open == 1])
  vapply(td, function(d) {
    nxt <- open[open > d]
    if (length(nxt)) nxt[1] else NA_character_
  }, character(1), USE.NAMES = FALSE)
}
