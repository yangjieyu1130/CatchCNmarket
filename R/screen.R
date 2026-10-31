# --- Universe helpers -------------------------------------------------------

#' Resolve the stock universe for screening
#'
#' @param universe One of: `"all"` (all listed A shares via `stock_basic`),
#'   a character vector of `ts_code` values, or a data frame from
#'   [cn_stock_basic()].
#' @param refresh Force a fresh `stock_basic` call.
#' @return A tibble of candidate stocks.
#' @keywords internal
cn_universe <- function(universe, refresh = FALSE) {
  if (is.data.frame(universe)) {
    if (!"ts_code" %in% names(universe)) stop("universe \u6570\u636e\u6846\u7f3a\u5c11 ts_code \u5217\u3002", call. = FALSE)
    return(tibble::as_tibble(universe))
  }
  if (is.character(universe) && length(universe) == 1L && universe == "all") {
    return(cn_stock_basic(refresh = refresh))
  }
  if (is.character(universe)) {
    basic <- cn_stock_basic(universe, refresh = refresh)
    missing <- setdiff(universe, basic$ts_code)
    if (length(missing)) warning("\u4ee5\u4e0b\u4ee3\u7801\u5728 stock_basic \u4e2d\u4e0d\u5b58\u5728\uff1a", paste(missing, collapse = ", "), call. = FALSE)
    return(basic)
  }
  stop("universe \u987b\u4e3a \"all\"\u3001ts_code \u5411\u91cf\u6216 stock_basic \u7ed3\u679c\u3002", call. = FALSE)
}

# Map a filter expression to a match test. Accepts:
#   - a length-2 numeric c(min, max)
#   - a length-2 numeric with -Inf/Inf open ends
#   - a scalar for exact / membership match
cn_eval_filter <- function(x, cond) {
  if (is.null(cond)) return(rep(TRUE, length(x)))
  if (is.numeric(cond) && length(cond) == 2L) {
    lo <- cond[1]; hi <- cond[2]
    if (!is.finite(lo)) lo <- -Inf
    if (!is.finite(hi)) hi <- Inf
    out <- x >= lo & x <= hi
    out[is.na(x)] <- NA
    out
  } else {
    out <- x %in% cond
    out[is.na(x)] <- NA
    out
  }
}

#' Compute a single-row feature vector for one stock over a lookback window
#'
#' Fetches ~n_lookback daily bars, tags them with [cn_flag()], and computes
#' the institutional + technical features that feed the screen.
#'
#' @param ts_code A single code like `"600519.SH"`.
#' @param n_lookback Trading days of history (default 60).
#' @param refresh Skip cache for the daily fetch.
#' @return A one-row tibble with the feature columns.
#' @keywords internal
cn_feature_row <- function(ts_code, n_lookback = 60L, refresh = FALSE,
                           basic = NULL) {
  end <- Sys.Date()
  start <- format(end - 1.5 * n_lookback, "%Y%m%d")
  end_s <- format(end, "%Y%m%d")
  bars <- tryCatch(
    cn_daily(ts_code, start, end_s, refresh = refresh),
    error = function(e) NULL
  )
  if (is.null(bars) || nrow(bars) < 20L) return(NULL)

  # Strip latest incomplete day if today is non-trading.
  bars <- bars[order(bars$trade_date), , drop = FALSE]
  bars <- utils::tail(bars, min(nrow(bars), n_lookback + 1L))

  is_st <- FALSE
  if (is.null(basic)) basic <- tryCatch(cn_stock_basic(ts_code, refresh = refresh), error = function(e) NULL)
  if (!is.null(basic) && nrow(basic) > 0L) is_st <- grepl("ST", basic$name[1], ignore.case = TRUE)

  tagged <- cn_flag(bars, is_st = is_st)
  if (nrow(tagged) < 20L) return(NULL)
  last <- tagged[nrow(tagged), , drop = FALSE]

  # Technical features (use full history).
  close <- as.numeric(tagged$close)
  vol   <- as.numeric(tagged$vol)
  pct5  <- pct_chg(close, 5L)[nrow(tagged)]
  pct20 <- pct_chg(close, 20L)[nrow(tagged)]
  volr  <- vol_ratio(vol, 5L, 20L)[nrow(tagged)]
  atr_p <- (roll_atr(tagged, 14L) / close)[nrow(tagged)]
  cvma  <- close_vs_ma(close, 20L)[nrow(tagged)]
  vola  <- roll_sd(diff(log(close)), 20L)[nrow(tagged)]
  lim_up_n10 <- limit_up_count(tagged, 10L)[nrow(tagged)]
  halt_n10   <- halt_count(tagged, 10L)[nrow(tagged)]
  td         <- t1_downside(tagged)[nrow(tagged)]

  tibble::tibble(
    ts_code = ts_code,
    trade_date = last$trade_date,
    close = close[length(close)],
    board = last$board,
    is_st = is_st,
    limit_pct = last$limit_pct,
    up_streak = last$up_streak,
    down_streak = last$down_streak,
    is_limit_up = last$is_limit_up,
    is_limit_down = last$is_limit_down,
    limit_up_count_10d = lim_up_n10,
    halt_count_10d = halt_n10,
    t1_downside = td,
    pct_chg_5d = pct5,
    pct_chg_20d = pct20,
    vol_ratio_5_20 = volr,
    atr_pct = atr_p,
    close_vs_ma20 = cvma,
    vol_20d = vola,
    sellable_date = last$sellable_date
  )
}

