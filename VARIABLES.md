# Variable definitions and source mapping

Source identifiers refer to SOEP-Core v40.1 (EU Edition), prior to the `00_build_soep_2023.do` construction. `01_estimate_tables.do` merges parental denomination from `bioparen.dta`.

| Final variable | Source variable(s) | Construction / interpretation |
| --- | --- | --- |
| `pid`, `year` | `pid`, `syear` | Individual and survey year; source-stage identifier `persnr` renamed to `pid` in the analysis. |
| `hhnr` | `hid` | Household identifier (source intermediate). |
| `psample` | `psample` | SOEP subsample code. Analysis retains codes 1, 3, 5, 6, 7, 8, 10–14. |
| `corigin` | `corigin` | Country-of-origin code; analysis retains `corigin == 276` (German-born restriction as implemented). |
| `happy` | `p11101` | Life satisfaction (0–10); negative values missing. |
| `age` | `d11101` | Age; analysis sample aged 20–80. |
| `female` | `sex` | 1 if `sex==2`, 0 if `sex==1`. |
| `state` | `l11101` | Federal state, negative codes missing. |
| `educ` | `d11109` | Years of education; values below 7 missing. |
| `marital` | `d11104` | Marital status; negative codes missing. |
| `emp_stat` | `e11102` | Employment status used for descriptive employed indicator; negative codes missing. |
| `e11103` | `e11103` | Employment status for regression controls; records with negative values excluded in table estimation. |
| `workh`, `lworkh` | `plb0186_h` | Working hours adjusted as in the code; `lworkh=ln(workh+1)`. |
| `hsize`, `nofch` | `d11106`, `d11107` | Household size and number of children. |
| `kid01`–`kid1618` | `h11103`–`h11109` | Numbers of children in seven age categories. |
| `curhealth` | `m11126` | Self-rated health, recoded so higher values denote better health (1–5). |
| `owner` | `hgowner` | Homeownership indicator equals 1 if `hgowner==1`. |
| `nlabor` | `renty`, `divdy` | `ln(1+max(0,renty+divdy))` for nonmissing amounts. |
| `linc_hh` | `i11102` | `ln(annual household disposable income)` after the source-stage zero/negative handling. |
| `linc_eq_m` | `i11102`, `d11106`, `d11107` | `ln(max(1, household income / modified OECD equivalence scale))`. |
| `pli0098_h`, `attend4` | `pli0098_h` | Attendance: source 5=never, 4=less often, 3=monthly, 1/2=daily/weekly; `attend4` recoded 1–4. |
| `any_attend` | `attend4` | 0=never; 1=any attendance including less often. |
| `freli`, `mreli` | `bioparen.dta`: `freli`, `mreli` | Paternal/maternal religious background merged by individual identifier. |
| `parent_denom` | `freli`, `mreli` | 1=both Catholic; 2=both Protestant; 3=mixed Catholic–Protestant; 4=other; 5=both without denomination. |
| `hlc0119_v1` | `hlc0119_v1` | Household savings filter, 1999–2014: 2=no saving. |
| `hlc0119_v2` | `hlc0119_v2` | Household savings filter, 2015–2019: 2=no saving. |
| `hlc0120_h` | `hlc0120_h` | Reported monthly household savings amount (EUR). |
| `saving_source`, `save_hh` | Savings filter and amount | Positive/nonnegative amount used if recorded; a skipped amount (`-2`/missing) set to zero **only** with explicit no-saving response; remaining invalid amounts missing. Annual savings=`12 × monthly savings`. |
| `lcons_eq_m` | `linc_hh`, `hlc0120_h`, household composition | `ln(1 + (annual household income − annual household savings)/modified OECD equivalence scale)` when defined. Proxy, not observed expenditure. |
| `rg_base`, `lref_base_loo` | `year`, `female`, `age`, `educ`, `state`, `linc_eq_m` | Comparison groups by year, gender, five age categories, two sample-derived education groups, and federal state. Log leave-one-out mean reference income; minimum 10 observations per group. |
| Consumption robustness reference measure | `lcons_eq_m` | Convert log own consumption back to level via `exp(lcons_eq_m)−1`, then log the leave-one-out mean level in the reference group. |

All variables used in the regressions, and the sampling and robustness restrictions, are implemented in the accompanying Stata files.
