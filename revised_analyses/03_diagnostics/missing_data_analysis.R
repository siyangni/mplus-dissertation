#!/usr/bin/env Rscript
# ==============================================================================
# MISSING DATA DIAGNOSTICS FOR LONGITUDINAL SELF-CONTROL ANALYSIS
# ==============================================================================
# Purpose: Comprehensive missing data analysis including:
#          - Missing data patterns across waves
#          - Tests for MCAR (Little's test)
#          - Comparison of complete vs incomplete cases
#          - Attrition analysis
# ==============================================================================

library(tidyverse)
library(naniar)      # For missing data visualization
library(mice)        # For missing data patterns
library(BaylorEdPsych) # For Little's MCAR test
library(knitr)
library(kableExtra)

# ==============================================================================
# FUNCTION: Load and prepare data
# ==============================================================================

load_mplus_data <- function(data_path, var_names) {

  cat("Loading data from:", data_path, "\n")

  # Read fixed-width or space-delimited data
  data <- read.table(data_path, header = FALSE, na.strings = c("-9999", "*", "."))

  # Assign variable names
  colnames(data) <- var_names

  return(data)
}

# ==============================================================================
# FUNCTION: Compute missing data patterns by wave
# ==============================================================================

analyze_wave_missingness <- function(data, sc_vars_by_wave) {

  cat("\nAnalyzing missing data patterns by wave...\n")

  results <- data.frame(
    Wave = character(),
    Age = integer(),
    N_Complete = integer(),
    N_Missing = integer(),
    Percent_Missing = numeric(),
    stringsAsFactors = FALSE
  )

  ages <- c(3, 5, 7, 11, 14, 17)

  for (i in 1:length(sc_vars_by_wave)) {
    wave_vars <- sc_vars_by_wave[[i]]

    # Count complete cases for this wave
    wave_complete <- complete.cases(data[, wave_vars])
    n_complete <- sum(wave_complete)
    n_missing <- sum(!wave_complete)
    pct_missing <- (n_missing / nrow(data)) * 100

    results <- rbind(results, data.frame(
      Wave = paste0("Wave ", i),
      Age = ages[i],
      N_Complete = n_complete,
      N_Missing = n_missing,
      Percent_Missing = pct_missing,
      stringsAsFactors = FALSE
    ))
  }

  return(results)
}

# ==============================================================================
# FUNCTION: Analyze attrition patterns
# ==============================================================================

analyze_attrition <- function(data, sc_vars_by_wave) {

  cat("\nAnalyzing attrition patterns...\n")

  # Create indicator for completeness at each wave
  n_waves <- length(sc_vars_by_wave)
  complete_matrix <- matrix(NA, nrow = nrow(data), ncol = n_waves)

  for (i in 1:n_waves) {
    complete_matrix[, i] <- complete.cases(data[, sc_vars_by_wave[[i]]])
  }

  # Count number of waves completed per person
  n_waves_completed <- rowSums(complete_matrix)

  attrition_summary <- data.frame(
    N_Waves_Completed = 0:n_waves,
    N_Participants = as.numeric(table(factor(n_waves_completed, levels = 0:n_waves))),
    Percent = as.numeric(table(factor(n_waves_completed, levels = 0:n_waves))) / nrow(data) * 100
  )

  # Identify attrition patterns
  cat("\nCommon attrition patterns:\n")
  cat("-------------------------\n")

  # Pattern 1: Monotone missingness (dropout after wave X)
  monotone_dropout <- rep(TRUE, nrow(data))
  for (i in 1:(n_waves-1)) {
    # If missing at wave i, should be missing at all subsequent waves
    monotone_dropout <- monotone_dropout &
      (!complete_matrix[, i] | all(complete_matrix[, (i+1):n_waves] == FALSE, na.rm = TRUE))
  }

  pct_monotone <- sum(monotone_dropout) / nrow(data) * 100
  cat(sprintf("  Monotone dropout pattern: %.1f%%\n", pct_monotone))

  # Pattern 2: Intermittent missingness
  has_gap <- rowSums(diff(t(complete_matrix)) != 0) > 1
  pct_intermittent <- sum(has_gap) / nrow(data) * 100
  cat(sprintf("  Intermittent missingness: %.1f%%\n", pct_intermittent))

  return(list(
    summary = attrition_summary,
    monotone_pct = pct_monotone,
    intermittent_pct = pct_intermittent
  ))
}

# ==============================================================================
# FUNCTION: Compare complete vs incomplete cases
# ==============================================================================

