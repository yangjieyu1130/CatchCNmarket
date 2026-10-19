#' Call a Tushare API endpoint
#'
#' Low-level wrapper around the Tushare HTTP API
#' (`https://api.tushare.pro`). It posts `api_name`/`token`/`params`/`fields`,
#' checks the returned `code`, and converts the `data.fields` + `data.items`
#' payload into a tidy tibble with numeric columns auto-detected.
#'
#' @param api_name Endpoint name, e.g. `"daily"`.
#' @param params Named list of endpoint parameters, e.g.
#'   `list(ts_code = "600519.SH", start_date = "20240101")`.
#' @param fields Comma-separated field whitelist (empty string = all fields).
#' @return A [tibble][tibble::tibble-package]. Returns a zero-row tibble with
#'   the requested columns when the endpoint yields no data.
#' @keywords internal
cn_api <- function(api_name, params = list(), fields = "") {
  body <- list(
    api_name = api_name,
    token = cn_token(),
    params = params,
    fields = fields
  )
  req <- httr2::request(cn_base_url()) |>
    httr2::req_user_agent("cnmarket (https://github.com/cnmarket)") |>
    httr2::req_body_json(body, auto_unbox = TRUE) |>
    httr2::req_timeout(30) |>
    httr2::req_retry(max_tries = 3)
  resp <- httr2::req_perform(req)
  parsed <- httr2::resp_body_json(resp, simplifyVector = FALSE)

  if (!identical(as.integer(parsed$code), 0L)) {
    stop(
      sprintf(
        "Tushare 接口 %s 返回错误（code=%s）：%s",
        api_name, parsed$code, parsed$msg %||% "未知错误"
      ),
      call. = FALSE
    )
  }
  data <- parsed$data
  if (is.null(data)) {
    stop(sprintf("Tushare 接口 %s 未返回 data 字段。", api_name), call. = FALSE)
  }
  fields <- as.character(unlist(data$fields))
  items <- data$items

  if (length(items) == 0L) {
    empty <- stats::setNames(
      replicate(length(fields), character(0), simplify = FALSE), fields
    )
    return(tibble::as_tibble(empty))
  }

  mat <- t(vapply(
    items,
    function(row) {
      vapply(
        seq_along(fields),
        function(j) {
          val <- row[[j]]
          if (is.null(val) || length(val) == 0L) NA_character_ else as.character(val)
        },
        character(1)
      )
    },
    character(length(fields))
  ))

  df <- as.data.frame(mat, stringsAsFactors = FALSE)
  names(df) <- fields
  cn_auto_type(tibble::as_tibble(df))
}
