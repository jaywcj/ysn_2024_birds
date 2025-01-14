### Poisson & Negative Binomial GLMM ###

## Importing CSV file ##
	All_HC <- read.csv("hawker_pigeons.csv", header=T)
	# View(All_HC)
	# str(All_HC)

### OVERVIEW ###
	# 1. Data organisation - setting categorical variables as factors, scaling & putting all into dataframe
	# 2. Check for multicollinearity or VIF
	# 3. Run global model 
	# 	 a. Poisson GLM - check overdispersion statistic, if > 2 then try negative binomial model
	#	 b. Negative Binomial GLM
	# 4. Model selection using dredge function from MuMIn package or define a set of candidate models to compare AIC
	# 5. Run model with random effects (i.e., GLMM)
	# 6. Use LRT (lrtest function) to see if mixed model is better fit than fixed effects only model
	# 7. Model selection using drop1 function - further model refinement
	# 8. Model validation using simulateResiduals function from DHARMa package
	# 9. Plot prediction graphs

## 1. Data organisation - setting categorical variables as factors, scaling & putting all into dataframe
	## Prep variables -> Do not scale categorical variables! Sqrt % variables to improve model fit ##
	# Random effect variable
	Site<-as.factor(All_HC$Abbrev)

	# Fixed effect variables that change between phases (n=9)
	Phase<-as.factor(All_HC$Phase)
	R.dov<-All_HC$R.dov
	
	sTotal_FW<-scale(All_HC$Total_FW)
	sSqrt_Perc_uncleared_levels<-scale(All_HC$Sqrt_Perc_Uncleared_levels)
	sTotal_deterrence<-scale(All_HC$Total_deterrence)
	sStalls_opened<-scale(All_HC$Stalls_opened)
	sUncleared_crockery<-scale(All_HC$Uncleared_crockery)
	sActive_cleaners<-scale(All_HC$Active_cleaners) #remove
	sFeeding_incidences<-scale(All_HC$Feeding_incidences)
	Weather<-as.factor(All_HC$Weather) #remove

	# Fixed effect variables that are constant across phases (n=7)
	sTotal_length<-scale(All_HC$Total_length)
	sTotal_openness<-scale(All_HC$Total_openness)
	sSqrt_Perc_HDB<-scale(All_HC$Sqrt_Perc_HDB)
	sSqrt_Perc_PNB<-scale(All_HC$Sqrt_Perc_PNB) #remove
	sDistance_to_MRT<-scale(All_HC$Distance_to_MRT)
	sDistance_to_bridge<-scale(All_HC$Distance_to_bridge)
	sDistance_to_drain<-scale(All_HC$Distance_to_drain) #remove
	
	All_HC_scaled<-data.frame(Phase, R.dov,
	sTotal_FW, sSqrt_Perc_uncleared_levels, 
	sTotal_deterrence, sStalls_opened, sUncleared_crockery, sActive_cleaners,
	sFeeding_incidences, sTotal_length, sTotal_openness,
	sSqrt_Perc_HDB, sSqrt_Perc_PNB, sDistance_to_MRT, 
	sDistance_to_bridge, sDistance_to_drain)

	sub_b4<-subset(All_HC_scaled, Phase=="before")
	sub_cb<-subset(All_HC_scaled, Phase=="cb")


## 2. Check for multicollinearity or VIF
	# Prep covariate dataframe
	All_HC_cov<-data.frame(sTotal_FW, sSqrt_Perc_uncleared_levels, 
	sTotal_deterrence, sStalls_opened, sUncleared_crockery, sActive_cleaners,
	sFeeding_incidences, sTotal_length, sTotal_openness,
	sSqrt_Perc_HDB, sSqrt_Perc_PNB, sDistance_to_MRT, 
	sDistance_to_bridge)

	# install.packages("corrplot")
	source("http://www.sthda.com/upload/rquery_cormat.r")
	rquery.cormat(All_HC_cov)
	rquery.cormat(All_HC_cov, type="flatten", graph=FALSE)
	cor(All_HC_cov)

	## Variance inflation factors -> VIF value > 5 = High collinearity ##
	# install.packages("car")
	library("car")
	vif(sAll_HC_Birds_Pmodel)
	vif(sAll_HC_Birds_NBmodel) # omitted acitve cleaners based on this model
	vif(Fpig_NBmodel)

	## Setting FULL data frame ##
	sAll_HC_Birds<-data.frame(Site, Phase, R.dov,
	sTotal_FW, sSqrt_Perc_uncleared_levels, sTotal_deterrence,
	sStalls_opened, sUncleared_crockery, sActive_cleaners,
	sFeeding_incidences, Weather, sTotal_length, sTotal_openness,
	sSqrt_Perc_HDB, sSqrt_Perc_PNB, sDistance_to_MRT, 
	sDistance_to_bridge, sDistance_to_drain)
	
	str(sAll_HC_Birds)


