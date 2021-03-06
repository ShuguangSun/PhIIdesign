% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sargent2stage_rando.R
\name{sargent2stage_R}
\alias{sargent2stage_R}
\title{The Sargent 2-stage function for two randomized arms}
\usage{
sargent2stage_R(
  p0,
  pa,
  alpha,
  beta,
  eta,
  pi,
  eps = 0.005,
  N_min,
  N_max,
  alloc,
  ...
)
}
\arguments{
\item{p0}{uninteresting response (null hypothesis H0)}

\item{pa}{interesting response (alternative hypothesis Ha)}

\item{alpha}{P(reject H0|H0)}

\item{beta}{P(reject Ha|Ha)}

\item{eta}{P(reject Ha|H0)}

\item{pi}{P(reject H0|Ha)}

\item{eps}{tolerance (actual alpha<=alpha+eps; actual beta<=beta+eps; actual eta>=eta-eps; actual pi>=pi-eps); default value = 0.005}

\item{N_min}{minimum sample size value for grid search}

\item{N_max}{maximum sample size value for grid search}

\item{alloc}{allocation ratio (e.g. 2 for 2:1)}

\item{...}{refers to type="exact" or "normal" for pdf and cdf difference of two binomial variables}
}
\value{
dataframe with selected scenarios, with following columns:
\describe{
    \item{r1}{if (E_1-C_1)<=r1 -> stop for futility}
    \item{n1_E}{Number of patients for experimental arm in stage 1}
    \item{n1_C}{Number of patients for control arm in stage 1}
    \item{n1}{Total number of patients in stage 1}
    \item{r2}{if (E_2+E_1)-(C_2+C_1)<=r1 -> futility}
    \item{s}{if (E_2+E_1)-(C_2+C_1)>=1 -> efficacy}
    \item{n2_E}{Number of patients for experimental arm in stage 1}
    \item{n2_C}{Number of patients for control arm in stage 1}
    \item{n2}{Total number of patients in stage 2}
    \item{N}{Total number of patients}
    \item{N_E}{Total number of patients in experimental arm}
    \item{N_C}{Total number of patients in control arm}
    \item{EN.p0}{expected sample size, under the null hypothesis}
    \item{PET.p0}{robability of terminating the trial at the end of the first stage, under the null hypothesis}
    \item{MIN}{Selected 'minimax' design}
    \item{OPT}{Selected 'optimal' design}
    \item{ADMISS}{Selected 'admissible' design}
    \item{alpha}{calculated alpha for selected design}
    \item{beta}{calculated beta for selected design}
    \item{eta}{calculated eta for selected design}
    \item{pi}{calculated pi for selected design}
    \item{lambda}{calculated lambda for selected design}
    \item{delta}{calculated delta for selected design}
    \item{alloc}{allocation rate}
    \item{p0}{p0 parameter for design}
    \item{pa}{pa parameter for design}
    \item{alpha_param}{alpha parameter for design}
    \item{beta_param}{beta parameter for design}
    \item{eta_param}{eta parameter for design}
    \item{pi_param}{pi parameter for design}
}
}
\description{
This function calculates sample sizes of the Sargent 2-stage design (randomized)

including first stage and second stage cutoff values for futility (r1 and r2) and efficacy (s)
}
\details{
E_1= number of successes experimental arm, stage 1

C_1= number of successes control arm, stage 1

E_2= number of successes experimental arm, stage 2

C_2= number of successes control arm, stage 2

with E_i~Bin(n_i,P) and C_i~Bin(n_i,P), i=1,2

if (E_1-C_1)<=r1 -> stop futility

if (E_2+E_1) - (C_2+C_1)<=r2 -> futility

if (E_2+E_1) - (C_2+C_1)>=s -> efficacy

Note that all sample sizes can be entered, but only calculations for sample sizes, without any decimals (taking into account allocation ratio)

Variable of interest: Z=E-C, so always in this direction

alloc >=1 (more patients in the experimental arm)
}
\examples{
\dontrun{
sargent2stage_R(
  p0 = 0.1, pa = 0.3, alpha = 0.05, beta = 0.15, eta = 0.8, pi = 0.8, eps = 0.005,
  N_min = 88, N_max = 90, alloc = 1, type = "normal"
)
}
}
