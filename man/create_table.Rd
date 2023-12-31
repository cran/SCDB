% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/create_table.R
\name{create_table}
\alias{create_table}
\title{Create a historical table from input data}
\usage{
create_table(.data, conn = NULL, db_table_id, temporary = TRUE, ...)
}
\arguments{
\item{.data}{A data frame, a tibble, a data.table or a tbl.}

\item{conn}{An object that inherits from DBIConnection (as generated by get_connection())'}

\item{db_table_id}{A \code{\link[DBI:Id]{DBI::Id()}} object or a character string readable by \link{id}.}

\item{temporary}{Should the table be created as a temporary table?}

\item{...}{Other arguments passed to \code{\link[DBI:dbCreateTable]{DBI::dbCreateTable()}}}
}
\value{
Invisibly returns the table as it looks on the destination (or locally if conn is NULL)
}
\description{
Create a historical table from input data
}
\examples{
conn <- get_connection(drv = RSQLite::SQLite())

create_table(mtcars, conn = conn, db_table_id = "mtcars_tmp")

close_connection(conn)
}