## 3. Run global model 
	## Poisson GLM - 12 covariates ##

	Fpig_Pmodel <- glm(formula = R.dov ~ Phase + sTotal_FW 
	+ sSqrt_Perc_uncleared_levels + sTotal_deterrence + sStalls_opened 
	+ sUncleared_crockery + sFeeding_incidences + sTotal_length 
	+ sTotal_openness + sSqrt_Perc_HDB + sDistance_to_MRT
	+ sDistance_to_bridge, data=sAll_HC_Birds, family=poisson)
	summary(Fpig_Pmodel)

	overdisp <- Fpig_Pmodel$deviance/Fpig_Pmodel$df.residual
	overdisp # 36.2, AIC 4118.2 - justifies using neg binomial

	## Negative binomial - 12 covariates ##
	library(lme4)

	Fpig_NBmodel <- glm(formula = R.dov ~ Phase + sTotal_FW 
	+ sSqrt_Perc_uncleared_levels + sTotal_deterrence + sStalls_opened 
	+ sUncleared_crockery + sFeeding_incidences + sTotal_length 
	+ sTotal_openness + sSqrt_Perc_HDB + sDistance_to_MRT
	+ sDistance_to_bridge, data=sAll_HC_Birds, family=negative.binomial(theta = 1))
	summary(Fpig_NBmodel) 

	overdisp <- Fpig_NBmodel$deviance/Fpig_NBmodel$df.residual
	overdisp # 1.19, AIC 1034 - much more acceptable over-dispersion statistic

## 4. Model selection using dredge function from MuMIn package or define a set of candidate models to compare AIC
	## Selecting model with dredge -> Pick lowest AIC and highest Weight ##
	library("MuMIn")
	library(arm) # runs display function
	 
	options(na.action=na.fail)

	dredge_NB<-dredge(Fpig_NBmodel, beta = c("sd"), evaluate = TRUE, rank = "AIC", trace = FALSE)
	top_model <- get.models(dredge_NB, subset=1)[[1]]
	top_model
	summary(top_model)
	display(top_model)
	# 7 predictors left, dispersion 1.1, AIC 1028.8
	# dropped uncleared lvls, stalls opened and uncleared crockery

	#top_models<-get.models(dredge_NB, subset= delta<2)
	#top_models
	#ma_fp<-model.avg(dredge_NB, subset = delta <=2)
	#summary(ma_fp)

## 5. Run model with random effects (i.e., GLMM)
	# GLMM Negative Binomial
	# We add Site as a random effect to top model (9 predictors)
	modelnbm_top<-glmer.nb(formula = R.dov ~ Phase + sTotal_FW 
	+ sTotal_deterrence + sFeeding_incidences + sTotal_length 
	+ sTotal_openness + sSqrt_Perc_HDB + sDistance_to_MRT
	+ sDistance_to_bridge + (1|Site), nAGQ=1, data=sAll_HC_Birds)
	summary(modelnbm_top) # AIC 1027.2

## 6. Use LRT (lrtest function) to see if mixed model is better fit than fixed effects only model
	library(lmtest)
	lrtest(modelnbm_top, top_model) # P < 0.05 - significantly better fit for GLMM

## 7. Model selection using drop1 function - further model refinement
	# Drop 1 variable from top model, and compare AIC for each one dropped 
	drop1(modelnbm_top, test="Chisq")
	?drop1

	# drop length
	modelnbm_top2<-glmer.nb(formula = R.dov ~ Phase + sTotal_FW 
	+ sTotal_deterrence + sFeeding_incidences
	+ sTotal_openness + sSqrt_Perc_HDB + sDistance_to_MRT
	+ sDistance_to_bridge + (1|Site), nAGQ=1, data=sAll_HC_Birds)
	summary(modelnbm_top1a) # AIC 1026.5

	# Examine the predictors for dropping in top model, drop the non-signficant ones 
	drop1(modelnbm_top2, test="Chisq") # AIC for all subsequent models all higher

## 8. Model validation using simulateResiduals function from DHARMa package
	## Model validation for top model, modelnbm_top2 ##
	library(DHARMa)

	## introduce re.form = NULL for mixed models
	simulationOutput1 <- simulateResiduals(fittedModel = modelnbm_top2, re.form=NULL)
	plot(simulationOutput1)

