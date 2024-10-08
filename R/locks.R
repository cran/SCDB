# We have to manually import parallelly to get access to the un-exported pid_exists() function
#' @import parallelly
NULL


#' Sets, queries and removes locks for database tables
#'
#' @name db_locks
#' @description
#'   This set of function adds a simple locking system to database tables.
#'
#'   * `lock_table()` adds a record in the schema.locks table with the current time and R-session process id.
#'
#'   * `unlock_table()` removes records in the schema.locks table with the target table and the R-session process id.
#'
#'   When locking a table, the function will check for existing locks on the table and produce an error a lock is held
#'   by a process which no longer exists.
#'   In this case, the lock needs to be removed manually by removing the record from the lock table.
#'   In addition, the error implies that a table may have partial updates that needs to be manually rolled back.
#' @template conn
#' @param db_table (`character(1)`)\cr
#'   A specification of "schema.table" to modify lock for.
#' @param schema (`character(1)`)\cr
#'   The schema where the "locks" table should be created.
#' @param pid (`numeric(1)`)\cr
#'   The process id to remove the lock for.
#' @return
#'   * `lock_table()` returns the `TRUE` (`FALSE`) if the lock was (un)successfully added.
#'     If a lock exists for a non-active process, an error is thrown.
#'
#'   * `unlock_table()` returns `NULL` (called for side effects).
#' @examplesIf requireNamespace("RSQLite", quietly = TRUE)
#'   conn <- DBI::dbConnect(RSQLite::SQLite())
#'
#'   lock_table(conn, "test_table") # TRUE
#'
#'   unlock_table(conn, "test_table")
#'
#'   DBI::dbDisconnect(conn)
#' @export
lock_table <- function(conn, db_table, schema = NULL) {
  checkmate::assert_class(conn, "DBIConnection")
  assert_id_like(db_table)
  checkmate::assert_character(schema, null.ok = TRUE)

  # Determine lock table id
  db_lock_table_id <- id(paste(c(schema, "locks"), collapse = "."), conn)

  # Create lock table if missing
  if (!table_exists(conn, db_lock_table_id)) {
    dplyr::copy_to(
      conn,
      data.frame(
        "schema" = character(0),
        "table" = character(0),
        "user" = character(0),
        "lock_start" = numeric(0),
        "pid" = numeric(0)
      ),
      db_lock_table_id,
      temporary = FALSE
    )

    if (inherits(conn, "PqConnection")) { # PostgreSQL needs an index for rows_insert
      res <- DBI::dbSendQuery(
        conn,
        glue::glue(
          "ALTER TABLE {as.character(db_lock_table_id, explicit = TRUE)} ADD PRIMARY KEY (\"schema\", \"table\");"
        )
      )
      DBI::dbClearResult(res)
    }
  }

  # Get a reference to the tables
  db_lock_table <- dplyr::tbl(conn, db_lock_table_id)
  db_table_id <- id(db_table, conn)

  # We then try to insert a lock, if none exists, our process ID (pid) will be assigned to the table-
  # If one already exists, our insert will fail.
  tryCatch(
    {
      lock <- dplyr::copy_to(
        conn,
        data.frame(
          "schema" = purrr::pluck(db_table_id, "name", "schema"),
          "table" = purrr::pluck(db_table_id, "name", "table"),
          "user" = Sys.info()[["user"]],
          "pid" = Sys.getpid(),
          "lock_start" = as.numeric(Sys.time())
        ),
        name = unique_table_name()
      )

      dplyr::rows_insert(db_lock_table, lock, by = c("schema", "table"), conflict = "ignore", in_place = TRUE)
    },
    error = function(e) {
      print(e$message)
    }
  )


  # Determine the owner of the lock
  lock_entry <- db_lock_table |>
    dplyr::filter(.data$schema == !!purrr::pluck(db_table_id, "name", "schema"),
                  .data$table  == !!purrr::pluck(db_table_id, "name", "table"))

  lock_owner_user <- dplyr::pull(lock_entry, "user")
  lock_owner_pid <- dplyr::pull(lock_entry, "pid")

  # Return early if we own the lock
  if (identical(as.integer(lock_owner_pid), Sys.getpid())) {
    return(TRUE)
  }

  # If we don't, check if the owner is still active
  if (!identical(lock_owner_pid, numeric(0))) {

    ## Detect stale lock
    # Attempt to get the un-exported pid_exists() from parallelly
    pid_exists <- tryCatch(
      utils::getFromNamespace("pid_exists", "parallelly"),
      error = function(e) FALSE
    )

    # If pid_exists is not available we cannot determine invalid locks and we throw an error to prevent infinite looping
    checkmate::assert_function(pid_exists)

    if (isFALSE(pid_exists(lock_owner_pid))) {
      stop(
        glue::glue(
          "Active lock (user = {lock_owner_user}, PID = {lock_owner_pid}) ",
          "on table {db_table_id} is no longer a valid PID! ",
          "Process likely crashed before completing."
        )
      )
    }

  }

  return(FALSE)
}


#' @rdname db_locks
#' @export
unlock_table <- function(conn, db_table, schema = NULL, pid = Sys.getpid()) {
  checkmate::assert_class(conn, "DBIConnection")
  assert_id_like(db_table)
  checkmate::assert_character(schema, null.ok = TRUE)

  # Determine lock table id
  db_lock_table_id <- id(paste(c(schema, "locks"), collapse = "."), conn)

  # Return early if lock table does not exist
  if (!table_exists(conn, db_lock_table_id)) {
    return(NULL)
  }

  # Get a reference to the table
  db_lock_table <- dplyr::tbl(conn, db_lock_table_id)

  # Delete locks matching  our process ID (pid) and the given db_table
  tryCatch(
    {
      db_table_id <- id(db_table, conn)

      lock <- dplyr::copy_to(
        conn,
        data.frame(
          "schema" = purrr::pluck(db_table_id, "name", "schema"),
          "table" = purrr::pluck(db_table_id, "name", "table"),
          "pid" = pid
        ),
        name = unique_table_name()
      )

      dplyr::rows_delete(db_lock_table, lock, by = c("schema", "table", "pid"), unmatched = "ignore", in_place = TRUE)
    },
    error = function(e) {
      print(e$message)
    }
  )

  return(NULL)
}
