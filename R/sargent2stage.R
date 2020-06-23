

#-----------------------------------------------------#
# two error probabilities functions (Equations p3530) #
#-----------------------------------------------------#

probho<-function(n1,n2,r1,r,p){
  i<-seq(r1+1,min(n1,r))
  pbinom(q=r1,size=n1,prob=p,lower.tail=T)+sum(pbinom(q=r-i,size=n2,prob=p,lower.tail=T)*dbinom(i,size=n1,prob=p))
}

probha<-function(n1,n2,r1,s,p){
  i<-seq(r1+1,min(n1,s))
  sum(pbinom(q=s-i-1,size=n2,prob=p,lower.tail=F)*dbinom(i,size=n1,prob=p))+as.numeric(n1>s)*pbinom(q=s,size=n1,prob=p,lower.tail=F)
}


#' @title The Sargent 2-stage function
#' @description This function calculates sample sizes of the sargent 2-stage design.
#' @details n1= n stage1
#' @details n2= n stage2
#' @details total number of patients=n1+n2
#' @details if x1<=r1 --> stop futility
#' @details if (x1+x2)<=r --> futility
#' @details if (x1+x2)>=s --> efficacy
#' @param p0 uninteresting response (null hypothesis H0)
#' @param pa interesting response (alternative hypothesis Ha)
#' @param alpha P(reject H0|H0)
#' @param beta P(reject Ha|Ha)
#' @param eta P(reject Ha|H0)
#' @param pi P(reject H0|Ha)
#' @param eps tolerance (actual alpha<=alpha+eps; actual beta<=beta+eps; actual eta>=eta-eps; actual p>=pi-eps); default value = 0.005
#' @param N_min minimum sample size value for grid search
#' @param N_max maximum sample size value for grid search
#' @examples
#' sargent2stage(p0=0.1,pa=0.3,alpha=0.05,beta=0.1,eta=0.8,pi=0.8,eps = 0.005,N_min=15,N_max=30)
#' @export
#' @import data.table
#' @importFrom grDevices chull
#' @importFrom graphics plot points
#' @importFrom stats aggregate dbinom


