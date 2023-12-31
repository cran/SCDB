% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get_schema.R
\name{get_schema}
\alias{get_schema}
\title{Get the current schema of a database-related objects}
\usage{
get_schema(.x)
}
\arguments{
\item{.x}{The object from which to retrieve a schema}
}
\value{
The current schema name, but defaults to "prod" instead of "public"
}
\description{
Get the current schema of a database-related objects
}
\examples{
conn <- get_connection(drv = RSQLite::SQLite())

dplyr::copy_to(conn, mtcars, name = "mtcars")

get_schema(conn)
get_schema(get_table(conn, id("mtcars", conn = conn)))

close_connection(conn)
}
