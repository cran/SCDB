## ----include = FALSE----------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup, results = 'hide'--------------------------------------------------
suppressPackageStartupMessages(library(SCDB))
options("SCDB.log_path" = tempdir())

## ----example_conn-------------------------------------------------------------
# First we connect to our database.
# If this is, e.g., a PostgreSQL database already running on the machine, connection
# can be done after the configuration of a .pgpass file.
# For this example, we use an on-disk SQLite db to showcase.
conn <- get_connection(drv = RSQLite::SQLite())
# NOTE: Had the PostgreSQL DB been configured, we would not need to pass any args
# to get_connection()

## ----example_data-------------------------------------------------------------
# Our example data is mtcars with rownames converted to a column and only the first hp
# column of mtcars
example_data <- dplyr::transmute(mtcars, car = rownames(mtcars), hp)
# If the data does not already live on the remote, we must transfer it
example_data <- dplyr::copy_to(conn, example_data, overwrite = TRUE)


## ----example_1----------------------------------------------------------------
# In this example, we imagine that on day 1, in this case 2020-01-01 11:00:00, our data
# known to us is the first 3 records of mtcars
data <- head(example_data, 3)

## ----update_snapshot_1, eval = FALSE------------------------------------------
#  # We then store these data in the database using update_snapshot
#  update_snapshot(.data = data,
#                  conn = conn,
#                  db_table = "mtcars", # the name of the DB table to store the data in
#                  timestamp = as.POSIXct("2020-01-01 11:00:00"))

## ----update_snapshot_1_hidden, results = 'hide', echo = FALSE-----------------
# We then store these data in the database using update_snapshot
invisible(capture.output({  # NOTE: update_snapshot does some printing to terminal
  update_snapshot(.data = data,
                  conn = conn,
                  db_table = "mtcars", # the name of the DB table to store the data in
                  timestamp = as.POSIXct("2020-01-01 11:00:00"))
}))

## ----example_1_results--------------------------------------------------------
# We can access our data using the `get_table` function
print(get_table(conn, "mtcars"))

# And we can see the time-keeping if we set `include_slice_info = TRUE`
print(get_table(conn, "mtcars", include_slice_info = TRUE))

## ----example_2----------------------------------------------------------------
# Let's say that the next day, our data set is now the first 5 of our example data
data <- head(example_data, 5)

## ----update_snapshot_2, eval = FALSE------------------------------------------
#  # We then store these data in the database using update_snapshot
#  update_snapshot(.data = data,
#                  conn = conn,
#                  db_table = "mtcars", # the name of the DB table to store the data in
#                  timestamp = as.POSIXct("2020-01-02 12:00:00"))

## ----update_snapshot_2_hidden, results = 'hide', echo = FALSE-----------------
# We then store these data in the database using update_snapshot
invisible(capture.output({
  update_snapshot(.data = data,
                  conn = conn,
                  db_table = "mtcars", # the name of the DB table to store the data in
                  timestamp = as.POSIXct("2020-01-02 12:00:00"))
}))

## ----example_2_results--------------------------------------------------------

# We again use the `get_table` function and see the latest available data
print(get_table(conn, "mtcars"))

# And we can see the time-keeping if we set `include_slice_info = TRUE`
print(get_table(conn, "mtcars", include_slice_info = TRUE))

# Since our data is time-versioned, we can recover the data from the day before
print(get_table(conn, "mtcars", slice_ts = "2020-01-01 11:00:00"))

## ----example_3----------------------------------------------------------------
# On day 3, we imagine that we have the same 5 records, but one of them is altered
data <- head(example_data, 5) |>
  dplyr::mutate(hp = ifelse(dplyr::row_number() == 1, hp / 2, hp))

## ----update_snapshot_3, eval = FALSE------------------------------------------
#  # We then store these data in the database using update_snapshot
#  update_snapshot(.data = data,
#                  conn = conn,
#                  db_table = "mtcars", # the name of the DB table to store the data in
#                  timestamp = as.POSIXct("2020-01-03 10:00:00"))

## ----update_snapshot_3_hidden, results = "hide", echo = FALSE-----------------
# We then store these data in the database using update_snapshot
invisible(capture.output({
  update_snapshot(.data = data,
                  conn = conn,
                  db_table = "mtcars", # the name of the DB table to store the data in
                  timestamp = as.POSIXct("2020-01-03 10:00:00"))
}))

## ----example_3_results--------------------------------------------------------
# We can again access our data using the `get_table` function and see that the currently
# available data (with the changed hp value for Mazda RX4)
print(get_table(conn, "mtcars"))


# When `slice_ts` is set to `NULL`, the full history of the table is returned
print(get_table(conn, "mtcars", slice_ts = NULL))

# Setting include_slice_info = TRUE also returns checksum, from_ts and until_ts.
# This is most useful when viewing data from a specific point in time
print(get_table(conn, "mtcars", slice_ts = "2020-01-03 06:30:00",
                include_slice_info = TRUE))

