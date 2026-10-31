#' Configure the Tushare token
#'
#' The token is read from the `cnmarket.token` option first, then from the
#' `TUSHARE_TOKEN` environment variable. `cn_set_token()` sets the option for the
#' current session.
#'
#' @param token A Tushare API token (single non-empty string).
#' @return `cn_set_token()` invisibly returns the token; `cn_token()` returns the
#'   resolved token or errors if none is configured.
#' @examples
#' \dontrun{
#' cn_set_token("your_tushare_token")
#' }
#' @export
cn_set_token <- function(token) {
  if (!is.character(token) || length(token) != 1L || !nzchar(token)) {
    stop("token \u5fc5\u987b\u662f\u975e\u7a7a\u5b57\u7b26\u4e32\u3002", call. = FALSE)
  }
  options(cnmarket.token = token)
  invisible(token)
}

#' @rdname cn_set_token
#' @export
cn_token <- function() {
  tok <- getOption("cnmarket.token")
  if (is.null(tok) || !nzchar(tok)) {
    tok <- Sys.getenv("TUSHARE_TOKEN", unset = "")
  }
  if (!nzchar(tok)) {
    stop(
      "\u672a\u914d\u7f6e Tushare token\u3002\u8bf7\u7528 cn_set_token(\"<\u4f60\u7684token>\") \u8bbe\u7f6e\uff0c",
      "\u6216\u8bbe\u7f6e\u73af\u5883\u53d8\u91cf TUSHARE_TOKEN\u3002",
      call. = FALSE
    )
  }
  tok
}

#' Configure the on-disk cache directory
#'
#' @param path Directory used to store cached responses. Created if missing.
#' @return `cn_set_cache_dir()` invisibly returns the normalised path;
#'   `cn_cache_dir()` returns the active directory (defaults to
#'   `tools::R_user_dir("cnmarket", "cache")`).
#' @examples
#' \dontrun{
#' cn_set_cache_dir("~/cnmarket_cache")
#' }
#' @export
cn_set_cache_dir <- function(path) {
  path <- normalizePath(path.expand(path), mustWork = FALSE)
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  options(cnmarket.cache_dir = path)
  invisible(path)
}

#' @rdname cn_set_cache_dir
#' @export
cn_cache_dir <- function() {
  d <- getOption("cnmarket.cache_dir")
  if (is.null(d)) {
    d <- tools::R_user_dir("cnmarket", which = "cache")
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    options(cnmarket.cache_dir = d)
  }
  d
}

#' Enable or disable the on-disk cache
#'
#' @param on `TRUE`/`FALSE` to set, or `NULL` (default) to query the current
#'   setting. Caching is enabled by default.
#' @return The (possibly updated) cache state as a length-one logical.
#' @examples
#' cn_use_cache()
#' @export
cn_use_cache <- function(on = NULL) {
  if (is.null(on)) return(isTRUE(getOption("cnmarket.cache", TRUE)))
  options(cnmarket.cache = isTRUE(on))
  invisible(isTRUE(on))
}

#' Base URL of the Tushare API
#' @keywords internal
cn_base_url <- function() {
  getOption("cnmarket.base_url", "https://api.tushare.pro")
}
