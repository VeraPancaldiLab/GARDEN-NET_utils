library(testthat)
library(stringr)
library(readr)
library(dplyr)
library(tidyr)
library(chaser)
library(igraph)
library(GenomicRanges)
source("../network_generator_lib.R")

# args <- parser_arguments(args = c("--PCHiC", "./input_datasets/Homo_sapiens-Mon.tsv", "--alias", "./alias_databases/Homo_sapiens.tsv", "--intronic_regions", "intronic_regions.tsv"))

rdata <- "/tmp/garden-net-test.Rdata"
if (!file.exists(rdata)) {
  mus_PCHiC_file <- "../input_datasets/Mus_musculus-Embryonic_stem_cells.tsv"
  mus_PCHiC <- read_tsv(
    file = mus_PCHiC_file,
    col_types = cols(baitChr = col_character(), oeChr = col_character())
  )
  homo_PCHiC_file <- "../input_datasets/Homo_sapiens-Mon.tsv"
  homo_PCHiC <- read_tsv(
    file = homo_PCHiC_file,
    col_types = cols(baitChr = col_character(), oeChr = col_character())
  )
  homo_PCHiC <- filter_by_threshold(homo_PCHiC, 5.0)
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net_homo <- make_chromnet(chaser_input_PCHiC_homo)
  homo_PCHiC <- add_PCHiC_types(homo_PCHiC, chaser_net_homo)
  homo_PCHiC_PP <- homo_PCHiC[homo_PCHiC$type == "P-P", ]
  mus_PCHiC <- filter_by_threshold(mus_PCHiC, 5.0)
  chaser_input_PCHiC_mus <- generate_input_chaser_PCHiC(mus_PCHiC)
  chaser_net_mus <- make_chromnet(chaser_input_PCHiC_mus)
  mus_PCHiC <- add_PCHiC_types(mus_PCHiC, chaser_net_mus)
  mus_PCHiC_PP <- mus_PCHiC[mus_PCHiC$type == "P-P", ]

  curated_PCHiC_vertex_mus <- generate_vertex(mus_PCHiC)
  curated_PCHiC_vertex_mus_PP <- generate_vertex(mus_PCHiC_PP)

  curated_PCHiC_vertex_homo <- generate_vertex(homo_PCHiC)
  curated_PCHiC_vertex_homo_PP <- generate_vertex(homo_PCHiC_PP)
  save(mus_PCHiC, mus_PCHiC_PP, curated_PCHiC_vertex_mus, curated_PCHiC_vertex_mus_PP, homo_PCHiC, homo_PCHiC_PP, curated_PCHiC_vertex_homo, curated_PCHiC_vertex_homo_PP, file = rdata)
} else {
  load(rdata, verbose = T)
}

context("Testing PCHiC")
test_that("Testing PCHiC columns", {
  expect_equal(colnames(mus_PCHiC)[1:14], c("baitChr", "baitStart", "baitEnd", "baitID", "baitName", "oeChr", "oeStart", "oeEnd", "oeID", "oeName", "dist", "mESC_wt", "mESC_Ring1A_KO", "mESC_Ring1A_1B_KO"))
  expect_equal(colnames(homo_PCHiC)[1:12], c("baitChr", "baitStart", "baitEnd", "baitID", "baitName", "oeChr", "oeStart", "oeEnd", "oeID", "oeName", "dist", "Mon"))
})

test_that("Testing PCHiC thresholds", {
  expect_equal(nrow(mus_PCHiC), 72231)
  expect_equal(nrow(homo_PCHiC), 171431)
  expect_true(all(homo_PCHiC[12] >= 5.0))
  expect_true(all(mus_PCHiC[12] >= 5.0))
})

test_that("Testing PCHiC chromosomes", {
  homo_PCHiC_chr1 <- filter_by_chromosome(homo_PCHiC, "1")
  expect_equal(nrow(homo_PCHiC_chr1), 16178)
  expect_equal(nrow(mus_PCHiC_PP), 21039)
  expect_equal(nrow(homo_PCHiC_PP), 21551)
  expect_equal(as.vector(table(mus_PCHiC$type)), c(51192, 21039))
  expect_equal(as.vector(table(homo_PCHiC$type)), c(149880, 21551))
  expect_true(all(homo_PCHiC_chr1$baitChr == "1" | homo_PCHiC_chr1$oeChr == "1"))
  expect_true(all(mus_PCHiC_PP$type == "P-P"))
})

