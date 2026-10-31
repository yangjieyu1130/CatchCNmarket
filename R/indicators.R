# Rolling mean without external deps; NA for the first (n - 1) positions
# and for any window that contains an NA.
roll_ma <- function(x, n) {
  n <- as.integer(n)[1]
  if (n < 1L) stop("n \u5fc5\u987b >= 1", call. = FALSE)
  x <- as.numeric(x)
  k <- length(x)
  out <- rep(NA_real_, k)
  if (n > k) return(out)
  for (i in n:k) {
    seg <- x[(i - n + 1L):i]
    if (!any(is.na(seg))) out[i] <- mean(seg)
  }
  out
}

# Rolling standard deviation using the same cumulative-sum trick.
roll_sd <- function(x, n) {
  n <- as.integer(n)[1]
  if (n < 2L) return(rep(NA_real_, length(x)))
  x <- as.numeric(x)
  k <- length(x)
  out <- rep(NA_real_, k)
  if (n > k) return(out)
  mean0 <- roll_ma(x, n)
  for (i in n:k) {
    seg <- x[(i - n + 1L):i]
    out[i] <- stats::sd(seg)
  }
  out
}

# Typical price (H+L+C)/3.
typical_price <- function(df) {
  (as.numeric(df$high) + as.numeric(df$low) + as.numeric(df$close)) / 3
}

# True range (max of |H-L|, |H-pre_close|, |L-pre_close|).
true_range <- function(df) {
  h <- as.numeric(df$high); l <- as.numeric(df$low); c0 <- as.numeric(df$close)
  k <- length(h)
  if (!is.null(df$pre_close)) {
    pc <- c(NA_real_, as.numeric(df$pre_close[-k]))
  } else {
    pc <- c(NA_real_, c0[-k])
  }
  pmax(h - l, abs(h - pc), abs(l - pc))
}

# Average true range over n days (simple rolling mean of TR).
roll_atr <- function(df, n = 14) {
  roll_ma(true_range(df), n)
}

# Return over the last n closed days; 0-based so pct_chg(x, 5) = x[i]/x[i-5]-1.
pct_chg <- function(x, n) {
  n <- as.integer(n)[1]
  x <- as.numeric(x)
  k <- length(x)
  out <- rep(NA_real_, k)
  if (n < 1L || n >= k) return(out)
  out[(n + 1L):k] <- x[(n + 1L):k] / x[1L:(k - n)] - 1
  out
}

# Volume ratio = mean(vol over last n) / mean(vol over last m).
vol_ratio <- function(vol, n = 5L, m = 20L) {
  vol <- as.numeric(vol)
  pmin(roll_ma(vol, n) / roll_ma(vol, m), 1000)  # cap 避免极端值
}

# close vs MA(n) offset in decimals, e.g. 0.05 = 5 percent above MA.
close_vs_ma <- function(close, n) {
  ma <- roll_ma(close, n)
  close / ma - 1
}

# Count of limit-up hits over trailing n days (needs cn_flag columns).
limit_up_count <- function(df, n = 10L) {
  if (!"is_limit_up" %in% names(df)) return(rep(NA_integer_, nrow(df)))
  x <- as.logical(df$is_limit_up); x[is.na(x)] <- FALSE
  k <- length(x)
  out <- rep(NA_integer_, k)
  if (n < 1L || n >= k) return(out)
  for (i in (n + 1L):k) out[i] <- sum(x[(i - n + 1L):i])
  out
}

# Count of trading halts over trailing n days.
halt_count <- function(df, n = 10L) {
  if (!"is_suspended" %in% names(df)) return(rep(NA_integer_, nrow(df)))
  x <- as.logical(df$is_suspended); x[is.na(x)] <- FALSE
  k <- length(x)
  out <- rep(NA_integer_, k)
  if (n < 1L || n >= k) return(out)
  for (i in (n + 1L):k) out[i] <- sum(x[(i - n + 1L):i])
  out
}

# T+1 downside space: close * limit_pct (the worst institutional loss per day),
# or NA if the board has no daily limit (IPO 1..5).
t1_downside <- function(df) {
  if (!all(c("close", "limit_pct") %in% names(df))) return(rep(NA_real_, nrow(df)))
  as.numeric(df$close) * as.numeric(df$limit_pct)
}
