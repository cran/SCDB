## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----library------------------------------------------------------------------
library(SCDB)

## ----setup, echo = FALSE, results = "hide", eval = rlang::is_installed("RSQLite")----

# Setup conn to be used for examples
conn <- get_connection()

# Use a wrapper for update_snapshot which uses LoggerNull to suppress all logging
if (!"update_snapshot" %in% ls(envir = globalenv())) {
  update_snapshot <- function(...) {
    return(SCDB::update_snapshot(logger = LoggerNull$new(), ...))
  }
}

# Setup example_data table in conn
example_data <-
  dplyr::copy_to(conn,
                 dplyr::transmute(datasets::mtcars, car = rownames(mtcars), hp),
                 name = "example_data",
                 overwrite = TRUE)

## ----example_data, eval = FALSE-----------------------------------------------
# conn <- get_connection()

## ----example_data_hidden, eval = requireNamespace("RSQLite", quietly = TRUE)----
example_data <- dplyr::tbl(conn, DBI::Id(table = "example_data"))
example_data

## ----example_1, eval = requireNamespace("RSQLite", quietly = TRUE)------------
data <- head(example_data, 3)

update_snapshot(
  .data = data,
  conn = conn,
  db_table = "mtcars", # the name of the DB table to store the data in
  timestamp = as.POSIXct("2020-01-01 11:00:00")
)

## ----example_1_results, eval = requireNamespace("RSQLite", quietly = TRUE)----
get_table(conn, "mtcars")

get_table(conn, "mtcars", include_slice_info = TRUE)

## ----example_2, eval = requireNamespace("RSQLite", quietly = TRUE)------------
# Let's say that the next day, our data set is now the first 5 of our example data
data <- head(example_data, 5)

update_snapshot(
  .data = data,
  conn = conn,
  db_table = "mtcars", # the name of the DB table to store the data in
  timestamp = as.POSIXct("2020-01-02 12:00:00")
)

## ----example_2_results_a, eval = requireNamespace("RSQLite", quietly = TRUE)----
get_table(conn, "mtcars")

get_table(conn, "mtcars", include_slice_info = TRUE)

## ----example_2_results_b, eval = requireNamespace("RSQLite", quietly = TRUE)----
get_table(conn, "mtcars", slice_ts = "2020-01-01 11:00:00")

## ----example_3, eval = requireNamespace("RSQLite", quietly = TRUE)------------
data <- head(example_data, 5) %>%
  dplyr::mutate(hp = ifelse(car == "Mazda RX4", hp / 2, hp))

update_snapshot(
  .data = data,
  conn = conn,
  db_table = "mtcars", # the name of the DB table to store the data in
  timestamp = as.POSIXct("2020-01-03 10:00:00")
)

## ----example_3_results_a, eval = requireNamespace("RSQLite", quietly = TRUE)----
get_table(conn, "mtcars")

## ----example_3_results_b, eval = requireNamespace("RSQLite", quietly = TRUE)----
get_table(conn, "mtcars", slice_ts = NULL)

