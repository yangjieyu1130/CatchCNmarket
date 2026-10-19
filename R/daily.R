# Fetch raw daily bars for one code, chunked by calendar year.
cn_daily_raw <- function(ts_code, start_date, end_date, refresh = FALSE) {
  years <- seq.int(
    as.integer(substr(start_date, 1, 4)),
    as.integer(substr(end_date, 1, 4))
  )
  chunks <- lapply(years, function(y) {
    cs <- max(start_date, sprintf("%04d0101", y))
    ce <- min(end_date, sprintf("%04d1231", y))
    if (cs > ce) return(NULL)
    cn_with_cache(
      cn_key("daily", ts_code, cs, ce),
      cn_api(
        "daily",
        list(ts_code = ts_code, start_date = cs, end_date = ce),
        fields = "ts_code,trade_date,open,high,low,close,pre_close,change,pct_chg,vol,amount"
      ),
      refresh = refresh
    )
  })
  chunks <- Filter(function(x) !is.null(x) && nrow(x) > 0L, chunks)
  if (length(chunks) == 0L) return(NULL)
  out <- do.call(rbind, chunks)
  out[order(out$trade_date), , drop = FALSE]
}

# Fetch unadjusted adjustment factors for one code, chunked by calendar year.
cn_adj_factor <- function(ts_code, start_date, end_date, refresh = FALSE) {
  years <- seq.int(
    as.integer(substr(start_date, 1, 4)),
    as.integer(substr(end_date, 1, 4))
  )
  chunks <- lapply(years, function(y) {
    cs <- max(start_date, sprintf("%04d0101", y))
    ce <- min(end_date, sprintf("%04d1231", y))
    if (cs > ce) return(NULL)
    cn_with_cache(
      cn_key("adj_factor", ts_code, cs, ce),
      cn_api(
        "adj_factor",
        list(ts_code = ts_code, start_date = cs, end_date = ce),
        fields = "ts_code,trade_date,adj_factor"
      ),
      refresh = refresh
    )
  })
  chunks <- Filter(function(x) !is.null(x) && nrow(x) > 0L, chunks)
  if (length(chunks) == 0L) return(NULL)
  out <- do.call(rbind, chunks)
  out[order(out$trade_date), , drop = FALSE]
}

#' Fetch daily bars with optional price adjustment
#'
#' Wraps Tushare `daily` (and `adj_factor` when `adjust != "none"`). Data are
#' chunked by calendar year, de-duplicated, sorted, and cached. Forward/backward
#' adjustment is computed locally from adjustment factors:
#' `qfq = price * factor / factor_latest`, `hfq = price * factor / factor_first`.
#'
#' Note that `pre_close` and the raw columns are the *unadjusted* values Tushare
#' returns -- the A-share price-limit base -- so [cn_flag()] can be applied to the
#' raw bars regardless of `adjust`.
#'
#' @param ts_code A single `ts_code`, e.g. `"600519.SH"`.
#' @param start_date,end_date Date range (`YYYYMMDD`, `YYYY-MM-DD` or `Date`).
#'   Defaults to the trailing 365 days ending today.
#' @param adjust One of `"none"` (raw), `"qfq"` (forward) or `"hfq"` (backward).
#' @param refresh Force a fresh API call, bypassing the cache.
#' @return A tibble with `ts_code`, `trade_date`, `open`, `high`, `low`, `close`,
#'   `pre_close`, `change`, `pct_chg`, `vol`, `amount`. The `adjust` mode is
#'   stored in the `"adjust"` attribute.
#' @examples
#' \dontrun{
#' cn_daily("600519.SH", "20240101", "20240331", adjust = "qfq")
#' }
#' @export
cn_daily <- function(ts_code, start_date = NULL, end_date = NULL,
                     adjust = c("none", "qfq", "hfq"), refresh = FALSE) {
  adjust <- match.arg(adjust)
  if (!is.character(ts_code) || length(ts_code) != 1L) {
    stop("ts_code 必须是单个证券代码字符串。", call. = FALSE)
  }
  end_date <- cn_ymd(if (is.null(end_date)) Sys.Date() else end_date)
  if (is.null(start_date)) {
    start_date <- format(as.Date(end_date, "%Y%m%d") - 365, "%Y%m%d")
  } else {
    start_date <- cn_ymd(start_date)
  }
  if (start_date > end_date) stop("start_date 必须不晚于 end_date。", call. = FALSE)

  bars <- cn_daily_raw(ts_code, start_date, end_date, refresh = refresh)
  if (is.null(bars)) {
    stop(sprintf("未取到 %s 在 %s ~ %s 的行情数据。", ts_code, start_date, end_date),
         call. = FALSE)
  }
  bars <- bars[!duplicated(bars$trade_date), , drop = FALSE]

  if (adjust == "none") {
    attr(bars, "adjust") <- "none"
    return(tibble::as_tibble(bars))
  }

  adj <- cn_adj_factor(ts_code, start_date, end_date, refresh = refresh)
  if (is.null(adj)) {
    warning("未取到 adj_factor，返回未复权数据。", call. = FALSE)
    attr(bars, "adjust") <- "none"
    return(tibble::as_tibble(bars))
  }
  adj <- adj[!duplicated(adj$trade_date), , drop = FALSE]
  merged <- merge(
    bars[, c("ts_code", "trade_date", "open", "high", "low", "close", "pre_close")],
    adj[, c("trade_date", "adj_factor")],
    by = "trade_date", all.x = TRUE
  )
  base_cols <- c("open", "high", "low", "close", "pre_close")
  f <- merged$adj_factor
  ref <- if (adjust == "qfq") f[length(f)] else f[1]
  merged[base_cols] <- lapply(merged[base_cols], function(col) col * f / ref)

  # Re-attach the non-adjusted columns of the raw bars.
  extra <- bars[, c("trade_date", "change", "pct_chg", "vol", "amount")]
  out <- merge(merged, extra, by = "trade_date", all.x = TRUE)
  out <- out[order(out$trade_date), , drop = FALSE]
  out <- out[, c("ts_code", "trade_date", base_cols,
                 "change", "pct_chg", "vol", "amount")]
  attr(out, "adjust") <- adjust
  tibble::as_tibble(out)
}