context("Testing vertex")
test_that("Testing PCHiC vertex", {
  hoxa6_mus <- curated_PCHiC_vertex_mus_PP[grep("Hoxa6", curated_PCHiC_vertex_mus_PP$gene_names), ]

  hoxa6_homo <- curated_PCHiC_vertex_homo_PP[grep("Hoxa6", curated_PCHiC_vertex_homo_PP$gene_names, ignore.case = T), ]
  # }
  expect_equal(nrow(curated_PCHiC_vertex_mus), 55855)
  expect_equal(nrow(curated_PCHiC_vertex_mus_PP), 13099)
  # hoxa6
  expect_equal(unname(unlist(hoxa6_mus)), c("6_52157513_52163059", "Hoxa6", "6", "52157513", "52163059", "P"))

  expect_equal(nrow(curated_PCHiC_vertex_homo), 96443)
  expect_equal(nrow(curated_PCHiC_vertex_homo_PP), 10120)
  # hoxa6
  expect_equal(unname(unlist(hoxa6_homo)), c("7_27181769_27195103", "HOXA3 HOXA5 HOXA6 HOXA-AS3 RP1-170O19.22 RP1-170O19.23", "7", "27181769", "27195103", "P"))
})

context("Testing search EZH2 node")
test_that("Testing search EZH2 node", {
  curated_PCHiC_edges_mus <- generate_edges(mus_PCHiC)
  curated_PCHiC_vertex_mus
  # Alias needed to search by gene name
  mus_alias <- read_tsv("../alias_databases/Mus_musculus.tsv", col_types = cols(chr = col_character()))
  curated_PCHiC_vertex_mus <- generate_alias_mus(curated_PCHiC_vertex_mus, mus_alias)
  mus_ensembl2name <- mus_alias$`Gene name`
  names(mus_ensembl2name) <- mus_alias$`Ensembl gene ID`
  mus_net <- graph_from_data_frame(curated_PCHiC_edges_mus, directed = F, curated_PCHiC_vertex_mus)
  curated_PCHiC_vertex_mus$name <- curated_PCHiC_vertex_mus$fragment
  mus_net <- simplify(mus_net, edge.attr.comb = "first")
  curated_PCHiC_vertex_mus$name <- NULL

  mus_EZH2_subnetwork <- search_subnetwork(search = "EZH2", expand = 0, nearest = T, mus_net, curated_PCHiC_vertex_mus, mus_ensembl2name)

  expect_equal(length(V(mus_EZH2_subnetwork)), 7)
  expect_equal(count_components(mus_EZH2_subnetwork), 2)

  # Two connected components with EZH2 in the middle: the bigger one V5 and the smaller one V2

  expect_equal(degree(mus_EZH2_subnetwork)[[2]], 1)
  expect_equal(degree(mus_EZH2_subnetwork)[[5]], 4)

  expect_equal(neighbors(mus_EZH2_subnetwork, V(mus_EZH2_subnetwork)[[2]])$gene_names, c("Atp5g3"))
  expect_equal(neighbors(mus_EZH2_subnetwork, V(mus_EZH2_subnetwork)[[5]])$gene_names, c("Adck2", "CNTNAP2", "EZH2", "Stk31"))

  curated_PCHiC_edges_homo <- generate_edges(homo_PCHiC)
  curated_PCHiC_vertex_homo
  # Alias needed to search by gene name
  homo_alias <- read_tsv("../alias_databases/Homo_sapiens.tsv", col_types = cols(chr = col_character()))
  curated_PCHiC_vertex_homo <- generate_alias_homo(curated_PCHiC_vertex_homo, homo_alias)
  homo_ensembl2name <- homo_alias$`Gene name`
  names(homo_ensembl2name) <- homo_alias$`Ensembl gene ID`
  homo_net <- graph_from_data_frame(curated_PCHiC_edges_homo, directed = F, curated_PCHiC_vertex_homo)
  curated_PCHiC_vertex_homo$name <- curated_PCHiC_vertex_homo$fragment
  homo_net <- simplify(homo_net, edge.attr.comb = "first")
  curated_PCHiC_vertex_homo$name <- NULL

  homo_EZH2_subnetwork <- search_subnetwork(search = "EZH2", expand = 0, nearest = T, homo_net, curated_PCHiC_vertex_homo, homo_ensembl2name)

  expect_equal(length(V(homo_EZH2_subnetwork)), 27)
  expect_equal(count_components(homo_EZH2_subnetwork), 1)

  # One connected component with EZH2 in the middle: V5
  expect_equal(degree(homo_EZH2_subnetwork)[[5]], 24)

  expect_equal(neighbors(homo_EZH2_subnetwork, V(homo_EZH2_subnetwork)[[5]])$gene_names, c("CUL1", "EZH2", "", "", "", "", "", "", "", "", "", "", "", "", "", "CUL1", "CUL1", "CUL1", "RNY5", "RNY4", "", "RNY3", "RNY1", "ZNF398"))
})

