test_that("get_connection() works", {
  for (conn in get_test_conns()) {
    expect_true(DBI::dbIsValid(conn))

    connection_clean_up(conn)
  }
})


test_that("get_connection() notifies if connection fails", {
  skip_if_not_installed("RSQLite")

  for (i in 1:100) {
    random_string <- paste(sample(letters, size = 32, replace = TRUE), collapse = "")

    if (dir.exists(random_string)) next

    expect_error(get_connection(drv = RSQLite::SQLite(), dbname = file.path(random_string, "/invalid_path")),
                 regexp = r"{checkmate::check_path_for_output\(dbname\)}")
  }
})


test_that("close_connection() works", {
  for (conn in get_test_conns()) {

    # Check that we can close the connection
    expect_true(DBI::dbIsValid(conn))
    close_connection(conn)
    expect_false(DBI::dbIsValid(conn))
  }
})
