## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----library------------------------------------------------------------------
library(SCDB)

## ----setup, echo = FALSE, results = "hide", eval = rlang::is_installed("duckdb") && R.version$major >= "4"----

# Setup conn to be used for examples
conn_primary <- get_connection(duckdb::duckdb())
conn_secondary <- conn_primary

# Use a wrapper for update_snapshot which uses LoggerNull to suppress all logging
if (!"update_snapshot" %in% ls(envir = globalenv())) {
  update_snapshot <- function(...) {
    return(SCDB::update_snapshot(logger = SCDB::LoggerNull$new(), ...))
  }
}

# Setup example_data table in conn
example_data <- dplyr::copy_to(
  conn_primary,
  dplyr::transmute(datasets::mtcars, car = rownames(mtcars), hp),
  name = "example_data",
  overwrite = TRUE
)

## ----example_data, eval = FALSE-----------------------------------------------
# conn_primary   <- get_connection(...)
# conn_secondary <- get_connection(...)

## ----example_data_hidden, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
example_data <- dplyr::tbl(conn_primary, DBI::Id(table = "example_data"))
example_data

## ----example_1, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
data <- head(example_data, 3)

update_snapshot(
  .data = data,
  conn = conn_primary,
  db_table = "mtcars", # the name of the DB table to store the data in
  timestamp = "2020-01-01 11:00:00"
)

## ----example_2, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
# Let's say that the next day, our data set is now the first 5 of our example data
data <- head(example_data, 5)

update_snapshot(
  .data = data,
  conn = conn_primary,
  db_table = "mtcars", # the name of the DB table to store the data in
  timestamp = "2020-01-02 12:00:00"
)

## ----example_2_results_a, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
get_table(conn_primary, "mtcars", slice_ts = NULL)

## ----delta_1_export, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
delta_1 <- delta_export(
  conn = conn_primary,
  db_table = "mtcars",
  timestamp_from = "2020-01-01 11:00:00"
)

delta_1

## ----delta_1_load, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
delta_load(
  conn = conn_secondary,
  db_table = "mtcars_firewalled",
  delta = delta_1
)

get_table(conn_secondary, "mtcars_firewalled", slice_ts = NULL)

## ----example_3, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
data <- head(example_data, 5) %>%
  dplyr::mutate(hp = ifelse(car == "Mazda RX4", hp / 2, hp))

update_snapshot(
  .data = data,
  conn = conn_primary,
  db_table = "mtcars", # the name of the DB table to store the data in
  timestamp = "2020-01-03 13:00:00"
)

## ----example_4, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
data <- head(example_data, 7) %>%
  dplyr::mutate(hp = ifelse(car == "Mazda RX4", hp / 2, hp))

update_snapshot(
  .data = data,
  conn = conn_primary,
  db_table = "mtcars", # the name of the DB table to store the data in
  timestamp = "2020-01-04 14:00:00"
)

## ----example_4_results_a, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
get_table(conn_primary, "mtcars", slice_ts = NULL)

## ----delta_2_export, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
delta_2 <- delta_export(
  conn = conn_primary,
  db_table = "mtcars",
  timestamp_from = "2020-01-03 13:00:00"
)

delta_2

## ----delta_2_load, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
delta_load(
  conn = conn_secondary,
  db_table = "mtcars_firewalled",
  delta = delta_2
)

get_table(conn_secondary, "mtcars_firewalled", slice_ts = NULL)

## ----delta_batch_export, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
delta_batch_1 <- delta_export(
  conn = conn_primary,
  db_table = "mtcars",
  timestamp_from  = "2020-01-01 11:00:00",
  timestamp_until = "2020-01-03 13:00:00"
)

delta_batch_2 <- delta_export(
  conn = conn_primary,
  db_table = "mtcars",
  timestamp_from  = "2020-01-03 13:00:00"
)

## ----delta_batch_load, eval = rlang::is_installed("duckdb") && R.version$major >= "4"----
delta_load(
  conn = conn_secondary,
  db_table = "mtcars_batch",
  delta = list(delta_batch_1, delta_batch_2)
)

get_table(conn_secondary, "mtcars_batch", slice_ts = NULL)

