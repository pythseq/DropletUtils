# Testing the downsampleCounts function.
# library(DropletUtils); library(testthat); source("test-downsample.R")

test_that("downsampling is correct", {
    CHECKFUN <- function(input, prop) {
        out <- scater:::downsampleCounts(input, prop)
        expect_identical(colSums(out), round(colSums(input)*prop))
        expect_true(all(out <= input))
        return(invisible(NULL))
    }

    # Vanilla run.
    set.seed(0)
    ncells <- 100
    u1 <- matrix(rpois(20000, 5), ncol=ncells)
    set.seed(100)
    CHECKFUN(u1, 0.111) # Avoid problems with different rounding of 0.5.
    CHECKFUN(u1, 0.333) # Avoid problems with different rounding of 0.5.
    CHECKFUN(u1, 0.777) # Avoid problems with different rounding of 0.5.

    u2 <- matrix(rpois(20000, 1), ncol=ncells)
    set.seed(101)
    CHECKFUN(u2, 0.111) # Avoid problems with different rounding of 0.5.
    CHECKFUN(u2, 0.333) # Avoid problems with different rounding of 0.5.
    CHECKFUN(u2, 0.777) # Avoid problems with different rounding of 0.5.

    # Checking double-precision inputs.
    v1 <- u1
    storage.mode(v1) <- "double"
    set.seed(200)
    CHECKFUN(v1, 0.111)
    CHECKFUN(v1, 0.333)
    CHECKFUN(v1, 0.777)

    v2 <- u2
    storage.mode(v2) <- "double"
    set.seed(202)
    CHECKFUN(v2, 0.111)
    CHECKFUN(v2, 0.333)
    CHECKFUN(v2, 0.777)

    # Checking vectors of proportions.
    set.seed(300)
    CHECKFUN(u1, runif(ncells))
    CHECKFUN(u1, runif(ncells, 0, 0.5))
    CHECKFUN(u1, runif(ncells, 0.1, 0.2))

    set.seed(303)
    CHECKFUN(u2, runif(ncells))
    CHECKFUN(u2, runif(ncells, 0, 0.5))
    CHECKFUN(u2, runif(ncells, 0.1, 0.2))

    # Checking sparse matrix inputs.
    library(Matrix)
    w1 <- as(v1, "dgCMatrix")
    set.seed(400)
    CHECKFUN(w1, 0.111)
    CHECKFUN(w1, 0.333)
    CHECKFUN(w1, 0.777)

    w2 <- as(v2, "dgCMatrix")
    set.seed(404)
    CHECKFUN(w2, 0.111)
    CHECKFUN(w2, 0.333)
    CHECKFUN(w2, 0.777)

    # Checking that the sampling scheme is correct (as much as possible).
    set.seed(500)
    known <- matrix(1:5, nrow=5, ncol=10000)
    prop <- 0.51
    truth <- known[,1]*prop
    out <- scater:::downsampleCounts(known, prop)
    expect_true(all(abs(rowMeans(out)/truth - 1) < 0.1)) # Less than 10% error on the estimated proportions.

    known <- matrix(1:5*10, nrow=5, ncol=10000)
    prop <- 0.51
    truth <- known[,1]*prop
    out <- scater:::downsampleCounts(known, prop)
    expect_true(all(abs(rowMeans(out)/truth - 1) < 0.01)) # Less than 1% error on the estimated proportions.
})
