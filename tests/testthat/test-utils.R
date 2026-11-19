test_that("cn_ymd normalises date inputs", {
  expect_equal(cn_ymd("2024-01-02"), "20240102")
  expect_equal(cn_ymd("20240102"), "20240102")
  expect_equal(cn_ymd(as.Date("2024-01-02")), "20240102")
  expect_error(cn_ymd("2024"), "日期")
})

test_that("cn_key is filesystem-safe", {
  expect_equal(cn_key("daily", "600519.SH", "20240101"), "daily__600519.SH__20240101")
  expect_false(grepl("[/:]", cn_key("a/b:c", "d e")))
})

test_that("cn_auto_type coerces numerics but keeps ids and dates", {
  df <- data.frame(
    ts_code = c("600519.SH"),
    trade_date = c("20240102"),
    close = c("1680.5"),
    name = c("贵州茅台"),
    stringsAsFactors = FALSE
  )
  out <- cn_auto_type(df)
  expect_type(out$close, "double")
  expect_type(out$trade_date, "character")
  expect_type(out$ts_code, "character")
})

test_that("Tencent security identifiers are mapped correctly", {
  expect_equal(cn_tencent_symbol("600519.SH"), "sh600519")
  expect_equal(cn_tencent_symbol("300750.SZ"), "sz300750")
  expect_equal(cn_tencent_symbol("430047.BJ"), "bj430047")
  expect_error(cn_tencent_symbol("600519"), "six-digit")
})

test_that("Tencent klines match the cn_daily schema", {
  klines <- list(
    c("2023-12-29", "1715.00", "1726.00", "1730.00", "1700.00", "30000"),
    c("2024-01-02", "1715.00", "1685.01", "1718.19", "1678.10", "32156")
  )
  out <- cn_tencent_parse(klines, "600519.SH")
  expect_s3_class(out, "tbl_df")
  expect_equal(out$trade_date, c("20231229", "20240102"))
  expect_equal(out$open, c(1715, 1715))
  expect_equal(out$close, c(1726, 1685.01))
  expect_equal(out$pre_close, c(NA_real_, 1726))
  expect_equal(out$change[2], -40.99)
  expect_equal(out$pct_chg[2], -40.99 / 1726 * 100)
  expect_equal(out$vol, c(30000, 32156))
  expect_true(all(is.na(out$amount)))
  expect_equal(attr(out, "adjust"), "none")
})

test_that("cn_streak counts consecutive TRUEs", {
  expect_equal(cn_streak(c(TRUE, TRUE, FALSE, TRUE)), c(1L, 2L, 0L, 1L))
  expect_equal(cn_streak(c(FALSE, FALSE)), c(0L, 0L))
  expect_equal(cn_streak(logical(0)), integer(0))
})
