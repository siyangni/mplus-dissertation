#!/usr/bin/env Rscript
# ==============================================================================
# DESCRIPTIVE VALIDATION OF TRAJECTORY CLASSES
# ==============================================================================
# Purpose: Compare trajectory classes on demographics and baseline characteristics
#          to establish concurrent validity and theoretical meaningfulness
# ==============================================================================

library(tidyverse)
library(knitr)
library(kableExtra)
library(effsize)  # For effect sizes

# ==============================================================================
# FUNCTION: Load class assignments
# ==============================================================================

load_class_assignments <- function(class_file) {

  cat("Loading class assignments from:", class_file, "\n")

  # Read class probabilities file from Mplus
  # Typical format: MCSID, CPROB1, CPROB2, CPROB3, CLASS
  class_data <- read.table(class_file, header = FALSE)

  # Assign column names based on 3-class model
  colnames(class_data) <- c(
    "SC_3", "SC_5", "SC_7", "SC_11", "SC_14", "SC_17",
    "GOVWT1", "MCSID", "PTTYPE2", "SPTN00",
    "CPROB1", "CPROB2", "CPROB3", "CLASS"
  )

  return(class_data)
}

# ==============================================================================
# FUNCTION: Load full dataset with covariates
# ==============================================================================

load_full_dataset <- function(data_path, var_names) {

  cat("Loading full dataset from:", data_path, "\n")

  data <- read.table(data_path, header = FALSE, na.strings = c("-9999", "*", "."))
  colnames(data) <- var_names

  return(data)
}

# ==============================================================================
# FUNCTION: Merge class assignments with covariates
# ==============================================================================

merge_class_covariates <- function(class_data, full_data) {

  merged <- left_join(class_data, full_data, by = "mcsid")

  cat(sprintf("Merged dataset: %d observations\n", nrow(merged)))

  return(merged)
}

# ==============================================================================
# FUNCTION: Descriptive statistics by class
# ==============================================================================