context("Testing chaser package")
test_that("Testing features_on_nodes format from chaser package", {
  chaser_input_PCHiC_mus <- generate_input_chaser_PCHiC(mus_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_mus)
  initial_features <- NULL
  initial_features_position <- NULL
  features <- suppressMessages(read_tsv(file = "../input_datasets/Mus_musculus-Embryonic_stem_cells.features"))
  # Remove chr prefix from the fragment column
  features$fragment <- str_sub(features$fragment, start = 4)
  initial_features <- features
  curated_PCHiC_vertex_mus_with_features <- merge_features(curated_PCHiC_vertex_mus, initial_features)
  initial_features_position <- which(colnames(curated_PCHiC_vertex_mus_with_features) == colnames(initial_features)[2])
  chaser_input_features <- generate_input_chaser_features(curated_PCHiC_vertex_mus_with_features, initial_features_position)

  chaser_net <- chaser::load_features(chaser_net, chaser_input_features, type = "features_on_nodes", missingv = 0)

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(net_features_metadata$Abundance["EZH2"][[1]], 0.03)
  expect_equal(net_features_metadata$ChAs["EZH2"][[1]], 0.3345724571)
  expect_equal(net_features_metadata$`Mean degree`["EZH2"][[1]], 3.89)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(pp_net_features_metadata$Abundance["EZH2"][[1]], 0.05)
  expect_equal(pp_net_features_metadata$ChAs["EZH2"][[1]], 0.3732509223)
  expect_equal(pp_net_features_metadata$`Mean degree`["EZH2"][[1]], 2.94)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(po_net_features_metadata$Abundance["EZH2"][[1]], 0.03)
  expect_equal(po_net_features_metadata$ChAs["EZH2"][[1]], 0.3170121798)
  expect_equal(po_net_features_metadata$`Mean degree`["EZH2"][[1]], 2.71)
})

test_that("Testing macs2 format from chaser package", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../S01RHSH1.ERX1305388.H3K27me3.bwa.GRCh38.broad.20160630.bed.gz", type = "macs2", featname = "H3K27me3", missingv = 0))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["H3K27me3"][[1]], 3), 0.06)
  expect_equal(round(net_features_metadata$ChAs["H3K27me3"][[1]], 3), 0.149)
  expect_equal(round(net_features_metadata$`Mean degree`["H3K27me3"][[1]], 3), 4.05)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["H3K27me3"][[1]], 3), 0.07)
  expect_equal(round(pp_net_features_metadata$ChAs["H3K27me3"][[1]], 3), 0.127)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["H3K27me3"][[1]], 3), 3.2)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["H3K27me3"][[1]], 3), 0.06)
  expect_equal(round(po_net_features_metadata$ChAs["H3K27me3"][[1]], 3), 0.151)
  expect_equal(round(po_net_features_metadata$`Mean degree`["H3K27me3"][[1]], 3), 3.6)
})

test_that("Testing bed3 format from chaser package using default aggregate function (mean)", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../mono27acproc.bed", type = "bed3", featname = "mono27ac", missingv = 0))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["mono27ac"][[1]], 3), 1)
  expect_equal(round(net_features_metadata$ChAs["mono27ac"][[1]], 3), -0.094)
  expect_equal(round(net_features_metadata$`Mean degree`["mono27ac"][[1]], 3), 3.47)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["mono27ac"][[1]], 3), 1)
  expect_equal(round(pp_net_features_metadata$ChAs["mono27ac"][[1]], 3), 0.003)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["mono27ac"][[1]], 3), 3.44)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["mono27ac"][[1]], 3), 1)
  expect_equal(round(po_net_features_metadata$ChAs["mono27ac"][[1]], 3), -0.109)
  expect_equal(round(po_net_features_metadata$`Mean degree`["mono27ac"][[1]], 3), 3.15)
})

