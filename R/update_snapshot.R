#' Update a historical table
#'
#' @description
#'   `update_snapshots` makes it easy to create and update a historical data table on a remote (SQL) server.
#'   The function takes the data (`.data`) as it looks on a given point in time (`timestamp`) and then updates
#'   (or creates) an remote table identified by `db_table`.
#'   This update only stores the changes between the new data (`.data`) and the data currently stored on the remote.
#'   This way, the data can be reconstructed as it looked at any point in time while taking as little space as possible.
#'
#'   See `vignette("basic-principles")` for further introduction to the function.
#'
#' @template .data
#' @template conn
#' @template db_table
#' @param timestamp (`POSIXct(1)`, `Date(1)`, or `character(1)`)\cr
#'   The timestamp describing the data being processed (not the current time).
#' @template filters
#' @param message (`character(1)`)\cr
#'   A message to add to the log-file (useful for supplying metadata to the log).
#' @param tic (`POSIXct(1)`)\cr
#'   A timestamp when computation began. If not supplied, it will be created at call-time
#'   (used to more accurately convey the runtime of the update process).
#' @param logger (`Logger(1)`)\cr
#'   A configured logging object. If none is given, one is initialized with default arguments.
#' @param enforce_chronological_order (`logical(1)`)\cr
#'   Are updates allowed if they are chronologically earlier than latest update?
#' @return
#'   No return value, called for side effects.
#' @examplesIf requireNamespace("RSQLite", quietly = TRUE)
#'   conn <- get_connection()
#'
#'   data <- dplyr::copy_to(conn, mtcars)
#'
#'   # Copy the first 3 records
#'   update_snapshot(
#'     head(data, 3),
#'     conn = conn,
#'     db_table = "test.mtcars",
#'     timestamp = Sys.time()
#'   )
#'
#'   # Update with the first 5 records
#'   update_snapshot(
#'     head(data, 5),
#'     conn = conn,
#'     db_table = "test.mtcars",
#'     timestamp = Sys.time()
#'   )
#'
#'   dplyr::tbl(conn, "test.mtcars")
#'
#'   close_connection(conn)
#' @seealso filter_keys
#' @importFrom rlang .data
#' @export
update_snapshot <- function(.data, conn, db_table, timestamp, filters = NULL, message = NULL, tic = Sys.time(),
                            logger = NULL,
                            enforce_chronological_order = TRUE) {

  # Check arguments
  checkmate::assert_class(.data, "tbl_dbi")
  checkmate::assert_class(conn, "DBIConnection")
  assert_dbtable_like(db_table)
  assert_timestamp_like(timestamp)
  checkmate::assert_class(filters, "tbl_dbi", null.ok = TRUE)
  checkmate::assert_character(message, null.ok = TRUE)
  assert_timestamp_like(tic)
  checkmate::assert_multi_class(logger, "Logger", null.ok = TRUE)
  checkmate::assert_logical(enforce_chronological_order)

  # Retrieve Id from any valid db_table inputs to correctly create a missing table
  db_table_id <- id(db_table, conn)

  if (table_exists(conn, db_table_id)) {
    # Obtain a lock on the table
    if (!lock_table(conn, db_table_id, schema = get_schema(db_table_id))) {
      stop("A lock could not be obtained on the table")
    }

    db_table <- dplyr::tbl(conn, db_table_id)
  } else {
    db_table <- create_table(dplyr::collect(utils::head(.data, 0)), conn, db_table_id, temporary = FALSE)
  }

  # Initialize logger
  if (is.null(logger)) {
    logger <- Logger$new(
      db_table = db_table_id,
      log_conn = conn,
      timestamp = timestamp,
      start_time = tic
    )
  }

  logger$log_info("Started", tic = tic) # Use input time in log

  # Add message to log (if given)
  if (!is.null(message)) {
    logger$log_to_db(message = message)
    logger$log_info("Message:", message, tic = tic)
  }


  # Opening checks
  if (!is.historical(db_table)) {

    # Release table lock
    unlock_table(conn, db_table_id, get_schema(db_table_id))

    logger$log_to_db(success = FALSE, end_time = !!db_timestamp(tic, conn))
    logger$log_error("Table does not seem like a historical table", tic = tic) # Use input time in log
  }

  if (!setequal(colnames(.data),
                colnames(dplyr::select(db_table, !c("checksum", "from_ts", "until_ts"))))) {

    # Release table lock
    unlock_table(conn, db_table_id, get_schema(db_table_id))

    logger$log_to_db(success = FALSE, end_time = !!db_timestamp(tic, conn))
    logger$log_error(
      "Columns do not match!\n",
      "Table columns:\n",
      toString(colnames(dplyr::select(db_table, !tidyselect::any_of(c("checksum", "from_ts", "until_ts"))))),
      "\nInput columns:\n",
      toString(colnames(.data)),
      tic = tic # Use input time in log
    )
  }

  logger$log_info("Parsing data for table", as.character(db_table_id), "started", tic = tic) # Use input time in log
  logger$log_info("Given timestamp for table is", timestamp, tic = tic) # Use input time in log

  # Check for current update status
  db_latest <- db_table |>
    dplyr::summarize(max(.data$from_ts, na.rm = TRUE)) |>
    dplyr::pull() |>
    as.character() |>
    max("1900-01-01 00:00:00", na.rm = TRUE)

  # Convert timestamp to character to prevent inconsistent R behavior with date/timestamps
  timestamp <- strftime(timestamp)
  db_latest <- strftime(db_latest)

  if (enforce_chronological_order && timestamp < db_latest) {

    # Release the table lock
    unlock_table(conn, db_table_id, get_schema(db_table_id))

    logger$log_to_db(success = FALSE, end_time = !!db_timestamp(tic, conn))
    logger$log_error("Given timestamp", timestamp, "is earlier than latest",
                     "timestamp in table:", db_latest, tic = tic) # Use input time in log
  }

  # Compute .data immediately to reduce runtime and compute checksum
  .data <- .data |>
    dplyr::ungroup() |>
    filter_keys(filters) |>
    dplyr::select(colnames(dplyr::select(db_table, !tidyselect::any_of(c("checksum", "from_ts", "until_ts")))))

  # Copy to the target connection if needed
  if (!identical(dbplyr::remote_con(.data), conn)) {
    .data <- dplyr::copy_to(conn, .data, name = unique_table_name())
    defer_db_cleanup(.data)
  }

  # Once we ensure .data is on the same connection as the target, we compute the checksums
  .data <- dplyr::compute(digest_to_checksum(.data, col = "checksum"))
  defer_db_cleanup(.data)

  # Apply filter to current records
  if (!is.null(filters) && !identical(dbplyr::remote_con(filters), conn)) {
    filters <- dplyr::copy_to(conn, filters, name = unique_table_name())
    defer_db_cleanup(filters)
  }
  db_table <- filter_keys(db_table, filters)

  # Determine the next timestamp in the data (can be NA if none is found)
  next_timestamp <- min(db_table |>
                          dplyr::filter(.data$from_ts  > timestamp) |>
                          dplyr::summarize(next_timestamp = min(.data$from_ts, na.rm = TRUE)) |>
                          dplyr::pull("next_timestamp"),
                        db_table |>
                          dplyr::filter(.data$until_ts > timestamp) |>
                          dplyr::summarize(next_timestamp = min(.data$until_ts, na.rm = TRUE)) |>
                          dplyr::pull("next_timestamp")) |>
    strftime()

  # Consider only records valid at timestamp (and apply the filter if present)
  db_table <- slice_time(db_table, timestamp)

  # Count open rows at timestamp
  nrow_open <- nrow(db_table)


  # Select only data with no until_ts and with different values in any fields
  logger$log_info("Deactivating records")
  if (nrow_open > 0) {
    to_remove <- dplyr::setdiff(dplyr::select(db_table, "checksum"),
                                dplyr::select(.data, "checksum")) |>
      dplyr::compute() # Something has changed in dbplyr (2.2.1) that makes this compute needed.
    # Code that takes 20 secs with can be more than 30 minutes to compute without...
    defer_db_cleanup(to_remove)

    nrow_to_remove <- nrow(to_remove)

    # Determine from_ts and checksum for the records we need to deactivate
    to_remove <- to_remove |>
      dplyr::left_join(dplyr::select(db_table, "from_ts", "checksum"), by = "checksum") |>
      dplyr::mutate(until_ts = !!db_timestamp(timestamp, conn))

  } else {
    nrow_to_remove <- 0
  }
  logger$log_info("After to_remove")



  to_add <- dplyr::setdiff(.data, dplyr::select(db_table, colnames(.data))) |>
    dplyr::mutate(from_ts  = !!db_timestamp(timestamp, conn),
                  until_ts = !!db_timestamp(next_timestamp, conn))

  nrow_to_add <- nrow(to_add)
  logger$log_info("After to_add")



  if (nrow_to_remove > 0) {
    dplyr::rows_update(x = dplyr::tbl(conn, db_table_id),
                       y = to_remove,
                       by = c("checksum", "from_ts"),
                       in_place = TRUE,
                       unmatched = "ignore")
  }

  logger$log_to_db(n_deactivations = nrow_to_remove) # Logs contains the aggregate number of added records on the day
  logger$log_info("Deactivate records count:", nrow_to_remove)
  logger$log_info("Adding new records")

  if (nrow_to_add > 0) {
    dplyr::rows_append(x = dplyr::tbl(conn, db_table_id), y = to_add, in_place = TRUE)
  }

  logger$log_to_db(n_insertions = nrow_to_add)
  logger$log_info("Insert records count:", nrow_to_add)


  # If several updates come in a single day, some records may have from_ts = until_ts.
  # We remove these records here
  redundant_rows <- dplyr::tbl(conn, db_table_id) |>
    dplyr::filter(.data$from_ts == .data$until_ts) |>
    dplyr::select("checksum", "from_ts")
  nrow_redundant <- nrow(redundant_rows)

  if (nrow_redundant > 0) {
    dplyr::rows_delete(dplyr::tbl(conn, db_table_id),
                       redundant_rows,
                       by = c("checksum", "from_ts"),
                       in_place = TRUE, unmatched = "ignore")
    logger$log_info("Doubly updated records removed:", nrow_redundant)
  }

  # If chronological order is not enforced, some records may be split across several records
  # checksum is the same, and from_ts / until_ts are continuous
  # We collapse these records here
  if (!enforce_chronological_order) {
    redundant_rows <- dplyr::tbl(conn, db_table_id) |>
      filter_keys(filters)

    redundant_rows <- dplyr::inner_join(
      redundant_rows,
      redundant_rows |> dplyr::select("checksum", "from_ts", "until_ts"),
      suffix = c("", ".p"),
      sql_on = '"RHS"."checksum" = "LHS"."checksum" AND "LHS"."until_ts" = "RHS"."from_ts"'
    ) |>
      dplyr::select(!"checksum.p")

    redundant_rows_to_delete <- redundant_rows |>
      dplyr::transmute(.data$checksum, from_ts = .data$from_ts.p) |>
      dplyr::compute()
    defer_db_cleanup(redundant_rows_to_delete)

    redundant_rows_to_update <- redundant_rows |>
      dplyr::transmute(.data$checksum, from_ts = .data$from_ts, until_ts = .data$until_ts.p) |>
      dplyr::compute()
    defer_db_cleanup(redundant_rows_to_update)

    if (nrow(redundant_rows_to_delete) > 0) {
      dplyr::rows_delete(x = dplyr::tbl(conn, db_table_id),
                         y = redundant_rows_to_delete,
                         by = c("checksum", "from_ts"),
                         in_place = TRUE,
                         unmatched = "ignore")
    }

    if (nrow(redundant_rows_to_update) > 0) {
      dplyr::rows_update(x = dplyr::tbl(conn, db_table_id),
                         y = redundant_rows_to_update,
                         by = c("checksum", "from_ts"),
                         in_place = TRUE,
                         unmatched = "ignore")
      logger$log_info("Continous records collapsed:", nrow(redundant_rows_to_update))
    }

  }

  toc <- Sys.time()
  logger$finalize_db_entry()
  logger$log_info("Finished processing for table", as.character(db_table_id), tic = toc)

  # Release table lock
  unlock_table(conn, db_table_id, get_schema(db_table_id))

  return(NULL)
}
