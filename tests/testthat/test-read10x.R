# Testing the read10xCounts function.
# library(DropletUtils); library(testthat); source("test-read10x.R")

set.seed(1000)
library(Matrix)
tmpdir <- tempfile()

# Mocking up some 10X genomics output.
my.counts <- matrix(rpois(1000, lambda=5), ncol=10, nrow=100)
my.counts <- as(my.counts, "dgCMatrix")

ngenes <- nrow(my.counts)
gene.ids <- paste0("GENE", seq_len(ngenes))
gene.symb <- paste0(sample(LETTERS, replace=TRUE, ngenes),
                    sample(LETTERS, replace=TRUE, ngenes),
                    sample(LETTERS, replace=TRUE, ngenes), "-",
                    sample(9, replace=TRUE, ngenes))

cell.ids <- paste0("BARCODE-", seq_len(ncol(my.counts)))

################################################

test_that("write10xCounts works correctly for sparse counts", {
    write10xCounts(path=tmpdir, my.counts, gene.id=gene.ids, gene.symbol=gene.symb, barcodes=cell.ids)
    expect_identical(sort(list.files(tmpdir)), c("barcodes.tsv", "genes.tsv", "matrix.mtx"))
    all.sizes <- file.info(list.files(tmpdir, full=TRUE))$size

    # Checking overwrite.
    expect_error(write10xCounts(path=tmpdir, my.counts, gene.id=gene.ids, gene.symbol=gene.symb, barcodes=cell.ids),
                 "specified 'path' already exists", fixed=TRUE)
    write10xCounts(path=tmpdir, my.counts, gene.id=gene.ids, gene.symbol=gene.symb, barcodes=cell.ids, overwrite=TRUE)
    expect_identical(all.sizes, file.info(list.files(tmpdir, full=TRUE))$size)

    # Checking lengths.
    expect_error(write10xCounts(path=tmpdir, my.counts, gene.id=gene.ids, gene.symbol=gene.symb), "barcodes")
    expect_error(write10xCounts(path=tmpdir, my.counts, barcodes=cell.ids, gene.symbol=gene.symb), "lengths of 'gene.id' and 'gene.symbol'")
    expect_error(write10xCounts(path=tmpdir, my.counts, barcodes=cell.ids, gene.id=gene.ids, gene.symbol=""), "lengths of 'gene.id' and 'gene.symbol'")

    all.sizes <- file.info(list.files(tmpdir, full=TRUE))$size # files should still be there after all those errors.
    expect_identical(all.sizes, file.info(list.files(tmpdir, full=TRUE))$size)

    # Checking default arguments.
    new.counts <- my.counts
    rownames(new.counts) <- gene.ids
    colnames(new.counts) <- cell.ids
    write10xCounts(path=tmpdir, new.counts, gene.symbol=gene.symb, overwrite=TRUE)
    expect_identical(all.sizes, file.info(list.files(tmpdir, full=TRUE))$size)
})

tmph5 <- tempfile(fileext=".h5")
test_that("write10xCounts works correctly for HDF5 counts", {
    write10xCounts(path=tmph5, group="mm9", my.counts, gene.id=gene.ids, gene.symbol=gene.symb, barcodes=cell.ids)
    all_fields <- rhdf5::h5ls(tmph5)
    expect_identical(all_fields$name, c("mm9", "barcodes", "data", "gene_names", "genes", "indices", "indptr", "shape"))
    all.sizes <- file.info(list.files(tmph5, full=TRUE))$size

    # Checking overwrite.
    expect_error(write10xCounts(path=tmph5, my.counts, gene.id=gene.ids, gene.symbol=gene.symb, barcodes=cell.ids),
                 "specified 'path' already exists", fixed=TRUE)
    write10xCounts(path=tmph5, my.counts, gene.id=gene.ids, gene.symbol=gene.symb, barcodes=cell.ids, overwrite=TRUE)
    expect_identical(all.sizes, file.info(list.files(tmph5, full=TRUE))$size)
})

################################################

test_that("read10xCounts works correctly for sparse counts", {
    # Reading it in.
    sce10x <- read10xCounts(tmpdir)
    alt.counts <- my.counts
    rownames(alt.counts) <- gene.ids
    colnames(alt.counts) <- NULL

    expect_equal(counts(sce10x), alt.counts)
    expect_identical(rowData(sce10x)$ID, gene.ids)
    expect_identical(rowData(sce10x)$Symbol, gene.symb)
    expect_identical(sce10x$Sample, rep(tmpdir, ncol(my.counts)))
    expect_identical(sce10x$Barcode, cell.ids)

    # Reading it in, twice; and checking it makes sense.
    sce10x2 <- read10xCounts(c(tmpdir, tmpdir))
    ref <- sce10x
    colnames(ref) <- NULL
    ref <- BiocGenerics::cbind(ref, ref)
    expect_equal(ref, sce10x2)

    # Checking that column names work.
    sce10x3 <- read10xCounts(tmpdir, col.names=TRUE)
    expect_identical(colnames(sce10x3), sce10x3$Barcode)
    sce10x4 <- read10xCounts(c(tmpdir, tmpdir), col.names=TRUE)
    expect_identical(colnames(sce10x4), NULL)
})

