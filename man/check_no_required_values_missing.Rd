% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/check_data.r
\name{check_no_required_values_missing}
\alias{check_no_required_values_missing}
\title{Check for missing entries in non-nullable columns}
\usage{
check_no_required_values_missing(dt, optional = character())
}
\arguments{
\item{dt}{a data.table, for which to check for missing entries.}

\item{optional}{a character vector, containing names of nullable columns in
\code{dt}. These columns are not checked.}
}
\value{
NULL, if no missing non-nullable entries are found.
}
\description{
Check for missing entries in non-nullable columns
}