## 9. Plot prediction graphs
	## Predicting how pigeon abundance varies with HDB and deterrence

	range(sSqrt_Perc_HDB) #-2.6 to 1.6
	range(sTotal_deterrence) #-1.7 to 3.1
	levels(Phase)
		
	#000000	black
	#E69F00	orange
	#56B4E9	skyblue
	#009E73	green
	#F0E442	yellow
	#0072B2	blue
	#D55E00	red
	#CC79A7	pink  

	lt.grey <- adjustcolor("#000000",alpha.f=0.2)
	lt.pink <- adjustcolor("#CC79A7",alpha.f=0.2)

	par(mfrow=c(1,2))
	par(mar=c(7.5,5,0.2,1.8))
		
	# R.pig - HDB #
	xHDB<- seq(-2.6,1.6,0.02)

	data_before<-data.frame(Phase = factor("before", levels=c("before","cb")), 
	sTotal_FW=mean(sub_b4$sTotal_FW), 
	sTotal_deterrence=mean(sub_b4$sTotal_deterrence),
	sFeeding_incidences=mean(sub_b4$sFeeding_incidences),
	sTotal_openness=mean(sub_b4$sTotal_openness),
	sSqrt_Perc_HDB=xHDB,
	sDistance_to_MRT=mean(sub_b4$sDistance_to_MRT),
	sDistance_to_bridge=mean(sub_b4$sDistance_to_bridge)
	)

	data_cb<-data.frame(Phase = factor("cb", levels=c("before","cb")), 
	sTotal_FW=mean(sub_cb$sTotal_FW), 
	sTotal_deterrence=mean(sub_cb$sTotal_deterrence),
	sFeeding_incidences=mean(sub_cb$sFeeding_incidences),
	sTotal_openness=mean(sub_cb$sTotal_openness),
	sSqrt_Perc_HDB=xHDB,
	sDistance_to_MRT=mean(sub_cb$sDistance_to_MRT),
	sDistance_to_bridge=mean(sub_cb$sDistance_to_bridge)
	)

	pred_before <- predict(modelnbm_top2, data_before, re.form=NA, type="response")
	pred_cb <- predict(modelnbm_top2, data_cb, re.form=NA, type="response")

	predframe <- data.frame(pred_before, pred_cb, xHDB)
	head(predframe)

	levels(sAll_HC_Birds$Phase)

	plot(R.dov ~ sSqrt_Perc_HDB, xlim=c(-2.6,1.6), ylim=c(0,210), 
	xlab="Public housing landuse cover (scaled)", 
	ylab="Feral pigeon abundance", cex.lab=1.1, col=c(lt.grey, lt.pink)[sAll_HC_Birds$Phase], pch=16)

	lines(predframe$pred_before ~ predframe$xHDB, col="#000000", lwd=2)
	lines(predframe$pred_cb ~ predframe$xHDB, col="#CC79A7", lwd=2, lty=2) # pink


	# R.pig - Deterrence #
	xdeter<- seq(-1.7,3.1,0.02)

	data_before<-data.frame(Phase = factor("before", levels=c("before","cb","enforce","phase 2")), 
	sTotal_FW=mean(sub_b4$sTotal_FW), 
	sTotal_deterrence=xdeter,
	sFeeding_incidences=mean(sub_b4$sFeeding_incidences),
	sTotal_openness=mean(sub_b4$sTotal_openness),
	sSqrt_Perc_HDB=mean(sub_b4$sSqrt_Perc_HDB),
	sDistance_to_MRT=mean(sub_b4$sDistance_to_MRT),
	sDistance_to_bridge=mean(sub_b4$sDistance_to_bridge)
	)

	data_cb<-data.frame(Phase = factor("cb", levels=c("before","cb","enforce","phase 2")), 
	sTotal_FW=mean(sub_cb$sTotal_FW), 
	sTotal_deterrence=xdeter,
	sFeeding_incidences=mean(sub_cb$sFeeding_incidences),
	sTotal_openness=mean(sub_cb$sTotal_openness),
	sSqrt_Perc_HDB=mean(sub_cb$sSqrt_Perc_HDB),
	sDistance_to_MRT=mean(sub_cb$sDistance_to_MRT),
	sDistance_to_bridge=mean(sub_cb$sDistance_to_bridge)
	)

	pred_before <- predict(modelnbm_top2, data_before, re.form=NA, type="response")
	pred_cb <- predict(modelnbm_top2, data_cb, re.form=NA, type="response")

	predframe <- data.frame(pred_before, pred_cb, xdeter)

	plot(R.dov ~ sTotal_deterrence, xlim=c(-1.7,3.1), ylim=c(0,210), 
	xlab="Deterrence level (scaled)", 
	ylab="Feral pigeon abundance", cex.lab=1.1, col=c(lt.grey, lt.pink)[sAll_HC_Birds$Phase], pch=16)

	lines(predframe$pred_before ~ predframe$xdeter, col="#000000", lwd=2)
	lines(predframe$pred_cb ~ predframe$xdeter, col="#CC79A7", lwd=2, lty=2) # pink

	# Adding legend
	add_legend <- function(...) {
	  opar <- par(fig=c(0, 1, 0, 1), oma=c(0, 0, 0, 0), 
		mar=c(0, 0, 0, 0), new=TRUE)
	  on.exit(par(opar))
	  plot(0, 0, type='n', bty='n', xaxt='n', yaxt='n')
	  legend(...)
	}
	add_legend("bottom", legend=c("Before CB", "CB"), 
	lty=c(1,2), lwd=2.5, col=c("#000000", "#CC79A7"),
	horiz=TRUE, bty=FALSE, cex=1.1, inset=0.01, xjust=0)