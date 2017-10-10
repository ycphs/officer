% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/read_xlsx.R
\name{read_xlsx}
\alias{read_xlsx}
\alias{length.rxlsx}
\alias{print.rxlsx}
\title{open a connexion to an 'Excel' file}
\usage{
read_xlsx(path = NULL)

\method{length}{rxlsx}(x)

\method{print}{rxlsx}(x, target = NULL, ...)
}
\arguments{
\item{path}{path to the xlsx file to use as base document.}

\item{x}{an rpptx object}

\item{target}{path to the xlsx file to write}

\item{...}{unused}
}
\description{
read and import an xlsx file as an R object
representing the document.
}
\examples{
read_xlsx()
# write a rdocx object in a docx file ----
if( require(magrittr) ){
  read_xlsx() \%>\% print(target = "out.xlsx")
  # full path of produced file is returned
  print(.Last.value)
}
}