test_that("rolling functions produce correct values", {
  # roll_ma
  x <- c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)
  ma3 <- roll_ma(x, 3)
  expect_true(all(is.na(ma3[1:2])))
  expect_equal(ma3[3], 2)
  expect_equal(ma3[10], mean(x[8:10]))

  # wider window than series -> all NA
  expect_true(all(is.na(roll_ma(x, 20))))

  # roll_sd
  sd5 <- roll_sd(x, 5)
  expect_true(all(is.na(sd5[1:4])))
  expect_equal(sd5[5], stats::sd(x[1:5]))

  # roll_atr (need df with H/L/C; pre_close optional)
  df <- data.frame(high  = c(12, 13, 14),
                   low   = c(10, 11, 12),
                   close = c(11, 12, 13),
                   stringsAsFactors = FALSE)
  atr2 <- roll_atr(df, 2)
  # TR day2 = max(|13-11|, |13-11|, |11-11|) = 2; TR day3 = max(2, 1, 1) = 2
  expect_equal(atr2[3], 2)
})

test_that("pct_chg and vol_ratio match hand calculations", {
  x <- c(100, 105, 110, 99, 102, 104)
  pc5 <- pct_chg(x, 5)
  expect_true(all(is.na(pc5[1:5])))
  expect_equal(pc5[6], 104 / 100 - 1)

  # vol_ratio: 5-day mean / 20-day mean (short series => NA at end)
  vol <- runif(50, 1, 100)
  vr <- vol_ratio(vol, 5, 20)
  expect_true(all(is.na(vr[1:19])))
  # cap kicks in for extreme ratios
  vr2 <- vol_ratio(c(rep(1, 20), rep(1e6, 5)), 5, 20)
  expect_lt(vr2[length(vr2)], 1000)
})

test_that("close_vs_ma and streak-count helpers work", {
  close <- c(10, 11, 12, 13, 14, 15)
  ma3 <- roll_ma(close, 3)
  cvma <- close_vs_ma(close, 3)
  expect_equal(cvma[5], close[5] / ma3[5] - 1)

  # limit_up_count on an already-tagged df
  df <- data.frame(is_limit_up = c(F, T, F, T, T, F), stringsAsFactors = FALSE)
  cnt <- limit_up_count(df, 3)
  # day4 window: F, T, F -> 1; day5 window: T, F, T -> 2; day6: F, T, T -> 2
  expect_equal(cnt[6], 2)

  # halt_count identical logic
  df2 <- data.frame(is_suspended = c(F, F, T, F, F, F), stringsAsFactors = FALSE)
  hc <- halt_count(df2, 3)
  expect_equal(hc[6], 0)
  expect_equal(hc[5], 1)
})