# Compute ARIMA prediction features and append them to an existing feature row.
# Returns the amended row, or NULL on failure.
cn_arima_feature_row <- function(ts_code, feat_row, horizon = 3L, refresh = FALSE) {
  tryCatch({
    fc <- cn_arima(ts_code, n_ahead = horizon, refresh = refresh)
    chg <- fc$forecast[horizon] / feat_row$close - 1
    ord <- paste(attr(fc, "order"), collapse = ",")
    feat_row$arima_pred_chg <- chg
    feat_row$arima_order <- ord
    feat_row
  }, error = function(e) {
    feat_row$arima_pred_chg <- NA_real_
    feat_row$arima_order <- NA_character_
    feat_row
  })
}

#' Screen the A-share universe on institutional + technical factors
#'
#' Fetches daily bars for every candidate, tags them with [cn_flag()], computes
#' a compact institutional/technical feature row per stock, and applies
#' arbitrary filter expressions. Optionally an ARIMA prediction pass is run
#' on the survivors.
#'
#' **Institutional factors are unique to `cnmarket`**:
#' `board`, `is_st`, `limit_pct`, `up_streak`, `down_streak`,
#' `limit_up_count_10d`, `halt_count_10d`, `t1_downside`, `sellable_date`.
#'
#' **Technical factors** (base-R implementation, zero extra deps):
#' `pct_chg_5d`, `pct_chg_20d`, `vol_ratio_5_20`, `atr_pct`,
#' `close_vs_ma20`, `vol_20d`.
#'
#' **Forecast factors** (when `run_arima = TRUE`):
#' `arima_pred_chg` (horizon-day predicted return), `arima_order`.
#'
#' @param universe `"all"`, a `ts_code` vector, or a data frame from
#'   [cn_stock_basic()].
#' @param filters Named list of filter expressions. Each value must be either
#'   `c(min, max)` for a numeric range (open ends allowed, e.g. `c(0.10, Inf)`),
#'   or a value / vector for exact / membership match (e.g. a vector of board
#'   labels from [cn_board()]).
#' @param n_lookback Trading-day history per stock (default 60).
#' @param run_arima If `TRUE`, append ARIMA forecast features and allow
#'   filtering on `arima_pred_chg`. Only runs on stocks that pass the
#'   institutional + technical filters first.
#' @param arima_horizon Forecast horizon in trading days (default 3).
#' @param refresh Bypass caches when fetching data.
#' @param progress If `TRUE`, print a per-stock progress tick.
#' @return A tibble, one row per surviving stock, with all feature columns
#'   (including `score` when `run_arima = TRUE`, simple z-score weighted sum).
#' @examples
#' \dontrun{
#' # ChiNext/STAR boards, non-ST, volume expansion, moderate 20-day gain
#' boards20 <- vapply(c("300750.SZ", "688981.SH"), cn_board, character(1))
#' res <- cn_screen(
#'   universe = c("600519.SH", "300750.SZ", "601318.SH", "000001.SZ"),
#'   filters = list(
#'     board          = boards20,
#'     is_st          = FALSE,
#'     pct_chg_20d    = c(-0.05, 0.30),
#'     vol_ratio_5_20 = c(1.2, 5)
#'   )
#' )
#'
#' # Relay boards (2-4 consecutive limit-ups, ChiNext/STAR) + forecast up
#' res <- cn_screen(
#'   universe = "all",
#'   filters = list(
#'     board       = boards20,
#'     is_st       = FALSE,
#'     up_streak   = c(2, 4),
#'     halt_count_10d = c(0, 0),
#'     arima_pred_chg  = c(0, Inf)
#'   ),
#'   run_arima = TRUE
#' )
#' }
#' @export
cn_screen <- function(universe = "all", filters = list(),
                      n_lookback = 60L, run_arima = FALSE,
                      arima_horizon = 3L, refresh = FALSE,
                      progress = FALSE) {
  # Validate inputs BEFORE any network calls. Universe first so obvious
  # misuse is caught even when filters is empty.
  if (!is.character(universe) && !is.data.frame(universe)) {
    stop("universe \u987b\u4e3a \"all\"\u3001ts_code \u5411\u91cf\u6216 stock_basic \u7ed3\u679c\u3002", call. = FALSE)
  }
  nms <- names(filters)
  if (is.null(nms) || !nzchar(nms[1])) stop("filters \u987b\u4e3a\u547d\u540d\u5217\u8868\u3002", call. = FALSE)

  cand <- cn_universe(universe, refresh = refresh)
  codes <- cand$ts_code
  name_map <- if ("name" %in% names(cand)) {
    stats::setNames(cand$name, cand$ts_code)
  } else {
    character(0)
  }

  if (length(codes) == 0L) stop("\u5019\u9009\u6c60\u4e3a\u7a7a\u3002", call. = FALSE)

  pre_arima_nms <- c(
    "board", "is_st", "limit_pct", "up_streak", "down_streak",
    "is_limit_up", "is_limit_down", "limit_up_count_10d",
    "halt_count_10d", "t1_downside", "pct_chg_5d", "pct_chg_20d",
    "vol_ratio_5_20", "atr_pct", "close_vs_ma20", "vol_20d"
  )

  if (progress) cat("\u6536\u96c6\u7279\u5f81\u4e2d... \u5171", length(codes), "\u53ea\n")
  feats <- vector("list", length(codes))
  for (i in seq_along(codes)) {
    if (progress && i %% 20 == 0) cat("  ", i, "/", length(codes), "\n")
    basic_row <- cand[cand$ts_code == codes[i], , drop = FALSE]
    feats[[i]] <- tryCatch(
      cn_feature_row(codes[i], n_lookback = n_lookback, refresh = refresh,
                     basic = basic_row),
      error = function(e) NULL
    )
  }
  feats <- Filter(Negate(is.null), feats)
  if (length(feats) == 0L) stop("\u6240\u6709\u5019\u9009\u6807\u7684\u53d6\u6570\u5931\u8d25\u3002", call. = FALSE)
  df <- do.call(rbind, feats)
  df$name <- ifelse(df$ts_code %in% names(name_map),
                    name_map[df$ts_code], NA_character_)
  df <- df[, c("ts_code", "name", setdiff(names(df), c("ts_code", "name")))]

  # Apply pre-arima filters.
  for (nm in nms[nms %in% pre_arima_nms]) {
    col <- df[[nm]]
    df <- df[cn_eval_filter(col, filters[[nm]]), , drop = FALSE]
  }
  if (nrow(df) == 0L) {
    return(tibble::as_tibble(df))
  }

  # ARIMA pass only if requested AND the filter needs it.
  want_arima_filters <- any(grepl("arima_pred_chg", nms))
  if (run_arima || want_arima_filters) {
    if (progress) cat("ARIMA \u9884\u6d4b\u4e2d... \u5171", nrow(df), "\u53ea\n")
    ar_rows <- vector("list", nrow(df))
    for (i in seq_len(nrow(df))) {
      if (progress && i %% 10 == 0) cat("  ", i, "/", nrow(df), "\n")
      ar_rows[[i]] <- cn_arima_feature_row(df$ts_code[i], df[i, , drop = FALSE],
                                            horizon = arima_horizon,
                                            refresh = refresh)
    }
    df <- do.call(rbind, ar_rows)

    # Apply post-arima filters.
    for (nm in nms[!nms %in% pre_arima_nms]) {
      if (nm %in% names(df)) {
        col <- df[[nm]]
        df <- df[cn_eval_filter(col, filters[[nm]]), , drop = FALSE]
      }
    }

    # Simple score: normalise arima_pred_chg into z-score weighted 1,
    # plus inverse of t1_downside, inverse of vol_20d.
    if (nrow(df) > 0L && all(c("arima_pred_chg", "t1_downside", "vol_20d") %in% names(df))) {
      z_origina <- (df$arima_pred_chg - mean(df$arima_pred_chg, na.rm = TRUE)) / stats::sd(df$arima_pred_chg, na.rm = TRUE)
      z_downside <- -(df$t1_downside - mean(df$t1_downside, na.rm = TRUE)) / stats::sd(df$t1_downside, na.rm = TRUE)
      z_vol     <- -(df$vol_20d - mean(df$vol_20d, na.rm = TRUE)) / stats::sd(df$vol_20d, na.rm = TRUE)
      df$score <- z_origina + z_downside + z_vol
      df <- df[order(-df$score), , drop = FALSE]
    }
  }

  tibble::as_tibble(df)
}

