#!/usr/bin/env Rscript
# ==============================================================================
# MODEL COMPARISON TABLE EXTRACTOR FOR MPLUS OUTPUTS
# ==============================================================================
# Purpose: Extract fit statistics from Mplus .out files and create comparison
#          tables for measurement invariance, growth models, and mixture models
# Author: Revised Analysis Package
# Date: 2025
# ==============================================================================

library(MplusAutomation)
library(tidyverse)
library(knitr)
library(kableExtra)

# ==============================================================================
# FUNCTION: Extract Measurement Invariance Model Fit
# ==============================================================================

extract_measurement_invariance_fit <- function(out_dir) {

  cat("Extracting measurement invariance model fit statistics...\n")

  # List of invariance models in order
  inv_models <- c(
    "configural_invariance_baseline.out",
    "threshold_invariance.out",
    "strong_invariance.out"
  )

  # Initialize results dataframe
  results <- data.frame(
    Model = character(),
    ChiSq = numeric(),
    df = numeric(),
    CFI = numeric(),
    TLI = numeric(),
    RMSEA = numeric(),
    RMSEA_CI_Lower = numeric(),
    RMSEA_CI_Upper = numeric(),
    SRMR = numeric(),
    stringsAsFactors = FALSE
  )

  for (model_file in inv_models) {
    model_path <- file.path(out_dir, model_file)

    if (!file.exists(model_path)) {
      cat("Warning: Model file not found:", model_path, "\n")
      next
    }

    # Read Mplus output
    model_output <- readModels(model_path, what = "summaries")

    # Extract fit indices
    fit_summary <- model_output$summaries

    results <- rbind(results, data.frame(
      Model = gsub("\\.out$", "", model_file),
      ChiSq = fit_summary$ChiSqM_Value,
      df = fit_summary$ChiSqM_DF,
      CFI = fit_summary$CFI,
      TLI = fit_summary$TLI,
      RMSEA = fit_summary$RMSEA_Estimate,
      RMSEA_CI_Lower = fit_summary$RMSEA_90CI_LB,
      RMSEA_CI_Upper = fit_summary$RMSEA_90CI_UB,
      SRMR = fit_summary$SRMR,
      stringsAsFactors = FALSE
    ))
  }

  # Calculate model comparisons (chi-square difference tests)
  if (nrow(results) > 1) {
    results$ChiSq_Diff <- c(NA, diff(results$ChiSq))
    results$df_Diff <- c(NA, diff(results$df))
    results$p_value <- c(NA, pchisq(diff(results$ChiSq), diff(results$df), lower.tail = FALSE))
    results$CFI_Diff <- c(NA, -diff(results$CFI))  # Negative because decline indicates worse fit
  }

  return(results)
}

# ==============================================================================
# FUNCTION: Extract Mixture Model Enumeration Fit
# ==============================================================================

extract_mixture_model_fit <- function(out_dir, pattern = "sc_gmm_lgbm_c") {

  cat("Extracting growth mixture model fit statistics...\n")

  # Find all mixture model output files
  gmm_files <- list.files(out_dir, pattern = paste0(pattern, "[0-9]+\\.out$"), full.names = TRUE)

  if (length(gmm_files) == 0) {
    cat("Warning: No mixture model files found matching pattern:", pattern, "\n")
    return(NULL)
  }

  results <- data.frame(
    Model = character(),
    Classes = integer(),
    LogLikelihood = numeric(),
    Parameters = integer(),
    AIC = numeric(),
    BIC = numeric(),
    SABIC = numeric(),
    Entropy = numeric(),
    BLRT_p = numeric(),
    Smallest_Class_Prop = numeric(),
    Smallest_Class_N = numeric(),
    stringsAsFactors = FALSE
  )

  for (model_file in gmm_files) {

    model_output <- readModels(model_file, what = "summaries")
    fit <- model_output$summaries

    # Extract number of classes from filename
    n_classes <- as.integer(gsub(".*c([0-9]+)\\.out$", "\\1", basename(model_file)))

    # Extract class proportions
    class_counts <- model_output$class_counts$mostLikely
    if (!is.null(class_counts)) {
      smallest_class <- min(class_counts$proportion)
      smallest_n <- min(class_counts$count)
    } else {
      smallest_class <- NA
      smallest_n <- NA
    }

    # Extract BLRT p-value (if available in TECH14)
    blrt_p <- NA
    if (!is.null(fit$T14_BLRT_PValue)) {
      blrt_p <- fit$T14_BLRT_PValue
    }

    results <- rbind(results, data.frame(
      Model = gsub("\\.out$", "", basename(model_file)),
      Classes = n_classes,
      LogLikelihood = fit$LL,
      Parameters = fit$Parameters,
      AIC = fit$AIC,
      BIC = fit$BIC,
      SABIC = fit$aBIC,
      Entropy = fit$Entropy,
      BLRT_p = blrt_p,
      Smallest_Class_Prop = smallest_class,
      Smallest_Class_N = smallest_n,
      stringsAsFactors = FALSE
    ))
  }

  # Sort by number of classes
  results <- results[order(results$Classes), ]

  return(results)
}

# ==============================================================================
# FUNCTION: Format and Print Tables
# ==============================================================================

