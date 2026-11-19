# Resolve the input into a close-price series plus provenance.
cn_arima_series <- function(x, refresh = FALSE) {
  if (is.character(x) && length(x) == 1L) {
    bars <- cn_daily(x, refresh = refresh)
    list(y = as.numeric(bars$close), last_date = max(bars$trade_date), ts_code = x)
  } else if (is.data.frame(x) && "close" %in% names(x)) {
    ord <- if ("trade_date" %in% names(x)) order(x$trade_date) else seq_len(nrow(x))
    x <- x[ord, , drop = FALSE]
    list(
      y = as.numeric(x$close),
      last_date = if ("trade_date" %in% names(x)) max(as.character(x$trade_date)) else NULL,
      ts_code = if ("ts_code" %in% names(x)) as.character(x$ts_code[1]) else NA_character_
    )
  } else if (is.numeric(x) && is.null(dim(x))) {
    list(y = as.numeric(x), last_date = NULL, ts_code = NA_character_)
  } else {
    stop("x \u5fc5\u987b\u662f ts_code \u5b57\u7b26\u4e32\u3001\u542b close \u5217\u7684\u6570\u636e\u6846\u6216\u6570\u503c\u5411\u91cf\u3002", call. = FALSE)
  }
}

# Small AIC grid search over non-seasonal orders (p, d, q each in 0..2).
cn_arima_auto <- function(y, max_order = 2L) {
  grid <- expand.grid(
    p = 0:max_order, d = 0:max_order, q = 0:max_order,
    KEEP.OUT.ATTRS = FALSE
  )
  fits <- lapply(seq_len(nrow(grid)), function(i) {
    ord <- c(grid$p[i], grid$d[i], grid$q[i])
    tryCatch(
      list(order = ord, aic = stats::arima(y, order = ord)$aic),
      error = function(e) NULL
    )
  })
  fits <- Filter(Negate(is.null), fits)
  if (length(fits) == 0L) {
    stop("auto \u9636\u6570\u641c\u7d22\u5168\u90e8\u5931\u8d25\uff0c\u8bf7\u6539\u7528\u663e\u5f0f order = c(p, d, q)\u3002", call. = FALSE)
  }
  fits[[which.min(vapply(fits, function(f) f$aic, numeric(1)))]]$order
}

# Next n open trading dates after last_date; NULL on any failure.
cn_future_dates <- function(last_date, n_ahead, refresh = FALSE) {
  if (is.null(last_date)) return(NULL)
  tryCatch({
    start <- format(as.Date(last_date, "%Y%m%d") + 1, "%Y%m%d")
    end <- format(as.Date(last_date, "%Y%m%d") + max(30L, 3L * n_ahead), "%Y%m%d")
    cal <- cn_trade_cal(start, end, refresh = refresh)
    open <- sort(cal$cal_date[cal$is_open == 1])
    open[seq_len(min(n_ahead, length(open)))]
  }, error = function(e) NULL)
}

