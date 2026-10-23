* ==============================================================================
* ==============================================================================
* ==============================================================================
* ==============================================================================
//Religion and Relative Income
//Akay, 2026 
* ==============================================================================
* ==============================================================================
* ==============================================================================
* ==============================================================================
clear
version 17
set more off
set type double
capture log close _all

global OUTDIR "$ROOT/output"
capture mkdir "$OUTDIR"

log using "$OUTDIR/data_preparation.log", text replace name(dataprep)

use "$ROOT/data/soep_2023.dta", clear

* Savings filter variables already included in the combined SOEP file.
foreach v in hlc0119_v1 hlc0119_v2 hlc0120_h {
    capture confirm numeric variable `v'
    if _rc {
        di as error "Required savings variable not found: `v'"
        exit 111
    }
}


duplicates report persnr year

count
di as text "Main data observations before BIOPAREN merge: " r(N)


* ============================================================
* 2. Prepare BIOPAREN subset
* ============================================================

preserve

    use "$SOEP_DIR/bioparen.dta", clear

	rename pid persnr
    * Keep only variables needed from BIOPAREN.
    keep persnr freli mreli

    * BIOPAREN should be unique at pid level.
    duplicates report persnr

    * If this fails, inspect duplicates before merging.
    isid persnr, sort

    tempfile bioparen_religion
    save `bioparen_religion', replace

restore


* ============================================================
* 3. Merge parental religion into main data
* ============================================================

merge m:1 persnr using `bioparen_religion'

* Merge codes:
* _merge == 1: observation exists only in main data
* _merge == 2: observation exists only in BIOPAREN
* _merge == 3: matched observation

tab _merge

* Keep the main analytical panel.
* We keep all main-data observations and drop BIOPAREN-only records.
drop if _merge == 2

rename _merge merge_bioparen

label var freli "Father's religion, BIOPAREN"
label var mreli "Mother's religion, BIOPAREN"
label var merge_bioparen "Merge status: main data with BIOPAREN"
keep persnr year ///
     corigin state psample ///
     age female educ ///
     hlc0119_v1 hlc0119_v2 hlc0120_h linc_hh linc_eq_m ///
     hsize nofch workh hgowner ///
     happy marital emp_stat curhealth nlabor e11103 ///
     kid01 kid24 kid57 kid810 kid1112 kid1315 kid1618 ///
     pli0098_h mreli freli

* ==============================================================================
* Initial Selection (Only German-Born)
* Checked with migrants: the result is the same
* ==============================================================================
	keep if corigin == 276		

* ==============================================================================
* Prep of some variables
* ==============================================================================

* Saving and Consumption
* Only explicit no-saving answers with a skipped amount are coded zero.
* 1999-2014: hlc0119_v1=2 (No).
* 2015-2019: hlc0119_v2=2 (No).
gen byte no_saving_confirmed = 0
replace no_saving_confirmed = 1 if inrange(year,1999,2014) & hlc0119_v1 == 2
replace no_saving_confirmed = 1 if inrange(year,2015,2019) & hlc0119_v2 == 2

gen byte saving_source = 3
replace saving_source = 1 if hlc0120_h >= 0 & hlc0120_h < .
replace saving_source = 2 if no_saving_confirmed == 1 & ///
    (hlc0120_h == -2 | missing(hlc0120_h))
replace saving_source = 4 if no_saving_confirmed == 1 & ///
    hlc0120_h > 0 & hlc0120_h < .

label define savings_source_lbl 1 "Reported nonnegative savings" ///
    2 "Confirmed zero, amount not applicable/missing" ///
    3 "Unresolved missing savings" 4 "Conflicting responses", replace
label values saving_source savings_source_lbl

      g save_row = hlc0120_h
replace save_row = . if save_row < 0
replace save_row = 0 if saving_source == 2
replace save_row = . if saving_source == 4
replace save_row = 12*save_row
      g save_hh = save_row

      g inc_hh = exp(linc_hh)
      g cons_hh = inc_hh-save_hh

qui g scale2 = 1 + (0.7 * (hsize - nofch - 1)) + (0.5 * nofch) //Standard OECD scale
qui g scale2_m = 1 + (0.5 * (hsize - nofch - 1)) + (0.3 * nofch) //Standard OECD scale

	      g cons_eq_m = cons_hh/scale2_m
	      g save_eq_m = save_hh/scale2_m
	      g lcons_hh = log(cons_hh+1)
	      g lcons_eq_m = log(cons_eq_m+1)
	      g lsave_eq_m = log(save_eq_m+1)

* Working hours and home ownership
	
          g lworkh = log(workh+1)
	      g ownerh = hgowner
	replace ownerh  =. if ownerh<0
	      g owner = (ownerh == 1 & ownerh != .)
		  
		  

* ==============================================================================
* Delete Duplicates
* ==============================================================================
sort persnr year
duplicates report persnr year
duplicates tag persnr year, gen(yedup)
drop if yedup
drop yedup
xtset persnr year

drop if happy == .
rename persnr pid

* Saving data and calculated consumption by year
di as text "Saving filter, 1999-2014: v1 (1=Yes, 2=No)"
tab hlc0119_v1 if inrange(year,1999,2014), missing
di as text "Saving filter, 2015-2019: v2 (2=No saving)"
tab hlc0119_v2 if inrange(year,2015,2019), missing
di as text "2015-2019: explicit no-saving answers by amount status"
count if inrange(year,2015,2019) & hlc0119_v2==2
count if inrange(year,2015,2019) & hlc0119_v2==2 & hlc0120_h==-2
count if inrange(year,2015,2019) & hlc0119_v2==2 & missing(hlc0120_h)
count if inrange(year,2015,2019) & hlc0119_v2==2 & hlc0120_h>=0 & hlc0120_h<.
count if inrange(year,2015,2019) & hlc0119_v2==2 & hlc0120_h<0 & hlc0120_h!=-2
di as text "Savings classification for analysis years"
tab saving_source if inrange(year,1999,2019), missing
tab year saving_source if inrange(year,1999,2019), missing

di as text "Explicit no-saving response"
count if no_saving_confirmed == 1 & inrange(year,1999,2019)
di as text "Verified zeros recovered from inapplicable/missing amount"
count if saving_source == 2 & inrange(year,1999,2019)
di as text "Conflicting no-saving response and positive amount"
count if saving_source == 4 & inrange(year,1999,2019)
di as text "Original codes of missing saving amount for explicit no-saving responses"
tab hlc0120_h if no_saving_confirmed==1 & hlc0120_h<0 & ///
    inrange(year,1999,2019), missing

di as text "Annual frequency of originally reported nonnegative savings"
tab year if inrange(year,1999,2019) & saving_source == 1
di as text "Annual frequency of calculated consumption after verified zeros"
tab year if inrange(year,1999,2019) & !missing(lcons_eq_m)

/**********************************************************************
 Clean church attendance variable

 Source variable:
 pli0098_h = church attendance / visit of religious events [harmonized]

 Original coding:
 1 = Daily
 2 = At least once per week
 3 = At least once per month
 4 = Less often
 5 = Never

**********************************************************************/

capture drop attend4 attend_cat high_attend

* Four-category attendance variable, coded so that higher values mean more attendance.
gen byte attend4 = .

replace attend4 = 1 if pli0098_h == 5
replace attend4 = 2 if pli0098_h == 4
replace attend4 = 3 if pli0098_h == 3
replace attend4 = 4 if inlist(pli0098_h, 1, 2)

label define attend4_lbl ///
    1 "Never" ///
    2 "Less often" ///
    3 "At least monthly" ///
    4 "At least weekly", replace

label values attend4 attend4_lbl
label var attend4 "Church attendance"

* Same variable with a more explicit name, useful for tables.
gen byte attend_cat = attend4
label values attend_cat attend4_lbl
label var attend_cat "Church attendance category"

* Binary attendance variable for compact denomination-interaction tables.
gen byte high_attend = .
replace high_attend = 0 if inlist(attend4, 1, 2)
replace high_attend = 1 if inlist(attend4, 3, 4)

label define high_attend_lbl ///
    0 "Never or less often" ///
    1 "Monthly or weekly", replace

label values high_attend high_attend_lbl
label var high_attend "High church attendance"

* Diagnostics.
tab pli0098_h, missing
tab attend4, missing
tab high_attend, missing
tab year attend4 if !missing(attend4), missing


/**********************************************************************
 Clean parental religion variables from BIOPAREN

 freli = father's religion
 mreli = mother's religion

 Coding:
 1 Catholic
 2 Protestant
 3 Other Christian
 4 Islam
 5 Other religion
 6 No denomination
 Negative values are missing / not applicable.
**********************************************************************/

capture drop father_relig mother_relig ///
             father_cath father_prot mother_cath mother_prot ///
             parent_denom parent_cath parent_prot parent_mixed_cp ///
             parent_other parent_none

* Clean father and mother religion.
gen byte father_relig = .
replace father_relig = freli if inrange(freli, 1, 6)

gen byte mother_relig = .
replace mother_relig = mreli if inrange(mreli, 1, 6)

label define parent_relig_lbl ///
    1 "Catholic" ///
    2 "Protestant" ///
    3 "Other Christian" ///
    4 "Islam" ///
    5 "Other religion" ///
    6 "No denomination", replace

label values father_relig parent_relig_lbl
label values mother_relig parent_relig_lbl

label var father_relig "Father's religion"
label var mother_relig "Mother's religion"

* Basic parental denomination indicators.
gen byte father_cath = (father_relig == 1) if !missing(father_relig)
gen byte father_prot = (father_relig == 2) if !missing(father_relig)

gen byte mother_cath = (mother_relig == 1) if !missing(mother_relig)
gen byte mother_prot = (mother_relig == 2) if !missing(mother_relig)

