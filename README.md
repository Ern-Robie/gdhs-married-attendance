# Replication code: school attendance among married women in Ghana, 1993-2022

Stata code for the paper **"Women in the Classroom: Three Decades of School Attendance Among Married Women in Ghana"** (Robert Naatey Angmor, University of Cape Coast).

The analysis uses six Ghana Demographic and Health Surveys (1993, 1998, 2003, 2008, 2014, 2022). The outcome is school attendance among married or cohabiting women aged 15-24.

## Data

The DHS data are not included, because the DHS Program does not permit redistribution. To reproduce the results:

1. Register at <https://dhsprogram.com> and request access to the Ghana surveys listed above.
2. Download the **Person Recode (PR)** and **Individual Recode (IR)** files in Stata format (.DTA) for each survey.
3. Unzip them and place all twelve .DTA files in the `raw/` folder. The file names expected by the code are set in `do/00_master.do` (section 2).

## Requirements

- Stata 17 or later
- User-written packages `estout`, `coefplot`, `firthlogit`, `fairlie`, `oaxaca` (installed automatically from SSC by `00_master.do`)

## How to run

1. Set Stata's working directory to this folder (the one containing `do/` and `raw/`).
2. Run `do do/00_master.do`.

The master file creates `data/`, `tables/`, `figures/` and `logs/` and runs every script in order. Random seed: 20261108.

## Contents

| File | Purpose |
|---|---|
| `00_master.do` | Paths, file names, settings, packages, run order |
| `00_inventory.do` | Lists the DHS files found and the variables available |
| `01_build.do` | Builds the pooled analysis file (`data/gdhs_pooled.dta`) |
| `02_audit.do` | Participant flow, missingness, consistency and design checks |
| `03_trends.do` | Weighted attendance trends, figures and trend tests |
| `04_models.do` | Survey-weighted logit models, interactions, sensitivity analyses |
| `05_decomposition.do` | Two-way, Fairlie and Oaxaca-Blinder decompositions |
| `06_firth.do` | Firth penalised-likelihood robustness checks |
| `07_table1.do` | Table 1: weighted sample characteristics by period |
| `08_additional_analyses.do` | Supplementary analyses (alternative contrasts, education, comparison group, bounds) |
| `09_robustness_checks.do` | Further robustness checks (reference categories, ratio and difference scales, Yun-normalised decompositions, power) |
| `_make_dummies.do`, `_load_extra.do` | Helper scripts called by the files above |

## Survey design

All estimates use survey weights (`v005/1,000,000`), PSUs and strata, with `singleunit(centered)`. Subpopulations are analysed with `svy, subpop()`. Firth logit and the decomposition commands do not support the full survey design; the corresponding scripts state how weights and clustering are handled.

## Citation

Please cite the paper and this repository (see `CITATION.cff`).

## Licence

Code: MIT licence (see `LICENSE`). The DHS data remain subject to the DHS Program terms of use.
