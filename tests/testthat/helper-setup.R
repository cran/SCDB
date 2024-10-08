#' Get a list of data base connections to test on
#' @return
#'   If you run your tests locally, it returns a list of connections corresponding to conn_list and conn_args
#'   If you run your tests on GitHub, it return a list of connection corresponding to the environment variables.
#'   i.e. the GitHub workflows will configure the testing back ends
#' @importFrom rlang `:=`
#' @noRd
get_test_conns <- function() {

  # Locally use rlang's (without this, it may not be bound)
  `:=` <- rlang::`:=`

  # Check if we run remotely
  running_locally <- !identical(Sys.getenv("CI"), "true")

  # Define list of connections to check
  if (running_locally) {

    # Define our local connection backends
    conn_list <- list(
      # Backend string = package::function
      "SQLite"              = "RSQLite::SQLite",
      "SQLite - w. schemas" = "RSQLite::SQLite"
    )

    # Define our local connection arguments
    conn_args <- list(
      # Backend string = list(named args)
      "SQLite"              = list(dbname = file.path(tempdir(), "SQLite.SQLite")),
      "SQLite - w. schemas" = list(dbname = file.path(tempdir(), "SQLite_schemas.SQLite"))
    )

    # Define post connection commands to run
    conn_post_connect <- list(
      # Backend string = list(named args)
      "SQLite - w. schemas" = list(
        paste0("ATTACH '", file.path(tempdir(), "SQLite_test.SQLite"), "' AS 'test'"),
        paste0("ATTACH '", file.path(tempdir(), "SQLite_test_one.SQLite"), "' AS 'test.one'")
      )
    )

  } else {

    # Use the connection configured by the remote
    conn_list <- tibble::lst(!!Sys.getenv("BACKEND") := !!Sys.getenv("BACKEND_DRV"))                                    # nolint: object_name_linter

    # Use the connection configured by the remote
    conn_args <- tibble::lst(!!Sys.getenv("BACKEND") := Sys.getenv("BACKEND_ARGS")) |>                                  # nolint: object_name_linter
      purrr::discard(~ identical(., "")) |>
      purrr::map(~ eval(parse(text = .)))

    # Use the connection configured by the remote
    conn_post_connect <- tibble::lst(!!Sys.getenv("BACKEND") := Sys.getenv("BACKEND_POST_CONNECT")) |>                  # nolint: object_name_linter
      purrr::discard(~ identical(., "")) |>
      purrr::map(~ eval(parse(text = .)))

  }

  # Early return if no connections are defined
  if (length(conn_list) == 0) {
    return(list())
  }

  # Parse any conn_args stored in CONN_ARGS_JSON
  conn_args_json <- jsonlite::fromJSON(Sys.getenv("CONN_ARGS_JSON", unset = "{}"))

  # Combine all arguments
  backends <- unique(c(names(conn_list), names(conn_args), names(conn_args_json)))
  conn_args <- backends |>
    purrr::map(~ c(purrr::pluck(conn_args, .), purrr::pluck(conn_args_json, .))) |>
    stats::setNames(backends)


  get_driver <- function(x = character(), ...) {                                                                        # nolint: object_usage_linter
    if (!grepl(".*::.*", x)) stop("Package must be specified with namespace (e.g. RSQLite::SQLite)!\n",
                                  "Received: ", x)
    parts <- strsplit(x, "::", fixed = TRUE)[[1]]

    # Skip unavailable packages
    if (!rlang::is_installed(parts[1])) {
      message("Library ", parts[1], " not available!")
      return(NULL)
    }

    return(getExportedValue(parts[1], parts[2])())
  }

  # Check all conn_args have associated entry in conn_list
  checkmate::assert_subset(names(conn_args), names(conn_list))

  # Open connections
  drivers <- names(conn_list) |>
    purrr::map(~ do.call(get_driver, list(x = purrr::pluck(conn_list, .)))) |>
    stats::setNames(names(conn_list)) |>
    purrr::discard(is.null)

  test_conns <- names(drivers) |>
    purrr::map(~ do.call(SCDB::get_connection, c(list(drv = purrr::pluck(drivers, .)), purrr::pluck(conn_args, .)))) |>
    stats::setNames(names(drivers)) |>
    purrr::discard(is.null)

  # Run post_connect commands on the connections
  purrr::walk2(test_conns, names(test_conns),
               \(conn, conn_name) purrr::walk(purrr::pluck(conn_post_connect, conn_name), ~ DBI::dbExecute(conn, .)))

  # Shutdown drivers that needs it
  drivers |>
    purrr::keep(~ inherits(., "duckdb_driver")) |>
    purrr::walk(~ duckdb::duckdb_shutdown(.))

  # Inform the user about the tested back ends:
  msg <- paste(sep = "\n",
    "#####",
    "Following backends will be tested:",
    paste("  ", names(test_conns), collapse = "\n"),
    "####"
  )

  # Message the user only once within this session
  rlang::inform(
    message = msg,
    .frequency = "once",
    .frequency_id = msg
  )

  return(test_conns)
}