descriptive_by_class <- function(data, continuous_vars, categorical_vars) {

  cat("\n")
  cat("================================================================================\n")
  cat("DESCRIPTIVE STATISTICS BY TRAJECTORY CLASS\n")
  cat("================================================================================\n\n")

  # Class sizes and proportions
  cat("Class Sizes:\n")
  cat("------------\n")
  class_table <- table(data$CLASS)
  class_props <- prop.table(class_table)

  class_summary <- data.frame(
    Class = names(class_table),
    N = as.numeric(class_table),
    Percent = as.numeric(class_props) * 100
  )

  print(kable(class_summary, format = "markdown", digits = 1))
  cat("\n")

  # Continuous variables by class
  if (!is.null(continuous_vars)) {
    cat("\nContinuous Variables by Class:\n")
    cat("------------------------------\n")

    cont_results <- data.frame()

    for (var in continuous_vars) {
      if (!var %in% colnames(data)) next

      var_data <- data[[var]]

      # Calculate means and SDs by class
      class_means <- tapply(var_data, data$CLASS, mean, na.rm = TRUE)
      class_sds <- tapply(var_data, data$CLASS, sd, na.rm = TRUE)
      class_ns <- tapply(!is.na(var_data), data$CLASS, sum)

      # ANOVA test for differences
      anova_result <- tryCatch({
        summary(aov(var_data ~ as.factor(CLASS), data = data))
      }, error = function(e) NULL)

      f_stat <- ifelse(!is.null(anova_result), anova_result[[1]]$`F value`[1], NA)
      p_value <- ifelse(!is.null(anova_result), anova_result[[1]]$`Pr(>F)`[1], NA)

      # Effect size (eta-squared)
      ss_between <- ifelse(!is.null(anova_result), anova_result[[1]]$`Sum Sq`[1], NA)
      ss_total <- ifelse(!is.null(anova_result), sum(anova_result[[1]]$`Sum Sq`), NA)
      eta_sq <- ss_between / ss_total

      cont_results <- rbind(cont_results, data.frame(
        Variable = var,
        Class1_Mean = class_means[1],
        Class1_SD = class_sds[1],
        Class2_Mean = class_means[2],
        Class2_SD = class_sds[2],
        Class3_Mean = class_means[3],
        Class3_SD = class_sds[3],
        F_stat = f_stat,
        p_value = p_value,
        eta_squared = eta_sq,
        stringsAsFactors = FALSE
      ))
    }

    # Format and print
    cont_formatted <- cont_results %>%
      mutate(
        Class1 = sprintf("%.2f (%.2f)", Class1_Mean, Class1_SD),
        Class2 = sprintf("%.2f (%.2f)", Class2_Mean, Class2_SD),
        Class3 = sprintf("%.2f (%.2f)", Class3_Mean, Class3_SD),
        Test = sprintf("F=%.2f, p=%.3f, eta²=%.3f", F_stat, p_value, eta_squared),
        Sig = ifelse(p_value < 0.001, "***",
                     ifelse(p_value < 0.01, "**",
                            ifelse(p_value < 0.05, "*", "")))
      ) %>%
      select(Variable, Class1, Class2, Class3, Test, Sig)

    print(kable(cont_formatted, format = "markdown", align = "lrrrrl"))
    cat("\n")
  }

  # Categorical variables by class
  if (!is.null(categorical_vars)) {
    cat("\nCategorical Variables by Class:\n")
    cat("-------------------------------\n")

    for (var in categorical_vars) {
      if (!var %in% colnames(data)) next

      cat(sprintf("\n%s:\n", var))

      # Cross-tabulation
      cross_tab <- table(data[[var]], data$CLASS, useNA = "no")
      cross_prop <- prop.table(cross_tab, margin = 2) * 100

      # Chi-square test
      chisq_result <- tryCatch({
        chisq.test(cross_tab)
      }, error = function(e) NULL)

      # Print proportions
      print(kable(cross_prop, format = "markdown", digits = 1))

      if (!is.null(chisq_result)) {
        cat(sprintf("  Chi-square = %.2f, df = %d, p = %.4f\n",
                    chisq_result$statistic, chisq_result$parameter, chisq_result$p.value))
      }
      cat("\n")
    }
  }

  return(list(continuous = cont_results, class_summary = class_summary))
}

# ==============================================================================
# FUNCTION: Pairwise comparisons with effect sizes
# ==============================================================================

pairwise_comparisons <- function(data, outcome_var) {

  cat(sprintf("\nPairwise Comparisons for %s:\n", outcome_var))
  cat("--------------------------------\n")

  classes <- sort(unique(data$CLASS))
  comparisons <- combn(classes, 2)

  results <- data.frame()

  for (i in 1:ncol(comparisons)) {
    c1 <- comparisons[1, i]
    c2 <- comparisons[2, i]

    data_c1 <- data[[outcome_var]][data$CLASS == c1]
    data_c2 <- data[[outcome_var]][data$CLASS == c2]

    # Remove missing
    data_c1 <- data_c1[!is.na(data_c1)]
    data_c2 <- data_c2[!is.na(data_c2)]

    # T-test
    t_result <- t.test(data_c1, data_c2)

    # Cohen's d
    d <- cohen.d(data_c1, data_c2)$estimate

    results <- rbind(results, data.frame(
      Comparison = sprintf("Class %d vs Class %d", c1, c2),
      Mean_Diff = mean(data_c1) - mean(data_c2),
      t_stat = t_result$statistic,
      p_value = t_result$p.value,
      Cohens_d = d,
      stringsAsFactors = FALSE
    ))
  }

  # Adjust for multiple comparisons
  results$p_adjusted <- p.adjust(results$p_value, method = "holm")

  results_formatted <- results %>%
    mutate(
      Test = sprintf("t=%.2f, p=%.3f", t_stat, p_adjusted),
      Effect = sprintf("d=%.2f", Cohens_d),
      Sig = ifelse(p_adjusted < 0.001, "***",
                   ifelse(p_adjusted < 0.01, "**",
                          ifelse(p_adjusted < 0.05, "*", "")))
    ) %>%
    select(Comparison, Mean_Diff, Test, Effect, Sig)

  print(kable(results_formatted, format = "markdown", digits = 2))

  cat("\nEffect Size Interpretation (Cohen's d):\n")
  cat("  Small: 0.20, Medium: 0.50, Large: 0.80\n\n")

  return(results)
}

