## R CMD check results

0 errors | 0 warnings | 0 notes

## Submission

This is a resubmission of `cnmarket` 0.3.0, a new package.

Changes since the first attempt (rejected 2026-10-30 on pre-tests):

* The PDF manual failed to build because Rd files contained CJK characters.
  All Chinese text has been removed from the documentation; the Chinese
  board labels returned at runtime are now described in English, and the
  affected examples derive them via `cn_board()` instead of string literals.
  `R CMD Rdconv --type=latex` now yields pure-ASCII output for every Rd file.
* `cn_limit_pct()` no longer uses a Chinese string as a formal default
  (the default is now `NULL`, resolved to the Main Board label internally),
  so the `\usage` section is ASCII.
* DESCRIPTION wording adjusted ('Tushare', 'ChiNext', 'qfq', 'hfq' quoted;
  acronyms spelled out).

## Notes for the reviewer

* The package talks to the Tushare Pro API, which requires users to register
  and obtain a personal access token. Every network-dependent example is
  wrapped in `\dontrun{...}`, and the online testthat tests call
  `testthat::skip()` when no token is configured. The package therefore
  installs, loads, and checks cleanly on a machine without credentials or
  outbound network access.

* Because of the token requirement, the package cannot be exercised end-to-end
  during checks. `cn_daily()`, `cn_stock_basic()`, `cn_trade_cal()`,
  `cn_arima()`, `cn_screen()` and `cn_screen_live()` all return a clear error
  message pointing at `cn_set_token()` / the `TUSHARE_TOKEN` environment
  variable when no token is present.

* All requests are cached on disk under `tools::R_user_dir()` so that repeated
  calls do not hammer the upstream API.

## Test environments

* local: Windows 11 x64, R 4.6.1 (ucrt), Rtools 4.5
