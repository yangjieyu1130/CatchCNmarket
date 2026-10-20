test_that("cn_arima forecasts a synthetic series with explicit order", {
  set.seed(42)
  y <- as.numeric(arima.sim(n = 200, list(ar = 0.6))) + 100
  # Numeric input has no last_date -> calendar lookup is skipped, dates are NA.
  expect_warning(
    fc <- cn_arima(y, order = c(1, 0, 1), n_ahead = 5),
    "交易日历"
  )

  expect_s3_class(fc, "tbl_df")
  expect_equal(nrow(fc), 5L)
  expect_true(all(c("h", "trade_date", "forecast", "lo80", "hi80", "lo95", "hi95") %in% names(fc)))
  expect_true(all(is.na(fc$trade_date)))
  expect_true(all(is.finite(fc$forecast)))
  expect_true(all(fc$forecast > 0))                 # log back-transform keeps positivity
  expect_true(all(fc$lo95 <= fc$lo80 & fc$lo80 <= fc$forecast &
                  fc$forecast <= fc$hi80 & fc$hi80 <= fc$hi95))
  expect_equal(attr(fc, "order"), c(1L, 0L, 1L))
  expect_true(is.finite(attr(fc, "aic")))
})

test_that("cn_arima auto order search returns a valid order", {
  set.seed(7)
  y <- as.numeric(arima.sim(n = 150, list(ar = 0.5, ma = 0.3))) + 50
  suppressWarnings(fc <- cn_arima(y, order = "auto", n_ahead = 3))
  ord <- attr(fc, "order")
  expect_length(ord, 3L)
  expect_true(all(ord >= 0L & ord <= 2L))
})

test_that("cn_arima accepts a cn_daily-style data frame", {
  df <- data.frame(
    ts_code = "000001.SZ",
    trade_date = sprintf("2024%02d%02d", rep(1:5, each = 20), rep(1:20, 5)),
    close = 10 + cumsum(rnorm(100, 0.02, 0.15)),
    stringsAsFactors = FALSE
  )
  suppressWarnings(fc <- cn_arima(df, order = c(0, 1, 1), n_ahead = 3))
  expect_equal(nrow(fc), 3L)
  expect_equal(attr(fc, "ts_code"), "000001.SZ")
  expect_length(fc$trade_date, 3L)
})

test_that("cn_arima validates inputs", {
  expect_error(cn_arima(1:5), "10")
  expect_error(cn_arima(rep(3, 50)), "常数")
  expect_error(cn_arima("600519.SH", order = c(1, 1)), "order")
  expect_error(cn_arima(data.frame(a = 1:20)), "x 必须")
})
