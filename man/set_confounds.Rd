% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/set_confounds.R
\name{set_confounds}
\alias{set_confounds}
\title{Set confounds}
\usage{
set_confounds(...)
}
\arguments{
\item{...}{arguments passed to set_confound}
}
\value{
An object of class \code{causal_model}. It essentially returns a list containing the elements comprising
a model (e.g. 'statement', 'nodal_types' and 'DAG') with the parameter matrix updated according to `confound`.
}
\description{
alias for set_confound. See set_confound.
}
