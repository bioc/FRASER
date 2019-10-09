#'
#' Feature exclusion
#'
#' To remove certain junctions from being used in the train step of the
#' encoding dimension we can set the \code{featureExclusion} vector to
#' \code{FALSE}. This can be helpfull if we have local linkage between
#' features which we do not want to model by the autoencoder.
#'
#' @param ods An OutriderDataSet object
#' @param value A logical vector of the length of the features. If
#'             \code{TRUE}, the corresponding feature will be excluded
#'             from the encoding dimension fit.
#' @return The exclusion vector
#'
#' @name featureExclusionMask
#' @rdname featureExclusionMask
#' @aliases featureExclusionMask, `featureExclusionMask<-`
#'
#' @examples
#' ods <- makeExampleFraseRDataSet()
#' featureExclusionMask(fds) <- sample(c(FALSE, TRUE), nrow(fds), replace=TRUE)
#'
#' featureExclusionMask(fds)
#'
#' @export featureExclusionMask
#' @export "featureExclusionMask<-"
featureExclusionMask <- function(fds, type=currentType(fds)){
    ans <- rep(TRUE, nrow(mcols(fds, type=type)))
    if(paste0('featureExclude_', type) %in% colnames(mcols(fds, type=type))){
        ans <- mcols(fds, type=type)[[paste0('featureExclude_', type)]]
    }
    # TODO names(ans, type=type) <- rownames(fds, type=type)
    return(ans)
}

#' @rdname featureExclusionMask
#' @export "featureExclusionMask<-"
`featureExclusionMask<-` <- function(fds, value, type=currentType(fds)){
    if(isScalarLogical(value)){
        value <- rep(value, nrow(mcols(fds, type=type)))
    }
    mcols(fds, type=type)[[paste0('featureExclude_', type)]] <- value
    return(fds)
}

K <- function(fds, type=currentType(fds)){
    K <- counts(fds, type=type, side="ofInterest")
    return(K);
}

N <- function(fds, type=currentType(fds)){
    N <- K(fds, type=type) + counts(fds, type=type, side="other")
    return(N);
}

x <- function(fds, type=currentType(fds), all=FALSE,
                    noiseAlpha=currentNoiseAlpha(fds), center=TRUE){
    K <- K(fds, type=type)
    N <- N(fds, type=type)

    # compute logit ratio with pseudocounts
    x <- t((K + pseudocount())/(N + (2*pseudocount())))
    x <- qlogis(x)

    if(any(is.infinite(x))){
        x[is.infinite(x) & x > 0] <- NA
        x[is.na(x)] <- max(x, na.rm=TRUE) + 1
    }

    # corrupt x if required
    if(!is.null(noiseAlpha)){
        noise <- noise(fds, type=type)
        if(is.null(noise)){
            noise <- matrix(rnorm(prod(dim(x))), ncol=ncol(x), nrow=nrow(x))
            noise(fds, type=type) <- noise
        }
        x <- x + t(colSds(x) * noiseAlpha * t(noise))
    }

    if(isFALSE(all)){
        x <- x[,featureExclusionMask(fds, type=type)]
    }
    if(isTRUE(center)){
        x <- t(t(x) - colMeans2(x))
    }

    return(x)
}

H <- function(fds, type=currentType(fds), noiseAlpha=NULL){
    x(fds, all=FALSE, type=type, noiseAlpha=noiseAlpha) %*% E(fds, type=type)
}

`D<-` <- function(fds, value, type=currentType(fds)){
    if(!is.matrix(value)){
        value <- matrix(value, nrow=nrow(fds))
    }
    metadata(fds)[[paste0('D_', type)]] <- value
    return(fds)
}

D <- function(fds, type=currentType(fds)){
    return(metadata(fds)[[paste0('D_', type)]])
}

`E<-` <- function(fds, value, type=currentType(fds)){
    if(!is.matrix(value)){
        value <- matrix(value, nrow=sum(featureExclusionMask(fds, type=type)))
    }
    metadata(fds)[[paste0('E_', type)]] <- value
    return(fds)
}

E <- function(fds, type=currentType(fds)){
    return(metadata(fds)[[paste0('E_', type)]])
}

`b<-` <- function(fds, value, type=currentType(fds)){
    mcols(fds, type=type)[[paste0('b_', type)]] <- value
    return(fds)
}

b <- function(fds, type=currentType(fds)){
    return(mcols(fds, type=type)[[paste0('b_', type)]])
}

