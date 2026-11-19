#' Identify the A-share board of a security
#'
#' Boards differ in their daily price-limit rules, so the board must be known
#' before limits can be derived.
#'
#' @param ts_code A `ts_code` such as `"600519.SH"`.
#' @param market Optional board label from `stock_basic` (the Chinese label
#'   of the Main Board, ChiNext, STAR Market or BSE, exactly as returned by
#'   this function). When supplied it is trusted; otherwise the board is
#'   inferred from the numeric code prefix.
#' @return The Chinese board label of the Main Board, ChiNext, STAR Market
#'   or BSE (e.g. `cn_board("600519.SH")` returns the Main Board label).
#' @examples
#' cn_board("600519.SH")   # Main Board
#' cn_board("688981.SH")   # STAR Market
#' cn_board("300750.SZ")   # ChiNext
#' @export
cn_board <- function(ts_code, market = NULL) {
  if (!is.null(market) && length(market) > 0L) {
    m <- as.character(market)[1]
    if (m %in% c("\u4e3b\u677f", "\u521b\u4e1a\u677f", "\u79d1\u521b\u677f", "\u5317\u4ea4\u6240")) return(m)
  }
  code <- sub("\\..*$", "", as.character(ts_code)[1])
  if (grepl("^(688|689)", code)) return("\u79d1\u521b\u677f")
  if (grepl("^(300|301)", code)) return("\u521b\u4e1a\u677f")
  if (grepl("^(43|83|87|88|920)", code)) return("\u5317\u4ea4\u6240")
  "\u4e3b\u677f"
}

#' Daily price-limit percentage for a security
#'
#' Implements the current A-share regime: Main Board 10 percent, STAR Market and
#' ChiNext 20 percent, Beijing Stock Exchange 30 percent, and 5 percent for
#' Main Board stocks under special treatment (ST / *ST). Stocks within their
#' first five trading days of listing (registration-based IPO) are exempt and
#' return `NA_real_` (no limit).
#'
#' @param board Board label from [cn_board()]; `NULL` (default) means the
#'   Main Board.
#' @param is_st Logical; `TRUE` for ST / *ST stocks (only affects the Main Board).
#' @param days_since_list Trading days since listing. Values `<= 5` mean the
#'   security is still in its unlimited first-5-day window.
#' @return A numeric fraction (e.g. `0.10`) or `NA_real_` when unlimited.
#' @examples
#' cn_limit_pct(cn_board("600519.SH"))                 # 0.10
#' cn_limit_pct(cn_board("600519.SH"), is_st = TRUE)   # 0.05
#' cn_limit_pct(cn_board("300750.SZ"))                 # 0.20
#' @export
cn_limit_pct <- function(board = NULL, is_st = FALSE, days_since_list = Inf) {
  if (is.null(board)) board <- "\u4e3b\u677f"
  if (is.finite(days_since_list) && days_since_list <= 5) return(NA_real_)
  switch(
    board,
    "\u5317\u4ea4\u6240" = 0.30,
    "\u79d1\u521b\u677f" = 0.20,
    "\u521b\u4e1a\u677f" = 0.20,
    "\u4e3b\u677f" = if (isTRUE(is_st)) 0.05 else 0.10,
    0.10
  )
}

#' Price-limit rule for one security
#'
#' Convenience wrapper combining [cn_board()] and [cn_limit_pct()].
#'
#' @param ts_code A `ts_code`.
#' @param market Optional board label (see [cn_board()]).
#' @param is_st,days_since_list See [cn_limit_pct()].
#' @return A one-row tibble with `ts_code`, `board`, `is_st`, `limit_pct`.
#' @examples
#' cn_limit_rule("688981.SH")
#' @export
cn_limit_rule <- function(ts_code, market = NULL, is_st = FALSE,
                          days_since_list = Inf) {
  board <- cn_board(ts_code, market)
  tibble::tibble(
    ts_code = ts_code,
    board = board,
    is_st = is_st,
    limit_pct = cn_limit_pct(board, is_st, days_since_list)
  )
}

