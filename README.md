# Replication materials

**Deadly Sins? Religion and the Marginal Utility of Income**  
Alpaslan Akay | SOEP-Core v40.1 (EU Edition) | Stata 17

## Requirements

Access to the licensed SOEP-Core v40.1 (EU Edition) Stata data files `pl.dta`, `pequiv.dta`, `ppathl.dta`, `pgen.dta`, `hl.dta`, `hgen.dta`, `gripstr.dta`, `bioimmig.dta`, and `bioparen.dta`. No SOEP microdata are distributed with this package.

## Run

1. Clone or download this repository, and in Stata set the working directory to the repository folder (`cd "/path/to/DeadlySins-Replication"`).
2. In `run_all.do`, set `SOEP_DIR` to the folder containing the licensed SOEP `.dta` files.
3. Execute `do run_all.do` in Stata 17.

The driver builds `data/soep_2023.dta` from the original SOEP modules, merges parental religion from `bioparen.dta`, and generates all four tables, five analysis logs, and a source-construction log. `data/` and `output/` are generated locally; do not redistribute `data/`.

## Files

- `run_all.do` — runs the two stages sequentially.
- `code/00_build_soep_2023.do` — constructs the combined SOEP source file.
- `code/01_estimate_tables.do` — prepares the analytic data and estimates all specifications. This is the final checked analysis code, with only input/output paths adapted.
- `VARIABLES.md` — mapping from SOEP source variables to analysis variables.
- `reference/tables/` — four LaTeX tables from the last Stata run.
- `reference/logs/` — five corresponding Stata analysis logs.

## Expected estimates and samples

| Table / specification | Observations | Individuals |
| --- | ---: | ---: |
| Table 1: attendance | 89,135 | 18,745 |
| Table 1: denomination | 140,587 | 16,748 |
| Table 1: attendance × denomination | 76,991 | 16,159 |
| Table 2: denomination-defined reference groups (column 4) | 64,718 | 14,340 |
| Table 2: consumption proxy (column 8) | 84,493 | 18,376 |
| Appendix A.2: baseline descriptive sample | 89,135 | 18,745 |

Appendix A.1 counts refer to the **prepared source panel (1984–2023)**, before the main analysis restrictions (1999–2019, ages 20–80). Its 645,756 observations comprise 572,265 retained-sample and 73,491 excluded-sample observations. The reported person totals are sums of sample-specific counts.

## Data access

The raw SOEP files and locally constructed intermediate data are restricted by the SOEP licence and are not included. Researchers must obtain access to SOEP-Core v40.1 (EU Edition) from the data provider. The programs use individual fixed-effects regressions with standard errors clustered at the reference-group-year level. Tables are written as self-contained `.tex` tabular environments; the manuscript presents Tables 1 and 2 sideways.

The archived reference logs have generic folder paths in place of local computer paths; the numerical results are unchanged.
