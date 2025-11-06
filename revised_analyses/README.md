# Revised Analyses for Self-Control Dissertation

This directory contains revised and enhanced analysis scripts addressing methodological improvements identified in the expert review.

## Overview

This package addresses critical methodological issues:

1. **Freed variance constraints in mixture models** (most critical)
2. **Comprehensive model comparison tables**
3. **Missing data diagnostics**
4. **External validation analyses**
5. **Sensitivity analyses**

## Directory Structure

```
revised_analyses/
├── 01_measurement/          # Measurement invariance refinements
├── 02_mixture_revised/      # Revised GMM specifications
├── 03_diagnostics/          # Model comparison and missing data tools
├── 04_validation/           # External validation analyses
├── 05_sensitivity/          # Sensitivity analyses
└── README.md               # This file
```

## Critical Revisions

### 1. Freed Growth Variances by Class

**Problem Addressed:**
Original models constrained intercept/slope variances and covariances to be equal across latent classes. This defeats much of the purpose of mixture modeling, as classes often differ in variability as well as means.

**Solution:**
- `02_mixture_revised/sc_gmm_lgbm_c3_FREED_VARIANCES.inp`
- `02_mixture_revised/sc_gmm_parenting_FREED_VARIANCES.inp`

**Impact:**
- Allows classes to have different levels of between-person heterogeneity
- More theoretically appropriate (e.g., "declining" class may show more variability)
- Expected to improve model fit (BIC) and interpretability

**Usage:**
```bash
# Run revised 3-class model with freed variances
cd /home/user/mplus-dissertation/revised_analyses/02_mixture_revised
mplus sc_gmm_lgbm_c3_FREED_VARIANCES.inp
```

### 2. Freed Time Scores by Class

**Problem Addressed:**
Original models constrained time scores (trajectory shapes) to be identical across classes. This forces all classes to have the same curvature, differing only in intercept and slope.

**Solution:**
- `02_mixture_revised/sc_gmm_lgbm_c3_FREED_TIMESCORES.inp`

**Impact:**
- Allows classes to have qualitatively different developmental patterns
- One class might show early change, another late change
- Tests if shape differences are statistically significant

### 3. Model Comparison Tables

**Problem Addressed:**
No systematic model comparison tables for measurement invariance or mixture model enumeration.

**Solution:**
- `03_diagnostics/extract_model_fit.R`

**Features:**
- Extracts fit indices from all Mplus .out files
- Creates publication-ready comparison tables
- Provides interpretation guidelines
- Identifies best-fitting models by BIC

**Usage:**
```bash
cd /home/user/mplus-dissertation
Rscript revised_analyses/03_diagnostics/extract_model_fit.R
```

**Output:**
- `measurement_invariance_comparison.csv`
- `mixture_model_comparison.csv`
- Formatted tables printed to console

### 4. Missing Data Diagnostics

**Problem Addressed:**
1,450 missing data patterns not analyzed. Need to verify MCAR assumption and document attrition.

**Solution:**
- `03_diagnostics/missing_data_analysis.R`

**Features:**
- Wave-by-wave missingness patterns
- Little's MCAR test
- Complete vs incomplete case comparisons
- Attrition analysis (monotone vs intermittent)

**Usage:**
```bash
cd /home/user/mplus-dissertation
Rscript revised_analyses/03_diagnostics/missing_data_analysis.R
```

**Output:**
- `wave_missingness_summary.csv`
- `attrition_summary.csv`
- `complete_vs_incomplete_comparison.csv`

### 5. External Validation

**Problem Addressed:**
Trajectory classes need validation against external outcomes to demonstrate construct validity.

**Solutions:**
- `04_validation/external_validation_template.inp` - Mplus template for R3STEP
- `04_validation/descriptive_validation.R` - Descriptive comparisons by class

