* Deadly Sins? Religion and the Marginal Utility of Income
* Build soep_2023.dta from licensed SOEP-Core v40.1 (EU Edition) files.
version 17
set more off
set type double
capture log close sourcebuild
log using "$OUTDIR/00_source_construction.log", text replace name(sourcebuild)

use "$SOEP_DIR/pl.dta", clear
label language EN

* Merge SOEP person-year sources. Default merge behavior retains all records.
merge 1:1 pid syear using "$SOEP_DIR/pequiv.dta"
drop _merge
label language EN
merge 1:1 pid syear using "$SOEP_DIR/ppathl.dta"
drop _merge
label language EN
merge 1:1 pid syear using "$SOEP_DIR/pgen.dta"
drop _merge
label language EN

* Household files are one observation per household and survey year.
merge m:1 hid syear using "$SOEP_DIR/hl.dta"
drop _merge
label language EN
merge m:1 hid syear using "$SOEP_DIR/hgen.dta"
drop _merge
label language EN

merge 1:1 pid syear using "$SOEP_DIR/gripstr.dta"
drop _merge
label language EN
merge 1:1 pid syear using "$SOEP_DIR/bioimmig.dta"
drop _merge
label language EN

rename syear year
rename pid persnr
rename hid hhnr

* Life satisfaction and related responses
gen happy = p11101
replace happy = . if happy < 0

gen job_sat = plh0173
replace job_sat = . if job_sat < 0

gen inc_sat = plh0175
replace inc_sat = . if inc_sat < 0

gen hea_sat = m11125
replace hea_sat = . if hea_sat < 0

gen curhealth = m11126
replace curhealth = . if curhealth < 0
recode curhealth (5=1) (4=2) (3=3) (2=4) (1=5)

* Demographic and household covariates
gen age = d11101
keep if age > 15

gen state = l11101
replace state = . if state < 0

gen female = 1 if sex == 2
replace female = 0 if sex == 1

replace e11102 = . if e11102 < 0
rename e11102 emp_stat

gen workh = plb0186_h
replace workh = 0 if workh < 0
replace workh = 1 if workh == 0

replace d11104 = . if d11104 < 0
gen marital = d11104

gen kid01 = h11103
gen kid24 = h11104
gen kid57 = h11105
gen kid810 = h11106
gen kid1112 = h11107
gen kid1315 = h11108
gen kid1618 = h11109

gen hsize = d11106
gen nofch = d11107

replace d11109 = . if d11109 < 7
rename d11109 educ

* Wage and annual disposable household income
gen wageinc = i11110
replace wageinc = . if wageinc < 0
replace wageinc = 1 if wageinc == 0
gen lwage = log(wageinc)

gen labinc = i11102
replace labinc = . if labinc < 0
replace labinc = 1 if labinc == 0
gen linc_hh = log(labinc)

gen scale   = 1 + 0.7*(d11106 - d11107 - 1) + 0.5*d11107
gen scale_m = 1 + 0.5*(d11106 - d11107 - 1) + 0.3*d11107

gen eq_inc   = labinc/scale
gen eq_inc_m = labinc/scale_m
replace eq_inc = 1 if eq_inc < 1
replace eq_inc_m = 1 if eq_inc_m < 1
gen linc_eq   = log(eq_inc)
gen linc_eq_m = log(eq_inc_m)

* Non-labour income
gen nlabh = renty + divdy
replace nlabh = 0 if nlabh <= 0
gen nlabor = log(nlabh + 1)
label var nlabor "Log(1+non-labour income)"

* Confirm identifiers and saving filter fields expected by the analysis.
isid persnr year
foreach v in hlc0119_v1 hlc0119_v2 hlc0120_h linc_eq_m linc_hh {
    confirm numeric variable `v'
}
count
display as text "Constructed source person-year observations: " as result r(N)
save "$ROOT/data/soep_2023.dta", replace
log close sourcebuild