test_that("Testing bed3 format from chaser package using min aggregate function", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../mono27acproc.bed", type = "bed3", featname = "mono27ac", missingv = 0, auxfun = min))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["mono27ac"][[1]], 3), 1)
  expect_equal(round(net_features_metadata$ChAs["mono27ac"][[1]], 3), -0.094)
  expect_equal(round(net_features_metadata$`Mean degree`["mono27ac"][[1]], 3), 3.47)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["mono27ac"][[1]], 3), 1)
  expect_equal(round(pp_net_features_metadata$ChAs["mono27ac"][[1]], 3), 0.003)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["mono27ac"][[1]], 3), 3.44)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["mono27ac"][[1]], 3), 1)
  expect_equal(round(po_net_features_metadata$ChAs["mono27ac"][[1]], 3), -0.109)
  expect_equal(round(po_net_features_metadata$`Mean degree`["mono27ac"][[1]], 3), 3.15)
})

test_that("Testing bed3 format from chaser package using max aggregate function", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../mono27acproc.bed", type = "bed3", featname = "mono27ac", missingv = 0, auxfun = max))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["mono27ac"][[1]], 3), 1)
  expect_equal(round(net_features_metadata$ChAs["mono27ac"][[1]], 3), -0.094)
  expect_equal(round(net_features_metadata$`Mean degree`["mono27ac"][[1]], 3), 3.47)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["mono27ac"][[1]], 3), 1)
  expect_equal(round(pp_net_features_metadata$ChAs["mono27ac"][[1]], 3), 0.003)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["mono27ac"][[1]], 3), 3.44)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["mono27ac"][[1]], 3), 1)
  expect_equal(round(po_net_features_metadata$ChAs["mono27ac"][[1]], 3), -0.109)
  expect_equal(round(po_net_features_metadata$`Mean degree`["mono27ac"][[1]], 3), 3.15)
})

test_that("Testing bed6 format from chaser package using default aggregate function (mean)", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../mono-meth.bed6", type = "bed6", featname = "mono_meth", missingv = 0))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["mono_meth"][[1]], 3), 0.19)
  expect_equal(round(net_features_metadata$ChAs["mono_meth"][[1]], 3), 0.046)
  expect_equal(round(net_features_metadata$`Mean degree`["mono_meth"][[1]], 3), 6.27)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["mono_meth"][[1]], 3), 0.29)
  expect_equal(round(pp_net_features_metadata$ChAs["mono_meth"][[1]], 3), 0.181)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["mono_meth"][[1]], 3), 3.53)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["mono_meth"][[1]], 3), 0.19)
  expect_equal(round(po_net_features_metadata$ChAs["mono_meth"][[1]], 3), 0.032)
  expect_equal(round(po_net_features_metadata$`Mean degree`["mono_meth"][[1]], 3), 5.47)
})

test_that("Testing bed6 format from chaser package using min as aggregation function", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../mono-meth.bed6", type = "bed6", featname = "mono_meth", missingv = 0, auxfun = min))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["mono_meth"][[1]], 3), 0.15)
  expect_equal(round(net_features_metadata$ChAs["mono_meth"][[1]], 3), 0.021)
  expect_equal(round(net_features_metadata$`Mean degree`["mono_meth"][[1]], 3), 6.27)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["mono_meth"][[1]], 3), 0.14)
  expect_equal(round(pp_net_features_metadata$ChAs["mono_meth"][[1]], 3), 0.115)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["mono_meth"][[1]], 3), 3.53)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["mono_meth"][[1]], 3), 0.15)
  expect_equal(round(po_net_features_metadata$ChAs["mono_meth"][[1]], 3), 0.012)
  expect_equal(round(po_net_features_metadata$`Mean degree`["mono_meth"][[1]], 3), 5.47)
})

test_that("Testing bed6 format from chaser package using max as aggregation function", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../mono-meth.bed6", type = "bed6", featname = "mono_meth", missingv = 0, auxfun = max))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["mono_meth"][[1]], 3), 0.26)
  expect_equal(round(net_features_metadata$ChAs["mono_meth"][[1]], 3), -0.097)
  expect_equal(round(net_features_metadata$`Mean degree`["mono_meth"][[1]], 3), 6.27)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["mono_meth"][[1]], 3), 0.64)
  expect_equal(round(pp_net_features_metadata$ChAs["mono_meth"][[1]], 3), 0.162)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["mono_meth"][[1]], 3), 3.53)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["mono_meth"][[1]], 3), 0.25)
  expect_equal(round(po_net_features_metadata$ChAs["mono_meth"][[1]], 3), -0.151)
  expect_equal(round(po_net_features_metadata$`Mean degree`["mono_meth"][[1]], 3), 5.47)
})

