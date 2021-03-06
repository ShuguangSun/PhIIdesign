

#-----------------------------------------------------#
# two error probabilities functions (Equations p3530) #
#-----------------------------------------------------#

probho <- function(n1, n2, r1, r, p) {
  i <- seq(r1 + 1, min(n1, r))
  pbinom(q = r1, size = n1, prob = p, lower.tail = TRUE) +
    sum(pbinom(q = r - i,     size = n2, prob = p, lower.tail = TRUE) *  dbinom(i, size = n1, prob = p))
}


probha <- function(n1, n2, r1, s, p, type = "original") {
  ## Equation 4 page 122 Sargent et. Al
  i <- seq(r1 + 1, min(n1, s))
  if(type == "original"){
    pbinom(q = s, size = n1, prob = p, lower.tail = FALSE) * as.numeric(n1 > s) +
      sum(pbinom(q = s - i - 1, size = n2, prob = p, lower.tail = FALSE) * dbinom(i, size = n1, prob = p))
  }else if(type == "speedup"){
    # same but more consistent with speedup logic implemented as in probsimon as we need P(X2>=s-i)
    # lower.tail=TRUE: P(X<=x|p)
    # lower.tail=FALSE:P(X >x|p)
    pbinom(q = s, size = n1, prob = p, lower.tail = FALSE) * as.numeric(n1 > s) +
      sum((1 - pbinom(q = s - i, size = n2, prob = p, lower.tail = TRUE) + dbinom(s - i, size = n2, prob = p)) * dbinom(i, size = n1, prob = p))
  }else{
    stop("type should be either 'original' or 'speedup'")
  }
}

probhaAll <- function(n1, n2, s, b_p0, B_p0, B_p0_ut, b_pa, B_pa, B_pa_ut){
  ## Equation 4 page 122 Sargent et. Al
  r <- s
  ## Similar code as probsimonAllR
  r_1 <- 0:(min(n1, r)-1)
  x   <- r_1 + 1
  ## note the n1+1 and n2+1 due to how R handles indexing B[[1]] is in fact the value of B for n = 0. Same for the 1 + in the vectors
  # alpha
  B_p0_r1         <- B_p0_ut[[n1 + 1]][1 + r] * as.numeric(n1 > r)
  b_p0_x          <- b_p0[[n1 + 1]][1 + x]
  B_p0_r2         <- B_p0[[n2 + 1]][1 + (r-x)]
  B_p0_r2_density <- b_p0[[n2 + 1]][1 + (r-x)]
  alpha_temp <- B_p0_r1 + rev(cumsum(rev(b_p0_x * (1 - B_p0_r2 + B_p0_r2_density))))
  # pi
  B_pa_r1         <- B_pa_ut[[n1 + 1]][1 + r] * as.numeric(n1 > r)
  b_pa_x          <- b_pa[[n1 + 1]][1 + x]
  B_pa_r2         <- B_pa[[n2 + 1]][1 + (r-x)]
  B_pa_r2_density <- b_pa[[n2 + 1]][1 + (r-x)]
  pi_temp <- B_pa_r1 + rev(cumsum(rev(b_pa_x * (1 - B_pa_r2 + B_pa_r2_density))))
  list(N = n1 + n2, n1 = n1, n2 = n2,
       r1 = r_1, s = s,
       alpha_temp = alpha_temp, pi_temp = pi_temp)
}


