## R CMD check results

0 errors | 0 warnings | 0 notes

Local check on Windows 11 x64 with R 4.6.1:

`R CMD check --as-cran --run-donttest --no-manual cnmarket_0.3.0.tar.gz`

Status: OK. The `--no-manual` option was used because `pdflatex` is not
installed locally.

## Resubmission

This is a resubmission of `cnmarket` 0.3.0, a new package.

Changes made in response to Leonore Hochhauser's review:

* Removed the redundant "toolkit" wording from the Title and Description.
* Single quotes are now used only for software/API names ('Tushare' and
  'Tencent'). Terms such as qfq, hfq and ChiNext are no longer quoted.
* Removed all uses of `\dontrun{}`. Fast, offline examples now run directly.
  Network-dependent examples use `\donttest{}` and are guarded by
  `if (interactive())`, so checks require neither API credentials nor outbound
  network access.
* Added an optional public Tencent daily-bar endpoint through
  `cn_daily(source = "tencent")`. Tushare remains the default and existing
  calls are unchanged. The Tencent endpoint supports none/qfq/hfq adjustment,
  caching and retries; its `amount` column is `NA` because turnover value is
  not provided by that endpoint.

All 125 tests pass, including unit tests for Tencent parsing and code mapping.
Online tests are skipped on CRAN.