#' Forecast A-share prices with a non-seasonal ARIMA model
#'
#' Fits a non-seasonal `ARIMA(p, d, q)` via [stats::arima()] on the close-price
#' series and produces an elementary point forecast with prediction intervals.
#' With `order = "auto"` (default) a small AIC grid search over
#' `p, d, q in 0..2` picks the order. Setting `log_price = TRUE` (default)
#' models log prices, which keeps forecasts positive and stabilises variance.
#'
#' Future `trade_date` values are looked up from the trading calendar
#' ([cn_trade_cal()]); when the calendar is unavailable (offline, no token),
#' dates are `NA` and the `h` column still marks the forecast horizon.
#'
#' This is a *basic* univariate extrapolation -- no seasonality, no exogenous
#' drivers, no regime switching. Treat it as a quick statistical baseline,
#' not investment advice.
#'
#' @param x A single `ts_code` (fetched via [cn_daily()], trailing 365 days),
#'   a data frame from [cn_daily()] (uses its `close` column, sorted by
#'   `trade_date`), or a numeric vector of prices.
#' @param order `"auto"` (default) for AIC grid search, or an explicit
#'   integer vector `c(p, d, q)`.
#' @param n_ahead Forecast horizon in trading days (default 5).
#' @param log_price Model log prices and back-transform (default `TRUE`).
#' @param level Interval confidence levels in percent (default `c(80, 95)`).
#' @param refresh Force fresh API calls, bypassing the cache.
#' @return A tibble with `h` (horizon), `trade_date`, `forecast`, and one
#'   `lo`/`hi` pair per entry of `level` (e.g. `lo80`, `hi95`). Attributes:
#'   `"order"` (fitted order), `"aic"`, `"log_price"`, `"ts_code"`.
#' @examples
#' prices <- 100 + cumsum(c(
#'   0.2, -0.1, 0.4, 0.1, -0.3, 0.2, 0.5, -0.2, 0.1, 0.3,
#'   -0.1, 0.2, 0.4, -0.3, 0.1, 0.2, -0.2, 0.3, 0.1, -0.1
#' ))
#' suppressWarnings(cn_arima(prices, order = c(1, 0, 0), n_ahead = 3))
#'
#' \donttest{
#' if (interactive()) {
#' cn_arima("600519.SH", n_ahead = 5)
#' cn_arima(cn_daily("300750.SZ", adjust = "qfq"), order = c(1, 1, 1))
#' }
#' }
#' @export
cn_arima <- function(x, order = "auto", n_ahead = 5, log_price = TRUE,
                     level = c(80, 95), refresh = FALSE) {
  # Validate inputs before any network call.
  n_ahead <- as.integer(n_ahead)[1]
  if (is.na(n_ahead) || n_ahead < 1L) stop("n_ahead \u5fc5\u987b\u662f\u6b63\u6574\u6570\u3002", call. = FALSE)
  level <- sort(unique(as.numeric(level)))
  if (any(level <= 0 | level >= 100)) stop("level \u5fc5\u987b\u5728 (0, 100) \u5185\u3002", call. = FALSE)
  if (!identical(order, "auto")) {
    o <- as.integer(order)
    if (length(o) != 3L || any(is.na(o)) || any(o < 0L)) {
      stop("order \u5fc5\u987b\u662f \"auto\" \u6216\u975e\u8d1f\u6574\u6570\u5411\u91cf c(p, d, q)\u3002", call. = FALSE)
    }
  }

  s <- cn_arima_series(x, refresh = refresh)
  y0 <- s$y[!is.na(s$y)]
  if (length(y0) < 10L) stop("\u5e8f\u5217\u592a\u77ed\uff0c\u81f3\u5c11\u9700\u8981 10 \u4e2a\u89c2\u6d4b\u3002", call. = FALSE)
  if (length(unique(y0)) < 2L) stop("\u5e8f\u5217\u4e3a\u5e38\u6570\uff0c\u65e0\u6cd5\u62df\u5408 ARIMA\u3002", call. = FALSE)
  if (log_price) {
    if (any(y0 <= 0)) stop("log_price = TRUE \u8981\u6c42\u4ef7\u683c\u5168\u4e3a\u6b63\u6570\u3002", call. = FALSE)
    y <- log(y0)
  } else {
    y <- y0
  }

  ord <- if (identical(order, "auto")) {
    cn_arima_auto(y)
  } else {
    as.integer(order)
  }
  fit <- stats::arima(y, order = ord)
  pr <- stats::predict(fit, n.ahead = n_ahead, se.fit = TRUE)
  mu <- as.numeric(pr$pred)
  se <- as.numeric(pr$se)

  out <- tibble::tibble(h = seq_len(n_ahead))
  dates <- cn_future_dates(s$last_date, n_ahead, refresh = refresh)
  if (is.null(dates) || length(dates) < n_ahead) {
    warning("\u4ea4\u6613\u65e5\u5386\u4e0d\u53ef\u7528\uff0ctrade_date \u4ee5 NA \u5360\u4f4d\uff08h \u5217\u4ecd\u4e3a\u9884\u6d4b\u6b65\u6570\uff09\u3002", call. = FALSE)
    dates <- c(dates, rep(NA_character_, n_ahead - length(dates)))
  }
  out$trade_date <- dates

  back <- if (log_price) exp else identity
  out$forecast <- back(mu)
  for (lv in level) {
    z <- stats::qnorm(0.5 + lv / 200)
    out[[paste0("lo", lv)]] <- back(mu - z * se)
    out[[paste0("hi", lv)]] <- back(mu + z * se)
  }
  attr(out, "order") <- unname(ord)
  attr(out, "aic") <- fit$aic
  attr(out, "log_price") <- log_price
  attr(out, "ts_code") <- s$ts_code
  out
}