#' @title The Sargent 2-stage function
#' @description This function calculates sample sizes of the Sargent 2-stage design.
#' @description The goal of a phase II trial is to make a preliminary determination regarding the activity and
#' tolerability of a new treatment and thus to determine whether the treatment warrants
#' further study in the phase III setting. \cr
#' This function calculates the sample size needed in a Sargent 2-stage design which is a
#' three-outcome design that allows for three outcomes: reject \eqn{H(0)}, reject \eqn{H(a)}, or reject neither.
#' @param p0 probability of the uninteresting response (null hypothesis \eqn{H0})
#' @param pa probability of the interesting response (alternative hypothesis Ha)
#' @param alpha Type I error rate \eqn{P(reject H0|H0)}
#' @param beta Type II error rate \eqn{P(reject Ha|Ha)}
#' @param eta \eqn{P(reject Ha|H0)}
#' @param pi \eqn{P(reject H0|Ha)}
#' @param eps tolerance default value = 0.005
#' @param N_min minimum sample size value for grid search
#' @param N_max maximum sample size value for grid search
#' @param admissible character string indicating how to compute admissible designs, either 'chull' or 'CHull', the former uses grDevices::chull, the latter uses multichull::CHull
#' @param method either 'original' or 'speedup' for the original implementation or a more speedier version
#' @param ... arguments passed on to plot in case admissible is set to CHull
#' @return a data.frame with elements
#' \itemize{
#' \item n1: total number of patients in stage1
#' \item n2: total number of patients in stage2
#' \item N: total number of patients=n1+n2
#' \item r1: critical value for the first stage
#' \item r2: critical value for the second stage
#' \item EN.p0: expected sample size under H0
#' \item PET.p0: probability of terminating the trial at the end of the first stage under H0
#' \item MIN: column indicating if the design is the minimal design
#' \item OPT: column indicating if the setting is the optimal design
#' \item ADMISS: column indicating if the setting is the admissible design
#' \item alpha: the actual alpha value which is smaller than \code{alpha_param + eps}
#' \item beta: the actual beta value where which is smaller than \code{beta_param + eps}
#' \item eta: the actual eta value which is smaller than \code{eta_param - eps}
#' \item pi: the actual pi value which is smaller than \code{pi_param - eps}
#' \item lambda:  1-(eta+alpha)
#' \item delta: 1-(beta+pi)
#' \item p0: your provided \code{p0} value
#' \item pa: your provided \code{pa} value
#' \item alpha_param: your provided \code{alpha} value
#' \item beta_param: your provided \code{beta} value
#' \item eta_param: your provided \code{eta} value
#' \item pi_param: your provided \code{pi} value
#' }
#' @details
#' if x1<=r1 --> stop futility \cr
#' if (x1+x2)<=r --> futility \cr
#' if (x1+x2)>=s --> efficacy \cr
#' @references Sargent DJ, Chan V, Goldberg RM. A three-outcome design for phase II clinical trials. Control Clin Trials. 2001;22(2):117-125. doi:10.1016/s0197-2456(00)00115-x
#' @export
#' @examples
#' samplesize <- sargent2stage(p0 = 0.1, pa = 0.3, alpha = 0.05, beta = 0.1,
#'                             eta = 0.8, pi = 0.8,
#'                             eps = 0.005, N_min = 15, N_max = 30)
#' plot(samplesize)
#'
#' \donttest{
#' data(data_sargent2)
#' test <- data_sargent2
#' samplesize <- sargent2stage(p0 = test$p0, pa = test$pa, alpha = test$alpha, beta = test$beta,
#'                             eta = test$eta, pi = test$pi,
#'                             eps = 0.005,
#'                             N_min = test$N_min, N_max = test$N_max)
#' optimal <- lapply(samplesize, FUN=function(x) subset(x, OPT == "Optimal"))
#' optimal <- data.table::rbindlist(optimal)
#' minimax <- lapply(samplesize, FUN=function(x) subset(x, MIN == "Minimax"))
#' minimax <- data.table::rbindlist(minimax)
#' }
sargent2stage <- function(p0, pa, alpha, beta, eta, pi, eps = 0.005, N_min, N_max, admissible = c("chull", "CHull"), method = c("speedup", "original"), ...){
  admissible <- match.arg(admissible)
  method <- match.arg(method)
  if(length(p0) > 1 && length(pa) > 1){
    results <- mapply(null = p0, alternative = pa, alpha = alpha, beta = beta, eta = eta, pi = pi, eps = eps, N_min = N_min, N_max = N_max,
                      FUN = function(null, alternative, alpha, beta, eta, pi, eps, N_min, N_max, admissible, method, ...){
                        sargent2stage.default(p0 = null, pa = alternative, alpha = alpha, beta = beta, eta = eta, pi = pi, eps = eps, N_min = N_min, N_max = N_max, admissible = admissible, method = method, ...)
                      }, MoreArgs = list(admissible = admissible, method = method), ...,
                      SIMPLIFY = FALSE)
  }else{
    results <- sargent2stage.default(p0 = p0, pa = pa, alpha = alpha, beta = beta, eta = eta, pi = pi, eps = eps, N_min = N_min, N_max = N_max, admissible = admissible, method = method, ...)
  }
}

