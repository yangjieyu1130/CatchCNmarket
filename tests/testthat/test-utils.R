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

test_that("cn_streak counts consecutive TRUEs", {
  expect_equal(cn_streak(c(TRUE, TRUE, FALSE, TRUE)), c(1L, 2L, 0L, 1L))
  expect_equal(cn_streak(c(FALSE, FALSE)), c(0L, 0L))
  expect_equal(cn_streak(logical(0)), integer(0))
})