**Features:**
- Compare classes on baseline characteristics
- Test associations with outcomes (academic, behavioral, mental health)
- Calculate effect sizes (Cohen's d)
- Generate trajectory plots by class

**Usage:**
```bash
# Descriptive validation
cd /home/user/mplus-dissertation
Rscript revised_analyses/04_validation/descriptive_validation.R

# Then modify and run Mplus template with outcome variables
```

### 6. Sensitivity Analyses

**Problem Addressed:**
Need to test robustness of findings to modeling decisions, especially survey weights.

**Solution:**
- `05_sensitivity/gmm_no_weights.inp`

**Features:**
- Test if class structure depends on survey weights
- Compare weighted vs unweighted class proportions
- Assess stability of trajectory shapes

## Recommended Analysis Workflow

### Phase 1: Measurement Foundation (if needed)
```bash
cd /home/user/mplus-dissertation/revised_analyses/01_measurement

# 1. If strong invariance failed, establish partial invariance
# Review original strong_invariance.out modification indices first
# Then modify partial_invariance_template.inp accordingly
mplus partial_invariance_template.inp
```

### Phase 2: Run Revised Mixture Models
```bash
cd /home/user/mplus-dissertation/revised_analyses/02_mixture_revised

# 2. Run GMM with freed variances (CRITICAL)
mplus sc_gmm_lgbm_c3_FREED_VARIANCES.inp

# 3. Run GMM with freed time scores
mplus sc_gmm_lgbm_c3_FREED_TIMESCORES.inp

# 4. Run parenting model with freed variances
mplus sc_gmm_parenting_FREED_VARIANCES.inp
```

### Phase 3: Model Comparison and Diagnostics
```bash
cd /home/user/mplus-dissertation

# 5. Extract model fit statistics
Rscript revised_analyses/03_diagnostics/extract_model_fit.R

# 6. Analyze missing data patterns
Rscript revised_analyses/03_diagnostics/missing_data_analysis.R
```

### Phase 4: Validation
```bash
# 7. Descriptive validation
Rscript revised_analyses/04_validation/descriptive_validation.R

# 8. External validation (requires outcome data)
# Modify external_validation_template.inp with available outcomes
cd revised_analyses/04_validation
# mplus external_validation_template.inp  # After modification
```

### Phase 5: Sensitivity Analysis
```bash
cd /home/user/mplus-dissertation/revised_analyses/05_sensitivity

# 9. Test sensitivity to survey weights
mplus gmm_no_weights.inp
```

## Expected Results

### Model Fit Changes
After freeing growth variances, expect:
- **BIC reduction** of 10-50 points (better fit)
- **Entropy** may decrease slightly (acceptable if > .60)
- **Class proportions** may shift moderately
- **Growth means** should remain substantively similar

### Statistical Significance
With freed variances:
- Variance estimates should differ significantly across classes
- Wald tests will show if differences are significant
- Include these tests in results tables

### Interpretation
Classes may now differ on:
1. **Intercept level** (starting point)
2. **Slope magnitude** (rate of change)
3. **Intercept variance** (heterogeneity in starting point)
4. **Slope variance** (heterogeneity in change rates)
5. **Intercept-slope correlation** (relationship between starting point and change)

## Required Software

- **Mplus 8.0+** (version 8.8 used in original analyses)
- **R 4.0+** with packages:
  - `tidyverse`
  - `MplusAutomation`
  - `naniar`
  - `mice`
  - `BaylorEdPsych`
  - `effsize`
  - `knitr`
  - `kableExtra`

### Installing R Packages
```r
install.packages(c("tidyverse", "MplusAutomation", "naniar", "mice",
                   "BaylorEdPsych", "effsize", "knitr", "kableExtra"))
```

## Reporting Results

### For Dissertation/Publication

1. **Measurement Section:**
   - Report full invariance test sequence (Table from `extract_model_fit.R`)
   - If partial invariance: Document which constraints freed and why
   - Report final model fit indices

2. **Missing Data Section:**
   - Wave-by-wave missingness table
   - Little's MCAR test results
   - Comparison of completers vs non-completers
   - Justify FIML approach

3. **Mixture Model Selection:**
   - Class enumeration table (1-4 classes) with:
     * Log-likelihood, AIC, BIC, aBIC
     * Entropy
     * BLRT p-value
     * Smallest class proportion
   - Justify 3-class solution

4. **Revised Model Results:**
   - Report that variances were freed (vs constrained in initial models)
   - Test and report class differences in variances
   - Include Wald tests for variance differences
   - Interpret substantively (which classes more heterogeneous?)

5. **Validation:**
   - Descriptive differences by class (demographics, baseline characteristics)
   - External criterion validation (outcomes)
   - Effect sizes (Cohen's d) for all comparisons

6. **Sensitivity:**
   - Report weighted vs unweighted results
   - Note any substantive differences
   - Justify use of weighted estimates

## Key References

### Methodological
- **Asparouhov, T., & Muthen, B. (2014).** Auxiliary variables in mixture modeling. *Structural Equation Modeling*, 21(3), 329-341.
- **Nylund, K. L., Asparouhov, T., & Muthen, B. O. (2007).** Deciding on the number of classes in latent class analysis. *Structural Equation Modeling*, 14(4), 535-569.
- **Muthén, B. (2004).** Latent variable analysis: Growth mixture modeling. In D. Kaplan (Ed.), *Handbook of quantitative methodology for the social sciences* (pp. 345-368).
- **Liu, Y., & Hancock, G. R. (2014).** Investigating partial measurement invariance. In W. Schweizer (Ed.), *Structural equation modeling* (pp. 97-117).

### Substantive
- **Hay, C., & Forrest, W. (2006).** The development of self-control. *Criminology*, 44(4), 739-771.
- **Nagin, D. S., & Odgers, C. L. (2010).** Group-based trajectory modeling in clinical research. *Annual Review of Clinical Psychology*, 6, 109-138.

## Troubleshooting

### Mplus Errors

**"WARNING: THE COVARIANCE MATRIX IS NOT POSITIVE DEFINITE"**
- Common with freed variances in mixture models
- Try: Increase `STARTS` or add `OPTSEED`
- May need to constrain some parameters for identification

**"MODEL DID NOT CONVERGE"**
- Increase `STITERATIONS` to 100
- Try different starting values seed
- Simplify model (e.g., constrain residual variances)

**"CLASS 3 HAS FEWER THAN 5% OF CASES"**
- Small class warning
- Check if class is substantively meaningful
- Consider testing 2-class vs 4-class models

### R Errors

**"Package 'MplusAutomation' not found"**
```r
install.packages("MplusAutomation")
```

**"Error in readModels(): File not found"**
- Check file paths in scripts
- Ensure .out files exist from Mplus runs
- Verify working directory is set correctly

**"Little's MCAR test fails to converge"**
- Expected with complex missing patterns
- Try subsetting to complete waves
- Report descriptive patterns instead

## Contact and Support

For questions about these revised analyses:
1. Review Mplus User's Guide (especially mixture modeling section)
2. Consult methodological references cited above
3. Check Mplus discussion board: www.statmodel.com/discussion

## Version History

- **v1.0 (2025-01-05)**: Initial revised analysis package
  - Freed variance specifications
  - Model comparison tools
  - Missing data diagnostics
  - External validation templates
  - Sensitivity analyses

## License

These analysis scripts are provided as supplementary materials for academic research. They may be freely used, modified, and distributed for non-commercial academic purposes with appropriate attribution.

## Citation

If using these revised analyses in publications:

> Revised mixture modeling specifications with freed class-specific growth variances, following recommendations of Muthén (2004) and Nylund et al. (2007). Analysis code available at [repository].

---

**IMPORTANT NOTES:**

1. **Always compare revised models to originals** - Document improvements in fit and interpretability

2. **Report both constrained and freed models** - Transparency about modeling decisions

3. **Justify analytical choices** - Cite methodological literature for each decision

4. **Focus on substantive interpretation** - Statistical improvements should enhance theoretical understanding

5. **Document all modifications** - Keep detailed notes on modeling decisions for reproducibility