sargent2stage<-function(p0,pa,alpha,beta,eta,pi,eps = 0.005,N_min,N_max){

  if (pa<p0) {stop('p0 should be smaller than pa')}

  # Define variables as a NULL value (to avoid 'notes' in devtools package check)

  EN.p0<-EN.p0_N_min<-EN.p0_min<-MIN<-N<-OPT<-NULL

  #----------------------------------------------------------------------------------------------------------#
  # Get all possible scenarios for N, n1, r1, r2 and n2                                                      #
  # Note that this is the possible range of values: 0 <=r1<n1; r1+1<=r; r+2<=s<=n1+n2                        #
  #----------------------------------------------------------------------------------------------------------#

  # Get all N's for which there is a max r (1:N-2) for which P(X<=r|Ha)<=beta+eps, and select that max r
  # Note that this is not taking into account first stage. However, the probability of rejecting Ha
  # should be lower in the second stage, compared to a 1-stage design, as some cases already rejected at first stage,
  # meaning that an rmax, calculated using a 1-stage design, is a good maximum
  #------------------------------------------------------------------------------------------------------------

  res0_t           <- data.frame(do.call("rbind", mapply(function(a) cbind(N=a,rtemp=1:(a-2)),a=(N_min:N_max),SIMPLIFY=F)))
  res0_t$betamax   <- pbinom(q=res0_t$rtemp,size=res0_t$N,prob=pa,lower.tail=T)
  res0             <- aggregate(res0_t[!is.na(res0_t$betamax) & res0_t$betamax<=(beta +eps),]$rtemp, by = list(res0_t[!is.na(res0_t$betamax) & res0_t$betamax<=(beta +eps),]$N), max)    # Select all possible N's: there needs to be
  # at least one r with P(X<=r|Ha)<=beta+eps
  names(res0)      <- c("N","rmax")

  # Get for selected N's all possible n1's (1:N-1) + create r1max with 0<=r1<=r-1 and 0<=r1<n1 (note: r1<n1, otherwise first stage makes
  # no sense: futility even if all outcomes a success)
  #-------------------------------------------------------------------------------------------

  res1        <- data.frame(do.call("rbind", mapply(function(a,b) cbind(N=a,n1=(1:(a-1)),rmax=b),a=res0$N,b=res0$rmax,SIMPLIFY=F)))

  res1$r1max  <- pmin(res1$rmax-1,res1$n1-1)

  # Get for selected N's and n1's, r1's (0:r1max, where P(X_1<=r_1|Ha)<=beta+eps)
  #------------------------------------------------------------------------------

  res2_t      <- data.frame(do.call("rbind", mapply(function(a,b,c,d) cbind(N=a,n1=b,rmax=c,r1max=d,r1=(0:d)),
                                                    a=res1$N,b=res1$n1,c=res1$rmax,d=res1$r1max,SIMPLIFY=F)))

  res2_t$beta <- pbinom(q=res2_t$r1,size=res2_t$n1,prob=pa,lower.tail=T)
  res2        <- res2_t[res2_t$beta<=(beta +eps),]

  # Get for selected N's, n1's and r1's: r2's ((r1+1):rmax)
  #----------------------------------------------------------

  res3        <- data.frame(do.call("rbind", mapply(function(a,b,c,d) cbind(N=a,n1=b,r1=d,r2=((d+1):c)),
                                                    a=res2$N,b=res2$n1,c=res2$rmax,d=res2$r1)))
  res3$n2     <- res3$N-res3$n1

  #----------------------------------------------------------#
  # Calculate beta and eta for all scenarios (only r needed) #
  #----------------------------------------------------------#

  res3$beta_temp   <- mapply(function (a,b,c,d) probho(n1=a,n2=b,r1=c,r=d,p=pa),a=res3$n1,b=res3$n2,c=res3$r1,d=res3$r2)
  res3$diff_beta   <- res3$beta_temp - beta
  res3             <- res3[res3$diff_beta<=eps,]

  res3$eta_temp    <- mapply(function (a,b,c,d) probho(n1=a,n2=b,r1=c,r=d,p=p0),a=res3$n1,b=res3$n2,c=res3$r1,d=res3$r2)
  res3$diff_eta    <- eta - res3$eta_temp
  res3             <- res3[res3$diff_eta<=eps,]

  # Get for selected N's, n1's, r1's and r1's: s's ((r2+2):n)
  #----------------------------------------------------------

  res4              <- data.frame(do.call("rbind", mapply(function(a,b,c,d,e,f,g) cbind(N=a,n1=b,n2=c,r1=d,r2=e,s=((e+2):a),beta_temp=f,eta_temp=g),
                                                          a=res3$N,b=res3$n1,c=res3$n2,d=res3$r1,e=res3$r2,f=res3$beta_temp,g=res3$eta_temp)))

  #----------------------------------------------------------#
  # Calculate pi and alpha for all scenarios (s needed)      #
  #----------------------------------------------------------#

  res4$pi_temp     <- mapply(function (a,b,c,d) probha(n1=a,n2=b,r1=c,s=d,p=pa),a=res4$n1,b=res4$n2,c=res4$r1,d=res4$s)
  res4$diff_pi     <- pi - res4$pi_temp
  res4             <- res4[res4$diff_pi<=eps,]

  res4$alpha_temp  <- mapply(function (a,b,c,d) probha(n1=a,n2=b,r1=c,s=d,p=p0),a=res4$n1,b=res4$n2,c=res4$r1,d=res4$s)
  res4$diff_alpha  <- res4$alpha_temp - alpha
  res5              <- res4[res4$diff_alpha<=eps,]

  res5$alpha <- alpha
  res5$beta  <- beta
  res5$eta   <- eta
  res5$pi    <- pi

  res5$PET.p0 <- pbinom(q=res5$r1,size=res5$n1,prob=p0,lower.tail=T)
  res5$EN.p0  <- res5$N-((res5$N-res5$n1)*res5$PET.p0)

  res5<-data.table::as.data.table(res5)

  res5 <- res5[,N_min := min(N) ]
  res5 <- res5[,EN.p0_min := min(EN.p0)]
  res5 <- res5[,EN.p0_N_min := min(EN.p0),by=N]
  res6<- res5[EN.p0==EN.p0_N_min]

  res6$OPT<-res6$MIN<-res6$ADMISS<-c("")
  res6[which(EN.p0==EN.p0_min),]$OPT  <-"Optimal"
  res6[which(N==N_min),]$MIN          <-"Minimax" # Note: if multiple designs that meet the criteria for minimax:choose
  # design with minimal expected sample size under H0: "Optimal minimax design"

  # Get admissible designs
  y <- data.frame(res6[,c("N","EN.p0")])
  con.ind <- chull(y)[chull((y)) == cummin(chull((y)))]

  #chull_result<-data.frame(print(multichull::CHull(y,bound = "lower")))
  #con.ind <- as.numeric(rownames(y[y$N %in% chull_result$complexity,]))

  res<-res6[N>=min(res6[MIN=="Minimax","N"]) & N<=max(res6[OPT=="Optimal","N"]),]
  res[which((rownames(res) %in% c(con.ind)) & (N > N_min) &  (EN.p0 > EN.p0_min) & (N<unique(res[OPT=="Optimal",]$N))),]$ADMISS<- "Admissible"

  names(res)[names(res)=="alpha"]<-"alpha_param"
  names(res)[names(res)=="beta" ]<-"beta_param"
  names(res)[names(res)=="eta"  ]<-"eta_param"
  names(res)[names(res)=="pi"   ]<-"pi_param"

  names(res)[names(res)=="alpha_temp"]<-"alpha"
  names(res)[names(res)=="beta_temp" ]<-"beta"
  names(res)[names(res)=="eta_temp"  ]<-"eta"
  names(res)[names(res)=="pi_temp"   ]<-"pi"

  res$lambda<-1-(res$eta +res$alpha)
  res$delta <-1-(res$beta+res$pi)

  # Plot
  #-----

  res.df<-data.frame(res)
  plot(res.df[,"N"],res.df[,"EN.p0"], type = "l",
       xlab = "Maximum Sample Size N",
       ylab = expression(paste("E( N | ",p[0], " )")),
       main = "Two-stage Designs")
  points(res.df[res.df$MIN   =="Minimax"   , "N"],res.df[res.df$MIN   =="Minimax"   , "EN.p0"],pch = "M")
  points(res.df[res.df$OPT   =="Optimal"   , "N"],res.df[res.df$OPT   =="Optimal"   , "EN.p0"],pch = "O")
  points(res.df[res.df$ADMISS=="Admissible", "N"],res.df[res.df$ADMISS=="Admissible", "EN.p0"],pch = "A")

  res<- res[,-c("diff_pi","diff_alpha","N_min","EN.p0_min","EN.p0_N_min")]
  res<- cbind(res[,c("r1","n1","r2","s","n2","N","EN.p0","PET.p0","MIN","OPT","ADMISS","alpha","beta","eta","pi","lambda","delta")],p0=p0,pa=pa,res[,c("alpha_param","beta_param","eta_param","pi_param")])

  return(res)

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