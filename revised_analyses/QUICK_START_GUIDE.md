# Quick Start Guide: Running Revised Analyses

This guide provides step-by-step instructions for running the revised analyses with minimal prior knowledge.

## Prerequisites

Check if you have required software:

```bash
# Check Mplus version
mplus -v

# Check R version
R --version

# Check if in correct directory
pwd
# Should show: /home/user/mplus-dissertation
```

## Step 1: Install R Packages (One-Time Setup)

```bash
R
```

In R console:
```r
# Install required packages
install.packages(c("tidyverse", "MplusAutomation", "naniar", "mice",
                   "BaylorEdPsych", "effsize", "knitr", "kableExtra"))

# Test installation
library(tidyverse)
library(MplusAutomation)

# If successful, quit R
quit()
```

## Step 2: Run Critical Revision (Freed Variances)

This is the MOST IMPORTANT revision.

```bash
# Navigate to revised models directory
cd /home/user/mplus-dissertation/revised_analyses/02_mixture_revised

# Run 3-class GMM with freed variances
mplus sc_gmm_lgbm_c3_FREED_VARIANCES.inp

# Wait for completion (may take 10-30 minutes)
# Output file: sc_gmm_lgbm_c3_FREED_VARIANCES.out
```

### What to Check in Output:

Open `sc_gmm_lgbm_c3_FREED_VARIANCES.out` and look for:

1. **Convergence:**
   ```
   THE MODEL ESTIMATION TERMINATED NORMALLY
   ```

2. **BIC value:**
   ```
   BIC = XXXXX.XXX
   ```
   Compare with original model BIC (should be LOWER = better)

3. **Entropy:**
   ```
   Entropy = 0.XXX
   ```
   Should be > 0.60 (higher is better)

4. **Class-specific variances:**
   ```
   Class 1:
   I           0.XXX    (VARI_C1)
   S           0.XXX    (VARS_C1)

   Class 2:
   I           0.XXX    (VARI_C2)
   S           0.XXX    (VARS_C2)
   ```
   These should DIFFER across classes

## Step 3: Generate Model Comparison Tables

```bash
# Return to main directory
cd /home/user/mplus-dissertation

# Run model comparison script
Rscript revised_analyses/03_diagnostics/extract_model_fit.R
```

### Expected Output:

Console will display:
- Measurement invariance comparison table
- Mixture model enumeration table

Files created in `revised_analyses/03_diagnostics/`:
- `measurement_invariance_comparison.csv`
- `mixture_model_comparison.csv`

### If You Get Errors:

**"command not found: Rscript"**
```bash
# Try this instead:
R CMD BATCH revised_analyses/03_diagnostics/extract_model_fit.R
```

**"cannot open file"**
```bash
# Make sure you're in the right directory:
pwd
# Should be: /home/user/mplus-dissertation
```

## Step 4: Missing Data Diagnostics

```bash
# Still in main directory
Rscript revised_analyses/03_diagnostics/missing_data_analysis.R
```

### Expected Output:

Console displays:
- Missing data patterns by wave
- Attrition summary
- Complete vs incomplete comparison
- Little's MCAR test result

Files created:
- `wave_missingness_summary.csv`
- `attrition_summary.csv`
- `complete_vs_incomplete_comparison.csv`

### Interpreting Results:

1. **Wave missingness:** Higher % missing at later waves is normal (attrition)
2. **Little's MCAR test:**
   - p > .05: Data consistent with MCAR (good!)
   - p < .05: Missingness not completely random (common, FIML still OK)
3. **Complete vs incomplete:** Look for significant differences (p < .05)

## Step 5: Validation Analysis

```bash
# Still in main directory
Rscript revised_analyses/04_validation/descriptive_validation.R
```

### Expected Output:

Console displays:
- Class sizes and proportions
- Continuous variables by class (with ANOVA)
- Categorical variables by class (with chi-square)
- Pairwise comparisons with effect sizes

Files created:
- `descriptive_comparison_continuous.csv`
- `class_sizes.csv`
- `trajectory_plot_by_class.png`

### What to Look For:

1. **Class sizes:** All classes > 5% of sample?
2. **Trajectory plot:** Do classes show distinct patterns?
3. **Validation:** Do classes differ on demographics as expected?

## Step 6: Parenting Model with Freed Variances

```bash
cd /home/user/mplus-dissertation/revised_analyses/02_mixture_revised

# Run parenting model (may take 30-60 minutes)
mplus sc_gmm_parenting_FREED_VARIANCES.inp

# Output: sc_gmm_parenting_FREED_VARIANCES.out
```

### What to Check:

1. Look for class-specific parenting effects:
   ```
   Class 1:
   SC_3 ON H3     0.XXX    (BH3NOW_C1)

   Class 2:
   SC_3 ON H3     0.XXX    (BH3NOW_C2)
   ```

