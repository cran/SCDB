## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup, echo = FALSE, results = 'hide'------------------------------------
suppressPackageStartupMessages(library(SCDB))

# Setup conn to be used for examples
conn <- get_connection(drv = RSQLite::SQLite())

# Setup log table in temporary db
SCDB::create_logs_if_missing("logs", conn)
options("SCDB.log_table_id" = "logs")

# Use a wrapper for update_snapshot which uses a quiet Logger
if (!"update_snapshot" %in% ls(envir = globalenv())) {
  logger <- Logger$new(output_to_console = FALSE, log_table_id = "logs", log_conn = conn)
  update_snapshot <- function(...) return(invisible(SCDB::update_snapshot(logger = logger, ...)))
}

# Setup example_data table in conn
example_data <-
  dplyr::copy_to(conn,
                 dplyr::transmute(datasets::mtcars, car = rownames(mtcars), hp),
                 name = "example_data",
                 overwrite = TRUE)

## ----example_data-------------------------------------------------------------
library(SCDB)
if (!exists("conn")) conn <- get_connection(drv = RSQLite::SQLite())

example_data <- dplyr::tbl(conn, DBI::Id(table = "example_data"))
example_data

## ----example_1----------------------------------------------------------------
data <- head(example_data, 3)

update_snapshot(.data = data,
                conn = conn,
                db_table = "mtcars", # the name of the DB table to store the data in
                timestamp = as.POSIXct("2020-01-01 11:00:00"))

## ----example_1_results--------------------------------------------------------
get_table(conn, "mtcars")

get_table(conn, "mtcars", include_slice_info = TRUE)

## ----example_2----------------------------------------------------------------
# Let's say that the next day, our data set is now the first 5 of our example data
data <- head(example_data, 5)

update_snapshot(.data = data,
                conn = conn,
                db_table = "mtcars", # the name of the DB table to store the data in
                timestamp = as.POSIXct("2020-01-02 12:00:00"))

## ----example_2_results_a------------------------------------------------------
get_table(conn, "mtcars")

get_table(conn, "mtcars", include_slice_info = TRUE)

## ----example_2_results_b------------------------------------------------------
get_table(conn, "mtcars", slice_ts = "2020-01-01 11:00:00")

## ----example_3----------------------------------------------------------------
data <- head(example_data, 5) |>
  dplyr::mutate(hp = ifelse(car == "Mazda RX4", hp / 2, hp))

update_snapshot(.data = data,
                conn = conn,
                db_table = "mtcars", # the name of the DB table to store the data in
                timestamp = as.POSIXct("2020-01-03 10:00:00"))

## ----example_3_results_a------------------------------------------------------
get_table(conn, "mtcars")

## ----example_3_results_b------------------------------------------------------
get_table(conn, "mtcars", slice_ts = NULL)