test_that("Testing chromhmm format from chaser package", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../C002TWH2_11_segments.bed", type = "chromhmm", missingv = 0))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["E1"][[1]], 3), 0.18)
  expect_equal(round(net_features_metadata$ChAs["E1"][[1]], 3), 0.040)
  expect_equal(round(net_features_metadata$`Mean degree`["E1"][[1]], 3), 4.19)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["E1"][[1]], 3), 0.16)
  expect_equal(round(pp_net_features_metadata$ChAs["E1"][[1]], 3), 0.062)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["E1"][[1]], 3), 3.68)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["E1"][[1]], 3), 0.18)
  expect_equal(round(po_net_features_metadata$ChAs["E1"][[1]], 3), 0.039)
  expect_equal(round(po_net_features_metadata$`Mean degree`["E1"][[1]], 3), 3.71)
})

test_that("Testing features_table format from chaser package using default aggregate function (mean)", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../RTnewFile.bedgraph.gz", type = "features_table", missingv = 0))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["RT"][[1]], 3), 1.15)
  expect_equal(round(net_features_metadata$ChAs["RT"][[1]], 3), 0.748)
  expect_equal(round(net_features_metadata$`Mean degree`["RT"][[1]], 3), 3.48)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["RT"][[1]], 3), 1.74)
  expect_equal(round(pp_net_features_metadata$ChAs["RT"][[1]], 3), 0.701)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["RT"][[1]], 3), 3.44)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["RT"][[1]], 3), 1.14)
  expect_equal(round(po_net_features_metadata$ChAs["RT"][[1]], 3), 0.752)
  expect_equal(round(po_net_features_metadata$`Mean degree`["RT"][[1]], 3), 3.16)
})

test_that("Testing features_table format from chaser package using min as aggregate function", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../RTnewFile.bedgraph.gz", type = "features_table", missingv = 0, auxfun = min))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["RT"][[1]], 3), 1.14)
  expect_equal(round(net_features_metadata$ChAs["RT"][[1]], 3), 0.747)
  expect_equal(round(net_features_metadata$`Mean degree`["RT"][[1]], 3), 3.48)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["RT"][[1]], 3), 1.71)
  expect_equal(round(pp_net_features_metadata$ChAs["RT"][[1]], 3), 0.7)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["RT"][[1]], 3), 3.44)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["RT"][[1]], 3), 1.13)
  expect_equal(round(po_net_features_metadata$ChAs["RT"][[1]], 3), 0.752)
  expect_equal(round(po_net_features_metadata$`Mean degree`["RT"][[1]], 3), 3.16)
})

test_that("Testing features_table format from chaser package using max as aggregate function", {
  chaser_input_PCHiC_homo <- generate_input_chaser_PCHiC(homo_PCHiC)
  chaser_net <- make_chromnet(chaser_input_PCHiC_homo)

  chaser_net <- suppressWarnings(chaser::load_features(chaser_net, "../RTnewFile.bedgraph.gz", type = "features_table", missingv = 0, auxfun = max))

  net_features_metadata <- generate_features_metadata(chaser_net)

  expect_equal(round(net_features_metadata$Abundance["RT"][[1]], 3), 1.17)
  expect_equal(round(net_features_metadata$ChAs["RT"][[1]], 3), 0.748)
  expect_equal(round(net_features_metadata$`Mean degree`["RT"][[1]], 3), 3.48)
  # PP network only
  baits <- chaser::export(chaser_net, "baits")
  chaser_net_bb <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits)
  pp_net_features_metadata <- generate_features_metadata(chaser_net_bb)
  expect_equal(round(pp_net_features_metadata$Abundance["RT"][[1]], 3), 1.76)
  expect_equal(round(pp_net_features_metadata$ChAs["RT"][[1]], 3), 0.701)
  expect_equal(round(pp_net_features_metadata$`Mean degree`["RT"][[1]], 3), 3.44)
  # PO network only
  all_oes <- chaser::export(chaser_net, "nodes")$name
  oes <- all_oes[!(all_oes %in% baits)]
  chaser_net_bo <- chaser::subset_chromnet(chaser_net, method = "nodes", nodes1 = baits, nodes2 = oes)
  po_net_features_metadata <- generate_features_metadata(chaser_net_bo)
  expect_equal(round(po_net_features_metadata$Abundance["RT"][[1]], 3), 1.16)
  expect_equal(round(po_net_features_metadata$ChAs["RT"][[1]], 3), 0.752)
  expect_equal(round(po_net_features_metadata$`Mean degree`["RT"][[1]], 3), 3.16)
})