format_invariance_table <- function(results) {

  cat("\n")
  cat("================================================================================\n")
  cat("MEASUREMENT INVARIANCE MODEL COMPARISON\n")
  cat("================================================================================\n\n")

  # Format numeric columns
  results_formatted <- results %>%
    mutate(
      ChiSq = sprintf("%.2f", ChiSq),
      df = as.character(df),
      CFI = sprintf("%.3f", CFI),
      TLI = sprintf("%.3f", TLI),
      RMSEA = sprintf("%.3f [%.3f, %.3f]", RMSEA, RMSEA_CI_Lower, RMSEA_CI_Upper),
      SRMR = sprintf("%.3f", SRMR)
    ) %>%
    select(Model, ChiSq, df, CFI, TLI, RMSEA, SRMR)

  # Print table
  print(kable(results_formatted, format = "markdown", align = "lrrrrrr"))

  # Print model comparisons
  if ("ChiSq_Diff" %in% names(results)) {
    cat("\n")
    cat("Model Comparisons (Chi-square Difference Tests):\n")
    cat("--------------------------------------------------------------------------------\n")

    for (i in 2:nrow(results)) {
      cat(sprintf("%s vs %s: Δχ²(%.0f) = %.2f, p = %.4f, ΔCFI = %.3f\n",
                  results$Model[i-1], results$Model[i],
                  results$df_Diff[i], results$ChiSq_Diff[i],
                  results$p_value[i], results$CFI_Diff[i]))
    }

    cat("\nInterpretation Guidelines:\n")
    cat("  - ΔCFI ≤ -.010 suggests measurement non-invariance (Cheung & Rensvold, 2002)\n")
    cat("  - p < .05 indicates significant deterioration in fit\n")
  }

  cat("\n")
  cat("Fit Index Guidelines (Hu & Bentler, 1999; Brown, 2015):\n")
  cat("  - CFI/TLI: ≥ .95 (excellent), ≥ .90 (acceptable)\n")
  cat("  - RMSEA: ≤ .06 (excellent), ≤ .08 (acceptable)\n")
  cat("  - SRMR: ≤ .08 (good fit)\n")
  cat("\n")
}

format_mixture_table <- function(results) {

  cat("\n")
  cat("================================================================================\n")
  cat("GROWTH MIXTURE MODEL ENUMERATION\n")
  cat("================================================================================\n\n")

  # Format results
  results_formatted <- results %>%
    mutate(
      LogLikelihood = sprintf("%.2f", LogLikelihood),
      Parameters = as.character(Parameters),
      AIC = sprintf("%.2f", AIC),
      BIC = sprintf("%.2f", BIC),
      SABIC = sprintf("%.2f", SABIC),
      Entropy = sprintf("%.3f", Entropy),
      BLRT_p = ifelse(is.na(BLRT_p), "N/A", sprintf("%.4f", BLRT_p)),
      Smallest_Class = sprintf("%.1f%% (n=%.0f)", Smallest_Class_Prop * 100, Smallest_Class_N)
    ) %>%
    select(Classes, LogLikelihood, Parameters, AIC, BIC, SABIC, Entropy, BLRT_p, Smallest_Class)

  # Print table
  print(kable(results_formatted, format = "markdown", align = "rrrrrrrrl"))

  cat("\n")
  cat("Model Selection Guidelines:\n")
  cat("--------------------------------------------------------------------------------\n")
  cat("  - Lower AIC/BIC/SABIC indicates better fit\n")
  cat("  - BIC is most reliable for mixture models (Nylund et al., 2007)\n")
  cat("  - Entropy: > .80 (excellent), > .60 (acceptable)\n")
  cat("  - BLRT p < .05: k-class model fits better than (k-1)-class model\n")
  cat("  - Smallest class should be > 5% of sample for reliability\n")
  cat("  - Consider theoretical interpretability and parsimony\n")
  cat("\n")

  # Identify best model by BIC
  best_bic_idx <- which.min(results$BIC)
  cat(sprintf("RECOMMENDATION: %d-class model has lowest BIC\n", results$Classes[best_bic_idx]))

  if (results$Entropy[best_bic_idx] < 0.60) {
    cat("WARNING: Selected model has low entropy (< .60) - poor classification quality\n")
  }

  if (results$Smallest_Class_Prop[best_bic_idx] < 0.05) {
    cat("WARNING: Selected model has very small class (< 5%) - may be unstable\n")
  }

  cat("\n")
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main <- function() {

  # Set working directory to dissertation root
  setwd("/home/user/mplus-dissertation")

  cat("================================================================================\n")
  cat("MPLUS MODEL COMPARISON TABLE GENERATOR\n")
  cat("================================================================================\n\n")

  # 1. Extract measurement invariance fit
  cat("\n[1/2] Processing measurement invariance models...\n")
  inv_results <- extract_measurement_invariance_fit("invariance_test")

  if (!is.null(inv_results) && nrow(inv_results) > 0) {
    format_invariance_table(inv_results)

    # Save to CSV
    write.csv(inv_results,
              "revised_analyses/03_diagnostics/measurement_invariance_comparison.csv",
              row.names = FALSE)
    cat("Saved: revised_analyses/03_diagnostics/measurement_invariance_comparison.csv\n")
  }

  # 2. Extract mixture model fit
  cat("\n[2/2] Processing growth mixture models...\n")
  gmm_results <- extract_mixture_model_fit(".", pattern = "sc_gmm_lgbm_c")

  if (!is.null(gmm_results) && nrow(gmm_results) > 0) {
    format_mixture_table(gmm_results)

    # Save to CSV
    write.csv(gmm_results,
              "revised_analyses/03_diagnostics/mixture_model_comparison.csv",
              row.names = FALSE)
    cat("Saved: revised_analyses/03_diagnostics/mixture_model_comparison.csv\n")
  }

  cat("\n")
  cat("================================================================================\n")
  cat("Model comparison extraction complete!\n")
  cat("================================================================================\n")
}

# Run if called as script
if (!interactive()) {
  main()
}