`rho<-` <- function(fds, value, type=currentType(fds)){
    mcols(fds, type=type)[[paste0('rho_', type)]] <- value
    return(fds)
}

rho <- function(fds, type=currentType(fds)){
    return(mcols(fds, type=type)[[paste0('rho_', type)]])
}

predictMu <- function(fds, type=currentType(fds), noiseAlpha=NULL){
    y <- predictY(fds, type=type, noiseAlpha=noiseAlpha)
    mu <- predictMuCpp(y)
    return(t(mu))
}

predictY <- function(fds, type=currentType(fds), noiseAlpha=NULL){
    D <- D(fds, type=type)
    b <- b(fds, type=type)
    H <- H(fds, type=type, noiseAlpha=noiseAlpha)

    y <- predictYCpp(as.matrix(H), D, b)

    return(t(y))
}


`setAssayMatrix<-` <- function(fds, value, name, type, ...){
    if(!is.matrix(value)){
        value <- matrix(value, ncol=ncol(fds), nrow=nrow(mcols(fds, type=type)))
    }
    if(is.null(colnames(value))){
        colnames(value) <- colnames(fds)
    }
    if(is.null(rownames(value))){
        rownames(value) <- rownames(counts(fds, type=type))
    }
    if(missing(name)){
        name <- type
    } else {
        name <- paste(name, type, sep="_")
    }
    assay(fds, name, ...) <- value
    fds
}

getAssayMatrix <- function(fds, name, type){
    if(missing(name)){
        name <- type
    } else {
        name <- paste(name, type, sep="_")
    }
    assay(fds, name)
}

zScores <- function(fds, type=currentType(fds)){
    return(getAssayMatrix(fds, name='zScores', type=type))
}

`zScores<-` <- function(fds, value, type=currentType(fds), ...){
    setAssayMatrix(fds, name="zScores", type=type, ...) <- value
    return(fds)
}

pVals <- function(fds, type=currentType(fds),
                    dist=c("BetaBinomial", "Binomial"), byGroup=FALSE){
    dist <- match.arg(dist)
    if(isTRUE(byGroup)){
        index <- getSiteIndex(fds, type=type)
        idx   <- !duplicated(index)
        return(getAssayMatrix(fds, paste0("pvalues", dist), type=type)[idx,])
    }
    return(getAssayMatrix(fds, paste0("pvalues", dist), type=type))
}

`pVals<-` <- function(fds, value, type=currentType(fds),
                    dist=c("BetaBinomial", "Binomial"), ...){
    dist <- match.arg(dist)
    setAssayMatrix(fds, name=paste0("pvalues", dist), type=type, ...) <- value
    return(fds)
}

padjVals <- function(fds, type=currentType(fds),
                    dist=c("BetaBinomial", "Binomial"), byGroup=FALSE){
    dist <- match.arg(dist)
    if(isTRUE(byGroup)){
        index <- getSiteIndex(fds, type=type)
        idx   <- !duplicated(index)
        return(getAssayMatrix(fds, paste0("pajd", dist), type=type)[idx,])
    }
    return(getAssayMatrix(fds, paste0("pajd", dist), type=type))
}

`padjVals<-` <- function(fds, value, type=currentType(fds),
                    dist=c("BetaBinomial", "Binomial"), ...){
    dist <- match.arg(dist)
    setAssayMatrix(fds, name=paste0("pajd", dist), type=type, ...) <- value
    return(fds)
}

predictedMeans <- function(fds, type=currentType(fds)){
    return(getAssayMatrix(fds, name="predictedMeans", type=type))
}

`predictedMeans<-` <- function(fds, value, type=currentType(fds), ...){
    setAssayMatrix(fds, name="predictedMeans", type=type, ...) <- value
    return(fds)
}

currentType <- function(fds){
    return(metadata(fds)[['currentType']])
}

`currentType<-` <- function(fds, value){
    stopifnot(isScalarCharacter(whichPSIType(value)))
    metadata(fds)[['currentType']] <- whichPSIType(value)
    return(fds)
}

#'
#' Set/get global pseudo count option
#'
#' Set and returns the pseudo count used within the FraseR fitting procedure.
#'
#' @examples
#' # set
#' pseudocount(4L)
#'
#' # get
#' psuedocount()
#'
#' @export
pseudocount <- function(value){
    # return if not provided
    if(missing(value)){
        ans <- options()[['FraseR.pseudoCount']]
        if(isScalarNumeric(ans)){
            return(ans)
        }
        return(1)
    }

    # set pseudo count if provided
    stopifnot(isScalarNumeric(value))
    stopifnot(value >= 0)
    value <- as.integer(value)
    options('FraseR.pseudoCount'=value)
    setPseudoCount(value)

    invisible(value)
}

