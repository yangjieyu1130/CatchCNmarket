`%||%` <- function(x, y) if (is.null(x)) y else x

# Columns that must never be auto-coerced to numeric (identifiers / labels).
cn_id_cols <- c(
  "ts_code", "symbol", "code", "exchange", "market", "name", "area",
  "industry", "list_status", "is_hs", "cal_date", "pretrade_date", "board"
)

# Normalise a date-ish input to the YYYYMMDD string Tushare expects.
cn_ymd <- function(x) {
  if (inherits(x, "Date") || inherits(x, "POSIXt")) return(format(x, "%Y%m%d"))
  if (is.numeric(x)) x <- format(x, scientific = FALSE)
  x <- gsub("[^0-9]", "", as.character(x))
  if (!nzchar(x) || nchar(x) != 8L) {
    stop("日期应为 YYYYMMDD / YYYY-MM-DD 或 Date 对象。", call. = FALSE)
  }
  x
}

# Coerce character columns that look purely numeric into numeric, leaving
# identifier and date columns as character.
cn_auto_type <- function(df) {
  for (nm in names(df)) {
    if (nm %in% cn_id_cols || grepl("date", nm, ignore.case = TRUE)) next
    x <- df[[nm]]
    if (!is.character(x)) next
    y <- suppressWarnings(as.numeric(x))
    if (!any(is.na(y) & !is.na(x))) df[[nm]] <- y
  }
  df
}

# Length of the current run, resetting on FALSE (e.g. consecutive limit-ups).
cn_streak <- function(x) {
  x <- as.logical(x)
  x[is.na(x)] <- FALSE
  n <- length(x)
  if (n == 0L) return(integer(0))
  out <- integer(n)
  run <- 0L
  for (i in seq_len(n)) {
    run <- if (x[i]) run + 1L else 0L
    out[i] <- run
  }
  out
}
