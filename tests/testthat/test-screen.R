cn_mock_feats <- function(n = 20, seed = 1) {
  set.seed(seed)
  boards <- sample(c("主板", "创业板", "科创板", "北交所"), n, replace = TRUE,
                   prob = c(0.5, 0.2, 0.2, 0.1))
  limits <- vapply(boards, function(b) cn_limit_pct(b), numeric(1))
  tibble::tibble(
    ts_code  = sprintf("mock%04d", 1:n),
    name     = paste0("Mock", 1:n),
    trade_date = rep("20240601", n),
    close    = round(runif(n, 8, 800), 2),
    board    = boards,
    is_st    = sample(c(TRUE, FALSE), n, replace = TRUE, prob = c(0.05, 0.95)),
    limit_pct = limits,
    up_streak = sample(0:6, n, replace = TRUE, prob = c(0.55, 0.20, 0.10, 0.08, 0.04, 0.02, 0.01)),
    down_streak = sample(0:3, n, replace = TRUE, prob = c(0.80, 0.12, 0.05, 0.03)),
    is_limit_up = runif(n) < 0.05,
    is_limit_down = runif(n) < 0.03,
    limit_up_count_10d = sample(0:3, n, replace = TRUE, prob = c(0.6, 0.25, 0.10, 0.05)),
    halt_count_10d = sample(0:2, n, replace = TRUE, prob = c(0.85, 0.12, 0.03)),
    t1_downside = runif(n, 0.5, 5),
    pct_chg_5d  = runif(n, -0.08, 0.12),
    pct_chg_20d = runif(n, -0.20, 0.40),
    vol_ratio_5_20 = runif(n, 0.5, 4),
    atr_pct     = runif(n, 0.01, 0.06),
    close_vs_ma20 = runif(n, -0.08, 0.15),
    vol_20d     = runif(n, 0.005, 0.030),
    sellable_date = rep("20240602", n)
  )
}

test_that("cn_eval_filter handles ranges and membership", {
  x <- c(1, 2, 3, 4, 5, NA)

  # numeric range
  expect_equal(cn_eval_filter(x, c(2, 4)), c(FALSE, TRUE, TRUE, TRUE, FALSE, NA))

  # open end via -Inf / Inf
  expect_equal(cn_eval_filter(x, c(3, Inf)), c(FALSE, FALSE, TRUE, TRUE, TRUE, NA))
  expect_equal(cn_eval_filter(x, c(-Inf, 2)), c(TRUE, TRUE, FALSE, FALSE, FALSE, NA))

  # NULL passthrough
  expect_true(all(cn_eval_filter(x, NULL)))

  # exact / membership
  expect_equal(cn_eval_filter(x, 3), c(FALSE, FALSE, TRUE, FALSE, FALSE, NA))
  expect_equal(cn_eval_filter(c("a", "b", "c", "d"), c("b", "d")),
               c(FALSE, TRUE, FALSE, TRUE))
})

test_that("cn_screen filters mocked features correctly", {
  feats <- cn_mock_feats()
  df <- feats

  # Board membership filter
  f_board <- cn_eval_filter(df$board, c("创业板", "科创板"))
  expect_true(all(df$board[f_board] %in% c("创业板", "科创板")))

  # ST exclusion
  f_no_st <- cn_eval_filter(df$is_st, FALSE)
  expect_false(any(df$is_st[f_no_st]))

  # Streak range 2..4
  f_streak <- cn_eval_filter(df$up_streak, c(2, 4))
  expect_true(all(df$up_streak[f_streak] >= 2 & df$up_streak[f_streak] <= 4))

  # Combined
  combined <- f_board & f_no_st & f_streak
  res <- df[combined, , drop = FALSE]
  expect_true(nrow(res) > 0L)
  expect_true(all(res$board %in% c("创业板", "科创板")))
  expect_true(!any(res$is_st))
  expect_true(all(res$up_streak >= 2 & res$up_streak <= 4))

  # Open-end pct_chg_20d filter
  f_gain <- cn_eval_filter(df$pct_chg_20d, c(-0.05, Inf))
  expect_true(all(df$pct_chg_20d[f_gain] >= -0.05))
})

test_that("cn_screen rejects invalid inputs early", {
  # This fails before any network call because universe type is invalid.
  expect_error(cn_screen(universe = 123, filters = list(a = 1)), regexp = "须为.*all")
  # data.frame without ts_code column should error inside cn_universe (still early,
  # but we need a valid filters list to avoid tripping the filters guard first).
  expect_error(cn_screen(universe = data.frame(foo = 1), filters = list(a = 1)),
               regexp = "ts_code")
  # empty filters list must error before any network
  expect_error(cn_screen(universe = "all"), regexp = "filters 须为命名列表")
})
