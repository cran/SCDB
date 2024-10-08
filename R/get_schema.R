#' Get the current schema/catalog of a database-related objects
#'
#' @name get_schema
#' @param obj (`DBIConnection(1)`, `tbl_dbi(1)`, `Id(1)`)\cr
#'   The object from which to retrieve a schema/catalog.
#' @param temporary (`logical(1)`) \cr
#'   Should the reference be to the temporary schema/catalog?
#' @param ... Further arguments passed to methods.
#' @return
#'   The schema is extracted from `obj` depending on the type of input:
#'
#'   * For `get_schema.DBIConnection()`, the current schema of the connection if `temporary = FALSE`.
#'     See "Default schema" for more.
#'     If `temporary = TRUE`, the temporary schema of the connection is returned.
#'
#'   * For `get_schema.tbl_dbi()` the schema is determined via `id()`.
#'
#'   * For `get_schema.Id()`, the schema is extracted from the `Id` specification.
#'
#' @section Default schema:
#'
#'   In some backends, it is possible to modify settings so that when a schema is not explicitly stated in a query,
#'   the backend searches for the table in this schema by default.
#'   For Postgres databases, this can be shown with `SELECT CURRENT_SCHEMA()` (defaults to `public`) and modified with
#'   `SET search_path TO { schema }`.
#'
#'   For SQLite databases, a `temp` schema for temporary tables always exists as well as a `main` schema for permanent
#'   tables. Additional databases may be attached to the connection with a named schema, but as the attachment must be
#'   made after the connection is established, `get_schema` will never return any of these, as the default schema will
#'   always be `main`.
#'
#' @examplesIf requireNamespace("RSQLite", quietly = TRUE)
#'   conn <- get_connection()
#'
#'   dplyr::copy_to(conn, mtcars, name = "mtcars", temporary = FALSE)
#'
#'   get_schema(conn)
#'   get_schema(get_table(conn, id("mtcars", conn = conn)))
#'
#'   get_catalog(conn)
#'   get_catalog(get_table(conn, id("mtcars", conn = conn)))
#'
#'   close_connection(conn)
#' @export
get_schema <- function(obj, ...) {
  UseMethod("get_schema")
}

#' @export
get_schema.tbl_dbi <- function(obj,  ...) {
  return(purrr::pluck(id(obj), "name", "schema"))
}

#' @export
get_schema.Id <- function(obj,  ...) {
  return(purrr::pluck(obj@name, "schema"))
}

#' @export
#' @rdname get_schema
get_schema.PqConnection <- function(obj, temporary = FALSE,  ...) {
  if (temporary)  {
    temp_schema <- DBI::dbGetQuery(obj, "SELECT nspname FROM pg_namespace WHERE oid = pg_my_temp_schema();")$nspname

    # If no temporary tables have been created, the temp schema has not been determined yet and we create a temporary
    # table to force the schema to be determined.
    if (identical(temp_schema, character(0))) {
      temp_table_name <- unique_table_name()
      DBI::dbExecute(obj, glue::glue("CREATE TEMPORARY TABLE {temp_table_name}(a TEXT)"))
      temp_schema <- DBI::dbGetQuery(obj, "SELECT nspname FROM pg_namespace WHERE oid = pg_my_temp_schema();")$nspname
      DBI::dbExecute(obj, glue::glue("DROP TABLE {temp_table_name}"))
    }

    return(temp_schema)
  } else {
    return(DBI::dbGetQuery(obj, "SELECT CURRENT_SCHEMA()")$current_schema)
  }
}

#' @export
#' @rdname get_schema
get_schema.SQLiteConnection <- function(obj, temporary = FALSE,  ...) {
  if (temporary)  {
    return("temp")
  } else {
    return("main")
  }
}

#' @export
`get_schema.Microsoft SQL Server` <- function(obj, ...) {
  query <- paste("SELECT ISNULL((SELECT",
                 "COALESCE(default_schema_name, 'dbo') AS default_schema",
                 "FROM sys.database_principals",
                 "WHERE [name] = CURRENT_USER), 'dbo') default_schema")

  return(DBI::dbGetQuery(obj, query)$default_schema)
}

#' @export
get_schema.duckdb_connection <- function(obj,  ...) {
  return("main")
}

#' @export
get_schema.NULL <- function(obj, ...) {
  return(NULL)
}