sargent2stage.default <- function(p0, pa, alpha, beta, eta, pi, eps = 0.005, N_min, N_max, admissible = c("chull", "CHull"), method = c("speedup", "original"), ...) {
  method <- match.arg(method)
  admissible <- match.arg(admissible)
  if (pa < p0) {
    stop("p0 should be smaller than pa")
  }

  # Define variables as a NULL value (to avoid 'notes' in devtools package check)
  n1 <- n2 <- r <- r2 <- rowid <- s <- NULL
  EN.p0 <- EN.p0_N_min <- EN.p0_min <- MIN <- N <- OPT <- NULL

  #----------------------------------------------------------------------------------------------------------#
  # Get all possible scenarios for N, n1, r1, r2 and n2                                                      #
  # Note that this is the possible range of values: 0 <=r1<n1; r1+1<=r; r+2<=s<=n1+n2                        #
  #----------------------------------------------------------------------------------------------------------#

  # Get all N's for which there is a max r (1:N-2) for which P(X<=r|Ha)<=beta+eps, and select that max r
  # Note that this is not taking into account first stage. However, the probability of rejecting Ha
  # should be lower in the second stage, compared to a 1-stage design, as some cases already rejected at first stage,
  # meaning that an rmax, calculated using a 1-stage design, is a good maximum
  #------------------------------------------------------------------------------------------------------------
  res0 <- lapply(N_min:N_max, FUN=function(a) cbind(N = a, rtemp = 1:(a - 2)))
  res0 <- do.call(rbind, res0)
  res0 <- data.frame(res0)
  res0$betamax <- pbinom(q = res0$rtemp, size = res0$N, prob = pa, lower.tail = TRUE)
  res0 <- res0[!is.na(res0$betamax) & res0$betamax <= (beta + eps), ]
  # Select all possible N"s: there needs to be
  # at least one r with P(X<=r|Ha)<=beta+eps
  res0 <- aggregate(res0$rtemp, by = list(res0$N), max)
  names(res0) <- c("N", "rmax")

  # Get for selected N's all possible n1's (1:N-1) + create r1max with 0<=r1<=r-1 and 0<=r1<n1 (note: r1<n1, otherwise first stage makes
  # no sense: futility even if all outcomes a success)
  #-------------------------------------------------------------------------------------------
  res1 <- mapply(a = res0$N, b = res0$rmax, FUN = function(a, b) cbind(N = a, n1 = (1:(a - 1)), rmax = b), SIMPLIFY = FALSE)
  res1 <- do.call(rbind, res1)
  res1 <- data.frame(res1)
  res1$r1max <- pmin(res1$rmax - 1, res1$n1 - 1)

  # Get for selected N's and n1's, r1's (0:r1max, where P(X_1<=r_1|Ha)<=beta+eps)
  #------------------------------------------------------------------------------
  res2 <- mapply(a = res1$N, b = res1$n1, c = res1$rmax, d = res1$r1max,
                 FUN = function(a, b, c, d) cbind(N = a, n1 = b, rmax = c, r1max = d, r1 = (0:d)),
                 SIMPLIFY = FALSE)
  res2 <- do.call(rbind, res2)
  res2 <- data.frame(res2)
  res2$beta <- pbinom(q = res2$r1, size = res2$n1, prob = pa, lower.tail = TRUE)
  res2 <- res2[res2$beta <= (beta + eps), ]

  # Get for selected N's, n1's and r1's: r2's ((r1+1):rmax)
  #----------------------------------------------------------
  res3 <- mapply(a = res2$N, b = res2$n1, c = res2$rmax, d = res2$r1,
                 FUN = function(a, b, c, d) cbind(N = a, n1 = b, r1 = d, r2 = ((d + 1):c)))
  res3 <- do.call(rbind, res3)
  res3 <- data.frame(res3)
  res3$n2 <- res3$N - res3$n1

  #----------------------------------------------------------#
  # Calculate beta and eta for all scenarios (only r needed) #
  #----------------------------------------------------------#
  nmax <- N_max
  b_p0 <- lapply(0:nmax, FUN = function(n) dbinom(0:nmax, size = n, prob = p0))
  b_pa <- lapply(0:nmax, FUN = function(n) dbinom(0:nmax, size = n, prob = pa))
  B_p0 <- lapply(0:nmax, FUN = function(n) pbinom(0:nmax, size = n, prob = p0, lower.tail = TRUE))
  B_pa <- lapply(0:nmax, FUN = function(n) pbinom(0:nmax, size = n, prob = pa, lower.tail = TRUE))
  B_p0_ut <- lapply(0:nmax, FUN = function(n) pbinom(0:nmax, size = n, prob = p0, lower.tail = FALSE))
  B_pa_ut <- lapply(0:nmax, FUN = function(n) pbinom(0:nmax, size = n, prob = pa, lower.tail = FALSE))
  if(method %in% c("original", "speedup")){
    res3$beta_temp <- mapply(a = res3$n1, b = res3$n2, c = res3$r1, d = res3$r2,
                           FUN = function(a, b, c, d) probho(n1 = a, n2 = b, r1 = c, r = d, p = pa))
    res3$diff_beta <- res3$beta_temp - beta
    res3 <- res3[res3$diff_beta <= eps, ]
    res3$eta_temp <- mapply(a = res3$n1, b = res3$n2, c = res3$r1, d = res3$r2,
                            FUN = function(a, b, c, d) probho(n1 = a, n2 = b, r1 = c, r = d, p = p0))
    res3$diff_eta <- eta - res3$eta_temp
    res3 <- res3[res3$diff_eta <= eps, ]
  }else if(method == "speedup"){
    # res3$beta_temp <- mapply(n1 = res3$n1, n2 = res3$n2, r1 = res3$r1, r2 = res3$r2,
    #                          FUN = function(n1, n2, r1, r2) probho(n1 = n1, n2 = n2, r1 = r1, r = r2, p = pa))
    # res3$diff_beta <- res3$beta_temp - beta
    # res3 <- res3[res3$diff_beta <= eps, ]
    # res3$eta_temp <- mapply(n1 = res3$n1, n2 = res3$n2, r1 = res3$r1, r2 = res3$r2,
    #                         FUN = function(n1, n2, r1, r2) probho(n1 = n1, n2 = n2, r1 = r1, r = r2, p = p0))
    # res3$diff_eta <- eta - res3$eta_temp
    # res3 <- res3[res3$diff_eta <= eps, ]

    ## NOTE: probho is exactly the same as probsimon so we can copy the speedup logic implemented from simon2stage
    res3 <- data.table::setDT(res3)
    settings <- res3[, list(r = unique(r2)), by = list(N, n1, n2)]
    settings$rowid <- seq_len(nrow(settings))
    res5 <- settings[, probsimonAllR(n1 = n1, n2 = n2, r = r, b_p0 = b_p0, B_p0 = B_p0, b_pa = b_pa, B_pa = B_pa), by = list(rowid)]
    res5 <- data.table::setnames(res5, old = c("alpha_temp"), new = c("eta_temp"))
    res5 <- merge(res5, res3[, c("N", "n1", "n2", "r1", "r2")], all.x = FALSE, all.y = FALSE, by = c("N", "n1", "n2", "r1", "r2"))
    res5 <- data.table::setDF(res5)
    res5$eta_temp <- 1 - res5$eta_temp ## DIFFERENCE WITH REGARDS TO SIMON2
    # datacheck <- merge(res5, OLD, all.x = FALSE, all.y = TRUE, by = c("N", "n1", "n2", "r1", "r2"))
    # table(datacheck$eta_temp.x - datacheck$eta_temp.y)
    # table(datacheck$beta_temp.x - datacheck$beta_temp.y)
    # subset(datacheck, eta_temp.x != eta_temp.y)
    # subset(datacheck, beta_temp.x != beta_temp.y)
    res5 <- res5[!is.na(res5$eta_temp) & !is.na(res5$beta_temp), ]
    res5$diff_beta <- res5$beta_temp - beta
    res5 <- res5[res5$diff_beta <= eps, ]
    res5$diff_eta <- eta - res5$eta_temp
    res5 <- res5[res5$diff_eta <= eps, ]
    res3 <- res5
  }

  # Get for selected N's, n1's, r1's and r1's: s's ((r2+2):n)
  #----------------------------------------------------------
  res4 <- mapply(a = res3$N, b = res3$n1, c = res3$n2, d = res3$r1, e = res3$r2, f = res3$beta_temp, g = res3$eta_temp,
                 FUN = function(a, b, c, d, e, f, g) cbind(N = a, n1 = b, n2 = c, r1 = d, r2 = e, s = ((e + 2):a), beta_temp = f, eta_temp = g))
  res4 <- do.call(rbind, res4)
  res4 <- data.frame(res4)

  #----------------------------------------------------------#
  # Calculate pi and alpha for all scenarios (s needed)      #
  #----------------------------------------------------------#
  if(method == "original"){
    res4$pi_temp <- mapply(a = res4$n1, b = res4$n2, c = res4$r1, d = res4$s,
                           FUN = function(a, b, c, d) probha(n1 = a, n2 = b, r1 = c, s = d, p = pa))
    res4$diff_pi <- pi - res4$pi_temp
    res4 <- res4[res4$diff_pi <= eps, ]

    res4$alpha_temp <- mapply(a = res4$n1, b = res4$n2, c = res4$r1, d = res4$s,
                              FUN = function(a, b, c, d) probha(n1 = a, n2 = b, r1 = c, s = d, p = p0))
    res4$diff_alpha <- res4$alpha_temp - alpha
    res5 <- res4[res4$diff_alpha <= eps, ]
  }else if(method == "speedup"){
    res4     <- data.table::setDT(res4)
    settings <- res4[, list(s = unique(s)), by = list(N, n1, n2)]
    settings$rowid <- seq_len(nrow(settings))
    res5 <- settings[, probhaAll(n1 = n1, n2 = n2, s = s,
                                 b_p0 = b_p0, B_p0 = B_p0, B_p0_ut = B_p0_ut,
                                 b_pa = b_pa, B_pa = B_pa, B_pa_ut = B_pa_ut), by = list(rowid)]
    #res4$test_alpha_temp <- mapply(a = res4$n1, b = res4$n2, c = res4$r1, d = res4$s, FUN = function(a, b, c, d) probha(n1 = a, n2 = b, r1 = c, s = d, p = p0))
    #res4$test_pi_temp    <- mapply(a = res4$n1, b = res4$n2, c = res4$r1, d = res4$s, FUN = function(a, b, c, d) probha(n1 = a, n2 = b, r1 = c, s = d, p = pa))
    #res5 <- merge(res4, res5, by = c("N", "n1", "n2", "r1", "r2", "s"), all.x = TRUE, all.y = FALSE, sort = FALSE)
    # table(round(res5$test_alpha_temp - res5$alpha_temp), 10)
    # table(round(res5$test_pi_temp - res5$pi_temp), 10)
    res5 <- merge(res4[, c("N", "n1", "n2", "r1", "r2", "s", "beta_temp", "eta_temp")], res5,
                  by = c("N", "n1", "n2", "r1", "s"), all.x = TRUE, all.y = FALSE, sort = FALSE)
    res5 <- data.table::setDF(res5)
    res5$diff_pi <- pi - res5$pi_temp
    res5 <- res5[res5$diff_pi <= eps, ]
    res5$diff_alpha <- res5$alpha_temp - alpha
    res5 <- res5[res5$diff_alpha <= eps, ]
  }
  res5 <- res5[!is.na(res5$alpha_temp) & !is.na(res5$beta_temp) & !is.na(res5$eta_temp) & !is.na(res5$pi_temp), ]
  if(nrow(res5) == 0){
    stop("No data satisfying the H0/Ha criteria")
  }
  res5$alpha <- alpha
  res5$beta <- beta
  res5$eta <- eta
  res5$pi <- pi

  res5$PET.p0 <- pbinom(q = res5$r1, size = res5$n1, prob = p0, lower.tail = T)
  res5$EN.p0 <- res5$N - ((res5$N - res5$n1) * res5$PET.p0)

  res5 <- data.table::setDT(res5)

  res5 <- res5[, N_min := min(N)]
  res5 <- res5[, EN.p0_min := min(EN.p0)]
  res5 <- res5[, EN.p0_N_min := min(EN.p0), by = N]
  res6 <- res5[EN.p0 == EN.p0_N_min, ]

  res6$OPT <- res6$MIN <- res6$ADMISS <- c("")
  res6$OPT[which(res6$EN.p0 == res6$EN.p0_min)] <- "Optimal"
  res6$MIN[which(res6$N == res6$N_min)] <- "Minimax" # Note: if multiple designs that meet the criteria for minimax:choose
  # design with minimal expected sample size under H0: "Optimal minimax design"

  # Get admissible designs
  y <- res6[, c("N", "EN.p0")]
  if(admissible == "CHull" && requireNamespace("multichull", quietly = TRUE)){
    chull_result <- multichull::CHull(y, bound = "lower")
    if(inherits(chull_result, "CHull")){
      chull_result <- data.frame(chull_result$Hull)
      con.ind <- as.numeric(rownames(y[y$N %in% chull_result$complexity,]))
      plot(y$N, y$EN.p0, ...)
      lines(y$N[con.ind], y$EN.p0[con.ind])
    }else{
      con.ind <- chull(y)[chull((y)) == cummin(chull((y)))]
    }
  }else{
    con.ind <- chull(y)[chull((y)) == cummin(chull((y)))]
  }

  res <- res6[res6$N >= min(res6$N[res6$MIN == "Minimax"]) & res6$N <= max(res6$N[res6$OPT == "Optimal"]), ]
  res$ADMISS[which((rownames(res) %in% c(con.ind)) & (res$N > res$N_min) & (res$EN.p0 > res$EN.p0_min) & (res$N < unique(res$N[res$OPT == "Optimal"])))] <- "Admissible"

  res <- data.table::setnames(res,
                              old = c("alpha", "beta", "eta", "pi"),
                              new = c("alpha_param", "beta_param", "eta_param", "pi_param"))
  res <- data.table::setnames(res,
                              old = c("alpha_temp", "beta_temp", "eta_temp", "pi_temp"),
                              new = c("alpha", "beta", "eta", "pi"))
  res$lambda <- 1 - (res$eta + res$alpha)
  res$delta  <- 1 - (res$beta + res$pi)
  res <- data.table::setDF(res)
  res <- cbind(design_nr=1:dim(res)[1],
               res[, c("r1", "n1", "r2", "s", "n2", "N", "EN.p0", "PET.p0", "MIN", "OPT", "ADMISS", "alpha", "beta", "eta", "pi", "lambda", "delta")],
               p0 = p0, pa = pa,
               res[, c("alpha_param", "beta_param", "eta_param", "pi_param")])

  attr(res, "inputs") <- list(p0 = p0, pa = pa, alpha = alpha, beta = beta, eta = eta, pi = pi, eps = eps, N_min = N_min, N_max = N_max)
  class(res) <- c("2stage", "sargent", "data.frame")
  res
}






