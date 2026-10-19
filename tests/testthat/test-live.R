test_that("live Tushare calls work when a token is configured", {
  skip_if(nchar(Sys.getenv("TUSHARE_TOKEN")) == 0, "no TUSHARE_TOKEN set")

  cal <- cn_trade_cal("20240102", "20240110")
  expect_true(nrow(cal) > 0L)
  expect_true("is_open" %in% names(cal))

  bars <- cn_daily("600519.SH", "20240102", "20240131")
  expect_true(nrow(bars) > 0L)
  expect_true(all(c("open", "high", "low", "close", "pre_close") %in% names(bars)))
  expect_s3_class(bars, "tbl_df")
})
