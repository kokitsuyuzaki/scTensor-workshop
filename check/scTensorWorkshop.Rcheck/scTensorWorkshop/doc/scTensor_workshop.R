## ----knitr, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  warning = FALSE,
  message = FALSE,
  fig.height = 7,
  fig.width = 10
)
options(knitr.duplicate.label = "allow")

## ----sctensor-----------------------------------------------------------------
library("scTensor")

data(GermMale) # Matrix (242 genes x 852 cells)
data(labelGermMale) # Vector (852 cells)
data(tsneGermMale) # Output object of Rtsne (852 cells x 2 coordinates)

## ----sce----------------------------------------------------------------------
library("SingleCellExperiment")

sce <- SingleCellExperiment(assays=list(counts = GermMale))

## ----readuceddims-------------------------------------------------------------
reducedDims(sce) <- SimpleList(TSNE=tsneGermMale$Y)

## ----normcounts---------------------------------------------------------------
CPMED <- function(input){
    libsize <- colSums(input)
    median(libsize) * t(t(input) / libsize)
}

normcounts(sce) <- log10(CPMED(counts(sce)) + 1)

## ----annotationhub------------------------------------------------------------
library("AnnotationHub")

ah <- AnnotationHub()
dbfile <- query(ah, c("LRBaseDb", c("Homo sapiens", "v002")))[[1]]

## ----lrbasedbi----------------------------------------------------------------
library("LRBaseDbi")

LRBase.Hsa.eg.db <- LRBaseDbi::LRBaseDb(dbfile)

## ----cellcellsetting----------------------------------------------------------
cellCellSetting(sce, LRBase.Hsa.eg.db, names(labelGermMale))
str(metadata(sce))

## ----cellcellranks------------------------------------------------------------
rks <- cellCellRanks(sce, assayNames="normcounts")

## ----cellcelldecomp-----------------------------------------------------------
set.seed(1234)
cellCellDecomp(sce, ranks=rks$selected, assayNames="normcounts")

## ----cellcellreport-----------------------------------------------------------
tmpdir <- tempdir()
cellCellReport(sce, reducedDimNames="TSNE", out.dir=tmpdir,
    assayNames="normcounts",
    title="Cell-cell interaction within Germline_Male, GSE86146",
    author="Koki Tsuyuzaki", html.open=FALSE, upper=2,
    goenrich=TRUE, meshenrich=FALSE, reactomeenrich=FALSE,
    doenrich=FALSE, ncgenrich=FALSE, dgnenrich=FALSE)
list.files(tmpdir)

## ----cellcellsimulate---------------------------------------------------------
params <- newCCSParams()
getParam(params, "nGene")
getParam(params, "nCell")
getParam(params, "cciInfo")
setParam(params, "nGene") <- 100
setParam(params, "nCell") <- c(10, 10, 10)
setParam(params, "cciInfo") <- list(
    nPair=50,
    CCI1=list(LPattern=c(1,0,0),
        RPattern=c(0,1,0),
        nGene=10, fc="E10"))

out_sim <- cellCellSimulate(params)
str(out_sim$input)
str(out_sim$LR)
geneL <- out_sim$LR[,"GENEID_L"]
geneR <- out_sim$LR[,"GENEID_R"]
L <- out_sim$input[geneL, ] # 50genes × 30cells
R <- out_sim$input[geneR, ] # 50genes × 30cells

## ----einsum-------------------------------------------------------------------
library("einsum")

CCItensor <- einsum::einsum('ij,kj->ikj', L, R)

## ----for----------------------------------------------------------------------
CCItensor2 <- array(0, dim=c(nrow(L), nrow(R), ncol(L)))
for(i in 1:nrow(L)){
    for(j in 1:ncol(L)){
        for(k in 1:nrow(R)){
            CCItensor2[i,k,j] <- L[i,j] * R[k,j]
        }
    }
}
identical(CCItensor, CCItensor2)

## ----rtensor------------------------------------------------------------------
library("rTensor")

CCItensor <- as.tensor(CCItensor)
is(CCItensor)
str(CCItensor@data) # Array data

## ----arithmetic---------------------------------------------------------------
rTensor::modeSum(CCItensor, m=1, drop=TRUE) # Summation in a mode
rTensor::cs_unfold(CCItensor, m=1) # Matricizing
rTensor::fnorm(CCItensor) # Frobenius Norm

## ----nntensor-----------------------------------------------------------------
library("nnTensor")

out_nn <- nnTensor::NTD(CCItensor, algorithm="KL", rank=c(3,4,5), verbose=TRUE)
str(out_nn$A) # Factor matrices
str(out_nn$S) # Core tensor

## ----delayedtensor1-----------------------------------------------------------
library("HDF5Array")
library("DelayedArray")
library("DelayedTensor")

options(delayedtensor.sparse = FALSE) # Sparse mode off
options(delayedtensor.verbose = TRUE) # Verbose message on
setHDF5DumpCompressionLevel(level=9L) # No compression inside of HDF5 file
setHDF5DumpDir(tmpdir) # Pass to save the temporary HDF5 files
setAutoBlockSize(size=1E+7) # Data size loaded on the memory at once

## ----delayedtensor2-----------------------------------------------------------
darr_L <- DelayedArray(L)
darr_R <- DelayedArray(R)

## ----delayedtensor3-----------------------------------------------------------
darr_CCItensor <- DelayedTensor::einsum('ij,kj->ikj', darr_L, darr_R)

## ----delayedtensor4-----------------------------------------------------------
DelayedTensor::modeSum(darr_CCItensor, m=1, drop=TRUE)
DelayedTensor::cs_unfold(darr_CCItensor, m=1)
DelayedTensor::fnorm(darr_CCItensor)

## ----mwtensor-----------------------------------------------------------------
library("mwTensor")

Xs <- mwTensor::toyModel("coupled_CP_Easy")
params <- new("CoupledMWCAParams", Xs=Xs, verbose=TRUE)
out_mw <- CoupledMWCA(params)
str(out_mw@common_factors)
str(out_mw@common_cores)

## -----------------------------------------------------------------------------
sessionInfo()