compare_complete_incomplete <- function(data, sc_vars, covariate_list) {

  cat("\nComparing complete vs incomplete cases on covariates...\n")

  # Define completeness for SC across all waves
  all_sc_vars <- unlist(sc_vars)
  complete_case <- complete.cases(data[, all_sc_vars])

  comparison_results <- data.frame(
    Variable = character(),
    Complete_Mean = numeric(),
    Complete_SD = numeric(),
    Incomplete_Mean = numeric(),
    Incomplete_SD = numeric(),
    t_statistic = numeric(),
    p_value = numeric(),
    stringsAsFactors = FALSE
  )

  for (var_name in covariate_list) {

    if (!var_name %in% colnames(data)) {
      next
    }

    var_data <- data[[var_name]]

    # Skip if too many missing values in covariate itself
    if (sum(!is.na(var_data)) < 100) {
      next
    }

    # T-test comparing complete vs incomplete
    complete_vals <- var_data[complete_case & !is.na(var_data)]
    incomplete_vals <- var_data[!complete_case & !is.na(var_data)]

    if (length(complete_vals) > 0 && length(incomplete_vals) > 0) {

      test_result <- tryCatch({
        t.test(complete_vals, incomplete_vals)
      }, error = function(e) {
        return(NULL)
      })

      if (!is.null(test_result)) {
        comparison_results <- rbind(comparison_results, data.frame(
          Variable = var_name,
          Complete_Mean = mean(complete_vals, na.rm = TRUE),
          Complete_SD = sd(complete_vals, na.rm = TRUE),
          Incomplete_Mean = mean(incomplete_vals, na.rm = TRUE),
          Incomplete_SD = sd(incomplete_vals, na.rm = TRUE),
          t_statistic = test_result$statistic,
          p_value = test_result$p.value,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  # Adjust for multiple comparisons
  if (nrow(comparison_results) > 0) {
    comparison_results$p_adjusted <- p.adjust(comparison_results$p_value, method = "holm")
    comparison_results$Significant <- ifelse(comparison_results$p_adjusted < 0.05, "***", "")
  }

  return(comparison_results)
}

# ==============================================================================
# FUNCTION: Little's MCAR Test
# ==============================================================================

test_mcar <- function(data, sc_vars) {

  cat("\nPerforming Little's MCAR test...\n")
  cat("(This may take a few minutes for large datasets)\n")

  # Select only SC variables for MCAR test
  all_sc_vars <- unlist(sc_vars)
  sc_data <- data[, all_sc_vars]

  # Little's test requires complete covariance matrix
  # Remove cases with all missing
  sc_data <- sc_data[rowSums(!is.na(sc_data)) > 0, ]

  tryCatch({
    mcar_result <- LittleMCAR(sc_data)

    cat("\n")
    cat("Little's MCAR Test Results:\n")
    cat("---------------------------\n")
    cat(sprintf("  Chi-square: %.2f\n", mcar_result$chi.square))
    cat(sprintf("  df: %d\n", mcar_result$df))
    cat(sprintf("  p-value: %.4f\n", mcar_result$p.value))
    cat("\n")

    if (mcar_result$p.value < 0.05) {
      cat("INTERPRETATION: Reject MCAR (p < .05)\n")
      cat("  Data are NOT missing completely at random.\n")
      cat("  Missingness may be related to observed or unobserved variables.\n")
      cat("  RECOMMENDATION: Use FIML or multiple imputation.\n")
    } else {
      cat("INTERPRETATION: Fail to reject MCAR (p >= .05)\n")
      cat("  Data are consistent with MCAR assumption.\n")
      cat("  Standard missing data methods (FIML) are appropriate.\n")
    }

    return(mcar_result)

  }, error = function(e) {
    cat("\nError performing Little's MCAR test:\n")
    cat(as.character(e), "\n")
    return(NULL)
  })
}

# ==============================================================================
# FUNCTION: Generate missing data report
# ==============================================================================

generate_missing_data_report <- function(data, sc_vars_by_wave, covariates) {

  cat("\n")
  cat("================================================================================\n")
  cat("MISSING DATA ANALYSIS REPORT\n")
  cat("================================================================================\n")

  # 1. Wave-level missingness
  cat("\n[1/4] Wave-level missingness patterns\n")
  wave_missing <- analyze_wave_missingness(data, sc_vars_by_wave)
  print(kable(wave_missing, format = "markdown", digits = 1))

  # 2. Attrition analysis
  cat("\n[2/4] Attrition analysis\n")
  attrition <- analyze_attrition(data, sc_vars_by_wave)
  print(kable(attrition$summary, format = "markdown", digits = 1))

  # 3. Complete vs incomplete cases
  cat("\n[3/4] Complete vs incomplete case comparison\n")
  comparison <- compare_complete_incomplete(data, sc_vars_by_wave, covariates)
  if (nrow(comparison) > 0) {
    comparison_formatted <- comparison %>%
      mutate(
        Complete = sprintf("%.2f (%.2f)", Complete_Mean, Complete_SD),
        Incomplete = sprintf("%.2f (%.2f)", Incomplete_Mean, Incomplete_SD),
        t_test = sprintf("t = %.2f, p = %.3f %s", t_statistic, p_adjusted, Significant)
      ) %>%
      select(Variable, Complete, Incomplete, t_test)

    print(kable(comparison_formatted, format = "markdown"))
  }

  # 4. MCAR test
  cat("\n[4/4] Testing MCAR assumption\n")
  mcar_result <- test_mcar(data, sc_vars_by_wave)

  # Save results
  output_dir <- "revised_analyses/03_diagnostics"

  write.csv(wave_missing,
            file.path(output_dir, "wave_missingness_summary.csv"),
            row.names = FALSE)

  write.csv(attrition$summary,
            file.path(output_dir, "attrition_summary.csv"),
            row.names = FALSE)

  write.csv(comparison,
            file.path(output_dir, "complete_vs_incomplete_comparison.csv"),
            row.names = FALSE)

  cat("\n")
  cat("================================================================================\n")
  cat("Results saved to: revised_analyses/03_diagnostics/\n")
  cat("================================================================================\n")

  return(list(
    wave_missing = wave_missing,
    attrition = attrition,
    comparison = comparison,
    mcar_result = mcar_result
  ))
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main <- function() {

  # Variable names from original data file
  var_names <- c(
    "pttype2", "nh2", "bovwt1", "covwt1", "dovwt1", "eovwt1", "fovwt1", "govwt1",
    "sptn00", "sc3thac", "sc3tcom", "sc3obey", "sc3dist", "sc3temp", "sc3rest",
    "sc3fidg", "sc5thac", "sc5tcom", "sc5obey", "sc5dist", "sc5temp", "sc5rest",
    "sc5fidg", "sc5lyin", "sc7thac", "sc7tcom", "sc7obey", "sc7dist", "sc7temp",
    "sc7rest", "sc7fidg", "sc7lyin", "sc11thac", "sc11tcom", "sc11obey", "sc11dist",
    "sc11temp", "sc11rest", "sc11fidg", "sc11lyin", "sc14thac", "sc14tcom",
    "sc14obey", "sc14dist", "sc14temp", "sc14rest", "sc14fidg", "sc14lyin",
    "sc17thac", "sc17tcom", "sc17obey", "sc17dist", "sc17temp", "sc17rest",
    "sc17fidg", "sc17lyin", "ignore3", "smack3", "shout3", "bedroom3", "treats3",
    "telloff3", "bribe3", "ignore5", "smack5", "shout5", "bedroom5", "treats5",
    "telloff5", "bribe5", "reason5", "rindoor5", "dinner5", "close5", "read5",
    "story5", "music5", "paint5", "active5", "games5", "park5", "ignore7",
    "smack7", "shout7", "bedroom7", "treats7", "telloff7", "bribe7", "reason7",
    "rindoor7", "dinner7", "close7", "read7", "story7", "music7", "paint7",
    "active7", "games7", "park7", "tvrules7", "bedroom11", "treats11", "reason11",
    "close11", "active11", "games11", "pwhere14", "pwho14", "pwhat14", "cmwhere14",
    "cmwho14", "cmwhat14", "cmwhere17", "cmtback17", "pwhere17", "ptback17",
    "livewp17", "pedu", "bpedu", "sex", "race", "brace", "bmarried", "incomec",
    "incomel", "incomef", "lbw", "namhapna0", "namunfaa0", "nambrusa0", "namfeeda0",
    "naminjua0", "nambatha0", "namwarya0", "nambshya0", "namfreta0", "namsleea0",
    "nammilka0", "namsltia0", "namnapsa0", "namsofoa0", "inftempr", "inftemp",
    "dfpw", "dupd", "dupw", "hfae", "coga", "scoga", "age3", "age5", "age7",
    "age11", "age14", "age17", "mcsid"
  )

  # Define SC variables by wave
  sc_vars_by_wave <- list(
    wave1 = c("sc3thac", "sc3tcom", "sc3obey", "sc3dist", "sc3temp", "sc3rest", "sc3fidg"),
    wave2 = c("sc5thac", "sc5tcom", "sc5obey", "sc5dist", "sc5temp", "sc5rest", "sc5fidg"),
    wave3 = c("sc7thac", "sc7tcom", "sc7obey", "sc7dist", "sc7temp", "sc7rest", "sc7fidg"),
    wave4 = c("sc11thac", "sc11tcom", "sc11obey", "sc11dist", "sc11temp", "sc11rest", "sc11fidg"),
    wave5 = c("sc14thac", "sc14tcom", "sc14obey", "sc14dist", "sc14temp", "sc14rest", "sc14fidg"),
    wave6 = c("sc17thac", "sc17tcom", "sc17obey", "sc17dist", "sc17temp", "sc17rest", "sc17fidg")
  )

  # Covariates for comparison
  covariates <- c("sex", "race", "brace", "bmarried", "incomef", "lbw", "pedu", "bpedu",
                  "scoga", "hfae", "inftemp")

  # Load data
  data <- load_mplus_data(
    "/home/user/mplus-dissertation/recoded_only_sc_pa_cov.dat",
    var_names
  )

  cat(sprintf("Data loaded: %d observations, %d variables\n", nrow(data), ncol(data)))

  # Generate comprehensive report
  results <- generate_missing_data_report(data, sc_vars_by_wave, covariates)

  return(results)
}

# Run if called as script
if (!interactive()) {
  main()
}