label var father_cath "Father Catholic"
label var father_prot "Father Protestant"
label var mother_cath "Mother Catholic"
label var mother_prot "Mother Protestant"

* Combined parental denomination.
* 1 both Catholic
* 2 both Protestant
* 3 Catholic-Protestant mixed
* 4 other religious background
* 5 both no denomination

gen byte parent_denom = .

replace parent_denom = 1 if father_relig == 1 & mother_relig == 1
replace parent_denom = 2 if father_relig == 2 & mother_relig == 2
replace parent_denom = 3 if ///
    (father_relig == 1 & mother_relig == 2) | ///
    (father_relig == 2 & mother_relig == 1)

replace parent_denom = 5 if father_relig == 6 & mother_relig == 6

replace parent_denom = 4 if missing(parent_denom) & ///
    !missing(father_relig, mother_relig)

label define parent_denom_lbl ///
    1 "Both parents Catholic" ///
    2 "Both parents Protestant" ///
    3 "Catholic-Protestant mixed parents" ///
    4 "Other parental religious background" ///
    5 "Both parents no denomination", replace

label values parent_denom parent_denom_lbl
label var parent_denom "Parental denomination"

gen byte parent_cath = (parent_denom == 1) if !missing(parent_denom)
gen byte parent_prot = (parent_denom == 2) if !missing(parent_denom)
gen byte parent_mixed_cp = (parent_denom == 3) if !missing(parent_denom)
gen byte parent_other = (parent_denom == 4) if !missing(parent_denom)
gen byte parent_none = (parent_denom == 5) if !missing(parent_denom)

label var parent_cath "Both parents Catholic"
label var parent_prot "Both parents Protestant"
label var parent_mixed_cp "Catholic-Protestant mixed parents"
label var parent_other "Other parental religious background"
label var parent_none "Both parents no denomination"

* Diagnostics.
tab father_relig, missing
tab mother_relig, missing
tab parent_denom, missing
tab parent_denom attend4, missing

tab parent_denom attend4 if !missing(attend4), row col
tab parent_denom high_attend if !missing(attend4), row col


log close dataprep

* ==============================================================================
* Table 1. Main Results
* ==============================================================================
preserve
version 17
set more off

* ============================================================
* 0. Settings
* ============================================================

global ID      "pid"
global Y       "happy"
global INCOME  "linc_eq_m"

global OUTDIR "$ROOT/output"
capture mkdir "$OUTDIR"

capture log close table1
log using "$OUTDIR/table1_estimation.log", text replace name(table1)

local min_year      1999
local max_year      2019

local age_min       20
local age_max       80

local min_ref_cell  10

drop if e11103<0
global X "i.marital educ hsize kid01 kid24 kid57 kid810 kid1112 kid1315 kid1618 i.curhealth nlabor i.e11103 owner lworkh i.year i.state"

* Keep core SOEP samples suitable for native German analysis.
* Exclude migration/refugee and special-purpose samples.

keep if inlist(psample, 1, 3, 5, 6, 7, 8, 10, 11, 12, 13, 14)

* ============================================================
* 1. Basic restrictions
* ============================================================

count
di as text "Initial observations: " r(N)

keep if year >= `min_year'
keep if year <= `max_year'
drop if age < `age_min' | age > `age_max'

sort $ID year
xtset $ID year

count
di as text "After year and age restrictions: " r(N)


* ============================================================
* 2. Attendance and denomination variables
* ============================================================

capture drop any_attend christian_parent_sample parent_cp_sample parent_protestant

gen byte any_attend = .
replace any_attend = 0 if attend4 == 1
replace any_attend = 1 if inlist(attend4, 2, 3, 4)

label define any_attend_lbl ///
    0 "Never" ///
    1 "Any attendance", replace

label values any_attend any_attend_lbl
label var any_attend "Any church attendance"

gen byte christian_parent_sample = .
replace christian_parent_sample = 1 if inlist(parent_denom, 1, 2, 3)
replace christian_parent_sample = 0 if !missing(parent_denom) & !inlist(parent_denom, 1, 2, 3)

label var christian_parent_sample "Christian parental background sample"

gen byte parent_cp_sample = .
replace parent_cp_sample = 1 if inlist(parent_denom, 1, 2)
replace parent_cp_sample = 0 if !missing(parent_denom) & !inlist(parent_denom, 1, 2)

label var parent_cp_sample "Catholic or Protestant parental background sample"

gen byte parent_protestant = .
replace parent_protestant = 0 if parent_denom == 1
replace parent_protestant = 1 if parent_denom == 2

label define parent_protestant_lbl ///
    0 "Catholic parental background" ///
    1 "Protestant parental background", replace

label values parent_protestant parent_protestant_lbl
label var parent_protestant "Protestant parental background"

di as text " "
di as text "============================================================"
di as text "Religion diagnostics"
di as text "============================================================"

tab attend4, missing
tab any_attend, missing
tab parent_denom, missing
tab parent_denom any_attend if !missing(any_attend), row col


* ============================================================
* 3. Income variables
* ============================================================

capture drop labs_0 inc1

gen double labs_0 = $INCOME
gen double inc1   = exp(labs_0) if !missing(labs_0)

label var labs_0 "Log own income"
label var inc1 "Own income in levels"


* ============================================================
* 4. Baseline reference group
* ============================================================

foreach v in qeduc2 agefn refmiss_base rg_base {
    capture drop `v'
}

xtile qeduc2 = educ if !missing(educ), nq(2)

gen byte agefn = .
replace agefn = 1 if age <= 30 & !missing(age)
replace agefn = 2 if age > 30  & age <= 40
replace agefn = 3 if age > 40  & age <= 50
replace agefn = 4 if age > 50  & age <= 65
replace agefn = 5 if age > 65  & !missing(age)

gen byte refmiss_base = missing(year, female, agefn, qeduc2, state)

egen long rg_base = group(year female agefn qeduc2 state) if refmiss_base == 0

label var qeduc2  "Education group, two categories"
label var agefn   "Age group"
label var rg_base "Baseline reference group-year cell"


* ============================================================
* 5. Leave-one-out reference income
* ============================================================

foreach v in nref_base sum_inc_base lref_base_loo {
    capture drop `v'
}

bysort rg_base: egen long nref_base = count(inc1)
bysort rg_base: egen double sum_inc_base = total(inc1)

replace nref_base = . if missing(rg_base)
replace sum_inc_base = . if missing(rg_base)

gen double lref_base_loo = .

replace lref_base_loo = log((sum_inc_base - inc1) / (nref_base - 1)) ///
    if nref_base > 1 & !missing(inc1) & (sum_inc_base - inc1) > 0

replace lref_base_loo = log(sum_inc_base / nref_base) ///
    if missing(inc1) & nref_base > 0 & sum_inc_base > 0

replace lref_base_loo = . if nref_base < `min_ref_cell'

label var lref_base_loo "Log leave-one-out mean reference income"


* ============================================================
* 6. Samples
* ============================================================

capture drop sample_att sample_den sample_int

* Model 1: Christian parental background, including Catholic, Protestant, and mixed.
gen byte sample_att = !missing($Y, labs_0, lref_base_loo, any_attend, ///
    rg_base, christian_parent_sample)
replace sample_att = 0 if christian_parent_sample != 1

* Model 2 and Model 3: Catholic vs Protestant parental background only.
gen byte sample_den = !missing($Y, labs_0, lref_base_loo, parent_protestant, ///
    rg_base, parent_cp_sample)
replace sample_den = 0 if parent_cp_sample != 1

gen byte sample_int = !missing($Y, labs_0, lref_base_loo, any_attend, ///
    parent_protestant, rg_base, parent_cp_sample)
replace sample_int = 0 if parent_cp_sample != 1

di as text " "
di as text "============================================================"
di as text "Sample diagnostics"
di as text "============================================================"

count if sample_att == 1
di as text "Attendance sample before controls: " r(N)
tab any_attend if sample_att == 1, missing
tab parent_denom any_attend if sample_att == 1, row col

count if sample_den == 1
di as text "Denomination sample before controls: " r(N)
tab parent_protestant if sample_den == 1, missing

count if sample_int == 1
di as text "Interaction sample before controls: " r(N)
tab parent_protestant any_attend if sample_int == 1, row col


* ============================================================
* 7. Model 1 variables: never vs any attendance
* ============================================================

foreach v in own_never own_any ref_never ref_any {
    capture drop `v'
}

gen double own_never = 0 if sample_att == 1
gen double own_any   = 0 if sample_att == 1

gen double ref_never = 0 if sample_att == 1
gen double ref_any   = 0 if sample_att == 1

replace own_never = labs_0 if sample_att == 1 & any_attend == 0
replace own_any   = labs_0 if sample_att == 1 & any_attend == 1

replace ref_never = lref_base_loo if sample_att == 1 & any_attend == 0
replace ref_any   = lref_base_loo if sample_att == 1 & any_attend == 1


* ============================================================
* 8. Model 2 variables: average Catholic vs Protestant gradients
* ============================================================

foreach v in own_cath own_prot ref_cath ref_prot {
    capture drop `v'
}

gen double own_cath = 0 if sample_den == 1
gen double own_prot = 0 if sample_den == 1

gen double ref_cath = 0 if sample_den == 1
gen double ref_prot = 0 if sample_den == 1

replace own_cath = labs_0 if sample_den == 1 & parent_protestant == 0
replace own_prot = labs_0 if sample_den == 1 & parent_protestant == 1

replace ref_cath = lref_base_loo if sample_den == 1 & parent_protestant == 0
replace ref_prot = lref_base_loo if sample_den == 1 & parent_protestant == 1


* ============================================================
* 9. Model 3 variables: attendance x denomination
* ============================================================

foreach v in ///
    own_cath_never own_cath_any own_prot_never own_prot_any ///
    ref_cath_never ref_cath_any ref_prot_never ref_prot_any {
    capture drop `v'
}

