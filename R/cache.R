# Build a filesystem-safe cache key from arbitrary components.
cn_key <- function(...) {
  parts <- as.character(unlist(list(...), use.names = FALSE))
  parts <- gsub("[^A-Za-z0-9._-]", "_", parts)
  paste(parts, collapse = "__")
}

# Read a cached value, or NULL on a miss.
cn_cache_read <- function(key) {
  path <- file.path(cn_cache_dir(), paste0(key, ".rds"))
  if (file.exists(path)) readRDS(path) else NULL
}

# Write a value to the cache.
cn_cache_write <- function(key, value) {
  saveRDS(value, file.path(cn_cache_dir(), paste0(key, ".rds")))
  invisible(value)
}

# Evaluate `expr` through the cache. `expr` is lazy: on a cache hit the
# underlying API request is never performed.
cn_with_cache <- function(key, expr, refresh = FALSE) {
  if (!cn_use_cache() || isTRUE(refresh)) return(expr)
  hit <- cn_cache_read(key)
  if (!is.null(hit)) return(hit)
  cn_cache_write(key, expr)
  expr
}

#' Clear the on-disk cache
#'
#' Removes every `.rds` file under [cn_cache_dir()].
#'
#' @return Invisibly, the number of files removed.
#' @examples
#' \dontrun{
#' cn_cache_clear()
#' }
#' @export
cn_cache_clear <- function() {
  files <- list.files(cn_cache_dir(), pattern = "\\.rds$", full.names = TRUE)
  if (length(files)) file.remove(files)
  invisible(length(files))
}