2. Check if effects differ significantly across classes (MODEL TEST section)

## Optional: Sensitivity Analyses

### Test Effect of Survey Weights

```bash
cd /home/user/mplus-dissertation/revised_analyses/05_sensitivity

# Run model without weights
mplus gmm_no_weights.inp
```

Compare results with weighted model. Class means should be similar, proportions may differ.

### Test Freed Time Scores

```bash
cd /home/user/mplus-dissertation/revised_analyses/02_mixture_revised

# Run model with class-specific trajectory shapes
mplus sc_gmm_lgbm_c3_FREED_TIMESCORES.inp
```

Check if trajectory SHAPES differ significantly across classes (MODEL TEST section).

## Troubleshooting

### Mplus Errors

**"File not found"**
- Check data file path in .inp file
- Make sure using relative path: `../../growth_mixture_models/...`

**"Model did not converge"**
- Increase STARTS: Change `STARTS = 4000 1000;` to `STARTS = 6000 1500;`
- Increase STITERATIONS: Change `STITERATIONS = 50;` to `STITERATIONS = 100;`

**"Covariance matrix not positive definite"**
- Common with freed variances
- Try constraining some parameters
- Check for small classes

### R Errors

**"package not found"**
```r
# In R console:
install.packages("package_name")
```

**"cannot open file"**
```bash
# Check working directory:
getwd()
# Should be: /home/user/mplus-dissertation

# If not:
setwd("/home/user/mplus-dissertation")
```

## Quick Results Summary

After running all analyses, you should have:

### Mplus Outputs
- `sc_gmm_lgbm_c3_FREED_VARIANCES.out` - Main revised model
- `sc_gmm_parenting_FREED_VARIANCES.out` - Parenting effects
- `gmm_no_weights.out` - Sensitivity check

### R Outputs (CSVs)
- `measurement_invariance_comparison.csv`
- `mixture_model_comparison.csv`
- `wave_missingness_summary.csv`
- `attrition_summary.csv`
- `complete_vs_incomplete_comparison.csv`
- `descriptive_comparison_continuous.csv`
- `class_sizes.csv`

### Figures
- `trajectory_plot_by_class.png`

## Creating Tables for Dissertation

All CSV files can be opened in Excel/Google Sheets and formatted for your dissertation.

### Key Tables to Include:

1. **Table 1:** Sample characteristics and attrition
   - Use: `attrition_summary.csv`

2. **Table 2:** Measurement invariance tests
   - Use: `measurement_invariance_comparison.csv`

3. **Table 3:** Class enumeration
   - Use: `mixture_model_comparison.csv`

4. **Table 4:** Class-specific growth parameters
   - Extract from: `sc_gmm_lgbm_c3_FREED_VARIANCES.out`
   - Include: Intercept/slope means AND variances by class

5. **Table 5:** Parenting effects by class
   - Extract from: `sc_gmm_parenting_FREED_VARIANCES.out`

6. **Table 6:** Validation - Demographics by class
   - Use: `descriptive_comparison_continuous.csv`

## Next Steps

1. **Compare BIC:** Is freed variance model better than original?
2. **Examine variances:** Do classes differ in heterogeneity?
3. **Interpret classes:** What do trajectory profiles mean?
4. **Validate:** Do classes predict outcomes as expected?
5. **Write up:** Integrate results into dissertation

## Time Estimates

- Mplus runs: 1-2 hours total (mostly waiting)
- R scripts: 5-10 minutes total
- Reviewing output: 2-3 hours
- Creating tables: 2-3 hours
- Interpretation/writing: Ongoing

## Getting Help

If you encounter issues:

1. **Check error messages carefully** - They're usually informative
2. **Review the main README** - More detailed explanations
3. **Consult Mplus User's Guide** - Chapter 14 (mixture models)
4. **Check file paths** - Most errors are path-related

## Final Checklist

Before considering analysis complete:

- [ ] Freed variance model converged successfully
- [ ] BIC improved compared to original model
- [ ] Entropy > 0.60
- [ ] All classes > 5% of sample
- [ ] Missing data diagnostics complete
- [ ] Classes validated on demographics
- [ ] Parenting model with freed variances converged
- [ ] Results tables created
- [ ] Trajectory plot generated
- [ ] Interpretation notes written

## Key Files to Keep

For reproducibility, archive:
- All .inp files (original and revised)
- All .out files
- All .csv files
- All R scripts
- trajectory_plot_by_class.png
- This documentation

## Contact

Refer to:
- `EXPERT_REVIEW_SUMMARY.md` - Detailed rationale for each revision
- `README.md` - Comprehensive documentation
- Mplus User's Guide - Technical details
- Methodological papers cited in documentation

Good luck with your revisions!
