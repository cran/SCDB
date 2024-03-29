% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/connection.R
\name{close_connection}
\alias{close_connection}
\title{Close connection to the database}
\usage{
close_connection(conn)
}
\arguments{
\item{conn}{(\code{DBIConnection(1)})\cr
Connection object.}
}
\value{
\code{dbDisconnect()} returns \code{TRUE}, invisibly.
}
\description{
Close connection to the database
}
\examples{
\dontshow{if (requireNamespace("RSQLite", quietly = TRUE)) (if (getRversion() >= "3.4") withAutoprint else force)(\{ # examplesIf}
  conn <- get_connection()

  close_connection(conn)
\dontshow{\}) # examplesIf}
}