# TEST (Sargent DJ, Goldberg RM. A Three-Outcome Design for Phase II Clinical Trials. Controlled Clinical Trials 22:117-125
#--------------------------------------------------------------------------------------------------------------------------
# test_0_a<- data.frame(do.call("rbind", mapply(function(a,b) cbind(p0=rep(a,2),pa=rep((a+0.15),2),alpha=c(0.1,0.05),beta=c(0.1,0.1),eta=c(0.8,0.8),pi=c(0.8,0.8)),a=c(0.05,0.1,0.2,0.3,0.4,0.5),SIMPLIFY=F)))
# test_0_b<- data.frame(do.call("rbind", mapply(function(a,b) cbind(p0=rep(a,2),pa=rep((a+0.2 ),2),alpha=c(0.1,0.05),beta=c(0.1,0.1),eta=c(0.8,0.8),pi=c(0.8,0.8)),a=c(0.05,0.1,0.2,0.3,0.4,0.5),SIMPLIFY=F)))
# test_0<-cbind(rbind(test_0_a,test_0_b),data.frame(N_min=c(23,23,26,31,37,47,44,58,48,64,46,62,12,12,17,17,20,28,24,32,24,33,24,33),N_max=c(31,31,37,45,52,58,58,69,56,74,56,72,21,21,28,30,29,38,32,41,36,41,37,43)))
#
# for (i in 1:dim(test_0)[1]){
#   res<- PhIIdesign::sargent2stage(p0=test_0[i,]$p0,pa=test_0[i,]$pa,alpha=test_0[i,]$alpha,beta=test_0[i,]$beta,eta=test_0[i,]$eta,pi=test_0[i,]$pi,eps=0.005,N_min=test_0[i,]$N_min,N_max=test_0[i,]$N_max)
#
#   if (i==1) {test_list_O      <-list(res[OPT=="Optimal",])}   # Create list with first dataset
#   if (i!=1) {test_list_O[[i]] <-res[OPT=="Optimal",] }        # Next iterations: append dataset
#
#   if (i==1) {test_list_M      <-list(res[MIN=="Minimax",])}   # Create list with first dataset
#   if (i!=1) {test_list_M[[i]] <-res[MIN=="Minimax",] }        # Next iterations: append dataset
#
# }
# test_O<- data.frame(do.call("rbind",test_list_O))
# test_O<-test_O[,c("p0","pa","alpha_param","beta_param","eta_param","pi_param","alpha","beta","eta","pi","n1","n2","r1","r2","s","N","EN.p0")]
#
# test_M<- data.frame(do.call("rbind",test_list_M))
# test_M<-test_M[,c("p0","pa","alpha_param","beta_param","eta_param","pi_param","alpha","beta","eta","pi","n1","n2","r1","r2","s","N","EN.p0")]
