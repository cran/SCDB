#' Combine any number of tables, where each has their own time axis of validity
#'
#' @description
#'   The function "interlaces" the queries and combines their validity time axes (valid_from and valid_until)
#'   onto a single time axis.
#'
#' @param tables (`list`(`tbl_dbi(1)`))\cr
#'   The historical tables to combine.
#' @param by (`character()`)\cr
#'   The variable to merge by.
#' @param colnames (`named list()`)\cr
#'   If the time axes of validity is not called "valid_to" and "valid_until" inside each `tbl_dbi`,
#'   you can specify their names by supplying the arguments as a list:
#'   e.g. c(t1.from = "\<colname\>", t2.until = "\<colname\>").
#'   colnames must be named in same order as as given in tables (i.e. t1, t2, t3, ...).
#' @return
#'   The combination of input queries with a single, interlaced valid_from / valid_until time axis.
#' @examplesIf requireNamespace("RSQLite", quietly = TRUE)
#'   conn <- get_connection()
#'
#'   t1 <- data.frame(key = c("A", "A", "B"),
#'                    obs_1   = c(1, 2, 2),
#'                    valid_from  = as.Date(c("2021-01-01", "2021-02-01", "2021-01-01")),
#'                    valid_until = as.Date(c("2021-02-01", "2021-03-01", NA))) |>
#'     dplyr::copy_to(conn, df = _, name = "t1")
#'
#'   t2 <- data.frame(key = c("A", "B"),
#'                    obs_2 = c("a", "b"),
#'                    valid_from  = as.Date(c("2021-01-01", "2021-01-01")),
#'                    valid_until = as.Date(c("2021-04-01", NA))) |>
#'     dplyr::copy_to(conn, df = _, name = "t2")
#'
#'   interlace(list(t1, t2), by = "key")
#'
#'   close_connection(conn)
#' @return          The combination of input queries with a single, interlaced
#'                  valid_from / valid_until time axis
#' @importFrom rlang .data
#' @export
interlace <- function(tables, by = NULL, colnames = NULL) {
  # Check arguments
  coll <- checkmate::makeAssertCollection()
  checkmate::assert_list(tables, types = c("tbl_dbi", "data.frame"), add = coll)
  checkmate::assert_character(by, null.ok = TRUE, add = coll)
  checkmate::assert_character(colnames, null.ok = TRUE, add = coll)
  checkmate::assert_character(names(colnames), pattern = r"{t\d+\.(from|until)}", null.ok = TRUE, add = coll)
  checkmate::reportAssertions(coll)


  # Check edge case
  if (length(tables) == 1) {
    return(purrr::pluck(tables, 1))
  }

  UseMethod("interlace", tables[[1]])
}

#' @export
interlace.tbl_sql <- function(tables, by = NULL, colnames = NULL) {

  # Parse inputs for colnames .from / .to columns
  from_cols <- seq_along(tables) |>
    purrr::map_chr(\(t) paste0("t", t, ".from")) |>
    purrr::map_chr(\(col) ifelse(col %in% names(colnames), colnames[col], "valid_from"))

  until_cols <- seq_along(tables) |>
    purrr::map_chr(\(t) paste0("t", t, ".until")) |>
    purrr::map_chr(\(col) ifelse(col %in% names(colnames), colnames[col], "valid_until"))


  # Rename valid_from / valid_until columns
  tables <- purrr::map2(tables, from_cols,
                        \(table, from_col)  table |> dplyr::rename(valid_from  = !!from_col))
  tables <- purrr::map2(tables, until_cols,
                        \(table, until_col) table |> dplyr::rename(valid_until = !!until_col))


  # Get all changes to valid_from / valid_until
  q1 <- tables |> purrr::map(\(table) {
    table |>
      dplyr::select(tidyselect::all_of(by), "valid_from")
  })
  q2 <- tables |>
    purrr::map(\(table) {
      table |>
        dplyr::select(tidyselect::all_of(by), "valid_until") |>
        dplyr::rename(valid_from = "valid_until")
    })
  t <- dplyr::union(q1, q2) |> purrr::reduce(dplyr::union)

  # Sort and find valid_until in the combined validities
  t <- t |>
    dplyr::group_by(dplyr::across(tidyselect::all_of(by))) |>
    dbplyr::window_order(.data$valid_from) |>
    dplyr::mutate(.row = dplyr::if_else(is.na(.data$valid_from),  # Some database backends considers NULL to be the
                                        dplyr::n(),               # smallest, so we need to adjust for that
                                        dplyr::row_number() - ifelse(is.na(dplyr::first(.data$valid_from)), 1, 0)))     # nolint: redundant_ifelse_linter

  t <- dplyr::left_join(t |>
                          dplyr::filter(.data$.row < dplyr::n()),
                        t |>
                          dplyr::filter(.data$.row > 1) |>
                          dplyr::mutate(.row = .data$.row - 1) |>
                          dplyr::rename("valid_until" = "valid_from"),
                        by = c(by, ".row")) |>
    dplyr::select(!".row") |>
    dplyr::ungroup() |>
    dplyr::compute(name = unique_table_name())


  # Merge data onto the new validities using non-equi joins
  joiner <- \(.data, table) {
    .data |>
      dplyr::left_join(table,
                       suffix = c("", ".tmp"),
                       sql_on = paste0('"LHS"."', by, '" = "RHS"."', by, '" AND
                                      "LHS"."valid_from"  >= "RHS"."valid_from" AND
                                     ("LHS"."valid_until" <= "RHS"."valid_until" OR "RHS"."valid_until" IS NULL)')) |>
      dplyr::select(!tidyselect::ends_with(".tmp")) |>
      dplyr::relocate(tidyselect::starts_with("valid_"), .after = tidyselect::everything())
  }

  return(purrr::reduce(tables, joiner, .init = t))
}

#' interlace_sql
#'
#' @rdname interlace
#' @description
#'  `interlace_sql()` is deprecated in favor of `interlace()`
#' @export
interlace_sql <- function(tables, by = NULL, colnames = NULL) {
  # Lifecycle deprecate function
  lifecycle::deprecate_soft("0.4.0", "interlace_sql()", "interlace()")
  interlace(tables, by, colnames)
}