gen double own_cath_never = 0 if sample_int == 1
gen double own_cath_any   = 0 if sample_int == 1
gen double own_prot_never = 0 if sample_int == 1
gen double own_prot_any   = 0 if sample_int == 1

gen double ref_cath_never = 0 if sample_int == 1
gen double ref_cath_any   = 0 if sample_int == 1
gen double ref_prot_never = 0 if sample_int == 1
gen double ref_prot_any   = 0 if sample_int == 1

replace own_cath_never = labs_0 if sample_int == 1 & parent_protestant == 0 & any_attend == 0
replace own_cath_any   = labs_0 if sample_int == 1 & parent_protestant == 0 & any_attend == 1
replace own_prot_never = labs_0 if sample_int == 1 & parent_protestant == 1 & any_attend == 0
replace own_prot_any   = labs_0 if sample_int == 1 & parent_protestant == 1 & any_attend == 1

replace ref_cath_never = lref_base_loo if sample_int == 1 & parent_protestant == 0 & any_attend == 0
replace ref_cath_any   = lref_base_loo if sample_int == 1 & parent_protestant == 0 & any_attend == 1
replace ref_prot_never = lref_base_loo if sample_int == 1 & parent_protestant == 1 & any_attend == 0
replace ref_prot_any   = lref_base_loo if sample_int == 1 & parent_protestant == 1 & any_attend == 1


* ============================================================
* 10. Estimate models
* ============================================================

sort $ID year
xtset $ID year

xtreg $Y ///
    c.own_never c.own_any ///
    c.ref_never c.ref_any ///
    i.any_attend ///
    $X ///
    if sample_att == 1, ///
    fe vce(cluster rg_base) nonest

estimates store M1


xtreg $Y ///
    c.own_cath c.own_prot ///
    c.ref_cath c.ref_prot ///
    i.parent_protestant ///
    $X ///
    if sample_den == 1, ///
    fe vce(cluster rg_base) nonest

estimates store M2


xtreg $Y ///
    c.own_cath_never c.own_cath_any ///
    c.own_prot_never c.own_prot_any ///
    c.ref_cath_never c.ref_cath_any ///
    c.ref_prot_never c.ref_prot_any ///
    i.parent_protestant##i.any_attend ///
    $X ///
    if sample_int == 1, ///
    fe vce(cluster rg_base) nonest

estimates store M3


* ============================================================
* 11. Key tests
* ============================================================

di as text " "
di as text "============================================================"
di as text "Model 1: Attendance"
di as text "============================================================"

estimates restore M1
test own_never = own_any
test ref_never = ref_any

di as text " "
di as text "============================================================"
di as text "Model 2: Denomination"
di as text "============================================================"

estimates restore M2
test own_cath = own_prot
test ref_cath = ref_prot

di as text " "
di as text "============================================================"
di as text "Model 3: Attendance x Denomination"
di as text "============================================================"

estimates restore M3

test own_cath_never = own_cath_any
test ref_cath_never = ref_cath_any

test own_prot_never = own_prot_any
test ref_prot_never = ref_prot_any

test (own_cath_any - own_cath_never) = (own_prot_any - own_prot_never)
test (ref_cath_any - ref_cath_never) = (ref_prot_any - ref_prot_never)


* ============================================================
* 12. Helper programs
* ============================================================

capture program drop make_coef_from_est
program define make_coef_from_est, rclass
    version 17
    syntax, EST(name) VAR(name)

    estimates restore `est'

    tempname b se t p

    capture scalar `b' = _b[`var']
    if _rc {
        return local bcell ""
        return local secell ""
        exit
    }

    scalar `se' = _se[`var']
    scalar `t'  = `b' / `se'
    scalar `p'  = 2 * ttail(e(df_r), abs(`t'))

    if missing(`p') {
        scalar `p' = 2 * normal(-abs(`t'))
    }

    local stars ""
    if (`p' < 0.01) {
        local stars "***"
    }
    else if (`p' < 0.05) {
        local stars "**"
    }
    else if (`p' < 0.10) {
        local stars "*"
    }

    local bstr : display %9.3f `b'
    local sestr : display %9.3f `se'

    local bstr = strtrim("`bstr'")
    local sestr = strtrim("`sestr'")

    return local bcell "`bstr'`stars'"
    return local secell "(`sestr')"
end


capture program drop make_p_from_est
program define make_p_from_est, rclass
    version 17
    syntax, EST(name) TEST(string)

    estimates restore `est'

    tempname p

    capture quietly test `test'
    if _rc {
        return local pcell ""
        exit
    }

    scalar `p' = r(p)

    local pstr : display %9.3f `p'
    local pstr = strtrim("`pstr'")

    return local pcell "`pstr'"
end


capture program drop make_stat_from_est
program define make_stat_from_est, rclass
    version 17
    syntax, EST(name) STAT(string)

    estimates restore `est'

    if "`stat'" == "N" {
        local v : display %12.0fc e(N)
    }
    else if "`stat'" == "N_g" {
        local v : display %12.0fc e(N_g)
    }
    else if "`stat'" == "r2_w" {
        local v : display %9.3f e(r2_w)
    }

    local v = strtrim("`v'")
    return local value "`v'"
end