# ==============================================================================
# FUNCTION: Plot trajectory means by class
# ==============================================================================

plot_trajectories_by_class <- function(data) {

  cat("\nGenerating trajectory plots...\n")

  # Reshape data to long format
  trajectory_data <- data %>%
    select(MCSID, CLASS, SC_3, SC_5, SC_7, SC_11, SC_14, SC_17) %>%
    pivot_longer(cols = starts_with("SC_"), names_to = "Wave", values_to = "SC") %>%
    mutate(
      Age = case_when(
        Wave == "SC_3" ~ 3,
        Wave == "SC_5" ~ 5,
        Wave == "SC_7" ~ 7,
        Wave == "SC_11" ~ 11,
        Wave == "SC_14" ~ 14,
        Wave == "SC_17" ~ 17
      ),
      Class = factor(CLASS, labels = c("Class 1", "Class 2", "Class 3"))
    )

  # Calculate means and SEs by class and age
  trajectory_summary <- trajectory_data %>%
    group_by(Class, Age) %>%
    summarize(
      Mean = mean(SC, na.rm = TRUE),
      SE = sd(SC, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    )

  # Plot
  p <- ggplot(trajectory_summary, aes(x = Age, y = Mean, color = Class, group = Class)) +
    geom_line(size = 1.2) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = Mean - SE, ymax = Mean + SE), width = 0.5) +
    labs(
      title = "Self-Control Trajectory Classes (Ages 3-17)",
      x = "Age (Years)",
      y = "Self-Control Factor Score",
      color = "Trajectory Class"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 14, face = "bold"),
      axis.title = element_text(size = 12),
      legend.position = "bottom"
    ) +
    scale_x_continuous(breaks = c(3, 5, 7, 11, 14, 17))

  ggsave("revised_analyses/04_validation/trajectory_plot_by_class.png",
         p, width = 8, height = 6, dpi = 300)

  cat("Saved: revised_analyses/04_validation/trajectory_plot_by_class.png\n")

  return(p)
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main <- function() {

  # Define variable names (same as missing data script)
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

  # Load class assignments
  class_data <- load_class_assignments(
    "/home/user/mplus-dissertation/growth_mixture_models/sc_gmm3_fscores_cprobs.dat"
  )

  # Load full dataset
  full_data <- load_full_dataset(
    "/home/user/mplus-dissertation/recoded_only_sc_pa_cov.dat",
    var_names
  )

  # Merge
  merged_data <- merge_class_covariates(class_data, full_data)

  # Continuous variables to compare
  continuous_vars <- c("scoga", "pedu", "bpedu", "incomef", "hfae")

  # Categorical variables to compare
  categorical_vars <- c("sex", "race", "bmarried", "lbw")

  # Generate descriptive statistics
  desc_results <- descriptive_by_class(
    merged_data,
    continuous_vars,
    categorical_vars
  )

  # Pairwise comparisons for key variables
  if ("scoga" %in% colnames(merged_data)) {
    pairwise_results <- pairwise_comparisons(merged_data, "scoga")
  }

  # Plot trajectories
  trajectory_plot <- plot_trajectories_by_class(merged_data)

  # Save results
  write.csv(desc_results$continuous,
            "revised_analyses/04_validation/descriptive_comparison_continuous.csv",
            row.names = FALSE)

  write.csv(desc_results$class_summary,
            "revised_analyses/04_validation/class_sizes.csv",
            row.names = FALSE)

  cat("\n")
  cat("================================================================================\n")
  cat("Validation analysis complete!\n")
  cat("Results saved to: revised_analyses/04_validation/\n")
  cat("================================================================================\n")

  return(list(
    descriptive = desc_results,
    plot = trajectory_plot
  ))
}

# Run if called as script
if (!interactive()) {
  main()
}