currentNoiseAlpha <- function(fds){
    return(metadata(fds)[['noiseAlpha']])
}

`currentNoiseAlpha<-` <- function(fds, value){
    metadata(fds)[['noiseAlpha']] <- value
    return(fds)
}

noise <- function(fds, type=currentType(fds)){
    return(t(getAssayMatrix(fds, name="noise", type=type)))
}

`noise<-` <- function(fds, value, type=currentType(fds), HDF5=FALSE, ...){
    if(!is.matrix(value)){
        value <- matrix(value, nrow=nrow(mcols(fds, type=type)), ncol=ncol(fds))
    }
    setAssayMatrix(fds, name='noise', type=type, HDF5=HDF5) <- t(value)
    return(fds)
}

hyperParams <- function(fds, type=currentType(fds), all=FALSE){
    ans <- metadata(fds)[[paste0("hyperParams_", type)]]
    if(is.null(ans)){
        return(ans)
    }
    if(isFALSE(all)){
        ans <- ans[aroc == max(aroc)][1]
    }
    ans
}

`hyperParams<-` <- function(fds, type=currentType(fds), value){
    metadata(fds)[[paste0("hyperParams_", type)]] <- value
    return(fds)
}

bestQ <- function(fds, type=currentType(fds)){
    ans <- hyperParams(fds, type=type)[1,q]
    if(is.null(ans)){
        warnings("Please set q by estimating it correctly.")
        ans <- min(100, max(2, round(ncol(fds)/10)))
    }
    return(as.integer(ans))
}

bestNoise <- function(fds, type=currentType(fds)){
    ans <- hyperParams(fds, type=type)[1,noise]
    if(is.null(ans)){
        warnings("Please set noise by estimating it correctly.")
        ans <- 1
    }
    as.numeric(as.character(ans))
}

#' @export
dontWriteHDF5 <- function(fds){
    return(metadata(fds)[['dontWriteHDF5']])
}

#' @export
`dontWriteHDF5<-` <- function(fds, value){
    metadata(fds)[['dontWriteHDF5']] <- isTRUE(value)
    return(fds)
}

getTrueOutlierByGroup <- function(fds, type, BPPARAM=parallel(fds)){
    index <- getSiteIndex(fds, type)
    idx   <- !duplicated(index)

    dt <- cbind(data.table(id=index),
            as.data.table(getAssayMatrix(fds, "trueOutliers", type)))
    setkey(dt, id)
    labels <- matrix(unlist(bplapply(samples(fds), BPPARAM=BPPARAM, function(i){
            dttmp <- dt[,any(get(i) != 0),by=id]
            setkey(dttmp, id)
            dttmp[J(unique(index)), V1]})), ncol=length(samples(fds))) + 0
    return(labels)
}

getAbsMaxByGroup <- function(fds, type, mat, BPPARAM=parallel(fds)){
    index <- getSiteIndex(fds, type)
    idx   <- !duplicated(index)

    dt <- cbind(data.table(id=index), as.data.table(mat))
    setkey(dt, id)
    deltaPsi <- matrix(unlist(bplapply(samples(fds), BPPARAM=BPPARAM,
        function(i){
                dttmp <- dt[,.(dpsi=get(i), max=max(abs(get(i)))),by=id]
                dttmp <- dttmp[abs(dpsi) == max, .SD[1], by=id]
                setkey(dttmp, id)
                dttmp[J(unique(index)), dpsi]})), ncol=length(samples(fds)))
    return(deltaPsi)
}

getByGroup <- function(fds, type, value){
    index <- getSiteIndex(fds, type)
    idx   <- !duplicated(index)
    return(value[idx,])
}

getDeltaPsi <- function(fds, type, byGroup=FALSE){
    mu <- predictedMeans(fds, type)
    dataPsi <- (K(fds, type)+pseudocount()) /(N(fds, type)+2*pseudocount())
    deltaPSI <- dataPsi-mu
    if(isTRUE(byGroup)){
        deltaPSI <- getAbsMaxByGroup(fds, psiType, deltaPSI)
    }
    return(deltaPSI)
}