test_that("read10xCounts works for sparse counts with odd inputs", {
    # Checking that we are robust to odd symbols in the gene names.
    tmpdir2 <- tempfile()
    gene.symb2 <- paste0(gene.symb, sample(c("#", "'", '"', ""), length(gene.ids), replace=TRUE))
    write10xCounts(path=tmpdir2, my.counts, gene.id=gene.ids, gene.symbol=gene.symb2, barcodes=cell.ids)
    sce10x <- read10xCounts(tmpdir2)

    expect_identical(assay(sce10x, withDimnames=FALSE), my.counts)
    expect_identical(colData(sce10x)$Barcode, cell.ids)
    expect_identical(rowData(sce10x)$ID, gene.ids)
    expect_identical(rowData(sce10x)$Symbol, gene.symb2)

    # Checking that we are robust to names in the inputs. 
    sce10x2 <- read10xCounts(c(A=tmpdir2, B=tmpdir2))
    expect_identical(assay(sce10x2), cbind(assay(sce10x), assay(sce10x)))

    expect_identical(sce10x2$Barcode, rep(colData(sce10x)$Barcode, 2))
    expect_true(all(sce10x2$Sample==tmpdir2))
    expect_identical(names(sce10x2$Sample), rep(c("A", "B"), each=ncol(sce10x)))

    expect_identical(rowData(sce10x2)$ID, rowData(sce10x)$ID)
    expect_identical(rowData(sce10x2)$Symbol, gene.symb2)
})

test_that("read10xCounts works correctly for HDF5 counts", {
    # Reading it in.
    sce10x <- read10xCounts(tmph5)
    alt.counts <- as.matrix(my.counts)
    dimnames(alt.counts) <- NULL

    expect_equal(as.matrix(counts(sce10x, withDimnames=FALSE)), alt.counts)
    expect_identical(rowData(sce10x)$ID, gene.ids)
    expect_identical(rowData(sce10x)$Symbol, gene.symb)
    expect_identical(sce10x$Sample, rep(tmph5, ncol(my.counts)))
    expect_identical(sce10x$Barcode, cell.ids)

    # Reading it in, twice; and checking it makes sense.
    sce10x2 <- read10xCounts(c(tmph5, tmph5))
    ref <- sce10x
    colnames(ref) <- NULL
    ref <- BiocGenerics::cbind(ref, ref)
    expect_equal(ref, sce10x2)
})

################################################

test_that("Alternative readMM schemes work correctly", {
    path <- file.path(tmpdir, "matrix.mtx")
    ref <- as(readMM(path), "dgCMatrix")
    out <- read10xMatrix(path)
    expect_identical(ref, out)
    expect_error(read10xMatrix(path, hdf5.out=TRUE), "missing")

    # HDF5Matrix output. 
    ref2 <- as.matrix(ref)
    out <- read10xMatrix(path, chunk.size=10, hdf5.out=TRUE)
    expect_s4_class(out, "HDF5Matrix")
    expect_identical(type(out), "integer")
    expect_equivalent(ref2, as.matrix(out))

    # Chunk sizes equal to or larger than the number of non-zero entries.
    out <- read10xMatrix(path, chunk.size=sum(ref!=0), hdf5.out=TRUE)
    expect_s4_class(out, "HDF5Matrix")
    expect_equivalent(ref2, as.matrix(out))
    out <- read10xMatrix(path, chunk.size=sum(ref!=0)*10, hdf5.out=TRUE)
    expect_s4_class(out, "HDF5Matrix")
    expect_equivalent(ref2, as.matrix(out))

    # For real matrices instead.
    path2 <- file.path(tmpdir, "matrix2.mtx")
    X <- readLines(path)
    X <- sub("integer", "real", X)
    writeLines(con=path2, X)

    out <- read10xMatrix(path2, hdf5.out=TRUE, chunk.size=10)
    expect_s4_class(out, "HDF5Matrix")
    expect_identical(type(out), "double")
    expect_equivalent(ref2, as.matrix(out))

    X[-(1:2)] <- sub("$", ".5", X[-(1:2)])
    writeLines(con=path2, X)
    out <- read10xMatrix(path2, hdf5.out=TRUE, chunk.size=10)
    ref3 <- ref2
    ref3[ref2!=0] <- ref3[ref2!=0] + 0.5
    expect_equivalent(ref3, as.matrix(out))

    # Supplying a connection rather than a file path.
    expect_error(read10xMatrix(file(path)), "read mode")
    expect_error(read10xMatrix(DataFrame(path)), "connection")
    fhandle <- file(path, open="r")
    outh <- read10xMatrix(fhandle)
    close(fhandle)
    expect_identical(outh, ref)
})
