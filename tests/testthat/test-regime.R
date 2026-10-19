test_that("cn_board infers the board from the code prefix", {
  expect_equal(cn_board("600519.SH"), "主板")
  expect_equal(cn_board("000001.SZ"), "主板")
  expect_equal(cn_board("688981.SH"), "科创板")
  expect_equal(cn_board("300750.SZ"), "创业板")
  expect_equal(cn_board("301029.SZ"), "创业板")
  expect_equal(cn_board("430047.BJ"), "北交所")
  expect_equal(cn_board("830799.BJ"), "北交所")
})

test_that("cn_board trusts an explicit market label", {
  expect_equal(cn_board("600519.SH", market = "创业板"), "创业板")
})

test_that("cn_limit_pct follows the A-share regime", {
  expect_equal(cn_limit_pct("主板"), 0.10)
  expect_equal(cn_limit_pct("主板", is_st = TRUE), 0.05)
  expect_equal(cn_limit_pct("创业板"), 0.20)
  expect_equal(cn_limit_pct("科创板"), 0.20)
  expect_equal(cn_limit_pct("北交所"), 0.30)
})

test_that("first-5-day listings are unlimited", {
  expect_true(is.na(cn_limit_pct("主板", days_since_list = 3)))
  expect_true(is.na(cn_limit_pct("创业板", days_since_list = 5)))
  expect_equal(cn_limit_pct("主板", days_since_list = 6), 0.10)
})

test_that("cn_limit_rule returns a one-row rule table", {
  r <- cn_limit_rule("688981.SH")
  expect_s3_class(r, "tbl_df")
  expect_equal(nrow(r), 1L)
  expect_equal(r$board, "科创板")
  expect_equal(r$limit_pct, 0.20)
})

test_that("cn_flag tags limits, halts, streaks and T+1 dates", {
  cal <- data.frame(
    exchange = "SSE",
    cal_date = c("20240102", "20240103", "20240104", "20240105"),
    is_open = c(1, 1, 1, 1),
    pretrade_date = c("20231229", "20240102", "20240103", "20240104")
  )
  bars <- data.frame(
    ts_code = "600519.SH",
    trade_date = c("20240102", "20240103", "20240104"),
    open = c(10.5, 11, 11.5),
    high = c(11, 11, 12.1),
    low = c(10.4, 10.9, 11.4),
    close = c(11, 11, 12.1),
    pre_close = c(10, 11, 11),
    vol = c(1000, 0, 1000)
  )
  out <- cn_flag(bars, is_st = FALSE, cal = cal)

  expect_true("limit_pct" %in% names(out))
  expect_equal(out$limit_pct, rep(0.10, 3))
  expect_equal(out$limit_up, c(11.00, 12.10, 12.10))
  expect_equal(out$is_limit_up, c(TRUE, FALSE, TRUE))
  expect_equal(out$is_suspended, c(FALSE, TRUE, FALSE))
  expect_equal(out$up_streak, c(1L, 0L, 1L))
  expect_equal(out$sellable_date, c("20240103", "20240104", "20240105"))
})

test_that("the same 10% move is a limit-up on the Main Board but not on ChiNext", {
  cal <- data.frame(
    exchange = "SSE",
    cal_date = c("20240102", "20240103"),
    is_open = c(1, 1),
    pretrade_date = c("20231229", "20240102")
  )
  bars <- data.frame(
    ts_code = "600519.SH",
    trade_date = "20240102",
    open = 12.1, high = 12.1, low = 11.9, close = 12.10,
    pre_close = 11, vol = 500
  )
  main <- cn_flag(bars, is_st = FALSE, cal = cal)
  expect_equal(main$limit_pct, 0.10)
  expect_equal(main$limit_up, 12.10)
  expect_true(main$is_limit_up)

  bars$ts_code <- "300750.SZ"
  cyb <- cn_flag(bars, is_st = FALSE, cal = cal)
  expect_equal(cyb$limit_pct, 0.20)
  expect_equal(cyb$limit_up, 13.20)
  expect_false(cyb$is_limit_up)
})