# calculate FraseR weights
calcFraseRWeights <- function(fds, psiType){
    k <- as.matrix(K(fds, psiType))
    n <- as.matrix(N(fds, psiType))
    mu <- t(predictMu(fds, psiType))
    rho <- rho(fds, psiType)
    dataPsi <- plogis(t(
            x(fds, type=psiType, all=TRUE, center=FALSE, noiseAlpha=NULL)))

    # pearson residuals for BB
    # on counts of success k
    # r <- ((k+pseudocount()) - (n+2*pseudocount()) * mu) / sqrt(
    #       (n+2*pseudocount()) * mu * (1-mu) *
    #       (1+((n+2*pseudocount())-1)*rho))
    # on probability of success mu
    r <- (dataPsi - mu) / sqrt(
            mu * (1-mu) * (1+((n+2*pseudocount())-1)*rho) /
            (n+2*pseudocount()))

    # weights according to Huber function (as in edgeR)
    c <- 1.345; # constant, as suggested in edgeR paper
    w <- ifelse(abs(r) > c, c/abs(r) , 1)

    return(w)
}

# get FraseR weights
weights <- function(fds, type){
    return(getAssayMatrix(fds, "weights", type))
}

# set FraseR weights
`weights<-` <- function(fds, value, type=currentType(fds), ...){
    setAssayMatrix(fds, name="weights", type=type, ...) <- value
    return(fds)
}

getIndexFromResultTable <- function(fds, resultTable, padj.method="holm"){
    type <- as.character(resultTable$type)
    target <- makeGRangesFromDataFrame(resultTable)
    if(type == "psiSite"){
        gr <- granges(asSE(nonSplicedReads(fds)))
    } else {
        gr <- granges(asSE(fds))
    }

    hits <- findOverlaps(target, gr, type="equal")
    ov <- to(hits)
    if(!isScalarInteger(ov)){
        stop("Can not find the given range within the FraseR object.")
    }
    ov
}

getPlottingDT <- function(fds, axis=c("row", "col"), type=NULL,
                    result=NULL, idx=NULL, aggregate=FALSE){
    if(!is.null(result)){
        type <- as.character(result$type)
        idx  <- getIndexFromResultTable(fds, result)
    }

    axis <- match.arg(axis)
    idxrow <- idx
    idxcol <- TRUE
    if(axis == "col"){
        idxcol <- idx
        if(is.character(idx)){
            idxcol <- colnames(fds) %in% idx
        }
        idxrow <- TRUE
    }

    k <- K(fds, type)[idxrow, idxcol]
    n <- N(fds, type)[idxrow, idxcol]

    dt <- data.table(
        idx       = idx,
        k         = k,
        n         = n,
        pval      = pVals(fds, type=type)[idxrow, idxcol],
        padj      = padjVals(fds, type=type)[idxrow, idxcol],
        zscore    = zScores(fds, type=type)[idxrow, idxcol],
        obsPsi    = (k + pseudocount())/(n + 2*pseudocount()),
        predPsi   = predictedMeans(fds, type)[idxrow, idxcol],
        sampleID  = as.character(colnames(K(fds, type))[idxcol]),
        featureID = as.character(rownames(K(fds, type)[idxrow,])),
        type      = type)

    dt[,deltaPsi:=obsPsi - predPsi]

    if("hgnc_symbol" %in% colnames(mcols(fds, type=type))){
        dt[,featureID:=mcols(fds, type=type)[idxrow,"hgnc_symbol"]]
    }

    # if requested return gene p values (correct for multiple testing again)
    if(isTRUE(aggregate)){
        dt <- dt[!is.na(featureID)]

        # correct by gene and take the smallest p value
        dt <- dt[, pval:=p.adjust(pval, method=padj.method),
                    by="sampleID,featureID"]
        dt <- dt[order(featureID, pval)][!duplicated(featureID)]
        dt <- dt[, padj:=p.adjust(pval, method="BY"), by="sampleID,featureID"]
    }

    dt
}


#'
#' Verbosity level of package
#'
#' Dependend on the level of verbosity the algorithm reports more or less to
#' the user. 0 means being quiet and 10 means everything.
#'
#' @rdname verbose
#' @export
verbose <- function(fds){
    if("verbosity" %in% names(metadata(fds))){
        return(metadata(fds)[["verbosity"]])
    }
    return(0)
}

#' @rdname verbose
#' @export
`verbose<-` <- function(fds, value){
    verbose <- value
    if(is.logical(verbose)){
        verbose <- verbose + 0
    }
    checkNaAndRange(verbose, min=0, max=10, na.ok=FALSE)
    metadata(fds)[["verbosity"]] <- floor(verbose)
    return(fds)
}