#' Convenience screen for limit-up / relay-board setups
#'
#' A preset on top of [cn_screen()] tuned for relay-board chasing:
#' non-ST, ChiNext / STAR (20 percent boards), up-streak in a target band,
#' no recent halts, no consecutive down-limits, and ARIMA forecast >= 0.
#'
#' @param universe `"all"` or a `ts_code` vector.
#' @param streak_range Integer band, default `2:4` (2..4 consecutive limit-ups).
#' @param refresh Bypass caches.
#' @param progress Print progress ticks (default `TRUE`).
#' @param ... Additional filter expressions forwarded to [cn_screen()].
#' @return See [cn_screen()].
#' @examples
#' \dontrun{
#' cn_screen_live(universe = c("600519.SH", "300750.SZ"))
#' cn_screen_live(universe = "all", streak_range = 3:5)
#' }
#' @export
cn_screen_live <- function(universe = "all", streak_range = 2L:4L,
                           refresh = FALSE, progress = TRUE, ...) {
  filters <- c(
    list(
      board           = c("\u521b\u4e1a\u677f", "\u79d1\u521b\u677f"),
      is_st           = FALSE,
      up_streak       = c(min(streak_range), max(streak_range)),
      down_streak     = c(0, 0),
      halt_count_10d  = c(0, 0),
      arima_pred_chg  = c(0, Inf)
    ),
    list(...)
  )
  cn_screen(universe = universe, filters = filters, run_arima = TRUE,
            refresh = refresh, progress = progress)
}