capture program drop make_mrs_from_est
program define make_mrs_from_est, rclass
    version 17
    syntax, EST(name) OWN(name) REF(name)

    estimates restore `est'

    tempname m

    capture scalar `m' = -_b[`ref'] / _b[`own']
    if _rc {
        return local mcell ""
        exit
    }

    local mstr : display %9.3f `m'
    local mstr = strtrim("`mstr'")

    return local mcell "`mstr'"
end


* ============================================================
* 13. Collect table entries
* ============================================================

* -------------------------
* Model 1
* -------------------------

foreach v in own_never own_any ref_never ref_any {
    quietly make_coef_from_est, est(M1) var(`v')
    local c_`v' "`r(bcell)'"
    local s_`v' "`r(secell)'"
}

quietly make_mrs_from_est, est(M1) own(own_never) ref(ref_never)
local mrs_never "`r(mcell)'"

quietly make_mrs_from_est, est(M1) own(own_any) ref(ref_any)
local mrs_any "`r(mcell)'"

quietly make_p_from_est, est(M1) test("own_never = own_any")
local p_m1_own "`r(pcell)'"

quietly make_p_from_est, est(M1) test("ref_never = ref_any")
local p_m1_ref "`r(pcell)'"

quietly make_stat_from_est, est(M1) stat(N)
local n_m1 "`r(value)'"

quietly make_stat_from_est, est(M1) stat(N_g)
local id_m1 "`r(value)'"

quietly make_stat_from_est, est(M1) stat(r2_w)
local r2_m1 "`r(value)'"


* -------------------------
* Model 2
* -------------------------

foreach v in own_cath own_prot ref_cath ref_prot {
    quietly make_coef_from_est, est(M2) var(`v')
    local c_`v' "`r(bcell)'"
    local s_`v' "`r(secell)'"
}

quietly make_mrs_from_est, est(M2) own(own_cath) ref(ref_cath)
local mrs_cath "`r(mcell)'"

quietly make_mrs_from_est, est(M2) own(own_prot) ref(ref_prot)
local mrs_prot "`r(mcell)'"

quietly make_p_from_est, est(M2) test("own_cath = own_prot")
local p_m2_own "`r(pcell)'"

quietly make_p_from_est, est(M2) test("ref_cath = ref_prot")
local p_m2_ref "`r(pcell)'"

quietly make_stat_from_est, est(M2) stat(N)
local n_m2 "`r(value)'"

quietly make_stat_from_est, est(M2) stat(N_g)
local id_m2 "`r(value)'"

quietly make_stat_from_est, est(M2) stat(r2_w)
local r2_m2 "`r(value)'"


* -------------------------
* Model 3
* -------------------------

foreach v in ///
    own_cath_never own_cath_any own_prot_never own_prot_any ///
    ref_cath_never ref_cath_any ref_prot_never ref_prot_any {

    quietly make_coef_from_est, est(M3) var(`v')
    local c_`v' "`r(bcell)'"
    local s_`v' "`r(secell)'"
}

quietly make_mrs_from_est, est(M3) own(own_cath_never) ref(ref_cath_never)
local mrs_cath_never "`r(mcell)'"

quietly make_mrs_from_est, est(M3) own(own_cath_any) ref(ref_cath_any)
local mrs_cath_any "`r(mcell)'"

quietly make_mrs_from_est, est(M3) own(own_prot_never) ref(ref_prot_never)
local mrs_prot_never "`r(mcell)'"

quietly make_mrs_from_est, est(M3) own(own_prot_any) ref(ref_prot_any)
local mrs_prot_any "`r(mcell)'"

quietly make_p_from_est, est(M3) test("own_cath_never = own_cath_any")
local p_m3_own_cath "`r(pcell)'"

quietly make_p_from_est, est(M3) test("ref_cath_never = ref_cath_any")
local p_m3_ref_cath "`r(pcell)'"

quietly make_p_from_est, est(M3) test("own_prot_never = own_prot_any")
local p_m3_own_prot "`r(pcell)'"

quietly make_p_from_est, est(M3) test("ref_prot_never = ref_prot_any")
local p_m3_ref_prot "`r(pcell)'"

quietly make_p_from_est, est(M3) test("(own_cath_any - own_cath_never) = (own_prot_any - own_prot_never)")
local p_m3_own_gap "`r(pcell)'"

quietly make_p_from_est, est(M3) test("(ref_cath_any - ref_cath_never) = (ref_prot_any - ref_prot_never)")
local p_m3_ref_gap "`r(pcell)'"

quietly make_stat_from_est, est(M3) stat(N)
local n_m3 "`r(value)'"

quietly make_stat_from_est, est(M3) stat(N_g)
local id_m3 "`r(value)'"

quietly make_stat_from_est, est(M3) stat(r2_w)
local r2_m3 "`r(value)'"


* ============================================================
* 14. Write LaTeX table
* ============================================================

local texfile "$OUTDIR/table_income_gradients_attendance_denomination_interaction.tex"

capture file close fh
file open fh using "`texfile'", write replace

file write fh "\begin{table}[!htbp]" _n
file write fh "\centering" _n
file write fh "\caption{Income Gradients by Church Attendance and Denominational Background}" _n
file write fh "\label{tab:income_gradients_attendance_denomination}" _n
file write fh "\begingroup" _n
file write fh "\scriptsize" _n
file write fh "\setlength{\tabcolsep}{5.2pt}" _n
file write fh "\renewcommand{\arraystretch}{1.14}" _n
file write fh "\begin{adjustbox}{max width=1.00\textwidth,center}" _n
file write fh "\begin{tabular}{lcccccccc}" _n
file write fh "\toprule" _n
file write fh " & \multicolumn{2}{c}{Attendance} & \multicolumn{2}{c}{Denomination} & \multicolumn{4}{c}{Attendance $\times$ Denomination} \\" _n
file write fh "\cmidrule(lr){2-3}\cmidrule(lr){4-5}\cmidrule(lr){6-9}" _n
file write fh " & Never & Any & Catholic & Protestant & Cath. never & Cath. any & Prot. never & Prot. any \\" _n
file write fh "\midrule" _n

file write fh "Own income & `c_own_never' & `c_own_any' & `c_own_cath' & `c_own_prot' & `c_own_cath_never' & `c_own_cath_any' & `c_own_prot_never' & `c_own_prot_any' \\" _n
file write fh " & `s_own_never' & `s_own_any' & `s_own_cath' & `s_own_prot' & `s_own_cath_never' & `s_own_cath_any' & `s_own_prot_never' & `s_own_prot_any' \\" _n

file write fh "Reference income & `c_ref_never' & `c_ref_any' & `c_ref_cath' & `c_ref_prot' & `c_ref_cath_never' & `c_ref_cath_any' & `c_ref_prot_never' & `c_ref_prot_any' \\" _n
file write fh " & `s_ref_never' & `s_ref_any' & `s_ref_cath' & `s_ref_prot' & `s_ref_cath_never' & `s_ref_cath_any' & `s_ref_prot_never' & `s_ref_prot_any' \\" _n

file write fh "MRS & `mrs_never' & `mrs_any' & `mrs_cath' & `mrs_prot' & `mrs_cath_never' & `mrs_cath_any' & `mrs_prot_never' & `mrs_prot_any' \\" _n

file write fh "\addlinespace[0.25em]" _n
file write fh "\(p\)-value: own gradient equality & \multicolumn{2}{c}{`p_m1_own'} & \multicolumn{2}{c}{`p_m2_own'} & \multicolumn{2}{c}{`p_m3_own_cath'} & \multicolumn{2}{c}{`p_m3_own_prot'} \\" _n
file write fh "\(p\)-value: reference gradient equality & \multicolumn{2}{c}{`p_m1_ref'} & \multicolumn{2}{c}{`p_m2_ref'} & \multicolumn{2}{c}{`p_m3_ref_cath'} & \multicolumn{2}{c}{`p_m3_ref_prot'} \\" _n
file write fh "\(p\)-value: difference in attendance gaps &  &  &  &  & \multicolumn{2}{c}{Own: `p_m3_own_gap'} & \multicolumn{2}{c}{Ref.: `p_m3_ref_gap'} \\" _n

file write fh "\midrule" _n
file write fh "Observations & \multicolumn{2}{c}{`n_m1'} & \multicolumn{2}{c}{`n_m2'} & \multicolumn{4}{c}{`n_m3'} \\" _n
file write fh "Individuals & \multicolumn{2}{c}{`id_m1'} & \multicolumn{2}{c}{`id_m2'} & \multicolumn{4}{c}{`id_m3'} \\" _n
file write fh "Within \(R^2\) & \multicolumn{2}{c}{`r2_m1'} & \multicolumn{2}{c}{`r2_m2'} & \multicolumn{4}{c}{`r2_m3'} \\" _n

file write fh "\bottomrule" _n
file write fh "\end{tabular}" _n
file write fh "\end{adjustbox}" _n

file write fh "\vspace{0.45em}" _n
file write fh "\begin{minipage}{1.00\textwidth}" _n
file write fh "\footnotesize" _n
file write fh "\emph{Notes:} Standard errors clustered at the reference-group-year level are in parentheses. " _n
file write fh "The attendance sample includes individuals with Catholic, Protestant, or Catholic-Protestant mixed parental background. " _n
file write fh "The denomination and interaction samples are restricted to individuals whose parents are both Catholic or both Protestant. " _n
file write fh "Any attendance equals one for individuals who attend religious services less often, at least monthly, or at least weekly. " _n
file write fh "Own income is log equivalised household income. Reference income is the log leave-one-out mean income of the reference group. " _n
file write fh "Reference groups are defined by year, gender, age group, two education groups, and federal state. " _n
file write fh "MRS is minus the reference-income gradient divided by the own-income gradient. " _n
file write fh "All models include individual fixed effects, year fixed effects, state fixed effects, the relevant group indicators, and baseline controls. " _n
file write fh "* \(p<0.10\), ** \(p<0.05\), *** \(p<0.01\)." _n
file write fh "\end{minipage}" _n
file write fh "\endgroup" _n
file write fh "\end{table}" _n

file close fh

log close table1

restore

* ==============================================================================
* Table 2. Robustness
* ==============================================================================
preserve
version 17
set more off


* ============================================================
* 0. Settings
* ============================================================

global ID      "pid"
global Y       "happy"
global INCOME  "linc_eq_m"
global CONS    "lcons_eq_m"

global OUTDIR "$ROOT/output"
capture mkdir "$OUTDIR"

capture log close table2
log using "$OUTDIR/table2_estimation.log", text replace name(table2)

local min_year 1999
local max_year 2019

local age_min 20
local age_max 80

global X "i.marital educ hsize kid01 kid24 kid57 kid810 kid1112 kid1315 kid1618 i.curhealth nlabor i.e11103 owner lworkh i.year i.state"

drop if e11103 < 0


* ============================================================
* 1. Sample restrictions
* ============================================================

keep if inlist(psample, 1, 3, 5, 6, 7, 8, 10, 11, 12, 13, 14)

keep if year >= `min_year'
keep if year <= `max_year'
drop if age < `age_min' | age > `age_max'

sort $ID year
xtset $ID year


* ============================================================
* 2. Attendance and parental denomination
* ============================================================

capture drop any_attend christian_parent_sample christian_cp_sample

gen byte any_attend = .
replace any_attend = 0 if attend4 == 1
replace any_attend = 1 if inlist(attend4, 2, 3, 4)

label define any_attend_lbl 0 "Never" 1 "Any attendance", replace
label values any_attend any_attend_lbl
label var any_attend "Any church attendance"

gen byte christian_parent_sample = .
replace christian_parent_sample = 1 if inlist(parent_denom, 1, 2, 3)
replace christian_parent_sample = 0 if !missing(parent_denom) & !inlist(parent_denom, 1, 2, 3)

label var christian_parent_sample "Catholic, Protestant, or mixed parental background"

gen byte christian_cp_sample = .
replace christian_cp_sample = 1 if inlist(parent_denom, 1, 2)
replace christian_cp_sample = 0 if !missing(parent_denom) & !inlist(parent_denom, 1, 2)

label var christian_cp_sample "Both Catholic or both Protestant parental background"


* ============================================================
* 3. Income and consumption
* ============================================================

capture drop labs_0 inc1 lcons_0 cons1

gen double labs_0 = $INCOME
gen double inc1 = exp(labs_0) if !missing(labs_0)

gen double lcons_0 = $CONS
gen double cons1 = exp(lcons_0)-1 if !missing(lcons_0)

label var labs_0 "Log own income"
label var inc1 "Own income in levels"
label var lcons_0 "Log own consumption"
label var cons1 "Own consumption in levels"


* ============================================================
* 4. Reference-group components
* ============================================================

capture drop qeduc2 agefn married2

xtile qeduc2 = educ if !missing(educ), nq(2)
label var qeduc2 "Education group, two categories"

gen byte married2 = .
replace married2 = 1 if marital == 1
replace married2 = 0 if !missing(marital) & marital != 1

label define married2_lbl 0 "Not married" 1 "Married", replace
label values married2 married2_lbl
label var married2 "Married"

gen byte agefn = .
replace agefn = 1 if age <= 30 & !missing(age)
replace agefn = 2 if age > 30 & age <= 40
replace agefn = 3 if age > 40 & age <= 50
replace agefn = 4 if age > 50 & age <= 65
replace agefn = 5 if age > 65 & !missing(age)

label define agefn_lbl 1 "20-30" 2 "31-40" 3 "41-50" 4 "51-65" 5 "66-80", replace
label values agefn agefn_lbl
label var agefn "Age group"


* ============================================================
* 5. Base analysis samples
* ============================================================

capture drop sample_income_base sample_cons_base

gen byte sample_income_base = 1
replace sample_income_base = 0 if missing($Y)
replace sample_income_base = 0 if missing(labs_0)
replace sample_income_base = 0 if missing(any_attend)
replace sample_income_base = 0 if christian_parent_sample != 1
replace sample_income_base = 0 if missing(female)
replace sample_income_base = 0 if missing(agefn)
replace sample_income_base = 0 if missing(qeduc2)
replace sample_income_base = 0 if missing(state)

gen byte sample_cons_base = 1
replace sample_cons_base = 0 if missing($Y)
replace sample_cons_base = 0 if missing(lcons_0)
replace sample_cons_base = 0 if missing(any_attend)
replace sample_cons_base = 0 if christian_parent_sample != 1
replace sample_cons_base = 0 if missing(female)
replace sample_cons_base = 0 if missing(agefn)
replace sample_cons_base = 0 if missing(qeduc2)
replace sample_cons_base = 0 if missing(state)


* ============================================================
* 6. Program: estimate one specification
* ============================================================

capture program drop run_attendance_spec
program define run_attendance_spec
    version 17

    syntax, EST(name) RGVARS(string) MINCELL(integer) ///
        [GINI MEDIAN RANK CONSUMP DENOMONLY FIXSAMPLE(name) SAVESAMPLE(name)]

    foreach v in rg_tmp nref_tmp sum_val_tmp med_val_tmp ref_tmp ///
        gini_tmp rank_tmp rankx_tmp sum_rankx_tmp relrank_tmp pos_tmp ///
        own_tmp val_tmp own_never own_any ref_never ref_any sample_tmp {
        capture drop `v'
    }

    if "`consump'" != "" {
        gen double own_tmp = lcons_0
        gen double val_tmp = cons1
        gen byte sample_tmp = sample_cons_base
    }
    else {
        gen double own_tmp = labs_0
        gen double val_tmp = inc1
        gen byte sample_tmp = sample_income_base
    }

    if "`denomonly'" != "" {
        replace sample_tmp = 0 if christian_cp_sample != 1
    }

    if "`fixsample'" != "" {
        replace sample_tmp = 0 if `fixsample' != 1
    }

    egen long rg_tmp = group(`rgvars') if !missing(val_tmp)

    bysort rg_tmp: egen long nref_tmp = count(val_tmp)
    bysort rg_tmp: egen double sum_val_tmp = total(val_tmp)

    gen double ref_tmp = .

    local cellrule "nref_tmp >= `mincell'"

    if "`rank'" != "" {

        sort rg_tmp val_tmp
        by rg_tmp: egen double pos_tmp = rank(val_tmp)

        gen double relrank_tmp = .
        replace relrank_tmp = (pos_tmp - 1) / (nref_tmp - 1) ///
            if `cellrule' & nref_tmp > 1 & !missing(pos_tmp)

        replace ref_tmp = relrank_tmp
    }
    else if "`median'" != "" {

        bysort rg_tmp: egen double med_val_tmp = median(val_tmp)

        replace ref_tmp = log(med_val_tmp) ///
            if `cellrule' & med_val_tmp > 0 & !missing(med_val_tmp)
    }
    else {

        replace ref_tmp = log((sum_val_tmp - val_tmp) / (nref_tmp - 1)) ///
            if `cellrule' & nref_tmp > 1 ///
            & !missing(val_tmp) & (sum_val_tmp - val_tmp) > 0
    }

    if "`gini'" != "" {

        sort rg_tmp val_tmp
        by rg_tmp: gen double rank_tmp = sum(!missing(val_tmp)) if !missing(val_tmp)
        gen double rankx_tmp = rank_tmp * val_tmp if !missing(val_tmp)

        bysort rg_tmp: egen double sum_rankx_tmp = total(rankx_tmp)

        gen double gini_tmp = ///
            (2 * sum_rankx_tmp) / (nref_tmp * sum_val_tmp) ///
            - (nref_tmp + 1) / nref_tmp ///
            if `cellrule' & nref_tmp > 1 & sum_val_tmp > 0

        replace sample_tmp = 0 if missing(gini_tmp)
    }

    replace sample_tmp = 0 if missing(own_tmp)
    replace sample_tmp = 0 if missing(ref_tmp)
    replace sample_tmp = 0 if missing(any_attend)
    replace sample_tmp = 0 if missing(rg_tmp)

    gen double own_never = 0 if sample_tmp == 1
    gen double own_any   = 0 if sample_tmp == 1
    gen double ref_never = 0 if sample_tmp == 1
    gen double ref_any   = 0 if sample_tmp == 1

    replace own_never = own_tmp if sample_tmp == 1 & any_attend == 0
    replace own_any   = own_tmp if sample_tmp == 1 & any_attend == 1

    replace ref_never = ref_tmp if sample_tmp == 1 & any_attend == 0
    replace ref_any   = ref_tmp if sample_tmp == 1 & any_attend == 1

    sort $ID year
    xtset $ID year

    if "`gini'" != "" {
        xtreg $Y ///
            c.own_never c.own_any ///
            c.ref_never c.ref_any ///
            i.any_attend ///
            c.gini_tmp ///
            $X ///
            if sample_tmp == 1, ///
            fe vce(cluster rg_tmp) nonest
    }
    else {
        xtreg $Y ///
            c.own_never c.own_any ///
            c.ref_never c.ref_any ///
            i.any_attend ///
            $X ///
            if sample_tmp == 1, ///
            fe vce(cluster rg_tmp) nonest
    }

    estimates store `est'

    if "`savesample'" != "" {
        capture drop `savesample'
        gen byte `savesample' = e(sample)
    }

    di as text " "
    di as text "Specification `est'"
    di as text "N = " e(N) " ; Individuals = " e(N_g) " ; Within R2 = " %6.3f e(r2_w)

    foreach v in rg_tmp nref_tmp sum_val_tmp med_val_tmp ref_tmp ///
        gini_tmp rank_tmp rankx_tmp sum_rankx_tmp relrank_tmp pos_tmp ///
        own_tmp val_tmp own_never own_any ref_never ref_any sample_tmp {
        capture drop `v'
    }
end


* ============================================================
* 7. Define fixed samples through actual estimation samples
* ============================================================

run_attendance_spec, ///
    est(R1) ///
    rgvars("year female agefn qeduc2 state") ///
    mincell(10) ///
    savesample(sample_R1)

run_attendance_spec, ///
    est(INTBASE) ///
    rgvars("year female agefn qeduc2 state") ///
    mincell(10) ///
    denomonly ///
    savesample(sample_INT)


* ============================================================
* 8. Run robustness specifications
* ============================================================

run_attendance_spec, ///
    est(R2) ///
    rgvars("year female agefn state") ///
    mincell(10) ///
    fixsample(sample_R1)

run_attendance_spec, ///
    est(R3) ///
    rgvars("year female agefn married2 state") ///
    mincell(10) ///
    fixsample(sample_R1)

run_attendance_spec, ///
    est(R4) ///
    rgvars("year female agefn qeduc2 state parent_denom") ///
    mincell(10) ///
    denomonly ///
    fixsample(sample_INT)

run_attendance_spec, ///
    est(R5) ///
    rgvars("year female agefn qeduc2 state") ///
    mincell(10) ///
    median ///
    fixsample(sample_R1)

run_attendance_spec, ///
    est(R6) ///
    rgvars("year female agefn qeduc2 state") ///
    mincell(10) ///
    gini ///
    fixsample(sample_R1)

run_attendance_spec, ///
    est(R7) ///
    rgvars("year female agefn qeduc2 state") ///
    mincell(10) ///
    rank ///
    fixsample(sample_R1)

run_attendance_spec, ///
    est(R8) ///
    rgvars("year female agefn qeduc2 state") ///
    mincell(10) ///
    consump ///
    savesample(sample_R8)

run_attendance_spec, ///
    est(R9) ///
    rgvars("year female agefn qeduc2 state") ///
    mincell(25) ///
    fixsample(sample_R1)


* ============================================================
* Consumption sample: annual coverage and estimation samples
* ============================================================
di as text "Baseline attendance sample by survey year"
tab year if sample_R1 == 1
di as text "Savings classification within baseline estimation sample"
tab saving_source if sample_R1 == 1, missing
tab year saving_source if sample_R1 == 1, missing
di as text "Reported savings by survey year within baseline"
tab year if sample_R1 == 1 & saving_source == 1
di as text "Verified zero saving by survey year within baseline"
tab year if sample_R1 == 1 & saving_source == 2
di as text "Consumption regression sample by survey year"
tab year if sample_R8 == 1

di as text "Baseline sample"
count if sample_R1 == 1
di as text "Baseline: original valid savings amount"
count if sample_R1 == 1 & saving_source == 1
di as text "Baseline: verified zeros recovered"
count if sample_R1 == 1 & saving_source == 2
di as text "Baseline: unresolved missing savings"
count if sample_R1 == 1 & saving_source == 3
di as text "Baseline: conflicting responses"
count if sample_R1 == 1 & saving_source == 4
di as text "Baseline: valid calculated consumption"
count if sample_R1 == 1 & !missing(lcons_eq_m)
di as text "Baseline: in consumption regression"
count if sample_R1 == 1 & sample_R8 == 1
di as text "Baseline: valid consumption but excluded from consumption regression"
count if sample_R1 == 1 & sample_R8 != 1 & !missing(lcons_eq_m)
di as text "Consumption regression observations outside baseline"
count if sample_R1 != 1 & sample_R8 == 1

* ============================================================
* 9. Helper programs
* ============================================================

capture program drop make_coef_from_est
program define make_coef_from_est, rclass
    version 17
    syntax, EST(name) VAR(name)

    estimates restore `est'

    tempname b se t p

    capture scalar `b' = _b[`var']
    if _rc {
        return local bcell ""
        return local secell ""
        exit
    }

    scalar `se' = _se[`var']
    scalar `t'  = `b' / `se'
    scalar `p'  = 2 * ttail(e(df_r), abs(`t'))

    if missing(`p') {
        scalar `p' = 2 * normal(-abs(`t'))
    }

    local stars ""
    if (`p' < 0.01) {
        local stars "***"
    }
    else if (`p' < 0.05) {
        local stars "**"
    }
    else if (`p' < 0.10) {
        local stars "*"
    }

    local bstr : display %9.3f `b'
    local sestr : display %9.3f `se'

    local bstr = strtrim("`bstr'")
    local sestr = strtrim("`sestr'")

    return local bcell "`bstr'`stars'"
    return local secell "(`sestr')"
end


capture program drop make_p_from_est
program define make_p_from_est, rclass
    version 17
    syntax, EST(name) TEST(string)

    estimates restore `est'

    capture quietly test `test'
    if _rc {
        return local pcell ""
        exit
    }

    local pstr : display %9.3f r(p)
    local pstr = strtrim("`pstr'")

    return local pcell "`pstr'"
end


capture program drop make_stat_from_est
program define make_stat_from_est, rclass
    version 17
    syntax, EST(name) STAT(string)

    estimates restore `est'

    if "`stat'" == "N" {
        local v : display %12.0fc e(N)
    }
    else if "`stat'" == "N_g" {
        local v : display %12.0fc e(N_g)
    }
    else if "`stat'" == "r2_w" {
        local v : display %9.3f e(r2_w)
    }

    local v = strtrim("`v'")
    return local value "`v'"
end


* ============================================================
* 10. Collect table entries
* ============================================================

foreach m in R1 R2 R3 R4 R5 R6 R7 R8 R9 {

    quietly make_coef_from_est, est(`m') var(own_never)
    local c_own_never_`m' "`r(bcell)'"
    local s_own_never_`m' "`r(secell)'"

    quietly make_coef_from_est, est(`m') var(own_any)
    local c_own_any_`m' "`r(bcell)'"
    local s_own_any_`m' "`r(secell)'"

    quietly make_coef_from_est, est(`m') var(ref_never)
    local c_ref_never_`m' "`r(bcell)'"
    local s_ref_never_`m' "`r(secell)'"

    quietly make_coef_from_est, est(`m') var(ref_any)
    local c_ref_any_`m' "`r(bcell)'"
    local s_ref_any_`m' "`r(secell)'"

    quietly make_p_from_est, est(`m') test("own_never = own_any")
    local p_own_`m' "`r(pcell)'"

    quietly make_p_from_est, est(`m') test("ref_never = ref_any")
    local p_ref_`m' "`r(pcell)'"

    quietly make_stat_from_est, est(`m') stat(N)
    local n_`m' "`r(value)'"

    quietly make_stat_from_est, est(`m') stat(N_g)
    local id_`m' "`r(value)'"

    quietly make_stat_from_est, est(`m') stat(r2_w)
    local r2_`m' "`r(value)'"
}


* ============================================================
* 11. Write LaTeX table
* ============================================================

local texfile "$OUTDIR/table_robustness_attendance_income_gradients.tex"

capture file close fh
file open fh using "`texfile'", write replace

file write fh "\begin{table}[!t]" _n
file write fh "\centering" _n
file write fh "\caption{Robustness Checks: Church Attendance and Income Gradients}" _n
file write fh "\label{tab:robustness_attendance_income_gradients}" _n
file write fh "\begingroup" _n
file write fh "\scriptsize" _n
file write fh "\setlength{\tabcolsep}{3.5pt}" _n
file write fh "\renewcommand{\arraystretch}{1.12}" _n
file write fh "\begin{adjustbox}{max width=1.00\textwidth,center}" _n
file write fh "\begin{tabular}{lccccccccc}" _n
file write fh "\toprule" _n
file write fh " & (1) & (2) & (3) & (4) & (5) & (6) & (7) & (8) & (9) \\" _n
file write fh "\cmidrule(lr){2-10}" _n
file write fh " & Base & No educ. & Married & Denom. & Median & Gini & Rank & Consumption & Cell 25 \\" _n
file write fh "\midrule" _n

file write fh "Own income/consumption, never & `c_own_never_R1' & `c_own_never_R2' & `c_own_never_R3' & `c_own_never_R4' & `c_own_never_R5' & `c_own_never_R6' & `c_own_never_R7' & `c_own_never_R8' & `c_own_never_R9' \\" _n
file write fh " & `s_own_never_R1' & `s_own_never_R2' & `s_own_never_R3' & `s_own_never_R4' & `s_own_never_R5' & `s_own_never_R6' & `s_own_never_R7' & `s_own_never_R8' & `s_own_never_R9' \\" _n

file write fh "Own income/consumption, any attendance & `c_own_any_R1' & `c_own_any_R2' & `c_own_any_R3' & `c_own_any_R4' & `c_own_any_R5' & `c_own_any_R6' & `c_own_any_R7' & `c_own_any_R8' & `c_own_any_R9' \\" _n
file write fh " & `s_own_any_R1' & `s_own_any_R2' & `s_own_any_R3' & `s_own_any_R4' & `s_own_any_R5' & `s_own_any_R6' & `s_own_any_R7' & `s_own_any_R8' & `s_own_any_R9' \\" _n

file write fh "\(p\)-value: never = any & `p_own_R1' & `p_own_R2' & `p_own_R3' & `p_own_R4' & `p_own_R5' & `p_own_R6' & `p_own_R7' & `p_own_R8' & `p_own_R9' \\" _n

file write fh "\addlinespace[0.25em]" _n

file write fh "Reference income/position/consumption, never & `c_ref_never_R1' & `c_ref_never_R2' & `c_ref_never_R3' & `c_ref_never_R4' & `c_ref_never_R5' & `c_ref_never_R6' & `c_ref_never_R7' & `c_ref_never_R8' & `c_ref_never_R9' \\" _n
file write fh " & `s_ref_never_R1' & `s_ref_never_R2' & `s_ref_never_R3' & `s_ref_never_R4' & `s_ref_never_R5' & `s_ref_never_R6' & `s_ref_never_R7' & `s_ref_never_R8' & `s_ref_never_R9' \\" _n

file write fh "Reference income/position/consumption, any attendance & `c_ref_any_R1' & `c_ref_any_R2' & `c_ref_any_R3' & `c_ref_any_R4' & `c_ref_any_R5' & `c_ref_any_R6' & `c_ref_any_R7' & `c_ref_any_R8' & `c_ref_any_R9' \\" _n
file write fh " & `s_ref_any_R1' & `s_ref_any_R2' & `s_ref_any_R3' & `s_ref_any_R4' & `s_ref_any_R5' & `s_ref_any_R6' & `s_ref_any_R7' & `s_ref_any_R8' & `s_ref_any_R9' \\" _n

file write fh "\(p\)-value: never = any & `p_ref_R1' & `p_ref_R2' & `p_ref_R3' & `p_ref_R4' & `p_ref_R5' & `p_ref_R6' & `p_ref_R7' & `p_ref_R8' & `p_ref_R9' \\" _n

file write fh "\midrule" _n
file write fh "Observations & `n_R1' & `n_R2' & `n_R3' & `n_R4' & `n_R5' & `n_R6' & `n_R7' & `n_R8' & `n_R9' \\" _n
file write fh "Individuals & `id_R1' & `id_R2' & `id_R3' & `id_R4' & `id_R5' & `id_R6' & `id_R7' & `id_R8' & `id_R9' \\" _n
file write fh "Within \(R^2\) & `r2_R1' & `r2_R2' & `r2_R3' & `r2_R4' & `r2_R5' & `r2_R6' & `r2_R7' & `r2_R8' & `r2_R9' \\" _n

file write fh "\bottomrule" _n
file write fh "\end{tabular}" _n
file write fh "\end{adjustbox}" _n

file write fh "\vspace{0.45em}" _n
file write fh "\begin{minipage}{1.00\textwidth}" _n
file write fh "\footnotesize" _n
file write fh "\emph{Notes:} Standard errors clustered at the reference-group-year level are in parentheses. Columns (1)--(3) and (5)--(7) are estimated on the baseline attendance-sample estimation sample. Column (4) adds parental denomination to the reference-group definition within the Catholic/Protestant interaction sample and applies the minimum cell size of 10. Column (8) uses the consumption proxy and is estimated on its available sample; amounts are set to zero only for explicit no-saving responses with an inapplicable or missing amount, while other invalid values remain missing. Column (9) uses the baseline reference-group definition but requires a minimum reference-group-year cell size of 25. Any attendance equals one for individuals who attend religious services less often, at least monthly, or at least weekly. Own income is log equivalised household income, except in column (8), which uses log(1+equivalised consumption), computed from household income less reported annual savings. Reference income is the log leave-one-out mean income of the reference group, except in column (5), which uses log median reference income, column (7), which uses relative income rank, and column (8), which uses log leave-one-out mean equivalised consumption. The baseline reference group is defined by year, gender, age group, two education groups, and federal state. Column (2) removes education from the reference-group definition; column (3) replaces education with a married/non-married indicator; column (6) controls for reference-group-year inequality using the Gini coefficient. All models include individual, year, and state fixed effects and baseline controls including working hours. * \(p<0.10\), ** \(p<0.05\), *** \(p<0.01\)." _n
file write fh "\end{minipage}" _n
file write fh "\endgroup" _n
file write fh "\end{table}" _n

file close fh

log close table2

di as text "Done."
di as text "Robustness table saved to:"
di as text "`texfile'"
restore

* ==============================================================================
* Appendix Table A1. SOEP Sample Composition
* ==============================================================================
version 17
set more off


* ============================================================
* 0. Settings
* ============================================================

global OUTDIR "$ROOT/output"
capture mkdir "$OUTDIR"

capture log close tableA1
log using "$OUTDIR/tableA1_sample_composition.log", text replace name(tableA1)

quietly summarize year, meanonly
local source_year_min = r(min)
local source_year_max = r(max)
di as text "Sample-composition input period: " as result `source_year_min' "--" `source_year_max'

local texfile "$OUTDIR/appendix_table_soep_sample_composition.tex"


* ============================================================
* 1. Check required variables
* ============================================================

capture confirm variable psample
if _rc {
    di as error "Variable psample not found."
    exit 111
}

capture confirm variable pid
if _rc {
    di as error "Variable pid not found."
    exit 111
}


* ============================================================
* 2. English labels for psample
* ============================================================

label define psample_en_lbl ///
    1  "A Original Sample West, 1984" ///
    2  "B Migration Sample, 1984" ///
    3  "C Original Sample East, 1990" ///
    4  "D Migration Sample, 1994/95" ///
    5  "E Refreshment Sample, 1998" ///
    6  "F Refreshment Sample, 2000" ///
    7  "G High-Income Sample, 2002" ///
    8  "H Refreshment Sample, 2006" ///
    9  "I Innovation Sample, 2009" ///
    10 "J Refreshment Sample, 2011" ///
    11 "K Refreshment Sample, 2012" ///
    12 "L1 Birth Cohorts Sample, 2010" ///
    13 "L2 Family Types, Low-Income Sample, 2010" ///
    14 "L3 Family Types, Single-Parent Sample, 2011" ///
    15 "M1 IAB-SOEP Migration Sample, 2013" ///
    16 "M2 IAB-SOEP Migration Sample, 2015" ///
    17 "M3 IAB-BAMF-SOEP Refugee Sample, 2016" ///
    18 "M4 IAB-BAMF-SOEP Refugee Family Sample, 2016" ///
    19 "M5 IAB-BAMF-SOEP Refugee Sample, 2017" ///
    20 "N PIAAC-L Refreshment Sample, 2017" ///
    21 "O Social City Sample, 2018" ///
    22 "P Top Shareholder Sample, 2019" ///
    23 "Q LGB Sample, 2019", replace

label values psample psample_en_lbl


* ============================================================
* 3. Mark retained core SOEP samples
* ============================================================

capture drop core_soep_sample

gen byte core_soep_sample = .
replace core_soep_sample = 1 if inlist(psample, 1, 3, 5, 6, 7, 8, 10, 11, 12, 13, 14)
replace core_soep_sample = 0 if !missing(psample) & core_soep_sample != 1

label define core_soep_sample_lbl ///
    0 "Excluded sample" ///
    1 "Retained core sample", replace

label values core_soep_sample core_soep_sample_lbl
label var core_soep_sample "Retained in core SOEP analysis"

tab psample core_soep_sample, missing


* ============================================================
* 4. Prepare counts by psample
* ============================================================

preserve

keep if !missing(psample)

capture drop tag_pid_sample
egen byte tag_pid_sample = tag(pid psample)

collapse ///
    (count) observations = pid ///
    (sum) individuals = tag_pid_sample ///
    (first) retained = core_soep_sample, ///
    by(psample)

sort psample

tempfile sample_counts
save `sample_counts', replace


* ============================================================
* 5. Write LaTeX table
* ============================================================

use `sample_counts', clear

capture file close fh
file open fh using "`texfile'", write replace

file write fh "\begin{table}[!htbp]" _n
file write fh "\centering" _n
file write fh "\caption{SOEP Sample Composition}" _n
file write fh "\label{tab:appendix_soep_sample_composition}" _n
file write fh "\begingroup" _n
file write fh "\scriptsize" _n
file write fh "\setlength{\tabcolsep}{6pt}" _n
file write fh "\renewcommand{\arraystretch}{1.08}" _n
file write fh "\begin{adjustbox}{max width=0.98\textwidth,center}" _n
file write fh "\begin{tabular}{clrrc}" _n
file write fh "\toprule" _n
file write fh "Code & SOEP sample & Observations & Individuals & Retained \\" _n
file write fh "\midrule" _n

forvalues i = 1/30 {

    quietly count if psample == `i'

    if r(N) > 0 {

        quietly summarize observations if psample == `i', meanonly
        local obs : display %12.0fc r(mean)
        local obs = strtrim("`obs'")

        quietly summarize individuals if psample == `i', meanonly
        local ids : display %12.0fc r(mean)
        local ids = strtrim("`ids'")

        quietly summarize retained if psample == `i', meanonly
        local retcode = r(mean)

        local retained "No"
        if `retcode' == 1 {
            local retained "Yes"
        }

        local sname ""
        if `i' == 1  local sname "A Original Sample West, 1984"
        if `i' == 2  local sname "B Migration Sample, 1984"
        if `i' == 3  local sname "C Original Sample East, 1990"
        if `i' == 4  local sname "D Migration Sample, 1994/95"
        if `i' == 5  local sname "E Refreshment Sample, 1998"
        if `i' == 6  local sname "F Refreshment Sample, 2000"
        if `i' == 7  local sname "G High-Income Sample, 2002"
        if `i' == 8  local sname "H Refreshment Sample, 2006"
        if `i' == 9  local sname "I Innovation Sample, 2009"
        if `i' == 10 local sname "J Refreshment Sample, 2011"
        if `i' == 11 local sname "K Refreshment Sample, 2012"
        if `i' == 12 local sname "L1 Birth Cohorts Sample, 2010"
        if `i' == 13 local sname "L2 Family Types, Low-Income Sample, 2010"
        if `i' == 14 local sname "L3 Family Types, Single-Parent Sample, 2011"
        if `i' == 15 local sname "M1 IAB-SOEP Migration Sample, 2013"
        if `i' == 16 local sname "M2 IAB-SOEP Migration Sample, 2015"
        if `i' == 17 local sname "M3 IAB-BAMF-SOEP Refugee Sample, 2016"
        if `i' == 18 local sname "M4 IAB-BAMF-SOEP Refugee Family Sample, 2016"
        if `i' == 19 local sname "M5 IAB-BAMF-SOEP Refugee Sample, 2017"
        if `i' == 20 local sname "N PIAAC-L Refreshment Sample, 2017"
        if `i' == 21 local sname "O Social City Sample, 2018"
        if `i' == 22 local sname "P Top Shareholder Sample, 2019"
        if `i' == 23 local sname "Q LGB Sample, 2019"
        if `i' >= 24 local sname "SOEP sample code `i'"

        file write fh "`i' & `sname' & `obs' & `ids' & `retained' \\" _n
    }
}

file write fh "\midrule" _n


* ============================================================
* 6. Totals
* ============================================================

quietly summarize observations if retained == 1, meanonly
quietly total observations if retained == 1
matrix T = r(table)
local obs_core : display %12.0fc T[1,1]
local obs_core = strtrim("`obs_core'")

quietly total individuals if retained == 1
matrix T = r(table)
local ids_core : display %12.0fc T[1,1]
local ids_core = strtrim("`ids_core'")

file write fh "\multicolumn{2}{l}{Retained core samples} & `obs_core' & `ids_core' &  \\" _n

quietly total observations if retained == 0
matrix T = r(table)
local obs_excl : display %12.0fc T[1,1]
local obs_excl = strtrim("`obs_excl'")

quietly total individuals if retained == 0
matrix T = r(table)
local ids_excl : display %12.0fc T[1,1]
local ids_excl = strtrim("`ids_excl'")

file write fh "\multicolumn{2}{l}{Excluded samples} & `obs_excl' & `ids_excl' &  \\" _n

quietly total observations
matrix T = r(table)
local obs_all : display %12.0fc T[1,1]
local obs_all = strtrim("`obs_all'")

quietly total individuals
matrix T = r(table)
local ids_all : display %12.0fc T[1,1]
local ids_all = strtrim("`ids_all'")

file write fh "\multicolumn{2}{l}{Total} & `obs_all' & `ids_all' &  \\" _n

file write fh "\bottomrule" _n
file write fh "\end{tabular}" _n
file write fh "\end{adjustbox}" _n

file write fh "\vspace{0.45em}" _n
file write fh "\begin{minipage}{0.98\textwidth}" _n
file write fh "\footnotesize" _n
file write fh "\emph{Notes:} The table reports person-year observations and person counts within each SOEP sample in the prepared source panel, covering `source_year_min'--`source_year_max' (before regression-year and age restrictions). " _n
file write fh "The retained core samples are A, C, E, F, G, H, J, K, L1, L2, and L3. " _n
file write fh "Excluded special-purpose samples and all additional sample codes (24--30) are shown. Person counts in the total rows are sums of sample-specific counts. " _n
file write fh "\end{minipage}" _n
file write fh "\endgroup" _n
file write fh "\end{table}" _n

file close fh

restore

di as text "Done."
log close tableA1
di as text "SOEP sample composition table saved to:"
di as text "`texfile'"

* ==============================================================================
* Appendix Table A2. Descriptive Statistics
* ==============================================================================
version 17
set more off

preserve


* ============================================================
* 0. Settings
* ============================================================

global ID      "pid"
global Y       "happy"
global INCOME  "linc_eq_m"
global CONS    "lcons_eq_m"

global OUTDIR "$ROOT/output"
capture mkdir "$OUTDIR"

capture log close tableA2
log using "$OUTDIR/tableA2_descriptive_statistics.log", text replace name(tableA2)

local min_year      1999
local max_year      2019

local age_min       20
local age_max       80

local min_ref_cell  10

global X "i.marital educ hsize kid01 kid24 kid57 kid810 kid1112 kid1315 kid1618 i.curhealth nlabor i.e11103 owner lworkh i.year i.state"

drop if e11103 < 0

* Keep core SOEP samples suitable for native German analysis.
* Exclude migration/refugee and special-purpose samples.

keep if inlist(psample, 1, 3, 5, 6, 7, 8, 10, 11, 12, 13, 14)

* ============================================================
* 1. Basic restrictions
* ============================================================

keep if year >= `min_year'
keep if year <= `max_year'
drop if age < `age_min' | age > `age_max'

sort $ID year
xtset $ID year


* ============================================================
* 2. Attendance and Christian parental-background sample
* ============================================================

capture drop any_attend christian_parent_sample

gen byte any_attend = .
replace any_attend = 0 if attend4 == 1
replace any_attend = 1 if inlist(attend4, 2, 3, 4)

label define any_attend_lbl ///
    0 "Never" ///
    1 "Any attendance", replace

label values any_attend any_attend_lbl
label var any_attend "Any church attendance"

gen byte christian_parent_sample = .
replace christian_parent_sample = 1 if inlist(parent_denom, 1, 2, 3)
replace christian_parent_sample = 0 if !missing(parent_denom) & !inlist(parent_denom, 1, 2, 3)

label var christian_parent_sample "Christian parental background sample"


* ============================================================
* 3. Income and consumption variables
* ============================================================

capture drop labs_0 inc1 lcons_0 cons1

gen double labs_0 = $INCOME
gen double inc1   = exp(labs_0) if !missing(labs_0)

gen double lcons_0 = $CONS
gen double cons1   = exp(lcons_0)-1 if !missing(lcons_0)

label var labs_0  "Log own income"
label var inc1    "Own income in levels"
label var lcons_0 "Log own consumption"
label var cons1   "Own consumption in levels"


* ============================================================
* 4. Baseline reference group and reference income
* ============================================================

foreach v in qeduc2 agefn rg_base nref_base sum_inc_base lref_base_loo {
    capture drop `v'
}

xtile qeduc2 = educ if !missing(educ), nq(2)

gen byte agefn = .
replace agefn = 1 if age <= 30 & !missing(age)
replace agefn = 2 if age > 30  & age <= 40
replace agefn = 3 if age > 40  & age <= 50
replace agefn = 4 if age > 50  & age <= 65
replace agefn = 5 if age > 65  & !missing(age)

egen long rg_base = group(year female agefn qeduc2 state) ///
    if !missing(year, female, agefn, qeduc2, state)

bysort rg_base: egen long nref_base = count(inc1)
bysort rg_base: egen double sum_inc_base = total(inc1)

replace nref_base = . if missing(rg_base)
replace sum_inc_base = . if missing(rg_base)

gen double lref_base_loo = .

replace lref_base_loo = log((sum_inc_base - inc1) / (nref_base - 1)) ///
    if nref_base > 1 & !missing(inc1) & (sum_inc_base - inc1) > 0

replace lref_base_loo = log(sum_inc_base / nref_base) ///
    if missing(inc1) & nref_base > 0 & sum_inc_base > 0

replace lref_base_loo = . if nref_base < `min_ref_cell'

label var lref_base_loo "Log leave-one-out mean reference income"


* ============================================================
* 5. Baseline regression sample
* ============================================================

capture drop sample_candidate own_never own_any ref_never ref_any sample_desc

gen byte sample_candidate = !missing($Y, labs_0, lref_base_loo, any_attend, rg_base, christian_parent_sample)
replace sample_candidate = 0 if christian_parent_sample != 1

gen double own_never = 0 if sample_candidate == 1
gen double own_any   = 0 if sample_candidate == 1

gen double ref_never = 0 if sample_candidate == 1
gen double ref_any   = 0 if sample_candidate == 1

replace own_never = labs_0 if sample_candidate == 1 & any_attend == 0
replace own_any   = labs_0 if sample_candidate == 1 & any_attend == 1

replace ref_never = lref_base_loo if sample_candidate == 1 & any_attend == 0
replace ref_any   = lref_base_loo if sample_candidate == 1 & any_attend == 1

sort $ID year
xtset $ID year

xtreg $Y ///
    c.own_never c.own_any ///
    c.ref_never c.ref_any ///
    i.any_attend ///
    $X ///
    if sample_candidate == 1, ///
    fe vce(cluster rg_base) nonest

gen byte sample_desc = e(sample)

label var sample_desc "Baseline regression sample"

count if sample_desc == 1
di as text "Baseline regression sample observations: " r(N)

capture drop tag_sample_desc
egen tag_sample_desc = tag(pid) if sample_desc == 1
count if tag_sample_desc == 1
di as text "Baseline regression sample individuals: " r(N)
capture drop tag_sample_desc


* ============================================================
* 6. Additional descriptive variables
* ============================================================

capture drop married employed child_sum any_child ///
             catholic_parent protestant_parent mixed_parent

gen byte married = .
replace married = 1 if marital == 1
replace married = 0 if !missing(marital) & marital != 1

gen byte employed = .
replace employed = 1 if emp_stat == 1
replace employed = 0 if !missing(emp_stat) & emp_stat != 1

egen double child_sum = rowtotal(kid01 kid24 kid57 kid810 kid1112 kid1315 kid1618), missing

gen byte any_child = .
replace any_child = 1 if child_sum > 0 & !missing(child_sum)
replace any_child = 0 if child_sum == 0

gen byte catholic_parent = .
replace catholic_parent = 1 if parent_denom == 1
replace catholic_parent = 0 if !missing(parent_denom) & parent_denom != 1

gen byte protestant_parent = .
replace protestant_parent = 1 if parent_denom == 2
replace protestant_parent = 0 if !missing(parent_denom) & parent_denom != 2

gen byte mixed_parent = .
replace mixed_parent = 1 if parent_denom == 3
replace mixed_parent = 0 if !missing(parent_denom) & parent_denom != 3


* ============================================================
* 7. Column conditions
* ============================================================

global G1 "sample_desc == 1"
global G2 "sample_desc == 1 & any_attend == 0"
global G3 "sample_desc == 1 & any_attend == 1"
global G4 "sample_desc == 1 & parent_denom == 1"
global G5 "sample_desc == 1 & parent_denom == 2"
global G6 "sample_desc == 1 & parent_denom == 3"


* ============================================================
* 8. Program to write one descriptive row
* ============================================================

capture program drop write_desc_row
program define write_desc_row
    version 17
    syntax varname, LABEL(string)

    local row "`label'"
    local serow " "

    forvalues j = 1/6 {
        local cond "${G`j'}"

        quietly summarize `varlist' if `cond'

        if r(N) > 0 {
            local mean : display %9.3f r(mean)
            local sd   : display %9.3f r(sd)

            local mean = strtrim("`mean'")
            local sd   = strtrim("`sd'")

            local row   "`row' & `mean'"
            local serow "`serow' & (`sd')"
        }
        else {
            local row   "`row' & "
            local serow "`serow' & "
        }
    }

    file write fh "`row' \\" _n
    file write fh "`serow' \\" _n
end


* ============================================================
* 9. Appendix Table A2
* ============================================================

local texfile "$OUTDIR/appendix_table_A1_descriptive_statistics.tex"

capture file close fh
file open fh using "`texfile'", write replace

file write fh "\begin{table}[!htbp]" _n
file write fh "\centering" _n
file write fh "\caption{Descriptive Statistics}" _n
file write fh "\label{tab:appendix_descriptive_statistics}" _n
file write fh "\begingroup" _n
file write fh "\scriptsize" _n
file write fh "\setlength{\tabcolsep}{5.5pt}" _n
file write fh "\renewcommand{\arraystretch}{1.12}" _n
file write fh "\begin{adjustbox}{max width=1.00\textwidth,center}" _n
file write fh "\begin{tabular}{lcccccc}" _n
file write fh "\toprule" _n
file write fh " & (1) & (2) & (3) & (4) & (5) & (6) \\" _n
file write fh "\cmidrule(lr){2-7}" _n
file write fh " & Full sample & Never & Any attend. & Catholic & Protestant & Mixed \\" _n
file write fh "\midrule" _n

write_desc_row happy,              label("Life satisfaction")
write_desc_row labs_0,             label("Log own income")
write_desc_row lref_base_loo,      label("Log reference income")
write_desc_row lcons_0,            label("Log(1+consumption)")
write_desc_row age,                label("Age")
write_desc_row female,             label("Female")
write_desc_row educ,               label("Years of education")
write_desc_row married,            label("Married")
write_desc_row employed,           label("Employed")
write_desc_row hsize,              label("Household size")
write_desc_row any_child,          label("Children in household")
write_desc_row curhealth,          label("Self-rated health")
write_desc_row nlabor,             label("Log(1+non-labour income)")
write_desc_row owner,              label("Home owner")
write_desc_row lworkh,             label("Log working hours")
write_desc_row any_attend,         label("Any church attendance")
write_desc_row catholic_parent,    label("Both parents Catholic")
write_desc_row protestant_parent,  label("Both parents Protestant")
write_desc_row mixed_parent,       label("Catholic-Protestant mixed parents")

file write fh "\midrule" _n

local obsrow "Observations"
local idrow  "Individuals"

forvalues j = 1/6 {
    local cond "${G`j'}"

    quietly count if `cond'
    local n : display %12.0fc r(N)
    local n = strtrim("`n'")
    local obsrow "`obsrow' & `n'"

    capture drop tag_tmp
    egen tag_tmp = tag(pid) if `cond'
    quietly count if tag_tmp == 1
    local ids : display %12.0fc r(N)
    local ids = strtrim("`ids'")
    local idrow "`idrow' & `ids'"
    capture drop tag_tmp
}

file write fh "`obsrow' \\" _n
file write fh "`idrow' \\" _n

file write fh "\bottomrule" _n
file write fh "\end{tabular}" _n
file write fh "\end{adjustbox}" _n

file write fh "\vspace{0.45em}" _n
file write fh "\begin{minipage}{1.00\textwidth}" _n
file write fh "\footnotesize" _n
file write fh "\emph{Notes:} Standard deviations are in parentheses. " _n
file write fh "The full sample is the baseline regression sample used in the main attendance analysis. " _n
file write fh "The sample is restricted to individuals aged 20--80 observed between 1999 and 2019 with Catholic, Protestant, or Catholic-Protestant mixed parental background. " _n
file write fh "Any attendance equals one for individuals who attend religious services less often, at least monthly, or at least weekly. " _n
file write fh "Reference income is the log leave-one-out mean income of the reference group, defined by year, gender, age group, two education groups, and federal state, with a minimum reference-group-year cell size of 10. " _n
file write fh "\end{minipage}" _n
file write fh "\endgroup" _n
file write fh "\end{table}" _n

file close fh

restore

di as text "Done."
di as text "Appendix descriptive statistics saved to:"
di as text "`texfile'"
log close tableA2

exit
