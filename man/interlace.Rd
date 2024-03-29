% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/interlace.R
\name{interlace}
\alias{interlace}
\alias{interlace_sql}
\title{Combine any number of tables, where each has their own time axis of validity}
\usage{
interlace(tables, by = NULL, colnames = NULL)

interlace_sql(tables, by = NULL, colnames = NULL)
}
\arguments{
\item{tables}{(\code{list}(\code{tbl_dbi(1)}))\cr
The historical tables to combine.}

\item{by}{(\code{character()})\cr
The variable to merge by.}

\item{colnames}{(\verb{named list()})\cr
If the time axes of validity is not called "valid_to" and "valid_until" inside each \code{tbl_dbi},
you can specify their names by supplying the arguments as a list:
e.g. c(t1.from = "\<colname\>", t2.until = "\<colname\>").
colnames must be named in same order as as given in tables (i.e. t1, t2, t3, ...).}
}
\value{
The combination of input queries with a single, interlaced valid_from / valid_until time axis.

\if{html}{\out{<div class="sourceCode">}}\preformatted{     The combination of input queries with a single, interlaced
             valid_from / valid_until time axis
}\if{html}{\out{</div>}}
}
\description{
The function "interlaces" the queries and combines their validity time axes (valid_from and valid_until)
onto a single time axis.

\code{interlace_sql()} is deprecated in favor of \code{interlace()}
}
\examples{
\dontshow{if (requireNamespace("RSQLite", quietly = TRUE)) (if (getRversion() >= "3.4") withAutoprint else force)(\{ # examplesIf}
  conn <- get_connection()

  t1 <- data.frame(key = c("A", "A", "B"),
                   obs_1   = c(1, 2, 2),
                   valid_from  = as.Date(c("2021-01-01", "2021-02-01", "2021-01-01")),
                   valid_until = as.Date(c("2021-02-01", "2021-03-01", NA))) |>
    dplyr::copy_to(conn, df = _, name = "t1")

  t2 <- data.frame(key = c("A", "B"),
                   obs_2 = c("a", "b"),
                   valid_from  = as.Date(c("2021-01-01", "2021-01-01")),
                   valid_until = as.Date(c("2021-04-01", NA))) |>
    dplyr::copy_to(conn, df = _, name = "t2")

  interlace(list(t1, t2), by = "key")

  close_connection(conn)
\dontshow{\}) # examplesIf}
}