#' Tag daily bars with A-share regime features
#'
#' Turns raw daily bars into A-share-regime-aware features that generic
#' market-data packages do not provide:
#'
#' * `board` / `limit_pct` -- board and the applicable daily limit fraction.
#' * `limit_up` / `limit_down` -- limit prices from `pre_close` (rounded to
#'   0.01), i.e. `pre_close * (1 +/- limit_pct)`.
#' * `is_limit_up` / `is_limit_down` -- whether the close reached the limit.
#' * `is_suspended` -- trading halt (missing or zero volume).
#' * `up_streak` / `down_streak` -- consecutive limit-up / limit-down counts.
#' * `sellable_date` -- the T+1 date on which a position bought that day can be
#'   sold (the next open trading date).
#'
#' `is_st` defaults to `NULL`, in which case it is auto-detected from the
#' security's current name in [cn_stock_basic()] (a name containing `"ST"`).
#'
#' @param df A tibble from [cn_daily()] (or compatible), containing `trade_date`,
#'   `pre_close`, `close`, `high`, `low` and `vol`.
#' @param ts_code The `ts_code` the bars belong to. Inferred from `df$ts_code`
#'   when omitted.
#' @param market Optional board label (see [cn_board()]).
#' @param is_st `TRUE`/`FALSE`, or `NULL` to auto-detect from `stock_basic`.
#' @param days_since_list Trading days since listing (see [cn_limit_pct()]).
#' @param cal Optional trading calendar from [cn_trade_cal()] used for
#'   `sellable_date`; fetched and cached when omitted.
#' @param refresh Force fresh API calls for any lookup.
#' @return `df` with the regime columns appended.
#' @examples
#' bars <- data.frame(
#'   ts_code = "600519.SH",
#'   trade_date = c("20240102", "20240103"),
#'   pre_close = c(10, 11), close = c(11, 11),
#'   high = c(11, 11.2), low = c(10, 10.8), vol = c(1000, 1200)
#' )
#' cal <- data.frame(
#'   cal_date = c("20240102", "20240103", "20240104"),
#'   is_open = c(1, 1, 1)
#' )
#' cn_flag(bars, is_st = FALSE, cal = cal)
#' @export
cn_flag <- function(df, ts_code = NULL, market = NULL, is_st = NULL,
                    days_since_list = Inf, cal = NULL, refresh = FALSE) {
  needed <- c("trade_date", "pre_close", "close", "high", "low", "vol")
  missing <- setdiff(needed, names(df))
  if (length(missing)) {
    stop("\u8f93\u5165\u6570\u636e\u7f3a\u5c11\u5217\uff1a", paste(missing, collapse = ", "), call. = FALSE)
  }
  if (is.null(ts_code) && "ts_code" %in% names(df)) {
    ts_code <- unique(df$ts_code)[1]
  }
  if (is.null(ts_code)) {
    stop("\u8bf7\u63d0\u4f9b ts_code\uff08\u8f93\u5165\u6570\u636e\u4e2d\u4e0d\u542b ts_code \u5217\uff09\u3002", call. = FALSE)
  }

  board <- cn_board(ts_code, market)
  if (is.null(is_st)) {
    is_st <- FALSE
    basic <- tryCatch(cn_stock_basic(ts_code, refresh = refresh),
                      error = function(e) NULL)
    if (!is.null(basic) && nrow(basic) > 0L) {
      is_st <- grepl("ST", basic$name[1], ignore.case = TRUE)
    }
  }
  pct <- cn_limit_pct(board, is_st, days_since_list)

  df <- as.data.frame(df, stringsAsFactors = FALSE)
  df$board <- board
  df$limit_pct <- pct
  if (is.na(pct)) {
    df$limit_up <- NA_real_
    df$limit_down <- NA_real_
    df$is_limit_up <- FALSE
    df$is_limit_down <- FALSE
  } else {
    df$limit_up <- round(df$pre_close * (1 + pct), 2)
    df$limit_down <- round(df$pre_close * (1 - pct), 2)
    df$is_limit_up <- !is.na(df$close) & df$close >= df$limit_up - 1e-9
    df$is_limit_down <- !is.na(df$close) & df$close <= df$limit_down + 1e-9
  }

  df$is_suspended <- is.na(df$vol) | df$vol == 0
  df <- df[order(df$trade_date), , drop = FALSE]
  df$up_streak <- cn_streak(df$is_limit_up)
  df$down_streak <- cn_streak(df$is_limit_down)
  df$sellable_date <- cn_next_trade_date(df$trade_date, cal = cal, refresh = refresh)

  tibble::as_tibble(df)
}
